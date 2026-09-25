-- ETAPA 20.3.17
-- Teste DEV: municipality_funding_processes
-- Valida RLS, isolamento multi-tenant, permissoes, auditoria e relacao 1:N.
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

-- A partir daqui, todas as operacoes funcionais passam pelos grants e RLS
-- do papel authenticated, simulando usuarios reais pelo JWT.
set local role authenticated;

do $prepare_relations$
declare
  beta_id uuid :=
    current_setting('app.funding_test.beta_id', true)::uuid;
  beta_manager_id uuid :=
    current_setting('app.funding_test.beta_manager_id', true)::uuid;
  opportunity_id uuid :=
    current_setting('app.funding_test.opportunity_id', true)::uuid;
  beta_relation_id uuid;
begin
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
    'TESTE ETAPA 20.3.17 - relacao Beta temporaria para validar processo de captacao.'
  )
  returning id into beta_relation_id;

  if beta_relation_id is null then
    raise exception 'FALHA: grants_manager Beta nao criou a relacao municipal temporaria.';
  end if;

  perform set_config(
    'app.funding_test.beta_relation_id',
    beta_relation_id::text,
    true
  );

  raise notice 'OK: relacao Beta interested criada temporariamente via authenticated/RLS.';
end;
$prepare_relations$;

-- A) municipality_admin Alfa cria dois processos para a mesma
-- municipality_opportunity, comprovando a cardinalidade 1:N.
do $test_alfa_create$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;
  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;
  alfa_membership_id uuid :=
    current_setting('app.funding_test.alfa_membership_id', true)::uuid;
  alfa_relation_id uuid :=
    current_setting('app.funding_test.alfa_relation_id', true)::uuid;
  process_one_id uuid;
  process_two_id uuid;
  process_count integer;
begin
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
    'TESTE ETAPA 20.3.17 - Processo Alfa 1',
    'preparing',
    100000.00,
    'Primeiro processo temporario para validar RLS e cardinalidade 1:N.'
  )
  returning id into process_one_id;

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
    'TESTE ETAPA 20.3.17 - Processo Alfa 2',
    'documentation',
    200000.00,
    'Segundo processo temporario vinculado a mesma oportunidade municipal.'
  )
  returning id into process_two_id;

  if process_one_id is null
     or process_two_id is null
     or process_one_id = process_two_id then
    raise exception 'FALHA: municipality_admin Alfa nao criou dois processos distintos.';
  end if;

  select count(*)
    into process_count
  from public.municipality_funding_processes
  where municipality_id = alfa_id
    and municipality_opportunity_id = alfa_relation_id
    and id in (process_one_id, process_two_id);

  if process_count <> 2 then
    raise exception 'FALHA: cardinalidade 1:N nao foi comprovada; encontrados % processos do teste.', process_count;
  end if;

  perform set_config(
    'app.funding_test.alfa_process_one_id',
    process_one_id::text,
    true
  );

  perform set_config(
    'app.funding_test.alfa_process_two_id',
    process_two_id::text,
    true
  );

  raise notice 'OK: municipality_admin Alfa criou dois processos para a mesma oportunidade municipal (1:N).';
end;
$test_alfa_create$;

-- B) grants_manager Beta cria e atualiza processo proprio,
-- mas nao enxerga nem altera processo da Alfa.
do $test_beta_manager$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;
  beta_id uuid :=
    current_setting('app.funding_test.beta_id', true)::uuid;
  beta_manager_id uuid :=
    current_setting('app.funding_test.beta_manager_id', true)::uuid;
  beta_membership_id uuid :=
    current_setting('app.funding_test.beta_membership_id', true)::uuid;
  beta_relation_id uuid :=
    current_setting('app.funding_test.beta_relation_id', true)::uuid;
  alfa_process_one_id uuid :=
    current_setting('app.funding_test.alfa_process_one_id', true)::uuid;
  beta_process_id uuid;
  visible_count integer;
  affected_rows integer;
