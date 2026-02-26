-- BLOCO 9.4: Impedir que usuário altere verification_status, pagarme_recipient_id, verified_at, verified_by

CREATE OR REPLACE FUNCTION public.protect_provider_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_role TEXT;
BEGIN
  v_role := COALESCE(
    (current_setting('request.jwt.claims', true))::json ->> 'role',
    ''
  );
  IF v_role = 'service_role' THEN
    RETURN NEW;
  END IF;

  IF NEW.pagarme_recipient_id IS DISTINCT FROM OLD.pagarme_recipient_id THEN
    RAISE EXCEPTION 'Alteracao de ID do recebedor nao permitida.';
  END IF;

  IF NEW.verified IS DISTINCT FROM OLD.verified THEN
    RAISE EXCEPTION 'Alteracao de status de verificacao nao permitida.';
  END IF;

  IF NEW.documents_verified IS DISTINCT FROM OLD.documents_verified THEN
    RAISE EXCEPTION 'Alteracao nao permitida.';
  END IF;

  IF NEW.is_verified IS DISTINCT FROM OLD.is_verified THEN
    RAISE EXCEPTION 'Alteracao nao permitida.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_provider_sensitive ON public.providers;
CREATE TRIGGER protect_provider_sensitive
  BEFORE UPDATE ON public.providers
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_provider_sensitive_fields();
