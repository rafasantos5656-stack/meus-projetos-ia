-- ETAPA 20.3.19
-- Teste DEV: Documentos e Checklist do Processo de Captacao
-- Valida RLS, isolamento multi-tenant, permissoes, departamentos,
-- responsaveis, prazos, validade, auditoria e integridade estrutural.
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
      ('public.municipality_departments'),
      ('public.municipality_members'),
      ('public.municipality_member_departments'),
      ('public.municipality_member_roles'),
      ('public.app_roles'),
      ('public.anchor_user_roles'),
      ('public.anchor_municipality_assignments'),
      ('public.municipality_opportunities'),
      ('public.municipality_funding_processes'),
      ('public.municipality_funding_process_documents'),
      ('public.municipality_funding_process_document_audit'),
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

  raise notice
    'OK: preflight da ETAPA 20.3.19 confirmou todas as tabelas obrigatorias.';
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
    'TESTE ETAPA 20.3.19 - relacao Beta temporaria.'
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
    'TESTE ETAPA 20.3.19 - Processo Beta',
    'preparing',
    150000.00,
    'Processo temporario Beta para testar documentos.'
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
    'TESTE ETAPA 20.3.19 - Processo Alfa',
    'preparing',
    100000.00,
    'Processo temporario Alfa para testar documentos.'
  )
  returning id into alfa_process_id;

  if alfa_process_id is null then
    raise exception
      'FALHA: municipality_admin Alfa nao criou processo temporario.';
  end if;

  perform set_config(
    'app.document_test.alfa_process_id',
    alfa_process_id::text,
    true
  );

  perform set_config(
    'app.document_test.beta_process_id',
    beta_process_id::text,
    true
  );

  perform set_config(
    'app.document_test.beta_relation_id',
    beta_relation_id::text,
    true
  );

  raise notice
    'OK: processos temporarios Alfa/Beta preparados para o teste de documentos.';
end;
$prepare_processes$;

do $prepare_departments$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;

  beta_id uuid :=
    current_setting('app.funding_test.beta_id', true)::uuid;

  alfa_department_id uuid;
  beta_department_id uuid;

  alfa_count integer;
  beta_count integer;
begin
  perform set_config(
    'request.jwt.claim.sub',
    current_setting('app.funding_test.superadmin_id', true),
    true
  );

  select count(*), (array_agg(d.id order by d.id))[1]
    into alfa_count, alfa_department_id
  from public.municipality_departments as d
  where d.municipality_id = alfa_id
    and lower(btrim(d.name)) = lower('Convênios')
    and d.status = 'active';

  if alfa_count <> 1 then
    raise exception
      'Teste cancelado: esperado exatamente 1 departamento ativo Convênios na Alfa; encontrados %.',
      alfa_count;
  end if;

  select count(*), (array_agg(d.id order by d.id))[1]
    into beta_count, beta_department_id
  from public.municipality_departments as d
  where d.municipality_id = beta_id
    and lower(btrim(d.name)) = lower('Convênios')
    and d.status = 'active';

  if beta_count <> 1 then
    raise exception
      'Teste cancelado: esperado exatamente 1 departamento ativo Convênios na Beta; encontrados %.',
      beta_count;
  end if;

  perform set_config(
    'app.document_test.alfa_department_id',
    alfa_department_id::text,
    true
  );

  perform set_config(
    'app.document_test.beta_department_id',
    beta_department_id::text,
    true
  );

  raise notice
    'OK: departamentos Convênios Alfa/Beta preparados para o teste documental.';
end;
$prepare_departments$;

-- A) municipality_admin Alfa cria documento obrigatorio valido.
do $test_alfa_create_document$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;

  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;

  alfa_membership_id uuid :=
    current_setting('app.funding_test.alfa_membership_id', true)::uuid;

  alfa_process_id uuid :=
    current_setting('app.document_test.alfa_process_id', true)::uuid;

  alfa_department_id uuid :=
    current_setting('app.document_test.alfa_department_id', true)::uuid;

  document_id uuid;
