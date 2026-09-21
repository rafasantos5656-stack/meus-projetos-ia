-- Etapa 20.2.2 — fundação global do catálogo de oportunidades.
-- Execução manual exclusiva no ambiente DEV após revisão.

begin;

create table public.opportunity_sources (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  sphere text null,
  official_base_url text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint opportunity_sources_code_not_blank_check
    check (char_length(btrim(code)) > 0),
  constraint opportunity_sources_name_not_blank_check
    check (char_length(btrim(name)) > 0),
  constraint opportunity_sources_official_base_url_check
    check (
      char_length(btrim(official_base_url)) > 0
      and btrim(official_base_url) ~* '^https?://'
    ),
  constraint opportunity_sources_sphere_check
    check (sphere is null or sphere in ('federal', 'state', 'municipal', 'other'))
);

create table public.opportunities (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references public.opportunity_sources (id) on delete restrict,
  external_id text not null,
  sphere text not null,
  granting_body text null,
  program_name text null,
  title text not null,
  description text null,
  eligibility_summary text null,
  coverage_type text not null default 'unknown',
  eligible_ufs text[] null,
  amount numeric(18, 2) null,
  amount_kind text null,
  opens_on date null,
  closes_on date null,
  status text not null default 'upcoming',
  official_url text not null,
  source_updated_at timestamptz null,
  last_checked_at timestamptz null,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint opportunities_source_external_key unique (source_id, external_id),
  constraint opportunities_external_id_not_blank_check
    check (char_length(btrim(external_id)) > 0),
  constraint opportunities_title_not_blank_check
    check (char_length(btrim(title)) > 0),
  constraint opportunities_sphere_check
    check (sphere in ('federal', 'state', 'municipal', 'other')),
  constraint opportunities_coverage_type_check
    check (coverage_type in ('national', 'selected_ufs', 'territorial_rule', 'unknown')),
  constraint opportunities_selected_ufs_check
    check (
      coverage_type <> 'selected_ufs'
      or coalesce(cardinality(eligible_ufs), 0) > 0
    ),
  constraint opportunities_amount_check
    check (amount is null or amount >= 0),
  constraint opportunities_amount_kind_check
    check (
      amount_kind is null
      or amount_kind in ('total_available', 'maximum_per_proposal', 'minimum_per_proposal', 'other')
    ),
  constraint opportunities_status_check
    check (status in ('upcoming', 'open', 'closed', 'suspended', 'cancelled', 'archived')),
  constraint opportunities_official_url_check
    check (
      char_length(btrim(official_url)) > 0
      and btrim(official_url) ~* '^https?://'
    ),
  constraint opportunities_dates_check
    check (opens_on is null or closes_on is null or opens_on <= closes_on)
);

create table public.opportunity_policy_areas (
  opportunity_id uuid not null references public.opportunities (id) on delete restrict,
  policy_area_id uuid not null references public.policy_areas (id) on delete restrict,
  primary key (opportunity_id, policy_area_id)
);

create table public.opportunity_versions (
  id uuid primary key default gen_random_uuid(),
  opportunity_id uuid not null references public.opportunities (id) on delete restrict,
  version_number integer not null,
  captured_at timestamptz not null default now(),
  source_updated_at timestamptz null,
  change_hash text not null,
  snapshot jsonb not null,
  constraint opportunity_versions_opportunity_version_key unique (opportunity_id, version_number),
  constraint opportunity_versions_version_number_check
    check (version_number > 0),
  constraint opportunity_versions_change_hash_not_blank_check
    check (char_length(btrim(change_hash)) > 0),
  constraint opportunity_versions_snapshot_object_check
    check (jsonb_typeof(snapshot) = 'object')
);

create index opportunities_published_status_closes_on_idx
  on public.opportunities (is_published, status, closes_on);

create index opportunities_source_last_checked_at_idx
  on public.opportunities (source_id, last_checked_at);

create index opportunity_policy_areas_policy_area_opportunity_idx
  on public.opportunity_policy_areas (policy_area_id, opportunity_id);

create index opportunity_versions_opportunity_captured_at_idx
  on public.opportunity_versions (opportunity_id, captured_at desc);

create trigger opportunity_sources_touch_updated_at
  before update on public.opportunity_sources
  for each row execute function private.touch_updated_at();

create trigger opportunities_touch_updated_at
  before update on public.opportunities
  for each row execute function private.touch_updated_at();

alter table public.opportunity_sources enable row level security;
alter table public.opportunities enable row level security;
alter table public.opportunity_policy_areas enable row level security;
alter table public.opportunity_versions enable row level security;

alter table public.opportunity_sources force row level security;
alter table public.opportunities force row level security;
alter table public.opportunity_policy_areas force row level security;
alter table public.opportunity_versions force row level security;

revoke all on table public.opportunity_sources from anon, authenticated;
revoke all on table public.opportunities from anon, authenticated;
revoke all on table public.opportunity_policy_areas from anon, authenticated;
revoke all on table public.opportunity_versions from anon, authenticated;

grant select on public.opportunity_sources to authenticated;
grant select on public.opportunities to authenticated;
grant select on public.opportunity_policy_areas to authenticated;

create policy opportunity_sources_select_active_authenticated
  on public.opportunity_sources
  for select to authenticated
  using (active = true);

create policy opportunities_select_published_authenticated
  on public.opportunities
  for select to authenticated
  using (is_published = true);

create policy opportunity_policy_areas_select_published_authenticated
  on public.opportunity_policy_areas
  for select to authenticated
  using (
    exists (
      select 1
      from public.opportunities as opportunity
      where opportunity.id = opportunity_policy_areas.opportunity_id
        and opportunity.is_published = true
    )
  );

commit;