-- Escrita controlada e auditoria de responsáveis por unidade administrativa.
-- DEV somente até revisão e aplicação manual. Não altera estruturas legadas.
-- Depende da fundação multi-tenant, da migration institucional e do helper
-- private.has_active_municipality_role(uuid, text).

begin;

-- Centraliza a autorização de escrita. anchor_operator e os papéis funcionais
-- permanecem somente leitura, independentemente do comportamento do frontend.
create or replace function private.can_manage_municipality_department_contacts(
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

revoke all on function private.can_manage_municipality_department_contacts(uuid) from public;
grant execute on function private.can_manage_municipality_department_contacts(uuid) to authenticated;

-- Histórico imutável dos dados operacionais do responsável. A referência direta
-- ao contato já identifica unicamente a linha, portanto não é necessária uma
-- alteração estrutural na tabela de contatos apenas para criar uma FK composta.
create table public.municipality_department_contact_audit (
  id uuid primary key default gen_random_uuid(),
  municipality_id uuid not null references public.municipalities (id) on delete restrict,
  contact_id uuid not null references public.municipality_department_contacts (id) on delete restrict,
  actor_user_id uuid null references auth.users (id) on delete set null,
  action text not null check (action in ('insert', 'update', 'activate', 'deactivate')),
  old_data jsonb null,
  new_data jsonb null,
  created_at timestamptz not null default now(),
  constraint municipality_department_contact_audit_payload_check check (
    (action = 'insert' and old_data is null and new_data is not null)
    or (action in ('update', 'activate', 'deactivate') and old_data is not null and new_data is not null)
  )
);

create index municipality_department_contact_audit_municipality_created_idx
  on public.municipality_department_contact_audit (municipality_id, created_at desc);

-- A função usa exclusivamente a linha persistida e auth.uid() da sessão que
-- provocou a mudança. O cliente não pode inserir nem controlar a auditoria.
create or replace function private.audit_municipality_department_contact_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  audit_action text;
begin
  if tg_op = 'INSERT' then
    insert into public.municipality_department_contact_audit (
      municipality_id,
      contact_id,
      actor_user_id,
      action,
      old_data,
      new_data
    ) values (
      new.municipality_id,
      new.id,
      (select auth.uid()),
      'insert',
      null,
      jsonb_build_object(
        'department_id', new.department_id,
        'membership_id', new.membership_id,
        'full_name', new.full_name,
        'job_title', new.job_title,
        'email', new.email,
        'phone', new.phone,
        'is_primary', new.is_primary,
        'status', new.status
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

    insert into public.municipality_department_contact_audit (
      municipality_id,
      contact_id,
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
        'department_id', old.department_id,
        'membership_id', old.membership_id,
        'full_name', old.full_name,
        'job_title', old.job_title,
        'email', old.email,
        'phone', old.phone,
        'is_primary', old.is_primary,
        'status', old.status
      ),
      jsonb_build_object(
        'department_id', new.department_id,
        'membership_id', new.membership_id,
        'full_name', new.full_name,
        'job_title', new.job_title,
        'email', new.email,
        'phone', new.phone,
        'is_primary', new.is_primary,
        'status', new.status
      )
    );
  end if;

  return new;
end;
$$;

revoke all on function private.audit_municipality_department_contact_change() from public;

create trigger municipality_department_contacts_audit_insert
  after insert
  on public.municipality_department_contacts
  for each row
  execute function private.audit_municipality_department_contact_change();

create trigger municipality_department_contacts_audit_update
  after update of department_id, membership_id, full_name, job_title, email, phone, is_primary, status
  on public.municipality_department_contacts
  for each row
  when (
    old.department_id is distinct from new.department_id
    or old.membership_id is distinct from new.membership_id
    or old.full_name is distinct from new.full_name
    or old.job_title is distinct from new.job_title
    or old.email is distinct from new.email
    or old.phone is distinct from new.phone
    or old.is_primary is distinct from new.is_primary
    or old.status is distinct from new.status
  )
  execute function private.audit_municipality_department_contact_change();

alter table public.municipality_department_contact_audit enable row level security;
alter table public.municipality_department_contact_audit force row level security;

-- authenticated pode somente consultar históricos do município ao qual já tem
-- acesso. INSERT é realizado exclusivamente pelo trigger security definer.
revoke all on table public.municipality_department_contact_audit from anon, authenticated;
grant select on public.municipality_department_contact_audit to authenticated;

create policy municipality_department_contact_audit_select_authorized_context
  on public.municipality_department_contact_audit
  for select to authenticated
  using (private.has_tenant_metadata_access(municipality_id));

-- A policy SELECT de municipality_department_contacts é preservada. Grants de
-- coluna deixam municipality_id disponível apenas no INSERT e impedem que ele,
-- id e timestamps sejam modificados via API authenticated.
revoke all on table public.municipality_department_contacts from anon, authenticated;
grant select on public.municipality_department_contacts to authenticated;
grant insert (
  municipality_id,
  department_id,
  membership_id,
  full_name,
  job_title,
  email,
  phone,
  is_primary,
  status
) on public.municipality_department_contacts to authenticated;
grant update (
  department_id,
  membership_id,
  full_name,
  job_title,
  email,
  phone,
  is_primary,
  status
) on public.municipality_department_contacts to authenticated;

create policy municipality_department_contacts_insert_managers
  on public.municipality_department_contacts
  for insert to authenticated
  with check (
    private.can_manage_municipality_department_contacts(municipality_id)
  );

create policy municipality_department_contacts_update_managers
  on public.municipality_department_contacts
  for update to authenticated
  using (
    private.can_manage_municipality_department_contacts(municipality_id)
  )
  with check (
    private.can_manage_municipality_department_contacts(municipality_id)
  );

commit;
