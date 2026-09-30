-- ETAPA 20.3.20A
-- Teste DEV: Metadados e Versionamento de Arquivos dos Documentos
-- Valida versionamento v1/v2, RLS, isolamento multi-tenant, permissoes,
-- campos derivados, constraints, auditoria e integridade estrutural.
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
      ('public.municipality_funding_process_document_files'),
      ('public.municipality_funding_process_document_file_audit'),
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
    'OK: preflight da ETAPA 20.3.20A confirmou todas as tabelas obrigatorias.';
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

-- C) municipality_admin Alfa cria a primeira versao do arquivo.
do $test_alfa_file_v1$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;
  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;
  alfa_process_id uuid :=
    current_setting('app.document_test.alfa_process_id', true)::uuid;
  alfa_document_id uuid :=
    current_setting('app.document_test.alfa_document_id', true)::uuid;

  file_id uuid;
begin
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  insert into public.municipality_funding_process_document_files (
    funding_process_document_id,
    original_filename,
    content_type,
    byte_size,
    checksum_sha256,
    notes
  ) values (
    alfa_document_id,
    'certidao-regularidade-v1.pdf',
    'application/pdf',
    1024,
    repeat('a', 64),
    'Primeira versao temporaria - TESTE 20.3.20A.'
  )
  returning id into file_id;

  if file_id is null then
    raise exception
      'FALHA: municipality_admin Alfa nao criou arquivo v1.';
  end if;

  if not exists (
    select 1
    from public.municipality_funding_process_document_files as f
    where f.id = file_id
      and f.municipality_id = alfa_id
      and f.funding_process_document_id = alfa_document_id
      and f.version_number = 1
      and f.storage_bucket = 'municipality-funding-process-documents'
      and f.storage_object_path =
        alfa_id::text || '/' ||
        alfa_process_id::text || '/' ||
        alfa_document_id::text || '/' ||
        file_id::text
      and f.original_filename = 'certidao-regularidade-v1.pdf'
      and f.content_type = 'application/pdf'
      and f.byte_size = 1024
      and f.checksum_sha256 = repeat('a', 64)
      and f.is_current is true
      and f.superseded_at is null
      and f.uploaded_by_user_id = alfa_admin_id
  ) then
    raise exception
      'FALHA: arquivo Alfa v1 nao possui metadados derivados esperados.';
  end if;

  perform set_config(
    'app.file_test.alfa_file_v1_id',
    file_id::text,
    true
  );

  raise notice
    'OK: Alfa criou arquivo v1; tenant, versao, bucket, path, current e uploader foram derivados.';
end;
$test_alfa_file_v1$;

-- D) Nova versao Alfa supersede automaticamente a v1.
do $test_alfa_file_v2$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;
  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;
  alfa_process_id uuid :=
    current_setting('app.document_test.alfa_process_id', true)::uuid;
  alfa_document_id uuid :=
    current_setting('app.document_test.alfa_document_id', true)::uuid;
  file_v1_id uuid :=
    current_setting('app.file_test.alfa_file_v1_id', true)::uuid;

  file_v2_id uuid;
  current_count integer;
