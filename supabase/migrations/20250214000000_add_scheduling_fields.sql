-- ============================================================
-- MIGRAÇÃO: Agendamento de serviços no Renthus
-- Execute no Supabase SQL Editor: Dashboard > SQL Editor > New query
-- ============================================================

-- 1.1 Novas colunas na tabela jobs
ALTER TABLE public.jobs
  ADD COLUMN IF NOT EXISTS scheduled_date DATE,
  ADD COLUMN IF NOT EXISTS scheduled_start_time TIME,
  ADD COLUMN IF NOT EXISTS scheduled_end_time TIME,
  ADD COLUMN IF NOT EXISTS has_flexible_schedule BOOLEAN DEFAULT TRUE;

ALTER TABLE public.jobs
  DROP CONSTRAINT IF EXISTS chk_schedule_times;
ALTER TABLE public.jobs
  ADD CONSTRAINT chk_schedule_times
  CHECK (
    scheduled_start_time IS NULL
    OR scheduled_end_time IS NULL
    OR scheduled_end_time > scheduled_start_time
  );

-- 1.2 Novas colunas na tabela job_quotes
ALTER TABLE public.job_quotes
  ADD COLUMN IF NOT EXISTS proposed_date DATE,
  ADD COLUMN IF NOT EXISTS proposed_start_time TIME DEFAULT '08:00',
  ADD COLUMN IF NOT EXISTS proposed_end_time TIME DEFAULT '12:00',
  ADD COLUMN IF NOT EXISTS estimated_duration_minutes INT;

ALTER TABLE public.job_quotes
  DROP CONSTRAINT IF EXISTS chk_quote_times;
ALTER TABLE public.job_quotes
  ADD CONSTRAINT chk_quote_times
  CHECK (proposed_end_time > proposed_start_time);

ALTER TABLE public.job_quotes
  DROP CONSTRAINT IF EXISTS chk_quote_duration;
ALTER TABLE public.job_quotes
  ADD CONSTRAINT chk_quote_duration
  CHECK (estimated_duration_minutes IS NULL OR estimated_duration_minutes > 0);

-- 1.3 Recriar RPC create_job (dropar e criar)
DROP FUNCTION IF EXISTS public.create_job(UUID,UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,DOUBLE PRECISION,DOUBLE PRECISION);
CREATE OR REPLACE FUNCTION public.create_job(
  p_service_type_id UUID,
  p_category_id UUID,
  p_title TEXT,
  p_description TEXT,
  p_service_detected TEXT,
  p_street TEXT,
  p_number TEXT,
  p_district TEXT,
  p_city TEXT,
  p_state TEXT,
  p_zipcode TEXT DEFAULT NULL,
  p_lat DOUBLE PRECISION DEFAULT NULL,
  p_lng DOUBLE PRECISION DEFAULT NULL,
  p_scheduled_date DATE DEFAULT NULL,
  p_scheduled_start_time TIME DEFAULT NULL,
  p_scheduled_end_time TIME DEFAULT NULL,
  p_has_flexible_schedule BOOLEAN DEFAULT TRUE
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_client_id UUID;
  v_job_id UUID;
BEGIN
  v_client_id := auth.uid();
  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado';
  END IF;

  INSERT INTO public.jobs (
    client_id, service_type_id, category_id,
    title, description, service_detected,
    status,
    scheduled_date, scheduled_start_time, scheduled_end_time, has_flexible_schedule
  ) VALUES (
    v_client_id, p_service_type_id, p_category_id,
    p_title, p_description, p_service_detected,
    'waiting_providers',
    p_scheduled_date, p_scheduled_start_time, p_scheduled_end_time, p_has_flexible_schedule
  )
  RETURNING id INTO v_job_id;

  INSERT INTO public.job_addresses (
    job_id, street, number, district, city, state, zipcode, lat, lng
  ) VALUES (
    v_job_id, p_street, p_number, p_district, p_city, p_state, p_zipcode, p_lat, p_lng
  );

  RETURN v_job_id;
END;
$$;

-- 1.4 Recriar RPC submit_job_quote (drop versão antiga com 3 params primeiro)
DROP FUNCTION IF EXISTS public.submit_job_quote(UUID, NUMERIC, TEXT);
CREATE OR REPLACE FUNCTION public.submit_job_quote(
  p_job_id UUID,
  p_approximate_price NUMERIC,
  p_message TEXT DEFAULT NULL,
  p_proposed_date DATE DEFAULT NULL,
  p_proposed_start_time TIME DEFAULT '08:00',
  p_proposed_end_time TIME DEFAULT '12:00',
  p_estimated_duration_minutes INT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_provider_id UUID;
  v_job_date DATE;
  v_has_flexible BOOLEAN;
BEGIN
  v_provider_id := auth.uid();
  IF v_provider_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado';
  END IF;

  SELECT scheduled_date, COALESCE(has_flexible_schedule, true)
    INTO v_job_date, v_has_flexible
    FROM public.jobs WHERE id = p_job_id;

  IF v_has_flexible = FALSE AND v_job_date IS NOT NULL THEN
    p_proposed_date := v_job_date;
  END IF;

  INSERT INTO public.job_candidates (job_id, provider_id, status)
  VALUES (p_job_id, v_provider_id, 'pending')
  ON CONFLICT (job_id, provider_id) DO UPDATE SET status = 'pending';

  INSERT INTO public.job_quotes (
    job_id, provider_id, approximate_price, message,
    proposed_date, proposed_start_time, proposed_end_time, estimated_duration_minutes
  ) VALUES (
    p_job_id, v_provider_id, p_approximate_price, p_message,
    COALESCE(p_proposed_date, v_job_date),
    p_proposed_start_time, p_proposed_end_time, p_estimated_duration_minutes
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

-- ============================================================
-- 1.5 Atualizar view v_provider_jobs_public com campos de agendamento
-- DROP necessário pois CREATE OR REPLACE não permite adicionar colunas
-- ============================================================
DROP VIEW IF EXISTS public.v_provider_jobs_public CASCADE;
CREATE VIEW public.v_provider_jobs_public AS
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
  COALESCE(
    (SELECT json_agg(json_build_object('url', pht.url, 'thumb_url', pht.thumb_url, 'created_at', pht.created_at) ORDER BY pht.created_at)
     FROM job_photos pht
     WHERE pht.job_id = j.id),
    '[]'::json
  ) AS photos
FROM jobs j
JOIN job_addresses a ON a.job_id = j.id
CROSS JOIN me
WHERE j.status = 'waiting_providers'
  AND j.provider_id IS NULL
  AND EXISTS (
    SELECT 1 FROM provider_service_types pst
    WHERE pst.provider_id = me.provider_id AND pst.service_type_id = j.service_type_id
  )
  AND NOT EXISTS (
    SELECT 1 FROM job_candidates jc
    WHERE jc.job_id = j.id AND jc.provider_id = me.provider_id
  );
