-- Verificação read-only da fundação de Perfil e Capacidade Municipal.
-- Executar somente no SQL Editor do Supabase DEV.

-- 1. Existência das seis tabelas esperadas no schema public.
with expected_tables(table_name) as (
  values
    ('policy_areas'),
    ('capability_dimensions'),
    ('municipality_priority_areas'),
    ('municipality_capacity_profiles'),
    ('municipality_capability_assessments'),
    ('municipality_demands')
)
select
  expected_tables.table_name,
  case when relation.oid is null then 'ausente' else 'presente' end as existence,
  relation.relkind as relation_kind
from expected_tables
left join pg_catalog.pg_namespace namespace
  on namespace.nspname = 'public'
left join pg_catalog.pg_class relation
  on relation.relnamespace = namespace.oid
 and relation.relname = expected_tables.table_name
order by expected_tables.table_name;

-- 2. Contagem dos seeds dos catálogos.
select 'policy_areas' as catalog, count(*)::integer as actual_count, 16 as expected_count
from public.policy_areas
union all
select 'capability_dimensions', count(*)::integer, 10
from public.capability_dimensions;

-- 3. Valores canônicos dos catálogos.
select code, name, status
from public.policy_areas
order by code;

select code, name, description, status
from public.capability_dimensions
order by code;

-- 4. PKs, uniques e checks das seis tabelas.
select
  relation.relname as table_name,
  constraint_info.conname as constraint_name,
  constraint_info.contype as constraint_type,
  pg_catalog.pg_get_constraintdef(constraint_info.oid, true) as definition
from pg_catalog.pg_constraint constraint_info
join pg_catalog.pg_class relation
  on relation.oid = constraint_info.conrelid
join pg_catalog.pg_namespace namespace
  on namespace.oid = relation.relnamespace
where namespace.nspname = 'public'
  and relation.relname in (
    'policy_areas',
    'capability_dimensions',
    'municipality_priority_areas',
    'municipality_capacity_profiles',
    'municipality_capability_assessments',
    'municipality_demands'
  )
  and constraint_info.contype in ('p', 'u', 'c')
order by relation.relname, constraint_info.contype, constraint_info.conname;

-- 5. Chaves estrangeiras, incluindo o vínculo composto demanda/unidade.
select
  relation.relname as table_name,
  constraint_info.conname as foreign_key_name,
  pg_catalog.pg_get_constraintdef(constraint_info.oid, true) as definition
from pg_catalog.pg_constraint constraint_info
join pg_catalog.pg_class relation
  on relation.oid = constraint_info.conrelid
join pg_catalog.pg_namespace namespace
  on namespace.oid = relation.relnamespace
where namespace.nspname = 'public'
  and relation.relname in (
    'municipality_priority_areas',
    'municipality_capacity_profiles',
    'municipality_capability_assessments',
    'municipality_demands'
  )
  and constraint_info.contype = 'f'
order by relation.relname, constraint_info.conname;

-- 6. RLS habilitado e forçado nas seis tabelas.
select
  relation.relname as table_name,
  relation.relrowsecurity as rls_enabled,
  relation.relforcerowsecurity as rls_forced
from pg_catalog.pg_class relation
join pg_catalog.pg_namespace namespace
  on namespace.oid = relation.relnamespace
where namespace.nspname = 'public'
  and relation.relname in (
    'policy_areas',
    'capability_dimensions',
    'municipality_priority_areas',
    'municipality_capacity_profiles',
    'municipality_capability_assessments',
    'municipality_demands'
  )
order by relation.relname;

-- 7. Policies e resumo de qualquer policy que não seja SELECT.
select
  tablename,
  policyname,
  cmd,
  roles,
  qual,
  with_check
from pg_catalog.pg_policies
where schemaname = 'public'
  and tablename in (
    'policy_areas',
    'capability_dimensions',
    'municipality_priority_areas',
    'municipality_capacity_profiles',
    'municipality_capability_assessments',
    'municipality_demands'
  )
order by tablename, policyname;

select
  tablename,
  count(*) filter (where cmd <> 'SELECT') as non_select_policy_count
from pg_catalog.pg_policies
where schemaname = 'public'
  and tablename in (
    'policy_areas',
    'capability_dimensions',
    'municipality_priority_areas',
    'municipality_capacity_profiles',
    'municipality_capability_assessments',
    'municipality_demands'
  )
group by tablename
order by tablename;

-- 8. Privilégios concedidos especificamente a authenticated.
with expected_tables(table_name) as (
  values
    ('policy_areas'),
    ('capability_dimensions'),
    ('municipality_priority_areas'),
    ('municipality_capacity_profiles'),
    ('municipality_capability_assessments'),
    ('municipality_demands')
)
select
  expected_tables.table_name,
  coalesce(
    string_agg(grants.privilege_type, ', ' order by grants.privilege_type),
    'nenhum'
  ) as authenticated_privileges
from expected_tables
left join information_schema.role_table_grants grants
  on grants.table_schema = 'public'
 and grants.table_name = expected_tables.table_name
 and grants.grantee = 'authenticated'
group by expected_tables.table_name
order by expected_tables.table_name;

-- 9. Triggers de updated_at esperados.
select
  relation.relname as table_name,
  trigger_info.tgname as trigger_name,
  procedure_info.proname as function_name,
  pg_catalog.pg_get_triggerdef(trigger_info.oid, true) as definition
from pg_catalog.pg_trigger trigger_info
join pg_catalog.pg_class relation
  on relation.oid = trigger_info.tgrelid
join pg_catalog.pg_namespace namespace
  on namespace.oid = relation.relnamespace
join pg_catalog.pg_proc procedure_info
  on procedure_info.oid = trigger_info.tgfoid
where namespace.nspname = 'public'
  and relation.relname in (
    'policy_areas',
    'capability_dimensions',
    'municipality_priority_areas',
    'municipality_capacity_profiles',
    'municipality_capability_assessments',
    'municipality_demands'
  )
  and not trigger_info.tgisinternal
order by relation.relname, trigger_info.tgname;

-- 10. Dados municipais devem iniciar vazios nesta fundação.
select 'municipality_priority_areas' as table_name, count(*)::bigint as row_count
from public.municipality_priority_areas
union all
select 'municipality_capacity_profiles', count(*)::bigint
from public.municipality_capacity_profiles
union all
select 'municipality_capability_assessments', count(*)::bigint
from public.municipality_capability_assessments
union all
select 'municipality_demands', count(*)::bigint
from public.municipality_demands
order by table_name;
