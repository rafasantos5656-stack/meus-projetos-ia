-- Escrita controlada e auditoria do perfil e capacidade municipal.
-- DEV somente até revisão e aplicação manual. Não altera frontend, projects ou tasks.
-- Depende de 20260909, 20260912 e 20260917.

begin;

-- Centraliza a decisão de escrita. anchor_operator e papéis funcionais
-- permanecem somente leitura, independentemente do comportamento do frontend.
create or replace function private.can_manage_municipality_profile_capacity(
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

revoke all on function private.can_manage_municipality_profile_capacity(uuid) from public;
grant execute on function private.can_manage_municipality_profile_capacity(uuid) to authenticated;

-- Histórico único e imutável das quatro entidades desta fundação. record_id é
-- polimórfico: para municipality_capacity_profiles, equivale ao municipality_id.
-- A fonte e os payloads são montados somente pelo trigger, nunca pelo cliente.
create table public.municipality_profile_capacity_audit (
  id uuid primary key default gen_random_uuid(),
  municipality_id uuid not null references public.municipalities (id) on delete restrict,
  entity_type text not null check (
    entity_type in (
      'municipality_priority_areas',
      'municipality_capacity_profiles',
      'municipality_capability_assessments',
      'municipality_demands'
    )
  ),
  record_id uuid not null,
  actor_user_id uuid null references auth.users (id) on delete set null,
  action text not null check (action in ('insert', 'update', 'activate', 'deactivate')),
  old_data jsonb null,
  new_data jsonb null,
  created_at timestamptz not null default now(),
  constraint municipality_profile_capacity_audit_payload_check check (
    (action = 'insert' and old_data is null and new_data is not null)
    or (action in ('update', 'activate', 'deactivate') and old_data is not null and new_data is not null)
  )
);

create index municipality_profile_capacity_audit_municipality_created_idx
  on public.municipality_profile_capacity_audit (municipality_id, created_at desc);

create index municipality_profile_capacity_audit_record_created_idx
  on public.municipality_profile_capacity_audit (entity_type, record_id, created_at desc);

-- O trigger usa apenas a linha persistida e auth.uid() da sessão que acionou a
-- mudança. Updates sem alteração relevante não chegam à função por causa dos WHEN.
create or replace function private.audit_municipality_profile_capacity_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  audit_entity_type text;
  audit_record_id uuid;
  audit_action text;
  audit_old_data jsonb;
  audit_new_data jsonb;
begin
  if tg_table_name = 'municipality_priority_areas' then
    audit_entity_type := 'municipality_priority_areas';
    audit_record_id := new.id;

    if tg_op = 'INSERT' then
      audit_action := 'insert';
      audit_old_data := null;
    else
      if old.status = 'active' and new.status = 'inactive' then
        audit_action := 'deactivate';
      elsif old.status = 'inactive' and new.status = 'active' then
        audit_action := 'activate';
      else
        audit_action := 'update';
      end if;

      audit_old_data := jsonb_build_object(
        'policy_area_id', old.policy_area_id,
        'priority_level', old.priority_level,
        'notes', old.notes,
        'status', old.status
      );
    end if;

    audit_new_data := jsonb_build_object(
      'policy_area_id', new.policy_area_id,
      'priority_level', new.priority_level,
      'notes', new.notes,
      'status', new.status
    );

  elsif tg_table_name = 'municipality_capacity_profiles' then
    audit_entity_type := 'municipality_capacity_profiles';
    audit_record_id := new.municipality_id;

    if tg_op = 'INSERT' then
      audit_action := 'insert';
      audit_old_data := null;
    else
      audit_action := 'update';
      audit_old_data := jsonb_build_object(
        'accepts_counterpart', old.accepts_counterpart,
        'counterpart_capacity_level', old.counterpart_capacity_level,
        'counterpart_notes', old.counterpart_notes,
        'overall_notes', old.overall_notes
      );
    end if;

    audit_new_data := jsonb_build_object(
      'accepts_counterpart', new.accepts_counterpart,
      'counterpart_capacity_level', new.counterpart_capacity_level,
      'counterpart_notes', new.counterpart_notes,
      'overall_notes', new.overall_notes
    );

  elsif tg_table_name = 'municipality_capability_assessments' then
    audit_entity_type := 'municipality_capability_assessments';
    audit_record_id := new.id;

    if tg_op = 'INSERT' then
      audit_action := 'insert';
      audit_old_data := null;
    else
      audit_action := 'update';
      audit_old_data := jsonb_build_object(
        'capability_dimension_id', old.capability_dimension_id,
        'capacity_level', old.capacity_level,
        'notes', old.notes
      );
    end if;

    audit_new_data := jsonb_build_object(
      'capability_dimension_id', new.capability_dimension_id,
      'capacity_level', new.capacity_level,
      'notes', new.notes
    );

  elsif tg_table_name = 'municipality_demands' then
    audit_entity_type := 'municipality_demands';
    audit_record_id := new.id;

    if tg_op = 'INSERT' then
      audit_action := 'insert';
      audit_old_data := null;
    else
      if old.status = 'active' and new.status = 'inactive' then
        audit_action := 'deactivate';
      elsif old.status = 'inactive' and new.status = 'active' then
        audit_action := 'activate';
      else
        audit_action := 'update';
      end if;

      audit_old_data := jsonb_build_object(
        'policy_area_id', old.policy_area_id,
        'department_id', old.department_id,
        'title', old.title,
        'description', old.description,
        'status', old.status,
        'priority_level', old.priority_level,
        'notes', old.notes
      );
    end if;

    audit_new_data := jsonb_build_object(
      'policy_area_id', new.policy_area_id,
      'department_id', new.department_id,
      'title', new.title,
      'description', new.description,
      'status', new.status,
      'priority_level', new.priority_level,
      'notes', new.notes
    );

  else
    raise exception using
      errcode = '22023',
      message = 'Entidade inesperada para auditoria de perfil e capacidade municipal.';
  end if;

  insert into public.municipality_profile_capacity_audit (
    municipality_id,
    entity_type,
    record_id,
    actor_user_id,
    action,
    old_data,
    new_data
  ) values (
    new.municipality_id,
    audit_entity_type,
    audit_record_id,
    (select auth.uid()),
    audit_action,
    audit_old_data,
    audit_new_data
  );

  return new;
end;
$$;

revoke all on function private.audit_municipality_profile_capacity_change() from public;

create trigger municipality_priority_areas_audit_insert
  after insert on public.municipality_priority_areas
  for each row
  execute function private.audit_municipality_profile_capacity_change();

create trigger municipality_priority_areas_audit_update
  after update of policy_area_id, priority_level, notes, status
  on public.municipality_priority_areas
  for each row
  when (
    old.policy_area_id is distinct from new.policy_area_id
    or old.priority_level is distinct from new.priority_level
    or old.notes is distinct from new.notes
    or old.status is distinct from new.status
  )
  execute function private.audit_municipality_profile_capacity_change();

create trigger municipality_capacity_profiles_audit_insert
  after insert on public.municipality_capacity_profiles
  for each row
  execute function private.audit_municipality_profile_capacity_change();

create trigger municipality_capacity_profiles_audit_update
  after update of accepts_counterpart, counterpart_capacity_level, counterpart_notes, overall_notes
  on public.municipality_capacity_profiles
  for each row
  when (
    old.accepts_counterpart is distinct from new.accepts_counterpart
    or old.counterpart_capacity_level is distinct from new.counterpart_capacity_level
    or old.counterpart_notes is distinct from new.counterpart_notes
    or old.overall_notes is distinct from new.overall_notes
  )
  execute function private.audit_municipality_profile_capacity_change();

create trigger municipality_capability_assessments_audit_insert
  after insert on public.municipality_capability_assessments
  for each row
  execute function private.audit_municipality_profile_capacity_change();

create trigger municipality_capability_assessments_audit_update
  after update of capability_dimension_id, capacity_level, notes
  on public.municipality_capability_assessments
  for each row
  when (
    old.capability_dimension_id is distinct from new.capability_dimension_id
    or old.capacity_level is distinct from new.capacity_level
    or old.notes is distinct from new.notes
  )
  execute function private.audit_municipality_profile_capacity_change();

create trigger municipality_demands_audit_insert
  after insert on public.municipality_demands
  for each row
  execute function private.audit_municipality_profile_capacity_change();

create trigger municipality_demands_audit_update
  after update of policy_area_id, department_id, title, description, status, priority_level, notes
  on public.municipality_demands
  for each row
  when (
    old.policy_area_id is distinct from new.policy_area_id
    or old.department_id is distinct from new.department_id
    or old.title is distinct from new.title
    or old.description is distinct from new.description
    or old.status is distinct from new.status
    or old.priority_level is distinct from new.priority_level
    or old.notes is distinct from new.notes
  )
  execute function private.audit_municipality_profile_capacity_change();

alter table public.municipality_profile_capacity_audit enable row level security;
alter table public.municipality_profile_capacity_audit force row level security;

-- A auditoria só pode ser escrita pelo trigger security definer. O usuário
-- autenticado recebe somente leitura dentro do município autorizado.
revoke all on table public.municipality_profile_capacity_audit from anon, authenticated;
grant select on public.municipality_profile_capacity_audit to authenticated;

create policy municipality_profile_capacity_audit_select_authorized_context
  on public.municipality_profile_capacity_audit
  for select to authenticated
  using (private.has_tenant_metadata_access(municipality_id));

-- As tabelas da fundação já possuem RLS e FORCE RLS. Estes grants preservam
-- SELECT e liberam somente campos de negócio; municipality_id permanece
-- disponível somente na criação e id/timestamps não recebem privilégio de escrita.
revoke all on table public.municipality_priority_areas from anon, authenticated;
grant select on public.municipality_priority_areas to authenticated;
grant insert (
  municipality_id,
  policy_area_id,
  priority_level,
  notes,
  status
) on public.municipality_priority_areas to authenticated;
grant update (
  policy_area_id,
  priority_level,
  notes,
  status
) on public.municipality_priority_areas to authenticated;

revoke all on table public.municipality_capacity_profiles from anon, authenticated;
grant select on public.municipality_capacity_profiles to authenticated;
grant insert (
  municipality_id,
  accepts_counterpart,
  counterpart_capacity_level,
  counterpart_notes,
  overall_notes
) on public.municipality_capacity_profiles to authenticated;
grant update (
  accepts_counterpart,
  counterpart_capacity_level,
  counterpart_notes,
  overall_notes
) on public.municipality_capacity_profiles to authenticated;

revoke all on table public.municipality_capability_assessments from anon, authenticated;
grant select on public.municipality_capability_assessments to authenticated;
grant insert (
  municipality_id,
  capability_dimension_id,
  capacity_level,
  notes
) on public.municipality_capability_assessments to authenticated;
grant update (
  capability_dimension_id,
  capacity_level,
  notes
) on public.municipality_capability_assessments to authenticated;

revoke all on table public.municipality_demands from anon, authenticated;
grant select on public.municipality_demands to authenticated;
grant insert (
  municipality_id,
  policy_area_id,
  department_id,
  title,
  description,
  status,
  priority_level,
  notes
) on public.municipality_demands to authenticated;
grant update (
  policy_area_id,
  department_id,
  title,
  description,
  status,
  priority_level,
  notes
) on public.municipality_demands to authenticated;

create policy municipality_priority_areas_insert_managers
  on public.municipality_priority_areas
  for insert to authenticated
  with check (
    private.can_manage_municipality_profile_capacity(municipality_id)
  );

create policy municipality_priority_areas_update_managers
  on public.municipality_priority_areas
  for update to authenticated
  using (
    private.can_manage_municipality_profile_capacity(municipality_id)
  )
  with check (
    private.can_manage_municipality_profile_capacity(municipality_id)
  );

create policy municipality_capacity_profiles_insert_managers
  on public.municipality_capacity_profiles
  for insert to authenticated
  with check (
    private.can_manage_municipality_profile_capacity(municipality_id)
  );

create policy municipality_capacity_profiles_update_managers
  on public.municipality_capacity_profiles
  for update to authenticated
  using (
    private.can_manage_municipality_profile_capacity(municipality_id)
  )
  with check (
    private.can_manage_municipality_profile_capacity(municipality_id)
  );

create policy municipality_capability_assessments_insert_managers
  on public.municipality_capability_assessments
  for insert to authenticated
  with check (
    private.can_manage_municipality_profile_capacity(municipality_id)
  );

create policy municipality_capability_assessments_update_managers
  on public.municipality_capability_assessments
  for update to authenticated
  using (
    private.can_manage_municipality_profile_capacity(municipality_id)
  )
  with check (
    private.can_manage_municipality_profile_capacity(municipality_id)
  );

create policy municipality_demands_insert_managers
  on public.municipality_demands
  for insert to authenticated
  with check (
    private.can_manage_municipality_profile_capacity(municipality_id)
  );

create policy municipality_demands_update_managers
  on public.municipality_demands
  for update to authenticated
  using (
    private.can_manage_municipality_profile_capacity(municipality_id)
  )
  with check (
    private.can_manage_municipality_profile_capacity(municipality_id)
  );

-- Reafirma a aplicação de RLS mesmo para o proprietário das tabelas.
alter table public.municipality_priority_areas force row level security;
alter table public.municipality_capacity_profiles force row level security;
alter table public.municipality_capability_assessments force row level security;
alter table public.municipality_demands force row level security;

commit;
