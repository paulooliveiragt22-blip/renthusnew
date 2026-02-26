-- BLOCO 9.2b: rpc_provider_update_me deve setar app.authorized_change para poder alterar phone
-- Adiciona set_config antes do UPDATE para que o trigger protect_email_and_phone permita

CREATE OR REPLACE FUNCTION public.rpc_provider_update_me(
  p_full_name text DEFAULT NULL,
  p_phone text DEFAULT NULL,
  p_address_city text DEFAULT NULL,
  p_address_state text DEFAULT NULL,
  p_address_cep text DEFAULT NULL,
  p_address_street text DEFAULT NULL,
  p_address_number text DEFAULT NULL,
  p_address_district text DEFAULT NULL,
  p_address_complement text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_user_id UUID;
  v_provider_id UUID;
  v_result JSON;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuario nao autenticado';
  END IF;

  SELECT id INTO v_provider_id FROM providers WHERE user_id = v_user_id;
  IF v_provider_id IS NULL THEN
    RAISE EXCEPTION 'Prestador nao encontrado';
  END IF;

  IF p_full_name IS NOT NULL AND LENGTH(TRIM(p_full_name)) < 3 THEN
    RAISE EXCEPTION 'Nome deve ter pelo menos 3 caracteres';
  END IF;

  IF p_phone IS NOT NULL THEN
    p_phone := REGEXP_REPLACE(p_phone, '[^0-9]', '', 'g');
    IF LENGTH(p_phone) < 10 OR LENGTH(p_phone) > 11 THEN
      RAISE EXCEPTION 'Telefone invalido (deve ter 10 ou 11 digitos)';
    END IF;
  END IF;

  IF p_address_cep IS NOT NULL THEN
    p_address_cep := REGEXP_REPLACE(p_address_cep, '[^0-9]', '', 'g');
    IF LENGTH(p_address_cep) != 8 THEN
      RAISE EXCEPTION 'CEP invalido (deve ter 8 digitos)';
    END IF;
  END IF;

  PERFORM set_config('app.authorized_change', 'true', true);

  UPDATE providers
  SET
    full_name = COALESCE(NULLIF(TRIM(p_full_name), ''), full_name),
    phone = COALESCE(p_phone, phone),
    address_city = COALESCE(NULLIF(TRIM(p_address_city), ''), address_city),
    address_state = COALESCE(NULLIF(TRIM(p_address_state), ''), address_state),
    address_cep = COALESCE(p_address_cep, address_cep),
    address_street = COALESCE(NULLIF(TRIM(p_address_street), ''), address_street),
    address_number = COALESCE(NULLIF(TRIM(p_address_number), ''), address_number),
    address_district = COALESCE(NULLIF(TRIM(p_address_district), ''), address_district),
    address_complement = COALESCE(NULLIF(TRIM(p_address_complement), ''), address_complement),
    updated_at = NOW()
  WHERE id = v_provider_id;

  PERFORM set_config('app.authorized_change', 'false', true);

  SELECT json_build_object(
    'id', id, 'user_id', user_id, 'full_name', full_name, 'phone', phone,
    'address_city', address_city, 'address_state', address_state,
    'address_cep', address_cep, 'updated_at', updated_at
  ) INTO v_result
  FROM providers WHERE id = v_provider_id;

  RETURN v_result;
END;
$function$;
