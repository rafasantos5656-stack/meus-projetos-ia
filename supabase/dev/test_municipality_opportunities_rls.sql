-- SOMENTE DEV — teste transacional de RLS para Prefeitura × Oportunidade.
-- Requer os fixtures ANCHOR_DEV_TEST criados pelo setup da Etapa 20.3.11.
-- Não usar em PROD. O script termina em ROLLBACK e não persiste relações/auditorias.
-- Cobertura explicitamente pendente, sem fixtures adicionais nesta execução:
-- anchor_operator e membership municipal somente leitura.

begin;

do $setup$
declare
  matching_count integer;
  fixture_source_id uuid;
  alfa_id uuid;
  beta_id uuid;
  superadmin_id uuid;
  alfa_manager_id uuid;
  beta_grants_manager_id uuid;
  published_one_id uuid;
  published_two_id uuid;
  unpublished_id uuid;
begin
  if exists (
    select 1
    from (values
      ('public.opportunity_sources'),
      ('public.opportunities'),
      ('public.municipality_opportunities'),
      ('public.municipality_opportunity_audit'),
      ('public.municipalities'),
      ('public.municipality_members'),
      ('public.municipality_member_roles'),
      ('public.anchor_user_roles')
    ) as required_table(qualified_name)
    where pg_catalog.to_regclass(required_table.qualified_name) is null
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: tabelas esperadas da fundação e do multi-tenant não existem no DEV.';
  end if;

  -- O teste parte de relações municipais vazias para que as contagens de leitura
  -- e auditoria sejam determinísticas. Não remova registros para satisfazer isto.
  if exists (select 1 from public.municipality_opportunities)
     or exists (select 1 from public.municipality_opportunity_audit) then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: as tabelas municipais já possuem dados. Revise o DEV antes de executar.';
  end if;

  select count(*), (array_agg(source.id order by source.id))[1]
    into matching_count, fixture_source_id
  from public.opportunity_sources as source
  where source.code = 'ANCHOR_DEV_TEST'
    and source.active = true;

  if matching_count <> 1 then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: deve existir exatamente uma fonte ANCHOR_DEV_TEST ativa.';
  end if;

  select count(*)
    into matching_count
  from public.opportunities as opportunity
  where opportunity.source_id = fixture_source_id;

  if matching_count <> 3 then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: ANCHOR_DEV_TEST deve possuir exatamente as três oportunidades canônicas e nenhuma adicional.';
  end if;

  select opportunity.id
    into published_one_id
  from public.opportunities as opportunity
  where opportunity.source_id = source_id
    and opportunity.external_id = 'OPP_DEV_PUBLISHED_001'
    and opportunity.is_published = true
    and opportunity.status = 'open';

  select opportunity.id
    into published_two_id
  from public.opportunities as opportunity
  where opportunity.source_id = source_id
    and opportunity.external_id = 'OPP_DEV_PUBLISHED_002'
    and opportunity.is_published = true
    and opportunity.status = 'open';

  select opportunity.id
    into unpublished_id
  from public.opportunities as opportunity
  where opportunity.source_id = source_id
    and opportunity.external_id = 'OPP_DEV_UNPUBLISHED_001'
    and opportunity.is_published = false
    and opportunity.status = 'open';

  if published_one_id is null or published_two_id is null or unpublished_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: os três fixtures globais esperados não estão no estado canônico.';
  end if;

  select count(*), (array_agg(municipality.id order by municipality.id))[1]
    into matching_count, alfa_id
  from public.municipalities as municipality
  where lower(btrim(municipality.name)) = lower('Prefeitura Alfa')
    and municipality.state = 'SP'
    and municipality.status = 'active'::public.municipality_status;

  if matching_count = 0 then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: nenhuma Prefeitura Alfa ativa em SP foi encontrada.';
  elsif matching_count > 1 then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: mais de uma Prefeitura Alfa ativa em SP foi encontrada; a resolução por nome/UF é ambígua.';
  end if;

  select count(*), (array_agg(municipality.id order by municipality.id))[1]
    into matching_count, beta_id
  from public.municipalities as municipality
  where lower(btrim(municipality.name)) = lower('Prefeitura Beta')
    and municipality.state = 'SP'
    and municipality.status = 'active'::public.municipality_status;

  if matching_count = 0 then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: nenhuma Prefeitura Beta ativa em SP foi encontrada.';
  elsif matching_count > 1 then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: mais de uma Prefeitura Beta ativa em SP foi encontrada; a resolução por nome/UF é ambígua.';
  end if;

  if alfa_id = beta_id then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: Prefeitura Alfa e Prefeitura Beta ativas e distintas são obrigatórias.';
  end if;

  select count(distinct role_assignment.user_id), (array_agg(distinct role_assignment.user_id))[1]
    into matching_count, superadmin_id
  from public.anchor_user_roles as role_assignment
  where role_assignment.role_scope = 'anchor'::public.role_scope
    and role_assignment.role_code = 'anchor_superadmin';

  if matching_count = 0 then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: nenhum anchor_superadmin foi encontrado no DEV.';
  elsif matching_count > 1 then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: mais de um anchor_superadmin foi encontrado no DEV; a resolução de identidade é ambígua.';
  end if;

  select count(distinct membership.user_id), (array_agg(distinct membership.user_id))[1]
    into matching_count, alfa_manager_id
  from public.municipality_members as membership
  join public.municipality_member_roles as role_assignment
    on role_assignment.membership_id = membership.id
  where membership.municipality_id = alfa_id
    and membership.status = 'active'::public.membership_status
    and role_assignment.role_scope = 'municipality'::public.role_scope
    and role_assignment.role_code = 'municipality_admin';

  if matching_count = 0 then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: nenhum municipality_admin ativo foi encontrado na Prefeitura Alfa.';
  elsif matching_count > 1 then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: mais de um municipality_admin ativo foi encontrado na Prefeitura Alfa; a resolução de identidade é ambígua.';
  end if;

  select count(distinct membership.user_id), (array_agg(distinct membership.user_id))[1]
    into matching_count, beta_grants_manager_id
  from public.municipality_members as membership
  join public.municipality_member_roles as role_assignment
    on role_assignment.membership_id = membership.id
  where membership.municipality_id = beta_id
    and membership.status = 'active'::public.membership_status
    and role_assignment.role_scope = 'municipality'::public.role_scope
    and role_assignment.role_code = 'grants_manager'
    and not exists (
      select 1
      from public.municipality_members as admin_membership
      join public.municipality_member_roles as admin_role
        on admin_role.membership_id = admin_membership.id
      where admin_membership.municipality_id = beta_id
        and admin_membership.user_id = membership.user_id
        and admin_membership.status = 'active'::public.membership_status
        and admin_role.role_scope = 'municipality'::public.role_scope
        and admin_role.role_code = 'municipality_admin'
    );

  if matching_count = 0 then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: nenhum grants_manager ativo sem municipality_admin foi encontrado na Prefeitura Beta.';
  elsif matching_count > 1 then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: mais de um grants_manager ativo sem municipality_admin foi encontrado na Prefeitura Beta; a resolução de identidade é ambígua.';
  end if;

  if superadmin_id = alfa_manager_id
     or superadmin_id = beta_grants_manager_id
     or alfa_manager_id = beta_grants_manager_id then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: superadmin, municipality_admin Alfa e grants_manager Beta devem ser usuários DEV distintos.';
  end if;

  perform set_config('app.municipality_opportunity_test.superadmin_id', superadmin_id::text, true);
  perform set_config('app.municipality_opportunity_test.alfa_manager_id', alfa_manager_id::text, true);
  perform set_config('app.municipality_opportunity_test.beta_grants_manager_id', beta_grants_manager_id::text, true);
  perform set_config('app.municipality_opportunity_test.alfa_id', alfa_id::text, true);
  perform set_config('app.municipality_opportunity_test.beta_id', beta_id::text, true);
  perform set_config('app.municipality_opportunity_test.published_one_id', published_one_id::text, true);
  perform set_config('app.municipality_opportunity_test.published_two_id', published_two_id::text, true);
  perform set_config('app.municipality_opportunity_test.unpublished_id', unpublished_id::text, true);

  raise notice 'Pré-condições OK: fixtures e identidades DEV resolvidos sem UUIDs fixos.';
end;
$setup$;

-- A partir deste ponto, operações passam pelos grants e RLS do papel authenticated.
set local role authenticated;

do $tests$
declare
  superadmin_id uuid := current_setting('app.municipality_opportunity_test.superadmin_id', true)::uuid;
  alfa_manager_id uuid := current_setting('app.municipality_opportunity_test.alfa_manager_id', true)::uuid;
  beta_grants_manager_id uuid := current_setting('app.municipality_opportunity_test.beta_grants_manager_id', true)::uuid;
  alfa_id uuid := current_setting('app.municipality_opportunity_test.alfa_id', true)::uuid;
  beta_id uuid := current_setting('app.municipality_opportunity_test.beta_id', true)::uuid;
  published_one_id uuid := current_setting('app.municipality_opportunity_test.published_one_id', true)::uuid;
  published_two_id uuid := current_setting('app.municipality_opportunity_test.published_two_id', true)::uuid;
  unpublished_id uuid := current_setting('app.municipality_opportunity_test.unpublished_id', true)::uuid;
  superadmin_alfa_relation_id uuid;
  superadmin_beta_relation_id uuid;
  alfa_relation_id uuid;
  beta_relation_id uuid;
  visible_count integer;
  affected_rows integer;
  audit_before_noop integer;
  audit_after_noop integer;
begin
  -- A) Superadmin lê Alfa/Beta, cria uma relação em cada município e atualiza Alfa.
  perform set_config('request.jwt.claim.sub', superadmin_id::text, true);

  insert into public.municipality_opportunities (
    municipality_id, opportunity_id, status, notes
  ) values (
    alfa_id, published_one_id, 'analyzing', 'TESTE RLS SUPERADMIN ALFA'
  )
  returning id into superadmin_alfa_relation_id;

  insert into public.municipality_opportunities (
    municipality_id, opportunity_id, status, notes
  ) values (
    beta_id, published_one_id, 'analyzing', 'TESTE RLS SUPERADMIN BETA'
  )
  returning id into superadmin_beta_relation_id;

  select count(*) into visible_count
  from public.municipality_opportunities
  where municipality_id in (alfa_id, beta_id);

  if visible_count <> 2 then
    raise exception 'FALHA: superadmin deveria ler duas relações municipais, leu %.', visible_count;
  end if;

  update public.municipality_opportunities
     set status = 'interested',
         notes = 'TESTE RLS SUPERADMIN ALFA ATUALIZADO'
   where id = superadmin_alfa_relation_id
     and municipality_id = alfa_id;
  get diagnostics affected_rows = row_count;

  if affected_rows <> 1 then
    raise exception 'FALHA: superadmin não atualizou a relação da Alfa.';
  end if;

  -- B) Oportunidade não publicada, UNIQUE, DELETE e IDs imutáveis devem falhar.
  begin
    insert into public.municipality_opportunities (
      municipality_id, opportunity_id, status, notes
    ) values (
      alfa_id, unpublished_id, 'analyzing', 'TESTE BLOQUEIO NÃO PUBLICADA SUPERADMIN'
    );
    raise exception 'FALHA: superadmin vinculou oportunidade não publicada.';
  exception
    when insufficient_privilege then
      raise notice 'OK: oportunidade não publicada foi bloqueada por RLS.';
  end;

  begin
    insert into public.municipality_opportunities (
      municipality_id, opportunity_id, status, notes
    ) values (
      alfa_id, published_one_id, 'analyzing', 'TESTE UNIQUE SUPERADMIN'
    );
    raise exception 'FALHA: UNIQUE permitiu relação municipal duplicada.';
  exception
    when unique_violation then
      raise notice 'OK: UNIQUE bloqueou relação municipal duplicada.';
  end;

  begin
    update public.municipality_opportunities
       set municipality_id = beta_id
     where id = superadmin_alfa_relation_id
       and municipality_id = alfa_id;
    raise exception 'FALHA: UPDATE de municipality_id foi permitido.';
  exception
    when insufficient_privilege then
      raise notice 'OK: municipality_id permaneceu imutável por privilégio de coluna.';
  end;

  begin
    update public.municipality_opportunities
       set opportunity_id = published_two_id
     where id = superadmin_alfa_relation_id
       and municipality_id = alfa_id;
    raise exception 'FALHA: UPDATE de opportunity_id foi permitido.';
  exception
    when insufficient_privilege then
      raise notice 'OK: opportunity_id permaneceu imutável por privilégio de coluna.';
  end;

  begin
    delete from public.municipality_opportunities
    where id = superadmin_alfa_relation_id;
    raise exception 'FALHA: DELETE foi permitido para authenticated.';
  exception
    when insufficient_privilege then
      raise notice 'OK: DELETE foi bloqueado por grants/RLS.';
  end;

  -- C) Municipality_admin Alfa enxerga Alfa, não enxerga Beta e não escreve na Beta.
  perform set_config('request.jwt.claim.sub', alfa_manager_id::text, true);

  select count(*) into visible_count
  from public.municipality_opportunities
  where municipality_id = alfa_id;
  if visible_count <> 1 then
    raise exception 'FALHA: municipality_admin Alfa deveria ler uma relação da Alfa, leu %.', visible_count;
  end if;

  select count(*) into visible_count
  from public.municipality_opportunities
  where municipality_id = beta_id;
  if visible_count <> 0 then
    raise exception 'FALHA: municipality_admin Alfa leu relação da Beta.';
  end if;

  begin
    insert into public.municipality_opportunities (
      municipality_id, opportunity_id, status, notes
    ) values (
      beta_id, published_two_id, 'analyzing', 'TESTE BLOQUEIO ALFA PARA BETA'
    );
    raise exception 'FALHA: municipality_admin Alfa inseriu relação na Beta.';
  exception
    when insufficient_privilege then
      raise notice 'OK: municipality_admin Alfa não inseriu relação na Beta.';
  end;

  begin
    insert into public.municipality_opportunities (
      municipality_id, opportunity_id, status, notes
    ) values (
      alfa_id, unpublished_id, 'analyzing', 'TESTE NÃO PUBLICADA ALFA'
    );
    raise exception 'FALHA: municipality_admin Alfa vinculou oportunidade não publicada.';
  exception
    when insufficient_privilege then
      raise notice 'OK: municipality_admin Alfa foi bloqueado para oportunidade não publicada.';
  end;

  update public.municipality_opportunities
     set notes = 'TESTE ALTERAÇÃO CRUZADA ALFA PARA BETA'
   where id = superadmin_beta_relation_id
     and municipality_id = beta_id;
  get diagnostics affected_rows = row_count;
  if affected_rows <> 0 then
    raise exception 'FALHA: municipality_admin Alfa atualizou relação da Beta.';
  end if;

  -- D) Grants_manager Beta tem escrita operacional somente no próprio município.
  perform set_config('request.jwt.claim.sub', beta_grants_manager_id::text, true);

  select count(*) into visible_count
  from public.municipality_opportunities
  where municipality_id = beta_id;
  if visible_count <> 1 then
    raise exception 'FALHA: grants_manager Beta deveria ler uma relação da Beta, leu %.', visible_count;
  end if;

  select count(*) into visible_count
  from public.municipality_opportunities
  where municipality_id = alfa_id;
  if visible_count <> 0 then
    raise exception 'FALHA: grants_manager Beta leu relação da Alfa.';
  end if;

  begin
    insert into public.municipality_opportunities (
      municipality_id, opportunity_id, status, notes
    ) values (
      alfa_id, published_two_id, 'analyzing', 'TESTE BLOQUEIO BETA PARA ALFA'
    );
    raise exception 'FALHA: grants_manager Beta inseriu relação na Alfa.';
  exception
    when insufficient_privilege then
      raise notice 'OK: grants_manager Beta não inseriu relação na Alfa.';
  end;

  begin
    insert into public.municipality_opportunities (
      municipality_id, opportunity_id, status, notes
    ) values (
      beta_id, unpublished_id, 'analyzing', 'TESTE NÃO PUBLICADA BETA'
    );
    raise exception 'FALHA: grants_manager Beta vinculou oportunidade não publicada.';
  exception
    when insufficient_privilege then
      raise notice 'OK: grants_manager Beta foi bloqueado para oportunidade não publicada.';
  end;

  update public.municipality_opportunities
     set notes = 'TESTE ALTERAÇÃO CRUZADA BETA PARA ALFA'
   where id = superadmin_alfa_relation_id
     and municipality_id = alfa_id;
  get diagnostics affected_rows = row_count;
  if affected_rows <> 0 then
    raise exception 'FALHA: grants_manager Beta atualizou relação da Alfa.';
  end if;

  -- E) Os dois gestores inserem e atualizam somente as próprias relações com a
  -- segunda oportunidade publicada, reservada para evitar colisões entre testes.
  perform set_config('request.jwt.claim.sub', alfa_manager_id::text, true);

  insert into public.municipality_opportunities (
    municipality_id, opportunity_id, status, notes
  ) values (
    alfa_id, published_two_id, 'review_later', 'TESTE INSERT MUNICIPALITY_ADMIN ALFA'
  )
  returning id into alfa_relation_id;

  update public.municipality_opportunities
     set status = 'interested',
         notes = 'TESTE UPDATE MUNICIPALITY_ADMIN ALFA'
   where id = alfa_relation_id
     and municipality_id = alfa_id;
  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'FALHA: municipality_admin Alfa não atualizou a própria relação.';
  end if;

  begin
    update public.municipality_opportunities
       set municipality_id = beta_id
     where id = alfa_relation_id
       and municipality_id = alfa_id;
    raise exception 'FALHA: municipality_admin Alfa atualizou municipality_id.';
  exception
    when insufficient_privilege then
      raise notice 'OK: municipality_admin Alfa não atualizou municipality_id por privilégio de coluna.';
  end;

  begin
    update public.municipality_opportunities
       set opportunity_id = published_one_id
     where id = alfa_relation_id
       and municipality_id = alfa_id;
    raise exception 'FALHA: municipality_admin Alfa atualizou opportunity_id.';
  exception
    when insufficient_privilege then
      raise notice 'OK: municipality_admin Alfa não atualizou opportunity_id por privilégio de coluna.';
  end;

  begin
    delete from public.municipality_opportunities
    where id = alfa_relation_id
      and municipality_id = alfa_id;
    raise exception 'FALHA: DELETE foi permitido para municipality_admin Alfa.';
  exception
    when insufficient_privilege then
      raise notice 'OK: DELETE foi bloqueado para municipality_admin Alfa.';
  end;

  perform set_config('request.jwt.claim.sub', beta_grants_manager_id::text, true);

  insert into public.municipality_opportunities (
    municipality_id, opportunity_id, status, notes
  ) values (
    beta_id, published_two_id, 'review_later', 'TESTE INSERT GRANTS_MANAGER BETA'
  )
  returning id into beta_relation_id;

  update public.municipality_opportunities
     set status = 'interested',
         notes = 'TESTE UPDATE GRANTS_MANAGER BETA'
   where id = beta_relation_id
     and municipality_id = beta_id;
  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'FALHA: grants_manager Beta não atualizou a própria relação.';
  end if;

  begin
    update public.municipality_opportunities
       set municipality_id = alfa_id
     where id = beta_relation_id
       and municipality_id = beta_id;
    raise exception 'FALHA: grants_manager Beta atualizou municipality_id.';
  exception
    when insufficient_privilege then
      raise notice 'OK: grants_manager Beta não atualizou municipality_id por privilégio de coluna.';
  end;

  begin
    update public.municipality_opportunities
       set opportunity_id = published_one_id
     where id = beta_relation_id
       and municipality_id = beta_id;
    raise exception 'FALHA: grants_manager Beta atualizou opportunity_id.';
  exception
    when insufficient_privilege then
      raise notice 'OK: grants_manager Beta não atualizou opportunity_id por privilégio de coluna.';
  end;

  begin
    delete from public.municipality_opportunities
    where id = beta_relation_id
      and municipality_id = beta_id;
    raise exception 'FALHA: DELETE foi permitido para grants_manager Beta.';
  exception
    when insufficient_privilege then
      raise notice 'OK: DELETE foi bloqueado para grants_manager Beta.';
  end;

  -- F) Cada município continua vendo apenas suas próprias linhas e auditorias.
  perform set_config('request.jwt.claim.sub', alfa_manager_id::text, true);

  select count(*) into visible_count
  from public.municipality_opportunities
  where municipality_id = alfa_id;
  if visible_count <> 2 then
    raise exception 'FALHA: municipality_admin Alfa deveria ler duas relações próprias, leu %.', visible_count;
  end if;

  select count(*) into visible_count
  from public.municipality_opportunity_audit
  where municipality_id = alfa_id;
  if visible_count <> 4 then
    raise exception 'FALHA: municipality_admin Alfa deveria ler quatro eventos próprios, leu %.', visible_count;
  end if;

  select count(*) into visible_count
  from public.municipality_opportunity_audit
  where municipality_id = beta_id;
  if visible_count <> 0 then
    raise exception 'FALHA: municipality_admin Alfa leu auditoria da Beta.';
  end if;

  perform set_config('request.jwt.claim.sub', beta_grants_manager_id::text, true);

  select count(*) into visible_count
  from public.municipality_opportunities
  where municipality_id = beta_id;
  if visible_count <> 2 then
    raise exception 'FALHA: grants_manager Beta deveria ler duas relações próprias, leu %.', visible_count;
  end if;

  select count(*) into visible_count
  from public.municipality_opportunity_audit
  where municipality_id = beta_id;
  if visible_count <> 3 then
    raise exception 'FALHA: grants_manager Beta deveria ler três eventos próprios, leu %.', visible_count;
  end if;

  select count(*) into visible_count
  from public.municipality_opportunity_audit
  where municipality_id = alfa_id;
  if visible_count <> 0 then
    raise exception 'FALHA: grants_manager Beta leu auditoria da Alfa.';
  end if;

  -- G) Superadmin valida auditoria completa, no-op e bloqueio de escrita direta.
  perform set_config('request.jwt.claim.sub', superadmin_id::text, true);

  select count(*) into visible_count
  from public.municipality_opportunities
  where municipality_id in (alfa_id, beta_id);
  if visible_count <> 4 then
    raise exception 'FALHA: superadmin deveria ler quatro relações, leu %.', visible_count;
  end if;

  select count(*) into visible_count
  from public.municipality_opportunity_audit;
  if visible_count <> 7 then
    raise exception 'FALHA: auditoria deveria possuir sete eventos antes do no-op, possui %.', visible_count;
  end if;

  if (select count(*) from public.municipality_opportunity_audit where action = 'insert') <> 4
     or (select count(*) from public.municipality_opportunity_audit where action = 'update') <> 3 then
    raise exception 'FALHA: auditoria não possui a distribuição esperada de INSERT/UPDATE.';
  end if;

  if exists (
    select 1
    from public.municipality_opportunity_audit as audit
    where (audit.action = 'insert' and (audit.old_data is not null or audit.new_data is null))
       or (audit.action = 'update' and (audit.old_data is null or audit.new_data is null))
       or audit.actor_user_id is null
       or audit.municipality_opportunity_id is null
       or audit.municipality_id is null
       or audit.opportunity_id is null
  ) then
    raise exception 'FALHA: auditoria não preservou ator, relação, município, oportunidade ou payloads esperados.';
  end if;

  if (select count(*) from public.municipality_opportunity_audit where actor_user_id = superadmin_id) <> 3
     or (select count(*) from public.municipality_opportunity_audit where actor_user_id = alfa_manager_id) <> 2
     or (select count(*) from public.municipality_opportunity_audit where actor_user_id = beta_grants_manager_id) <> 2 then
    raise exception 'FALHA: auditoria não atribuiu os eventos aos três atores esperados.';
  end if;

  select count(*) into audit_before_noop
  from public.municipality_opportunity_audit;

  update public.municipality_opportunities
     set status = 'interested',
         notes = 'TESTE RLS SUPERADMIN ALFA ATUALIZADO'
   where id = superadmin_alfa_relation_id
     and municipality_id = alfa_id;
  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'FALHA: UPDATE sem mudança não encontrou a relação do superadmin.';
  end if;

  select count(*) into audit_after_noop
  from public.municipality_opportunity_audit;
  if audit_after_noop <> audit_before_noop then
    raise exception 'FALHA: UPDATE sem mudança criou evento de auditoria.';
  end if;

  begin
    insert into public.municipality_opportunity_audit (
      municipality_opportunity_id,
      municipality_id,
      opportunity_id,
      action,
      actor_user_id,
      old_data,
      new_data
    ) values (
      superadmin_alfa_relation_id,
      alfa_id,
      published_one_id,
      'insert',
      superadmin_id,
      null,
      jsonb_build_object('source', 'teste direto bloqueado')
    );
    raise exception 'FALHA: authenticated inseriu diretamente na auditoria.';
  exception
    when insufficient_privilege then
      raise notice 'OK: escrita direta na auditoria foi bloqueada.';
  end;

  raise notice 'SUCESSO: superadmin, municipality_admin Alfa e grants_manager Beta validaram RLS, grants, isolamento, UNIQUE, publicação, auditoria, DELETE e imutabilidade de IDs.';
end;
$tests$;

rollback;

select
  'PASSOU' as status,
  'Todos os testes críticos de RLS da Etapa 20.3 passaram e o ROLLBACK preservou o DEV.' as mensagem;