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

-- F) Infraestrutura Storage: bucket privado e parser UUID seguro.
do $test_storage_infrastructure$
declare
  bucket_is_public boolean;
begin
  -- Verificacao tecnica da infraestrutura: storage.buckets possui RLS.
  set local role postgres;

  select b.public
    into bucket_is_public
  from storage.buckets as b
  where b.id = 'municipality-funding-process-documents';

  if not found then
    raise exception
      'FALHA STORAGE: bucket municipality-funding-process-documents nao existe.';
  end if;

  if bucket_is_public is distinct from false then
    raise exception
      'FALHA STORAGE: bucket de documentos deve permanecer privado.';
  end if;

  -- Volta ao papel da aplicacao para o restante dos testes.
  set local role authenticated;

  if private.try_parse_uuid('not-a-uuid') is not null then
    raise exception
      'FALHA STORAGE: try_parse_uuid aceitou UUID invalido.';
  end if;

  if private.try_parse_uuid(null) is not null then
    raise exception
      'FALHA STORAGE: try_parse_uuid deveria retornar NULL para entrada NULL.';
  end if;

  raise notice
    'OK: bucket Storage privado e parser UUID seguro validados.';
end;
$test_storage_infrastructure$;

-- G) municipality_admin Alfa insere objeto Storage somente no caminho canonico do metadata.
do $test_alfa_storage_insert$
declare
  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;
  alfa_file_v2_id uuid :=
    current_setting('app.file_test.alfa_file_v2_id', true)::uuid;

  expected_bucket text;
  expected_path text;
  inserted_object_id uuid;
begin
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  select
    f.storage_bucket,
    f.storage_object_path
  into
    expected_bucket,
    expected_path
  from public.municipality_funding_process_document_files as f
  where f.id = alfa_file_v2_id;

  if expected_bucket is null or expected_path is null then
    raise exception
      'FALHA STORAGE: metadata da v2 Alfa nao foi encontrado.';
  end if;

  insert into storage.objects (
    bucket_id,
    name
  )
  values (
    expected_bucket,
    expected_path
  )
  returning id into inserted_object_id;

  if inserted_object_id is null then
    raise exception
      'FALHA STORAGE: INSERT autorizado da Alfa nao retornou object id.';
  end if;

  if not private.is_valid_funding_document_storage_object(
    expected_bucket,
    expected_path
  ) then
    raise exception
      'FALHA STORAGE: objeto Alfa nao corresponde ao metadata/caminho canonico.';
  end if;

  perform set_config(
    'app.storage_test.alfa_object_id',
    inserted_object_id::text,
    true
  );

  raise notice
    'OK: municipality_admin Alfa inseriu objeto Storage no caminho canonico autorizado.';
end;
$test_alfa_storage_insert$;
-- H) municipality_admin Alfa nao pode inserir objeto sem metadata correspondente.
do $test_alfa_storage_without_metadata$
declare
  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;

  fake_path text;
  was_blocked boolean := false;
begin
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  fake_path :=
    alfa_id::text || '/' ||
    gen_random_uuid()::text || '/' ||
    gen_random_uuid()::text || '/' ||
    gen_random_uuid()::text;

  begin
    insert into storage.objects (
      bucket_id,
      name
    )
    values (
      'municipality-funding-process-documents',
      fake_path
    );
  exception
    when insufficient_privilege then
      was_blocked := true;
  end;

  if not was_blocked then
    raise exception
      'FALHA STORAGE: Alfa conseguiu inserir objeto sem metadata correspondente.';
  end if;

  raise notice
    'OK: objeto sem metadata correspondente foi bloqueado pelo Storage RLS.';
end;
$test_alfa_storage_without_metadata$;

-- I) municipality_admin Alfa nao pode inserir objeto no caminho real da Beta.
do $test_alfa_cannot_insert_beta_storage$
declare
  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;
  beta_file_id uuid :=
    current_setting('app.file_test.beta_file_id', true)::uuid;

  beta_bucket text;
  beta_path text;
  was_blocked boolean := false;
begin
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  -- Fixture tecnica: obtem o caminho Beta fora do RLS da Alfa
  -- somente para preparar o ataque controlado.
  set local role postgres;

  select
    f.storage_bucket,
    f.storage_object_path
  into
    beta_bucket,
    beta_path
  from public.municipality_funding_process_document_files as f
  where f.id = beta_file_id;

  if beta_bucket is null or beta_path is null then
    raise exception
      'FALHA STORAGE: metadata Beta necessario ao teste nao foi encontrado.';
  end if;

  -- Volta ao papel real da aplicacao antes da tentativa.
  set local role authenticated;

  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  begin
    insert into storage.objects (
      bucket_id,
      name
    )
    values (
      beta_bucket,
      beta_path
    );
  exception
    when insufficient_privilege then
      was_blocked := true;
  end;

  if not was_blocked then
    raise exception
      'FALHA STORAGE: Alfa conseguiu inserir objeto no caminho pertencente a Beta.';
  end if;

  raise notice
    'OK: Storage RLS bloqueou Alfa no caminho real pertencente a Beta.';
