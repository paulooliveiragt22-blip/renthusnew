-- BLOCO 9.2b: RPCs autorizadas para alterar email e telefone

-- RPC para alterar telefone do CLIENTE (chamada pelo app após confirmar senha)
CREATE OR REPLACE FUNCTION public.update_client_phone(p_new_phone TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM set_config('app.authorized_change', 'true', true);

  UPDATE public.clients
  SET phone = NULLIF(TRIM(p_new_phone), '')
  WHERE id = auth.uid();

  PERFORM set_config('app.authorized_change', 'false', true);
END;
$$;

-- RPC para alterar telefone do PRESTADOR
CREATE OR REPLACE FUNCTION public.update_provider_phone(p_new_phone TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM set_config('app.authorized_change', 'true', true);

  UPDATE public.providers
  SET phone = NULLIF(TRIM(p_new_phone), '')
  WHERE user_id = auth.uid();

  PERFORM set_config('app.authorized_change', 'false', true);
END;
$$;

-- Atualizar sync_email_on_auth_change para setar flag (compatível com protect_email_and_phone)
CREATE OR REPLACE FUNCTION public.sync_email_on_auth_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM set_config('app.authorized_change', 'true', true);

  UPDATE public.clients SET email = NEW.email WHERE id = NEW.id;
  UPDATE public.providers SET email = NEW.email WHERE user_id = NEW.id;

  PERFORM set_config('app.authorized_change', 'false', true);
  RETURN NEW;
END;
$$;