begin
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  insert into public.municipality_funding_process_documents (
    municipality_id,
    funding_process_id,
    responsible_department_id,
    responsible_membership_id,
    document_name,
    description,
    document_type,
    is_required,
    status,
    due_date,
    issued_at,
    expires_at,
    notes
  ) values (
    alfa_id,
    alfa_process_id,
    alfa_department_id,
    alfa_membership_id,
    'Certidão de Regularidade Fiscal - TESTE 20.3.19',
    'Documento obrigatorio temporario para validar o checklist documental.',
    'certificate',
    true,
    'pending',
    current_date + 10,
    current_date,
    current_date + 30,
    'Documento criado exclusivamente pelo teste DEV da ETAPA 20.3.19.'
  )
  returning id into document_id;

  if document_id is null then
    raise exception
      'FALHA: municipality_admin Alfa nao criou documento obrigatorio.';
  end if;

  if not exists (
    select 1
    from public.municipality_funding_process_documents as d
    where d.id = document_id
      and d.municipality_id = alfa_id
      and d.funding_process_id = alfa_process_id
      and d.responsible_department_id = alfa_department_id
      and d.responsible_membership_id = alfa_membership_id
      and d.document_type = 'certificate'
      and d.is_required is true
      and d.status = 'pending'
      and d.due_date = current_date + 10
      and d.issued_at = current_date
      and d.expires_at = current_date + 30
  ) then
    raise exception
      'FALHA: documento Alfa foi criado, mas seus dados nao correspondem ao esperado.';
  end if;

  perform set_config(
    'app.document_test.alfa_document_id',
    document_id::text,
    true
  );

  raise notice
    'OK: municipality_admin Alfa criou documento obrigatorio com departamento, responsavel, prazo e validade.';
end;
$test_alfa_create_document$;

-- B) grants_manager Beta cria documento opcional valido no proprio tenant.
do $test_beta_create_document$
declare
  beta_id uuid :=
    current_setting('app.funding_test.beta_id', true)::uuid;

  beta_manager_id uuid :=
    current_setting('app.funding_test.beta_manager_id', true)::uuid;

  beta_membership_id uuid :=
    current_setting('app.funding_test.beta_membership_id', true)::uuid;

  beta_process_id uuid :=
    current_setting('app.document_test.beta_process_id', true)::uuid;

  beta_department_id uuid :=
    current_setting('app.document_test.beta_department_id', true)::uuid;

  document_id uuid;
begin
  perform set_config(
    'request.jwt.claim.sub',
    beta_manager_id::text,
    true
  );

  insert into public.municipality_funding_process_documents (
    municipality_id,
    funding_process_id,
    responsible_department_id,
    responsible_membership_id,
    document_name,
    description,
    document_type,
    is_required,
    status,
    due_date,
    notes
  ) values (
    beta_id,
    beta_process_id,
    beta_department_id,
    beta_membership_id,
    'Declaração Complementar - TESTE 20.3.19',
    'Documento opcional temporario do processo Beta.',
    'declaration',
    false,
    'requested',
    current_date + 15,
    'Documento Beta criado exclusivamente pelo teste DEV da ETAPA 20.3.19.'
  )
  returning id into document_id;

  if document_id is null then
    raise exception
      'FALHA: grants_manager Beta nao criou documento no proprio tenant.';
  end if;

  if not exists (
    select 1
    from public.municipality_funding_process_documents as d
    where d.id = document_id
      and d.municipality_id = beta_id
      and d.funding_process_id = beta_process_id
      and d.responsible_department_id = beta_department_id
      and d.responsible_membership_id = beta_membership_id
      and d.document_type = 'declaration'
      and d.is_required is false
      and d.status = 'requested'
      and d.due_date = current_date + 15
      and d.issued_at is null
      and d.expires_at is null
  ) then
    raise exception
      'FALHA: documento Beta foi criado, mas seus dados nao correspondem ao esperado.';
  end if;

  perform set_config(
    'app.document_test.beta_document_id',
    document_id::text,
    true
  );

  raise notice
    'OK: grants_manager Beta criou documento opcional no proprio tenant.';
end;
$test_beta_create_document$;

-- C) Alfa nao pode vincular documento a processo pertencente a Beta.
do $test_cross_tenant_process_blocked$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;

  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;

  alfa_membership_id uuid :=
    current_setting('app.funding_test.alfa_membership_id', true)::uuid;

  alfa_department_id uuid :=
    current_setting('app.document_test.alfa_department_id', true)::uuid;

  beta_process_id uuid :=
    current_setting('app.document_test.beta_process_id', true)::uuid;

  blocked boolean := false;
