-- View para busca de serviços na tela de pesquisa do cliente (client_service_search_page).
-- Expõe os mesmos dados que service_types + nome da categoria, com permissão para authenticated/anon.
-- A tabela service_types não tem SELECT para authenticated; esta view usa a mesma lógica de v_service_types_search
-- (usada pelo CreateJobBottomSheet/ServiceTypesRepository) e adiciona category_name para exibição.

CREATE OR REPLACE VIEW public.v_service_types_search_display AS
SELECT
  st.id,
  st.name,
  st.description,
  st.category_id,
  sc.name AS category_name
FROM public.service_types st
LEFT JOIN public.service_categories sc ON sc.id = st.category_id
WHERE st.is_active = true;

COMMENT ON VIEW public.v_service_types_search_display IS 'Tipos de serviço ativos com nome da categoria; para busca na tela do cliente (SELECT para authenticated/anon).';

GRANT SELECT ON public.v_service_types_search_display TO authenticated;
GRANT SELECT ON public.v_service_types_search_display TO anon;
