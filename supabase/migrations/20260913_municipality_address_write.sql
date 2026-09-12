-- Escrita controlada do endereço municipal — DEV somente até revisão/aplicação manual.
-- Depende da fundação multi-tenant e do helper private.has_active_municipality_role.

begin;

create or replace function private.can_manage_municipality_address(
  target_municipality_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select
    private.is_anchor_superadmin()
    or private.has_active_municipality_role(
      target_municipality_id,
      'municipality_admin'
    );
$$;

revoke all on function private.can_manage_municipality_address(uuid) from public;
grant execute on function private.can_manage_municipality_address(uuid) to authenticated;

create table public.municipality_address_audit (
  id uuid primary key default gen_random_uuid(),
  municipality_id uuid not null references public.municipalities (id) on delete restrict,
  actor_user_id uuid null references auth.users (id) on delete set null,
  action text not null check (action in ('insert', 'update')),
  old_data jsonb null,
  new_data jsonb null,
  created_at timestamptz not null default now(),
  constraint municipality_address_audit_payload_check check (
    (action = 'insert' and old_data is null and new_data is not null)
    or (action = 'update' and old_data is not null and new_data is not null)
  )
);

create index municipality_address_audit_municipality_created_idx
  on public.municipality_address_audit (municipality_id, created_at desc);

create or replace function private.audit_municipality_address_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.municipality_address_audit (
      municipality_id,
      actor_user_id,
      action,
      old_data,
      new_data
    ) values (
      new.municipality_id,
      (select auth.uid()),
      'insert',
      null,
      jsonb_build_object(
        'postal_code', new.postal_code,
        'street', new.street,
        'number', new.number,
        'complement', new.complement,
        'district', new.district,
        'city', new.city,
        'state', new.state
      )
    );
  elsif tg_op = 'UPDATE' then
    insert into public.municipality_address_audit (
      municipality_id,
      actor_user_id,
      action,
      old_data,
      new_data
    ) values (
      new.municipality_id,
      (select auth.uid()),
      'update',
      jsonb_build_object(
        'postal_code', old.postal_code,
        'street', old.street,
        'number', old.number,
        'complement', old.complement,
        'district', old.district,
        'city', old.city,
        'state', old.state
      ),
      jsonb_build_object(
        'postal_code', new.postal_code,
        'street', new.street,
        'number', new.number,
        'complement', new.complement,
        'district', new.district,
        'city', new.city,
        'state', new.state
      )
    );
  end if;

  return new;
end;
$$;

revoke all on function private.audit_municipality_address_change() from public;

create trigger municipality_addresses_audit_insert
  after insert
  on public.municipality_addresses
  for each row
  execute function private.audit_municipality_address_change();

create trigger municipality_addresses_audit_update
  after update of postal_code, street, number, complement, district, city, state
  on public.municipality_addresses
  for each row
  when (
    old.postal_code is distinct from new.postal_code
    or old.street is distinct from new.street
    or old.number is distinct from new.number
    or old.complement is distinct from new.complement
    or old.district is distinct from new.district
    or old.city is distinct from new.city
    or old.state is distinct from new.state
  )
  execute function private.audit_municipality_address_change();

alter table public.municipality_address_audit enable row level security;
alter table public.municipality_address_audit force row level security;

revoke all on table public.municipality_address_audit from anon, authenticated;
grant select on public.municipality_address_audit to authenticated;

create policy municipality_address_audit_select_authorized_context
  on public.municipality_address_audit
  for select to authenticated
  using (private.has_tenant_metadata_access(municipality_id));

-- A policy SELECT existente é preservada. Os grants abaixo liberam somente as
-- colunas necessárias para criar ou editar o endereço do contexto autorizado.
revoke all on table public.municipality_addresses from anon, authenticated;
grant select on public.municipality_addresses to authenticated;
grant insert (
  municipality_id,
  postal_code,
  street,
  number,
  complement,
  district,
  city,
  state
) on public.municipality_addresses to authenticated;
grant update (
  postal_code,
  street,
  number,
  complement,
  district,
  city,
  state
) on public.municipality_addresses to authenticated;

create policy municipality_addresses_insert_managers
  on public.municipality_addresses
  for insert to authenticated
  with check (
    private.can_manage_municipality_address(municipality_id)
  );

create policy municipality_addresses_update_managers
  on public.municipality_addresses
  for update to authenticated
  using (
    private.can_manage_municipality_address(municipality_id)
  )
  with check (
    private.can_manage_municipality_address(municipality_id)
  );

commit;