-- Corrige o trigger de notificações ao mudar status do job.
-- Substitui qualquer trigger existente que gerava texto cru como "seu job mudou para accepted".

CREATE OR REPLACE FUNCTION public.notify_job_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_client_title  text;
  v_client_body   text;
  v_provider_title text;
  v_provider_body  text;
  v_provider_user_id uuid;
BEGIN
  -- Só dispara quando status mudar
  IF OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  -- Monta mensagens humanizadas por status
  CASE NEW.status
    WHEN 'accepted' THEN
      v_client_title   := 'Pagamento confirmado!';
      v_client_body    := 'Seu serviço foi confirmado. O prestador já está ciente e pode entrar em contato.';
      v_provider_title := 'Novo serviço confirmado!';
      v_provider_body  := 'O cliente confirmou o pagamento. Combine os detalhes pelo chat.';
    WHEN 'on_the_way' THEN
      v_client_title   := 'Prestador a caminho!';
      v_client_body    := 'Seu prestador está se deslocando até você. Fique atento!';
      v_provider_title := NULL; -- sem notif para prestador neste status
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
      RETURN NEW; -- outros status: sem notificação
  END CASE;

  -- Busca user_id do prestador
  IF NEW.provider_id IS NOT NULL THEN
    SELECT user_id INTO v_provider_user_id
    FROM public.providers
    WHERE id = NEW.provider_id;
  END IF;

  -- Insere notificação para o cliente
  IF NEW.client_id IS NOT NULL AND v_client_title IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      NEW.client_id,
      CASE NEW.status
        WHEN 'accepted'            THEN 'payment_confirmed'
        WHEN 'completed'           THEN 'job_completed'
        WHEN 'cancelled_by_client' THEN 'job_cancelled'
        WHEN 'cancelled_by_provider' THEN 'job_cancelled'
        WHEN 'dispute'             THEN 'dispute_opened'
        ELSE 'job_status'
      END,
      v_client_title,
      v_client_body,
      jsonb_build_object('job_id', NEW.id, 'status', NEW.status)
    );
  END IF;

  -- Insere notificação para o prestador
  IF v_provider_user_id IS NOT NULL AND v_provider_title IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      v_provider_user_id,
      CASE NEW.status
        WHEN 'accepted'            THEN 'payment_received'
        WHEN 'completed'           THEN 'job_completed'
        WHEN 'cancelled_by_client' THEN 'job_cancelled'
        WHEN 'cancelled_by_provider' THEN 'job_cancelled'
        WHEN 'dispute'             THEN 'dispute_opened'
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

-- Remove qualquer trigger antigo com nome diferente que possa estar gerando texto cru
DROP TRIGGER IF EXISTS trg_notify_job_status ON public.jobs;
DROP TRIGGER IF EXISTS notify_job_status_change ON public.jobs;
DROP TRIGGER IF EXISTS trg_job_status_notification ON public.jobs;
DROP TRIGGER IF EXISTS job_status_changed ON public.jobs;
DROP TRIGGER IF EXISTS on_job_status_change ON public.jobs;

-- Cria o trigger correto
CREATE TRIGGER trg_notify_job_status
  AFTER UPDATE OF status ON public.jobs
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_job_status_change();
