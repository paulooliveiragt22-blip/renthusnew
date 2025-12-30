alter table public.clients
add column if not exists phone text;

create or replace function public.rpc_client_step2(
  p_full_name text,
  p_phone text,
  p_city text,
  p_address_zip_code text,
  p_address_street text,
  p_address_number text,
  p_address_district text,
  p_address_state text
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  insert into public.clients (
    id, full_name, phone, city,
    address_zip_code, address_street, address_number, address_district, address_state,
    address_completed, updated_at
  )
  values (
    v_uid, p_full_name, p_phone, p_city,
    p_address_zip_code, p_address_street, p_address_number, p_address_district, p_address_state,
    true, now()
  )
  on conflict (id) do update
    set
      full_name = excluded.full_name,
      phone = excluded.phone,
      city = excluded.city,
      address_zip_code = excluded.address_zip_code,
      address_street = excluded.address_street,
      address_number = excluded.address_number,
      address_district = excluded.address_district,
      address_state = excluded.address_state,
      address_completed = true,
      updated_at = now();
end;
$$;

grant execute on function public.rpc_client_step2(
  text, text, text, text, text, text, text, text
) to authenticated;

create or replace function public.rpc_provider_set_services(
  p_full_name text,
  p_phone text,
  p_city text,
  p_cep text,
  p_address_street text,
  p_address_number text,
  p_address_complement text,
  p_address_district text,
  p_state text,
  p_service_type_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_user_id uuid := auth.uid();
  v_provider_id uuid;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if array_length(p_service_type_ids, 1) is null then
    raise exception 'No services selected';
  end if;

  insert into public.providers (
    id, user_id, full_name, phone, city, cep, state,
    address_street, address_number, address_complement, address_district,
    has_configured_services, onboarding_completed, updated_at
  )
  values (
    gen_random_uuid(), v_user_id, p_full_name, p_phone, p_city, p_cep, p_state,
    p_address_street, p_address_number, p_address_complement, p_address_district,
    true, true, now()
  )
  on conflict (user_id) do update
    set
      full_name = excluded.full_name,
      phone = excluded.phone,
      city = excluded.city,
      cep = excluded.cep,
      state = excluded.state,
      address_street = excluded.address_street,
      address_number = excluded.address_number,
      address_complement = excluded.address_complement,
      address_district = excluded.address_district,
      has_configured_services = true,
      onboarding_completed = true,
      updated_at = now()
  returning id into v_provider_id;

  if v_provider_id is null then
    select id into v_provider_id
    from public.providers
    where user_id = v_user_id;
  end if;

  delete from public.provider_service_types
  where provider_id = v_provider_id;

  insert into public.provider_service_types (id, provider_id, service_type_id, created_at)
  select gen_random_uuid(), v_provider_id, unnest(p_service_type_ids), now();
end;
$$;

grant execute on function public.rpc_provider_set_services(
  text, text, text, text, text, text, text, text, text, uuid[]
) to authenticated;
