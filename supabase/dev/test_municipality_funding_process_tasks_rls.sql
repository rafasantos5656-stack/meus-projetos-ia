-- ETAPA 20.3.18
-- Teste DEV: municipality_funding_process_tasks
-- Valida RLS, isolamento multi-tenant, permissoes, prazos,
-- responsaveis, auditoria e integridade estrutural.
-- Todo o teste roda em transacao e termina com ROLLBACK.

begin;

do $preflight$
declare
  missing_table text;
begin
  select string_agg(required_table.qualified_name, ', ')
    into missing_table
  from (
    values
      ('public.opportunity_sources'),
      ('public.opportunities'),
      ('public.municipalities'),
      ('public.municipality_opportunities'),
      ('public.municipality_funding_processes'),
      ('public.municipality_funding_process_audit'),
      ('public.municipality_funding_process_tasks'),
      ('public.municipality_funding_process_task_audit'),
      ('public.municipality_members'),
      ('public.municipality_member_roles'),
      ('public.app_roles'),
      ('public.anchor_user_roles'),
      ('public.anchor_municipality_assignments'),
      ('auth.users')
  ) as required_table(qualified_name)
  where pg_catalog.to_regclass(required_table.qualified_name) is null;

  if missing_table is not null then
    raise exception using
      errcode = 'P0001',
      message = format(
        'Teste cancelado: tabelas obrigatorias ausentes no DEV: %s.',
        missing_table
      );
  end if;
end;
$preflight$;
do $fixtures$
declare
  fixture_source_id uuid;
  alfa_id uuid;
  beta_id uuid;
  superadmin_id uuid;
  alfa_admin_id uuid;
  alfa_membership_id uuid;
  beta_manager_id uuid;
  beta_membership_id uuid;
  unauthorized_id uuid;
  published_opportunity_id uuid;
  alfa_relation_id uuid;
  matching_count integer;
  membership_count integer;
