-- BLOCO 9.2: Bloquear UPDATE direto de email e phone pelo usuario autenticado

CREATE OR REPLACE FUNCTION public.protect_email_and_phone()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_role TEXT;
  v_authorized TEXT;
BEGIN
  v_role := COALESCE((current_setting('request.jwt.claims', true))::json ->> 'role', '');
  IF v_role = 'service_role' THEN RETURN NEW; END IF;

  v_authorized := current_setting('app.authorized_change', true);
  IF v_authorized = 'true' THEN RETURN NEW; END IF;

  IF OLD.email IS NOT NULL AND COALESCE(OLD.email::text, '') != '' AND NEW.email IS DISTINCT FROM OLD.email THEN
    RAISE EXCEPTION 'Alteracao de email so e permitida pela area de seguranca do app.';
  END IF;

  IF OLD.phone IS NOT NULL AND COALESCE(OLD.phone::text, '') != '' AND NEW.phone IS DISTINCT FROM OLD.phone THEN
    RAISE EXCEPTION 'Alteracao de telefone so e permitida pela area de seguranca do app.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_client_email_phone ON public.clients;
CREATE TRIGGER protect_client_email_phone BEFORE UPDATE ON public.clients FOR EACH ROW EXECUTE FUNCTION public.protect_email_and_phone();

DROP TRIGGER IF EXISTS protect_provider_email_phone ON public.providers;
CREATE TRIGGER protect_provider_email_phone BEFORE UPDATE ON public.providers FOR EACH ROW EXECUTE FUNCTION public.protect_email_and_phone();
