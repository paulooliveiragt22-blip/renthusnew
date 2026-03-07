-- A1: Remove trigger duplicado de notificação de status em jobs.
-- Ambos trg_notify_job_status e trg_notify_job_status_change chamavam notify_job_status_change.
-- Mantemos trg_notify_job_status_change (criado pela migration 20260306000002).
-- Removemos trg_notify_job_status (trigger antigo/duplicado).

DROP TRIGGER IF EXISTS trg_notify_job_status ON public.jobs;

-- Confirma estado final
DO $$
DECLARE r RECORD; cnt INT := 0;
BEGIN
  FOR r IN
    SELECT t.tgname, p.proname AS fn
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_proc p ON p.oid = t.tgfoid
    WHERE c.relname = 'jobs'
      AND NOT t.tgisinternal
      AND t.tgname ILIKE '%notify%status%'
  LOOP
    cnt := cnt + 1;
    RAISE NOTICE 'TRIGGER RESTANTE: % → fn: %', r.tgname, r.fn;
  END LOOP;

  IF cnt = 1 THEN
    RAISE NOTICE 'A1 OK: apenas 1 trigger de notificação de status em jobs.';
  ELSE
    RAISE WARNING 'A1 ATENÇÃO: % triggers encontrados (esperado: 1)', cnt;
  END IF;
END;
$$;