begin
  select count(*), (array_agg(source.id order by source.id))[1]
    into matching_count, fixture_source_id
  from public.opportunity_sources as source
  where source.code = 'ANCHOR_DEV_TEST'
    and source.active = true;

  if matching_count <> 1 then
    raise exception 'Teste cancelado: ANCHOR_DEV_TEST ativo deve ser inequivoco; encontrados %.', matching_count;
  end if;

  select count(*), (array_agg(municipality.id order by municipality.id))[1]
    into matching_count, alfa_id
  from public.municipalities as municipality
  where municipality.name = 'Prefeitura Alfa'
    and municipality.state = 'SP'
    and municipality.status = 'active';

  if matching_count <> 1 then
    raise exception 'Teste cancelado: Prefeitura Alfa/SP ativa deve ser inequivoca; encontradas %.', matching_count;
  end if;

  select count(*), (array_agg(municipality.id order by municipality.id))[1]
    into matching_count, beta_id
  from public.municipalities as municipality
  where municipality.name = 'Prefeitura Beta'
    and municipality.state = 'SP'
    and municipality.status = 'active';

  if matching_count <> 1 then
    raise exception 'Teste cancelado: Prefeitura Beta/SP ativa deve ser inequivoca; encontradas %.', matching_count;
  end if;

  select count(distinct role_assignment.user_id),
         (array_agg(distinct role_assignment.user_id order by role_assignment.user_id))[1]
    into matching_count, superadmin_id
  from public.anchor_user_roles as role_assignment
  where role_assignment.role_scope = 'anchor'::public.role_scope
    and role_assignment.role_code = 'anchor_superadmin';

  if matching_count <> 1 then
    raise exception 'Teste cancelado: deve existir exatamente um anchor_superadmin no DEV; encontrados %.', matching_count;
  end if;

  select
    count(distinct membership.user_id),
    (array_agg(distinct membership.user_id order by membership.user_id))[1],
    count(distinct membership.id),
    (array_agg(distinct membership.id order by membership.id))[1]
  into matching_count, alfa_admin_id, membership_count, alfa_membership_id
  from public.municipality_members as membership
  join public.municipality_member_roles as role_assignment
    on role_assignment.membership_id = membership.id
  where membership.municipality_id = alfa_id
    and membership.status = 'active'::public.membership_status
    and role_assignment.role_scope = 'municipality'::public.role_scope
    and role_assignment.role_code = 'municipality_admin';

  if matching_count <> 1 or membership_count <> 1 then
    raise exception 'Teste cancelado: municipality_admin Alfa ativo deve ser inequivoco.';
  end if;

  select
    count(distinct membership.user_id),
    (array_agg(distinct membership.user_id order by membership.user_id))[1],
    count(distinct membership.id),
    (array_agg(distinct membership.id order by membership.id))[1]
  into matching_count, beta_manager_id, membership_count, beta_membership_id
  from public.municipality_members as membership
  join public.municipality_member_roles as role_assignment
    on role_assignment.membership_id = membership.id
  where membership.municipality_id = beta_id
    and membership.status = 'active'::public.membership_status
    and role_assignment.role_scope = 'municipality'::public.role_scope
    and role_assignment.role_code = 'grants_manager'
    and not exists (
      select 1
      from public.municipality_member_roles as admin_role
      where admin_role.membership_id = membership.id
        and admin_role.role_scope = 'municipality'::public.role_scope
        and admin_role.role_code = 'municipality_admin'
    );

  if matching_count <> 1 or membership_count <> 1 then
    raise exception 'Teste cancelado: grants_manager Beta ativo sem municipality_admin deve ser inequivoco.';
  end if;

  select count(*), (array_agg(candidate.id order by candidate.id))[1]
    into matching_count, unauthorized_id
  from auth.users as candidate
  where not exists (
    select 1 from public.municipality_members as membership
    where membership.user_id = candidate.id
  )
  and not exists (
    select 1 from public.anchor_user_roles as anchor_role
    where anchor_role.user_id = candidate.id
  )
  and not exists (
    select 1 from public.anchor_municipality_assignments as assignment
    where assignment.anchor_user_id = candidate.id
  );

  if matching_count <> 1 then
    raise exception 'Teste cancelado: usuario autenticado totalmente sem acesso deve ser inequivoco; encontrados %.', matching_count;
  end if;

  if unauthorized_id in (superadmin_id, alfa_admin_id, beta_manager_id) then
    raise exception 'Teste cancelado: ator sem acesso colidiu com ator autorizado.';
  end if;

  select count(*), (array_agg(opportunity.id order by opportunity.id))[1]
    into matching_count, published_opportunity_id
  from public.opportunities as opportunity
  where opportunity.source_id = fixture_source_id
    and opportunity.is_published = true
    and exists (
      select 1
      from public.municipality_opportunities as relation
      where relation.municipality_id = alfa_id
        and relation.opportunity_id = opportunity.id
        and relation.status = 'interested'
    )
    and not exists (
      select 1
      from public.municipality_opportunities as relation
      where relation.municipality_id = beta_id
        and relation.opportunity_id = opportunity.id
    );

  if matching_count = 0 then
    raise exception 'Teste cancelado: nenhuma oportunidade publicada/interested da Alfa esta livre para criar relacao Beta temporaria.';
  end if;

  select relation.id
    into alfa_relation_id
  from public.municipality_opportunities as relation
  where relation.municipality_id = alfa_id
    and relation.opportunity_id = published_opportunity_id
    and relation.status = 'interested';

  perform set_config('app.funding_test.alfa_id', alfa_id::text, true);
  perform set_config('app.funding_test.beta_id', beta_id::text, true);
  perform set_config('app.funding_test.superadmin_id', superadmin_id::text, true);
  perform set_config('app.funding_test.alfa_admin_id', alfa_admin_id::text, true);
  perform set_config('app.funding_test.alfa_membership_id', alfa_membership_id::text, true);
  perform set_config('app.funding_test.beta_manager_id', beta_manager_id::text, true);
  perform set_config('app.funding_test.beta_membership_id', beta_membership_id::text, true);
  perform set_config('app.funding_test.unauthorized_id', unauthorized_id::text, true);
  perform set_config('app.funding_test.opportunity_id', published_opportunity_id::text, true);
  perform set_config('app.funding_test.alfa_relation_id', alfa_relation_id::text, true);
end;
$fixtures$;

-- A partir daqui, as operacoes funcionais passam pelos grants e RLS
-- do papel authenticated, simulando usuarios reais pelo JWT.
set local role authenticated;

