-- Drop ALL overloaded versions of rpc_provider_ensure_me and recreate clean.
-- The previous CREATE OR REPLACE only creates a new overload if the parameter
-- list differs from the existing function — it does NOT replace the old version.
-- This migration explicitly drops every version found in pg_proc.

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT oid, pg_get_function_identity_arguments(oid) AS args
      FROM pg_proc
     WHERE proname = 'rpc_provider_ensure_me'
       AND pronamespace = 'public'::regnamespace
  LOOP
    EXECUTE format(
      'DROP FUNCTION IF EXISTS public.rpc_provider_ensure_me(%s) CASCADE',
      r.args
    );
    RAISE NOTICE 'Dropped rpc_provider_ensure_me(%)', r.args;
  END LOOP;
END;
$$;

-- Recreate the single correct version (no client guard, supports p_user_id fallback)
CREATE FUNCTION public.rpc_provider_ensure_me(
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
