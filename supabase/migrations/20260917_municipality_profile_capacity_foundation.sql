-- Fundação do perfil e capacidade municipal — somente leitura nesta etapa.
-- Não altera projects, tasks, estruturas legadas ou permissões de escrita.

begin;

create table public.policy_areas (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint policy_areas_code_format_check
    check (code = lower(code) and code ~ '^[a-z][a-z0-9_]{1,79}$'),
  constraint policy_areas_name_check check (char_length(btrim(name)) between 1 and 160),
  constraint policy_areas_status_check check (status in ('active', 'inactive'))
);

create table public.capability_dimensions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text null,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint capability_dimensions_code_format_check
    check (code = lower(code) and code ~ '^[a-z][a-z0-9_]{1,79}$'),
  constraint capability_dimensions_name_check check (char_length(btrim(name)) between 1 and 160),
  constraint capability_dimensions_description_check
    check (description is null or char_length(btrim(description)) between 1 and 1000),
  constraint capability_dimensions_status_check check (status in ('active', 'inactive'))
);

create table public.municipality_priority_areas (
  id uuid primary key default gen_random_uuid(),
  municipality_id uuid not null references public.municipalities (id) on delete restrict,
  policy_area_id uuid not null references public.policy_areas (id) on delete restrict,
  priority_level text not null,
  notes text null,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint municipality_priority_areas_municipality_policy_area_key
    unique (municipality_id, policy_area_id),
  constraint municipality_priority_areas_priority_level_check
    check (priority_level in ('low', 'medium', 'high')),
  constraint municipality_priority_areas_notes_check
    check (notes is null or char_length(btrim(notes)) between 1 and 2000),
  constraint municipality_priority_areas_status_check check (status in ('active', 'inactive'))
);

create table public.municipality_capacity_profiles (
  municipality_id uuid primary key references public.municipalities (id) on delete restrict,
  accepts_counterpart boolean null,
  counterpart_capacity_level text not null default 'not_informed',
  counterpart_notes text null,
  overall_notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint municipality_capacity_profiles_counterpart_capacity_level_check
    check (counterpart_capacity_level in ('not_informed', 'limited', 'possible', 'adequate')),
  constraint municipality_capacity_profiles_counterpart_notes_check
    check (counterpart_notes is null or char_length(btrim(counterpart_notes)) between 1 and 2000),
  constraint municipality_capacity_profiles_overall_notes_check
    check (overall_notes is null or char_length(btrim(overall_notes)) between 1 and 4000)
);

create table public.municipality_capability_assessments (
  id uuid primary key default gen_random_uuid(),
  municipality_id uuid not null references public.municipalities (id) on delete restrict,
  capability_dimension_id uuid not null references public.capability_dimensions (id) on delete restrict,
  capacity_level text not null default 'not_informed',
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint municipality_capability_assessments_municipality_dimension_key
    unique (municipality_id, capability_dimension_id),
  constraint municipality_capability_assessments_capacity_level_check
    check (capacity_level in ('not_informed', 'unavailable', 'limited', 'adequate')),
  constraint municipality_capability_assessments_notes_check
    check (notes is null or char_length(btrim(notes)) between 1 and 2000)
);

create table public.municipality_demands (
  id uuid primary key default gen_random_uuid(),
  municipality_id uuid not null references public.municipalities (id) on delete restrict,
  policy_area_id uuid not null references public.policy_areas (id) on delete restrict,
  department_id uuid null,
  title text not null,
  description text null,
  status text not null default 'identified',
  priority_level text not null default 'medium',
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint municipality_demands_department_tenant_fkey
    foreign key (department_id, municipality_id)
    references public.municipality_departments (id, municipality_id)
    on delete restrict,
  constraint municipality_demands_title_check check (char_length(btrim(title)) between 1 and 240),
  constraint municipality_demands_description_check
    check (description is null or char_length(btrim(description)) between 1 and 5000),
  constraint municipality_demands_status_check
    check (status in ('identified', 'planned', 'in_preparation', 'active', 'paused', 'inactive')),
  constraint municipality_demands_priority_level_check
    check (priority_level in ('low', 'medium', 'high')),
  constraint municipality_demands_notes_check
    check (notes is null or char_length(btrim(notes)) between 1 and 4000)
);

create index municipality_priority_areas_municipality_status_priority_idx
  on public.municipality_priority_areas (municipality_id, status, priority_level);
create index municipality_capability_assessments_municipality_level_idx
  on public.municipality_capability_assessments (municipality_id, capacity_level);
create index municipality_demands_municipality_status_priority_idx
  on public.municipality_demands (municipality_id, status, priority_level);
create index municipality_demands_municipality_policy_area_idx
  on public.municipality_demands (municipality_id, policy_area_id);
create index municipality_demands_department_idx
  on public.municipality_demands (municipality_id, department_id)
  where department_id is not null;

create trigger policy_areas_touch_updated_at
  before update on public.policy_areas
  for each row execute function private.touch_updated_at();
