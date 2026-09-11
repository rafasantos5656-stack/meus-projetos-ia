-- DEV ONLY — Dados mínimos para testar isolamento entre Prefeituras.
-- Execute somente no SQL Editor do Supabase DEV, após a foundation migration.
-- Nunca execute em homologação ou produção.
--
-- Substitua TODAS as ocorrências de 086c5fd9-4e53-4cd0-8e96-c0b1720e07e7 e  b24f5061-05a4-4f21-9176-c314afff3ffe pelos UUIDs
-- de dois usuários DEV distintos já criados manualmente em auth.users.
-- Este script não cria usuários, não atribui papéis Âncora e não cria assignments.

begin;

do $setup$
declare
  user_a_id uuid := '086c5fd9-4e53-4cd0-8e96-c0b1720e07e7'::uuid;
  user_b_id uuid := '086c5fd9-4e53-4cd0-8e96-c0b1720e07e7'::uuid;
  alfa_id uuid;
  beta_id uuid;
  alfa_status public.municipality_status;
  beta_status public.municipality_status;
  alfa_matches integer;
  beta_matches integer;
  user_a_membership_id uuid;
  user_b_membership_id uuid;
  user_a_membership_status public.membership_status;
  user_b_membership_status public.membership_status;
begin
  if user_a_id = user_b_id then
    raise exception using
      errcode = 'P0001',
      message = 'Setup cancelado: USER A e USER B devem ser UUIDs distintos.';
  end if;

  if not exists (select 1 from auth.users where id = user_a_id) then
    raise exception using
      errcode = 'P0001',
      message = 'Setup cancelado: USER A não existe em auth.users.';
  end if;

  if not exists (select 1 from auth.users where id = user_b_id) then
    raise exception using
      errcode = 'P0001',
      message = 'Setup cancelado: USER B não existe em auth.users.';
  end if;

  if exists (
    select 1
    from public.anchor_user_roles
    where user_id in (user_a_id, user_b_id)
      and role_scope = 'anchor'::public.role_scope
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'Setup cancelado: USER A e USER B não podem possuir papel Âncora durante este teste de isolamento.';
  end if;

  select count(*)
  into alfa_matches
  from public.municipalities
  where lower(btrim(name)) = lower('Prefeitura Alfa')
    and state = 'SP';

  if alfa_matches > 1 then
    raise exception using
      errcode = 'P0001',
      message = 'Setup cancelado: foram encontradas múltiplas Prefeituras Alfa de teste. Faça revisão manual no DEV.';
  elsif alfa_matches = 0 then
    insert into public.municipalities (name, state, status)
    values ('Prefeitura Alfa', 'SP', 'active'::public.municipality_status)
    returning id, status into alfa_id, alfa_status;
  else
    select id, status
    into alfa_id, alfa_status
    from public.municipalities
    where lower(btrim(name)) = lower('Prefeitura Alfa')
      and state = 'SP';
  end if;

  select count(*)
  into beta_matches
  from public.municipalities
  where lower(btrim(name)) = lower('Prefeitura Beta')
    and state = 'SP';

  if beta_matches > 1 then
    raise exception using
      errcode = 'P0001',
      message = 'Setup cancelado: foram encontradas múltiplas Prefeituras Beta de teste. Faça revisão manual no DEV.';
  elsif beta_matches = 0 then
    insert into public.municipalities (name, state, status)
    values ('Prefeitura Beta', 'SP', 'active'::public.municipality_status)
    returning id, status into beta_id, beta_status;
  else
    select id, status
    into beta_id, beta_status
    from public.municipalities
    where lower(btrim(name)) = lower('Prefeitura Beta')
      and state = 'SP';
  end if;

  if alfa_status <> 'active'::public.municipality_status
    or beta_status <> 'active'::public.municipality_status then
    raise exception using
      errcode = 'P0001',
      message = 'Setup cancelado: as Prefeituras de teste existentes precisam estar ativas.';
  end if;

  if exists (
    select 1
    from public.municipality_members
    where status = 'active'::public.membership_status
      and (
        (user_id = user_a_id and municipality_id = beta_id)
        or (user_id = user_b_id and municipality_id = alfa_id)
      )
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'Setup cancelado: existe vínculo cruzado ativo que invalidaria o teste Alfa/Beta.';
  end if;

  insert into public.profiles (id)
  values (user_a_id), (user_b_id)
  on conflict (id) do nothing;

  insert into public.municipality_departments (municipality_id, name)
  values
    (alfa_id, 'Convênios'),
    (alfa_id, 'Engenharia'),
    (alfa_id, 'Contabilidade'),
    (alfa_id, 'Licitações'),
    (beta_id, 'Convênios'),
    (beta_id, 'Engenharia'),
    (beta_id, 'Contabilidade'),
    (beta_id, 'Licitações')
  on conflict do nothing;

  insert into public.municipality_members (
    municipality_id,
    user_id,
    status,
    activated_at
  )
  values
    (alfa_id, user_a_id, 'active'::public.membership_status, now()),
    (beta_id, user_b_id, 'active'::public.membership_status, now())
  on conflict (municipality_id, user_id) do nothing;

  select id, status
  into user_a_membership_id, user_a_membership_status
  from public.municipality_members
  where municipality_id = alfa_id and user_id = user_a_id;

  select id, status
  into user_b_membership_id, user_b_membership_status
  from public.municipality_members
  where municipality_id = beta_id and user_id = user_b_id;

  if user_a_membership_status <> 'active'::public.membership_status
    or user_b_membership_status <> 'active'::public.membership_status then
    raise exception using
      errcode = 'P0001',
      message = 'Setup cancelado: os vínculos existentes de teste precisam estar ativos.';
  end if;

  insert into public.municipality_member_roles (
    membership_id,
    role_scope,
    role_code
  )
  values
    (user_a_membership_id, 'municipality'::public.role_scope, 'grants_manager'),
    (user_b_membership_id, 'municipality'::public.role_scope, 'grants_manager')
  on conflict (membership_id, role_code) do nothing;

  insert into public.municipality_member_departments (
    membership_id,
    municipality_id,
    department_id
  )
  select user_a_membership_id, alfa_id, department.id
  from public.municipality_departments as department
  where department.municipality_id = alfa_id
    and lower(btrim(department.name)) = lower('Convênios')
  on conflict (membership_id, department_id) do nothing;

  insert into public.municipality_member_departments (
    membership_id,
    municipality_id,
    department_id
  )
  select user_b_membership_id, beta_id, department.id
  from public.municipality_departments as department
  where department.municipality_id = beta_id
    and lower(btrim(department.name)) = lower('Convênios')
  on conflict (membership_id, department_id) do nothing;

  if not exists (
    select 1
    from public.municipality_member_departments
    where membership_id = user_a_membership_id
      and municipality_id = alfa_id
  ) or not exists (
    select 1
    from public.municipality_member_departments
    where membership_id = user_b_membership_id
      and municipality_id = beta_id
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'Setup cancelado: não foi possível associar os usuários ao departamento Convênios correto.';
  end if;
end;
$setup$;

commit;