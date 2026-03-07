-- ============================================================
-- MIGRACAO: obrigatoriedade de data e hora na proposta do prestador
-- Regra:
--   - Cliente: continua podendo enviar pedido flexivel ou com data sem horario.
--   - Prestador: deve sempre enviar data + horario inicio/fim na proposta.
-- ============================================================

CREATE OR REPLACE FUNCTION public.submit_job_quote(
  p_job_id UUID,
  p_approximate_price NUMERIC,
  p_message TEXT DEFAULT NULL,
  p_proposed_date DATE DEFAULT NULL,
  p_proposed_start_time TIME DEFAULT NULL,
  p_proposed_end_time TIME DEFAULT NULL,
  p_estimated_duration_minutes INT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_provider_id UUID;
  v_job_date DATE;
  v_has_flexible BOOLEAN;
  v_final_date DATE;
BEGIN
  v_provider_id := auth.uid();
  IF v_provider_id IS NULL THEN
    RAISE EXCEPTION 'Usuario nao autenticado';
  END IF;

  SELECT
    j.scheduled_date,
    COALESCE(j.has_flexible_schedule, TRUE)
  INTO
    v_job_date,
    v_has_flexible
  FROM public.jobs j
  WHERE j.id = p_job_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pedido nao encontrado';
  END IF;

  -- Se o cliente travou data, usa a data do job como padrao.
  IF v_has_flexible = FALSE AND v_job_date IS NOT NULL THEN
    v_final_date := v_job_date;
  ELSE
    v_final_date := p_proposed_date;
  END IF;

  IF v_final_date IS NULL THEN
    RAISE EXCEPTION 'Data da proposta e obrigatoria';
  END IF;

  IF p_proposed_start_time IS NULL OR p_proposed_end_time IS NULL THEN
    RAISE EXCEPTION 'Horario de inicio e fim da proposta sao obrigatorios';
  END IF;

  IF p_proposed_end_time <= p_proposed_start_time THEN
    RAISE EXCEPTION 'Horario de fim deve ser maior que o horario de inicio';
  END IF;

  INSERT INTO public.job_candidates (job_id, provider_id, status)
  VALUES (p_job_id, v_provider_id, 'pending')
  ON CONFLICT (job_id, provider_id) DO UPDATE SET status = 'pending';

  INSERT INTO public.job_quotes (
    job_id,
    provider_id,
    approximate_price,
    message,
    proposed_date,
    proposed_start_time,
    proposed_end_time,
    estimated_duration_minutes
  ) VALUES (
    p_job_id,
    v_provider_id,
    p_approximate_price,
    p_message,
    v_final_date,
    p_proposed_start_time,
    p_proposed_end_time,
    p_estimated_duration_minutes
  )
  ON CONFLICT (job_id, provider_id) DO UPDATE SET
    approximate_price = EXCLUDED.approximate_price,
    message = EXCLUDED.message,
    proposed_date = EXCLUDED.proposed_date,
    proposed_start_time = EXCLUDED.proposed_start_time,
    proposed_end_time = EXCLUDED.proposed_end_time,
    estimated_duration_minutes = EXCLUDED.estimated_duration_minutes;
END;
$$;
