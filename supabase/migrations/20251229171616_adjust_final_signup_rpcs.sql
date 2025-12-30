create or replace function public.rpc_client_step2(
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
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  -- cria o client se ainda não existir
  insert into public.clients (id, city)
  values (v_uid, p_city)
  on conflict (id) do update
    set city = excluded.city;

  -- endereço (exemplo: ajuste conforme sua modelagem real)
  insert into public.client_addresses (
    client_id,
    zipcode,
    street,
    number,
    district,
    state
  )
  values (
    v_uid,
    p_address_zip_code,
    p_address_street,
    p_address_number,
    p_address_district,
    p_address_state
  )
  on conflict (client_id) do update
    set
      zipcode = excluded.zipcode,
      street = excluded.street,
      number = excluded.number,
      district = excluded.district,
      state = excluded.state;
end;
$$;

create or replace function public.rpc_provider_set_services(
  p_service_type_ids uuid[]
)
returns void
language plpgsql
security definer
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if array_length(p_service_type_ids, 1) is null then
    raise exception 'No services selected';
  end if;

  -- cria o provider se ainda não existir
  insert into public.providers (id, rating, is_verified)
  values (v_uid, 0, false)
  on conflict (id) do nothing;

  -- remove serviços antigos
  delete from public.provider_service_types
  where provider_id = v_uid;

  -- insere novos serviços
  insert into public.provider_service_types (provider_id, service_type_id)
  select v_uid, unnest(p_service_type_ids);
end;
$$;
