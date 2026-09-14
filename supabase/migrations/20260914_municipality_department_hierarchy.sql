-- Estrutura administrativa hierárquica — DEV somente até revisão e aplicação manual.
-- Esta migration é versionada para execução única e não libera escrita para authenticated.

begin;

alter table public.municipality_departments
  add column unit_type text not null default 'unit',
  add column parent_department_id uuid null,
  add constraint municipality_departments_unit_type_check
    check (unit_type in ('secretariat', 'department', 'sector', 'unit')),
  add constraint municipality_departments_not_own_parent_check
    check (parent_department_id is null or parent_department_id <> id),
  add constraint municipality_departments_parent_tenant_fkey
    foreign key (parent_department_id, municipality_id)
    references public.municipality_departments (id, municipality_id)
    on delete restrict;

-- Suporta a montagem da árvore e a busca por unidades filhas sem duplicar
-- os índices já existentes para nome e município.
create index municipality_departments_parent_tenant_idx
  on public.municipality_departments (municipality_id, parent_department_id)
  where parent_department_id is not null;

-- Impede ciclos, inclusive sob atualizações concorrentes do mesmo município.
-- O lock transacional é por município; assim duas alterações simultâneas de
-- parent_department_id não conseguem criar um ciclo por leituras isoladas.
create or replace function private.assert_municipality_department_acyclic()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  would_create_cycle boolean;
begin
  if new.parent_department_id is null then
    return new;
  end if;

  if new.parent_department_id = new.id then
    raise exception using
      errcode = '23514',
      message = 'Uma unidade administrativa não pode ser sua própria unidade superior.';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.municipality_id::text, 0::bigint)
  );

  with recursive ancestry as (
    select
      parent.id,
      parent.parent_department_id,
      array[parent.id] as visited_ids
    from public.municipality_departments as parent
    where parent.id = new.parent_department_id
      and parent.municipality_id = new.municipality_id

    union all

    select
      parent.id,
      parent.parent_department_id,
      pg_catalog.array_append(ancestry.visited_ids, parent.id)
    from public.municipality_departments as parent
    join ancestry
      on parent.id = ancestry.parent_department_id
     and parent.municipality_id = new.municipality_id
    where not parent.id = any(ancestry.visited_ids)
  )
  select exists (
    select 1
    from ancestry
    where ancestry.id = new.id
  )
  into would_create_cycle;

  if would_create_cycle then
    raise exception using
      errcode = '23514',
      message = 'A hierarquia administrativa não pode conter ciclos.';
  end if;

  return new;
end;
$$;

revoke all on function private.assert_municipality_department_acyclic() from public;

create trigger municipality_departments_prevent_hierarchy_cycles
  before insert or update of parent_department_id, municipality_id
  on public.municipality_departments
  for each row
  execute function private.assert_municipality_department_acyclic();

-- RLS já está habilitado e a policy SELECT existente continua sendo a única
-- policy de acesso desta tabela. FORCE ROW LEVEL SECURITY fica para uma
-- migration de escrita dedicada, após validar os efeitos nos helpers e triggers.

commit;