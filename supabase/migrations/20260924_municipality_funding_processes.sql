-- ETAPA 20.3.17 - Fundacao do processo municipal de captacao.
-- Execucao manual exclusiva no ambiente DEV apos revisao.

begin;

-- Escrita operacional: superadmin ou membership ativa com papel municipal
-- explicitamente autorizado. Anchor operator nao recebe escrita por esta funcao.
create or replace function private.can_manage_municipality_funding_process(
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

revoke all on function private.can_manage_municipality_funding_process(uuid) from public;
grant execute on function private.can_manage_municipality_funding_process(uuid) to authenticated;

-- Chave candidata composta para permitir FKs que carreguem o tenant junto
-- com a oportunidade municipal e impeçam relacionamentos entre municipios.
alter table public.municipality_opportunities
  add constraint municipality_opportunities_id_municipality_key
  unique (id, municipality_id);

create table public.municipality_funding_processes (
  id uuid primary key default gen_random_uuid(),
  municipality_id uuid not null,
  municipality_opportunity_id uuid not null,
  responsible_membership_id uuid null,
  object_description text not null,
  status text not null default 'preparing',
  requested_amount numeric(18, 2) null,
  internal_deadline date null,
  proposal_number text null,
  protocol_number text null,
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint municipality_funding_processes_municipality_fkey
    foreign key (municipality_id)
    references public.municipalities (id)
    on delete restrict,

  constraint municipality_funding_processes_opportunity_tenant_fkey
    foreign key (municipality_opportunity_id, municipality_id)
    references public.municipality_opportunities (id, municipality_id)
    on delete restrict,

  constraint municipality_funding_processes_responsible_tenant_fkey
    foreign key (responsible_membership_id, municipality_id)
    references public.municipality_members (id, municipality_id)
    on delete restrict,

  constraint municipality_funding_processes_object_description_check
    check (
      char_length(btrim(object_description)) between 1 and 500
    ),

  constraint municipality_funding_processes_status_check
    check (
      status in (
        'preparing',
        'documentation',
        'submitted',
        'under_review',
        'approved',
        'rejected',
        'cancelled'
      )
    ),

  constraint municipality_funding_processes_requested_amount_check
    check (requested_amount is null or requested_amount >= 0),

  constraint municipality_funding_processes_proposal_number_check
    check (
      proposal_number is null
      or char_length(btrim(proposal_number)) between 1 and 200
    ),

  constraint municipality_funding_processes_protocol_number_check
    check (
      protocol_number is null
      or char_length(btrim(protocol_number)) between 1 and 200
    ),

  constraint municipality_funding_processes_notes_check
    check (
      notes is null
      or char_length(btrim(notes)) between 1 and 4000
    )
);

create index municipality_funding_processes_municipality_status_idx
  on public.municipality_funding_processes (municipality_id, status);

create index municipality_funding_processes_opportunity_idx
  on public.municipality_funding_processes (municipality_opportunity_id);

create index municipality_funding_processes_responsible_idx
  on public.municipality_funding_processes (responsible_membership_id)
  where responsible_membership_id is not null;

create index municipality_funding_processes_internal_deadline_idx
  on public.municipality_funding_processes (municipality_id, internal_deadline)
  where internal_deadline is not null;

create trigger municipality_funding_processes_touch_updated_at
  before update on public.municipality_funding_processes
  for each row execute function private.touch_updated_at();

-- Um novo processo somente pode nascer de uma oportunidade que a Prefeitura
-- tenha marcado como interessada. Depois de criado, o historico do processo
-- permanece independente de eventual mudanca posterior na decisao municipal.
create or replace function private.validate_municipality_funding_process_insert()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if not exists (
    select 1
    from public.municipality_opportunities as municipality_opportunity
    where municipality_opportunity.id = new.municipality_opportunity_id
      and municipality_opportunity.municipality_id = new.municipality_id
      and municipality_opportunity.status = 'interested'
  ) then
    raise exception
      'O processo de captacao somente pode ser criado para uma oportunidade municipal interessada.';
  end if;

  if new.responsible_membership_id is not null
     and not exists (
       select 1
       from public.municipality_members as membership
       where membership.id = new.responsible_membership_id
         and membership.municipality_id = new.municipality_id
         and membership.status = 'active'::public.membership_status
     )
  then
    raise exception
      'O responsavel deve possuir membership ativa no municipio do processo.';
  end if;

  return new;
end;
$$;

revoke all on function private.validate_municipality_funding_process_insert() from public;

create trigger municipality_funding_processes_validate_insert
  before insert on public.municipality_funding_processes
  for each row
  execute function private.validate_municipality_funding_process_insert();

-- Em atualizacoes, se houver responsavel, ele tambem deve continuar sendo
-- uma membership ativa pertencente ao mesmo municipio.
create or replace function private.validate_municipality_funding_process_update()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if new.municipality_id is distinct from old.municipality_id
     or new.municipality_opportunity_id is distinct from old.municipality_opportunity_id
  then
    raise exception
      'Municipio e oportunidade municipal nao podem ser alterados apos a criacao do processo.';
  end if;

  if new.responsible_membership_id is not null
     and not exists (
       select 1
       from public.municipality_members as membership
       where membership.id = new.responsible_membership_id
         and membership.municipality_id = new.municipality_id
         and membership.status = 'active'::public.membership_status
     )
  then
    raise exception
      'O responsavel deve possuir membership ativa no municipio do processo.';
  end if;

  return new;
end;
$$;

revoke all on function private.validate_municipality_funding_process_update() from public;

create trigger municipality_funding_processes_validate_update
  before update on public.municipality_funding_processes
  for each row
  execute function private.validate_municipality_funding_process_update();

alter table public.municipality_funding_processes enable row level security;
alter table public.municipality_funding_processes force row level security;

revoke all on table public.municipality_funding_processes from anon, authenticated;

grant select on public.municipality_funding_processes to authenticated;

grant insert (
  municipality_id,
  municipality_opportunity_id,
  responsible_membership_id,
  object_description,
  status,
  requested_amount,
  internal_deadline,
  proposal_number,
  protocol_number,
  notes
) on public.municipality_funding_processes to authenticated;

grant update (
  responsible_membership_id,
  object_description,
  status,
  requested_amount,
  internal_deadline,
  proposal_number,
  protocol_number,
  notes
) on public.municipality_funding_processes to authenticated;

create policy municipality_funding_processes_select_authorized_context
  on public.municipality_funding_processes
  for select to authenticated
  using (private.has_tenant_metadata_access(municipality_id));

create policy municipality_funding_processes_insert_managers
  on public.municipality_funding_processes
  for insert to authenticated
  with check (
    private.can_manage_municipality_funding_process(municipality_id)
  );

create policy municipality_funding_processes_update_managers
  on public.municipality_funding_processes
  for update to authenticated
  using (
    private.can_manage_municipality_funding_process(municipality_id)
  )
  with check (
    private.can_manage_municipality_funding_process(municipality_id)
  );

-- Auditoria imutavel dos processos de captacao.
create table public.municipality_funding_process_audit (
  id uuid primary key default gen_random_uuid(),
  funding_process_id uuid not null,
  municipality_id uuid not null,
  action text not null,
  actor_user_id uuid null references auth.users (id) on delete set null,
  old_data jsonb null,
  new_data jsonb null,
  created_at timestamptz not null default now(),

  constraint municipality_funding_process_audit_process_fkey
    foreign key (funding_process_id)
    references public.municipality_funding_processes (id)
    on delete restrict,

  constraint municipality_funding_process_audit_action_check
    check (action in ('insert', 'update')),

  constraint municipality_funding_process_audit_payload_check
    check (
      (action = 'insert' and old_data is null and new_data is not null)
      or
      (action = 'update' and old_data is not null and new_data is not null)
    )
);

create index municipality_funding_process_audit_process_idx
  on public.municipality_funding_process_audit (funding_process_id, created_at desc);

create index municipality_funding_process_audit_municipality_idx
  on public.municipality_funding_process_audit (municipality_id, created_at desc);

create or replace function private.audit_municipality_funding_process_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  insert into public.municipality_funding_process_audit (
    funding_process_id,
    municipality_id,
    action,
    actor_user_id,
    old_data,
    new_data
  ) values (
    new.id,
    new.municipality_id,
    case when tg_op = 'INSERT' then 'insert' else 'update' end,
    (select auth.uid()),
    case when tg_op = 'INSERT' then null else to_jsonb(old) end,
    to_jsonb(new)
  );

  return new;
end;
$$;

revoke all on function private.audit_municipality_funding_process_change() from public;

create trigger municipality_funding_processes_audit_insert
  after insert on public.municipality_funding_processes
  for each row
  execute function private.audit_municipality_funding_process_change();

create trigger municipality_funding_processes_audit_update
  after update of
    responsible_membership_id,
    object_description,
    status,
    requested_amount,
    internal_deadline,
    proposal_number,
    protocol_number,
    notes
  on public.municipality_funding_processes
  for each row
  when (
    old.responsible_membership_id is distinct from new.responsible_membership_id
    or old.object_description is distinct from new.object_description
    or old.status is distinct from new.status
    or old.requested_amount is distinct from new.requested_amount
    or old.internal_deadline is distinct from new.internal_deadline
    or old.proposal_number is distinct from new.proposal_number
    or old.protocol_number is distinct from new.protocol_number
    or old.notes is distinct from new.notes
  )
  execute function private.audit_municipality_funding_process_change();

alter table public.municipality_funding_process_audit enable row level security;
alter table public.municipality_funding_process_audit force row level security;

revoke all on table public.municipality_funding_process_audit from anon, authenticated;
grant select on public.municipality_funding_process_audit to authenticated;

create policy municipality_funding_process_audit_select_authorized_context
  on public.municipality_funding_process_audit
  for select to authenticated
  using (private.has_tenant_metadata_access(municipality_id));

commit;
