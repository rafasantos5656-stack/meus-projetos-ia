-- Etapa 20.3.6 — verificação read-only da relação Prefeitura × Oportunidade.
-- Executar manualmente somente no Supabase DEV, após a migration 20260923.

with
main_table as (
  select cls.oid, cls.relrowsecurity, cls.relforcerowsecurity
  from pg_catalog.pg_class as cls
  join pg_catalog.pg_namespace as nsp on nsp.oid = cls.relnamespace
  where nsp.nspname = 'public'
    and cls.relname = 'municipality_opportunities'
    and cls.relkind = 'r'
),
audit_table as (
  select cls.oid, cls.relrowsecurity, cls.relforcerowsecurity
  from pg_catalog.pg_class as cls
  join pg_catalog.pg_namespace as nsp on nsp.oid = cls.relnamespace
  where nsp.nspname = 'public'
    and cls.relname = 'municipality_opportunity_audit'
    and cls.relkind = 'r'
),
expected_main_columns(column_name, data_type, is_nullable) as (
  values
    ('id', 'uuid', 'NO'),
    ('municipality_id', 'uuid', 'NO'),
    ('opportunity_id', 'uuid', 'NO'),
    ('status', 'text', 'NO'),
    ('notes', 'text', 'YES'),
    ('created_at', 'timestamp with time zone', 'NO'),
    ('updated_at', 'timestamp with time zone', 'NO')
),
main_column_state as (
  select
    count(*) filter (where exists (
      select 1
      from information_schema.columns as col
      where col.table_schema = 'public'
        and col.table_name = 'municipality_opportunities'
        and col.column_name = expected.column_name
        and col.data_type = expected.data_type
        and col.is_nullable = expected.is_nullable
    )) as matching_columns,
    count(*) as expected_columns,
    (
      select count(*)
      from information_schema.columns as col
      where col.table_schema = 'public'
        and col.table_name = 'municipality_opportunities'
    ) as actual_columns
  from expected_main_columns as expected
),
expected_audit_columns(column_name, data_type, is_nullable) as (
  values
    ('id', 'uuid', 'NO'),
    ('municipality_opportunity_id', 'uuid', 'NO'),
    ('municipality_id', 'uuid', 'NO'),
    ('opportunity_id', 'uuid', 'NO'),
    ('action', 'text', 'NO'),
    ('actor_user_id', 'uuid', 'YES'),
    ('old_data', 'jsonb', 'YES'),
    ('new_data', 'jsonb', 'YES'),
    ('created_at', 'timestamp with time zone', 'NO')
),
audit_column_state as (
  select
    count(*) filter (where exists (
      select 1
      from information_schema.columns as col
      where col.table_schema = 'public'
        and col.table_name = 'municipality_opportunity_audit'
        and col.column_name = expected.column_name
        and col.data_type = expected.data_type
        and col.is_nullable = expected.is_nullable
    )) as matching_columns,
    count(*) as expected_columns,
    (
      select count(*)
      from information_schema.columns as col
      where col.table_schema = 'public'
        and col.table_name = 'municipality_opportunity_audit'
    ) as actual_columns
  from expected_audit_columns as expected
),
foreign_keys as (
  select
    child_nsp.nspname as child_schema,
    child.relname as child_table,
    child_col.attname as child_column,
    parent_nsp.nspname as parent_schema,
    parent.relname as parent_table,
    parent_col.attname as parent_column,
    con.confdeltype
  from pg_catalog.pg_constraint as con
  join pg_catalog.pg_class as child on child.oid = con.conrelid
  join pg_catalog.pg_namespace as child_nsp on child_nsp.oid = child.relnamespace
  join pg_catalog.pg_class as parent on parent.oid = con.confrelid
  join pg_catalog.pg_namespace as parent_nsp on parent_nsp.oid = parent.relnamespace
  join lateral unnest(con.conkey) with ordinality as child_key(attnum, position)
    on true
  join lateral unnest(con.confkey) with ordinality as parent_key(attnum, position)
    on parent_key.position = child_key.position
  join pg_catalog.pg_attribute as child_col
    on child_col.attrelid = child.oid
   and child_col.attnum = child_key.attnum
  join pg_catalog.pg_attribute as parent_col
    on parent_col.attrelid = parent.oid
   and parent_col.attnum = parent_key.attnum
  where con.contype = 'f'
),
expected_foreign_keys(section, check_name, child_schema, child_table, child_column, parent_schema, parent_table, parent_column, confdeltype) as (
  values
    ('Constraints', 'FK municipality_id → municipalities.id (RESTRICT)', 'public', 'municipality_opportunities', 'municipality_id', 'public', 'municipalities', 'id', 'r'),
    ('Constraints', 'FK opportunity_id → opportunities.id (RESTRICT)', 'public', 'municipality_opportunities', 'opportunity_id', 'public', 'opportunities', 'id', 'r'),
    ('Auditoria', 'FK municipality_opportunity_id → municipality_opportunities.id (RESTRICT)', 'public', 'municipality_opportunity_audit', 'municipality_opportunity_id', 'public', 'municipality_opportunities', 'id', 'r'),
    ('Auditoria', 'FK actor_user_id → auth.users.id (SET NULL)', 'public', 'municipality_opportunity_audit', 'actor_user_id', 'auth', 'users', 'id', 'n')
),
foreign_key_checks as (
  select
    expected.section,
    expected.check_name,
    'presente'::text as expected,
    case when exists (
      select 1
      from foreign_keys as fk
      where fk.child_schema = expected.child_schema
        and fk.child_table = expected.child_table
        and fk.child_column = expected.child_column
        and fk.parent_schema = expected.parent_schema
        and fk.parent_table = expected.parent_table
        and fk.parent_column = expected.parent_column
        and fk.confdeltype = expected.confdeltype
    ) then 'presente' else 'ausente' end as actual
  from expected_foreign_keys as expected
),
main_attnums as (
  select
    max(attnum) filter (where attname = 'municipality_id') as municipality_id,
    max(attnum) filter (where attname = 'opportunity_id') as opportunity_id,
    max(attnum) filter (where attname = 'status') as status
  from pg_catalog.pg_attribute
  where attrelid = (select oid from main_table)
    and attnum > 0
    and not attisdropped
),
index_keys as (
  select
    idx.indexrelid,
    idx.indisunique,
    idx.indnkeyatts,
    idx.indnatts,
    idx.indexprs is null as has_no_expressions,
    idx.indpred is null as has_no_predicate,
    array_agg(att.attname::text order by key_position.position) as key_columns
  from pg_catalog.pg_index as idx
  join pg_catalog.pg_class as index_relation on index_relation.oid = idx.indexrelid
  join pg_catalog.pg_namespace as index_schema on index_schema.oid = index_relation.relnamespace
  join lateral unnest(idx.indkey::smallint[]) with ordinality as key_position(attnum, position)
    on key_position.position <= idx.indnkeyatts::integer
  join pg_catalog.pg_attribute as att
    on att.attrelid = idx.indrelid
   and att.attnum = key_position.attnum
  where idx.indrelid = (select oid from main_table)
    and index_schema.nspname = 'public'
  group by
    idx.indexrelid,
    idx.indisunique,
    idx.indnkeyatts,
    idx.indnatts,
    idx.indexprs is null,
    idx.indpred is null
),
index_state as (
  select
    exists (
      select 1
      from index_keys as idx
      where idx.indisunique
        and idx.has_no_expressions
        and idx.has_no_predicate
        and idx.indnkeyatts = 2
        and idx.indnatts = 2
        and idx.key_columns = array['municipality_id', 'opportunity_id']::text[]
    ) as unique_pair,
    exists (
      select 1
      from index_keys as idx
      where not idx.indisunique
        and idx.has_no_expressions
        and idx.has_no_predicate
        and idx.indnkeyatts = 2
        and idx.indnatts = 2
        and idx.key_columns = array['municipality_id', 'status']::text[]
    ) as municipality_status,
    exists (
      select 1
      from index_keys as idx
      where not idx.indisunique
        and idx.has_no_expressions
        and idx.has_no_predicate
        and idx.indnkeyatts = 1
        and idx.indnatts = 1
        and idx.key_columns = array['opportunity_id']::text[]
    ) as opportunity_id
),
main_constraint_state as (
  select
    exists (
      select 1
      from pg_catalog.pg_constraint as con
      cross join main_attnums as att
      where con.conrelid = (select oid from main_table)
        and con.contype = 'u'
        and con.conkey = array[att.municipality_id, att.opportunity_id]::smallint[]
    ) as unique_pair,
    exists (
      select 1
      from pg_catalog.pg_constraint as con
      where con.conrelid = (select oid from main_table)
        and con.contype = 'c'
        and pg_catalog.pg_get_constraintdef(con.oid, true) ilike '%analyzing%'
        and pg_catalog.pg_get_constraintdef(con.oid, true) ilike '%interested%'
        and pg_catalog.pg_get_constraintdef(con.oid, true) ilike '%review_later%'
        and pg_catalog.pg_get_constraintdef(con.oid, true) ilike '%not_applicable%'
    ) as status_check,
    exists (
      select 1
      from pg_catalog.pg_constraint as con
      where con.conrelid = (select oid from main_table)
        and con.contype = 'c'
        and pg_catalog.pg_get_constraintdef(con.oid, true) ilike '%btrim%'
        and pg_catalog.pg_get_constraintdef(con.oid, true) ilike '%char_length%'
        and pg_catalog.pg_get_constraintdef(con.oid, true) ilike '%4000%'
    ) as notes_check,
    exists (
      select 1
      from pg_catalog.pg_constraint as con
      where con.conrelid = (select oid from audit_table)
        and con.contype = 'c'
        and pg_catalog.pg_get_constraintdef(con.oid, true) ilike '%insert%'
        and pg_catalog.pg_get_constraintdef(con.oid, true) ilike '%update%'
    ) as audit_action_check
),
policy_state as (
  select
    count(*) filter (where tablename = 'municipality_opportunities' and cmd = 'SELECT') as main_select,
    count(*) filter (where tablename = 'municipality_opportunities' and cmd = 'INSERT') as main_insert,
    count(*) filter (where tablename = 'municipality_opportunities' and cmd = 'UPDATE') as main_update,
    count(*) filter (where tablename = 'municipality_opportunities' and cmd = 'DELETE') as main_delete,
    count(*) filter (where tablename = 'municipality_opportunities' and cmd = 'ALL') as main_all,
    count(*) filter (where tablename = 'municipality_opportunity_audit' and cmd = 'SELECT') as audit_select,
    count(*) filter (where tablename = 'municipality_opportunity_audit' and cmd in ('INSERT', 'UPDATE', 'DELETE', 'ALL')) as audit_write
  from pg_catalog.pg_policies
  where schemaname = 'public'
    and tablename in ('municipality_opportunities', 'municipality_opportunity_audit')
),
column_grants as (
  select
    coalesce(array_agg(column_name::text order by column_name::text) filter (
      where grantee = 'authenticated'
        and table_name = 'municipality_opportunities'
        and privilege_type = 'INSERT'
    ), array[]::text[]) as authenticated_insert,
    coalesce(array_agg(column_name::text order by column_name::text) filter (
      where grantee = 'authenticated'
        and table_name = 'municipality_opportunities'
        and privilege_type = 'UPDATE'
    ), array[]::text[]) as authenticated_update,
    count(*) filter (
      where grantee = 'authenticated'
        and table_name = 'municipality_opportunities'
        and privilege_type = 'REFERENCES'
    ) as authenticated_main_references,
    count(*) filter (
      where grantee = 'authenticated'
        and table_name = 'municipality_opportunity_audit'
        and privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'REFERENCES')
    ) as authenticated_audit_write,
    count(*) filter (where grantee = 'anon') as anon_column_grants
  from information_schema.column_privileges
  where table_schema = 'public'
    and table_name in ('municipality_opportunities', 'municipality_opportunity_audit')
    and grantee in ('authenticated', 'anon')
),
helper_state as (
  select
    proc.oid,
    proc.prosecdef,
    proc.provolatile,
    not exists (
      select 1
      from pg_catalog.aclexplode(coalesce(proc.proacl, pg_catalog.acldefault('f', proc.proowner))) as acl
      where acl.grantee = 0
        and acl.privilege_type = 'EXECUTE'
    ) as public_revoked,
    pg_catalog.has_function_privilege('authenticated', proc.oid, 'EXECUTE') as authenticated_execute
  from pg_catalog.pg_proc as proc
  join pg_catalog.pg_namespace as nsp on nsp.oid = proc.pronamespace
  where nsp.nspname = 'private'
    and proc.proname = 'can_manage_municipality_opportunity'
    and pg_catalog.oidvectortypes(proc.proargtypes) = 'uuid'
),
audit_function_state as (
  select
    proc.oid,
    proc.prosecdef,
    not exists (
      select 1
      from pg_catalog.aclexplode(coalesce(proc.proacl, pg_catalog.acldefault('f', proc.proowner))) as acl
      where acl.grantee = 0
        and acl.privilege_type = 'EXECUTE'
    ) as public_revoked,
    not pg_catalog.has_function_privilege('authenticated', proc.oid, 'EXECUTE') as authenticated_revoked
  from pg_catalog.pg_proc as proc
  join pg_catalog.pg_namespace as nsp on nsp.oid = proc.pronamespace
  where nsp.nspname = 'private'
    and proc.proname = 'audit_municipality_opportunity_change'
    and proc.pronargs = 0
),
trigger_state as (
  select
    count(*) filter (
      where trg.tgrelid = (select oid from main_table)
        and not trg.tgisinternal
        and pg_catalog.pg_get_triggerdef(trg.oid, true) ilike '%before update%'
        and pg_catalog.pg_get_triggerdef(trg.oid, true) ilike '%private.touch_updated_at%'
    ) as updated_at_triggers,
    count(*) filter (
      where trg.tgrelid = (select oid from main_table)
        and not trg.tgisinternal
        and pg_catalog.pg_get_triggerdef(trg.oid, true) ilike '%after insert%'
        and pg_catalog.pg_get_triggerdef(trg.oid, true) ilike '%private.audit_municipality_opportunity_change%'
    ) as audit_insert_triggers,
    count(*) filter (
      where trg.tgrelid = (select oid from main_table)
        and not trg.tgisinternal
        and pg_catalog.pg_get_triggerdef(trg.oid, true) ilike '%after update of status, notes%'
        and pg_catalog.pg_get_triggerdef(trg.oid, true) ilike '%old.status is distinct from new.status%'
        and pg_catalog.pg_get_triggerdef(trg.oid, true) ilike '%old.notes is distinct from new.notes%'
        and pg_catalog.pg_get_triggerdef(trg.oid, true) ilike '%private.audit_municipality_opportunity_change%'
    ) as audit_update_triggers
  from pg_catalog.pg_trigger as trg
),
default_state as (
  select
    max(pg_catalog.pg_get_expr(def.adbin, def.adrelid)) filter (where att.attname = 'id') as id_default,
    max(pg_catalog.pg_get_expr(def.adbin, def.adrelid)) filter (where att.attname = 'status') as status_default,
    max(pg_catalog.pg_get_expr(def.adbin, def.adrelid)) filter (where att.attname = 'created_at') as created_at_default,
    max(pg_catalog.pg_get_expr(def.adbin, def.adrelid)) filter (where att.attname = 'updated_at') as updated_at_default
  from pg_catalog.pg_attrdef as def
  join pg_catalog.pg_attribute as att
    on att.attrelid = def.adrelid
   and att.attnum = def.adnum
  where def.adrelid = (select oid from main_table)
),
data_state as (
  select
    (select count(*) from public.municipality_opportunities) as municipality_opportunities_count,
    (select count(*) from public.municipality_opportunity_audit) as municipality_opportunity_audit_count
),
checks as (
  select 10 as sort_order, 'Tabelas'::text as section, 'Tabelas públicas existentes'::text as check_name,
    '2/2'::text as expected,
    ((select count(*) from main_table) + (select count(*) from audit_table))::text || '/2' as actual,
    case when (select count(*) from main_table) = 1 and (select count(*) from audit_table) = 1 then 'OK' else 'PROBLEMA' end as result
  union all
  select 20, 'Colunas principais', 'Colunas, tipos e nullability', '7/7 sem colunas extras',
    matching_columns::text || '/7; total=' || actual_columns::text,
    case when matching_columns = 7 and actual_columns = 7 then 'OK' else 'PROBLEMA' end
  from main_column_state
  union all
  select 30 + row_number() over (order by check_name), section, check_name, expected, actual,
    case when actual = 'presente' then 'OK' else 'PROBLEMA' end
  from foreign_key_checks
  union all
  select 40, 'Constraints', 'Quantidade de FKs estruturais esperadas', '4',
    (select count(*) from foreign_key_checks where actual = 'presente')::text,
    case when (select count(*) from foreign_key_checks where actual = 'presente') = 4 then 'OK' else 'PROBLEMA' end
  union all
  select 50, 'Constraints', 'UNIQUE (municipality_id, opportunity_id)', 'presente',
    case when unique_pair then 'presente' else 'ausente' end,
    case when unique_pair then 'OK' else 'PROBLEMA' end
  from main_constraint_state
  union all
  select 60, 'Constraints', 'CHECK de status com quatro valores', 'presente',
    case when status_check then 'presente' else 'ausente' end,
    case when status_check then 'OK' else 'PROBLEMA' end
  from main_constraint_state
  union all
  select 70, 'Constraints', 'CHECK de notes: btrim, não vazio e até 4000', 'presente',
    case when notes_check then 'presente' else 'ausente' end,
    case when notes_check then 'OK' else 'PROBLEMA' end
  from main_constraint_state
  union all
  select 80, 'Índices', 'Índice UNIQUE (municipality_id, opportunity_id)', 'presente',
    case when unique_pair then 'presente' else 'ausente' end,
    case when unique_pair then 'OK' else 'PROBLEMA' end
  from index_state
  union all
  select 90, 'Índices', 'Índice (municipality_id, status)', 'presente',
    case when municipality_status then 'presente' else 'ausente' end,
    case when municipality_status then 'OK' else 'PROBLEMA' end
  from index_state
  union all
  select 100, 'Índices', 'Índice (opportunity_id)', 'presente',
    case when opportunity_id then 'presente' else 'ausente' end,
    case when opportunity_id then 'OK' else 'PROBLEMA' end
  from index_state
  union all
  select 110, 'RLS principal', 'RLS ENABLE e FORCE', 'habilitado/forçado',
    case when relrowsecurity and relforcerowsecurity then 'habilitado/forçado' else 'incompleto' end,
    case when relrowsecurity and relforcerowsecurity then 'OK' else 'PROBLEMA' end
  from main_table
  union all
  select 120, 'Policies principal', 'SELECT / INSERT / UPDATE / DELETE / ALL', '1 / 1 / 1 / 0 / 0',
    main_select::text || ' / ' || main_insert::text || ' / ' || main_update::text || ' / ' || main_delete::text || ' / ' || main_all::text,
    case when main_select = 1 and main_insert = 1 and main_update = 1 and main_delete = 0 and main_all = 0 then 'OK' else 'PROBLEMA' end
  from policy_state
  union all
  select 130, 'Grants principal', 'SELECT authenticated disponível', 'sim',
    case when pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunities', 'SELECT') then 'sim' else 'não' end,
    case when pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunities', 'SELECT') then 'OK' else 'PROBLEMA' end
  union all
  select 140, 'Grants principal', 'INSERT authenticated por coluna', 'municipality_id, opportunity_id, notes, status',
    array_to_string(authenticated_insert, ', '),
    case when authenticated_insert = array['municipality_id', 'notes', 'opportunity_id', 'status']::text[] then 'OK' else 'PROBLEMA' end
  from column_grants
  union all
  select 150, 'Grants principal', 'UPDATE authenticated por coluna', 'notes, status',
    array_to_string(authenticated_update, ', '),
    case when authenticated_update = array['notes', 'status']::text[] then 'OK' else 'PROBLEMA' end
  from column_grants
  union all
  select 160, 'Grants principal', 'DELETE / TRUNCATE / REFERENCES / TRIGGER authenticated', '0 / 0 / 0 / 0',
    (pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunities', 'DELETE')::int)::text || ' / ' ||
    (pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunities', 'TRUNCATE')::int)::text || ' / ' ||
    (pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunities', 'REFERENCES')::int)::text || ' / ' ||
    (pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunities', 'TRIGGER')::int)::text,
    case when not pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunities', 'DELETE')
              and not pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunities', 'TRUNCATE')
              and not pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunities', 'REFERENCES')
              and not pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunities', 'TRIGGER')
         then 'OK' else 'PROBLEMA' end
  union all
  select 170, 'Grants principal', 'REFERENCES authenticated por coluna', '0', authenticated_main_references::text,
    case when authenticated_main_references = 0 then 'OK' else 'PROBLEMA' end
  from column_grants
  union all
  select 180, 'Grants principal', 'Privilégios anon em tabela e coluna', '0',
    ((select count(*) from (values ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')) as privilege(privilege_name)
      where pg_catalog.has_table_privilege('anon', 'public.municipality_opportunities', privilege.privilege_name)) + anon_column_grants)::text,
    case when (select count(*) from (values ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')) as privilege(privilege_name)
      where pg_catalog.has_table_privilege('anon', 'public.municipality_opportunities', privilege.privilege_name)) = 0
      and anon_column_grants = 0 then 'OK' else 'PROBLEMA' end
  from column_grants
  union all
  select 190, 'Helper', 'SECURITY DEFINER + STABLE', 'sim',
    case when prosecdef and provolatile = 's' then 'sim' else 'não' end,
    case when prosecdef and provolatile = 's' then 'OK' else 'PROBLEMA' end
  from helper_state
  union all
  select 200, 'Helper', 'EXECUTE: PUBLIC revogado / authenticated permitido', 'sim / sim',
    case when public_revoked then 'sim' else 'não' end || ' / ' || case when authenticated_execute then 'sim' else 'não' end,
    case when public_revoked and authenticated_execute then 'OK' else 'PROBLEMA' end
  from helper_state
  union all
  select 210, 'Trigger updated_at', 'Um trigger não interno usando private.touch_updated_at()', '1', updated_at_triggers::text,
    case when updated_at_triggers = 1 then 'OK' else 'PROBLEMA' end
  from trigger_state
  union all
  select 220, 'Auditoria', 'Colunas, tipos e nullability', '9/9 sem colunas extras',
    matching_columns::text || '/9; total=' || actual_columns::text,
    case when matching_columns = 9 and actual_columns = 9 then 'OK' else 'PROBLEMA' end
  from audit_column_state
  union all
  select 230, 'Auditoria', 'CHECK action: insert/update', 'presente',
    case when audit_action_check then 'presente' else 'ausente' end,
    case when audit_action_check then 'OK' else 'PROBLEMA' end
  from main_constraint_state
  union all
  select 240, 'Auditoria', 'RLS ENABLE e FORCE', 'habilitado/forçado',
    case when relrowsecurity and relforcerowsecurity then 'habilitado/forçado' else 'incompleto' end,
    case when relrowsecurity and relforcerowsecurity then 'OK' else 'PROBLEMA' end
  from audit_table
  union all
  select 250, 'Auditoria', 'Policies SELECT / escrita', '1 / 0', audit_select::text || ' / ' || audit_write::text,
    case when audit_select = 1 and audit_write = 0 then 'OK' else 'PROBLEMA' end
  from policy_state
  union all
  select 260, 'Auditoria', 'SELECT authenticated disponível', 'sim',
    case when pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunity_audit', 'SELECT') then 'sim' else 'não' end,
    case when pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunity_audit', 'SELECT') then 'OK' else 'PROBLEMA' end
  union all
  select 270, 'Auditoria', 'INSERT / UPDATE / DELETE / TRUNCATE / REFERENCES / TRIGGER authenticated', '0 / 0 / 0 / 0 / 0 / 0',
    (pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunity_audit', 'INSERT')::int)::text || ' / ' ||
    (pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunity_audit', 'UPDATE')::int)::text || ' / ' ||
    (pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunity_audit', 'DELETE')::int)::text || ' / ' ||
    (pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunity_audit', 'TRUNCATE')::int)::text || ' / ' ||
    (pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunity_audit', 'REFERENCES')::int)::text || ' / ' ||
    (pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunity_audit', 'TRIGGER')::int)::text,
    case when not pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunity_audit', 'INSERT')
              and not pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunity_audit', 'UPDATE')
              and not pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunity_audit', 'DELETE')
              and not pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunity_audit', 'TRUNCATE')
              and not pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunity_audit', 'REFERENCES')
              and not pg_catalog.has_table_privilege('authenticated', 'public.municipality_opportunity_audit', 'TRIGGER')
         then 'OK' else 'PROBLEMA' end
  union all
  select 280, 'Auditoria', 'Grants de escrita authenticated por coluna', '0', authenticated_audit_write::text,
    case when authenticated_audit_write = 0 then 'OK' else 'PROBLEMA' end
  from column_grants
  union all
  select 290, 'Auditoria', 'Privilégios anon em tabela e coluna', '0',
    ((select count(*) from (values ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')) as privilege(privilege_name)
      where pg_catalog.has_table_privilege('anon', 'public.municipality_opportunity_audit', privilege.privilege_name)) + anon_column_grants)::text,
    case when (select count(*) from (values ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')) as privilege(privilege_name)
      where pg_catalog.has_table_privilege('anon', 'public.municipality_opportunity_audit', privilege.privilege_name)) = 0
      and anon_column_grants = 0 then 'OK' else 'PROBLEMA' end
  from column_grants
  union all
  select 300, 'Função auditoria', 'SECURITY DEFINER; PUBLIC e authenticated sem EXECUTE', 'sim',
    case when prosecdef and public_revoked and authenticated_revoked then 'sim' else 'não' end,
    case when prosecdef and public_revoked and authenticated_revoked then 'OK' else 'PROBLEMA' end
  from audit_function_state
  union all
  select 310, 'Triggers auditoria', 'INSERT e UPDATE condicionado a status/notes', '1 / 1',
    audit_insert_triggers::text || ' / ' || audit_update_triggers::text,
    case when audit_insert_triggers = 1 and audit_update_triggers = 1 then 'OK' else 'PROBLEMA' end
  from trigger_state
  union all
  select 320, 'Defaults', 'status = analyzing', 'analyzing',
    coalesce(status_default, 'ausente'),
    case when status_default ilike '%analyzing%' then 'OK' else 'PROBLEMA' end
  from default_state
  union all
  select 330, 'Defaults', 'id = gen_random_uuid()', 'gen_random_uuid()',
    coalesce(id_default, 'ausente'),
    case when id_default ilike '%gen_random_uuid%' then 'OK' else 'PROBLEMA' end
  from default_state
  union all
  select 340, 'Defaults', 'created_at = now()', 'now()',
    coalesce(created_at_default, 'ausente'),
    case when created_at_default ilike '%now()%' then 'OK' else 'PROBLEMA' end
  from default_state
  union all
  select 350, 'Defaults', 'updated_at = now()', 'now()',
    coalesce(updated_at_default, 'ausente'),
    case when updated_at_default ilike '%now()%' then 'OK' else 'PROBLEMA' end
  from default_state
  union all
  select 360, 'Dados iniciais', 'municipality_opportunities sem registros', '0', municipality_opportunities_count::text,
    case when municipality_opportunities_count = 0 then 'OK' else 'PROBLEMA' end
  from data_state
  union all
  select 370, 'Dados iniciais', 'municipality_opportunity_audit sem registros', '0', municipality_opportunity_audit_count::text,
    case when municipality_opportunity_audit_count = 0 then 'OK' else 'PROBLEMA' end
  from data_state
)
select section, check_name, expected, actual, result
from checks
order by sort_order, check_name;