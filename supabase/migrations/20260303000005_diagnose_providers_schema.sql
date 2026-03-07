-- Diagnostic: dump providers columns and rpc_provider_update_address body.
DO $$
DECLARE
  r record;
BEGIN
  RAISE NOTICE '=== providers columns ===';
  FOR r IN
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'providers'
    ORDER BY ordinal_position
  LOOP
    RAISE NOTICE '  col: % | type: % | nullable: %', r.column_name, r.data_type, r.is_nullable;
  END LOOP;

  RAISE NOTICE '=== rpc_provider_update_address body ===';
  FOR r IN
    SELECT pg_get_function_identity_arguments(p.oid) AS args,
           pg_get_functiondef(p.oid) AS body
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE p.proname = 'rpc_provider_update_address' AND n.nspname = 'public'
  LOOP
    RAISE NOTICE 'ARGS: %  BODY: %', r.args, r.body;
  END LOOP;
END;
$$;