begin
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  begin
    insert into public.municipality_funding_process_documents (
      municipality_id,
      funding_process_id,
      responsible_department_id,
      responsible_membership_id,
      document_name,
      document_type,
      is_required,
      status
    ) values (
      alfa_id,
      beta_process_id,
      alfa_department_id,
      alfa_membership_id,
      'TESTE INVALIDO - processo Beta em documento Alfa',
      'other',
      true,
      'pending'
    );

  exception
    when foreign_key_violation then
      blocked := true;
  end;

  if not blocked then
    raise exception
      'FALHA CRITICA: documento Alfa conseguiu referenciar processo pertencente a Beta.';
  end if;

  if exists (
    select 1
    from public.municipality_funding_process_documents
    where municipality_id = alfa_id
      and document_name = 'TESTE INVALIDO - processo Beta em documento Alfa'
  ) then
    raise exception
      'FALHA CRITICA: tentativa cross-tenant deixou documento persistido.';
  end if;

  raise notice
    'OK: FK composta bloqueou processo Beta em documento Alfa.';
end;
$test_cross_tenant_process_blocked$;

-- D) Alfa nao pode vincular departamento pertencente a Beta.
do $test_cross_tenant_department_blocked$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;

  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;

  alfa_membership_id uuid :=
    current_setting('app.funding_test.alfa_membership_id', true)::uuid;

  alfa_process_id uuid :=
    current_setting('app.document_test.alfa_process_id', true)::uuid;

  beta_department_id uuid :=
    current_setting('app.document_test.beta_department_id', true)::uuid;

  blocked boolean := false;
begin
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  begin
    insert into public.municipality_funding_process_documents (
      municipality_id,
      funding_process_id,
      responsible_department_id,
      responsible_membership_id,
      document_name,
      document_type,
      is_required,
      status
    ) values (
      alfa_id,
      alfa_process_id,
      beta_department_id,
      alfa_membership_id,
      'TESTE INVALIDO - departamento Beta em documento Alfa',
      'other',
      true,
      'pending'
    );

  exception
    when foreign_key_violation then
      blocked := true;
    when check_violation then
      blocked := true;
    when raise_exception then
      if SQLERRM = 'O departamento responsavel deve estar ativo e pertencer ao mesmo municipio.' then
        blocked := true;
      else
        raise;
      end if;
  end;

  if not blocked then
    raise exception
      'FALHA CRITICA: documento Alfa conseguiu referenciar departamento pertencente a Beta.';
  end if;

  if exists (
    select 1
    from public.municipality_funding_process_documents
    where municipality_id = alfa_id
      and document_name =
        'TESTE INVALIDO - departamento Beta em documento Alfa'
  ) then
    raise exception
      'FALHA CRITICA: tentativa com departamento cross-tenant deixou documento persistido.';
  end if;

  raise notice
    'OK: departamento Beta foi bloqueado em documento Alfa.';
end;
$test_cross_tenant_department_blocked$;

-- E) Alfa nao pode vincular responsavel pertencente a Beta.
do $test_cross_tenant_responsible_blocked$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;

  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;

  alfa_process_id uuid :=
    current_setting('app.document_test.alfa_process_id', true)::uuid;

  alfa_department_id uuid :=
    current_setting('app.document_test.alfa_department_id', true)::uuid;

  beta_membership_id uuid :=
    current_setting('app.funding_test.beta_membership_id', true)::uuid;

  blocked boolean := false;
begin
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  begin
    insert into public.municipality_funding_process_documents (
      municipality_id,
      funding_process_id,
      responsible_department_id,
      responsible_membership_id,
      document_name,
      document_type,
      is_required,
      status
    ) values (
      alfa_id,
      alfa_process_id,
      alfa_department_id,
      beta_membership_id,
      'TESTE INVALIDO - responsavel Beta em documento Alfa',
      'other',
      true,
      'pending'
    );

  exception
    when foreign_key_violation then
      blocked := true;
    when check_violation then
      blocked := true;
    when raise_exception then
      if SQLERRM ILIKE '%responsavel%' and SQLERRM ILIKE '%municipio%' then
        blocked := true;
      else
        raise;
      end if;
  end;

  if not blocked then
    raise exception
      'FALHA CRITICA: documento Alfa conseguiu referenciar responsavel pertencente a Beta.';
  end if;

  if exists (
    select 1
    from public.municipality_funding_process_documents
    where municipality_id = alfa_id
      and document_name =
        'TESTE INVALIDO - responsavel Beta em documento Alfa'
  ) then
    raise exception
      'FALHA CRITICA: tentativa com responsavel cross-tenant deixou documento persistido.';
  end if;

  raise notice
    'OK: responsavel Beta foi bloqueado em documento Alfa.';
