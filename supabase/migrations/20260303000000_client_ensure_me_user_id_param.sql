-- Update rpc_client_ensure_me to accept optional p_user_id fallback.
-- auth.uid() can be null immediately after signUp when email confirmation is
-- required in production (no session returned). The p_user_id param lets
-- Flutter pass user.id explicitly so the SECURITY DEFINER RPC can insert
-- without relying on auth.uid().
-- Security: if both auth.uid() and p_user_id are set, they must match.

CREATE OR REPLACE FUNCTION public.rpc_client_ensure_me(
  p_full_name text DEFAULT NULL,
  p_phone     text DEFAULT NULL,
  p_user_id   uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid;
BEGIN
  v_uid := COALESCE(auth.uid(), p_user_id);

  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Prevent impersonation: if both are set, they must match
  IF auth.uid() IS NOT NULL AND p_user_id IS NOT NULL AND auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'Unauthorized: user_id mismatch';
  END IF;

  INSERT INTO clients (id, full_name, phone)
  VALUES (v_uid, COALESCE(p_full_name, ''), COALESCE(p_phone, ''))
  ON CONFLICT (id) DO UPDATE
    SET full_name  = COALESCE(NULLIF(EXCLUDED.full_name, ''), clients.full_name),
        phone      = COALESCE(NULLIF(EXCLUDED.phone, ''),     clients.phone),
        updated_at = NOW();
END;
$$;
