-- Mantém e-mails de clients/providers sincronizados com auth.users

CREATE OR REPLACE FUNCTION public.sync_email_on_auth_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Clients usam id = auth.users.id
  UPDATE public.clients
  SET email = NEW.email
  WHERE id = NEW.id;

  -- Providers usam user_id = auth.users.id
  UPDATE public.providers
  SET email = NEW.email
  WHERE user_id = NEW.id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_update_sync_email ON auth.users;
CREATE TRIGGER on_auth_user_update_sync_email
AFTER UPDATE OF email ON auth.users
FOR EACH ROW
WHEN (OLD.email IS DISTINCT FROM NEW.email)
EXECUTE FUNCTION public.sync_email_on_auth_change();