end;
$test_cross_tenant_responsible_blocked$;

-- F) Usuario authenticated sem membership, papel Anchor ou assignment
-- nao le nem escreve documentos/auditoria.
do $test_unauthorized_documents$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;

  unauthorized_id uuid :=
    current_setting('app.funding_test.unauthorized_id', true)::uuid;

  alfa_process_id uuid :=
    current_setting('app.document_test.alfa_process_id', true)::uuid;

  alfa_document_id uuid :=
    current_setting('app.document_test.alfa_document_id', true)::uuid;

  visible_count integer;
  affected_rows integer;
begin
  perform set_config(
    'request.jwt.claim.sub',
    unauthorized_id::text,
    true
  );

  -- Nao pode enxergar documentos.
  select count(*)
    into visible_count
  from public.municipality_funding_process_documents;

  if visible_count <> 0 then
    raise exception
      'FALHA: usuario sem acesso enxergou % documento(s).',
      visible_count;
  end if;

  -- Nao pode criar documento.
  begin
    insert into public.municipality_funding_process_documents (
      municipality_id,
      funding_process_id,
      document_name,
      document_type,
      is_required,
      status
    ) values (
      alfa_id,
      alfa_process_id,
      'TESTE INVALIDO - usuario sem acesso',
      'other',
      true,
      'pending'
    );

    raise exception
      'FALHA: usuario sem acesso conseguiu criar documento.';

  exception
    when insufficient_privilege then
      raise notice
        'OK: usuario sem acesso foi bloqueado no INSERT de documento.';
  end;

  -- RLS deve transformar tentativa de UPDATE em zero linhas afetadas.
  update public.municipality_funding_process_documents
     set notes = 'FALHA - UPDATE NAO AUTORIZADO'
   where id = alfa_document_id
     and municipality_id = alfa_id;

  get diagnostics affected_rows = row_count;

  if affected_rows <> 0 then
    raise exception
      'FALHA: usuario sem acesso atualizou documento da Alfa.';
  end if;

  -- Tambem nao pode enxergar auditoria.
  select count(*)
    into visible_count
  from public.municipality_funding_process_document_audit;

  if visible_count <> 0 then
    raise exception
      'FALHA: usuario sem acesso enxergou % registro(s) de auditoria documental.',
      visible_count;
  end if;

  raise notice
    'OK: usuario authenticated sem acesso nao le nem escreve documentos/auditoria.';
end;
$test_unauthorized_documents$;

-- G) Superadmin administra os dois tenants e a auditoria
-- preserva corretamente atores e payloads.
do $test_superadmin_document_audit$
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

  alfa_document_id uuid :=
    current_setting('app.document_test.alfa_document_id', true)::uuid;

  beta_document_id uuid :=
    current_setting('app.document_test.beta_document_id', true)::uuid;

  visible_count integer;
  audit_count integer;
  affected_rows integer;
