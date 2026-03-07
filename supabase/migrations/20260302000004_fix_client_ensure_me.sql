-- Fix rpc_client_ensure_me: the function does not set clients.id, but the
-- column has no DEFAULT gen_random_uuid(). This causes a NOT NULL violation
-- when called after signUp (since id = null).
-- Fix: set id = auth.uid() explicitly, matching the clients table structure
-- where id is 1:1 with auth.users.id.

DO $$
DECLARE
  func_def  text;
  fixed_def text;
BEGIN
  SELECT pg_get_functiondef(oid)
    INTO func_def
    FROM pg_proc
   WHERE proname = 'rpc_client_ensure_me'
     AND pronamespace = 'public'::regnamespace;

  IF func_def IS NULL THEN
    RAISE NOTICE 'rpc_client_ensure_me not found — skipping fix';
    RETURN;
  END IF;

  RAISE NOTICE 'rpc_client_ensure_me current definition: %', func_def;
END;
$$;

-- Recreate rpc_client_ensure_me to always set id = auth.uid()
-- Uses INSERT ... ON CONFLICT (id) DO UPDATE to be safe (idempotent).
CREATE OR REPLACE FUNCTION public.rpc_client_ensure_me(
  p_full_name text DEFAULT NULL,
  p_phone     text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  INSERT INTO clients (id, full_name, phone)
  VALUES (auth.uid(), COALESCE(p_full_name, ''), COALESCE(p_phone, ''))
  ON CONFLICT (id) DO UPDATE
    SET full_name = COALESCE(NULLIF(EXCLUDED.full_name, ''), clients.full_name),
        phone     = COALESCE(NULLIF(EXCLUDED.phone,     ''), clients.phone),
        updated_at = NOW();
END;
$$;
