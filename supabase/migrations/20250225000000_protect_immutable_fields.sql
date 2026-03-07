-- BLOCO 9.1: Impedir alteração de nome e CPF pelo próprio usuário
-- O admin (service_role) continua podendo alterar tudo

CREATE OR REPLACE FUNCTION public.protect_immutable_fields()
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

  IF TG_TABLE_NAME = 'clients' THEN
    IF OLD.full_name IS NOT NULL AND TRIM(OLD.full_name) != ''
       AND NEW.full_name IS DISTINCT FROM OLD.full_name THEN
      RAISE EXCEPTION 'Alteração de nome não permitida. Entre em contato com o suporte.';
    END IF;
  END IF;

  IF TG_TABLE_NAME = 'providers' THEN
    IF OLD.full_name IS NOT NULL AND TRIM(OLD.full_name) != ''
       AND NEW.full_name IS DISTINCT FROM OLD.full_name THEN
      RAISE EXCEPTION 'Alteração de nome não permitida. Entre em contato com o suporte.';
    END IF;

    IF OLD.cpf IS NOT NULL AND TRIM(OLD.cpf) != ''
       AND NEW.cpf IS DISTINCT FROM OLD.cpf THEN
      RAISE EXCEPTION 'Alteração de CPF não permitida. O CPF está vinculado ao cadastro financeiro.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_client_immutable_fields ON public.clients;
CREATE TRIGGER protect_client_immutable_fields
  BEFORE UPDATE ON public.clients
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_immutable_fields();

DROP TRIGGER IF EXISTS protect_provider_immutable_fields ON public.providers;
CREATE TRIGGER protect_provider_immutable_fields
  BEFORE UPDATE ON public.providers
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_immutable_fields();
