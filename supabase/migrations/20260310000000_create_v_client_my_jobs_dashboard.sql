-- ============================================================
-- Cria/recria v_client_my_jobs_dashboard
-- Adicionado: provider_name, scheduled_date, payment_status,
--             service_type_name
-- ============================================================

DROP VIEW IF EXISTS public.v_client_my_jobs_dashboard CASCADE;

CREATE VIEW public.v_client_my_jobs_dashboard AS
SELECT
  j.id                                                     AS job_id,
  j.job_code,
  j.title,
  j.description,
  j.status,
  j.created_at,
  j.scheduled_date,
  j.payment_status,

  -- Prestador (só quando atribuído)
  COALESCE(NULLIF(TRIM(pv.full_name), ''), NULL)           AS provider_name,

  -- Tipo de serviço
  st.name                                                  AS service_type_name,

  -- Quantidade de orçamentos recebidos
  (SELECT COUNT(*)::int
     FROM public.job_quotes q
    WHERE q.job_id = j.id)                                AS quotes_count,

  -- Candidatos pendentes (ainda não enviaram orçamento)
  (SELECT COUNT(*)::int
     FROM public.job_candidates jc
    WHERE jc.job_id = j.id
      AND COALESCE(jc.status,          'pending') = 'pending'
      AND COALESCE(jc.decision_status, 'pending') = 'pending')
                                                           AS new_candidates_count,

  -- Status de disputa derivado das flags do job
  CASE
    WHEN j.dispute_open = true                  THEN 'open'
    WHEN j.is_disputed  = true
     AND j.dispute_open IS DISTINCT FROM true   THEN 'resolved'
    ELSE NULL
  END                                                      AS dispute_status

FROM public.jobs j
LEFT JOIN public.providers     pv ON pv.id = j.provider_id
LEFT JOIN public.service_types st ON st.id = j.service_type_id
WHERE j.client_id = auth.uid()
  AND j.deleted_at IS NULL;

GRANT SELECT ON public.v_client_my_jobs_dashboard TO authenticated;

DO $$
BEGIN
  RAISE NOTICE 'v_client_my_jobs_dashboard: recriada com provider_name, scheduled_date, payment_status, service_type_name.';
END;
$$;
