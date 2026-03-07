-- Atualiza v_provider_jobs_accepted:
--   Renomeia street/number/district → address_street/address_number/address_district
--   para ficar consistente com v_client_jobs.
--
-- Também adiciona campos de agendamento (scheduled_date, scheduled_start_time,
-- scheduled_end_time, has_flexible_schedule) e scheduled_at que o app usa.
--
-- O mascaramento por status é mantido:
--   completed → NULL para rua/número/bairro/zipcode/lat/lng
--   dispute   → endereço visível (regra confirmada)

-- DROP + CREATE necessário pois PostgreSQL não permite renomear colunas via CREATE OR REPLACE
DROP VIEW IF EXISTS public.v_provider_jobs_accepted;

CREATE VIEW public.v_provider_jobs_accepted AS
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
  j.amount_provider,
  j.price,
  j.daily_total,
  j.client_budget,
  j.payment_status,

  -- Endereço: mascarado em 'completed', visível nos demais status da view
  CASE WHEN j.status = 'completed' THEN NULL ELSE a.street   END AS address_street,
  CASE WHEN j.status = 'completed' THEN NULL ELSE a.number   END AS address_number,
  CASE WHEN j.status = 'completed' THEN NULL ELSE a.district END AS address_district,
  a.city,
  a.state,
  CASE WHEN j.status = 'completed' THEN NULL ELSE a.zipcode  END AS address_zipcode,
  CASE WHEN j.status = 'completed' THEN NULL ELSE a.lat      END AS lat,
  CASE WHEN j.status = 'completed' THEN NULL ELSE a.lng      END AS lng,

  -- Agendamento
  j.scheduled_at,
  j.scheduled_date,
  j.scheduled_start_time,
  j.scheduled_end_time,
  j.has_flexible_schedule,

  j.created_at,
  j.updated_at,

  COALESCE((
    SELECT json_agg(
      json_build_object('url', p.url, 'thumb_url', p.thumb_url, 'created_at', p.created_at)
      ORDER BY p.created_at
    )
    FROM job_photos p
    WHERE p.job_id = j.id
  ), '[]'::json) AS photos,

  c.full_name  AS client_full_name,
  c.avatar_url AS client_avatar_url

FROM public.jobs j
JOIN public.job_addresses a ON a.job_id = j.id
LEFT JOIN public.clients c ON c.id = j.client_id

WHERE j.provider_id = auth.uid()
  AND j.status = ANY(ARRAY[
    'accepted'::text,
    'on_the_way'::text,
    'in_progress'::text,
    'completed'::text,
    'dispute'::text
  ]);

DO $$
BEGIN
  RAISE NOTICE 'v_provider_jobs_accepted recriada: street→address_street, agendamento adicionado.';
END;
$$;
