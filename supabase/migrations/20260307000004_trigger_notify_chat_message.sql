-- Trigger para criar notificação (in-app) ao inserir mensagem em `messages`.
-- Resolve o problema: 4 funções de notificação de chat existiam mas nenhum trigger as chamava.
-- Esta abordagem cria uma função nova simples e direta.
--
-- Lógica:
--   sender_role = 'client'   → notifica o prestador (lookup providers.user_id)
--   sender_role = 'provider' → notifica o cliente   (client_id = user_id direto)
--   sender_role NULL/outro   → infere pelo sender_id comparando com conversations
--
-- Formato da notificação (compatível com providerMyJobs unread badge):
--   channel = 'app'
--   data = { type: 'chat_message', job_id: ..., conversation_id: ..., sender_role: ..., message_preview: ... }

CREATE OR REPLACE FUNCTION fn_notify_chat_message()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client_id     UUID;
  v_provider_id   UUID;  -- providers.id (not user_id)
  v_job_id        UUID;
  v_sender_role   TEXT;
  v_recipient_uid UUID;
BEGIN
  -- Busca informações da conversa
  SELECT c.client_id, c.provider_id, c.job_id
  INTO v_client_id, v_provider_id, v_job_id
  FROM public.conversations c
  WHERE c.id = NEW.conversation_id;

  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  v_sender_role := COALESCE(NEW.sender_role, '');

  -- Se sender_role não foi fornecido, infere pelo sender_id
  IF v_sender_role = '' THEN
    IF NEW.sender_id = v_client_id THEN
      v_sender_role := 'client';
    ELSE
      IF EXISTS (
        SELECT 1 FROM public.providers
        WHERE id = v_provider_id AND user_id = NEW.sender_id
      ) THEN
        v_sender_role := 'provider';
      END IF;
    END IF;
  END IF;

  -- Determina destinatário
  IF v_sender_role = 'client' THEN
    -- Prestador recebe: user_id via providers
    SELECT p.user_id INTO v_recipient_uid
    FROM public.providers p
    WHERE p.id = v_provider_id;
  ELSIF v_sender_role = 'provider' THEN
    -- Cliente recebe: client_id = user_id
    v_recipient_uid := v_client_id;
  ELSE
    -- Role desconhecido, não notifica
    RETURN NEW;
  END IF;

  IF v_recipient_uid IS NULL THEN
    RETURN NEW;
  END IF;

  -- Não notifica o próprio remetente (segurança extra)
  IF v_recipient_uid = NEW.sender_id THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.notifications (user_id, channel, type, data, read, created_at)
  VALUES (
    v_recipient_uid,
    'app',
    'chat_message',
    jsonb_build_object(
      'type',            'chat_message',
      'job_id',          v_job_id::text,
      'conversation_id', NEW.conversation_id::text,
      'sender_id',       NEW.sender_id::text,
      'sender_role',     v_sender_role,
      'message_preview', left(NEW.content, 120)
    ),
    false,
    now()
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_chat_message ON public.messages;

CREATE TRIGGER trg_notify_chat_message
AFTER INSERT ON public.messages
FOR EACH ROW
EXECUTE FUNCTION fn_notify_chat_message();

-- Confirma
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    WHERE c.relname = 'messages' AND t.tgname = 'trg_notify_chat_message'
  ) THEN
    RAISE NOTICE 'OK: trigger trg_notify_chat_message criado em messages.';
  ELSE
    RAISE WARNING 'FALHA: trigger trg_notify_chat_message NÃO encontrado.';
  END IF;
END;
$$;
