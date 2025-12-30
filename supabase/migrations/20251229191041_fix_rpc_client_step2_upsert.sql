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
set search_path to 'public'
as $$
declare
  v_uid uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  insert into public.clients (
    id,
    city,
    address_zip_code,
    address_street,
    address_number,
    address_district,
    address_state,
    address_completed,
    updated_at
  )
  values (
    v_uid,
    p_city,
    p_address_zip_code,
    p_address_street,
    p_address_number,
    p_address_district,
    p_address_state,
    true,
    now()
  )
  on conflict (id) do update
    set
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
  text, text, text, text, text, text
) to authenticated;