-- Prepara uma relacao Beta temporaria e um processo de captacao
-- para Alfa e Beta. Tudo sera removido pelo ROLLBACK final.
do $prepare_processes$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;
  beta_id uuid :=
    current_setting('app.funding_test.beta_id', true)::uuid;
  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;
  alfa_membership_id uuid :=
    current_setting('app.funding_test.alfa_membership_id', true)::uuid;
  beta_manager_id uuid :=
    current_setting('app.funding_test.beta_manager_id', true)::uuid;
  beta_membership_id uuid :=
    current_setting('app.funding_test.beta_membership_id', true)::uuid;
  opportunity_id uuid :=
    current_setting('app.funding_test.opportunity_id', true)::uuid;
  alfa_relation_id uuid :=
    current_setting('app.funding_test.alfa_relation_id', true)::uuid;
  beta_relation_id uuid;
  alfa_process_id uuid;
  beta_process_id uuid;
begin
  -- Beta cria sua relacao municipal temporaria.
  perform set_config(
    'request.jwt.claim.sub',
    beta_manager_id::text,
    true
  );

  insert into public.municipality_opportunities (
    municipality_id,
    opportunity_id,
    status,
    notes
  ) values (
    beta_id,
    opportunity_id,
    'interested',
    'TESTE ETAPA 20.3.18 - relacao Beta temporaria.'
  )
  returning id into beta_relation_id;

  if beta_relation_id is null then
    raise exception
      'FALHA: grants_manager Beta nao criou relacao temporaria.';
  end if;

  -- Beta cria seu processo temporario.
  insert into public.municipality_funding_processes (
    municipality_id,
    municipality_opportunity_id,
    responsible_membership_id,
    object_description,
    status,
    requested_amount,
    notes
  ) values (
    beta_id,
    beta_relation_id,
    beta_membership_id,
    'TESTE ETAPA 20.3.18 - Processo Beta',
    'preparing',
    150000.00,
    'Processo temporario Beta para testar tarefas.'
  )
  returning id into beta_process_id;

  if beta_process_id is null then
    raise exception
      'FALHA: grants_manager Beta nao criou processo temporario.';
  end if;

  -- Alfa cria seu processo temporario.
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  insert into public.municipality_funding_processes (
    municipality_id,
    municipality_opportunity_id,
    responsible_membership_id,
    object_description,
    status,
    requested_amount,
    notes
  ) values (
    alfa_id,
    alfa_relation_id,
    alfa_membership_id,
    'TESTE ETAPA 20.3.18 - Processo Alfa',
    'preparing',
    100000.00,
    'Processo temporario Alfa para testar tarefas.'
  )
  returning id into alfa_process_id;

  if alfa_process_id is null then
    raise exception
      'FALHA: municipality_admin Alfa nao criou processo temporario.';
  end if;

  perform set_config(
    'app.task_test.alfa_process_id',
    alfa_process_id::text,
    true
  );

  perform set_config(
    'app.task_test.beta_process_id',
    beta_process_id::text,
    true
  );

  perform set_config(
    'app.task_test.beta_relation_id',
    beta_relation_id::text,
    true
  );

  raise notice
    'OK: processos temporarios Alfa/Beta preparados para o teste de tarefas.';
end;
$prepare_processes$;

-- A) municipality_admin Alfa cria duas tarefas para o mesmo processo,
-- comprovando a cardinalidade 1:N entre processo e tarefas.
do $test_alfa_tasks$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;
  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;
  alfa_membership_id uuid :=
    current_setting('app.funding_test.alfa_membership_id', true)::uuid;
  alfa_process_id uuid :=
    current_setting('app.task_test.alfa_process_id', true)::uuid;
  task_one_id uuid;
  task_two_id uuid;
  task_count integer;
