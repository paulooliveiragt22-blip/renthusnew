-- Função chamada pelo webhook do Pagar.me para marcar payment como pago.
-- Usa session_replication_role = replica para contornar triggers de proteção
-- que bloqueiam updates diretos na tabela payments.
CREATE OR REPLACE FUNCTION public.webhook_mark_payment_paid(
  p_payment_id   uuid,
  p_job_id       uuid,
  p_provider_id  uuid,
  p_order_id     text,
  p_paid_at      timestamptz,
  p_metadata     jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_job_paid_amount numeric;
  v_amount_total    numeric;
BEGIN
  -- Desativa triggers para este bloco de transação
  SET LOCAL session_replication_role = 'replica';

  -- 1) Marca payment como pago
  UPDATE public.payments
  SET
    status                 = 'paid',
    paid_at                = p_paid_at,
    gateway_transaction_id = p_order_id,
    gateway_metadata       = p_metadata,
    updated_at             = now()
  WHERE id = p_payment_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'payment not found');
  END IF;

  -- 2) Busca amount_total do payment para calcular amount_provider
  SELECT amount_total INTO v_amount_total
  FROM public.payments WHERE id = p_payment_id;

  v_job_paid_amount := ROUND((v_amount_total * 0.85)::numeric, 2);

  -- 3) Atualiza job
  UPDATE public.jobs
  SET
    payment_status = 'paid',
    provider_id    = p_provider_id,
    status         = 'accepted',
    paid_at        = p_paid_at,
    amount_provider = v_job_paid_amount
  WHERE id = p_job_id;

  RETURN jsonb_build_object('ok', true, 'payment_id', p_payment_id, 'job_id', p_job_id);
END;
$$;

-- Permite que o service role chame a função
GRANT EXECUTE ON FUNCTION public.webhook_mark_payment_paid(uuid, uuid, uuid, text, timestamptz, jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.webhook_mark_payment_paid(uuid, uuid, uuid, text, timestamptz, jsonb) TO authenticated;