begin
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  insert into public.municipality_funding_process_document_files (
    funding_process_document_id,
    original_filename,
    content_type,
    byte_size,
    checksum_sha256,
    notes
  ) values (
    alfa_document_id,
    'certidao-regularidade-v2.pdf',
    'application/pdf',
    2048,
    repeat('b', 64),
    'Segunda versao temporaria - TESTE 20.3.20A.'
  )
  returning id into file_v2_id;

  if file_v2_id is null then
    raise exception
      'FALHA: municipality_admin Alfa nao criou arquivo v2.';
  end if;

  if not exists (
    select 1
    from public.municipality_funding_process_document_files as f
    where f.id = file_v2_id
      and f.municipality_id = alfa_id
      and f.funding_process_document_id = alfa_document_id
      and f.version_number = 2
      and f.storage_bucket = 'municipality-funding-process-documents'
      and f.storage_object_path =
        alfa_id::text || '/' ||
        alfa_process_id::text || '/' ||
        alfa_document_id::text || '/' ||
        file_v2_id::text
      and f.original_filename = 'certidao-regularidade-v2.pdf'
      and f.content_type = 'application/pdf'
      and f.byte_size = 2048
      and f.checksum_sha256 = repeat('b', 64)
      and f.is_current is true
      and f.superseded_at is null
      and f.uploaded_by_user_id = alfa_admin_id
  ) then
    raise exception
      'FALHA: arquivo Alfa v2 nao possui os metadados esperados.';
  end if;

  if not exists (
    select 1
    from public.municipality_funding_process_document_files as f
    where f.id = file_v1_id
      and f.version_number = 1
      and f.is_current is false
      and f.superseded_at is not null
  ) then
    raise exception
      'FALHA: v1 Alfa nao foi marcada como superseded pela v2.';
  end if;

  select count(*)
    into current_count
  from public.municipality_funding_process_document_files as f
  where f.funding_process_document_id = alfa_document_id
    and f.is_current is true;

  if current_count <> 1 then
    raise exception
      'FALHA: documento Alfa deveria possuir exatamente 1 versao current; encontrou %.',
      current_count;
  end if;

  if (
    select max(f.version_number)
    from public.municipality_funding_process_document_files as f
    where f.funding_process_document_id = alfa_document_id
  ) <> 2 then
    raise exception
      'FALHA: maior version_number do documento Alfa deveria ser 2.';
  end if;

  perform set_config(
    'app.file_test.alfa_file_v2_id',
    file_v2_id::text,
    true
  );

  raise notice
    'OK: Alfa v2 criada; v1 superseded e existe exatamente uma versao current.';
end;
$test_alfa_file_v2$;

-- E) grants_manager Beta cria arquivo proprio e nao enxerga arquivos Alfa.
do $test_beta_file_and_isolation$
declare
  beta_id uuid :=
    current_setting('app.funding_test.beta_id', true)::uuid;
  beta_manager_id uuid :=
    current_setting('app.funding_test.beta_manager_id', true)::uuid;
  beta_process_id uuid :=
    current_setting('app.document_test.beta_process_id', true)::uuid;
  beta_document_id uuid :=
    current_setting('app.document_test.beta_document_id', true)::uuid;
  alfa_document_id uuid :=
    current_setting('app.document_test.alfa_document_id', true)::uuid;

  beta_file_id uuid;
  alfa_visible_count integer;
begin
  perform set_config(
    'request.jwt.claim.sub',
    beta_manager_id::text,
    true
  );

  insert into public.municipality_funding_process_document_files (
    funding_process_document_id,
    original_filename,
    content_type,
    byte_size,
    checksum_sha256,
    notes
  ) values (
    beta_document_id,
    'declaracao-beta-v1.pdf',
    'application/pdf',
    1536,
    repeat('c', 64),
    'Arquivo temporario Beta - TESTE 20.3.20A.'
  )
  returning id into beta_file_id;

  if beta_file_id is null then
    raise exception
      'FALHA: grants_manager Beta nao criou arquivo proprio.';
  end if;

  if not exists (
    select 1
    from public.municipality_funding_process_document_files as f
    where f.id = beta_file_id
      and f.municipality_id = beta_id
      and f.funding_process_document_id = beta_document_id
      and f.version_number = 1
      and f.storage_bucket = 'municipality-funding-process-documents'
      and f.storage_object_path =
        beta_id::text || '/' ||
        beta_process_id::text || '/' ||
        beta_document_id::text || '/' ||
        beta_file_id::text
      and f.is_current is true
      and f.superseded_at is null
      and f.uploaded_by_user_id = beta_manager_id
  ) then
    raise exception
      'FALHA: arquivo Beta nao possui tenant/versionamento/path/uploader esperados.';
  end if;

  select count(*)
    into alfa_visible_count
  from public.municipality_funding_process_document_files as f
  where f.funding_process_document_id = alfa_document_id;

  if alfa_visible_count <> 0 then
    raise exception
      'FALHA RLS: Beta enxergou % arquivo(s) pertencente(s) a Alfa.',
      alfa_visible_count;
  end if;

  perform set_config(
    'app.file_test.beta_file_id',
    beta_file_id::text,
    true
  );

  raise notice
    'OK: Beta criou arquivo proprio e RLS ocultou os arquivos Alfa.';
end;
$test_beta_file_and_isolation$;