begin
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  insert into public.municipality_funding_process_tasks (
    municipality_id,
    funding_process_id,
    responsible_membership_id,
    title,
    description,
    status,
    priority,
    due_date,
    notes
  ) values (
    alfa_id,
    alfa_process_id,
    alfa_membership_id,
    'TESTE 20.3.18 - Reunir documentos',
    'Separar documentos obrigatorios para o processo Alfa.',
    'pending',
    'high',
    current_date + 10,
    'Primeira tarefa temporaria Alfa.'
  )
  returning id into task_one_id;

  insert into public.municipality_funding_process_tasks (
    municipality_id,
    funding_process_id,
    responsible_membership_id,
    title,
    description,
    status,
    priority,
    due_date,
    notes
  ) values (
    alfa_id,
    alfa_process_id,
    alfa_membership_id,
    'TESTE 20.3.18 - Revisar proposta',
    'Revisar dados e valores antes do protocolo.',
    'in_progress',
    'urgent',
    current_date + 5,
    'Segunda tarefa temporaria Alfa.'
  )
  returning id into task_two_id;

  if task_one_id is null
     or task_two_id is null
     or task_one_id = task_two_id then
    raise exception
      'FALHA: municipality_admin Alfa nao criou duas tarefas distintas.';
  end if;

  select count(*)
    into task_count
  from public.municipality_funding_process_tasks
  where municipality_id = alfa_id
    and funding_process_id = alfa_process_id
    and id in (task_one_id, task_two_id);

  if task_count <> 2 then
    raise exception
      'FALHA: processo Alfa deveria possuir 2 tarefas do teste; encontrou %.',
      task_count;
  end if;

  perform set_config(
    'app.task_test.alfa_task_one_id',
    task_one_id::text,
    true
  );

  perform set_config(
    'app.task_test.alfa_task_two_id',
    task_two_id::text,
    true
  );

  raise notice
    'OK: municipality_admin Alfa criou duas tarefas no mesmo processo (1:N).';
end;
$test_alfa_tasks$;

-- B) grants_manager Beta cria e conclui tarefa propria,
-- mas nao enxerga nem altera tarefas da Alfa.
do $test_beta_tasks$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;
  beta_id uuid :=
    current_setting('app.funding_test.beta_id', true)::uuid;
  beta_manager_id uuid :=
    current_setting('app.funding_test.beta_manager_id', true)::uuid;
  beta_membership_id uuid :=
    current_setting('app.funding_test.beta_membership_id', true)::uuid;
  beta_process_id uuid :=
    current_setting('app.task_test.beta_process_id', true)::uuid;
  alfa_task_one_id uuid :=
    current_setting('app.task_test.alfa_task_one_id', true)::uuid;
  beta_task_id uuid;
  visible_count integer;
  affected_rows integer;
  final_status text;
  final_completed_at timestamptz;
begin
  perform set_config(
    'request.jwt.claim.sub',
    beta_manager_id::text,
    true
  );

  -- Beta nao pode enxergar tarefa da Alfa.
  select count(*)
    into visible_count
  from public.municipality_funding_process_tasks
  where id = alfa_task_one_id
    and municipality_id = alfa_id;

  if visible_count <> 0 then
    raise exception
      'FALHA: grants_manager Beta enxergou tarefa da Alfa.';
  end if;

  -- Beta cria sua propria tarefa.
  insert into public.municipality_funding_process_tasks (
    municipality_id,
    funding_process_id,
    responsible_membership_id,
    title,
    description,
    status,
    priority,
    due_date,
    notes
  ) values (
    beta_id,
    beta_process_id,
    beta_membership_id,
    'TESTE 20.3.18 - Protocolar documentos Beta',
    'Protocolar documentacao do processo temporario Beta.',
    'pending',
    'normal',
    current_date + 7,
    'Tarefa temporaria criada pelo grants_manager Beta.'
  )
  returning id into beta_task_id;

  if beta_task_id is null then
    raise exception
      'FALHA: grants_manager Beta nao criou tarefa propria.';
  end if;

  -- Beta inicia a tarefa.
  update public.municipality_funding_process_tasks
     set status = 'in_progress',
         priority = 'high',
         notes = 'Tarefa Beta em andamento.'
   where id = beta_task_id
     and municipality_id = beta_id;

  get diagnostics affected_rows = row_count;

  if affected_rows <> 1 then
    raise exception
      'FALHA: Beta deveria atualizar exatamente uma tarefa propria; atualizou %.',
      affected_rows;
  end if;

  -- Beta conclui a tarefa respeitando a regra completed/completed_at.
  update public.municipality_funding_process_tasks
     set status = 'completed',
         completed_at = now(),
         notes = 'Tarefa Beta concluida.'
   where id = beta_task_id
     and municipality_id = beta_id;

  get diagnostics affected_rows = row_count;

  if affected_rows <> 1 then
    raise exception
      'FALHA: Beta deveria concluir exatamente uma tarefa; concluiu %.',
      affected_rows;
  end if;

  select status, completed_at
    into final_status, final_completed_at
  from public.municipality_funding_process_tasks
  where id = beta_task_id
    and municipality_id = beta_id;

  if final_status <> 'completed'
     or final_completed_at is null then
    raise exception
      'FALHA: tarefa Beta nao preservou status completed/completed_at.';
  end if;

  -- Tentativa de alteracao cruzada Beta -> Alfa deve afetar zero linhas.
  update public.municipality_funding_process_tasks
     set notes = 'FALHA - ALTERACAO CRUZADA BETA PARA ALFA'
   where id = alfa_task_one_id
     and municipality_id = alfa_id;

  get diagnostics affected_rows = row_count;

  if affected_rows <> 0 then
    raise exception
      'FALHA: grants_manager Beta alterou tarefa da Alfa.';
  end if;

  perform set_config(
    'app.task_test.beta_task_id',
    beta_task_id::text,
    true
  );

  raise notice
    'OK: grants_manager Beta criou/concluiu tarefa propria e permaneceu isolado da Alfa.';