end;
$test_alfa_cannot_insert_beta_storage$;

-- J) grants_manager Beta insere objeto Storage no proprio caminho canonico.
do $test_beta_storage_insert$
declare
  beta_manager_id uuid :=
    current_setting('app.funding_test.beta_manager_id', true)::uuid;
  beta_file_id uuid :=
    current_setting('app.file_test.beta_file_id', true)::uuid;

  expected_bucket text;
  expected_path text;
  inserted_object_id uuid;
begin
  perform set_config(
    'request.jwt.claim.sub',
    beta_manager_id::text,
    true
  );

  select
    f.storage_bucket,
    f.storage_object_path
  into
    expected_bucket,
    expected_path
  from public.municipality_funding_process_document_files as f
  where f.id = beta_file_id;

  if expected_bucket is null or expected_path is null then
    raise exception
      'FALHA STORAGE: metadata do arquivo Beta nao foi encontrado.';
  end if;

  insert into storage.objects (
    bucket_id,
    name
  )
  values (
    expected_bucket,
    expected_path
  )
  returning id into inserted_object_id;

  if inserted_object_id is null then
    raise exception
      'FALHA STORAGE: INSERT autorizado da Beta nao retornou object id.';
  end if;

  perform set_config(
    'app.storage_test.beta_object_id',
    inserted_object_id::text,
    true
  );

  raise notice
    'OK: grants_manager Beta inseriu objeto Storage no proprio caminho canonico.';
end;
$test_beta_storage_insert$;

-- K) municipality_admin Alfa enxerga o proprio objeto, mas nao o objeto Beta.
do $test_alfa_storage_select_isolation$
declare
  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;
  alfa_object_id uuid :=
    current_setting('app.storage_test.alfa_object_id', true)::uuid;
  beta_object_id uuid :=
    current_setting('app.storage_test.beta_object_id', true)::uuid;

  alfa_visible_count integer;
  beta_visible_count integer;
begin
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  select count(*)
    into alfa_visible_count
  from storage.objects
  where id = alfa_object_id;

  if alfa_visible_count <> 1 then
    raise exception
      'FALHA STORAGE RLS: Alfa deveria enxergar seu proprio objeto, mas encontrou %.',
      alfa_visible_count;
  end if;

  select count(*)
    into beta_visible_count
  from storage.objects
  where id = beta_object_id;

  if beta_visible_count <> 0 then
    raise exception
      'FALHA STORAGE RLS: Alfa enxergou % objeto(s) pertencente(s) a Beta.',
      beta_visible_count;
  end if;

  raise notice
    'OK: Alfa enxerga seu proprio objeto Storage e nao enxerga o objeto Beta.';
end;
$test_alfa_storage_select_isolation$;

-- L) grants_manager Beta enxerga o proprio objeto, mas nao o objeto Alfa.
do $test_beta_storage_select_isolation$
declare
  beta_manager_id uuid :=
    current_setting('app.funding_test.beta_manager_id', true)::uuid;
  alfa_object_id uuid :=
    current_setting('app.storage_test.alfa_object_id', true)::uuid;
  beta_object_id uuid :=
    current_setting('app.storage_test.beta_object_id', true)::uuid;

  alfa_visible_count integer;
  beta_visible_count integer;
begin
  perform set_config(
    'request.jwt.claim.sub',
    beta_manager_id::text,
    true
  );

  select count(*)
    into beta_visible_count
  from storage.objects
  where id = beta_object_id;

  if beta_visible_count <> 1 then
    raise exception
      'FALHA STORAGE RLS: Beta deveria enxergar seu proprio objeto, mas encontrou %.',
      beta_visible_count;
  end if;

  select count(*)
    into alfa_visible_count
  from storage.objects
  where id = alfa_object_id;

  if alfa_visible_count <> 0 then
    raise exception
      'FALHA STORAGE RLS: Beta enxergou % objeto(s) pertencente(s) a Alfa.',
      alfa_visible_count;
  end if;

  raise notice
    'OK: Beta enxerga seu proprio objeto Storage e nao enxerga o objeto Alfa.';
end;
$test_beta_storage_select_isolation$;

