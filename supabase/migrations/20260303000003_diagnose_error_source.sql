-- Diagnostic: find functions/triggers with 'already registered' and dump ensure_me bodies.
-- Filters to prokind = 'f' (regular functions only) to avoid errors on aggregates/windows.

DO $$
DECLARE
  r record;
BEGIN
  RAISE NOTICE '=== Searching for "already registered" in regular functions ===';

  FOR r IN
    SELECT
      n.nspname   AS schema,
      p.proname   AS func_name,
      pg_get_function_identity_arguments(p.oid) AS args,
      pg_get_functiondef(p.oid) AS body
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE p.prokind = 'f'
      AND pg_get_functiondef(p.oid) ILIKE '%already registered%'
  LOOP
    RAISE NOTICE 'FOUND: %.%(%)  BODY: %',
      r.schema, r.func_name, r.args, left(r.body, 2000);
  END LOOP;

  RAISE NOTICE '=== ensure_me functions (all versions) ===';

  FOR r IN
    SELECT
      p.proname AS func_name,
      pg_get_function_identity_arguments(p.oid) AS args,
      pg_get_functiondef(p.oid) AS body
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE p.prokind = 'f'
      AND p.proname IN ('rpc_provider_ensure_me', 'rpc_client_ensure_me',
                        'handle_new_user', 'handle_new_provider', 'handle_new_client')
      AND n.nspname IN ('public', 'auth')
  LOOP
    RAISE NOTICE 'FUNCTION: %(%)  BODY: %',
      r.func_name, r.args, r.body;
  END LOOP;

  RAISE NOTICE '=== triggers on providers and clients tables ===';

  FOR r IN
    SELECT
      t.tgname   AS trigger_name,
      c.relname  AS table_name,
      p.proname  AS func_name,
      pg_get_functiondef(p.oid) AS body
    FROM pg_trigger t
    JOIN pg_class   c ON c.oid = t.tgrelid
    JOIN pg_proc    p ON p.oid = t.tgfoid
    WHERE c.relname IN ('providers', 'clients', 'users')
      AND NOT t.tgisinternal
  LOOP
    RAISE NOTICE 'TRIGGER: % ON %  FUNC: %  BODY: %',
      r.trigger_name, r.table_name, r.func_name, left(r.body, 2000);
  END LOOP;

  RAISE NOTICE '=== done ===';
END;
$$;