begin
  perform set_config(
    'request.jwt.claim.sub',
    beta_manager_id::text,
    true
  );

  select count(*)
    into visible_count
  from public.municipality_funding_processes
  where id = alfa_process_one_id
    and municipality_id = alfa_id;

  if visible_count <> 0 then
    raise exception 'FALHA: grants_manager Beta enxergou processo da Alfa.';
  end if;

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
    'TESTE ETAPA 20.3.17 - Processo Beta',
    'preparing',
    150000.00,
    'Processo temporario criado pelo grants_manager Beta.'
  )
  returning id into beta_process_id;

  if beta_process_id is null then
    raise exception 'FALHA: grants_manager Beta nao criou processo proprio.';
  end if;

  update public.municipality_funding_processes
     set status = 'documentation',
         protocol_number = 'TESTE-20.3.17-BETA',
         notes = 'Processo Beta atualizado pelo grants_manager.'
   where id = beta_process_id
     and municipality_id = beta_id;

  get diagnostics affected_rows = row_count;

  if affected_rows <> 1 then
    raise exception 'FALHA: grants_manager Beta deveria atualizar exatamente um processo proprio; atualizou %.', affected_rows;
  end if;

  update public.municipality_funding_processes
     set notes = 'FALHA - ALTERACAO CRUZADA BETA PARA ALFA'
   where id = alfa_process_one_id
     and municipality_id = alfa_id;

  get diagnostics affected_rows = row_count;

  if affected_rows <> 0 then
    raise exception 'FALHA: grants_manager Beta alterou processo da Alfa.';
  end if;

  perform set_config(
    'app.funding_test.beta_process_id',
    beta_process_id::text,
    true
  );

  raise notice 'OK: grants_manager Beta criou/atualizou processo proprio e permaneceu isolado da Alfa.';
end;
$test_beta_manager$;

-- C) Usuario authenticated sem membership, papel Anchor ou assignment
-- nao le nem escreve processos municipais.
do $test_unauthorized$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;
  unauthorized_id uuid :=
    current_setting('app.funding_test.unauthorized_id', true)::uuid;
  alfa_relation_id uuid :=
    current_setting('app.funding_test.alfa_relation_id', true)::uuid;
  alfa_process_one_id uuid :=
    current_setting('app.funding_test.alfa_process_one_id', true)::uuid;
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
  from public.municipality_funding_processes;

  if visible_count <> 0 then
    raise exception 'FALHA: usuario sem acesso enxergou % processo(s).', visible_count;
  end if;

  begin
    insert into public.municipality_funding_processes (
      municipality_id,
      municipality_opportunity_id,
      object_description,
      status,
      notes
    ) values (
      alfa_id,
      alfa_relation_id,
      'TESTE ETAPA 20.3.17 - INSERCAO NAO AUTORIZADA',
      'preparing',
      'Esta insercao deve ser bloqueada por RLS.'
    );

    raise exception 'FALHA: usuario sem acesso conseguiu criar processo.';
  exception
    when insufficient_privilege then
      raise notice 'OK: usuario sem acesso foi bloqueado no INSERT por RLS.';
  end;

  update public.municipality_funding_processes
     set notes = 'FALHA - UPDATE NAO AUTORIZADO'
   where id = alfa_process_one_id
     and municipality_id = alfa_id;

  get diagnostics affected_rows = row_count;

  if affected_rows <> 0 then
    raise exception 'FALHA: usuario sem acesso atualizou processo da Alfa.';
  end if;

  select count(*)
    into visible_count
  from public.municipality_funding_process_audit;

  if visible_count <> 0 then
    raise exception 'FALHA: usuario sem acesso enxergou % registro(s) de auditoria.', visible_count;
  end if;

  raise notice 'OK: usuario authenticated sem acesso nao le nem escreve processos/auditoria.';
end;
$test_unauthorized$;

