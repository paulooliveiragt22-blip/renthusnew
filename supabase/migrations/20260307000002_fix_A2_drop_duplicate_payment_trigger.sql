-- A2: Remove trigger duplicado apply_payment_paid_effects em payments.
-- O trigger "apply_payment_paid_effects" (AFTER INSERT UPDATE) e
-- "trg_apply_payment_paid_effects" (AFTER UPDATE) chamavam a mesma função.
-- No UPDATE, a função disparava 2 vezes.
-- Mantemos trg_apply_payment_paid_effects (com prefixo trg_, padrão do projeto).
-- Removemos apply_payment_paid_effects (sem prefixo, trigger legado/duplicado).

DROP TRIGGER IF EXISTS apply_payment_paid_effects ON public.payments;

-- Confirma estado final
DO $$
DECLARE r RECORD; cnt INT := 0;
BEGIN
  FOR r IN
    SELECT t.tgname, p.proname AS fn,
      CASE t.tgtype::int & 66 WHEN 2 THEN 'BEFORE' ELSE 'AFTER' END AS timing,
      CASE WHEN (t.tgtype::int & 4)  > 0 THEN 'INSERT ' ELSE '' END ||
      CASE WHEN (t.tgtype::int & 16) > 0 THEN 'UPDATE ' ELSE '' END AS events
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_proc p ON p.oid = t.tgfoid
    WHERE c.relname = 'payments'
      AND NOT t.tgisinternal
      AND p.proname = 'apply_payment_paid_effects'
  LOOP
    cnt := cnt + 1;
    RAISE NOTICE 'TRIGGER RESTANTE: % | % % → fn: %', r.tgname, r.timing, r.events, r.fn;
  END LOOP;

  IF cnt = 1 THEN
    RAISE NOTICE 'A2 OK: apenas 1 trigger apply_payment_paid_effects em payments.';
  ELSE
    RAISE WARNING 'A2 ATENÇÃO: % triggers encontrados (esperado: 1)', cnt;
  END IF;
END;
$$;