begin
  perform set_config(
    'request.jwt.claim.sub',
    superadmin_id::text,
    true
  );

  -- Superadmin deve enxergar os dois documentos do teste.
  select count(*)
    into visible_count
  from public.municipality_funding_process_documents
  where id in (alfa_document_id, beta_document_id);

  if visible_count <> 2 then
    raise exception
      'FALHA: superadmin deveria enxergar os 2 documentos do teste; enxergou %.',
      visible_count;
  end if;

  -- Superadmin valida o documento Alfa.
  update public.municipality_funding_process_documents
     set status = 'validated',
         notes = 'Documento Alfa validado pelo superadmin.'
   where id = alfa_document_id
     and municipality_id = alfa_id;

  get diagnostics affected_rows = row_count;

  if affected_rows <> 1 then
    raise exception
      'FALHA: superadmin deveria atualizar exatamente 1 documento Alfa; atualizou %.',
      affected_rows;
  end if;

  -- INSERT Alfa deve preservar municipality_admin como ator.
  select count(*)
    into audit_count
  from public.municipality_funding_process_document_audit
  where funding_process_document_id = alfa_document_id
    and municipality_id = alfa_id
    and action = 'insert'
    and actor_user_id = alfa_admin_id
    and old_data is null
    and new_data is not null
    and new_data ->> 'status' = 'pending'
    and new_data ->> 'document_type' = 'certificate';

  if audit_count <> 1 then
    raise exception
      'FALHA: auditoria INSERT Alfa esperava 1 registro do municipality_admin; encontrou %.',
      audit_count;
  end if;

  -- UPDATE realizado pelo superadmin deve registrar transicao pending -> validated.
  select count(*)
    into audit_count
  from public.municipality_funding_process_document_audit
  where funding_process_document_id = alfa_document_id
    and municipality_id = alfa_id
    and action = 'update'
    and actor_user_id = superadmin_id
    and old_data is not null
    and new_data is not null
    and old_data ->> 'status' = 'pending'
    and new_data ->> 'status' = 'validated'
    and new_data ->> 'notes' =
      'Documento Alfa validado pelo superadmin.';

  if audit_count <> 1 then
    raise exception
      'FALHA: auditoria UPDATE superadmin esperava 1 registro; encontrou %.',
      audit_count;
  end if;

  -- INSERT Beta deve preservar grants_manager como ator.
  select count(*)
    into audit_count
  from public.municipality_funding_process_document_audit
  where funding_process_document_id = beta_document_id
    and municipality_id = beta_id
    and action = 'insert'
    and actor_user_id = beta_manager_id
    and old_data is null
    and new_data is not null
    and new_data ->> 'status' = 'requested'
    and new_data ->> 'document_type' = 'declaration';

  if audit_count <> 1 then
    raise exception
      'FALHA: auditoria INSERT Beta esperava 1 registro do grants_manager; encontrou %.',
      audit_count;
  end if;

  raise notice
    'OK: superadmin administrou Alfa/Beta e auditoria documental preservou atores e payloads.';
end;
$test_superadmin_document_audit$;

-- H) Integridade estrutural:
-- municipality_id e funding_process_id sao imutaveis.
do $test_document_immutability$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;

  beta_id uuid :=
    current_setting('app.funding_test.beta_id', true)::uuid;

  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;

  alfa_document_id uuid :=
    current_setting('app.document_test.alfa_document_id', true)::uuid;

  beta_process_id uuid :=
    current_setting('app.document_test.beta_process_id', true)::uuid;

  blocked boolean;
begin
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  -- 1) municipality_id nao pode ser alterado.
  blocked := false;

  begin
    update public.municipality_funding_process_documents
       set municipality_id = beta_id
     where id = alfa_document_id
       and municipality_id = alfa_id;

  exception
    when others then
      blocked := true;
  end;

  if not blocked then
    raise exception
      'FALHA CRITICA: municipality_id do documento pôde ser alterado.';
  end if;

  -- Confirma que o documento continua em Alfa.
  if not exists (
    select 1
    from public.municipality_funding_process_documents
    where id = alfa_document_id
      and municipality_id = alfa_id
  ) then
    raise exception
      'FALHA CRITICA: documento Alfa perdeu seu municipio original.';
  end if;

  -- 2) funding_process_id nao pode ser alterado.
  blocked := false;

  begin
    update public.municipality_funding_process_documents
       set funding_process_id = beta_process_id
     where id = alfa_document_id
       and municipality_id = alfa_id;

  exception
    when others then
      blocked := true;
  end;

  if not blocked then
    raise exception
      'FALHA CRITICA: funding_process_id do documento pôde ser alterado.';
  end if;

  -- Confirma novamente que o documento continua no processo Alfa original.
  if not exists (
    select 1
    from public.municipality_funding_process_documents as d
    where d.id = alfa_document_id
      and d.municipality_id = alfa_id
      and d.funding_process_id =
        current_setting(
          'app.document_test.alfa_process_id',
          true
        )::uuid
  ) then
    raise exception
      'FALHA CRITICA: documento Alfa perdeu seu processo original.';
  end if;

  raise notice
    'OK: municipality_id e funding_process_id permanecem imutaveis.';
end;
$test_document_immutability$;

-- I) Constraints de dominio e datas devem rejeitar dados invalidos.
do $test_document_constraints$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;

  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;

  alfa_process_id uuid :=
    current_setting('app.document_test.alfa_process_id', true)::uuid;

  blocked boolean;
