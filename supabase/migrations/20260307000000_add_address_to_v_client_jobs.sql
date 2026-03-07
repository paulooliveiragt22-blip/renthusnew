-- Adiciona campos de endereço do job (job_addresses) na view v_client_jobs.
-- O endereço é exibido no app quando o status for accepted ou posterior.

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
  pr.avatar_url AS provider_avatar_url,
  -- Endereço do job (salvo no momento da criação)
  ja.street        AS address_street,
  ja.number        AS address_number,
  ja.district      AS address_district,
  ja.city          AS address_city,
  ja.state         AS address_state,
  ja.zipcode       AS address_zipcode
FROM public.jobs j
LEFT JOIN public.providers pr ON pr.id = j.provider_id
LEFT JOIN public.job_addresses ja ON ja.job_id = j.id
WHERE j.client_id = auth.uid();