-- M) Usuario autenticado sem acesso nao enxerga nem insere objetos Storage.
do $test_unauthorized_storage_access$
declare
  unauthorized_id uuid :=
    current_setting('app.funding_test.unauthorized_id', true)::uuid;
  alfa_file_v2_id uuid :=
    current_setting('app.file_test.alfa_file_v2_id', true)::uuid;

  alfa_bucket text;
  alfa_path text;
  visible_count integer;
  was_blocked boolean := false;
begin
  perform set_config(
    'request.jwt.claim.sub',
    unauthorized_id::text,
    true
  );

  select count(*)
    into visible_count
  from storage.objects
  where bucket_id = 'municipality-funding-process-documents';

  if visible_count <> 0 then
    raise exception
      'FALHA STORAGE RLS: usuario sem acesso enxergou % objeto(s).',
      visible_count;
  end if;

  -- Obtem o caminho Alfa fora da visibilidade normal do usuario
  -- apenas para preparar a tentativa controlada de INSERT.
  select
    f.storage_bucket,
    f.storage_object_path
  into
    alfa_bucket,
    alfa_path
  from public.municipality_funding_process_document_files as f
  where f.id = alfa_file_v2_id;

  -- Se o RLS da tabela de metadata ocultar a linha, reconstruimos
  -- o caminho a partir das configuracoes ja criadas pelo teste.
  if alfa_bucket is null or alfa_path is null then
    alfa_bucket := 'municipality-funding-process-documents';

    select f.storage_object_path
      into alfa_path
    from public.municipality_funding_process_document_files as f
    where f.id = alfa_file_v2_id;
  end if;

  begin
    insert into storage.objects (
      bucket_id,
      name
    )
    values (
      coalesce(alfa_bucket, 'municipality-funding-process-documents'),
      coalesce(alfa_path, gen_random_uuid()::text)
    );
  exception
    when insufficient_privilege then
      was_blocked := true;
  end;

  if not was_blocked then
    raise exception
      'FALHA STORAGE RLS: usuario sem acesso conseguiu inserir objeto.';
  end if;

  raise notice
    'OK: usuario sem acesso nao le nem insere objetos Storage.';
end;
$test_unauthorized_storage_access$;

-- N) Auditor Alfa le Storage do proprio tenant, nao ve Beta e nao pode inserir.
do $test_alfa_auditor_storage_read_only$
declare
  alfa_id uuid :=
    current_setting('app.funding_test.alfa_id', true)::uuid;
  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;
  auditor_id uuid :=
    current_setting('app.funding_test.unauthorized_id', true)::uuid;
  alfa_file_v2_id uuid :=
    current_setting('app.file_test.alfa_file_v2_id', true)::uuid;
  alfa_object_id uuid :=
    current_setting('app.storage_test.alfa_object_id', true)::uuid;
  beta_object_id uuid :=
    current_setting('app.storage_test.beta_object_id', true)::uuid;

  auditor_membership_id uuid;
  alfa_bucket text;
  alfa_path text;
  alfa_visible_count integer;
  beta_visible_count integer;
  was_blocked boolean := false;
begin
  -- Fixture tecnica: cria o vinculo do auditor fora do papel authenticated.
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

  -- Recupera o caminho Alfa para a tentativa controlada de escrita.
  select
    f.storage_bucket,
    f.storage_object_path
  into
    alfa_bucket,
    alfa_path
  from public.municipality_funding_process_document_files as f
  where f.id = alfa_file_v2_id;

  -- Volta ao papel real da aplicacao.
  set local role authenticated;

  perform set_config(
    'request.jwt.claim.sub',
    auditor_id::text,
    true
  );

  select count(*)
    into alfa_visible_count
  from storage.objects
  where id = alfa_object_id;

  if alfa_visible_count <> 1 then
    raise exception
      'FALHA STORAGE RLS: auditor Alfa deveria enxergar o objeto Alfa; encontrou %.',
      alfa_visible_count;
  end if;

  select count(*)
    into beta_visible_count
  from storage.objects
  where id = beta_object_id;

  if beta_visible_count <> 0 then
    raise exception
      'FALHA STORAGE RLS: auditor Alfa enxergou % objeto(s) Beta.',
      beta_visible_count;
  end if;

  begin
    insert into storage.objects (
      bucket_id,
      name
    )
    values (
      alfa_bucket,
      alfa_path
    );
  exception
    when insufficient_privilege then
      was_blocked := true;
    when unique_violation then
      -- Unique nao conta como bloqueio de autorizacao.
      was_blocked := false;
  end;

  if not was_blocked then
    raise exception
      'FALHA STORAGE RLS: auditor Alfa nao foi bloqueado por autorizacao no INSERT.';
  end if;

  raise notice
    'OK: auditor Alfa le somente Storage do proprio tenant e nao possui permissao de INSERT.';
