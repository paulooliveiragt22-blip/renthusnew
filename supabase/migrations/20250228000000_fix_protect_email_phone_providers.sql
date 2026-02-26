-- Fix: providers não tem coluna email, mas protect_email_and_phone acessava OLD.email
-- Tabela providers: tem phone, NÃO tem email
-- Tabela clients: tem email e phone

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

  -- Só verifica email se a tabela tiver a coluna (clients tem, providers não)
  IF TG_TABLE_NAME = 'clients' THEN
    IF OLD.email IS NOT NULL AND COALESCE(OLD.email::text, '') != '' AND NEW.email IS DISTINCT FROM OLD.email THEN
      RAISE EXCEPTION 'Alteracao de email so e permitida pela area de seguranca do app.';
    END IF;
  END IF;

  -- Ambas as tabelas (clients e providers) têm phone
  IF OLD.phone IS NOT NULL AND COALESCE(OLD.phone::text, '') != '' AND NEW.phone IS DISTINCT FROM OLD.phone THEN
    RAISE EXCEPTION 'Alteracao de telefone so e permitida pela area de seguranca do app.';
  END IF;

  RETURN NEW;
END;
$$;
