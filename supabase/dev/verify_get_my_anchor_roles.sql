-- Verificação read-only do RPC público de papéis globais Âncora.
-- Execute somente no SQL Editor do Supabase DEV após aplicar a migration 20260920.
-- Não cria, altera ou remove objetos/dados.

with target_function as (
  select
    procedure.oid,
    procedure.pronargs,
    procedure.prosecdef,
    procedure.proconfig,
    procedure.proacl,
    procedure.proowner,
    pg_catalog.pg_get_function_result(procedure.oid) as result_signature,
    pg_catalog.pg_get_functiondef(procedure.oid) as definition
  from pg_catalog.pg_proc as procedure
  join pg_catalog.pg_namespace as namespace
    on namespace.oid = procedure.pronamespace
  where namespace.nspname = 'public'
    and procedure.proname = 'get_my_anchor_roles'
    and procedure.pronargs = 0
),
checks as (
  select
    'RPC existe'::text as check_name,
    '1 função public.get_my_anchor_roles()'::text as expected,
    (select count(*)::text from target_function) as actual,
    case when (select count(*) from target_function) = 1 then 'OK' else 'REVIEW' end as result

  union all

  select
    'RPC não aceita user_id',
    '0 argumentos',
    coalesce((select pronargs::text from target_function), 'não encontrada'),
    case when (select count(*) from target_function) = 1
      and (select pronargs from target_function) = 0 then 'OK' else 'REVIEW' end

  union all

  select
    'Resultado mínimo',
    'TABLE(role_code text)',
    coalesce((select result_signature from target_function), 'não encontrada'),
    case when (select result_signature from target_function) = 'TABLE(role_code text)'
      then 'OK' else 'REVIEW' end

  union all

  select
    'SECURITY DEFINER',
    'habilitado',
    coalesce((select prosecdef::text from target_function), 'não encontrada'),
    case when (select prosecdef from target_function) then 'OK' else 'REVIEW' end

  union all

  select
    'search_path seguro',
    'search_path=pg_catalog',
    coalesce((select array_to_string(proconfig, ', ') from target_function), 'não encontrada'),
    case when (select proconfig @> array['search_path=pg_catalog'] from target_function)
      then 'OK' else 'REVIEW' end

  union all

  select
    'Filtro pelo usuário autenticado',
    'auth.uid() no corpo da função',
    case when (select position('auth.uid()' in definition) > 0 from target_function)
      then 'presente' else 'ausente' end,
    case when (select position('auth.uid()' in definition) > 0 from target_function)
      then 'OK' else 'REVIEW' end

  union all

  select
    'Somente papéis do escopo Âncora',
    'role_scope = anchor',
    case when (select position('role_scope = ''anchor''' in definition) > 0 from target_function)
      then 'presente' else 'ausente' end,
    case when (select position('role_scope = ''anchor''' in definition) > 0 from target_function)
      then 'OK' else 'REVIEW' end

  union all

  select
    'Papéis municipais fora do RPC',
    'sem municipality_member_roles',
    case when (select position('municipality_member_roles' in definition) = 0 from target_function)
      then 'ausente' else 'presente' end,
    case when (select position('municipality_member_roles' in definition) = 0 from target_function)
      then 'OK' else 'REVIEW' end

  union all

  select
    'EXECUTE para PUBLIC',
    'bloqueado',
    case when exists (
      select 1
      from target_function
      cross join lateral pg_catalog.aclexplode(
        coalesce(proacl, pg_catalog.acldefault('f'::"char", proowner))
      ) as privilege(grantor, grantee, privilege_type, is_grantable)
      where privilege.grantee = 0
        and privilege.privilege_type = 'EXECUTE'
    ) then 'concedido' else 'bloqueado' end,
    case when not exists (
      select 1
      from target_function
      cross join lateral pg_catalog.aclexplode(
        coalesce(proacl, pg_catalog.acldefault('f'::"char", proowner))
      ) as privilege(grantor, grantee, privilege_type, is_grantable)
      where privilege.grantee = 0
        and privilege.privilege_type = 'EXECUTE'
    ) then 'OK' else 'REVIEW' end

  union all

  select
    'EXECUTE para anon',
    'bloqueado',
    case when (select pg_catalog.has_function_privilege('anon', oid, 'EXECUTE') from target_function)
      then 'concedido' else 'bloqueado' end,
    case when not coalesce((select pg_catalog.has_function_privilege('anon', oid, 'EXECUTE') from target_function), false)
      then 'OK' else 'REVIEW' end

  union all

  select
    'EXECUTE para authenticated',
    'concedido',
    case when (select pg_catalog.has_function_privilege('authenticated', oid, 'EXECUTE') from target_function)
      then 'concedido' else 'bloqueado' end,
    case when coalesce((select pg_catalog.has_function_privilege('authenticated', oid, 'EXECUTE') from target_function), false)
      then 'OK' else 'REVIEW' end

  union all

  select
    'SELECT direto em anchor_user_roles para authenticated',
    'bloqueado',
    case when pg_catalog.has_table_privilege('authenticated', 'public.anchor_user_roles', 'SELECT')
      then 'concedido' else 'bloqueado' end,
    case when not pg_catalog.has_table_privilege('authenticated', 'public.anchor_user_roles', 'SELECT')
      then 'OK' else 'REVIEW' end

  union all

  select
    'SELECT direto em anchor_user_roles para anon',
    'bloqueado',
    case when pg_catalog.has_table_privilege('anon', 'public.anchor_user_roles', 'SELECT')
      then 'concedido' else 'bloqueado' end,
    case when not pg_catalog.has_table_privilege('anon', 'public.anchor_user_roles', 'SELECT')
      then 'OK' else 'REVIEW' end

  union all

  select
    'RLS de anchor_user_roles',
    'habilitado',
    case when class.relrowsecurity then 'habilitado' else 'desabilitado' end,
    case when class.relrowsecurity then 'OK' else 'REVIEW' end
  from pg_catalog.pg_class as class
  join pg_catalog.pg_namespace as namespace
    on namespace.oid = class.relnamespace
  where namespace.nspname = 'public'
    and class.relname = 'anchor_user_roles'
)
select check_name, expected, actual, result
from checks
order by check_name;