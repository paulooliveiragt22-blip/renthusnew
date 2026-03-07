-- ============================================================
-- MIGRACAO: resumo financeiro do prestador
-- Objetivo:
--  - Expor valores liberados para saque
--  - Expor valores pagos ainda pendentes (execucao/liberacao)
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_provider_financial_summary()
RETURNS TABLE (
  provider_id UUID,
  released_total NUMERIC,
  pending_total NUMERIC,
  pending_execution_total NUMERIC,
  pending_release_total NUMERIC,
  month_released_total NUMERIC,
  released_jobs_count BIGINT,
  pending_jobs_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_provider_id UUID;
BEGIN
  SELECT p.id
    INTO v_provider_id
    FROM public.providers p
   WHERE p.user_id = auth.uid()
   LIMIT 1;

  IF v_provider_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT
      j.id,
      COALESCE(j.amount_provider, 0)::NUMERIC AS amount_provider,
      j.status,
      j.payment_released_at,
      j.paid_at,
      j.payment_status,
      (
        j.paid_at IS NOT NULL
        OR LOWER(COALESCE(j.payment_status, '')) = 'paid'
        OR EXISTS (
          SELECT 1
            FROM public.job_payments jp
           WHERE jp.job_id = j.id
             AND LOWER(COALESCE(jp.status, '')) = 'paid'
        )
      ) AS is_paid
    FROM public.jobs j
    WHERE j.provider_id = v_provider_id
      AND COALESCE(j.amount_provider, 0) > 0
      AND j.deleted_at IS NULL
      AND COALESCE(j.status, '') <> 'cancelled'
  )
  SELECT
    v_provider_id AS provider_id,
    COALESCE(SUM(CASE
      WHEN b.payment_released_at IS NOT NULL THEN b.amount_provider
      ELSE 0
    END), 0) AS released_total,
    COALESCE(SUM(CASE
      WHEN b.is_paid AND b.payment_released_at IS NULL THEN b.amount_provider
      ELSE 0
    END), 0) AS pending_total,
    COALESCE(SUM(CASE
      WHEN b.is_paid
       AND b.payment_released_at IS NULL
       AND COALESCE(b.status, '') <> 'completed'
      THEN b.amount_provider
      ELSE 0
    END), 0) AS pending_execution_total,
    COALESCE(SUM(CASE
      WHEN b.is_paid
       AND b.payment_released_at IS NULL
       AND b.status = 'completed'
      THEN b.amount_provider
      ELSE 0
    END), 0) AS pending_release_total,
    COALESCE(SUM(CASE
      WHEN b.payment_released_at >= date_trunc('month', now())
       AND b.payment_released_at < (date_trunc('month', now()) + INTERVAL '1 month')
      THEN b.amount_provider
      ELSE 0
    END), 0) AS month_released_total,
    COUNT(*) FILTER (WHERE b.payment_released_at IS NOT NULL) AS released_jobs_count,
    COUNT(*) FILTER (WHERE b.is_paid AND b.payment_released_at IS NULL) AS pending_jobs_count
  FROM base b;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_provider_financial_summary() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_provider_financial_released_jobs(
  p_limit INT DEFAULT 20
)
RETURNS TABLE (
  job_id UUID,
  title TEXT,
  amount NUMERIC,
  released_at TIMESTAMPTZ,
  status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_provider_id UUID;
  v_limit INT;
BEGIN
  SELECT p.id
    INTO v_provider_id
    FROM public.providers p
   WHERE p.user_id = auth.uid()
   LIMIT 1;

  IF v_provider_id IS NULL THEN
    RETURN;
  END IF;

  v_limit := GREATEST(1, LEAST(COALESCE(p_limit, 20), 100));

  RETURN QUERY
  SELECT
    j.id AS job_id,
    COALESCE(NULLIF(TRIM(j.title), ''), 'Servico') AS title,
    COALESCE(j.amount_provider, 0)::NUMERIC AS amount,
    j.payment_released_at AS released_at,
    j.status
  FROM public.jobs j
  WHERE j.provider_id = v_provider_id
    AND j.payment_released_at IS NOT NULL
    AND COALESCE(j.amount_provider, 0) > 0
    AND j.deleted_at IS NULL
    AND COALESCE(j.status, '') <> 'cancelled'
  ORDER BY j.payment_released_at DESC
  LIMIT v_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_provider_financial_released_jobs(INT) TO authenticated;