-- D) Superadmin administra os dois tenants e a auditoria
-- registra INSERT/UPDATE com o actor_user_id correto.
do $test_superadmin_audit$
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
  alfa_process_one_id uuid :=
    current_setting('app.funding_test.alfa_process_one_id', true)::uuid;
  alfa_process_two_id uuid :=
    current_setting('app.funding_test.alfa_process_two_id', true)::uuid;
  beta_process_id uuid :=
    current_setting('app.funding_test.beta_process_id', true)::uuid;
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
  from public.municipality_funding_processes
  where id in (
    alfa_process_one_id,
    alfa_process_two_id,
    beta_process_id
  );

  if visible_count <> 3 then
    raise exception 'FALHA: superadmin deveria enxergar os 3 processos do teste; enxergou %.', visible_count;
  end if;

  update public.municipality_funding_processes
     set status = 'submitted',
         proposal_number = 'TESTE-20.3.17-SUPERADMIN',
         notes = 'Processo Alfa atualizado pelo superadmin para validar administracao e auditoria.'
   where id = alfa_process_one_id
     and municipality_id = alfa_id;

  get diagnostics affected_rows = row_count;

  if affected_rows <> 1 then
    raise exception 'FALHA: superadmin deveria atualizar exatamente um processo Alfa; atualizou %.', affected_rows;
  end if;

  select count(*)
    into audit_count
  from public.municipality_funding_process_audit
  where funding_process_id = alfa_process_one_id
    and municipality_id = alfa_id
    and action = 'insert'
    and actor_user_id = alfa_admin_id
    and old_data is null
    and new_data is not null;

  if audit_count <> 1 then
    raise exception 'FALHA: auditoria do INSERT Alfa esperava 1 registro do municipality_admin; encontrou %.', audit_count;
  end if;

  select count(*)
    into audit_count
  from public.municipality_funding_process_audit
  where funding_process_id = alfa_process_one_id
    and municipality_id = alfa_id
    and action = 'update'
    and actor_user_id = superadmin_id
    and old_data is not null
    and new_data is not null
    and old_data ->> 'status' = 'preparing'
    and new_data ->> 'status' = 'submitted';

  if audit_count <> 1 then
    raise exception 'FALHA: auditoria do UPDATE do superadmin esperava 1 registro; encontrou %.', audit_count;
  end if;

  select count(*)
    into audit_count
  from public.municipality_funding_process_audit
  where funding_process_id = beta_process_id
    and municipality_id = beta_id
    and action = 'insert'
    and actor_user_id = beta_manager_id
    and old_data is null
    and new_data is not null;

  if audit_count <> 1 then
    raise exception 'FALHA: auditoria do INSERT Beta esperava 1 registro do grants_manager; encontrou %.', audit_count;
  end if;

  select count(*)
    into audit_count
  from public.municipality_funding_process_audit
  where funding_process_id = beta_process_id
    and municipality_id = beta_id
    and action = 'update'
    and actor_user_id = beta_manager_id
    and old_data is not null
    and new_data is not null
    and old_data ->> 'status' = 'preparing'
    and new_data ->> 'status' = 'documentation';

  if audit_count <> 1 then
    raise exception 'FALHA: auditoria do UPDATE Beta esperava 1 registro do grants_manager; encontrou %.', audit_count;
  end if;

  raise notice 'OK: superadmin administrou Alfa/Beta e auditoria preservou atores e payloads.';
end;
$test_superadmin_audit$;

-- E) Os vinculos estruturais permanecem imutaveis e a auditoria
-- nao aceita escrita direta pelo papel authenticated.
do $test_integrity$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;
  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;
  alfa_relation_id uuid :=
    current_setting('app.funding_test.alfa_relation_id', true)::uuid;
  alfa_process_one_id uuid :=
    current_setting('app.funding_test.alfa_process_one_id', true)::uuid;
begin
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  begin
    update public.municipality_funding_processes
       set municipality_id = alfa_id
     where id = alfa_process_one_id;

    raise exception 'FALHA: authenticated conseguiu executar UPDATE de municipality_id.';
  exception
    when insufficient_privilege then
      raise notice 'OK: municipality_id permanece imutavel por privilegio de coluna.';
  end;

  begin
    update public.municipality_funding_processes
       set municipality_opportunity_id = alfa_relation_id
     where id = alfa_process_one_id;

    raise exception 'FALHA: authenticated conseguiu executar UPDATE de municipality_opportunity_id.';
  exception
    when insufficient_privilege then
      raise notice 'OK: municipality_opportunity_id permanece imutavel por privilegio de coluna.';
  end;

  begin
    insert into public.municipality_funding_process_audit (
      funding_process_id,
      municipality_id,
      action,
      actor_user_id,
      old_data,
      new_data
    ) values (
      alfa_process_one_id,
      alfa_id,
      'update',
      alfa_admin_id,
      jsonb_build_object('source', 'teste direto'),
      jsonb_build_object('source', 'teste direto')
    );

    raise exception 'FALHA: authenticated escreveu diretamente na auditoria.';
  exception
    when insufficient_privilege then
      raise notice 'OK: escrita direta na auditoria foi bloqueada.';
  end;

  raise notice 'SUCESSO: integridade estrutural e imutabilidade da auditoria validadas.';
end;
$test_integrity$;

rollback;

select
  'PASSOU' as status,
  'ETAPA 20.3.17: RLS, isolamento multi-tenant, municipality_admin, grants_manager, superadmin, usuario sem acesso, cardinalidade 1:N, auditoria e integridade validados; ROLLBACK preservou o DEV.' as mensagem;