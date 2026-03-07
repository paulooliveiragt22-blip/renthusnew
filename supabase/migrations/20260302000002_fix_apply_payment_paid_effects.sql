-- Corrige o trigger apply_payment_paid_effects:
-- Quando a quote já está aceita (is_accepted = true), o UPDATE dispara um trigger
-- de proteção em job_quotes e causa erro. Adicionamos a condição
-- "AND q.is_accepted = false" para evitar o update desnecessário.
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

  -- 2) Aceita a quote — só se ainda não estiver aceita (evita trigger de proteção)
  UPDATE public.job_quotes q
  SET is_accepted = true
  WHERE q.job_id      = new.job_id
    AND q.provider_id = new.provider_id
    AND q.is_accepted = false;

  -- 3) Aprova candidato do provider selecionado
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
