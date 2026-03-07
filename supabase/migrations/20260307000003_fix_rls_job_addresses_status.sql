-- Fix RLS policy job_addresses_select_participants.
-- Problema: prestador de job cancelado ainda passava na policy (sem filtro de status).
-- Solução: adicionar filtro de status na condição do provider.
-- Cliente continua vendo sem restrição de status (correto — é o endereço dele).
-- Prestador só vê em: accepted, on_the_way, in_progress, dispute.

DROP POLICY IF EXISTS job_addresses_select_participants ON public.job_addresses;

CREATE POLICY job_addresses_select_participants
ON public.job_addresses
FOR SELECT
USING (
  job_id IN (
    SELECT id FROM public.jobs
    WHERE client_id = auth.uid()
       OR (
            provider_id IN (
              SELECT id FROM public.providers WHERE user_id = auth.uid()
            )
            AND status IN ('accepted','on_the_way','in_progress','dispute')
          )
  )
);

-- Confirma
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT p.polname, pg_get_expr(p.polqual, p.polrelid) AS using_expr
    FROM pg_policy p
    JOIN pg_class c ON c.oid = p.polrelid
    WHERE c.relname = 'job_addresses'
      AND p.polname = 'job_addresses_select_participants'
  LOOP
    RAISE NOTICE 'POLICY: %', r.polname;
    RAISE NOTICE 'USING: %', r.using_expr;
  END LOOP;
  RAISE NOTICE 'RLS job_addresses atualizada com sucesso.';
END;
$$;
