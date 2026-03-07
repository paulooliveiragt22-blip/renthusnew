-- Corrige set_user_avatar_url:
--   1. Provider WHERE: user_id = v_uid (era id = v_uid — bug)
--   2. Permite p_avatar_url NULL/vazio para remover foto
--   3. RETURN QUERY do provider também usa user_id = v_uid

CREATE OR REPLACE FUNCTION public.set_user_avatar_url(
  p_role       TEXT,
  p_avatar_url TEXT DEFAULT NULL
)
RETURNS TABLE(role text, avatar_url text, updated_at timestamp with time zone)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_url text := NULLIF(TRIM(COALESCE(p_avatar_url, '')), '');
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_role NOT IN ('client', 'provider') THEN
    RAISE EXCEPTION 'Invalid role. Use client or provider.';
  END IF;

  IF p_role = 'client' THEN
    UPDATE public.clients
       SET avatar_url = v_url,
           updated_at = now()
     WHERE id = v_uid;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Client profile not found for this user';
    END IF;

    RETURN QUERY
    SELECT 'client'::text, c.avatar_url, c.updated_at
      FROM public.clients c
     WHERE c.id = v_uid;

  ELSE
    -- providers.user_id references auth.users.id (NOT providers.id)
    UPDATE public.providers
       SET avatar_url = v_url,
           updated_at = now()
     WHERE user_id = v_uid;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Provider profile not found for this user';
    END IF;

    RETURN QUERY
    SELECT 'provider'::text, p.avatar_url, p.updated_at
      FROM public.providers p
     WHERE p.user_id = v_uid;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_user_avatar_url(TEXT, TEXT) TO authenticated;

DO $$
BEGIN
  RAISE NOTICE 'set_user_avatar_url: WHERE user_id corrigido p/ provider; NULL aceito para remover foto.';
END;
$$;