end;
$test_beta_tasks$;

-- C) Usuario authenticated sem membership, papel Anchor ou assignment
-- nao le nem escreve tarefas/auditoria.
do $test_unauthorized_tasks$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;
  unauthorized_id uuid :=
    current_setting('app.funding_test.unauthorized_id', true)::uuid;
  alfa_process_id uuid :=
    current_setting('app.task_test.alfa_process_id', true)::uuid;
  alfa_task_one_id uuid :=
    current_setting('app.task_test.alfa_task_one_id', true)::uuid;
  visible_count integer;
  affected_rows integer;
begin
  perform set_config(
    'request.jwt.claim.sub',
    unauthorized_id::text,
    true
  );

  select count(*)
    into visible_count
  from public.municipality_funding_process_tasks;

  if visible_count <> 0 then
    raise exception
      'FALHA: usuario sem acesso enxergou % tarefa(s).',
      visible_count;
  end if;

  begin
    insert into public.municipality_funding_process_tasks (
      municipality_id,
      funding_process_id,
      title,
      status,
      priority,
      notes
    ) values (
      alfa_id,
      alfa_process_id,
      'TESTE 20.3.18 - INSERCAO NAO AUTORIZADA',
      'pending',
      'normal',
      'Esta insercao deve ser bloqueada por RLS.'
    );

    raise exception
      'FALHA: usuario sem acesso conseguiu criar tarefa.';
  exception
    when insufficient_privilege then
      raise notice
        'OK: usuario sem acesso foi bloqueado no INSERT de tarefa.';
  end;

  update public.municipality_funding_process_tasks
     set notes = 'FALHA - UPDATE NAO AUTORIZADO'
   where id = alfa_task_one_id
     and municipality_id = alfa_id;

  get diagnostics affected_rows = row_count;

  if affected_rows <> 0 then
    raise exception
      'FALHA: usuario sem acesso atualizou tarefa da Alfa.';
  end if;

  select count(*)
    into visible_count
  from public.municipality_funding_process_task_audit;

  if visible_count <> 0 then
    raise exception
      'FALHA: usuario sem acesso enxergou % registro(s) de auditoria de tarefas.',
      visible_count;
  end if;

  raise notice
    'OK: usuario authenticated sem acesso nao le nem escreve tarefas/auditoria.';
end;
$test_unauthorized_tasks$;

-- D) Responsavel de outro municipio nao pode ser atribuido a tarefa Alfa.
do $test_cross_tenant_responsible$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;
  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;
  beta_membership_id uuid :=
    current_setting('app.funding_test.beta_membership_id', true)::uuid;
  alfa_process_id uuid :=
    current_setting('app.task_test.alfa_process_id', true)::uuid;
begin
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  begin
    insert into public.municipality_funding_process_tasks (
      municipality_id,
      funding_process_id,
      responsible_membership_id,
      title,
      status,
      priority,
      notes
    ) values (
      alfa_id,
      alfa_process_id,
      beta_membership_id,
      'TESTE 20.3.18 - RESPONSAVEL CRUZADO',
      'pending',
      'normal',
      'Esta tarefa deve ser rejeitada.'
    );

    raise exception
      'FALHA: tarefa Alfa aceitou membership da Beta.';
  exception
    when foreign_key_violation then
      raise notice
        'OK: FK composta bloqueou responsavel de outro municipio.';
    when raise_exception then
      if sqlerrm like 'O responsavel deve possuir membership ativa%' then
        raise notice
          'OK: validacao bloqueou responsavel de outro municipio.';
      else
        raise;
      end if;
  end;
