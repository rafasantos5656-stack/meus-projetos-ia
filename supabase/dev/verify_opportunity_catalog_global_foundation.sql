-- Etapa 20.2.5 — verificação exclusivamente read-only da fundação global.
-- Execute somente no SQL Editor do Supabase DEV, após a migration 20260922.

with
expected_tables(table_name) as (
  values
    ('opportunity_sources'),
    ('opportunities'),
    ('opportunity_policy_areas'),
    ('opportunity_versions')
),
expected_columns(table_name, column_name) as (
  values
    ('opportunity_sources', 'id'),
    ('opportunity_sources', 'code'),
    ('opportunity_sources', 'name'),
    ('opportunity_sources', 'sphere'),
    ('opportunity_sources', 'official_base_url'),
    ('opportunity_sources', 'active'),
    ('opportunity_sources', 'created_at'),
    ('opportunity_sources', 'updated_at'),
    ('opportunities', 'id'),
    ('opportunities', 'source_id'),
    ('opportunities', 'external_id'),
    ('opportunities', 'sphere'),
    ('opportunities', 'granting_body'),
    ('opportunities', 'program_name'),
    ('opportunities', 'title'),
    ('opportunities', 'description'),
    ('opportunities', 'eligibility_summary'),
    ('opportunities', 'coverage_type'),
    ('opportunities', 'eligible_ufs'),
    ('opportunities', 'amount'),
    ('opportunities', 'amount_kind'),
    ('opportunities', 'opens_on'),
    ('opportunities', 'closes_on'),
    ('opportunities', 'status'),
    ('opportunities', 'official_url'),
    ('opportunities', 'source_updated_at'),
    ('opportunities', 'last_checked_at'),
    ('opportunities', 'is_published'),
    ('opportunities', 'created_at'),
    ('opportunities', 'updated_at'),
    ('opportunity_policy_areas', 'opportunity_id'),
    ('opportunity_policy_areas', 'policy_area_id'),
    ('opportunity_versions', 'id'),
    ('opportunity_versions', 'opportunity_id'),
    ('opportunity_versions', 'version_number'),
    ('opportunity_versions', 'captured_at'),
    ('opportunity_versions', 'source_updated_at'),
    ('opportunity_versions', 'change_hash'),
    ('opportunity_versions', 'snapshot')
),
table_state as (
  select
    expected.table_name,
    rel.oid,
    rel.relrowsecurity,
    rel.relforcerowsecurity
  from expected_tables as expected
  left join pg_catalog.pg_namespace as namespace
    on namespace.nspname = 'public'
  left join pg_catalog.pg_class as rel
    on rel.relnamespace = namespace.oid
   and rel.relname = expected.table_name
   and rel.relkind = 'r'
),
missing_columns as (
  select
    expected.table_name,
    count(*) filter (where columns.column_name is null) as missing_count
  from expected_columns as expected
  left join information_schema.columns as columns
    on columns.table_schema = 'public'
   and columns.table_name = expected.table_name
   and columns.column_name = expected.column_name
  group by expected.table_name
),
foreign_key_state as (
  select
    con.oid as foreign_key_oid,
    source_namespace.nspname as source_schema,
    source_relation.relname as source_table,
    source_attribute.attname as source_column,
    target_namespace.nspname as target_schema,
    target_relation.relname as target_table,
    target_attribute.attname as target_column,
    con.confdeltype,
    pg_catalog.cardinality(con.conkey) as source_column_count,
    pg_catalog.cardinality(con.confkey) as target_column_count
  from pg_catalog.pg_constraint as con
  join pg_catalog.pg_class as source_relation
    on source_relation.oid = con.conrelid
  join pg_catalog.pg_namespace as source_namespace
    on source_namespace.oid = source_relation.relnamespace
  join pg_catalog.pg_class as target_relation
    on target_relation.oid = con.confrelid
  join pg_catalog.pg_namespace as target_namespace
    on target_namespace.oid = target_relation.relnamespace
  join lateral pg_catalog.unnest(con.conkey) with ordinality as source_key(attnum, position)
    on true
  join lateral pg_catalog.unnest(con.confkey) with ordinality as target_key(attnum, position)
    on target_key.position = source_key.position
  join pg_catalog.pg_attribute as source_attribute
    on source_attribute.attrelid = con.conrelid
   and source_attribute.attnum = source_key.attnum
   and not source_attribute.attisdropped
  join pg_catalog.pg_attribute as target_attribute
    on target_attribute.attrelid = con.confrelid
   and target_attribute.attnum = target_key.attnum
   and not target_attribute.attisdropped
  where source_namespace.nspname = 'public'
    and source_relation.relname in (
      'opportunities',
      'opportunity_policy_areas',
      'opportunity_versions'
    )
    and con.contype = 'f'
),
expected_foreign_keys(check_order, check_name, source_table, source_column, target_schema, target_table, target_column) as (
  values
    (10, 'FK opportunities.source_id → opportunity_sources.id (RESTRICT)', 'opportunities', 'source_id', 'public', 'opportunity_sources', 'id'),
    (20, 'FK opportunity_policy_areas.opportunity_id → opportunities.id (RESTRICT)', 'opportunity_policy_areas', 'opportunity_id', 'public', 'opportunities', 'id'),
    (30, 'FK opportunity_policy_areas.policy_area_id → policy_areas.id (RESTRICT)', 'opportunity_policy_areas', 'policy_area_id', 'public', 'policy_areas', 'id'),
    (40, 'FK opportunity_versions.opportunity_id → opportunities.id (RESTRICT)', 'opportunity_versions', 'opportunity_id', 'public', 'opportunities', 'id')
),
foreign_key_checks as (
  select
    expected.check_order,
    expected.check_name,
    exists (
      select 1
      from foreign_key_state as actual
      where actual.source_schema = 'public'
        and actual.source_table = expected.source_table
        and actual.source_column = expected.source_column
        and actual.target_schema = expected.target_schema
        and actual.target_table = expected.target_table
        and actual.target_column = expected.target_column
        and actual.confdeltype = 'r'
        and actual.source_column_count = 1
        and actual.target_column_count = 1
    ) as passed
  from expected_foreign_keys as expected
),
key_state as (
  select
    rel.relname as table_name,
    con.contype,
    pg_catalog.pg_get_constraintdef(con.oid) as definition
  from pg_catalog.pg_constraint as con
  join pg_catalog.pg_class as rel
    on rel.oid = con.conrelid
  join pg_catalog.pg_namespace as namespace
    on namespace.oid = rel.relnamespace
  where namespace.nspname = 'public'
    and rel.relname in (
      'opportunity_sources',
      'opportunities',
      'opportunity_policy_areas',
      'opportunity_versions'
    )
    and con.contype in ('p', 'u')
),
index_state as (
  select
    indexname,
    indexdef
  from pg_catalog.pg_indexes
  where schemaname = 'public'
    and tablename in (
      'opportunities',
      'opportunity_policy_areas',
      'opportunity_versions'
    )
),
policy_state as (
  select
    tablename,
    policyname,
    cmd,
    roles
  from pg_catalog.pg_policies
  where schemaname = 'public'
    and tablename in (
      'opportunity_sources',
      'opportunities',
      'opportunity_policy_areas',
      'opportunity_versions'
    )
),
trigger_state as (
  select
    rel.relname as table_name,
    trigger.tgname,
    pg_catalog.pg_get_triggerdef(trigger.oid) as definition
  from pg_catalog.pg_trigger as trigger
  join pg_catalog.pg_class as rel
    on rel.oid = trigger.tgrelid
  join pg_catalog.pg_namespace as namespace
    on namespace.oid = rel.relnamespace
  where namespace.nspname = 'public'
    and rel.relname in (
      'opportunity_sources',
      'opportunities',
      'opportunity_policy_areas',
      'opportunity_versions'
    )
    and not trigger.tgisinternal
),
default_state as (
  select
    table_name,
    column_name,
    column_default
  from information_schema.columns
  where table_schema = 'public'
    and (
      (table_name = 'opportunity_sources' and column_name = 'active')
      or (table_name = 'opportunities' and column_name in ('coverage_type', 'status', 'is_published'))
    )
),
authenticated_column_write_grants as (
  select count(*) as grant_count
  from information_schema.column_privileges
  where table_schema = 'public'
    and table_name in (
      'opportunity_sources',
      'opportunities',
      'opportunity_policy_areas',
      'opportunity_versions'
    )
    and grantee = 'authenticated'
    and privilege_type in ('INSERT', 'UPDATE', 'REFERENCES')
),
table_counts as (
  select
    (select count(*) from public.opportunity_sources) as opportunity_sources_count,
    (select count(*) from public.opportunities) as opportunities_count,
    (select count(*) from public.opportunity_policy_areas) as opportunity_policy_areas_count,
    (select count(*) from public.opportunity_versions) as opportunity_versions_count
),
checks(section_order, check_order, section, check_name, expected, actual, passed) as (
  select 10, 10, 'Tabelas', 'Tabelas globais existentes', '4',
    count(*) filter (where oid is not null)::text,
    count(*) filter (where oid is not null) = 4
  from table_state

  union all

  select 20, 10, 'Colunas', 'Colunas obrigatórias ausentes — opportunity_sources', '0',
    missing_count::text,
    missing_count = 0
  from missing_columns
  where table_name = 'opportunity_sources'

  union all

  select 20, 20, 'Colunas', 'Colunas obrigatórias ausentes — opportunities', '0',
    missing_count::text,
    missing_count = 0
  from missing_columns
  where table_name = 'opportunities'

  union all

  select 20, 30, 'Colunas', 'Colunas obrigatórias ausentes — opportunity_policy_areas', '0',
    missing_count::text,
    missing_count = 0
  from missing_columns
  where table_name = 'opportunity_policy_areas'

  union all

  select 20, 40, 'Colunas', 'Colunas obrigatórias ausentes — opportunity_versions', '0',
    missing_count::text,
    missing_count = 0
  from missing_columns
  where table_name = 'opportunity_versions'

  union all

  select 30, check_order, 'Chaves estrangeiras', check_name, 'presente',
    case when passed then 'presente' else 'ausente' end,
    passed
  from foreign_key_checks

  union all

  select 30, 50, 'Chaves estrangeiras', 'Quantidade total de FKs da fundação', '4',
    (select count(distinct foreign_key_oid) from foreign_key_state)::text,
    (select count(distinct foreign_key_oid) from foreign_key_state) = 4

  union all

  select 40, 10, 'Chaves únicas', 'opportunity_sources.code UNIQUE', 'presente',
    case when exists (
      select 1 from key_state
      where table_name = 'opportunity_sources'
        and contype = 'u'
        and definition = 'UNIQUE (code)'
    ) then 'presente' else 'ausente' end,
    exists (
      select 1 from key_state
      where table_name = 'opportunity_sources'
        and contype = 'u'
        and definition = 'UNIQUE (code)'
    )

  union all

  select 40, 20, 'Chaves únicas', 'opportunities (source_id, external_id) UNIQUE', 'presente',
    case when exists (
      select 1 from key_state
      where table_name = 'opportunities'
        and contype = 'u'
        and definition = 'UNIQUE (source_id, external_id)'
    ) then 'presente' else 'ausente' end,
    exists (
      select 1 from key_state
      where table_name = 'opportunities'
        and contype = 'u'
        and definition = 'UNIQUE (source_id, external_id)'
    )

  union all

  select 40, 30, 'Chaves únicas', 'opportunity_policy_areas PK composta', 'presente',
    case when exists (
      select 1 from key_state
      where table_name = 'opportunity_policy_areas'
        and contype = 'p'
        and definition = 'PRIMARY KEY (opportunity_id, policy_area_id)'
    ) then 'presente' else 'ausente' end,
    exists (
      select 1 from key_state
      where table_name = 'opportunity_policy_areas'
        and contype = 'p'
        and definition = 'PRIMARY KEY (opportunity_id, policy_area_id)'
    )

  union all

  select 40, 40, 'Chaves únicas', 'opportunity_versions (opportunity_id, version_number) UNIQUE', 'presente',
    case when exists (
      select 1 from key_state
      where table_name = 'opportunity_versions'
        and contype = 'u'
        and definition = 'UNIQUE (opportunity_id, version_number)'
    ) then 'presente' else 'ausente' end,
    exists (
      select 1 from key_state
      where table_name = 'opportunity_versions'
        and contype = 'u'
        and definition = 'UNIQUE (opportunity_id, version_number)'
    )

  union all

  select 50, 10, 'Índices', 'opportunities (is_published, status, closes_on)', 'presente',
    case when exists (
      select 1 from index_state
      where indexname = 'opportunities_published_status_closes_on_idx'
        and indexdef ilike '%(is_published, status, closes_on)%'
    ) then 'presente' else 'ausente' end,
    exists (
      select 1 from index_state
      where indexname = 'opportunities_published_status_closes_on_idx'
        and indexdef ilike '%(is_published, status, closes_on)%'
    )

  union all

  select 50, 20, 'Índices', 'opportunities (source_id, last_checked_at)', 'presente',
    case when exists (
      select 1 from index_state
      where indexname = 'opportunities_source_last_checked_at_idx'
        and indexdef ilike '%(source_id, last_checked_at)%'
    ) then 'presente' else 'ausente' end,
    exists (
      select 1 from index_state
      where indexname = 'opportunities_source_last_checked_at_idx'
        and indexdef ilike '%(source_id, last_checked_at)%'
    )

  union all

  select 50, 30, 'Índices', 'opportunity_policy_areas (policy_area_id, opportunity_id)', 'presente',
    case when exists (
      select 1 from index_state
      where indexname = 'opportunity_policy_areas_policy_area_opportunity_idx'
        and indexdef ilike '%(policy_area_id, opportunity_id)%'
    ) then 'presente' else 'ausente' end,
    exists (
      select 1 from index_state
      where indexname = 'opportunity_policy_areas_policy_area_opportunity_idx'
        and indexdef ilike '%(policy_area_id, opportunity_id)%'
    )

  union all

  select 50, 40, 'Índices', 'opportunity_versions (opportunity_id, captured_at DESC)', 'presente',
    case when exists (
      select 1 from index_state
      where indexname = 'opportunity_versions_opportunity_captured_at_idx'
        and indexdef ilike '%(opportunity_id, captured_at DESC)%'
    ) then 'presente' else 'ausente' end,
    exists (
      select 1 from index_state
      where indexname = 'opportunity_versions_opportunity_captured_at_idx'
        and indexdef ilike '%(opportunity_id, captured_at DESC)%'
    )

  union all

  select 60, 10, 'RLS', 'Tabelas com RLS habilitado', '4',
    count(*) filter (where relrowsecurity)::text,
    count(*) filter (where relrowsecurity) = 4
  from table_state

  union all

  select 60, 20, 'RLS', 'Tabelas com FORCE RLS', '4',
    count(*) filter (where relforcerowsecurity)::text,
    count(*) filter (where relforcerowsecurity) = 4
  from table_state

  union all

  select 70, 10, 'Policies', 'SELECT authenticated — opportunity_sources', '1',
    count(*) filter (
      where tablename = 'opportunity_sources'
        and cmd = 'SELECT'
        and pg_catalog.array_to_string(roles, ',') like '%authenticated%'
    )::text,
    count(*) filter (
      where tablename = 'opportunity_sources'
        and cmd = 'SELECT'
        and pg_catalog.array_to_string(roles, ',') like '%authenticated%'
    ) = 1
  from policy_state

  union all

  select 70, 20, 'Policies', 'SELECT authenticated — opportunities', '1',
    count(*) filter (
      where tablename = 'opportunities'
        and cmd = 'SELECT'
        and pg_catalog.array_to_string(roles, ',') like '%authenticated%'
    )::text,
    count(*) filter (
      where tablename = 'opportunities'
        and cmd = 'SELECT'
        and pg_catalog.array_to_string(roles, ',') like '%authenticated%'
    ) = 1
  from policy_state

  union all

  select 70, 30, 'Policies', 'SELECT authenticated — opportunity_policy_areas', '1',
    count(*) filter (
      where tablename = 'opportunity_policy_areas'
        and cmd = 'SELECT'
        and pg_catalog.array_to_string(roles, ',') like '%authenticated%'
    )::text,
    count(*) filter (
      where tablename = 'opportunity_policy_areas'
        and cmd = 'SELECT'
        and pg_catalog.array_to_string(roles, ',') like '%authenticated%'
    ) = 1
  from policy_state

  union all

  select 70, 40, 'Policies', 'Policies — opportunity_versions', '0',
    count(*) filter (where tablename = 'opportunity_versions')::text,
    count(*) filter (where tablename = 'opportunity_versions') = 0
  from policy_state

  union all

  select 70, 50, 'Policies', 'Policies de escrita ou ALL', '0',
    count(*) filter (where cmd in ('INSERT', 'UPDATE', 'DELETE', 'ALL'))::text,
    count(*) filter (where cmd in ('INSERT', 'UPDATE', 'DELETE', 'ALL')) = 0
  from policy_state

  union all

  select 80, 10, 'Grants authenticated', 'SELECT em três tabelas públicas', '3',
    (
      case when pg_catalog.has_table_privilege('authenticated', 'public.opportunity_sources', 'SELECT') then 1 else 0 end
      + case when pg_catalog.has_table_privilege('authenticated', 'public.opportunities', 'SELECT') then 1 else 0 end
      + case when pg_catalog.has_table_privilege('authenticated', 'public.opportunity_policy_areas', 'SELECT') then 1 else 0 end
    )::text,
    (
      case when pg_catalog.has_table_privilege('authenticated', 'public.opportunity_sources', 'SELECT') then 1 else 0 end
      + case when pg_catalog.has_table_privilege('authenticated', 'public.opportunities', 'SELECT') then 1 else 0 end
      + case when pg_catalog.has_table_privilege('authenticated', 'public.opportunity_policy_areas', 'SELECT') then 1 else 0 end
    ) = 3

  union all

  select 80, 20, 'Grants authenticated', 'SELECT em opportunity_versions', '0',
    case when pg_catalog.has_table_privilege('authenticated', 'public.opportunity_versions', 'SELECT') then '1' else '0' end,
    not pg_catalog.has_table_privilege('authenticated', 'public.opportunity_versions', 'SELECT')

  union all

  select 80, 30, 'Grants authenticated', 'Privilégios de escrita, TRUNCATE, REFERENCES ou TRIGGER', '0',
    (
      select count(*)
      from (values
        ('public.opportunity_sources'),
        ('public.opportunities'),
        ('public.opportunity_policy_areas'),
        ('public.opportunity_versions')
      ) as target(qualified_name)
      cross join (values
        ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')
      ) as privilege(privilege_name)
      where pg_catalog.has_table_privilege('authenticated', target.qualified_name, privilege.privilege_name)
    )::text,
    (
      select count(*)
      from (values
        ('public.opportunity_sources'),
        ('public.opportunities'),
        ('public.opportunity_policy_areas'),
        ('public.opportunity_versions')
      ) as target(qualified_name)
      cross join (values
        ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')
      ) as privilege(privilege_name)
      where pg_catalog.has_table_privilege('authenticated', target.qualified_name, privilege.privilege_name)
    ) = 0

  union all

  select 80, 40, 'Grants authenticated', 'Privilégios de escrita por coluna', '0',
    grant_count::text,
    grant_count = 0
  from authenticated_column_write_grants

  union all

  select 90, 10, 'Grants anon', 'Privilégios em todas as quatro tabelas', '0',
    (
      select count(*)
      from (values
        ('public.opportunity_sources'),
        ('public.opportunities'),
        ('public.opportunity_policy_areas'),
        ('public.opportunity_versions')
      ) as target(qualified_name)
      cross join (values
        ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')
      ) as privilege(privilege_name)
      where pg_catalog.has_table_privilege('anon', target.qualified_name, privilege.privilege_name)
    )::text,
    (
      select count(*)
      from (values
        ('public.opportunity_sources'),
        ('public.opportunities'),
        ('public.opportunity_policy_areas'),
        ('public.opportunity_versions')
      ) as target(qualified_name)
      cross join (values
        ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')
      ) as privilege(privilege_name)
      where pg_catalog.has_table_privilege('anon', target.qualified_name, privilege.privilege_name)
    ) = 0

  union all

  select 100, 10, 'Triggers', 'updated_at — opportunity_sources', '1',
    count(*) filter (
      where table_name = 'opportunity_sources'
        and tgname = 'opportunity_sources_touch_updated_at'
        and definition ilike '%BEFORE UPDATE%'
        and definition ilike '%private.touch_updated_at()%'
    )::text,
    count(*) filter (
      where table_name = 'opportunity_sources'
        and tgname = 'opportunity_sources_touch_updated_at'
        and definition ilike '%BEFORE UPDATE%'
        and definition ilike '%private.touch_updated_at()%'
    ) = 1
  from trigger_state

  union all

  select 100, 20, 'Triggers', 'updated_at — opportunities', '1',
    count(*) filter (
      where table_name = 'opportunities'
        and tgname = 'opportunities_touch_updated_at'
        and definition ilike '%BEFORE UPDATE%'
        and definition ilike '%private.touch_updated_at()%'
    )::text,
    count(*) filter (
      where table_name = 'opportunities'
        and tgname = 'opportunities_touch_updated_at'
        and definition ilike '%BEFORE UPDATE%'
        and definition ilike '%private.touch_updated_at()%'
    ) = 1
  from trigger_state

  union all

  select 100, 30, 'Triggers', 'Triggers — opportunity_policy_areas', '0',
    count(*) filter (where table_name = 'opportunity_policy_areas')::text,
    count(*) filter (where table_name = 'opportunity_policy_areas') = 0
  from trigger_state

  union all

  select 100, 40, 'Triggers', 'Triggers — opportunity_versions', '0',
    count(*) filter (where table_name = 'opportunity_versions')::text,
    count(*) filter (where table_name = 'opportunity_versions') = 0
  from trigger_state

  union all

  select 110, 10, 'Defaults', 'opportunity_sources.active', 'true',
    coalesce((select column_default from default_state where table_name = 'opportunity_sources' and column_name = 'active'), '<ausente>'),
    coalesce((select column_default from default_state where table_name = 'opportunity_sources' and column_name = 'active'), '') ~* 'true'

  union all

  select 110, 20, 'Defaults', 'opportunities.coverage_type', '''unknown''',
    coalesce((select column_default from default_state where table_name = 'opportunities' and column_name = 'coverage_type'), '<ausente>'),
    coalesce((select column_default from default_state where table_name = 'opportunities' and column_name = 'coverage_type'), '') ~* '''unknown'''

  union all

  select 110, 30, 'Defaults', 'opportunities.status', '''upcoming''',
    coalesce((select column_default from default_state where table_name = 'opportunities' and column_name = 'status'), '<ausente>'),
    coalesce((select column_default from default_state where table_name = 'opportunities' and column_name = 'status'), '') ~* '''upcoming'''

  union all

  select 110, 40, 'Defaults', 'opportunities.is_published', 'false',
    coalesce((select column_default from default_state where table_name = 'opportunities' and column_name = 'is_published'), '<ausente>'),
    coalesce((select column_default from default_state where table_name = 'opportunities' and column_name = 'is_published'), '') ~* 'false'

  union all

  select 120, 10, 'Dados iniciais', 'opportunity_sources', '0', opportunity_sources_count::text,
    opportunity_sources_count = 0
  from table_counts

  union all

  select 120, 20, 'Dados iniciais', 'opportunities', '0', opportunities_count::text,
    opportunities_count = 0
  from table_counts

  union all

  select 120, 30, 'Dados iniciais', 'opportunity_policy_areas', '0', opportunity_policy_areas_count::text,
    opportunity_policy_areas_count = 0
  from table_counts

  union all

  select 120, 40, 'Dados iniciais', 'opportunity_versions', '0', opportunity_versions_count::text,
    opportunity_versions_count = 0
  from table_counts
)
select
  section,
  check_name,
  expected,
  actual,
  case when passed then 'OK' else 'PROBLEMA' end as result
from checks
order by section_order, check_order;