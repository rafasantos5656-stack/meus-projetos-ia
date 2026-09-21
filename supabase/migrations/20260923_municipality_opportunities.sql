-- Etapa 20.3.3 — decisões municipais sobre oportunidades globais.
-- Execução manual exclusiva no ambiente DEV após revisão.

begin;

-- Escrita operacional: superadmin ou membership ativa com papel municipal
-- explicitamente autorizado. Assignment de anchor_operator não concede escrita.
create or replace function private.can_manage_municipality_opportunity(
  target_municipality_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select
    (select auth.uid()) is not null
    and (
      private.is_anchor_superadmin()
      or private.has_active_municipality_role(
        target_municipality_id,
        'municipality_admin'
      )
      or private.has_active_municipality_role(
        target_municipality_id,
        'grants_manager'
      )
    );
$$;

revoke all on function private.can_manage_municipality_opportunity(uuid) from public;
grant execute on function private.can_manage_municipality_opportunity(uuid) to authenticated;

create table public.municipality_opportunities (
  id uuid primary key default gen_random_uuid(),
  municipality_id uuid not null,
  opportunity_id uuid not null,
  status text not null default 'analyzing',
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint municipality_opportunities_municipality_fkey
    foreign key (municipality_id)
    references public.municipalities (id)
    on delete restrict,
  constraint municipality_opportunities_opportunity_fkey
    foreign key (opportunity_id)
    references public.opportunities (id)
    on delete restrict,
  constraint municipality_opportunities_municipality_opportunity_key
    unique (municipality_id, opportunity_id),
  constraint municipality_opportunities_status_check
    check (status in ('analyzing', 'interested', 'review_later', 'not_applicable')),
  constraint municipality_opportunities_notes_check
    check (notes is null or char_length(btrim(notes)) between 1 and 4000)
);

create index municipality_opportunities_municipality_status_idx
  on public.municipality_opportunities (municipality_id, status);

-- A FK não cria índice no lado referenciante; este índice evita varreduras em
-- verificações de integridade e apoia consultas administrativas futuras.
create index municipality_opportunities_opportunity_idx
  on public.municipality_opportunities (opportunity_id);

create trigger municipality_opportunities_touch_updated_at
  before update on public.municipality_opportunities
  for each row execute function private.touch_updated_at();

alter table public.municipality_opportunities enable row level security;
alter table public.municipality_opportunities force row level security;

revoke all on table public.municipality_opportunities from anon, authenticated;

grant select on public.municipality_opportunities to authenticated;
grant insert (
  municipality_id,
  opportunity_id,
  status,
  notes
) on public.municipality_opportunities to authenticated;
grant update (
  status,
  notes
) on public.municipality_opportunities to authenticated;

create policy municipality_opportunities_select_authorized_context
  on public.municipality_opportunities
  for select to authenticated
  using (private.has_tenant_metadata_access(municipality_id));

create policy municipality_opportunities_insert_managers
  on public.municipality_opportunities
  for insert to authenticated
  with check (
    private.can_manage_municipality_opportunity(municipality_id)
    and exists (
      select 1
      from public.opportunities as opportunity
      where opportunity.id = municipality_opportunities.opportunity_id
        and opportunity.is_published = true
    )
  );

create policy municipality_opportunities_update_managers
  on public.municipality_opportunities
  for update to authenticated
  using (private.can_manage_municipality_opportunity(municipality_id))
  with check (private.can_manage_municipality_opportunity(municipality_id));

-- Histórico imutável: municipality_id e opportunity_id são cópias da linha
-- auditada para filtragem por tenant e leitura operacional. A escrita é apenas
-- realizada pelo trigger abaixo.
create table public.municipality_opportunity_audit (
  id uuid primary key default gen_random_uuid(),
  municipality_opportunity_id uuid not null,
  municipality_id uuid not null,
  opportunity_id uuid not null,
  action text not null,
  actor_user_id uuid null references auth.users (id) on delete set null,
  old_data jsonb null,
  new_data jsonb null,
  created_at timestamptz not null default now(),
  constraint municipality_opportunity_audit_relation_fkey
    foreign key (municipality_opportunity_id)
    references public.municipality_opportunities (id)
    on delete restrict,
  constraint municipality_opportunity_audit_action_check
    check (action in ('insert', 'update')),
  constraint municipality_opportunity_audit_payload_check
    check (
      (action = 'insert' and old_data is null and new_data is not null)
      or (action = 'update' and old_data is not null and new_data is not null)
    )
);

create or replace function private.audit_municipality_opportunity_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  insert into public.municipality_opportunity_audit (
    municipality_opportunity_id,
    municipality_id,
    opportunity_id,
    action,
    actor_user_id,
    old_data,
    new_data
  ) values (
    new.id,
    new.municipality_id,
    new.opportunity_id,
    case when tg_op = 'INSERT' then 'insert' else 'update' end,
    (select auth.uid()),
    case when tg_op = 'INSERT' then null else to_jsonb(old) end,
    to_jsonb(new)
  );

  return new;
end;
$$;

revoke all on function private.audit_municipality_opportunity_change() from public;

create trigger municipality_opportunities_audit_insert
  after insert on public.municipality_opportunities
  for each row
  execute function private.audit_municipality_opportunity_change();

create trigger municipality_opportunities_audit_update
  after update of status, notes on public.municipality_opportunities
  for each row
  when (
    old.status is distinct from new.status
    or old.notes is distinct from new.notes
  )
  execute function private.audit_municipality_opportunity_change();

alter table public.municipality_opportunity_audit enable row level security;
alter table public.municipality_opportunity_audit force row level security;

revoke all on table public.municipality_opportunity_audit from anon, authenticated;
grant select on public.municipality_opportunity_audit to authenticated;

create policy municipality_opportunity_audit_select_authorized_context
  on public.municipality_opportunity_audit
  for select to authenticated
  using (private.has_tenant_metadata_access(municipality_id));

commit;