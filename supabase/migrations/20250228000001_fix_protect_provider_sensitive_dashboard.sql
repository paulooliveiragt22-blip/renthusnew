-- Fix: permitir alteração de verification_status pelo Dashboard do Supabase
-- O Table Editor usa conexão que pode não ter JWT com service_role.
-- Permite: service_role, app.authorized_change, ou conexão sem JWT (SQL Editor/Dashboard)

CREATE OR REPLACE FUNCTION public.protect_provider_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_role TEXT;
  v_authorized TEXT;
  v_has_jwt BOOLEAN;
BEGIN
  v_role := COALESCE(
    (current_setting('request.jwt.claims', true))::json ->> 'role',
    ''
  );
  v_has_jwt := current_setting('request.jwt.claims', true) IS NOT NULL
    AND current_setting('request.jwt.claims', true) != '';

  -- service_role: sempre permite
  IF v_role = 'service_role' THEN
    RETURN NEW;
  END IF;

  -- Conexão sem JWT (SQL Editor, Dashboard): assume admin
  IF NOT v_has_jwt THEN
    RETURN NEW;
  END IF;

  -- Flag app.authorized_change (RPCs do app)
  v_authorized := current_setting('app.authorized_change', true);
  IF v_authorized = 'true' THEN
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
