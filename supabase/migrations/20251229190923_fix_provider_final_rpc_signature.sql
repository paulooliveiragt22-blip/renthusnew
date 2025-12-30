create or replace function public.rpc_provider_set_services(
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

  -- cria provider se não existir
  insert into public.providers (id, city, rating, is_verified)
  values (v_uid, p_city, 0, false)
  on conflict (id) do update
    set city = excluded.city;

  -- salva endereço (ajuste o nome da tabela/colunas conforme seu schema)
  insert into public.provider_addresses (
    provider_id, cep, street, number, complement, district, city, state
  )
  values (
    v_uid, p_cep, p_address_street, p_address_number, p_address_complement,
    p_address_district, p_city, upper(p_state)
  )
  on conflict (provider_id) do update
    set
      cep = excluded.cep,
      street = excluded.street,
      number = excluded.number,
      complement = excluded.complement,
      district = excluded.district,
      city = excluded.city,
      state = excluded.state;

  -- serviços: substitui tudo
  delete from public.provider_service_types where provider_id = v_uid;

  insert into public.provider_service_types (provider_id, service_type_id)
  select v_uid, unnest(p_service_type_ids);
end;
$$;

grant execute on function public.rpc_provider_set_services(
  text, text, text, text, text, text, text, uuid[]
) to authenticated;