-- F) municipality_admin Alfa nao pode inserir arquivo no documento Beta.
do $test_alfa_cannot_insert_beta_file$
declare
  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;
  beta_document_id uuid :=
    current_setting('app.document_test.beta_document_id', true)::uuid;

  inserted_id uuid;
  was_blocked boolean := false;
begin
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  begin
    insert into public.municipality_funding_process_document_files (
      funding_process_document_id,
      original_filename,
      content_type,
      byte_size,
      checksum_sha256,
      notes
    ) values (
      beta_document_id,
      'tentativa-alfa-em-beta.pdf',
      'application/pdf',
      512,
      repeat('d', 64),
      'Esta insercao deve ser bloqueada - TESTE 20.3.20A.'
    )
    returning id into inserted_id;

  exception
    when insufficient_privilege then
      was_blocked := true;
    when check_violation then
      was_blocked := true;
    when raise_exception then
      was_blocked := true;
  end;

  if not was_blocked then
    raise exception
      'FALHA RLS: Alfa conseguiu inserir arquivo no documento pertencente a Beta.';
  end if;

  if inserted_id is not null then
    raise exception
      'FALHA: tentativa cross-tenant retornou um file_id inesperadamente.';
  end if;

  raise notice
    'OK: Alfa foi bloqueada ao tentar inserir arquivo no documento Beta.';
end;
$test_alfa_cannot_insert_beta_file$;

-- G) Usuario sem acesso nao enxerga arquivos e nao consegue inserir.
do $test_unauthorized_user$
declare
  unauthorized_id uuid :=
    current_setting('app.funding_test.unauthorized_id', true)::uuid;
  alfa_document_id uuid :=
    current_setting('app.document_test.alfa_document_id', true)::uuid;

  visible_count integer;
  inserted_id uuid;
  was_blocked boolean := false;
begin
  perform set_config(
    'request.jwt.claim.sub',
    unauthorized_id::text,
    true
  );

  select count(*)
    into visible_count
  from public.municipality_funding_process_document_files;

  if visible_count <> 0 then
    raise exception
      'FALHA RLS: usuario sem acesso enxergou % arquivo(s).',
      visible_count;
  end if;

  begin
    insert into public.municipality_funding_process_document_files (
      funding_process_document_id,
      original_filename,
      content_type,
      byte_size,
      checksum_sha256,
      notes
    ) values (
      alfa_document_id,
      'tentativa-sem-acesso.pdf',
      'application/pdf',
      256,
      repeat('e', 64),
      'Esta insercao deve ser bloqueada - TESTE 20.3.20A.'
    )
    returning id into inserted_id;

  exception
    when insufficient_privilege then
      was_blocked := true;
    when check_violation then
      was_blocked := true;
    when raise_exception then
      was_blocked := true;
  end;

  if not was_blocked then
    raise exception
      'FALHA RLS: usuario sem acesso conseguiu inserir arquivo.';
  end if;

  if inserted_id is not null then
    raise exception
      'FALHA: tentativa sem acesso retornou um file_id inesperadamente.';
  end if;

  raise notice
    'OK: usuario sem acesso nao enxerga arquivos e nao consegue inserir.';
end;
$test_unauthorized_user$;

-- H) Auditor municipal Alfa possui leitura do proprio tenant, mas nao escrita.
do $test_alfa_auditor_read_only$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;
  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;
  auditor_id uuid :=
    current_setting('app.funding_test.unauthorized_id', true)::uuid;
  alfa_document_id uuid :=
    current_setting('app.document_test.alfa_document_id', true)::uuid;
  alfa_file_v2_id uuid :=
    current_setting('app.file_test.alfa_file_v2_id', true)::uuid;

  auditor_membership_id uuid;
  alfa_visible_count integer;
  beta_visible_count integer;
  inserted_id uuid;
  was_blocked boolean;
