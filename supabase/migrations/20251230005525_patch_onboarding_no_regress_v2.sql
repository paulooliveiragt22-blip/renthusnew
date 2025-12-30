-- 1) helper: rank do status
create or replace function public.onboarding_status_rank(p_status text)
returns int
language sql
immutable
as $$
  select case p_status
    when 'started' then 1
    when 'signup_submitted' then 2
    when 'email_confirmed' then 3
    when 'step2_started' then 4
    when 'completed' then 5
    else 0
  end;
$$;

-- 2) RPC: só avança status (não regride)
create or replace function public.rpc_onboarding_upsert(
  p_status text default null,
  p_intended_role text default null,
  p_utm_source text default null,
  p_utm_medium text default null,
  p_utm_campaign text default null,
  p_referrer text default null,
  p_platform text default null
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid := auth.uid();
  v_now timestamptz := now();

  v_current_status text;
  v_current_rank int := 0;
  v_new_rank int := null;

  v_effective_status text;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  -- garante linha
  insert into public.user_onboarding(user_id, intended_role, status, started_at, updated_at)
  values (
    v_uid,
    case when p_intended_role in ('client','provider') then p_intended_role else null end,
    coalesce(p_status, 'started'),
    v_now,
    v_now
  )
  on conflict (user_id) do nothing;

  -- status atual
  select u.status into v_current_status
  from public.user_onboarding u
  where u.user_id = v_uid;

  v_current_rank := public.onboarding_status_rank(coalesce(v_current_status, 'started'));
  if p_status is not null then
    v_new_rank := public.onboarding_status_rank(p_status);
  end if;

  -- decide status final (não regride; status inválido ignora)
  v_effective_status :=
    case
      when p_status is null then v_current_status
      when v_new_rank = 0 then v_current_status
      when v_new_rank >= v_current_rank then p_status
      else v_current_status
    end;

  update public.user_onboarding u
  set
    intended_role = coalesce(
      case when p_intended_role in ('client','provider') then p_intended_role else null end,
      u.intended_role
    ),

    utm_source = coalesce(p_utm_source, u.utm_source),
    utm_medium = coalesce(p_utm_medium, u.utm_medium),
    utm_campaign = coalesce(p_utm_campaign, u.utm_campaign),
    referrer = coalesce(p_referrer, u.referrer),
    platform = coalesce(p_platform, u.platform),

    status = coalesce(v_effective_status, u.status),

    signup_submitted_at = case
      when v_effective_status = 'signup_submitted' then coalesce(u.signup_submitted_at, v_now)
      else u.signup_submitted_at
    end,

    email_confirmed_at = case
      when v_effective_status = 'email_confirmed' then coalesce(u.email_confirmed_at, v_now)
      else u.email_confirmed_at
    end,

    step2_started_at = case
      when v_effective_status = 'step2_started' then coalesce(u.step2_started_at, v_now)
      else u.step2_started_at
    end,

    completed_at = case
      when v_effective_status = 'completed' then coalesce(u.completed_at, v_now)
      else u.completed_at
    end,

    updated_at = v_now
  where u.user_id = v_uid;
end;
$$;

grant execute on function public.rpc_onboarding_upsert(
  text, text, text, text, text, text, text
) to authenticated;
