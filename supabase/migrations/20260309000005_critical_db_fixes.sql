-- ============================================================
-- CRITICAL DB FIXES
-- 1. mark_messages_read RPC (is_read não existe → read_by_client/provider)
-- 2. get_unread_messages_count RPC (substituí 2 queries por 1)
-- 3. conversations_with_last_message VIEW (nomes, fotos, unread_count real)
-- 4. Fix become_candidate (usava auth.uid() como providers.id — bug)
-- 5. Fix jobs status CHECK (adiciona cancelled, execution_overdue, etc.)
-- 6. Adiciona job_id em reviews + índice
-- 7. Adiciona file_url, file_name em messages (Flutter envia mas coluna ausente)
-- 8. release_pending_payments() — versão correta para jobs (não bookings)
-- 9. Índices de performance em tabelas críticas
-- ============================================================


-- ============================================================
-- 1. mark_messages_read
-- ============================================================
CREATE OR REPLACE FUNCTION public.mark_messages_read(
  p_conversation_id UUID,
  p_role            TEXT  -- 'client' ou 'provider'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_role = 'client' THEN
    UPDATE public.messages
       SET read_by_client = true
     WHERE conversation_id = p_conversation_id
       AND read_by_client  = false
       AND sender_id       != v_uid
       AND deleted_at      IS NULL;

  ELSIF p_role = 'provider' THEN
    UPDATE public.messages
       SET read_by_provider = true
     WHERE conversation_id  = p_conversation_id
       AND read_by_provider = false
       AND sender_id        != v_uid
       AND deleted_at       IS NULL;

  ELSE
    RAISE EXCEPTION 'Invalid role. Use client or provider.';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_messages_read(UUID, TEXT) TO authenticated;


-- ============================================================
-- 2. get_unread_messages_count (1 query, não 2)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_unread_messages_count()
RETURNS int
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (
      SELECT SUM(
        CASE
          WHEN c.client_id = auth.uid() THEN
            (SELECT COUNT(*) FROM public.messages m
              WHERE m.conversation_id = c.id
                AND m.sender_id       != auth.uid()
                AND m.read_by_client  = false
                AND m.deleted_at      IS NULL)
          ELSE
            (SELECT COUNT(*) FROM public.messages m
              WHERE m.conversation_id  = c.id
                AND m.sender_id        != auth.uid()
                AND m.read_by_provider = false
                AND m.deleted_at       IS NULL)
        END
      )::int
      FROM public.conversations c
      WHERE c.client_id = auth.uid()
         OR c.provider_id IN (
              SELECT id FROM public.providers WHERE user_id = auth.uid()
            )
    ),
    0
  );
$$;

GRANT EXECUTE ON FUNCTION public.get_unread_messages_count() TO authenticated;


-- ============================================================
-- 3. conversations_with_last_message VIEW
--    Expõe: nomes, fotos, última mensagem, unread_count, is_active
-- ============================================================
DROP VIEW IF EXISTS public.conversations_with_last_message;

CREATE VIEW public.conversations_with_last_message
WITH (security_invoker = on)
AS
SELECT
  c.id,
  c.job_id,
  c.client_id,
  c.provider_id,
  c.title,
  c.status,
  -- is_active: conversa aberta enquanto status = 'open'
  (c.status = 'open')                              AS is_active,
  c.created_at,
  c.last_message_at,
  c.updated_at,

  -- última mensagem (via LATERAL para eficiência com índice)
  lm.content                                       AS last_message,
  lm.content                                       AS last_message_content,
  lm.created_at                                    AS last_message_created_at,

  -- dados do cliente
  cl.full_name                                     AS client_name,
  cl.avatar_url                                    AS client_photo_url,

  -- dados do prestador
  pv.full_name                                     AS provider_name,
  pv.avatar_url                                    AS provider_photo_url,

  -- título do job
  j.title                                          AS job_title,

  -- unread_count calculado para quem está consultando
  CASE
    WHEN c.client_id = auth.uid() THEN
      (SELECT COUNT(*)::int
         FROM public.messages m
        WHERE m.conversation_id = c.id
          AND m.sender_id       != auth.uid()
          AND m.read_by_client  = false
          AND m.deleted_at      IS NULL)
    ELSE
      (SELECT COUNT(*)::int
         FROM public.messages m
        WHERE m.conversation_id  = c.id
          AND m.sender_id        != auth.uid()
          AND m.read_by_provider = false
          AND m.deleted_at       IS NULL)
  END                                              AS unread_count