begin
  -- Fixture tecnica do teste: sai temporariamente de authenticated.
  set local role postgres;

  insert into public.municipality_members (
    municipality_id,
    user_id,
    status,
    invited_by,
    activated_at
  ) values (
    alfa_id,
    auditor_id,
    'active'::public.membership_status,
    alfa_admin_id,
    now()
  )
  returning id into auditor_membership_id;

  insert into public.municipality_member_roles (
    membership_id,
    role_scope,
    role_code,
    assigned_by
  ) values (
    auditor_membership_id,
    'municipality'::public.role_scope,
    'auditor',
    alfa_admin_id
  );

  -- Volta ao papel real da aplicacao antes de testar o auditor.
  set local role authenticated;

  perform set_config(
    'request.jwt.claim.sub',
    auditor_id::text,
    true
  );

  select count(*)
    into alfa_visible_count
  from public.municipality_funding_process_document_files
  where municipality_id = alfa_id;

  if alfa_visible_count <> 2 then
    raise exception
      'FALHA RLS: auditor Alfa deveria enxergar 2 arquivos Alfa; encontrou %.',
      alfa_visible_count;
  end if;

  select count(*)
    into beta_visible_count
  from public.municipality_funding_process_document_files
  where municipality_id <> alfa_id;

  if beta_visible_count <> 0 then
    raise exception
      'FALHA RLS: auditor Alfa enxergou % arquivo(s) de outro tenant.',
      beta_visible_count;
  end if;

  was_blocked := false;

  begin
    insert into public.municipality_funding_process_document_files (
      funding_process_document_id,
      original_filename,
      content_type,
      byte_size,
      checksum_sha256,
      notes
    ) values (
      alfa_document_id,
      'tentativa-auditor.pdf',
      'application/pdf',
      300,
      repeat('f', 64),
      'Auditor nao pode criar arquivo.'
    )
    returning id into inserted_id;

  exception
    when insufficient_privilege then
      was_blocked := true;
    when check_violation then
      was_blocked := true;
    when raise_exception then
      was_blocked := true;
  end;

  if not was_blocked then
    raise exception
      'FALHA: auditor Alfa conseguiu inserir arquivo.';
  end if;

  was_blocked := false;

  begin
    update public.municipality_funding_process_document_files
       set notes = 'Auditor nao pode alterar notas.'
     where id = alfa_file_v2_id;

    get diagnostics alfa_visible_count = row_count;

    if alfa_visible_count = 0 then
      was_blocked := true;
    end if;

  exception
    when insufficient_privilege then
      was_blocked := true;
    when check_violation then
      was_blocked := true;
    when raise_exception then
      was_blocked := true;
  end;

  if not was_blocked then
    raise exception
      'FALHA: auditor Alfa conseguiu atualizar arquivo.';
  end if;

  raise notice
    'OK: auditor Alfa le somente o proprio tenant e nao insere nem atualiza arquivos.';
end;
$test_alfa_auditor_read_only$;

-- I) Superadmin enxerga Alfa/Beta e pode atualizar notes.
do $test_superadmin_access_and_notes$
declare
  superadmin_id uuid :=
    current_setting('app.funding_test.superadmin_id', true)::uuid;
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;
  beta_id uuid :=
    current_setting('app.funding_test.beta_id', true)::uuid;
  alfa_file_v2_id uuid :=
    current_setting('app.file_test.alfa_file_v2_id', true)::uuid;

  alfa_visible_count integer;
  beta_visible_count integer;
  affected_rows integer;
begin
  perform set_config(
    'request.jwt.claim.sub',
    superadmin_id::text,
    true
  );

  select count(*)
    into alfa_visible_count
  from public.municipality_funding_process_document_files
  where municipality_id = alfa_id;

  if alfa_visible_count <> 2 then
    raise exception
      'FALHA: superadmin deveria enxergar 2 arquivos Alfa; encontrou %.',
      alfa_visible_count;
  end if;

  select count(*)
    into beta_visible_count
  from public.municipality_funding_process_document_files
  where municipality_id = beta_id;

  if beta_visible_count <> 1 then
    raise exception
      'FALHA: superadmin deveria enxergar 1 arquivo Beta; encontrou %.',
      beta_visible_count;
  end if;

  update public.municipality_funding_process_document_files
     set notes = 'Notas atualizadas pelo superadmin - TESTE 20.3.20A.'
   where id = alfa_file_v2_id;

  get diagnostics affected_rows = row_count;

  if affected_rows <> 1 then
    raise exception
      'FALHA: superadmin deveria atualizar exatamente 1 arquivo Alfa; atualizou %.',
      affected_rows;
  end if;

  if not exists (
    select 1
    from public.municipality_funding_process_document_files
    where id = alfa_file_v2_id
      and notes = 'Notas atualizadas pelo superadmin - TESTE 20.3.20A.'
  ) then
    raise exception
      'FALHA: UPDATE de notes pelo superadmin nao foi persistido.';
  end if;

  raise notice
    'OK: superadmin enxerga Alfa/Beta e atualiza notes.';
