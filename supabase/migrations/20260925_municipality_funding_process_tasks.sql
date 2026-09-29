-- ETAPA 20.3.18 - Tarefas e prazos do processo municipal de captacao.
-- Execucao manual exclusiva no ambiente DEV apos revisao.

begin;

-- Chave candidata composta para que as tarefas carreguem o tenant
-- juntamente com o processo e nao possam cruzar municipios.
alter table public.municipality_funding_processes
  add constraint municipality_funding_processes_id_municipality_key
  unique (id, municipality_id);

create table public.municipality_funding_process_tasks (
  id uuid primary key default gen_random_uuid(),
  municipality_id uuid not null,
  funding_process_id uuid not null,
  responsible_membership_id uuid null,
  title text not null,
  description text null,
  status text not null default 'pending',
  priority text not null default 'normal',
  due_date date null,
  completed_at timestamptz null,
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint municipality_funding_process_tasks_municipality_fkey
    foreign key (municipality_id)
    references public.municipalities (id)
    on delete restrict,

  constraint municipality_funding_process_tasks_process_tenant_fkey
    foreign key (funding_process_id, municipality_id)
    references public.municipality_funding_processes (id, municipality_id)
    on delete restrict,

  constraint municipality_funding_process_tasks_responsible_tenant_fkey
    foreign key (responsible_membership_id, municipality_id)
    references public.municipality_members (id, municipality_id)
    on delete restrict,

  constraint municipality_funding_process_tasks_title_check
    check (char_length(btrim(title)) between 1 and 240),

  constraint municipality_funding_process_tasks_description_check
    check (
      description is null
      or char_length(btrim(description)) between 1 and 2000
    ),

  constraint municipality_funding_process_tasks_status_check
    check (
      status in (
        'pending',
        'in_progress',
        'completed',
        'cancelled'
      )
    ),

  constraint municipality_funding_process_tasks_priority_check
    check (
      priority in (
        'low',
        'normal',
        'high',
        'urgent'
      )
    ),

  constraint municipality_funding_process_tasks_notes_check
    check (
      notes is null
      or char_length(btrim(notes)) between 1 and 4000
    ),

  constraint municipality_funding_process_tasks_completion_check
    check (
      (status = 'completed' and completed_at is not null)
      or
      (status <> 'completed' and completed_at is null)
    )
);

create index municipality_funding_process_tasks_process_status_idx
  on public.municipality_funding_process_tasks (funding_process_id, status);

create index municipality_funding_process_tasks_municipality_due_date_idx
  on public.municipality_funding_process_tasks (municipality_id, due_date)
  where due_date is not null;

create index municipality_funding_process_tasks_responsible_status_idx
  on public.municipality_funding_process_tasks (
    responsible_membership_id,
    status
  )
  where responsible_membership_id is not null;

create trigger municipality_funding_process_tasks_touch_updated_at
  before update on public.municipality_funding_process_tasks
  for each row
  execute function private.touch_updated_at();

-- Se houver responsavel, ele deve possuir membership ativa
-- pertencente ao mesmo municipio da tarefa.
create or replace function private.validate_municipality_funding_process_task_insert()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
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
      'O responsavel deve possuir membership ativa no municipio da tarefa.';
  end if;

  return new;
end;
$$;

revoke all on function private.validate_municipality_funding_process_task_insert()
  from public;

create trigger municipality_funding_process_tasks_validate_insert
  before insert on public.municipality_funding_process_tasks
  for each row
  execute function private.validate_municipality_funding_process_task_insert();

-- Municipio e processo sao estruturais e permanecem imutaveis.
-- O responsavel, quando informado, deve continuar ativo no mesmo municipio.
create or replace function private.validate_municipality_funding_process_task_update()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if new.municipality_id is distinct from old.municipality_id
     or new.funding_process_id is distinct from old.funding_process_id
  then
    raise exception
      'Municipio e processo de captacao nao podem ser alterados apos a criacao da tarefa.';
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
      'O responsavel deve possuir membership ativa no municipio da tarefa.';
  end if;

  return new;
end;
$$;

revoke all on function private.validate_municipality_funding_process_task_update()
  from public;

create trigger municipality_funding_process_tasks_validate_update
  before update on public.municipality_funding_process_tasks
  for each row
  execute function private.validate_municipality_funding_process_task_update();

-- RLS e privilegios da tabela operacional de tarefas.

alter table public.municipality_funding_process_tasks enable row level security;
alter table public.municipality_funding_process_tasks force row level security;

revoke all on table public.municipality_funding_process_tasks
  from anon, authenticated;

grant select on table public.municipality_funding_process_tasks
  to authenticated;

grant insert (
  municipality_id,
  funding_process_id,
  responsible_membership_id,
  title,
  description,
  status,
  priority,
  due_date,
  completed_at,
  notes
) on public.municipality_funding_process_tasks
  to authenticated;

