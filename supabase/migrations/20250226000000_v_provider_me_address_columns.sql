-- Inclui colunas de endereço na view v_provider_me para a tela "Meu perfil" do prestador.
-- A view já expunha city/state; faltavam cep, rua, número e bairro.
-- DROP necessário para recriar com novas colunas (CREATE OR REPLACE não permite mudar ordem/nomes).

DROP VIEW IF EXISTS public.v_provider_me;

CREATE VIEW public.v_provider_me AS
SELECT
  p.id AS provider_id,
  p.user_id,
  p.full_name,
  p.avatar_url,
  p.bio,
  p.phone,
  p.address_city AS city,
  p.address_state AS state,
  p.address_cep AS cep,
  p.address_street,
  p.address_number,
  p.address_district,
  p.is_online,
  p.rating,
  p.status,
  p.onboarding_completed,
  p.documents_verified,
  p.is_verified,
  p.verified,
  p.verification_status,
  p.cpf,
  p.document_rejected_reason,
  p.created_at,
  p.updated_at
FROM public.providers p
WHERE p.user_id = auth.uid();

COMMENT ON VIEW public.v_provider_me IS 'Dados do prestador logado (meu perfil); usado por provider_profile_page e getMe().';
