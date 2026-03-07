-- Fix rpc_provider_ensure_me: remove the incorrect guard that blocks users
-- who already have a client record from also becoming providers.
-- In Renthus provider signup, rpc_client_ensure_me is called first (creating a
-- client record), then rpc_provider_ensure_me is called. The existing check
-- RAISE EXCEPTION 'User already registered as client' is wrong and must be removed.

DO $$
DECLARE
  func_def  text;
  fixed_def text;
BEGIN
  SELECT pg_get_functiondef(oid)
    INTO func_def
    FROM pg_proc
   WHERE proname = 'rpc_provider_ensure_me'
     AND pronamespace = 'public'::regnamespace;

  IF func_def IS NULL THEN
    RAISE NOTICE 'rpc_provider_ensure_me not found — skipping fix';
    RETURN;
  END IF;

  -- Replace the RAISE EXCEPTION line (simple string replace, no regex needed)
  fixed_def := replace(
    func_def,
    'RAISE EXCEPTION ''User already registered as client'';',
    '-- removed: users may be both client and provider (NULL = do nothing)'
  );

  IF fixed_def = func_def THEN
    RAISE WARNING 'rpc_provider_ensure_me: guard pattern not found. '
                  'Function may already be fixed or formatted differently. '
                  'Definition preview: %', left(func_def, 800);
  ELSE
    EXECUTE fixed_def;
    RAISE NOTICE 'rpc_provider_ensure_me: guard removed successfully';
  END IF;
END;
$$;
