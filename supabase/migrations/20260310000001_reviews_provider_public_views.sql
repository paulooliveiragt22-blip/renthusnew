-- ============================================================
-- Reviews: add provider_id + create public views
-- ============================================================
-- 1. Adiciona coluna provider_id em reviews (FK para providers)
-- 2. Cria v_provider_public_profile (perfil público do prestador)
-- 3. Cria v_provider_public_reviews  (avaliações públicas do prestador)
-- ============================================================


-- ============================================================
-- 1. Adiciona provider_id em reviews
-- ============================================================

ALTER TABLE public.reviews
  ADD COLUMN IF NOT EXISTS provider_id uuid
    REFERENCES public.providers(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_reviews_provider_id
  ON public.reviews(provider_id);


-- ============================================================
-- 2. v_provider_public_profile
-- ============================================================

DROP VIEW IF EXISTS public.v_provider_public_profile CASCADE;

CREATE VIEW public.v_provider_public_profile AS
SELECT
  p.id                                                        AS provider_id,
  COALESCE(NULLIF(TRIM(p.full_name), ''), 'Profissional')     AS name,
  p.avatar_url,
  p.bio,

  -- Rating médio calculado das avaliações reais
  (
    SELECT ROUND(AVG(r.rating)::numeric, 1)
    FROM public.reviews r
    WHERE r.provider_id = p.id
  )                                                           AS rating,

  -- Localidade
  NULLIF(TRIM(p.address_city),  '')                           AS city,
  NULLIF(TRIM(p.address_state), '')                           AS state,

  -- Serviços concluídos
  (
    SELECT COUNT(*)::int
    FROM public.jobs j
    WHERE j.provider_id = p.id
      AND j.status = 'completed'
  )                                                           AS completed_jobs_count,

  -- Data de entrada
  p.created_at                                                AS member_since,

  -- Tipos de serviço como JSON array [{service_name: "..."}]
  (
    SELECT json_agg(json_build_object('service_name', st.name) ORDER BY st.name)
    FROM public.provider_service_types pst
    JOIN public.service_types st ON st.id = pst.service_type_id
    WHERE pst.provider_id = p.id
  )                                                           AS services

FROM public.providers p
WHERE p.onboarding_completed = true
  AND p.status != 'blocked';

-- Torna a view acessível publicamente (owner = postgres → bypassa RLS nas tabelas)
ALTER VIEW public.v_provider_public_profile OWNER TO postgres;

GRANT SELECT ON public.v_provider_public_profile TO anon, authenticated;


-- ============================================================
-- 3. v_provider_public_reviews
-- ============================================================

DROP VIEW IF EXISTS public.v_provider_public_reviews CASCADE;

CREATE VIEW public.v_provider_public_reviews AS
SELECT
  r.id,
  r.provider_id,
  r.rating,
  r.comment,
  r.created_at,

  -- Nome do cliente que fez a avaliação (anonimizado ao primeiro nome)
  COALESCE(
    SPLIT_PART(NULLIF(TRIM(c.full_name), ''), ' ', 1),
    'Cliente'
  )                                                           AS client_name

FROM public.reviews r
LEFT JOIN public.clients c ON c.id = r.from_user
WHERE r.provider_id IS NOT NULL
  AND r.rating IS NOT NULL;

-- Bypassa RLS nas tabelas subjacentes (reviews tem política restritiva)
ALTER VIEW public.v_provider_public_reviews OWNER TO postgres;

GRANT SELECT ON public.v_provider_public_reviews TO anon, authenticated;


-- ============================================================
-- 4. Trigger para atualizar providers.rating automaticamente
-- ============================================================

CREATE OR REPLACE FUNCTION public.update_provider_rating()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_provider_id uuid;
  v_avg         numeric;
BEGIN
  -- Determina o provider_id afetado
  v_provider_id := COALESCE(NEW.provider_id, OLD.provider_id);
  IF v_provider_id IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- Recalcula média
  SELECT ROUND(AVG(rating)::numeric, 2)
  INTO v_avg
  FROM public.reviews
  WHERE provider_id = v_provider_id;

  -- Atualiza providers.rating
  UPDATE public.providers
  SET rating = COALESCE(v_avg, 0)
  WHERE id = v_provider_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_update_provider_rating ON public.reviews;

CREATE TRIGGER trg_update_provider_rating
  AFTER INSERT OR UPDATE OR DELETE ON public.reviews
  FOR EACH ROW
  EXECUTE FUNCTION public.update_provider_rating();


DO $$
BEGIN
  RAISE NOTICE 'reviews.provider_id: coluna adicionada com FK e índice.';
  RAISE NOTICE 'v_provider_public_profile: view criada (owner=postgres, grant anon+authenticated).';
  RAISE NOTICE 'v_provider_public_reviews: view criada (owner=postgres, grant anon+authenticated).';
  RAISE NOTICE 'trg_update_provider_rating: trigger criado para manter providers.rating atualizado.';
END;
$$;