grant update (
  responsible_membership_id,
  title,
  description,
  status,
  priority,
  due_date,
  completed_at,
  notes
) on public.municipality_funding_process_tasks
  to authenticated;

create policy municipality_funding_process_tasks_select
  on public.municipality_funding_process_tasks
  for select
  to authenticated
  using (
    private.has_tenant_metadata_access(municipality_id)
  );

create policy municipality_funding_process_tasks_insert
  on public.municipality_funding_process_tasks
  for insert
  to authenticated
  with check (
    private.can_manage_municipality_funding_process(municipality_id)
  );

create policy municipality_funding_process_tasks_update
  on public.municipality_funding_process_tasks
  for update
  to authenticated
  using (
    private.can_manage_municipality_funding_process(municipality_id)
  )
  with check (
    private.can_manage_municipality_funding_process(municipality_id)
  );

-- DELETE permanece deliberadamente sem grant e sem policy.
-- Tarefas operacionais devem manter rastreabilidade historica.

-- Auditoria imutavel das tarefas dos processos municipais de captacao.

create table public.municipality_funding_process_task_audit (
  id uuid primary key default gen_random_uuid(),
  funding_process_task_id uuid not null,
  municipality_id uuid not null,
  action text not null,
  actor_user_id uuid null,
  old_data jsonb null,
  new_data jsonb null,
  created_at timestamptz not null default now(),

  constraint municipality_funding_process_task_audit_task_fkey
    foreign key (funding_process_task_id)
    references public.municipality_funding_process_tasks (id)
    on delete restrict,

  constraint municipality_funding_process_task_audit_municipality_fkey
    foreign key (municipality_id)
    references public.municipalities (id)
    on delete restrict,

  constraint municipality_funding_process_task_audit_action_check
    check (action in ('insert', 'update')),

  constraint municipality_funding_process_task_audit_payload_check
    check (
      (action = 'insert' and old_data is null and new_data is not null)
      or
      (action = 'update' and old_data is not null and new_data is not null)
    )
);

create index municipality_funding_process_task_audit_task_created_idx
  on public.municipality_funding_process_task_audit (
    funding_process_task_id,
    created_at
  );

create index municipality_funding_process_task_audit_municipality_created_idx
  on public.municipality_funding_process_task_audit (
    municipality_id,
    created_at
  );

create or replace function private.audit_municipality_funding_process_task()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.municipality_funding_process_task_audit (
      funding_process_task_id,
      municipality_id,
      action,
      actor_user_id,
      old_data,
      new_data
    )
    values (
      new.id,
      new.municipality_id,
      'insert',
      auth.uid(),
      null,
      to_jsonb(new)
    );

    return new;
  end if;

  if tg_op = 'UPDATE' then
    insert into public.municipality_funding_process_task_audit (
      funding_process_task_id,
      municipality_id,
      action,
      actor_user_id,
      old_data,
      new_data
    )
    values (
      new.id,
      new.municipality_id,
      'update',
      auth.uid(),
      to_jsonb(old),
      to_jsonb(new)
    );

    return new;
  end if;

  return null;
end;
$$;

revoke all on function private.audit_municipality_funding_process_task()
  from public;

create trigger municipality_funding_process_tasks_audit
  after insert or update on public.municipality_funding_process_tasks
  for each row
  execute function private.audit_municipality_funding_process_task();

alter table public.municipality_funding_process_task_audit
  enable row level security;

alter table public.municipality_funding_process_task_audit
  force row level security;

revoke all on table public.municipality_funding_process_task_audit
  from anon, authenticated;

grant select on table public.municipality_funding_process_task_audit
  to authenticated;

create policy municipality_funding_process_task_audit_select
  on public.municipality_funding_process_task_audit
  for select
  to authenticated
  using (
    private.has_tenant_metadata_access(municipality_id)
  );

-- Nenhum INSERT, UPDATE ou DELETE direto e concedido na auditoria.
-- As gravacoes ocorrem exclusivamente pelo trigger SECURITY DEFINER.

comment on table public.municipality_funding_process_tasks is
  'Tarefas e prazos operacionais vinculados aos processos municipais de captacao.';

comment on column public.municipality_funding_process_tasks.funding_process_id is
  'Processo municipal de captacao ao qual a tarefa pertence.';

comment on column public.municipality_funding_process_tasks.responsible_membership_id is
  'Membership municipal ativa responsavel pela tarefa, quando definida.';

comment on column public.municipality_funding_process_tasks.status is
  'Estado operacional: pending, in_progress, completed ou cancelled.';

comment on column public.municipality_funding_process_tasks.priority is
  'Prioridade operacional: low, normal, high ou urgent.';

comment on column public.municipality_funding_process_tasks.due_date is
  'Prazo operacional da tarefa, quando definido.';

comment on table public.municipality_funding_process_task_audit is
  'Historico imutavel de criacoes e alteracoes das tarefas dos processos municipais de captacao.';

commit;