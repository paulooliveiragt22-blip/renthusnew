-- Fix rpc_provider_update_address: use correct column names (address_cep, address_city, address_state).
-- The original function referenced non-existent columns cep, city, state.

CREATE OR REPLACE FUNCTION public.rpc_provider_update_address(
  p_cep                     text,
  p_address_street          text,
  p_address_number          text,
  p_address_complement      text,
  p_address_district        text,
  p_city                    text,
  p_state                   text,
  p_mark_onboarding_completed boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE providers
  SET
    address_cep        = NULLIF(p_cep, ''),
    address_street     = NULLIF(p_address_street, ''),
    address_number     = NULLIF(p_address_number, ''),
    address_complement = NULLIF(p_address_complement, ''),
    address_district   = NULLIF(p_address_district, ''),
    address_city       = NULLIF(p_city, ''),
    address_state      = NULLIF(UPPER(p_state), ''),
    onboarding_completed = CASE
      WHEN p_mark_onboarding_completed THEN true
      ELSE onboarding_completed
    END,
    updated_at = NOW()
  WHERE user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Provider não encontrado para este usuário.';
  END IF;
END;
$$;
