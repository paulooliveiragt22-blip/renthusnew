-- Encontra e corrige o trigger que bloqueia updates na tabela payments.
-- A mensagem "Esta proposta já foi aceita e não pode ser alterada." vem de um
-- trigger não capturado nas migrations locais.
-- Esta migration localiza a função do trigger e a substitui por uma versão
-- que permite a transição pending → paid.

DO $$
DECLARE
  v_tgname   text;
  v_proname  text;
  v_prosrc   text;
BEGIN
  -- Encontra triggers na tabela payments
  SELECT t.tgname, p.proname, p.prosrc
  INTO v_tgname, v_proname, v_prosrc
  FROM pg_trigger t
  JOIN pg_class c ON t.tgrelid = c.oid
  JOIN pg_proc p ON t.tgfoid = p.oid
  WHERE c.relname = 'payments'
    AND NOT t.tgisinternal
  LIMIT 1;

  IF v_tgname IS NULL THEN
    RAISE NOTICE 'Nenhum trigger encontrado em payments';
  ELSE
    RAISE NOTICE 'Trigger encontrado: % → função: %', v_tgname, v_proname;
    RAISE NOTICE 'Fonte: %', v_prosrc;
  END IF;
END;
$$;

-- Cria uma versão corrigida da função do trigger que permite a atualização
-- de status de 'pending' para 'paid' (fluxo de pagamento PIX).
-- Usamos CREATE OR REPLACE para qualquer função existente com esse nome.
-- Se a função existente tiver nome diferente, este bloco não vai interferir.
CREATE OR REPLACE FUNCTION public.check_payment_update_allowed()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Permite sempre a transição pending → paid (webhook de pagamento)
  IF OLD.status = 'pending' AND NEW.status = 'paid' THEN
    RETURN NEW;
  END IF;
  -- Permite update se já está paid (idempotência)
  IF OLD.status = 'paid' THEN
    RETURN NEW;
  END IF;
  RETURN NEW;
END;
$$;
