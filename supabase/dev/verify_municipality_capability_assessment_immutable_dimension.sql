-- Verificação read-only da imutabilidade de capability_dimension_id.
-- Execute somente no SQL Editor do Supabase DEV após a migration 20260921.

with target_table as (
  select 'public.municipality_capability_assessments'::regclass as relation
),
checks as (
  select
    'RLS habilitado'::text as check_name,
    'true'::text as expected,
    class.relrowsecurity::text as actual,
    case when class.relrowsecurity then 'OK' else 'REVISAR' end as result
  from target_table
  join pg_class as class on class.oid = target_table.relation

  union all

  select
    'FORCE RLS habilitado',
    'true',
    class.relforcerowsecurity::text,
    case when class.relforcerowsecurity then 'OK' else 'REVISAR' end
  from target_table
  join pg_class as class on class.oid = target_table.relation

  union all

  select
    'Policies SELECT, INSERT e UPDATE',
    'SELECT=1, INSERT=1, UPDATE=1, ALL=0',
    format(
      'SELECT=%s, INSERT=%s, UPDATE=%s, ALL=%s',
      count(*) filter (where policy.cmd = 'SELECT'),
      count(*) filter (where policy.cmd = 'INSERT'),
      count(*) filter (where policy.cmd = 'UPDATE'),
      count(*) filter (where policy.cmd = 'ALL')
    ),
    case when count(*) filter (where policy.cmd = 'SELECT') = 1
          and count(*) filter (where policy.cmd = 'INSERT') = 1
          and count(*) filter (where policy.cmd = 'UPDATE') = 1
          and count(*) filter (where policy.cmd = 'ALL') = 0
      then 'OK' else 'REVISAR' end
  from pg_policies as policy
  where policy.schemaname = 'public'
    and policy.tablename = 'municipality_capability_assessments'

  union all

  select
    'Policies DELETE',
    '0',
    count(*)::text,
    case when count(*) = 0 then 'OK' else 'REVISAR' end
  from pg_policies as policy
  where policy.schemaname = 'public'
    and policy.tablename = 'municipality_capability_assessments'
    and policy.cmd in ('DELETE', 'ALL')

  union all

  select
    'Privilégio DELETE para authenticated',
    'false',
    has_table_privilege('authenticated', target_table.relation, 'DELETE')::text,
    case when not has_table_privilege('authenticated', target_table.relation, 'DELETE') then 'OK' else 'REVISAR' end
  from target_table

  union all

  select
    'UPDATE amplo para authenticated',
    'false',
    has_table_privilege('authenticated', target_table.relation, 'UPDATE')::text,
    case when not has_table_privilege('authenticated', target_table.relation, 'UPDATE') then 'OK' else 'REVISAR' end
  from target_table

  union all

  select
    'Colunas UPDATE para authenticated',
    'capacity_level, notes',
    coalesce(string_agg(attribute.attname, ', ' order by attribute.attnum), '(nenhuma)'),
    case when array_agg(attribute.attname order by attribute.attnum) filter (
      where has_column_privilege('authenticated', target_table.relation, attribute.attname, 'UPDATE')
    ) = array['capacity_level', 'notes']::name[] then 'OK' else 'REVISAR' end
  from target_table
  join pg_attribute as attribute
    on attribute.attrelid = target_table.relation
   and attribute.attnum > 0
   and not attribute.attisdropped
   and has_column_privilege('authenticated', target_table.relation, attribute.attname, 'UPDATE')

  union all

  select
    'Campos imutáveis sem UPDATE para authenticated',
    'id, municipality_id, capability_dimension_id, created_at, updated_at',
    coalesce(string_agg(attribute.attname, ', ' order by attribute.attnum), '(nenhum)'),
    case when count(*) = 0 then 'OK' else 'REVISAR' end
  from target_table
  join pg_attribute as attribute
    on attribute.attrelid = target_table.relation
   and attribute.attname = any (array['id', 'municipality_id', 'capability_dimension_id', 'created_at', 'updated_at']::name[])
   and has_column_privilege('authenticated', target_table.relation, attribute.attname, 'UPDATE')

  union all

  select
    'Colunas INSERT para authenticated',
    'municipality_id, capability_dimension_id, capacity_level, notes',
    coalesce(string_agg(attribute.attname, ', ' order by attribute.attnum), '(nenhuma)'),
    case when array_agg(attribute.attname order by attribute.attnum) filter (
      where has_column_privilege('authenticated', target_table.relation, attribute.attname, 'INSERT')
    ) = array['municipality_id', 'capability_dimension_id', 'capacity_level', 'notes']::name[] then 'OK' else 'REVISAR' end
  from target_table
  join pg_attribute as attribute
    on attribute.attrelid = target_table.relation
   and attribute.attnum > 0
   and not attribute.attisdropped
   and has_column_privilege('authenticated', target_table.relation, attribute.attname, 'INSERT')

  union all

  select
    'UNIQUE (municipality_id, capability_dimension_id)',
    'presente',
    case when exists (
      select 1
      from pg_constraint as con
      where con.conrelid = target_table.relation
        and con.contype = 'u'
        and pg_get_constraintdef(con.oid) = 'UNIQUE (municipality_id, capability_dimension_id)'
    ) then 'presente' else 'ausente' end,
    case when exists (
      select 1
      from pg_constraint as con
      where con.conrelid = target_table.relation
        and con.contype = 'u'
        and pg_get_constraintdef(con.oid) = 'UNIQUE (municipality_id, capability_dimension_id)'
    ) then 'OK' else 'REVISAR' end
  from target_table

  union all

  select
    'Triggers updated_at e auditoria',
    '3',
    count(*)::text,
    case when count(*) = 3 then 'OK' else 'REVISAR' end
  from target_table
  join pg_trigger as trigger on trigger.tgrelid = target_table.relation
  where not trigger.tgisinternal
    and trigger.tgname = any (array[
      'municipality_capability_assessments_touch_updated_at',
      'municipality_capability_assessments_audit_insert',
      'municipality_capability_assessments_audit_update'
    ])
)
select check_name, expected, actual, result
from checks
order by check_name;