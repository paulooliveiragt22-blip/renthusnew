create or replace function public.sync_profile_from_providers()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  insert into public.profiles (
    id, full_name, role, city, avatar_url, rating, bio, is_verified, created_at
  )
  values (
    new.user_id,                 -- ✅ auth.uid (não o providers.id)
    new.full_name,
    'provider',                  -- ✅ fixa o papel (sem coluna role)
    new.city,
    new.avatar_url,
    new.rating,
    new.bio,
    new.is_verified,
    coalesce(new.created_at, now())
  )
  on conflict (id)
  do update set
    full_name   = excluded.full_name,
    role        = excluded.role,
    city        = excluded.city,
    avatar_url  = excluded.avatar_url,
    rating      = excluded.rating,
    bio         = excluded.bio,
    is_verified = excluded.is_verified;

  return new;
end;
$$;

create or replace function public.prevent_dual_role_by_id()
returns trigger
language plpgsql
as $$
begin
  if tg_table_name = 'clients' then
    if exists (select 1 from public.providers p where p.user_id = new.id) then
      raise exception 'User already registered as provider';
    end if;
  end if;

  if tg_table_name = 'providers' then
    if exists (select 1 from public.clients c where c.id = new.user_id) then
      raise exception 'User already registered as client';
    end if;
  end if;

  return new;
end;
$$;
