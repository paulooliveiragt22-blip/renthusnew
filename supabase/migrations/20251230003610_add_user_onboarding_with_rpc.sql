-- 0) extensões úteis
create extension if not exists pgcrypto;

-- 1) tabela
create table if not exists public.user_onboarding (
  user_id uuid primary key references auth.users(id) on delete cascade,

  intended_role text check (intended_role in ('client', 'provider')),

  status text not null default 'started'
    check (status in (
      'started',
      'signup_submitted',
      'email_confirmed',
      'step2_started',
      'completed'
    )),

  started_at timestamptz not null default now(),
  signup_submitted_at timestamptz,
  email_confirmed_at timestamptz,
  step2_started_at timestamptz,
  completed_at timestamptz,

  utm_source text,
  utm_medium text,
  utm_campaign text,
  referrer text,
  platform text,

  updated_at timestamptz not null default now()
);

-- 2) trigger updated_at
create or replace function public.touch_user_onboarding_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_touch_user_onboarding_updated_at on public.user_onboarding;
create trigger trg_touch_user_onboarding_updated_at
before update on public.user_onboarding
for each row
execute function public.touch_user_onboarding_updated_at();

-- 3) RLS
alter table public.user_onboarding enable row level security;

drop policy if exists onboarding_select_own on public.user_onboarding;
create policy onboarding_select_own
on public.user_onboarding
for select
to authenticated
using (user_id = auth.uid());

-- Sem insert/update direto do app (vamos usar RPC)
drop policy if exists onboarding_insert_own on public.user_onboarding;
drop policy if exists onboarding_update_own on public.user_onboarding;

-- 4) RPC única para upsert + timestamps
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
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  -- garante linha
  insert into public.user_onboarding(user_id, intended_role, status, started_at, updated_at)
  values (
    v_uid,
    case when p_intended_role in ('client','provider') then p_intended_role else null end,
    case when p_status is not null then p_status else 'started' end,
    v_now,
    v_now
  )
  on conflict (user_id) do nothing;

  -- atualiza campos opcionais + status
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

    status = coalesce(p_status, u.status),

    signup_submitted_at = case when p_status = 'signup_submitted' then v_now else u.signup_submitted_at end,
    email_confirmed_at   = case when p_status = 'email_confirmed'   then v_now else u.email_confirmed_at end,
    step2_started_at     = case when p_status = 'step2_started'     then v_now else u.step2_started_at end,
    completed_at         = case when p_status = 'completed'         then v_now else u.completed_at end,

    updated_at = v_now
  where u.user_id = v_uid;
end;
$$;

grant execute on function public.rpc_onboarding_upsert(
  text, text, text, text, text, text, text
) to authenticated;

-- 5) (opcional) revoke acesso direto para forçar RPC (recomendado)
revoke all on public.user_onboarding from authenticated;
revoke all on public.user_onboarding from anon;
