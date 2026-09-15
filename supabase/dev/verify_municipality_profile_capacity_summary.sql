-- Resultado único read-only da fundação de Perfil e Capacidade Municipal.
-- Execute somente no SQL Editor do Supabase DEV.

with expected_tables(table_name, table_group) as (
  values
    ('policy_areas', 'catalog'),
    ('capability_dimensions', 'catalog'),
    ('municipality_priority_areas', 'municipal'),
    ('municipality_capacity_profiles', 'municipal'),
    ('municipality_capability_assessments', 'municipal'),
    ('municipality_demands', 'municipal')
),
table_relations as (
  select
    expected_tables.table_name,
    expected_tables.table_group,
    relation.oid,
    coalesce(relation.relrowsecurity, false) as rls_enabled,
    coalesce(relation.relforcerowsecurity, false) as rls_forced
  from expected_tables
  left join pg_catalog.pg_namespace namespace
    on namespace.nspname = 'public'
  left join pg_catalog.pg_class relation
    on relation.relnamespace = namespace.oid
   and relation.relname = expected_tables.table_name
),
policy_rows as (
  select tablename, cmd
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
),
authenticated_privileges as (
  select
    table_name,
    coalesce(
      pg_catalog.has_table_privilege('authenticated'::name, oid, 'INSERT'),
      false
    ) as can_insert,
    coalesce(
      pg_catalog.has_table_privilege('authenticated'::name, oid, 'UPDATE'),
      false
    ) as can_update,
    coalesce(
      pg_catalog.has_table_privilege('authenticated'::name, oid, 'DELETE'),
      false
    ) as can_delete
  from table_relations
),
updated_at_triggers as (
  select count(*)::integer as trigger_count
  from pg_catalog.pg_trigger trigger_info
  join pg_catalog.pg_class relation
    on relation.oid = trigger_info.tgrelid
  join pg_catalog.pg_namespace namespace
    on namespace.oid = relation.relnamespace
  join pg_catalog.pg_proc procedure_info
    on procedure_info.oid = trigger_info.tgfoid
  join pg_catalog.pg_namespace procedure_namespace
    on procedure_namespace.oid = procedure_info.pronamespace
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
    and procedure_namespace.nspname = 'private'
    and procedure_info.proname = 'touch_updated_at'
),
column_numbers as (
  select
    (
      select attribute_info.attnum::smallint
      from pg_catalog.pg_attribute attribute_info
      where attribute_info.attrelid = 'public.municipality_demands'::regclass
        and attribute_info.attname = 'department_id'
        and not attribute_info.attisdropped
    ) as demand_department_id,
    (
      select attribute_info.attnum::smallint
      from pg_catalog.pg_attribute attribute_info
      where attribute_info.attrelid = 'public.municipality_demands'::regclass
        and attribute_info.attname = 'municipality_id'
        and not attribute_info.attisdropped
    ) as demand_municipality_id,
    (
      select attribute_info.attnum::smallint
      from pg_catalog.pg_attribute attribute_info
      where attribute_info.attrelid = 'public.municipality_priority_areas'::regclass
        and attribute_info.attname = 'municipality_id'
        and not attribute_info.attisdropped
    ) as priority_municipality_id,
    (
      select attribute_info.attnum::smallint
      from pg_catalog.pg_attribute attribute_info
      where attribute_info.attrelid = 'public.municipality_priority_areas'::regclass
        and attribute_info.attname = 'policy_area_id'
        and not attribute_info.attisdropped
    ) as priority_policy_area_id,
    (
      select attribute_info.attnum::smallint
      from pg_catalog.pg_attribute attribute_info
      where attribute_info.attrelid = 'public.municipality_capability_assessments'::regclass
        and attribute_info.attname = 'municipality_id'
        and not attribute_info.attisdropped
    ) as assessment_municipality_id,
    (
      select attribute_info.attnum::smallint
      from pg_catalog.pg_attribute attribute_info
      where attribute_info.attrelid = 'public.municipality_capability_assessments'::regclass
        and attribute_info.attname = 'capability_dimension_id'
        and not attribute_info.attisdropped
    ) as assessment_dimension_id,
    (
      select attribute_info.attnum::smallint
      from pg_catalog.pg_attribute attribute_info
      where attribute_info.attrelid = 'public.municipality_capacity_profiles'::regclass
        and attribute_info.attname = 'municipality_id'
        and not attribute_info.attisdropped
    ) as capacity_profile_municipality_id
),
constraint_checks as (
  select
    exists (
      select 1
      from pg_catalog.pg_constraint constraint_info
      where constraint_info.contype = 'f'
        and constraint_info.conrelid = 'public.municipality_demands'::regclass
        and constraint_info.confrelid = 'public.municipality_departments'::regclass
        and constraint_info.conkey = array[
          column_numbers.demand_department_id,
          column_numbers.demand_municipality_id
        ]
        and constraint_info.confkey = array[
          (
            select attribute_info.attnum::smallint
            from pg_catalog.pg_attribute attribute_info
            where attribute_info.attrelid = 'public.municipality_departments'::regclass
              and attribute_info.attname = 'id'
              and not attribute_info.attisdropped
          ),
          (
            select attribute_info.attnum::smallint
            from pg_catalog.pg_attribute attribute_info
            where attribute_info.attrelid = 'public.municipality_departments'::regclass
              and attribute_info.attname = 'municipality_id'
              and not attribute_info.attisdropped
          )
        ]
    ) as demand_department_tenant_fk,
    exists (
      select 1
      from pg_catalog.pg_constraint constraint_info
      where constraint_info.contype = 'u'
        and constraint_info.conrelid = 'public.municipality_priority_areas'::regclass
        and constraint_info.conkey = array[
          column_numbers.priority_municipality_id,
          column_numbers.priority_policy_area_id
        ]
    ) as priority_area_unique,
    exists (
      select 1
      from pg_catalog.pg_constraint constraint_info
      where constraint_info.contype = 'u'
        and constraint_info.conrelid = 'public.municipality_capability_assessments'::regclass
        and constraint_info.conkey = array[
          column_numbers.assessment_municipality_id,
          column_numbers.assessment_dimension_id
        ]
    ) as capability_assessment_unique,
    exists (
      select 1
      from pg_catalog.pg_constraint constraint_info
      where constraint_info.contype = 'p'
        and constraint_info.conrelid = 'public.municipality_capacity_profiles'::regclass
        and constraint_info.conkey = array[
          column_numbers.capacity_profile_municipality_id
        ]
    ) as capacity_profile_municipality_pk
  from column_numbers
),
checks(check_order, check_name, expected, actual, is_ok) as (
  select
    1,
    'Tabelas esperadas',
    '6',
    (select count(*)::text from table_relations where oid is not null),
    (select count(*) = 6 from table_relations where oid is not null)
  union all
  select 2, 'Seeds policy_areas', '16',
    (select count(*)::text from public.policy_areas),
    (select count(*) = 16 from public.policy_areas)
  union all
  select 3, 'Seeds capability_dimensions', '10',
    (select count(*)::text from public.capability_dimensions),
    (select count(*) = 10 from public.capability_dimensions)
  union all
  select 4, 'Dados municipality_priority_areas', '0',
    (select count(*)::text from public.municipality_priority_areas),
    (select count(*) = 0 from public.municipality_priority_areas)
  union all
  select 5, 'Dados municipality_capacity_profiles', '0',
    (select count(*)::text from public.municipality_capacity_profiles),
    (select count(*) = 0 from public.municipality_capacity_profiles)
  union all
  select 6, 'Dados municipality_capability_assessments', '0',
    (select count(*)::text from public.municipality_capability_assessments),
    (select count(*) = 0 from public.municipality_capability_assessments)
  union all
  select 7, 'Dados municipality_demands', '0',
    (select count(*)::text from public.municipality_demands),
    (select count(*) = 0 from public.municipality_demands)
  union all
  select 8, 'RLS habilitado', '6',
    (select count(*)::text from table_relations where rls_enabled),
    (select count(*) = 6 from table_relations where rls_enabled)
  union all
  select 9, 'FORCE RLS', '6',
    (select count(*)::text from table_relations where rls_forced),
    (select count(*) = 6 from table_relations where rls_forced)
  union all
  select 10, 'Policies SELECT dos catálogos', '2',
    (select count(*)::text from policy_rows
      where tablename in ('policy_areas', 'capability_dimensions') and cmd = 'SELECT'),
    (select count(*) = 2 from policy_rows
      where tablename in ('policy_areas', 'capability_dimensions') and cmd = 'SELECT')
  union all
  select 11, 'Policies SELECT municipais', '4',
    (select count(*)::text from policy_rows
      where tablename in (
        'municipality_priority_areas',
        'municipality_capacity_profiles',
        'municipality_capability_assessments',
        'municipality_demands'
      ) and cmd = 'SELECT'),
    (select count(*) = 4 from policy_rows
      where tablename in (
        'municipality_priority_areas',
        'municipality_capacity_profiles',
        'municipality_capability_assessments',
        'municipality_demands'
      ) and cmd = 'SELECT')
  union all
  select 12, 'Policies INSERT', '0',
    (select count(*)::text from policy_rows where cmd in ('INSERT', 'ALL')),
    (select count(*) = 0 from policy_rows where cmd in ('INSERT', 'ALL'))
  union all
  select 13, 'Policies UPDATE', '0',
    (select count(*)::text from policy_rows where cmd in ('UPDATE', 'ALL')),
    (select count(*) = 0 from policy_rows where cmd in ('UPDATE', 'ALL'))
  union all
  select 14, 'Policies DELETE', '0',
    (select count(*)::text from policy_rows where cmd in ('DELETE', 'ALL')),
    (select count(*) = 0 from policy_rows where cmd in ('DELETE', 'ALL'))
  union all
  select 15, 'Grants INSERT para authenticated', '0',
    (select count(*)::text from authenticated_privileges where can_insert),
    (select count(*) = 0 from authenticated_privileges where can_insert)
  union all
  select 16, 'Grants UPDATE para authenticated', '0',
    (select count(*)::text from authenticated_privileges where can_update),
    (select count(*) = 0 from authenticated_privileges where can_update)
  union all
  select 17, 'Grants DELETE para authenticated', '0',
    (select count(*)::text from authenticated_privileges where can_delete),
    (select count(*) = 0 from authenticated_privileges where can_delete)
  union all
  select 18, 'Triggers private.touch_updated_at', '6',
    (select trigger_count::text from updated_at_triggers),
    (select trigger_count = 6 from updated_at_triggers)
  union all
  select 19, 'FK composta demanda/unidade', 'presente',
    (select case when demand_department_tenant_fk then 'presente' else 'ausente' end from constraint_checks),
    (select demand_department_tenant_fk from constraint_checks)
  union all
  select 20, 'UNIQUE prioridade por área municipal', 'presente',
    (select case when priority_area_unique then 'presente' else 'ausente' end from constraint_checks),
    (select priority_area_unique from constraint_checks)
  union all
  select 21, 'UNIQUE avaliação por dimensão', 'presente',
    (select case when capability_assessment_unique then 'presente' else 'ausente' end from constraint_checks),
    (select capability_assessment_unique from constraint_checks)
  union all
  select 22, 'PK perfil de capacidade em municipality_id', 'presente',
    (select case when capacity_profile_municipality_pk then 'presente' else 'ausente' end from constraint_checks),
    (select capacity_profile_municipality_pk from constraint_checks)
)
select
  check_name,
  expected,
  actual,
  case when is_ok then 'OK' else 'REVIEW' end as result
from checks
order by check_order;