create trigger capability_dimensions_touch_updated_at
  before update on public.capability_dimensions
  for each row execute function private.touch_updated_at();
create trigger municipality_priority_areas_touch_updated_at
  before update on public.municipality_priority_areas
  for each row execute function private.touch_updated_at();
create trigger municipality_capacity_profiles_touch_updated_at
  before update on public.municipality_capacity_profiles
  for each row execute function private.touch_updated_at();
create trigger municipality_capability_assessments_touch_updated_at
  before update on public.municipality_capability_assessments
  for each row execute function private.touch_updated_at();
create trigger municipality_demands_touch_updated_at
  before update on public.municipality_demands
  for each row execute function private.touch_updated_at();

-- Seeds idempotentes por código estável; nenhum UUID é fixado.
insert into public.policy_areas (code, name, status)
values
  ('health', 'Saúde', 'active'),
  ('education', 'Educação', 'active'),
  ('social_assistance', 'Assistência Social', 'active'),
  ('infrastructure', 'Infraestrutura', 'active'),
  ('mobility', 'Mobilidade', 'active'),
  ('housing', 'Habitação', 'active'),
  ('agriculture', 'Agricultura', 'active'),
  ('environment', 'Meio Ambiente', 'active'),
  ('tourism', 'Turismo', 'active'),
  ('culture', 'Cultura', 'active'),
  ('sport', 'Esporte', 'active'),
  ('public_safety', 'Segurança', 'active'),
  ('economic_development', 'Desenvolvimento Econômico', 'active'),
  ('sanitation', 'Saneamento', 'active'),
  ('technology', 'Tecnologia', 'active'),
  ('civil_defense', 'Defesa Civil', 'active')
on conflict (code) do update
set name = excluded.name,
    status = excluded.status,
    updated_at = now();

insert into public.capability_dimensions (code, name, status)
values
  ('grants_management', 'Gestão de Convênios', 'active'),
  ('engineering_architecture', 'Engenharia e Arquitetura', 'active'),
  ('accounting', 'Contabilidade', 'active'),
  ('procurement', 'Licitações e Compras', 'active'),
  ('legal', 'Jurídico', 'active'),
  ('planning', 'Planejamento', 'active'),
  ('accountability', 'Prestação de Contas', 'active'),
  ('project_development', 'Elaboração de Projetos', 'active'),
  ('works_supervision', 'Fiscalização de Obras', 'active'),
  ('contract_management', 'Gestão de Contratos', 'active')
on conflict (code) do update
set name = excluded.name,
    status = excluded.status,
    updated_at = now();

-- Catálogos globais: leitura autenticada, sem políticas ou grants de escrita.
alter table public.policy_areas enable row level security;
alter table public.capability_dimensions enable row level security;
alter table public.policy_areas force row level security;
alter table public.capability_dimensions force row level security;
revoke all on table public.policy_areas from anon, authenticated;
revoke all on table public.capability_dimensions from anon, authenticated;
grant select on public.policy_areas to authenticated;
grant select on public.capability_dimensions to authenticated;
create policy policy_areas_select_authenticated
  on public.policy_areas for select to authenticated using (true);
create policy capability_dimensions_select_authenticated
  on public.capability_dimensions for select to authenticated using (true);

-- Dados municipais: RLS isolado por tenant e estritamente somente leitura.
alter table public.municipality_priority_areas enable row level security;
alter table public.municipality_capacity_profiles enable row level security;
alter table public.municipality_capability_assessments enable row level security;
alter table public.municipality_demands enable row level security;
alter table public.municipality_priority_areas force row level security;
alter table public.municipality_capacity_profiles force row level security;
alter table public.municipality_capability_assessments force row level security;
alter table public.municipality_demands force row level security;
revoke all on table public.municipality_priority_areas from anon, authenticated;
revoke all on table public.municipality_capacity_profiles from anon, authenticated;
revoke all on table public.municipality_capability_assessments from anon, authenticated;
revoke all on table public.municipality_demands from anon, authenticated;
grant select on public.municipality_priority_areas to authenticated;
grant select on public.municipality_capacity_profiles to authenticated;
grant select on public.municipality_capability_assessments to authenticated;
grant select on public.municipality_demands to authenticated;
create policy municipality_priority_areas_select_authorized_context
  on public.municipality_priority_areas for select to authenticated
  using (private.has_tenant_metadata_access(municipality_id));
create policy municipality_capacity_profiles_select_authorized_context
  on public.municipality_capacity_profiles for select to authenticated
  using (private.has_tenant_metadata_access(municipality_id));
create policy municipality_capability_assessments_select_authorized_context
  on public.municipality_capability_assessments for select to authenticated
  using (private.has_tenant_metadata_access(municipality_id));
create policy municipality_demands_select_authorized_context
  on public.municipality_demands for select to authenticated
  using (private.has_tenant_metadata_access(municipality_id));

commit;
