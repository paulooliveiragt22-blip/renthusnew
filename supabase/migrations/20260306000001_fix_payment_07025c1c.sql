-- One-time fix: marca o payment 07025c1c-8810-462e-ac29-ba9db9a9490d como paid.
-- O trigger apply_payment_paid_effects vai propagar para jobs automaticamente.
DO $$
DECLARE
  v_payment RECORD;
BEGIN
  SELECT id, job_id, status, provider_id INTO v_payment
  FROM public.payments
  WHERE id = '07025c1c-8810-462e-ac29-ba9db9a9490d';

  IF v_payment IS NULL THEN
    RAISE NOTICE 'Payment não encontrado';
    RETURN;
  END IF;

  RAISE NOTICE 'Payment encontrado: job_id=%, status=%', v_payment.job_id, v_payment.status;

  UPDATE public.payments
  SET
    status     = 'paid',
    paid_at    = now(),
    updated_at = now()
  WHERE id = '07025c1c-8810-462e-ac29-ba9db9a9490d'
    AND status <> 'paid';

  RAISE NOTICE 'Payment atualizado. Trigger deve ter propagado para jobs.';
END;
$$;