end;
$test_alfa_auditor_storage_read_only$;

-- O) Caminho Storage malformado e negado com seguranca, sem erro de cast UUID.
do $test_malformed_storage_path$
declare
  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;

  malformed_path text :=
    'not-a-uuid/' ||
    gen_random_uuid()::text || '/' ||
    gen_random_uuid()::text || '/' ||
    gen_random_uuid()::text;

  was_blocked boolean := false;
begin
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  if private.try_parse_uuid(
    (storage.foldername(malformed_path))[1]
  ) is not null then
    raise exception
      'FALHA STORAGE: primeiro segmento malformado foi convertido para UUID.';
  end if;

  begin
    insert into storage.objects (
      bucket_id,
      name
    )
    values (
      'municipality-funding-process-documents',
      malformed_path
    );
  exception
    when insufficient_privilege then
      was_blocked := true;
  end;

  if not was_blocked then
    raise exception
      'FALHA STORAGE RLS: caminho malformado nao foi bloqueado.';
  end if;

  raise notice
    'OK: caminho Storage malformado foi negado com seguranca pelo RLS.';
end;
$test_malformed_storage_path$;

-- P) Objetos Storage nao podem ser atualizados nem excluidos diretamente.
do $test_storage_update_delete_blocked$
declare
  alfa_admin_id uuid :=
    current_setting('app.funding_test.alfa_admin_id', true)::uuid;
  alfa_object_id uuid :=
    current_setting('app.storage_test.alfa_object_id', true)::uuid;

  affected_rows integer;
  update_blocked boolean := false;
  delete_blocked boolean := false;
begin
  perform set_config(
    'request.jwt.claim.sub',
    alfa_admin_id::text,
    true
  );

  -- Nao existe policy UPDATE para este bucket.
  begin
    update storage.objects
       set user_metadata = '{"attempt":"blocked"}'::jsonb
     where id = alfa_object_id;

    get diagnostics affected_rows = row_count;

    if affected_rows = 0 then
      update_blocked := true;
    end if;
  exception
    when insufficient_privilege then
      update_blocked := true;
  end;

  if not update_blocked then
    raise exception
      'FALHA STORAGE: municipality_admin Alfa conseguiu atualizar objeto diretamente.';
  end if;

  -- Nao existe policy DELETE para este bucket.
  begin
    delete from storage.objects
     where id = alfa_object_id;

    get diagnostics affected_rows = row_count;

    if affected_rows = 0 then
      delete_blocked := true;
    end if;
  exception
    when insufficient_privilege then
      delete_blocked := true;
  end;

  if not delete_blocked then
    raise exception
      'FALHA STORAGE: municipality_admin Alfa conseguiu excluir objeto diretamente.';
  end if;

  raise notice
    'OK: UPDATE e DELETE diretos em objetos Storage foram bloqueados.';
end;
$test_storage_update_delete_blocked$;

-- Q) Superadmin enxerga os objetos Storage Alfa e Beta.
do $test_superadmin_storage_select$
declare
  superadmin_id uuid :=
    current_setting('app.funding_test.superadmin_id', true)::uuid;
  alfa_object_id uuid :=
    current_setting('app.storage_test.alfa_object_id', true)::uuid;
  beta_object_id uuid :=
    current_setting('app.storage_test.beta_object_id', true)::uuid;

  alfa_visible_count integer;
  beta_visible_count integer;
begin
  perform set_config(
    'request.jwt.claim.sub',
    superadmin_id::text,
    true
  );

  select count(*)
    into alfa_visible_count
  from storage.objects
  where id = alfa_object_id;

  if alfa_visible_count <> 1 then
    raise exception
      'FALHA STORAGE RLS: superadmin deveria enxergar o objeto Alfa; encontrou %.',
      alfa_visible_count;
  end if;

  select count(*)
    into beta_visible_count
  from storage.objects
  where id = beta_object_id;

  if beta_visible_count <> 1 then
    raise exception
      'FALHA STORAGE RLS: superadmin deveria enxergar o objeto Beta; encontrou %.',
      beta_visible_count;
  end if;

  raise notice
    'OK: superadmin enxerga os objetos Storage Alfa e Beta.';
end;
$test_superadmin_storage_select$;

-- Nenhum dado de teste deve permanecer no DEV.
rollback;

select
  'PASSOU' as status,
  'ETAPA 20.3.20B: bucket privado, Storage RLS, caminhos canonicos, INSERT autorizado, isolamento Alfa/Beta, usuario sem acesso, auditor, caminho malformado, bloqueio de UPDATE/DELETE e superadmin validados; ROLLBACK preservou o DEV.' as etapa;