end;
$test_cross_tenant_responsible$;

-- E) Superadmin administra os dois tenants e a auditoria
-- preserva corretamente os atores e os payloads.
do $test_superadmin_task_audit$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;
  beta_id uuid :=
    current_setting('app.funding_test.beta_id', true)::uuid;
  superadmin_id uuid :=
    current_setting('app.funding_test.superadmin_id', true)::uuid;
  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;
  beta_manager_id uuid :=
    current_setting('app.funding_test.beta_manager_id', true)::uuid;
  alfa_task_one_id uuid :=
    current_setting('app.task_test.alfa_task_one_id', true)::uuid;
  alfa_task_two_id uuid :=
    current_setting('app.task_test.alfa_task_two_id', true)::uuid;
  beta_task_id uuid :=
    current_setting('app.task_test.beta_task_id', true)::uuid;
  visible_count integer;
  audit_count integer;
  affected_rows integer;
begin
  perform set_config(
    'request.jwt.claim.sub',
    superadmin_id::text,
    true
  );

  select count(*)
    into visible_count
  from public.municipality_funding_process_tasks
  where id in (
    alfa_task_one_id,
    alfa_task_two_id,
    beta_task_id
  );

  if visible_count <> 3 then
    raise exception
      'FALHA: superadmin deveria enxergar as 3 tarefas do teste; enxergou %.',
      visible_count;
  end if;

  -- Superadmin atualiza tarefa Alfa.
  update public.municipality_funding_process_tasks
     set status = 'in_progress',
         priority = 'urgent',
         notes = 'Tarefa Alfa atualizada pelo superadmin.'
   where id = alfa_task_one_id
     and municipality_id = alfa_id;

  get diagnostics affected_rows = row_count;

  if affected_rows <> 1 then
    raise exception
      'FALHA: superadmin deveria atualizar exatamente uma tarefa Alfa; atualizou %.',
      affected_rows;
  end if;

  -- INSERT da primeira tarefa Alfa deve ter sido atribuido ao Alfa Admin.
  select count(*)
    into audit_count
  from public.municipality_funding_process_task_audit
  where funding_process_task_id = alfa_task_one_id
    and municipality_id = alfa_id
    and action = 'insert'
    and actor_user_id = alfa_admin_id
    and old_data is null
    and new_data is not null;

  if audit_count <> 1 then
    raise exception
      'FALHA: auditoria INSERT Alfa esperava 1 registro do municipality_admin; encontrou %.',
      audit_count;
  end if;

  -- UPDATE realizado pelo superadmin.
  select count(*)
    into audit_count
  from public.municipality_funding_process_task_audit
  where funding_process_task_id = alfa_task_one_id
    and municipality_id = alfa_id
    and action = 'update'
    and actor_user_id = superadmin_id
    and old_data is not null
    and new_data is not null
    and old_data ->> 'status' = 'pending'
    and new_data ->> 'status' = 'in_progress'
    and new_data ->> 'priority' = 'urgent';

  if audit_count <> 1 then
    raise exception
      'FALHA: auditoria UPDATE superadmin esperava 1 registro; encontrou %.',
      audit_count;
  end if;

  -- INSERT Beta deve preservar o grants_manager como ator.
  select count(*)
    into audit_count
  from public.municipality_funding_process_task_audit
  where funding_process_task_id = beta_task_id
    and municipality_id = beta_id
    and action = 'insert'
    and actor_user_id = beta_manager_id
    and old_data is null
    and new_data is not null;

  if audit_count <> 1 then
    raise exception
      'FALHA: auditoria INSERT Beta esperava 1 registro do grants_manager; encontrou %.',
      audit_count;
  end if;

  -- Beta realizou dois UPDATEs: pending -> in_progress -> completed.
  select count(*)
    into audit_count
  from public.municipality_funding_process_task_audit
  where funding_process_task_id = beta_task_id
    and municipality_id = beta_id
    and action = 'update'
    and actor_user_id = beta_manager_id
    and old_data is not null
    and new_data is not null;

  if audit_count <> 2 then
    raise exception
      'FALHA: auditoria Beta esperava 2 UPDATEs; encontrou %.',
      audit_count;
  end if;

  select count(*)
    into audit_count
  from public.municipality_funding_process_task_audit
  where funding_process_task_id = beta_task_id
    and municipality_id = beta_id
    and action = 'update'
    and actor_user_id = beta_manager_id
    and old_data ->> 'status' = 'in_progress'
    and new_data ->> 'status' = 'completed'
    and new_data ->> 'completed_at' is not null;

  if audit_count <> 1 then
    raise exception
      'FALHA: auditoria da conclusao Beta esperava 1 transicao para completed; encontrou %.',
      audit_count;
  end if;

  raise notice
    'OK: superadmin administrou Alfa/Beta e auditoria das tarefas preservou atores e payloads.';
