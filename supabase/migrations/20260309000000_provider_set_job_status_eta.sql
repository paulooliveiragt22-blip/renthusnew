-- Recria provider_set_job_status adicionando suporte a p_eta_minutes.
-- Quando newStatus = 'on_the_way', salva o tempo estimado de chegada em jobs.eta_minutes.
--
-- Também atualiza notify_job_status_change para:
--   - Incluir eta_minutes na mensagem do cliente quando on_the_way
--   - Incluir eta_minutes no campo data do JSONB da notificação

-- ============================================================
-- 1. Recria provider_set_job_status com p_eta_minutes
-- ============================================================

CREATE OR REPLACE FUNCTION public.provider_set_job_status(
  p_job_id       UUID,
  p_new_status   TEXT,
  p_eta_minutes  INT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_provider_id UUID;
BEGIN
  SELECT p.id INTO v_provider_id
  FROM public.providers p
  WHERE p.user_id = auth.uid();

  IF v_provider_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não é um prestador cadastrado.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.jobs j
    WHERE j.id = p_job_id AND j.provider_id = v_provider_id
  ) THEN
    RAISE EXCEPTION 'Job não encontrado ou não pertence a este prestador.';
  END IF;

  UPDATE public.jobs
  SET
    status      = p_new_status,
    eta_minutes = CASE
                    WHEN p_new_status = 'on_the_way' AND p_eta_minutes IS NOT NULL
                      THEN p_eta_minutes
                    ELSE eta_minutes
                  END,
    updated_at  = now()
  WHERE id = p_job_id;
END;
$$;

DO $$
BEGIN
  RAISE NOTICE 'provider_set_job_status recriada com suporte a p_eta_minutes.';
END;
$$;

-- ============================================================
-- 2. Atualiza notify_job_status_change: ETA no corpo + dados
-- ============================================================

CREATE OR REPLACE FUNCTION public.notify_job_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_client_title   text;
  v_client_body    text;
  v_provider_title text;
  v_provider_body  text;
  v_provider_user_id uuid;
  v_eta_suffix     text;
BEGIN
  IF OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  CASE NEW.status
    WHEN 'accepted' THEN
      v_client_title   := 'Pagamento confirmado!';
      v_client_body    := 'Seu serviço foi confirmado. O prestador já está ciente e pode entrar em contato.';
      v_provider_title := 'Novo serviço confirmado!';
      v_provider_body  := 'O cliente confirmou o pagamento. Combine os detalhes pelo chat.';

    WHEN 'on_the_way' THEN
      v_eta_suffix := CASE
        WHEN NEW.eta_minutes IS NOT NULL
          THEN ' Previsão de chegada: ~' || NEW.eta_minutes || ' min.'
        ELSE ' Fique atento!'
      END;
      v_client_title   := 'Prestador a caminho!';
      v_client_body    := 'Seu prestador está se deslocando até você.' || v_eta_suffix;
      v_provider_title := NULL;
      v_provider_body  := NULL;

    WHEN 'in_progress' THEN
      v_client_title   := 'Serviço em andamento';
      v_client_body    := 'O prestador iniciou o serviço. Acompanhe pelo app.';
      v_provider_title := NULL;
      v_provider_body  := NULL;

    WHEN 'completed' THEN
      v_client_title   := 'Serviço concluído!';
      v_client_body    := 'O serviço foi finalizado. Avalie o prestador e deixe sua opinião.';
      v_provider_title := 'Serviço marcado como concluído';
      v_provider_body  := 'O serviço foi marcado como concluído pelo app. Obrigado!';

    WHEN 'cancelled_by_client' THEN
      v_client_title   := 'Pedido cancelado';
      v_client_body    := 'Seu pedido foi cancelado. Se houve pagamento, o estorno será processado.';
      v_provider_title := 'Pedido cancelado pelo cliente';
      v_provider_body  := 'O cliente cancelou o pedido. Nenhuma ação necessária.';

    WHEN 'cancelled_by_provider' THEN
      v_client_title   := 'Prestador cancelou o pedido';
      v_client_body    := 'O prestador precisou cancelar. Você pode escolher outro profissional.';
      v_provider_title := 'Pedido cancelado';
      v_provider_body  := 'O pedido foi cancelado.';

    WHEN 'dispute' THEN
      v_client_title   := 'Reclamação em análise';
      v_client_body    := 'Sua reclamação foi registrada e está sendo analisada.';
      v_provider_title := 'Reclamação aberta';
      v_provider_body  := 'O cliente abriu uma reclamação. Entre em contato pelo chat para resolver.';

    ELSE
      RETURN NEW;
  END CASE;

  IF NEW.provider_id IS NOT NULL THEN
    SELECT user_id INTO v_provider_user_id
    FROM public.providers
    WHERE id = NEW.provider_id;
  END IF;

  IF NEW.client_id IS NOT NULL AND v_client_title IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      NEW.client_id,
      CASE NEW.status
        WHEN 'accepted'              THEN 'payment_confirmed'
        WHEN 'completed'             THEN 'job_completed'
        WHEN 'cancelled_by_client'   THEN 'job_cancelled'
        WHEN 'cancelled_by_provider' THEN 'job_cancelled'
        WHEN 'dispute'               THEN 'dispute_opened'
        ELSE 'job_status'
      END,
      v_client_title,
      v_client_body,
      jsonb_build_object(
        'job_id',      NEW.id,
        'status',      NEW.status,
        'eta_minutes', NEW.eta_minutes
      )
    );
  END IF;

  IF v_provider_user_id IS NOT NULL AND v_provider_title IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      v_provider_user_id,
      CASE NEW.status
        WHEN 'accepted'              THEN 'payment_received'
        WHEN 'completed'             THEN 'job_completed'
        WHEN 'cancelled_by_client'   THEN 'job_cancelled'
        WHEN 'cancelled_by_provider' THEN 'job_cancelled'
        WHEN 'dispute'               THEN 'dispute_opened'
        ELSE 'job_status'
      END,
      v_provider_title,
      v_provider_body,
      jsonb_build_object('job_id', NEW.id, 'status', NEW.status)
    );
  END IF;

  RETURN NEW;
END;
$$;

DO $$
BEGIN
  RAISE NOTICE 'notify_job_status_change atualizada: on_the_way inclui ETA no corpo e no data JSONB.';
END;
$$;
