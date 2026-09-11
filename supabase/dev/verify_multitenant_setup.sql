-- DEV ONLY — Consultas administrativas somente-leitura da estrutura Alfa/Beta.
-- Execute no SQL Editor do Supabase DEV após setup_multitenant_isolation_test.sql.
-- Não há INSERT, UPDATE, DELETE, DDL, nem qualquer alteração de dados neste arquivo.

-- 1. Municípios de teste.
select
  id as municipality_id,
  name,
  state,
  status,
  timezone,
  created_at
from public.municipalities
where lower(btrim(name)) in (lower('Prefeitura Alfa'), lower('Prefeitura Beta'))
  and state = 'SP'
order by name;

-- 2. Departamentos de cada Prefeitura de teste.
select
  municipality.name as municipality,
  department.id as department_id,
  department.name as department,
  department.status as department_status
from public.municipality_departments as department
join public.municipalities as municipality
  on municipality.id = department.municipality_id
where lower(btrim(municipality.name)) in (lower('Prefeitura Alfa'), lower('Prefeitura Beta'))
  and municipality.state = 'SP'
order by municipality.name, department.name;

-- 3. Memberships e papel municipal esperado.
select
  municipality.name as municipality,
  membership.id as membership_id,
  membership.user_id,
  membership.status as membership_status,
  membership.activated_at,
  role_assignment.role_code
from public.municipality_members as membership
join public.municipalities as municipality
  on municipality.id = membership.municipality_id
left join public.municipality_member_roles as role_assignment
  on role_assignment.membership_id = membership.id
where lower(btrim(municipality.name)) in (lower('Prefeitura Alfa'), lower('Prefeitura Beta'))
  and municipality.state = 'SP'
order by municipality.name, membership.user_id, role_assignment.role_code;

-- 4. Associação N:N dos usuários aos departamentos: deve apontar para Convênios
-- dentro da mesma Prefeitura de cada membership.
select
  municipality.name as municipality,
  membership.user_id,
  membership.status as membership_status,
  department.name as linked_department
from public.municipality_member_departments as member_department
join public.municipality_members as membership
  on membership.id = member_department.membership_id
  and membership.municipality_id = member_department.municipality_id
join public.municipality_departments as department
  on department.id = member_department.department_id
  and department.municipality_id = member_department.municipality_id
join public.municipalities as municipality
  on municipality.id = member_department.municipality_id
where lower(btrim(municipality.name)) in (lower('Prefeitura Alfa'), lower('Prefeitura Beta'))
  and municipality.state = 'SP'
order by municipality.name, membership.user_id, department.name;