-- Add CPF support for clients:
-- 1. Update rpc_client_ensure_me to accept p_cpf (used at signup)
-- 2. Create rpc_client_set_cpf for first-time CPF set (immutable after first set,
--    same protection pattern as providers.cpf)

-- ─────────────────────────────────────────────────────────────────────────────
-- 1) rpc_client_ensure_me — add p_cpf param
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.rpc_client_ensure_me(
  p_full_name text DEFAULT NULL,
  p_phone     text DEFAULT NULL,
  p_user_id   uuid DEFAULT NULL,
  p_cpf       text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid  uuid;
  v_cpf  text;
BEGIN
  v_uid := COALESCE(auth.uid(), p_user_id);
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF auth.uid() IS NOT NULL AND p_user_id IS NOT NULL AND auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'Unauthorized: user_id mismatch';
  END IF;

  -- Normalise CPF: digits only
  v_cpf := NULLIF(regexp_replace(COALESCE(p_cpf, ''), '\D', '', 'g'), '');

  INSERT INTO clients (id, full_name, phone, cpf)
  VALUES (v_uid, COALESCE(p_full_name, ''), COALESCE(p_phone, ''), v_cpf)
  ON CONFLICT (id) DO UPDATE
    SET full_name  = COALESCE(NULLIF(EXCLUDED.full_name, ''), clients.full_name),
        phone      = COALESCE(NULLIF(EXCLUDED.phone, ''),     clients.phone),
        -- CPF: set only if not already set (immutable after first set)
        cpf        = CASE
                       WHEN clients.cpf IS NULL OR clients.cpf = ''
                       THEN COALESCE(EXCLUDED.cpf, clients.cpf)
                       ELSE clients.cpf
                     END,
        updated_at = NOW();
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2) rpc_client_set_cpf — first-time CPF set (immutable after)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.rpc_client_set_cpf(
  p_cpf text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid      uuid;
  v_cpf      text;
  v_existing text;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Normalise: digits only
  v_cpf := NULLIF(regexp_replace(COALESCE(p_cpf, ''), '\D', '', 'g'), '');

  IF v_cpf IS NULL OR length(v_cpf) <> 11 THEN
    RAISE EXCEPTION 'CPF inválido';
  END IF;

  SELECT cpf INTO v_existing FROM clients WHERE id = v_uid;

  IF v_existing IS NOT NULL AND v_existing <> '' THEN
    RAISE EXCEPTION 'CPF já cadastrado e não pode ser alterado';
  END IF;

  UPDATE clients
    SET cpf = v_cpf, updated_at = NOW()
  WHERE id = v_uid;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_client_ensure_me(text, text, uuid, text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.rpc_client_set_cpf(text) TO authenticated;
