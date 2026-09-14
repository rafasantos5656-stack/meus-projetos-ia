-- DEV ONLY — teste transacional do bloqueio de ciclos hierárquicos.
-- Não executar em produção. O script termina em ROLLBACK e não persiste dados.

begin;

do $$
declare
  target_municipality_id uuid;
  department_a_id uuid;
  department_b_id uuid;
  department_c_id uuid;
  self_reference_blocked boolean := false;
  indirect_cycle_blocked boolean := false;
begin
  select municipality.id
    into target_municipality_id
  from public.municipalities as municipality
  where lower(btrim(municipality.name)) = lower(btrim('Prefeitura Alfa'))
  order by municipality.created_at asc
  limit 1;

  if target_municipality_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: Prefeitura Alfa não foi encontrada no ambiente DEV.';
  end if;

  if exists (
    select 1
    from public.municipality_departments as department
    where department.municipality_id = target_municipality_id
      and lower(btrim(department.name)) in (
        lower('TESTE CICLO A'),
        lower('TESTE CICLO B'),
        lower('TESTE CICLO C')
      )
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: já existe uma unidade TESTE CICLO A, B ou C na Prefeitura Alfa. Não remova dados; investigue antes de repetir.';
  end if;

  insert into public.municipality_departments (
    municipality_id,
    name,
    unit_type,
    status
  ) values (
    target_municipality_id,
    'TESTE CICLO A',
    'unit',
    'active'
  )
  returning id into department_a_id;

  insert into public.municipality_departments (
    municipality_id,
    name,
    unit_type,
    parent_department_id,
    status
  ) values (
    target_municipality_id,
    'TESTE CICLO B',
    'unit',
    department_a_id,
    'active'
  )
  returning id into department_b_id;

  insert into public.municipality_departments (
    municipality_id,
    name,
    unit_type,
    parent_department_id,
    status
  ) values (
    target_municipality_id,
    'TESTE CICLO C',
    'unit',
    department_b_id,
    'active'
  )
  returning id into department_c_id;

  raise notice 'Hierarquia válida criada temporariamente: A -> B -> C.';

  begin
    update public.municipality_departments
       set parent_department_id = department_a_id
     where id = department_a_id
       and municipality_id = target_municipality_id;

    raise warning 'FALHA NO TESTE: a autorreferência A -> A foi aceita.';
  exception
    when check_violation then
      self_reference_blocked := true;
      raise notice 'OK: autorreferência A -> A foi bloqueada: %', sqlerrm;
  end;

  begin
    update public.municipality_departments
       set parent_department_id = department_c_id
     where id = department_a_id
       and municipality_id = target_municipality_id;

    raise warning 'FALHA NO TESTE: o ciclo A -> B -> C -> A foi aceito.';
  exception
    when check_violation then
      indirect_cycle_blocked := true;
      raise notice 'OK: ciclo indireto A -> B -> C -> A foi bloqueado: %', sqlerrm;
  end;

  if self_reference_blocked and indirect_cycle_blocked then
    raise notice 'SUCESSO: a proteção contra autorreferência e ciclos hierárquicos está ativa.';
  else
    raise warning 'FALHA NO TESTE: pelo menos uma proteção de hierarquia não bloqueou a alteração esperada.';
  end if;
end;
$$;

rollback;