FROM public.conversations c
LEFT JOIN public.clients   cl ON cl.id = c.client_id
LEFT JOIN public.providers pv ON pv.id = c.provider_id
LEFT JOIN public.jobs       j ON  j.id = c.job_id
LEFT JOIN LATERAL (
  SELECT content, created_at
    FROM public.messages
   WHERE conversation_id = c.id
     AND deleted_at      IS NULL
   ORDER BY created_at DESC
   LIMIT 1
) lm ON true;

GRANT SELECT ON public.conversations_with_last_message TO authenticated;


-- ============================================================
-- 4. Fix become_candidate
--    Era: provider_id = auth.uid()  → ERRADO (auth.uid = user_id, não providers.id)
--    Fix: busca providers.id WHERE user_id = auth.uid()
-- ============================================================
CREATE OR REPLACE FUNCTION public.become_candidate(p_job_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_provider_id uuid;
  v_status      text;
BEGIN
  -- Resolve o providers.id do usuário logado
  SELECT id INTO v_provider_id
    FROM public.providers
   WHERE user_id = auth.uid()
   LIMIT 1;

  IF v_provider_id IS NULL THEN
    RAISE EXCEPTION 'Perfil de prestador não encontrado para este usuário';
  END IF;

  -- Job precisa existir e estar aguardando providers
  SELECT status INTO v_status
    FROM public.jobs
   WHERE id = p_job_id;

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Job não encontrado';
  END IF;

  IF v_status <> 'waiting_providers' THEN
    RAISE EXCEPTION 'Não é possível candidatar neste status: %', v_status;
  END IF;

  -- Evita candidatura duplicada
  IF EXISTS (
    SELECT 1 FROM public.job_candidates
     WHERE job_id = p_job_id AND provider_id = v_provider_id
  ) THEN
    RAISE EXCEPTION 'Você já é candidato neste job';
  END IF;

  INSERT INTO public.job_candidates (job_id, provider_id, created_at)
  VALUES (p_job_id, v_provider_id, now());
END;
$$;

GRANT EXECUTE ON FUNCTION public.become_candidate(uuid) TO authenticated;


-- ============================================================
-- 5. Fix jobs status CHECK
--    Adiciona: cancelled, execution_overdue, refunded, waiting_client
-- ============================================================
ALTER TABLE public.jobs
  DROP CONSTRAINT IF EXISTS jobs_status_check;

ALTER TABLE public.jobs
  ADD CONSTRAINT jobs_status_check
  CHECK (status = ANY (ARRAY[
    'waiting_providers',
    'waiting_client',
    'accepted',
    'on_the_way',
    'in_progress',
    'completed',
    'cancelled',
    'cancelled_by_client',
    'cancelled_by_provider',
    'dispute',
    'execution_overdue',
    'refunded'
  ])) NOT VALID;
-- NOT VALID: não revalida rows existentes (seguro para dados legados)


-- ============================================================
-- 6. Adiciona job_id em reviews + índice
-- ============================================================
ALTER TABLE public.reviews
  ADD COLUMN IF NOT EXISTS job_id uuid
    REFERENCES public.jobs(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_reviews_job_id
  ON public.reviews(job_id);


-- ============================================================
-- 7. Adiciona file_url, file_name em messages
--    (Flutter envia esses campos mas colunas não existiam)
-- ============================================================
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS file_url  text,
  ADD COLUMN IF NOT EXISTS file_name text;


-- ============================================================
-- 8. release_pending_payments() — versão correta (usa jobs, não bookings)
-- ============================================================
CREATE OR REPLACE FUNCTION public.release_pending_payments()
RETURNS int   -- retorna quantidade de jobs liberados
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int;
BEGIN
  UPDATE public.jobs
     SET payment_released_at = now(),
         updated_at          = now()
   WHERE status              = 'completed'
     AND payment_status      = 'paid'
     AND payment_released_at IS NULL
     AND paid_at             IS NOT NULL
     AND paid_at + (COALESCE(payout_delay_hours, 24) * INTERVAL '1 hour') <= now()
     AND deleted_at          IS NULL
     AND NOT EXISTS (
           SELECT 1 FROM public.disputes d
            WHERE d.job_id = jobs.id
              AND d.status = 'open'
         );

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- Agendar via pg_cron (rodar a cada hora):
-- SELECT cron.schedule('release-payments', '0 * * * *', 'SELECT release_pending_payments()');

GRANT EXECUTE ON FUNCTION public.release_pending_payments() TO service_role;


-- ============================================================
-- 9. Índices de performance
-- ============================================================

-- messages: stream por conversa + unread count
CREATE INDEX IF NOT EXISTS idx_messages_conversation_created
  ON public.messages(conversation_id, created_at ASC)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_messages_unread_client
  ON public.messages(conversation_id, read_by_client)
  WHERE read_by_client = false AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_messages_unread_provider
  ON public.messages(conversation_id, read_by_provider)
  WHERE read_by_provider = false AND deleted_at IS NULL;

-- notifications: badge + listagem
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications(user_id, created_at DESC)
  WHERE read = false AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON public.notifications(user_id, created_at DESC)
  WHERE deleted_at IS NULL;

-- jobs: tela "Meus Jobs" e "Meus Pedidos"
CREATE INDEX IF NOT EXISTS idx_jobs_provider_status
  ON public.jobs(provider_id, status)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_jobs_client_status
  ON public.jobs(client_id, status)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_jobs_payment_release
  ON public.jobs(payment_released_at, status, payment_status)
  WHERE deleted_at IS NULL AND payment_released_at IS NOT NULL;

-- job_candidates
CREATE INDEX IF NOT EXISTS idx_job_candidates_job_provider
  ON public.job_candidates(job_id, provider_id);

CREATE INDEX IF NOT EXISTS idx_job_candidates_provider
  ON public.job_candidates(provider_id);

-- conversations: lista de chats
CREATE INDEX IF NOT EXISTS idx_conversations_client
  ON public.conversations(client_id, last_message_at DESC);

CREATE INDEX IF NOT EXISTS idx_conversations_provider
  ON public.conversations(provider_id, last_message_at DESC);

-- job_payments
CREATE INDEX IF NOT EXISTS idx_job_payments_job
  ON public.job_payments(job_id);


DO $$
BEGIN
  RAISE NOTICE 'mark_messages_read: RPC criado (read_by_client/provider).';
  RAISE NOTICE 'get_unread_messages_count: RPC criado (1 query).';
  RAISE NOTICE 'conversations_with_last_message: VIEW criada com unread_count real.';
  RAISE NOTICE 'become_candidate: corrigido para usar providers.id via user_id.';
  RAISE NOTICE 'jobs.status CHECK: adicionados cancelled, execution_overdue, refunded, waiting_client.';
  RAISE NOTICE 'reviews.job_id: coluna adicionada.';
  RAISE NOTICE 'messages: file_url, file_name adicionados.';
  RAISE NOTICE 'release_pending_payments: função criada para jobs (não bookings).';
  RAISE NOTICE 'Índices de performance: criados em messages, notifications, jobs, conversations.';
END;
$$;