end;
$test_superadmin_access_and_notes$;

-- J) UPDATE real de notes gera auditoria; UPDATE sem mudanca nao gera evento extra.
do $test_notes_audit_and_noop$
declare
  superadmin_id uuid :=
    current_setting('app.funding_test.superadmin_id', true)::uuid;
  alfa_file_v2_id uuid :=
    current_setting('app.file_test.alfa_file_v2_id', true)::uuid;

  audit_before integer;
  audit_after_noop integer;
begin
  perform set_config(
    'request.jwt.claim.sub',
    superadmin_id::text,
    true
  );

  select count(*)
    into audit_before
  from public.municipality_funding_process_document_file_audit
  where funding_process_document_file_id = alfa_file_v2_id
    and action = 'update'
    and actor_user_id = superadmin_id
    and old_data ->> 'notes' =
      'Segunda versao temporaria - TESTE 20.3.20A.'
    and new_data ->> 'notes' =
      'Notas atualizadas pelo superadmin - TESTE 20.3.20A.';

  if audit_before <> 1 then
    raise exception
      'FALHA: auditoria esperava 1 UPDATE real de notes pelo superadmin; encontrou %.',
      audit_before;
  end if;

  update public.municipality_funding_process_document_files
     set notes = 'Notas atualizadas pelo superadmin - TESTE 20.3.20A.'
   where id = alfa_file_v2_id;

  select count(*)
    into audit_after_noop
  from public.municipality_funding_process_document_file_audit
  where funding_process_document_file_id = alfa_file_v2_id
    and action = 'update'
    and actor_user_id = superadmin_id;

  if audit_after_noop <> audit_before then
    raise exception
      'FALHA: UPDATE sem mudanca criou auditoria extra; antes %, depois %.',
      audit_before,
      audit_after_noop;
  end if;

  raise notice
    'OK: UPDATE real de notes gerou auditoria e no-op nao gerou evento extra.';
end;
$test_notes_audit_and_noop$;

-- K) Auditoria preserva a sequencia v1 INSERT -> v1 superseded -> v2 INSERT.
do $test_versioning_audit$
declare
  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;
  alfa_file_v1_id uuid :=
    current_setting('app.file_test.alfa_file_v1_id', true)::uuid;
  alfa_file_v2_id uuid :=
    current_setting('app.file_test.alfa_file_v2_id', true)::uuid;

  v1_insert_count integer;
  v1_supersede_count integer;
  v2_insert_count integer;
begin
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  select count(*)
    into v1_insert_count
  from public.municipality_funding_process_document_file_audit
  where funding_process_document_file_id = alfa_file_v1_id
    and action = 'insert'
    and actor_user_id = alfa_admin_id
    and old_data is null
    and new_data ->> 'version_number' = '1'
    and new_data ->> 'is_current' = 'true';

  if v1_insert_count <> 1 then
    raise exception
      'FALHA: auditoria esperava 1 INSERT da v1 Alfa; encontrou %.',
      v1_insert_count;
  end if;

  select count(*)
    into v1_supersede_count
  from public.municipality_funding_process_document_file_audit
  where funding_process_document_file_id = alfa_file_v1_id
    and action = 'update'
    and actor_user_id = alfa_admin_id
    and old_data ->> 'is_current' = 'true'
    and new_data ->> 'is_current' = 'false'
    and new_data ->> 'superseded_at' is not null;

  if v1_supersede_count <> 1 then
    raise exception
      'FALHA: auditoria esperava 1 supersede da v1 Alfa; encontrou %.',
      v1_supersede_count;
  end if;

  select count(*)
    into v2_insert_count
  from public.municipality_funding_process_document_file_audit
  where funding_process_document_file_id = alfa_file_v2_id
    and action = 'insert'
    and actor_user_id = alfa_admin_id
    and old_data is null
    and new_data ->> 'version_number' = '2'
    and new_data ->> 'is_current' = 'true';

  if v2_insert_count <> 1 then
    raise exception
      'FALHA: auditoria esperava 1 INSERT da v2 Alfa; encontrou %.',
      v2_insert_count;
  end if;

  raise notice
    'OK: auditoria registrou INSERT v1, supersede v1 e INSERT v2 com ator correto.';
