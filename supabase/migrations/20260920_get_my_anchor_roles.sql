-- RPC mínimo para o usuário autenticado consultar exclusivamente os próprios
-- papéis globais da Âncora. Não concede acesso direto às tabelas de papéis.
-- Depende de 20260909_anchor_multitenant_foundation.sql.

begin;

create or replace function public.get_my_anchor_roles()
returns table (role_code text)
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select role_assignment.role_code
  from public.anchor_user_roles as role_assignment
  where (select auth.uid()) is not null
    and role_assignment.user_id = (select auth.uid())
    and role_assignment.role_scope = 'anchor'::public.role_scope
  order by role_assignment.role_code;
$$;

-- Funções têm EXECUTE para PUBLIC por padrão no PostgreSQL. Acesso fica
-- limitado ao papel authenticated; anon e PUBLIC não podem invocar o RPC.
revoke all on function public.get_my_anchor_roles() from public, anon, authenticated;
grant execute on function public.get_my_anchor_roles() to authenticated;

commit;