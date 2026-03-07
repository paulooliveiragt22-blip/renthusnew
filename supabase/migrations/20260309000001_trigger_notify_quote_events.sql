-- Notificações para eventos de proposta (quote) entre prestador e cliente.
--
-- Eventos criados:
--   1. trg_notify_new_candidate — prestador aceita slot do pedido (job_candidates INSERT)
--      → notifica o cliente: type = 'new_candidate'
--
--   2. trg_notify_new_quote — prestador envia proposta (job_quotes INSERT)
--      → notifica o cliente: type = 'new_quote'
--
-- Nota: quote_accepted → já coberto por notify_job_status_change quando status='accepted'
--         (provider recebe 'payment_received', client recebe 'payment_confirmed')
--       quote_rejected → não há fluxo explícito de rejeição; inativo até implementação.

-- ============================================================
-- 1. Notificação: prestador aceitou o slot do pedido (new_candidate)
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_notify_new_candidate()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_client_id   UUID;
  v_job_title   TEXT;
  v_job_id      UUID;
  v_provider_name TEXT;
BEGIN
  -- Só dispara em novos slots pendentes (não em re-inserts expirados)
  IF NEW.status <> 'pending' THEN
    RETURN NEW;
  END IF;

  v_job_id := NEW.job_id;

  SELECT j.client_id, COALESCE(j.title, 'seu serviço')
  INTO v_client_id, v_job_title
  FROM public.jobs j
  WHERE j.id = v_job_id;

  IF v_client_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(p.full_name, 'Um prestador')
  INTO v_provider_name
  FROM public.providers p
  WHERE p.id = NEW.provider_id;

  INSERT INTO public.notifications (user_id, channel, type, title, body, data, read, created_at)
  VALUES (
    v_client_id,
    'app',
    'new_candidate',
    'Prestador interessado!',
    v_provider_name || ' aceitou o pedido "' || v_job_title || '" e vai enviar um orçamento.',
    jsonb_build_object('job_id', v_job_id::text, 'provider_id', NEW.provider_id::text),
    false,
    now()
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_new_candidate ON public.job_candidates;

CREATE TRIGGER trg_notify_new_candidate
AFTER INSERT ON public.job_candidates
FOR EACH ROW
EXECUTE FUNCTION public.fn_notify_new_candidate();

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    WHERE c.relname = 'job_candidates' AND t.tgname = 'trg_notify_new_candidate'
  ) THEN
    RAISE NOTICE 'OK: trg_notify_new_candidate criado.';
  ELSE
    RAISE WARNING 'FALHA: trg_notify_new_candidate NÃO encontrado.';
  END IF;
END;
$$;

-- ============================================================
-- 2. Notificação: prestador enviou proposta (new_quote)
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_notify_new_quote()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_client_id     UUID;
  v_job_title     TEXT;
  v_provider_name TEXT;
  v_price_text    TEXT;
BEGIN
  SELECT j.client_id, COALESCE(j.title, 'seu serviço')
  INTO v_client_id, v_job_title
  FROM public.jobs j
  WHERE j.id = NEW.job_id;

  IF v_client_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(p.full_name, 'Um prestador')
  INTO v_provider_name
  FROM public.providers p
  WHERE p.id = NEW.provider_id;

  v_price_text := CASE
    WHEN NEW.approximate_price IS NOT NULL AND NEW.approximate_price > 0
      THEN ' Valor: R$ ' || to_char(NEW.approximate_price, 'FM999G999D00') || '.'
    ELSE ''
  END;

  INSERT INTO public.notifications (user_id, channel, type, title, body, data, read, created_at)
  VALUES (
    v_client_id,
    'app',
    'new_quote',
    'Nova proposta recebida!',
    v_provider_name || ' enviou um orçamento para "' || v_job_title || '".' || v_price_text || ' Acesse para ver os detalhes.',
    jsonb_build_object(
      'job_id',       NEW.job_id::text,
      'provider_id',  NEW.provider_id::text,
      'price',        NEW.approximate_price
    ),
    false,
    now()
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_new_quote ON public.job_quotes;

CREATE TRIGGER trg_notify_new_quote
AFTER INSERT ON public.job_quotes
FOR EACH ROW
EXECUTE FUNCTION public.fn_notify_new_quote();

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    WHERE c.relname = 'job_quotes' AND t.tgname = 'trg_notify_new_quote'
  ) THEN
    RAISE NOTICE 'OK: trg_notify_new_quote criado.';
  ELSE
    RAISE WARNING 'FALHA: trg_notify_new_quote NÃO encontrado.';
  END IF;
END;
$$;
