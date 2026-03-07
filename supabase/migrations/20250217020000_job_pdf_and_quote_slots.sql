-- ============================================================
-- PDF no pedido + janela de 2h para orçamento + limite de 4 slots
-- ============================================================

ALTER TABLE public.job_candidates
  ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS quote_deadline_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS quote_submitted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_job_candidates_job_deadline
  ON public.job_candidates(job_id, quote_deadline_at);

CREATE TABLE IF NOT EXISTS public.job_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id UUID NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  filename TEXT,
  mime_type TEXT NOT NULL DEFAULT 'application/pdf',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_job_documents_job_id_created_at
  ON public.job_documents(job_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.add_job_document(
  p_job_id UUID,
  p_url TEXT,
  p_filename TEXT DEFAULT NULL,
  p_mime_type TEXT DEFAULT 'application/pdf'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID;
  v_doc_id UUID;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario nao autenticado';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.jobs j
    WHERE j.id = p_job_id
      AND j.client_id = v_uid
  ) THEN
    RAISE EXCEPTION 'Sem permissao para anexar documento neste pedido';
  END IF;

  IF COALESCE(TRIM(p_url), '') = '' THEN
    RAISE EXCEPTION 'URL do documento e obrigatoria';
  END IF;

  INSERT INTO public.job_documents (job_id, url, filename, mime_type)
  VALUES (
    p_job_id,
    TRIM(p_url),
    NULLIF(TRIM(COALESCE(p_filename, '')), ''),
    COALESCE(NULLIF(TRIM(COALESCE(p_mime_type, '')), ''), 'application/pdf')
  )
  RETURNING id INTO v_doc_id;

  RETURN v_doc_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_job_document(UUID, TEXT, TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.provider_accept_job_for_quote(
  p_job_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID;
  v_provider_id UUID;
  v_service_type_id UUID;
  v_status TEXT;
  v_provider_owner UUID;
  v_existing_deadline TIMESTAMPTZ;
  v_quotes_count INT;
  v_active_accepts INT;
  v_slots_used INT;
  v_deadline TIMESTAMPTZ;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario nao autenticado';
  END IF;

  SELECT p.id INTO v_provider_id
  FROM public.providers p
  WHERE p.user_id = v_uid
  LIMIT 1;

  IF v_provider_id IS NULL THEN
    RAISE EXCEPTION 'Prestador nao encontrado';
  END IF;

  SELECT j.service_type_id, j.status, j.provider_id
    INTO v_service_type_id, v_status, v_provider_owner
  FROM public.jobs j
  WHERE j.id = p_job_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pedido nao encontrado';
  END IF;

  IF v_provider_owner IS NOT NULL THEN
    RAISE EXCEPTION 'Pedido ja possui prestador definido';
  END IF;

  IF v_status <> 'waiting_providers' THEN
    RAISE EXCEPTION 'Pedido nao esta aberto para novos orcamentos';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.provider_service_types pst
    WHERE pst.provider_id = v_provider_id
      AND pst.service_type_id = v_service_type_id
  ) THEN
    RAISE EXCEPTION 'Prestador nao atende esse tipo de servico';
  END IF;

  UPDATE public.job_candidates jc
     SET status = 'expired',
         decision_status = 'expired'
   WHERE jc.job_id = p_job_id
     AND jc.status = 'pending'
     AND COALESCE(jc.quote_deadline_at, jc.created_at + INTERVAL '2 hours') <= now()
     AND NOT EXISTS (
       SELECT 1
       FROM public.job_quotes q
       WHERE q.job_id = jc.job_id
         AND q.provider_id = jc.provider_id
     );

  SELECT q.created_at
    INTO v_existing_deadline
  FROM public.job_quotes q
  WHERE q.job_id = p_job_id
    AND q.provider_id = v_provider_id
  LIMIT 1;

  IF v_existing_deadline IS NOT NULL THEN
    RAISE EXCEPTION 'Voce ja enviou orcamento para este pedido';
  END IF;

  SELECT COALESCE(jc.quote_deadline_at, jc.created_at + INTERVAL '2 hours')
    INTO v_existing_deadline
  FROM public.job_candidates jc
  WHERE jc.job_id = p_job_id
    AND jc.provider_id = v_provider_id
    AND jc.status = 'pending'
    AND COALESCE(jc.quote_deadline_at, jc.created_at + INTERVAL '2 hours') > now()
  LIMIT 1;

  IF v_existing_deadline IS NOT NULL THEN
    RETURN jsonb_build_object(
      'accepted', true,
      'quote_deadline_at', v_existing_deadline,
      'slots_total', 4
    );
  END IF;

  SELECT COUNT(*)::INT
    INTO v_quotes_count
  FROM public.job_quotes q
  WHERE q.job_id = p_job_id;

  SELECT COUNT(*)::INT
    INTO v_active_accepts
  FROM public.job_candidates jc
  WHERE jc.job_id = p_job_id
    AND jc.status = 'pending'
    AND COALESCE(jc.quote_deadline_at, jc.created_at + INTERVAL '2 hours') > now()
    AND NOT EXISTS (
      SELECT 1
      FROM public.job_quotes q
      WHERE q.job_id = jc.job_id
        AND q.provider_id = jc.provider_id
    );

  v_slots_used := v_quotes_count + v_active_accepts;
  IF v_slots_used >= 4 THEN
    RAISE EXCEPTION 'Limite de 4 prestadores em orcamento ja foi atingido';
  END IF;

  v_deadline := now() + INTERVAL '2 hours';

  INSERT INTO public.job_candidates (
    job_id,
    provider_id,
    status,
    decision_status,
    client_status,
    accepted_at,
    quote_deadline_at,
    quote_submitted_at
  )
  VALUES (
    p_job_id,
    v_provider_id,
    'pending',
    'pending',
    'pending',
    now(),
    v_deadline,
    NULL
  )
  ON CONFLICT (job_id, provider_id) DO UPDATE
    SET status = 'pending',
        decision_status = 'pending',
        client_status = 'pending',
        accepted_at = EXCLUDED.accepted_at,
        quote_deadline_at = EXCLUDED.quote_deadline_at,
        quote_submitted_at = NULL;

  RETURN jsonb_build_object(
    'accepted', true,
    'quote_deadline_at', v_deadline,
    'slots_used', v_slots_used + 1,
    'slots_total', 4
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.provider_accept_job_for_quote(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.submit_job_quote(
  p_job_id UUID,
  p_approximate_price NUMERIC,
  p_message TEXT DEFAULT NULL,
  p_proposed_date DATE DEFAULT NULL,
  p_proposed_start_time TIME DEFAULT NULL,
  p_proposed_end_time TIME DEFAULT NULL,
  p_estimated_duration_minutes INT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_provider_id UUID;
  v_job_date DATE;
  v_has_flexible BOOLEAN;
  v_final_date DATE;
  v_has_quote BOOLEAN;
  v_quote_deadline TIMESTAMPTZ;
BEGIN
  v_provider_id := auth.uid();
  IF v_provider_id IS NULL THEN
    RAISE EXCEPTION 'Usuario nao autenticado';
  END IF;

  UPDATE public.job_candidates jc
     SET status = 'expired',
         decision_status = 'expired'
   WHERE jc.job_id = p_job_id
     AND jc.status = 'pending'
     AND COALESCE(jc.quote_deadline_at, jc.created_at + INTERVAL '2 hours') <= now()
     AND NOT EXISTS (
       SELECT 1
       FROM public.job_quotes q
       WHERE q.job_id = jc.job_id
         AND q.provider_id = jc.provider_id
     );

  SELECT
    j.scheduled_date,
    COALESCE(j.has_flexible_schedule, TRUE)
  INTO
    v_job_date,
    v_has_flexible
  FROM public.jobs j
  WHERE j.id = p_job_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pedido nao encontrado';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.job_quotes q
    WHERE q.job_id = p_job_id
      AND q.provider_id = v_provider_id
  ) INTO v_has_quote;

  IF NOT v_has_quote THEN
    SELECT COALESCE(jc.quote_deadline_at, jc.created_at + INTERVAL '2 hours')
      INTO v_quote_deadline
    FROM public.job_candidates jc
    WHERE jc.job_id = p_job_id
      AND jc.provider_id = v_provider_id
      AND jc.status = 'pending'
    LIMIT 1;

    IF v_quote_deadline IS NULL THEN
      RAISE EXCEPTION 'Aceite o pedido antes de enviar o orcamento';
    END IF;

    IF v_quote_deadline <= now() THEN
      RAISE EXCEPTION 'Prazo de 2 horas expirou. Aceite o pedido novamente para enviar orcamento';
    END IF;
  END IF;

  IF v_has_flexible = FALSE AND v_job_date IS NOT NULL THEN
    v_final_date := v_job_date;
  ELSE
    v_final_date := p_proposed_date;
  END IF;

  IF v_final_date IS NULL THEN
    RAISE EXCEPTION 'Data da proposta e obrigatoria';
  END IF;

  IF p_proposed_start_time IS NULL OR p_proposed_end_time IS NULL THEN
    RAISE EXCEPTION 'Horario de inicio e fim da proposta sao obrigatorios';
  END IF;

  IF p_proposed_end_time <= p_proposed_start_time THEN
    RAISE EXCEPTION 'Horario de fim deve ser maior que o horario de inicio';
  END IF;

  INSERT INTO public.job_candidates (
    job_id, provider_id, status, decision_status, client_status, quote_submitted_at
  )
  VALUES (p_job_id, v_provider_id, 'pending', 'pending', 'pending', now())
  ON CONFLICT (job_id, provider_id) DO UPDATE SET
    status = 'pending',
    decision_status = 'pending',
    client_status = 'pending',
    quote_submitted_at = now();

  INSERT INTO public.job_quotes (
    job_id, provider_id, approximate_price, message,
    proposed_date, proposed_start_time, proposed_end_time, estimated_duration_minutes
  ) VALUES (
    p_job_id, v_provider_id, p_approximate_price, p_message,
    v_final_date, p_proposed_start_time, p_proposed_end_time, p_estimated_duration_minutes
  )
  ON CONFLICT (job_id, provider_id) DO UPDATE SET
    approximate_price = EXCLUDED.approximate_price,
    message = EXCLUDED.message,
    proposed_date = EXCLUDED.proposed_date,
    proposed_start_time = EXCLUDED.proposed_start_time,
    proposed_end_time = EXCLUDED.proposed_end_time,
    estimated_duration_minutes = EXCLUDED.estimated_duration_minutes;
END;
$$;

DROP VIEW IF EXISTS public.v_provider_jobs_public CASCADE;
CREATE VIEW public.v_provider_jobs_public AS
WITH me AS (
  SELECT p.id AS provider_id
  FROM providers p
  WHERE p.user_id = auth.uid()
  LIMIT 1
),
slots AS (
  SELECT
    j.id AS job_id,
    (
      (SELECT COUNT(*) FROM public.job_quotes q WHERE q.job_id = j.id) +
      (SELECT COUNT(*)
       FROM public.job_candidates jc
       WHERE jc.job_id = j.id
         AND jc.status = 'pending'
         AND COALESCE(jc.quote_deadline_at, jc.created_at + INTERVAL '2 hours') > now()
         AND NOT EXISTS (
           SELECT 1 FROM public.job_quotes q2
           WHERE q2.job_id = jc.job_id
             AND q2.provider_id = jc.provider_id
         ))
    )::INT AS slots_used
  FROM public.jobs j
)
SELECT
  j.id,
  j.client_id,
  j.service_type_id,
  j.category_id,
  j.title,
  j.description,
  j.service_detected,
  j.status,
  j.scheduled_date,
  j.scheduled_start_time,
  j.scheduled_end_time,
  j.has_flexible_schedule,
  a.city,
  a.state,
  round(a.lat::numeric, 2)::double precision AS lat,
  round(a.lng::numeric, 2)::double precision AS lng,
  j.created_at,
  NULL::timestamptz AS my_quote_deadline_at,
  COALESCE(s.slots_used, 0) AS quotes_slots_used,
  4 AS quotes_slots_total,
  COALESCE(
    (
      SELECT json_agg(
        json_build_object(
          'url', pht.url,
          'thumb_url', pht.thumb_url,
          'created_at', pht.created_at
        ) ORDER BY pht.created_at
      )
      FROM public.job_photos pht
      WHERE pht.job_id = j.id
    ),
    '[]'::json
  ) AS photos,
  COALESCE(
    (
      SELECT json_agg(
        json_build_object(
          'url', d.url,
          'filename', d.filename,
          'mime_type', d.mime_type,
          'created_at', d.created_at
        ) ORDER BY d.created_at
      )
      FROM public.job_documents d
      WHERE d.job_id = j.id
    ),
    '[]'::json
  ) AS documents
FROM public.jobs j
JOIN public.job_addresses a ON a.job_id = j.id
JOIN slots s ON s.job_id = j.id
CROSS JOIN me
WHERE j.status = 'waiting_providers'
  AND j.provider_id IS NULL
  AND COALESCE(s.slots_used, 0) < 4
  AND EXISTS (
    SELECT 1 FROM public.provider_service_types pst
    WHERE pst.provider_id = me.provider_id
      AND pst.service_type_id = j.service_type_id
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.job_quotes q
    WHERE q.job_id = j.id
      AND q.provider_id = me.provider_id
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.job_candidates jc
    WHERE jc.job_id = j.id
      AND jc.provider_id = me.provider_id
      AND jc.status = 'pending'
      AND COALESCE(jc.quote_deadline_at, jc.created_at + INTERVAL '2 hours') > now()
  );

CREATE VIEW public.v_provider_jobs_candidate_pending AS
WITH me AS (
  SELECT p.id AS provider_id
  FROM providers p
  WHERE p.user_id = auth.uid()
  LIMIT 1
)
SELECT
  j.id,
  j.client_id,
  j.service_type_id,
  j.category_id,
  j.title,
  j.description,
  j.service_detected,
  j.status,
  j.scheduled_date,
  j.scheduled_start_time,
  j.scheduled_end_time,
  j.has_flexible_schedule,
  a.city,
  a.state,
  round(a.lat::numeric, 2)::double precision AS lat,
  round(a.lng::numeric, 2)::double precision AS lng,
  j.created_at,
  COALESCE(jc.quote_deadline_at, jc.created_at + INTERVAL '2 hours') AS my_quote_deadline_at,
  COALESCE(
    (
      SELECT json_agg(
        json_build_object(
          'url', pht.url,
          'thumb_url', pht.thumb_url,
          'created_at', pht.created_at
        ) ORDER BY pht.created_at
      )
      FROM public.job_photos pht
      WHERE pht.job_id = j.id
    ),
    '[]'::json
  ) AS photos,
  COALESCE(
    (
      SELECT json_agg(
        json_build_object(
          'url', d.url,
          'filename', d.filename,
          'mime_type', d.mime_type,
          'created_at', d.created_at
        ) ORDER BY d.created_at
      )
      FROM public.job_documents d
      WHERE d.job_id = j.id
    ),
    '[]'::json
  ) AS documents
FROM public.job_candidates jc
JOIN public.jobs j ON j.id = jc.job_id
JOIN public.job_addresses a ON a.job_id = j.id
CROSS JOIN me
WHERE jc.provider_id = me.provider_id
  AND jc.status = 'pending'
  AND j.provider_id IS NULL
  AND j.status = 'waiting_providers'
  AND COALESCE(jc.quote_deadline_at, jc.created_at + INTERVAL '2 hours') > now()
  AND NOT EXISTS (
    SELECT 1 FROM public.job_quotes q
    WHERE q.job_id = j.id
      AND q.provider_id = jc.provider_id
  );

DROP VIEW IF EXISTS public.v_provider_my_jobs CASCADE;
CREATE VIEW public.v_provider_my_jobs AS
WITH me AS (
  SELECT current_provider_id() AS provider_id
),
matched AS (
  SELECT
    j.id AS job_id,
    j.job_code,
    j.title,
    j.description,
    j.status,
    j.created_at,
    j.scheduled_at,
    j.amount_provider,
    NULL::timestamptz AS candidate_created_at,
    'matched'::text AS source
  FROM public.jobs j
  CROSS JOIN me
  WHERE j.provider_id = me.provider_id
),
candidates AS (
  SELECT
    j.id AS job_id,
    j.job_code,
    j.title,
    j.description,
    'waiting_client'::text AS status,
    j.created_at,
    j.scheduled_at,
    NULL::numeric AS amount_provider,
    jc.created_at AS candidate_created_at,
    'candidate'::text AS source
  FROM public.job_candidates jc
  JOIN public.jobs j ON j.id = jc.job_id
  CROSS JOIN me
  WHERE jc.provider_id = me.provider_id
    AND j.provider_id IS NULL
    AND j.status = ANY (ARRAY['open'::text, 'waiting_providers'::text])
    AND jc.status = 'pending'
    AND COALESCE(jc.decision_status, 'pending') = 'pending'
    AND COALESCE(jc.quote_deadline_at, jc.created_at + INTERVAL '2 hours') > now()
    AND NOT EXISTS (
      SELECT 1 FROM public.job_quotes q
      WHERE q.job_id = jc.job_id
        AND q.provider_id = jc.provider_id
    )
)
SELECT
  x.job_id,
  x.job_code,
  x.title,
  x.description,
  x.status,
  x.created_at,
  x.scheduled_at,
  x.amount_provider,
  x.candidate_created_at,
  x.source,
  CASE
    WHEN x.status = ANY (ARRAY['completed','refunded','cancelled','cancelled_by_client','cancelled_by_provider']) THEN 'history'
    WHEN x.status = 'dispute' THEN 'active'
    WHEN x.status = ANY (ARRAY['accepted','on_the_way','in_progress']) THEN 'active'
    WHEN x.status = 'waiting_client' THEN 'waitingClient'
    ELSE 'waitingClient'
  END AS ui_group
FROM (
  SELECT * FROM matched
  UNION ALL
  SELECT * FROM candidates
) x;
