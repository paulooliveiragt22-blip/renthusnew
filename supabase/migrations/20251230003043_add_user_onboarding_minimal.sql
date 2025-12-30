-- 1) tabela
create table if not exists public.user_onboarding (
  user_id uuid primary key references auth.users(id) on delete cascade,

  intended_role text check (intended_role in ('client', 'provider')),
  status text not null check (status in (
    'started',
    'signup_submitted',
    'email_confirmed',
    'step2_started',
    'completed'
  )) default 'started',

  started_at timestamptz not null default now(),
  signup_submitted_at timestamptz,
  email_confirmed_at timestamptz,
  step2_started_at timestamptz,
  completed_at timestamptz,

  -- métricas/atribuição (opcional, mas útil)
  utm_source text,
  utm_medium text,
  utm_campaign text,
  referrer text,
  platform text,          -- ex: 'android', 'ios', 'web'

  updated_at timestamptz not null default now()
);

-- 2) updated_at automático
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

drop policy if exists "onboarding_select_own" on public.user_onboarding;
create policy "onboarding_select_own"
on public.user_onboarding
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "onboarding_insert_own" on public.user_onboarding;
create policy "onboarding_insert_own"
on public.user_onboarding
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "onboarding_update_own" on public.user_onboarding;
create policy "onboarding_update_own"
on public.user_onboarding
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());