end;
$test_versioning_audit$;

-- L) Campos estruturais/derivados nao podem ser alterados diretamente.
do $test_structural_fields_immutable$
declare
  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;
  alfa_file_v2_id uuid :=
    current_setting('app.file_test.alfa_file_v2_id', true)::uuid;

  was_blocked boolean;
begin
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  -- storage_object_path nao esta liberado para UPDATE do authenticated.
  was_blocked := false;

  begin
    update public.municipality_funding_process_document_files
       set storage_object_path = 'caminho/adulterado'
     where id = alfa_file_v2_id;

  exception
    when insufficient_privilege then
      was_blocked := true;
    when check_violation then
      was_blocked := true;
    when raise_exception then
      was_blocked := true;
  end;

  if not was_blocked then
    raise exception
      'FALHA: authenticated conseguiu alterar storage_object_path.';
  end if;

  -- is_current tambem e controlado internamente pelo versionamento.
  was_blocked := false;

  begin
    update public.municipality_funding_process_document_files
       set is_current = false
     where id = alfa_file_v2_id;

  exception
    when insufficient_privilege then
      was_blocked := true;
    when check_violation then
      was_blocked := true;
    when raise_exception then
      was_blocked := true;
  end;

  if not was_blocked then
    raise exception
      'FALHA: authenticated conseguiu alterar is_current diretamente.';
  end if;

  -- A linha deve permanecer estruturalmente intacta.
  if not exists (
    select 1
    from public.municipality_funding_process_document_files
    where id = alfa_file_v2_id
      and version_number = 2
      and is_current is true
      and superseded_at is null
  ) then
    raise exception
      'FALHA: tentativa de adulteracao modificou a estrutura da v2.';
  end if;

  raise notice
    'OK: storage_object_path e is_current estao protegidos contra alteracao direta.';
end;
$test_structural_fields_immutable$;

-- M) Constraints rejeitam metadados de arquivo invalidos.
do $test_file_input_constraints$
declare
  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;
  alfa_document_id uuid :=
    current_setting('app.document_test.alfa_document_id', true)::uuid;

  was_blocked boolean;
begin
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  -- Nome vazio.
  was_blocked := false;
  begin
    insert into public.municipality_funding_process_document_files (
      funding_process_document_id, original_filename, content_type,
      byte_size, checksum_sha256, notes
    ) values (
      alfa_document_id, '', 'application/pdf',
      100, repeat('1', 64), 'Deve falhar: filename vazio.'
    );
  exception
    when check_violation then was_blocked := true;
    when raise_exception then was_blocked := true;
  end;

  if not was_blocked then
    raise exception 'FALHA: original_filename vazio foi aceito.';
  end if;

  -- Tamanho negativo.
  was_blocked := false;
  begin
    insert into public.municipality_funding_process_document_files (
      funding_process_document_id, original_filename, content_type,
      byte_size, checksum_sha256, notes
    ) values (
      alfa_document_id, 'tamanho-invalido.pdf', 'application/pdf',
      -1, repeat('2', 64), 'Deve falhar: byte_size negativo.'
    );
  exception
    when check_violation then was_blocked := true;
    when raise_exception then was_blocked := true;
  end;

  if not was_blocked then
    raise exception 'FALHA: byte_size negativo foi aceito.';
  end if;

  -- SHA-256 invalido.
  was_blocked := false;
  begin
    insert into public.municipality_funding_process_document_files (
      funding_process_document_id, original_filename, content_type,
      byte_size, checksum_sha256, notes
    ) values (
      alfa_document_id, 'checksum-invalido.pdf', 'application/pdf',
      100, 'checksum-invalido', 'Deve falhar: SHA-256 invalido.'
    );
  exception
    when check_violation then was_blocked := true;
    when raise_exception then was_blocked := true;
  end;

  if not was_blocked then
    raise exception 'FALHA: checksum_sha256 invalido foi aceito.';
  end if;

  -- MIME type sem barra.
  was_blocked := false;
  begin
    insert into public.municipality_funding_process_document_files (
      funding_process_document_id, original_filename, content_type,
      byte_size, checksum_sha256, notes
    ) values (
      alfa_document_id, 'mime-invalido.pdf', 'applicationpdf',
      100, repeat('3', 64), 'Deve falhar: MIME type invalido.'
    );
  exception
    when check_violation then was_blocked := true;
    when raise_exception then was_blocked := true;
  end;

  if not was_blocked then
    raise exception 'FALHA: content_type malformado foi aceito.';
  end if;

  raise notice
    'OK: filename, byte_size, checksum SHA-256 e content_type invalidos foram bloqueados.';
