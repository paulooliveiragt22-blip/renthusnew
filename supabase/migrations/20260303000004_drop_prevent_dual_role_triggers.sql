-- Remove triggers and function that block dual-role (client + provider) accounts.
-- In Renthus, a single user CAN hold both the client and provider roles simultaneously.
-- The prevent_dual_role_by_id triggers were wrong for this domain and must be removed.

DROP TRIGGER IF EXISTS trg_prevent_dual_role_providers ON public.providers;
DROP TRIGGER IF EXISTS trg_prevent_dual_role_clients   ON public.clients;

DROP FUNCTION IF EXISTS public.prevent_dual_role_by_id() CASCADE;
