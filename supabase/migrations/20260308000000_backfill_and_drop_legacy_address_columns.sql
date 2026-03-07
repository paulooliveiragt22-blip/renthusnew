-- Backfill job_addresses + remove colunas legadas de endereço da tabela jobs.
--
-- Contexto:
--   A tabela jobs tinha: address_street, address_number, address_district,
--   address_state, address_zip_code como colunas legadas.
--   A função create_job já insere apenas em job_addresses desde a refatoração.
--   Porém jobs criados antes disso podem ter dados nas colunas legadas mas
--   sem entrada em job_addresses.
--
-- PASSO 1: Backfill — popula job_addresses com dados legados dos jobs que ainda
--          não têm entrada nessa tabela. Inclui jobs em qualquer status.

INSERT INTO public.job_addresses (job_id, street, number, district, city, state, zipcode)
SELECT
  j.id,
  j.address_street,
  j.address_number,
  j.address_district,
  j.city,
  j.address_state,
  j.address_zip_code
FROM public.jobs j
WHERE NOT EXISTS (
  SELECT 1 FROM public.job_addresses ja WHERE ja.job_id = j.id
)
  AND (
    j.address_street   IS NOT NULL OR
    j.address_district IS NOT NULL OR
    j.city             IS NOT NULL
  );

DO $$
DECLARE v_backfilled INT;
BEGIN
  GET DIAGNOSTICS v_backfilled = ROW_COUNT;
  RAISE NOTICE 'PASSO 1: % job_addresses inseridos (backfill de colunas legadas).', v_backfilled;
END;
$$;

-- PASSO 2: Recria v_admin_jobs_stalled usando LEFT JOIN em job_addresses
--          em vez de ler as colunas legadas diretamente de jobs.

CREATE OR REPLACE VIEW public.v_admin_jobs_stalled AS
SELECT
  j.id,
  j.client_id,
  j.provider_id,
  j.service_type_id,
  j.title,
  j.description,
  j.service_keyword,
  j.service_detected,
  j.pricing_model,
  j.price,
  j.amount_provider         AS provider_amount,
  j.payment_method,
  j.payment_method_fee,
  j.payment_fixed_fee,
  j.platform_fee,
  j.scheduled_at,
  ja.street                 AS address_street,
  ja.number                 AS address_number,
  ja.district               AS address_district,
  j.city,
  ja.state                  AS address_state,
  ja.zipcode                AS address_zip_code,
  j.status,
  j.payout_delay_hours,
  j.hold_until,
  j.paid_at,
  j.payment_released_at,
  j.is_disputed,
  j.dispute_opened_at,
  j.created_at,
  j.category_id,
  j.distance_km,
  j.daily_quantity,
  j.budget_value,
  j.client_budget,
  j.client_budget_type,
  j.daily_rate,
  j.daily_total,
  j.execution_overdue,
  j.execution_overdue_at,
  j.cancelled_at,
  j.job_type,
  j.payment_status,
  j.deleted_at,
  j.updated_at,
  j.cancel_reason,
  j.dispute_open,
  j.dispute_opened_by,
  j.dispute_reason,
  j.job_code,
  j.is_private_job,
  j.private_provider_id,
  j.private_expires_at,
  j.original_job_id
FROM public.jobs j
LEFT JOIN public.job_addresses ja ON ja.job_id = j.id
WHERE j.status = ANY(ARRAY['accepted'::text, 'in_progress'::text])
  AND j.updated_at < (now() - INTERVAL '48 hours');

DO $$
BEGIN
  RAISE NOTICE 'PASSO 2: v_admin_jobs_stalled recriada com LEFT JOIN job_addresses.';
END;
$$;

-- PASSO 3: Remove as colunas legadas de endereço da tabela jobs.
--          jobs.city NÃO é removido — é campo ativo usado para filtragem por cidade.

ALTER TABLE public.jobs
  DROP COLUMN IF EXISTS address_street,
  DROP COLUMN IF EXISTS address_number,
  DROP COLUMN IF EXISTS address_district,
  DROP COLUMN IF EXISTS address_state,
  DROP COLUMN IF EXISTS address_zip_code;

DO $$
DECLARE cnt INT;
BEGIN
  SELECT COUNT(*) INTO cnt
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name   = 'jobs'
    AND column_name  IN ('address_street','address_number','address_district','address_state','address_zip_code');

  IF cnt = 0 THEN
    RAISE NOTICE 'PASSO 3: 5 colunas legadas removidas de jobs. jobs.city mantida.';
  ELSE
    RAISE WARNING 'PASSO 3: ainda restam % colunas legadas em jobs!', cnt;
  END IF;
END;
$$;

-- PASSO 4: Confirma contagem final
DO $$
DECLARE
  v_total_jobs        INT;
  v_total_addresses   INT;
  v_jobs_no_address   INT;
BEGIN
  SELECT COUNT(*) INTO v_total_jobs      FROM public.jobs;
  SELECT COUNT(*) INTO v_total_addresses FROM public.job_addresses;
  SELECT COUNT(*) INTO v_jobs_no_address
  FROM public.jobs j
  WHERE NOT EXISTS (SELECT 1 FROM public.job_addresses ja WHERE ja.job_id = j.id);

  RAISE NOTICE 'RESUMO FINAL: total_jobs=% total_addresses=% jobs_sem_address=%',
    v_total_jobs, v_total_addresses, v_jobs_no_address;
END;
$$;