end;
$test_file_input_constraints$;

-- N) DELETE de arquivo e escrita direta na auditoria sao bloqueados.
do $test_delete_and_direct_audit_write$
declare
  superadmin_id uuid :=
    current_setting('app.funding_test.superadmin_id', true)::uuid;
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;
  alfa_file_v2_id uuid :=
    current_setting('app.file_test.alfa_file_v2_id', true)::uuid;

  was_blocked boolean;
begin
  perform set_config(
    'request.jwt.claim.sub',
    superadmin_id::text,
    true
  );

  -- Nem o superadmin autenticado possui DELETE direto nos arquivos.
  was_blocked := false;

  begin
    delete from public.municipality_funding_process_document_files
    where id = alfa_file_v2_id;

  exception
    when insufficient_privilege then
      was_blocked := true;
    when raise_exception then
      was_blocked := true;
  end;

  if not was_blocked then
    raise exception
      'FALHA: authenticated/superadmin conseguiu executar DELETE de arquivo.';
  end if;

  if not exists (
    select 1
    from public.municipality_funding_process_document_files
    where id = alfa_file_v2_id
  ) then
    raise exception
      'FALHA: arquivo Alfa v2 desapareceu apos tentativa de DELETE.';
  end if;

  -- INSERT direto na auditoria deve ser bloqueado.
  was_blocked := false;

  begin
    insert into public.municipality_funding_process_document_file_audit (
      funding_process_document_file_id,
      municipality_id,
      action,
      actor_user_id,
      old_data,
      new_data
    ) values (
      alfa_file_v2_id,
      alfa_id,
      'update',
      superadmin_id,
      jsonb_build_object('source', 'teste-direto'),
      jsonb_build_object('source', 'teste-direto')
    );

  exception
    when insufficient_privilege then
      was_blocked := true;
    when raise_exception then
      was_blocked := true;
  end;

  if not was_blocked then
    raise exception
      'FALHA: authenticated conseguiu INSERT direto na auditoria.';
  end if;

  -- UPDATE direto na auditoria tambem deve ser bloqueado.
  was_blocked := false;

  begin
    update public.municipality_funding_process_document_file_audit
       set new_data = jsonb_build_object('source', 'adulterado')
     where funding_process_document_file_id = alfa_file_v2_id;

  exception
    when insufficient_privilege then
      was_blocked := true;
    when raise_exception then
      was_blocked := true;
  end;

  if not was_blocked then
    raise exception
      'FALHA: authenticated conseguiu UPDATE direto na auditoria.';
  end if;

  -- DELETE direto na auditoria tambem deve ser bloqueado.
  was_blocked := false;

  begin
    delete from public.municipality_funding_process_document_file_audit
    where funding_process_document_file_id = alfa_file_v2_id;

  exception
    when insufficient_privilege then
      was_blocked := true;
    when raise_exception then
      was_blocked := true;
  end;

  if not was_blocked then
    raise exception
      'FALHA: authenticated conseguiu DELETE direto na auditoria.';
  end if;

  raise notice
    'OK: DELETE de arquivo e INSERT/UPDATE/DELETE direto na auditoria foram bloqueados.';
end;
$test_delete_and_direct_audit_write$;


rollback;

select
  'PASSOU' as status,
  'ETAPA 20.3.20A: metadados e versionamento de arquivos, v1/v2, RLS, isolamento multi-tenant, permissoes, campos derivados, constraints, auditoria e integridade estrutural validados; ROLLBACK preservou o DEV.' as mensagem;


