-- Recreate rpc_provider_ensure_me from scratch.
-- Previous attempt (20260302000005) was recorded in migration history but the
-- function body on the remote still contains the incorrect guard
-- RAISE EXCEPTION 'User already registered as client' that blocks provider
-- signup when the user already has a client record.
-- This migration forces a clean CREATE OR REPLACE to fix the remote state.

CREATE OR REPLACE FUNCTION public.rpc_provider_ensure_me(
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
  v_uid    uuid;
  v_exists boolean;
BEGIN
  v_uid := COALESCE(auth.uid(), p_user_id);

  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Prevent impersonation: if both are set, they must match
  IF auth.uid() IS NOT NULL AND p_user_id IS NOT NULL AND auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'Unauthorized: user_id mismatch';
  END IF;

  SELECT EXISTS(SELECT 1 FROM providers WHERE user_id = v_uid) INTO v_exists;

  IF NOT v_exists THEN
    INSERT INTO providers (user_id, full_name, phone)
    VALUES (v_uid, COALESCE(p_full_name, ''), COALESCE(p_phone, ''));
  ELSE
    UPDATE providers
       SET full_name = COALESCE(NULLIF(p_full_name, ''), full_name),
           phone     = COALESCE(NULLIF(p_phone, ''),     phone)
     WHERE user_id = v_uid;
  END IF;
END;
$$;
