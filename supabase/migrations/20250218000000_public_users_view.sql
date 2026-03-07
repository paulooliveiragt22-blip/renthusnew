-- View public.users para o ProfileRepository (app espera tabela/view "users")
-- Retorna uma linha por usuário autenticado (apenas o próprio usuário) com dados de clients/providers e user_roles.

CREATE OR REPLACE VIEW public.users AS
SELECT
  u.id,
  COALESCE(c.full_name, p.full_name) AS name,
  COALESCE(c.phone, p.phone) AS phone,
  COALESCE(c.avatar_url, p.avatar_url) AS avatar_url,
  COALESCE(
    (SELECT ur.role::text FROM public.user_roles ur WHERE ur.user_id = u.id LIMIT 1),
    'client'
  ) AS role,
  true AS is_active,
  u.created_at,
  COALESCE(c.updated_at, p.updated_at, u.updated_at) AS updated_at
FROM auth.users u
LEFT JOIN public.clients c ON c.id = u.id
LEFT JOIN public.providers p ON p.user_id = u.id
WHERE u.id = auth.uid();

COMMENT ON VIEW public.users IS 'Perfil unificado do usuário atual (leitura/atualização via trigger); usado pelo ProfileRepository.';

-- Permissões
GRANT SELECT ON public.users TO authenticated;
GRANT UPDATE ON public.users TO authenticated;

-- Trigger INSTEAD OF UPDATE: redireciona atualizações para clients e/ou providers (e user_roles se role mudar)
CREATE OR REPLACE FUNCTION public.users_instead_of_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.name IS NOT NULL OR NEW.phone IS NOT NULL OR NEW.avatar_url IS NOT NULL THEN
    UPDATE public.clients
    SET
      full_name = COALESCE(NEW.name, full_name),
      phone = COALESCE(NEW.phone, phone),
      avatar_url = COALESCE(NEW.avatar_url, avatar_url),
      updated_at = NOW()
    WHERE id = NEW.id;

    UPDATE public.providers
    SET
      full_name = COALESCE(NEW.name, full_name),
      phone = COALESCE(NEW.phone, phone),
      avatar_url = COALESCE(NEW.avatar_url, avatar_url),
      updated_at = NOW()
    WHERE user_id = NEW.id;
  END IF;

  IF NEW.role IS NOT NULL AND NEW.role <> '' THEN
    UPDATE public.user_roles
    SET role = NEW.role::public.user_role, updated_at = NOW()
    WHERE user_id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS users_instead_of_update ON public.users;
CREATE TRIGGER users_instead_of_update
  INSTEAD OF UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.users_instead_of_update();
