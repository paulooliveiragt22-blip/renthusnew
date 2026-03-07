-- ============================================================
-- Fix: cria v_provider_public_profile e v_provider_public_reviews
-- (provider_id já existe em reviews — adicionado pela migração anterior)
-- ============================================================


-- ============================================================
-- 1. v_provider_public_profile
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

  -- Localidade (sem fallback para colunas inexistentes)
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

ALTER VIEW public.v_provider_public_profile OWNER TO postgres;
GRANT SELECT ON public.v_provider_public_profile TO anon, authenticated;


-- ============================================================
-- 2. v_provider_public_reviews
-- ============================================================

DROP VIEW IF EXISTS public.v_provider_public_reviews CASCADE;

CREATE VIEW public.v_provider_public_reviews AS
SELECT
  r.id,
  r.provider_id,
  r.rating,
  r.comment,
  r.created_at,

  -- Primeiro nome do cliente (leve anonimização)
  COALESCE(
    NULLIF(SPLIT_PART(TRIM(c.full_name), ' ', 1), ''),
    'Cliente'
  )                                                           AS client_name

FROM public.reviews r
LEFT JOIN public.clients c ON c.id = r.from_user
WHERE r.provider_id IS NOT NULL
  AND r.rating IS NOT NULL;

ALTER VIEW public.v_provider_public_reviews OWNER TO postgres;
GRANT SELECT ON public.v_provider_public_reviews TO anon, authenticated;


-- ============================================================
-- 3. Trigger para manter providers.rating atualizado
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
  v_provider_id := COALESCE(NEW.provider_id, OLD.provider_id);
  IF v_provider_id IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  SELECT ROUND(AVG(rating)::numeric, 2)
  INTO v_avg
  FROM public.reviews
  WHERE provider_id = v_provider_id;

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
  RAISE NOTICE 'v_provider_public_profile: criada.';
  RAISE NOTICE 'v_provider_public_reviews: criada.';
  RAISE NOTICE 'trg_update_provider_rating: criado.';
END;
$$;
