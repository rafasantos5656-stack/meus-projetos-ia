-- Escrita controlada e auditoria da estrutura administrativa — DEV somente.
-- Depende da fundação multi-tenant, da migration 20260912 e da hierarquia 20260914.

begin;

create or replace function private.can_manage_municipality_structure(
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

revoke all on function private.can_manage_municipality_structure(uuid) from public;
grant execute on function private.can_manage_municipality_structure(uuid) to authenticated;

create table public.municipality_department_audit (
  id uuid primary key default gen_random_uuid(),
  municipality_id uuid not null references public.municipalities (id) on delete restrict,
  department_id uuid not null,
  actor_user_id uuid null references auth.users (id) on delete set null,
  action text not null check (action in ('insert', 'update', 'activate', 'deactivate')),
  old_data jsonb null,
  new_data jsonb null,
  created_at timestamptz not null default now(),
  constraint municipality_department_audit_department_tenant_fkey
    foreign key (department_id, municipality_id)
    references public.municipality_departments (id, municipality_id)
    on delete restrict,
  constraint municipality_department_audit_payload_check check (
    (action = 'insert' and old_data is null and new_data is not null)
    or (action in ('update', 'activate', 'deactivate') and old_data is not null and new_data is not null)
  )
);

create index municipality_department_audit_municipality_created_idx
  on public.municipality_department_audit (municipality_id, created_at desc);

create or replace function private.audit_municipality_department_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  audit_action text;
begin
  if tg_op = 'INSERT' then
    audit_action := 'insert';

    insert into public.municipality_department_audit (
      municipality_id,
      department_id,
      actor_user_id,
      action,
      old_data,
      new_data
    ) values (
      new.municipality_id,
      new.id,
      (select auth.uid()),
      audit_action,
      null,
      jsonb_build_object(
        'name', new.name,
        'abbreviation', new.abbreviation,
        'status', new.status,
        'unit_type', new.unit_type,
        'parent_department_id', new.parent_department_id
      )
    );
  elsif tg_op = 'UPDATE' then
    if old.status = 'active' and new.status = 'inactive' then
      audit_action := 'deactivate';
    elsif old.status = 'inactive' and new.status = 'active' then
      audit_action := 'activate';
    else
      audit_action := 'update';
    end if;

    insert into public.municipality_department_audit (
      municipality_id,
      department_id,
      actor_user_id,
      action,
      old_data,
      new_data
    ) values (
      new.municipality_id,
      new.id,
      (select auth.uid()),
      audit_action,
      jsonb_build_object(
        'name', old.name,
        'abbreviation', old.abbreviation,
        'status', old.status,
        'unit_type', old.unit_type,
        'parent_department_id', old.parent_department_id
      ),
      jsonb_build_object(
        'name', new.name,
        'abbreviation', new.abbreviation,
        'status', new.status,
        'unit_type', new.unit_type,
        'parent_department_id', new.parent_department_id
      )
    );
  end if;

  return new;
end;
$$;

revoke all on function private.audit_municipality_department_change() from public;

create trigger municipality_departments_audit_insert
  after insert
  on public.municipality_departments
  for each row
  execute function private.audit_municipality_department_change();

create trigger municipality_departments_audit_update
  after update of name, abbreviation, status, unit_type, parent_department_id
  on public.municipality_departments
  for each row
  when (
    old.name is distinct from new.name
    or old.abbreviation is distinct from new.abbreviation
    or old.status is distinct from new.status
    or old.unit_type is distinct from new.unit_type
    or old.parent_department_id is distinct from new.parent_department_id
  )
  execute function private.audit_municipality_department_change();

alter table public.municipality_department_audit enable row level security;
alter table public.municipality_department_audit force row level security;

revoke all on table public.municipality_department_audit from anon, authenticated;
grant select on public.municipality_department_audit to authenticated;

create policy municipality_department_audit_select_authorized_context
  on public.municipality_department_audit
  for select to authenticated
  using (private.has_tenant_metadata_access(municipality_id));

-- A policy SELECT existente de municipality_departments é preservada. Os
-- grants abaixo liberam somente as colunas administrativas necessárias.
revoke all on table public.municipality_departments from anon, authenticated;
grant select on public.municipality_departments to authenticated;
grant insert (
  municipality_id,
  name,
  abbreviation,
  status,
  unit_type,
  parent_department_id
) on public.municipality_departments to authenticated;
grant update (
  name,
  abbreviation,
  status,
  unit_type,
  parent_department_id
) on public.municipality_departments to authenticated;

create policy municipality_departments_insert_managers
  on public.municipality_departments
  for insert to authenticated
  with check (
    private.can_manage_municipality_structure(municipality_id)
  );

create policy municipality_departments_update_managers
  on public.municipality_departments
  for update to authenticated
  using (
    private.can_manage_municipality_structure(municipality_id)
  )
  with check (
    private.can_manage_municipality_structure(municipality_id)
  );

-- A tabela já possui RLS habilitado. Forçar RLS mantém a mesma policy SELECT
-- para o proprietário da tabela e preserva a autoridade do banco para leituras
-- e escritas; os helpers de leitura/escrita usam auth.uid() da sessão corrente.
alter table public.municipality_departments force row level security;

commit;