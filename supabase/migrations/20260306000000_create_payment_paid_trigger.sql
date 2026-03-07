-- Cria o trigger apply_payment_paid_effects na tabela payments.
-- A função já existe (criada em 20260302000002_fix_apply_payment_paid_effects.sql)
-- mas o CREATE TRIGGER nunca foi adicionado às migrations.

-- Remove trigger anterior se existir (idempotente)
DROP TRIGGER IF EXISTS apply_payment_paid_effects ON public.payments;

-- Recria a função garantindo a versão mais recente
CREATE OR REPLACE FUNCTION public.apply_payment_paid_effects()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Só roda quando status mudar para 'paid'
  IF (tg_op = 'UPDATE') THEN
    IF (old.status = new.status) THEN
      RETURN new;
    END IF;
  END IF;

  IF (new.status <> 'paid') THEN
    RETURN new;
  END IF;

  -- 1) Atualiza JOB com dados do pagamento
  UPDATE public.jobs j
  SET
    payment_status  = 'paid',
    price           = new.amount_total,
    amount_provider = new.amount_provider,
    provider_id     = new.provider_id,
    paid_at         = COALESCE(new.paid_at, now()),
    payment_method  = new.payment_method,
    status          = 'accepted'
  WHERE j.id = new.job_id;

  -- 2) Aceita a quote (evita trigger de proteção com AND is_accepted = false)
  UPDATE public.job_quotes q
  SET is_accepted = true
  WHERE q.job_id      = new.job_id
    AND q.provider_id = new.provider_id
    AND q.is_accepted = false;

  -- 3) Aprova candidato selecionado
  UPDATE public.job_candidates c
  SET
    approved        = true,
    analyzed        = true,
    decision_status = 'approved',
    client_status   = 'approved'
  WHERE c.job_id      = new.job_id
    AND c.provider_id = new.provider_id;

  -- 4) Rejeita demais candidatos
  UPDATE public.job_candidates c
  SET
    approved        = false,
    analyzed        = true,
    decision_status = 'rejected',
    client_status   = 'rejected'
  WHERE c.job_id      = new.job_id
    AND c.provider_id <> new.provider_id;

  RETURN new;
END;
$$;

-- Cria o trigger AFTER UPDATE (e INSERT para sandbox auto-approve)
CREATE TRIGGER apply_payment_paid_effects
  AFTER INSERT OR UPDATE ON public.payments
  FOR EACH ROW
  EXECUTE FUNCTION public.apply_payment_paid_effects();
