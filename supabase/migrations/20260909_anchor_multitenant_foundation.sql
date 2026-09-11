-- Fundação Multi-Prefeitura Âncora — DRAFT local, NÃO EXECUTAR sem autorização.
-- Não altera projects, tasks, dados legados ou produção.

begin;

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create type public.municipality_status as enum ('active', 'suspended', 'archived');
create type public.membership_status as enum ('invited', 'active', 'suspended', 'revoked');
create type public.role_scope as enum ('anchor', 'municipality');
create type public.anchor_assignment_status as enum ('pending', 'active', 'suspended', 'revoked');
create type public.anchor_assignment_access_level as enum ('read_only', 'operational_support');

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text null check (display_name is null or char_length(btrim(display_name)) between 1 and 160),
  status text not null default 'active' check (status in ('active', 'suspended', 'disabled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.municipalities (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) > 0),
  state char(2) not null check (state = upper(state) and state ~ '^[A-Z]{2}$'),
  ibge_code text null check (ibge_code is null or ibge_code ~ '^[0-9]{7}$'),
  primary_cnpj text null check (primary_cnpj is null or primary_cnpj ~ '^[0-9]{14}$'),
  timezone text not null default 'America/Sao_Paulo',
  status public.municipality_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index municipalities_ibge_code_unique
  on public.municipalities (ibge_code) where ibge_code is not null;
create unique index municipalities_primary_cnpj_unique
  on public.municipalities (primary_cnpj) where primary_cnpj is not null;

create table public.municipality_departments (
  id uuid primary key default gen_random_uuid(),
  municipality_id uuid not null references public.municipalities (id) on delete restrict,
  name text not null check (char_length(btrim(name)) > 0),
  abbreviation text null check (abbreviation is null or char_length(btrim(abbreviation)) between 1 and 30),
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint municipality_departments_id_municipality_key unique (id, municipality_id)
);

create unique index municipality_departments_name_unique
  on public.municipality_departments (municipality_id, lower(btrim(name)));

create table public.municipality_members (
  id uuid primary key default gen_random_uuid(),
  municipality_id uuid not null references public.municipalities (id) on delete restrict,
  user_id uuid not null references auth.users (id) on delete restrict,
  status public.membership_status not null default 'invited',
  invited_by uuid null references auth.users (id) on delete set null,
  activated_at timestamptz null,
  deactivated_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint municipality_members_municipality_user_key unique (municipality_id, user_id),
  constraint municipality_members_id_municipality_key unique (id, municipality_id)
);

create index municipality_members_user_status_idx
  on public.municipality_members (user_id, status);
create index municipality_members_municipality_status_idx
  on public.municipality_members (municipality_id, status);

create table public.municipality_member_departments (
  membership_id uuid not null,
  municipality_id uuid not null,
  department_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (membership_id, department_id),
  constraint member_departments_membership_tenant_fkey
    foreign key (membership_id, municipality_id)
    references public.municipality_members (id, municipality_id)
    on delete cascade,
  constraint member_departments_department_tenant_fkey
    foreign key (department_id, municipality_id)
    references public.municipality_departments (id, municipality_id)
    on delete restrict
);

create index municipality_member_departments_municipality_idx
  on public.municipality_member_departments (municipality_id);

create table public.app_roles (
  scope public.role_scope not null,
  code text not null check (code ~ '^[a-z][a-z0-9_]*$'),
  label text not null,
  created_at timestamptz not null default now(),
  primary key (scope, code)
);

insert into public.app_roles (scope, code, label)
values
  ('anchor', 'anchor_superadmin', 'Âncora Superadmin'),
  ('anchor', 'anchor_operator', 'Âncora Operador'),
  ('municipality', 'municipality_admin', 'Prefeitura Admin'),
  ('municipality', 'grants_manager', 'Gestor de Convênios'),
  ('municipality', 'secretariat', 'Secretaria'),
  ('municipality', 'engineering', 'Engenharia'),
  ('municipality', 'finance', 'Contabilidade e Financeiro'),
  ('municipality', 'procurement', 'Licitações e Compras'),
  ('municipality', 'auditor', 'Consulta e Auditoria');

create table public.anchor_user_roles (
  user_id uuid not null references auth.users (id) on delete restrict,
  role_scope public.role_scope not null default 'anchor' check (role_scope = 'anchor'),
  role_code text not null,
  assigned_by uuid null references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (user_id, role_code),
  constraint anchor_user_roles_not_self_assigned_check check (assigned_by is null or assigned_by <> user_id),
  constraint anchor_user_roles_role_fkey
    foreign key (role_scope, role_code) references public.app_roles (scope, code)
);

create table public.municipality_member_roles (
  membership_id uuid not null references public.municipality_members (id) on delete cascade,
  role_scope public.role_scope not null default 'municipality' check (role_scope = 'municipality'),
  role_code text not null,
  assigned_by uuid null references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (membership_id, role_code),
  constraint municipality_member_roles_role_fkey
    foreign key (role_scope, role_code) references public.app_roles (scope, code)
);

create table public.anchor_municipality_assignments (
  id uuid primary key default gen_random_uuid(),
  anchor_user_id uuid not null references auth.users (id) on delete restrict,
  municipality_id uuid not null references public.municipalities (id) on delete restrict,
  access_level public.anchor_assignment_access_level not null default 'read_only',
  status public.anchor_assignment_status not null default 'pending',
  starts_at timestamptz not null default now(),
  expires_at timestamptz null,
  justification text not null check (char_length(btrim(justification)) between 10 and 1000),
  assigned_by uuid not null references auth.users (id) on delete restrict,
  approved_by uuid null references auth.users (id) on delete restrict,
  approved_at timestamptz null,
  revoked_by uuid null references auth.users (id) on delete restrict,
  revoked_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint anchor_assignment_expiration_check check (expires_at is null or expires_at > starts_at),
  constraint anchor_assignment_not_self_assigned_check check (assigned_by <> anchor_user_id),
  constraint anchor_assignment_not_self_approved_check check (approved_by is null or approved_by <> anchor_user_id),
  constraint anchor_assignment_approval_pair_check check (
    (approved_by is null and approved_at is null)
    or (approved_by is not null and approved_at is not null)
  ),
  constraint anchor_assignment_revocation_pair_check check (
    (revoked_by is null and revoked_at is null)
    or (revoked_by is not null and revoked_at is not null)
  ),
  constraint anchor_assignment_active_requires_approval_check check (
    status <> 'active'
    or (approved_by is not null and approved_at is not null and revoked_by is null and revoked_at is null)
  ),
  constraint anchor_assignment_suspended_requires_approval_check check (
    status <> 'suspended'
    or (approved_by is not null and approved_at is not null and revoked_by is null and revoked_at is null)
  ),
  constraint anchor_assignment_revoked_requires_revocation_check check (
    status <> 'revoked'
    or (revoked_by is not null and revoked_at is not null)
  ),
  constraint anchor_assignment_nonrevoked_has_no_revocation_check check (
    status = 'revoked' or (revoked_by is null and revoked_at is null)
  )
);

create unique index anchor_municipality_assignments_one_active_unique
  on public.anchor_municipality_assignments (anchor_user_id, municipality_id)
  where status = 'active'::public.anchor_assignment_status;

create index anchor_municipality_assignments_lookup_idx
  on public.anchor_municipality_assignments (anchor_user_id, municipality_id, status);

create or replace function private.touch_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function private.enforce_anchor_assignment_target()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if not exists (
    select 1
    from public.anchor_user_roles role_assignment
    where role_assignment.user_id = new.anchor_user_id
      and role_assignment.role_scope = 'anchor'::public.role_scope
      and role_assignment.role_code in ('anchor_superadmin', 'anchor_operator')
  ) then
    raise exception 'O usuário indicado não possui papel global da Âncora.';
  end if;

  return new;
end;
$$;

create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function private.touch_updated_at();
create trigger municipalities_touch_updated_at
  before update on public.municipalities
  for each row execute function private.touch_updated_at();
create trigger municipality_departments_touch_updated_at
  before update on public.municipality_departments
  for each row execute function private.touch_updated_at();
create trigger municipality_members_touch_updated_at
  before update on public.municipality_members
  for each row execute function private.touch_updated_at();
create trigger anchor_municipality_assignments_touch_updated_at
  before update on public.anchor_municipality_assignments
  for each row execute function private.touch_updated_at();
create trigger anchor_municipality_assignments_validate_target
  before insert or update of anchor_user_id on public.anchor_municipality_assignments
  for each row execute function private.enforce_anchor_assignment_target();

create or replace function private.is_anchor_superadmin()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select exists (
    select 1
    from public.anchor_user_roles role_assignment
    where role_assignment.user_id = (select auth.uid())
      and role_assignment.role_scope = 'anchor'::public.role_scope
      and role_assignment.role_code = 'anchor_superadmin'
  );
$$;

create or replace function private.has_active_municipality_membership(p_municipality_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select exists (
    select 1
    from public.municipality_members membership
    where membership.municipality_id = p_municipality_id
      and membership.user_id = (select auth.uid())
      and membership.status = 'active'::public.membership_status
  );
$$;

create or replace function private.has_active_anchor_municipality_assignment(p_municipality_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select exists (
    select 1
    from public.anchor_municipality_assignments assignment
    join public.anchor_user_roles role_assignment
      on role_assignment.user_id = assignment.anchor_user_id
    where assignment.anchor_user_id = (select auth.uid())
      and assignment.municipality_id = p_municipality_id
      and assignment.status = 'active'::public.anchor_assignment_status
      and assignment.approved_by is not null
      and assignment.approved_at is not null
      and assignment.starts_at <= now()
      and (assignment.expires_at is null or assignment.expires_at > now())
      and role_assignment.role_scope = 'anchor'::public.role_scope
      and role_assignment.role_code in ('anchor_superadmin', 'anchor_operator')
  );
$$;

create or replace function private.has_tenant_metadata_access(p_municipality_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select
    private.is_anchor_superadmin()
    or private.has_active_municipality_membership(p_municipality_id)
    or private.has_active_anchor_municipality_assignment(p_municipality_id);
$$;

create or replace function private.owns_active_membership(p_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select exists (
    select 1
    from public.municipality_members membership
    where membership.id = p_membership_id
      and membership.user_id = (select auth.uid())
      and membership.status = 'active'::public.membership_status
  );
$$;

revoke all on function private.is_anchor_superadmin() from public;
revoke all on function private.has_active_municipality_membership(uuid) from public;
revoke all on function private.has_active_anchor_municipality_assignment(uuid) from public;
revoke all on function private.has_tenant_metadata_access(uuid) from public;
revoke all on function private.owns_active_membership(uuid) from public;

grant execute on function private.is_anchor_superadmin() to authenticated;
grant execute on function private.has_active_municipality_membership(uuid) to authenticated;
grant execute on function private.has_active_anchor_municipality_assignment(uuid) to authenticated;
grant execute on function private.has_tenant_metadata_access(uuid) to authenticated;
grant execute on function private.owns_active_membership(uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.municipalities enable row level security;
alter table public.municipality_departments enable row level security;
alter table public.municipality_members enable row level security;
alter table public.municipality_member_departments enable row level security;
alter table public.app_roles enable row level security;
alter table public.anchor_user_roles enable row level security;
alter table public.municipality_member_roles enable row level security;
alter table public.anchor_municipality_assignments enable row level security;

revoke all on table public.profiles from anon, authenticated;
revoke all on table public.municipalities from anon, authenticated;
revoke all on table public.municipality_departments from anon, authenticated;
revoke all on table public.municipality_members from anon, authenticated;
revoke all on table public.municipality_member_departments from anon, authenticated;
revoke all on table public.app_roles from anon, authenticated;
revoke all on table public.anchor_user_roles from anon, authenticated;
revoke all on table public.municipality_member_roles from anon, authenticated;
revoke all on table public.anchor_municipality_assignments from anon, authenticated;

grant select, insert on public.profiles to authenticated;
grant update (display_name) on public.profiles to authenticated;
grant select on public.municipalities to authenticated;
grant select on public.municipality_departments to authenticated;
grant select on public.municipality_members to authenticated;
grant select on public.municipality_member_departments to authenticated;
grant select on public.app_roles to authenticated;
grant select on public.municipality_member_roles to authenticated;
grant select on public.anchor_municipality_assignments to authenticated;

create policy profiles_select_self on public.profiles
  for select to authenticated using ((select auth.uid()) = id);
create policy profiles_insert_self on public.profiles
  for insert to authenticated with check ((select auth.uid()) = id and status = 'active');
create policy profiles_update_self on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id and status = 'active');

create policy municipalities_select_authorized_context on public.municipalities
  for select to authenticated using (private.has_tenant_metadata_access(id));
create policy departments_select_authorized_context on public.municipality_departments
  for select to authenticated using (private.has_tenant_metadata_access(municipality_id));
create policy memberships_select_self_or_superadmin on public.municipality_members
  for select to authenticated
  using (user_id = (select auth.uid()) or private.is_anchor_superadmin());
create policy member_departments_select_self_or_superadmin on public.municipality_member_departments
  for select to authenticated
  using (private.owns_active_membership(membership_id) or private.is_anchor_superadmin());
create policy app_roles_select_authenticated on public.app_roles
  for select to authenticated using (true);
create policy municipality_member_roles_select_self_or_superadmin on public.municipality_member_roles
  for select to authenticated
  using (private.owns_active_membership(membership_id) or private.is_anchor_superadmin());
create policy anchor_assignments_select_self_or_superadmin on public.anchor_municipality_assignments
  for select to authenticated
  using (anchor_user_id = (select auth.uid()) or private.is_anchor_superadmin());

commit;