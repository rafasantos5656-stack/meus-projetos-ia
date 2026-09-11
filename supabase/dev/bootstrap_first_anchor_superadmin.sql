-- DEV ONLY — Bootstrap administrativo inicial da Fundação Multi-Prefeitura.
-- Execute exclusivamente no SQL Editor do projeto Supabase DEV, após a migration
-- 20260909_anchor_multitenant_foundation.sql. Nunca execute em homologação ou produção.
--
-- Antes de executar, substitua TODAS as ocorrências de <DEV_USER_UUID> pelo UUID
-- da conta DEV já existente em auth.users. Não use e-mail, senha, token ou chave.
--
-- Este script não cria municípios, memberships, assignments, projects ou tasks.
-- assigned_by fica NULL apenas para o primeiro anchor_superadmin, pois ainda não
-- existe outro superadmin que possa realizar a atribuição.

begin;

do $bootstrap$
declare
  target_user_id uuid := '03fa4979-d73c-4bb5-82fd-4317d28a157e'::uuid;
  another_superadmin_exists boolean;
  target_role_exists boolean;
begin
  if not exists (
    select 1
    from auth.users
    where id = target_user_id
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'Bootstrap cancelado: o UUID informado não existe em auth.users.';
  end if;

  if not exists (
    select 1
    from public.app_roles
    where scope = 'anchor'::public.role_scope
      and code = 'anchor_superadmin'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'Bootstrap cancelado: o papel anchor_superadmin não foi encontrado. Execute primeiro a migration da fundação.';
  end if;

  select exists (
    select 1
    from public.anchor_user_roles
    where role_scope = 'anchor'::public.role_scope
      and role_code = 'anchor_superadmin'
      and user_id <> target_user_id
  )
  into another_superadmin_exists;

  if another_superadmin_exists then
    raise exception using
      errcode = 'P0001',
      message = 'Bootstrap cancelado: já existe outro anchor_superadmin. Use o fluxo administrativo apropriado, não este bootstrap inicial.';
  end if;

  insert into public.profiles (id)
  values (target_user_id)
  on conflict (id) do nothing;

  select exists (
    select 1
    from public.anchor_user_roles
    where user_id = target_user_id
      and role_scope = 'anchor'::public.role_scope
      and role_code = 'anchor_superadmin'
  )
  into target_role_exists;

  if not target_role_exists then
    insert into public.anchor_user_roles (
      user_id,
      role_scope,
      role_code,
      assigned_by
    )
    values (
      target_user_id,
      'anchor'::public.role_scope,
      'anchor_superadmin',
      null
    );
  end if;
end;
$bootstrap$;

commit;

-- Confirmação somente-leitura. O resultado deve mostrar o UUID e e-mail informados,
-- profile_exists = true e has_anchor_superadmin = true.
select
  user_record.id as user_uuid,
  user_record.email,
  (profile_record.id is not null) as profile_exists,
  profile_record.display_name as profile_display_name,
  profile_record.status as profile_status,
  exists (
    select 1
    from public.anchor_user_roles role_assignment
    where role_assignment.user_id = user_record.id
      and role_assignment.role_scope = 'anchor'::public.role_scope
      and role_assignment.role_code = 'anchor_superadmin'
  ) as has_anchor_superadmin
from auth.users as user_record
left join public.profiles as profile_record
  on profile_record.id = user_record.id
where user_record.id = '<DEV_USER_UUID>'::uuid;