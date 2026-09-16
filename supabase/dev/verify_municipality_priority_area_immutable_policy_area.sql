-- Verificação READ-ONLY dos privilégios efetivos de authenticated.
-- Execute somente após aplicar 20260919_municipality_priority_area_immutable_policy_area.sql.

with privilege_checks (operation, column_name, expected_allowed, actual_allowed) as (
  values
    ('INSERT', 'municipality_id', true, has_column_privilege('authenticated', 'public.municipality_priority_areas', 'municipality_id', 'INSERT')),
    ('INSERT', 'policy_area_id', true, has_column_privilege('authenticated', 'public.municipality_priority_areas', 'policy_area_id', 'INSERT')),
    ('INSERT', 'priority_level', true, has_column_privilege('authenticated', 'public.municipality_priority_areas', 'priority_level', 'INSERT')),
    ('INSERT', 'notes', true, has_column_privilege('authenticated', 'public.municipality_priority_areas', 'notes', 'INSERT')),
    ('INSERT', 'status', true, has_column_privilege('authenticated', 'public.municipality_priority_areas', 'status', 'INSERT')),
    ('UPDATE', 'priority_level', true, has_column_privilege('authenticated', 'public.municipality_priority_areas', 'priority_level', 'UPDATE')),
    ('UPDATE', 'notes', true, has_column_privilege('authenticated', 'public.municipality_priority_areas', 'notes', 'UPDATE')),
    ('UPDATE', 'status', true, has_column_privilege('authenticated', 'public.municipality_priority_areas', 'status', 'UPDATE')),
    ('UPDATE', 'municipality_id', false, has_column_privilege('authenticated', 'public.municipality_priority_areas', 'municipality_id', 'UPDATE')),
    ('UPDATE', 'policy_area_id', false, has_column_privilege('authenticated', 'public.municipality_priority_areas', 'policy_area_id', 'UPDATE')),
    ('UPDATE', 'id', false, has_column_privilege('authenticated', 'public.municipality_priority_areas', 'id', 'UPDATE')),
    ('UPDATE', 'created_at', false, has_column_privilege('authenticated', 'public.municipality_priority_areas', 'created_at', 'UPDATE')),
    ('UPDATE', 'updated_at', false, has_column_privilege('authenticated', 'public.municipality_priority_areas', 'updated_at', 'UPDATE')),
    ('DELETE', null, false, has_table_privilege('authenticated', 'public.municipality_priority_areas', 'DELETE'))
)
select
  operation,
  coalesce(column_name, '—') as column_name,
  case when expected_allowed then 'PERMITIDO' else 'NÃO permitido' end as expected,
  case when actual_allowed then 'PERMITIDO' else 'NÃO permitido' end as actual,
  case when actual_allowed = expected_allowed then 'OK' else 'PROBLEMA' end as result
from privilege_checks
order by
  case operation when 'INSERT' then 1 when 'UPDATE' then 2 else 3 end,
  column_name nulls last;