end;
$test_superadmin_task_audit$;

-- F) Integridade estrutural:
-- municipio/processo permanecem imutaveis, a regra completed/completed_at
-- e respeitada e a auditoria nao aceita escrita direta.
do $test_task_integrity$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;
  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;
  alfa_process_id uuid :=
    current_setting('app.task_test.alfa_process_id', true)::uuid;
  beta_process_id uuid :=
    current_setting('app.task_test.beta_process_id', true)::uuid;
  alfa_task_one_id uuid :=
    current_setting('app.task_test.alfa_task_one_id', true)::uuid;
begin
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  -- municipality_id nao pode ser atualizado pelo papel authenticated.
  begin
    update public.municipality_funding_process_tasks
       set municipality_id = alfa_id
     where id = alfa_task_one_id;

    raise exception
      'FALHA: authenticated conseguiu executar UPDATE de municipality_id.';
  exception
    when insufficient_privilege then
      raise notice
        'OK: municipality_id da tarefa permanece imutavel por privilegio de coluna.';
  end;

  -- funding_process_id tambem e estrutural e imutavel.
  begin
    update public.municipality_funding_process_tasks
       set funding_process_id = alfa_process_id
     where id = alfa_task_one_id;

    raise exception
      'FALHA: authenticated conseguiu executar UPDATE de funding_process_id.';
  exception
    when insufficient_privilege then
      raise notice
        'OK: funding_process_id da tarefa permanece imutavel por privilegio de coluna.';
  end;

  -- Mesmo que tentasse apontar para processo de outro tenant,
  -- a coluna estrutural nao possui privilegio de UPDATE.
  begin
    update public.municipality_funding_process_tasks
       set funding_process_id = beta_process_id
     where id = alfa_task_one_id;

    raise exception
      'FALHA: authenticated conseguiu trocar processo Alfa por processo Beta.';
  exception
    when insufficient_privilege then
      raise notice
        'OK: troca cruzada de funding_process_id foi bloqueada.';
  end;

  -- Nao pode marcar completed sem completed_at.
  begin
    update public.municipality_funding_process_tasks
       set status = 'completed',
           completed_at = null
     where id = alfa_task_one_id;

    raise exception
      'FALHA: tarefa foi marcada completed sem completed_at.';
  exception
    when check_violation then
      raise notice
        'OK: regra completed/completed_at bloqueou estado inconsistente.';
  end;

  -- Escrita direta na auditoria deve ser proibida.
  begin
    insert into public.municipality_funding_process_task_audit (
      funding_process_task_id,
      municipality_id,
      action,
      actor_user_id,
      old_data,
      new_data
    ) values (
      alfa_task_one_id,
      alfa_id,
      'update',
      alfa_admin_id,
      jsonb_build_object('source', 'teste direto'),
      jsonb_build_object('source', 'teste direto')
    );

    raise exception
      'FALHA: authenticated escreveu diretamente na auditoria de tarefas.';
  exception
    when insufficient_privilege then
      raise notice
        'OK: escrita direta na auditoria de tarefas foi bloqueada.';
  end;

  raise notice
    'SUCESSO: integridade estrutural e imutabilidade da auditoria de tarefas validadas.';
end;
$test_task_integrity$;

rollback;

select
  'PASSOU' as status,
  'ETAPA 20.3.18: tarefas e prazos, RLS, isolamento multi-tenant, municipality_admin, grants_manager, superadmin, usuario sem acesso, cardinalidade 1:N, responsavel por tenant, conclusao, auditoria e integridade validados; ROLLBACK preservou o DEV.' as mensagem;
