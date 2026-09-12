-- Perfil institucional municipal — revisão obrigatória antes de aplicar no DEV.
-- Não altera estruturas legadas, projects, tasks ou as policies existentes.

begin;

create table public.municipality_institutional_profiles (
  municipality_id uuid primary key references public.municipalities (id) on delete restrict,
  mayor_name text null check (mayor_name is null or char_length(btrim(mayor_name)) between 1 and 160),
  official_website text null check (
    official_website is null
    or (char_length(btrim(official_website)) between 8 and 500 and btrim(official_website) ~* '^https?://')
  ),
  institutional_phone text null check (institutional_phone is null or char_length(btrim(institutional_phone)) between 8 and 40),
  institutional_email text null check (
    institutional_email is null
    or (char_length(btrim(institutional_email)) between 3 and 320 and btrim(institutional_email) ~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.municipality_addresses (
  id uuid primary key default gen_random_uuid(),
  municipality_id uuid not null unique references public.municipalities (id) on delete restrict,
  postal_code text null check (postal_code is null or btrim(postal_code) ~ '^[0-9]{5}-?[0-9]{3}$'),
  street text null check (street is null or char_length(btrim(street)) between 1 and 240),
  number text null check (number is null or char_length(btrim(number)) between 1 and 40),
  complement text null check (complement is null or char_length(btrim(complement)) between 1 and 160),
  district text null check (district is null or char_length(btrim(district)) between 1 and 160),
  city text null check (city is null or char_length(btrim(city)) between 1 and 160),
  state char(2) null check (state is null or (state = upper(state) and state ~ '^[A-Z]{2}$')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.municipality_population_records (
  id uuid primary key default gen_random_uuid(),
  municipality_id uuid not null references public.municipalities (id) on delete restrict,
  reference_year integer not null check (reference_year between 1800 and 2100),
  population bigint not null check (population >= 0),
  source_name text not null check (char_length(btrim(source_name)) between 1 and 160),
  source_url text null check (
    source_url is null
    or (char_length(btrim(source_url)) between 8 and 500 and btrim(source_url) ~* '^https?://')
  ),
  source_checked_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.municipality_department_contacts (
  id uuid primary key default gen_random_uuid(),
  municipality_id uuid not null,
  department_id uuid not null,
  membership_id uuid null,
  full_name text not null check (char_length(btrim(full_name)) between 1 and 160),
  job_title text null check (job_title is null or char_length(btrim(job_title)) between 1 and 160),
  email text null check (
    email is null
    or (char_length(btrim(email)) between 3 and 320 and btrim(email) ~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$')
  ),
  phone text null check (phone is null or char_length(btrim(phone)) between 8 and 40),
  is_primary boolean not null default false,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint municipality_department_contacts_department_tenant_fkey
    foreign key (department_id, municipality_id)
    references public.municipality_departments (id, municipality_id)
    on delete restrict,
  constraint municipality_department_contacts_membership_tenant_fkey
    foreign key (membership_id, municipality_id)
    references public.municipality_members (id, municipality_id)
    on delete restrict
);

create unique index municipality_population_records_source_year_unique
  on public.municipality_population_records (municipality_id, reference_year, lower(btrim(source_name)));

create index municipality_population_records_municipality_year_idx
  on public.municipality_population_records (municipality_id, reference_year desc);

create index municipality_department_contacts_municipality_department_idx
  on public.municipality_department_contacts (municipality_id, department_id);

create index municipality_department_contacts_membership_idx
  on public.municipality_department_contacts (membership_id)
  where membership_id is not null;

create unique index municipality_department_contacts_one_primary_active_unique
  on public.municipality_department_contacts (department_id)
  where is_primary and status = 'active';

create trigger municipality_institutional_profiles_touch_updated_at
  before update on public.municipality_institutional_profiles
  for each row execute function private.touch_updated_at();

create trigger municipality_addresses_touch_updated_at
  before update on public.municipality_addresses
  for each row execute function private.touch_updated_at();

create trigger municipality_population_records_touch_updated_at
  before update on public.municipality_population_records
  for each row execute function private.touch_updated_at();

create trigger municipality_department_contacts_touch_updated_at
  before update on public.municipality_department_contacts
  for each row execute function private.touch_updated_at();

alter table public.municipality_institutional_profiles enable row level security;
alter table public.municipality_addresses enable row level security;
alter table public.municipality_population_records enable row level security;
alter table public.municipality_department_contacts enable row level security;

alter table public.municipality_institutional_profiles force row level security;
alter table public.municipality_addresses force row level security;
alter table public.municipality_population_records force row level security;
alter table public.municipality_department_contacts force row level security;

revoke all on table public.municipality_institutional_profiles from anon, authenticated;
revoke all on table public.municipality_addresses from anon, authenticated;
revoke all on table public.municipality_population_records from anon, authenticated;
revoke all on table public.municipality_department_contacts from anon, authenticated;

grant select on public.municipality_institutional_profiles to authenticated;
grant select on public.municipality_addresses to authenticated;
grant select on public.municipality_population_records to authenticated;
grant select on public.municipality_department_contacts to authenticated;

create policy municipality_institutional_profiles_select_authorized_context
  on public.municipality_institutional_profiles
  for select to authenticated
  using (private.has_tenant_metadata_access(municipality_id));

create policy municipality_addresses_select_authorized_context
  on public.municipality_addresses
  for select to authenticated
  using (private.has_tenant_metadata_access(municipality_id));

create policy municipality_population_records_select_authorized_context
  on public.municipality_population_records
  for select to authenticated
  using (private.has_tenant_metadata_access(municipality_id));

create policy municipality_department_contacts_select_authorized_context
  on public.municipality_department_contacts
  for select to authenticated
  using (private.has_tenant_metadata_access(municipality_id));

commit;