begin
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  -- 1) expires_at nao pode ser anterior a issued_at.
  blocked := false;

  begin
    insert into public.municipality_funding_process_documents (
      municipality_id,
      funding_process_id,
      document_name,
      document_type,
      status,
      issued_at,
      expires_at
    ) values (
      alfa_id,
      alfa_process_id,
      'TESTE INVALIDO - validade anterior a emissao',
      'certificate',
      'pending',
      current_date,
      current_date - 1
    );

  exception
    when check_violation then
      blocked := true;
  end;

  if not blocked then
    raise exception
      'FALHA: documento aceitou expires_at anterior a issued_at.';
  end if;

  -- 2) document_type fora do dominio deve ser rejeitado.
  blocked := false;

  begin
    insert into public.municipality_funding_process_documents (
      municipality_id,
      funding_process_id,
      document_name,
      document_type,
      status
    ) values (
      alfa_id,
      alfa_process_id,
      'TESTE INVALIDO - document_type',
      'tipo_inexistente',
      'pending'
    );

  exception
    when check_violation then
      blocked := true;
  end;

  if not blocked then
    raise exception
      'FALHA: document_type invalido foi aceito.';
  end if;

  -- 3) status fora do dominio deve ser rejeitado.
  blocked := false;

  begin
    insert into public.municipality_funding_process_documents (
      municipality_id,
      funding_process_id,
      document_name,
      document_type,
      status
    ) values (
      alfa_id,
      alfa_process_id,
      'TESTE INVALIDO - status',
      'other',
      'status_inexistente'
    );

  exception
    when check_violation then
      blocked := true;
  end;

  if not blocked then
    raise exception
      'FALHA: status documental invalido foi aceito.';
  end if;

  raise notice
    'OK: datas, document_type e status invalidos foram bloqueados.';
end;
$test_document_constraints$;

-- J) Auditoria e DELETE sao protegidos contra escrita direta.
do $test_document_protected_operations$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;

  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;

  alfa_document_id uuid :=
    current_setting('app.document_test.alfa_document_id', true)::uuid;

  blocked boolean;
begin
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  -- 1) DELETE direto de documento deve ser bloqueado.
  blocked := false;

  begin
    delete from public.municipality_funding_process_documents
    where id = alfa_document_id
      and municipality_id = alfa_id;

  exception
    when insufficient_privilege then
      blocked := true;
  end;

  if not blocked then
    raise exception
      'FALHA CRITICA: DELETE direto de documento foi permitido.';
  end if;

  -- Documento deve continuar existindo.
  if not exists (
    select 1
    from public.municipality_funding_process_documents
    where id = alfa_document_id
      and municipality_id = alfa_id
  ) then
    raise exception
      'FALHA CRITICA: documento Alfa desapareceu apos tentativa de DELETE.';
  end if;

  -- 2) INSERT direto na auditoria deve ser bloqueado.
  blocked := false;

  begin
    insert into public.municipality_funding_process_document_audit (
      municipality_id,
      funding_process_document_id,
      action,
      actor_user_id,
      old_data,
      new_data
    ) values (
      alfa_id,
      alfa_document_id,
      'update',
      alfa_admin_id,
      '{}'::jsonb,
      '{}'::jsonb
    );

  exception
    when insufficient_privilege then
      blocked := true;
  end;

  if not blocked then
    raise exception
      'FALHA CRITICA: INSERT direto na auditoria documental foi permitido.';
  end if;

  -- 3) UPDATE direto da auditoria deve ser bloqueado.
  blocked := false;

  begin
    update public.municipality_funding_process_document_audit
       set new_data = '{"alterado":"indevidamente"}'::jsonb
     where funding_process_document_id = alfa_document_id
       and municipality_id = alfa_id;

  exception
    when insufficient_privilege then
      blocked := true;
  end;

  if not blocked then
    raise exception
      'FALHA CRITICA: UPDATE direto da auditoria documental foi permitido.';
  end if;

  -- 4) DELETE direto da auditoria deve ser bloqueado.
  blocked := false;

  begin
    delete from public.municipality_funding_process_document_audit
    where funding_process_document_id = alfa_document_id
      and municipality_id = alfa_id;

  exception
    when insufficient_privilege then
      blocked := true;
  end;

  if not blocked then
    raise exception
      'FALHA CRITICA: DELETE direto da auditoria documental foi permitido.';
  end if;

  raise notice
    'OK: DELETE de documentos e escrita direta na auditoria foram bloqueados.';
end;
$test_document_protected_operations$;

rollback;

select
  'PASSOU' as status,
  'ETAPA 20.3.19: documentos e checklist, RLS, isolamento multi-tenant, municipality_admin, grants_manager, superadmin, usuario sem acesso, processo/departamento/responsavel por tenant, constraints, auditoria e integridade validados; ROLLBACK preservou o DEV.' as mensagem;



