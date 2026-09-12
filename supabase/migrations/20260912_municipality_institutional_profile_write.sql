-- Escrita controlada do perfil institucional municipal — DEV somente até revisão/aplicação manual.
-- Não altera estruturas legadas, projects, tasks, nem a policy SELECT existente.

begin;

-- Retorna verdadeiro somente para uma membership ativa do usuário atual que possua
-- o papel municipal solicitado. A consulta é security definer para não recursar
-- pelas policies das tabelas de membership durante a avaliação de RLS.
create or replace function private.has_active_municipality_role(
  target_municipality_id uuid,
  target_role_code text
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select exists (
    select 1
    from public.municipality_members as membership
    join public.municipality_member_roles as membership_role
      on membership_role.membership_id = membership.id
    where membership.municipality_id = target_municipality_id
      and membership.user_id = (select auth.uid())
      and membership.status = 'active'::public.membership_status
      and membership_role.role_scope = 'municipality'::public.role_scope
      and membership_role.role_code = target_role_code
  );
$$;

-- Centraliza a decisão de escrita deste recurso. Não inclui anchor_operator.
create or replace function private.can_manage_municipality_institutional_profile(
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

revoke all on function private.has_active_municipality_role(uuid, text) from public;
revoke all on function private.can_manage_municipality_institutional_profile(uuid) from public;

grant execute on function private.has_active_municipality_role(uuid, text) to authenticated;
grant execute on function private.can_manage_municipality_institutional_profile(uuid) to authenticated;

-- Auditoria imutável de alterações realizadas pelo trigger abaixo.
create table public.municipality_institutional_profile_audit (
  id uuid primary key default gen_random_uuid(),
  municipality_id uuid not null references public.municipalities (id) on delete restrict,
  actor_user_id uuid null references auth.users (id) on delete set null,
  action text not null check (action in ('insert', 'update')),
  old_data jsonb null,
  new_data jsonb null,
  created_at timestamptz not null default now(),
  constraint municipality_institutional_profile_audit_payload_check check (
    (action = 'insert' and old_data is null and new_data is not null)
    or (action = 'update' and old_data is not null and new_data is not null)
  )
);

create index municipality_institutional_profile_audit_municipality_created_idx
  on public.municipality_institutional_profile_audit (municipality_id, created_at desc);

-- A função recebe os valores exclusivamente da linha do banco e da sessão atual.
-- Nenhum campo de auditoria é aceito do frontend.
create or replace function private.audit_municipality_institutional_profile_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.municipality_institutional_profile_audit (
      municipality_id,
      actor_user_id,
      action,
      old_data,
      new_data
    ) values (
      new.municipality_id,
      (select auth.uid()),
      'insert',
      null,
      jsonb_build_object(
        'mayor_name', new.mayor_name,
        'official_website', new.official_website,
        'institutional_phone', new.institutional_phone,
        'institutional_email', new.institutional_email
      )
    );
  elsif tg_op = 'UPDATE' then
    insert into public.municipality_institutional_profile_audit (
      municipality_id,
      actor_user_id,
      action,
      old_data,
      new_data
    ) values (
      new.municipality_id,
      (select auth.uid()),
      'update',
      jsonb_build_object(
        'mayor_name', old.mayor_name,
        'official_website', old.official_website,
        'institutional_phone', old.institutional_phone,
        'institutional_email', old.institutional_email
      ),
      jsonb_build_object(
        'mayor_name', new.mayor_name,
        'official_website', new.official_website,
        'institutional_phone', new.institutional_phone,
        'institutional_email', new.institutional_email
      )
    );
  end if;

  return new;
end;
$$;

revoke all on function private.audit_municipality_institutional_profile_change() from public;

create trigger municipality_institutional_profiles_audit_insert
  after insert
  on public.municipality_institutional_profiles
  for each row
  execute function private.audit_municipality_institutional_profile_change();

create trigger municipality_institutional_profiles_audit_update
  after update of mayor_name, official_website, institutional_phone, institutional_email
  on public.municipality_institutional_profiles
  for each row
  when (
    old.mayor_name is distinct from new.mayor_name
    or old.official_website is distinct from new.official_website
    or old.institutional_phone is distinct from new.institutional_phone
    or old.institutional_email is distinct from new.institutional_email
  )
  execute function private.audit_municipality_institutional_profile_change();

alter table public.municipality_institutional_profile_audit enable row level security;
alter table public.municipality_institutional_profile_audit force row level security;

-- authenticated mantém somente leitura do histórico. O trigger security definer
-- é a única via de INSERT; não há grants ou policies de UPDATE/DELETE.
revoke all on table public.municipality_institutional_profile_audit from anon, authenticated;
grant select on public.municipality_institutional_profile_audit to authenticated;

create policy municipality_institutional_profile_audit_select_authorized_context
  on public.municipality_institutional_profile_audit
  for select to authenticated
  using (private.has_tenant_metadata_access(municipality_id));

-- Reafirma privilégios mínimos no perfil: leitura existente, INSERT limitado e
-- UPDATE somente nos quatro campos de conteúdo. municipality_id é imutável pelo
-- privilégio de coluna e é novamente protegido pelas duas expressões da policy.
revoke all on table public.municipality_institutional_profiles from anon, authenticated;
grant select on public.municipality_institutional_profiles to authenticated;
grant insert (
  municipality_id,
  mayor_name,
  official_website,
  institutional_phone,
  institutional_email
) on public.municipality_institutional_profiles to authenticated;
grant update (
  mayor_name,
  official_website,
  institutional_phone,
  institutional_email
) on public.municipality_institutional_profiles to authenticated;

create policy municipality_institutional_profiles_insert_managers
  on public.municipality_institutional_profiles
  for insert to authenticated
  with check (
    private.can_manage_municipality_institutional_profile(municipality_id)
  );

create policy municipality_institutional_profiles_update_managers
  on public.municipality_institutional_profiles
  for update to authenticated
  using (
    private.can_manage_municipality_institutional_profile(municipality_id)
  )
  with check (
    private.can_manage_municipality_institutional_profile(municipality_id)
  );

commit;