-- ============================================================
-- MIGRAÇÃO: Atualizar views do cliente (agendamento + nome/rating prestador)
-- Execute no Supabase SQL Editor após 20250214000000
-- ============================================================
-- IMPORTANTE: Se as views tiverem estrutura diferente, execute primeiro:
--   SELECT pg_get_viewdef('public.v_client_jobs', true);
--   SELECT pg_get_viewdef('public.v_client_job_quotes', true);
-- e ajuste os CREATE VIEW abaixo conforme necessário.
-- ============================================================

-- 2.1 v_client_jobs: incluir colunas de agendamento (para mostrar data/hora selecionada pelo cliente)
-- Estrutura baseada na definição atual da view + j.scheduled_date, j.scheduled_start_time,
-- j.scheduled_end_time, j.has_flexible_schedule
DROP VIEW IF EXISTS public.v_client_jobs CASCADE;
CREATE VIEW public.v_client_jobs AS
SELECT
  j.id,
  j.job_code,
  j.client_id,
  j.provider_id,
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
  j.created_at,
  j.updated_at,
  COALESCE(
    (SELECT json_agg(json_build_object('url', ph.url, 'thumb_url', ph.thumb_url, 'created_at', ph.created_at) ORDER BY ph.created_at)
     FROM job_photos ph
     WHERE ph.job_id = j.id),
    '[]'::json
  ) AS photos,
  j.eta_minutes,
  j.on_the_way_at,
  j.in_progress_at,
  j.completed_at,
  j.cancelled_at,
  j.is_disputed,
  j.dispute_open,
  pr.avatar_url AS provider_avatar_url
FROM public.jobs j
LEFT JOIN public.providers pr ON pr.id = j.provider_id
WHERE j.client_id = auth.uid();

-- 2.2 v_client_job_quotes: incluir provider_name e provider_rating (de profiles)
-- Usa profiles (via providers.user_id) para full_name, rating, avatar_url
DROP VIEW IF EXISTS public.v_client_job_quotes CASCADE;
CREATE VIEW public.v_client_job_quotes AS
SELECT
  q.id AS quote_id,
  q.job_id,
  q.provider_id,
  q.approximate_price,
  q.message,
  q.created_at,
  q.proposed_date,
  q.proposed_start_time,
  q.proposed_end_time,
  q.estimated_duration_minutes,
  COALESCE(NULLIF(TRIM(pf.full_name), ''), 'Profissional') AS provider_name,
  pf.rating AS provider_rating,
  pf.avatar_url AS provider_avatar_url
FROM public.job_quotes q
JOIN public.providers p ON p.id = q.provider_id
JOIN public.profiles pf ON pf.id = p.user_id;
