-- SOMENTE DEV — teste transacional dos cenários municipal read-only e anchor_operator.
-- Requer os fixtures globais ANCHOR_DEV_TEST e não deve ser executado em PROD.
-- As relações, auditorias, papéis, memberships e assignments temporários são revertidos por ROLLBACK.

begin;

-- A) Pré-condições e resolução inequívoca dos fixtures e atores existentes.
do $preflight$
declare
  matching_count integer;
  membership_count integer;
  fixture_source_id uuid;
  alfa_id uuid;
  beta_id uuid;
  superadmin_id uuid;
  beta_actor_id uuid;
  beta_membership_id uuid;
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
      ('public.app_roles'),
      ('public.anchor_user_roles'),
      ('public.anchor_municipality_assignments')
    ) as required_table(qualified_name)
    where pg_catalog.to_regclass(required_table.qualified_name) is null
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: tabelas esperadas da fundação global e multi-tenant não existem no DEV.';
  end if;

  if exists (select 1 from public.municipality_opportunities)
     or exists (select 1 from public.municipality_opportunity_audit) then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: relações municipais ou auditorias já possuem dados. Revise o DEV antes de executar.';
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

  select count(*) into matching_count
  from public.opportunities as opportunity
  where opportunity.source_id = fixture_source_id;

  if matching_count <> 3 then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: ANCHOR_DEV_TEST deve possuir exatamente as três oportunidades canônicas e nenhuma adicional.';
  end if;

  select opportunity.id into published_one_id
  from public.opportunities as opportunity
  where opportunity.source_id = fixture_source_id
    and opportunity.external_id = 'OPP_DEV_PUBLISHED_001'
    and opportunity.is_published = true
    and opportunity.status = 'open';

  select opportunity.id into published_two_id
  from public.opportunities as opportunity
  where opportunity.source_id = fixture_source_id
    and opportunity.external_id = 'OPP_DEV_PUBLISHED_002'
    and opportunity.is_published = true
    and opportunity.status = 'open';

  select opportunity.id into unpublished_id
  from public.opportunities as opportunity
  where opportunity.source_id = fixture_source_id
    and opportunity.external_id = 'OPP_DEV_UNPUBLISHED_001'
    and opportunity.is_published = false
    and opportunity.status = 'open';

  if published_one_id is null or published_two_id is null or unpublished_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: os três fixtures globais não estão no estado canônico true/true/false e open.';
  end if;

  select count(*), (array_agg(municipality.id order by municipality.id))[1]
    into matching_count, alfa_id
  from public.municipalities as municipality
  where lower(btrim(municipality.name)) = lower('Prefeitura Alfa')
    and municipality.state = 'SP'
    and municipality.status = 'active'::public.municipality_status;

  if matching_count = 0 then
    raise exception using errcode = 'P0001', message = 'Teste cancelado: nenhuma Prefeitura Alfa ativa em SP foi encontrada.';
  elsif matching_count > 1 then
    raise exception using errcode = 'P0001', message = 'Teste cancelado: mais de uma Prefeitura Alfa ativa em SP foi encontrada.';
  end if;

  select count(*), (array_agg(municipality.id order by municipality.id))[1]
    into matching_count, beta_id
  from public.municipalities as municipality
  where lower(btrim(municipality.name)) = lower('Prefeitura Beta')
    and municipality.state = 'SP'
    and municipality.status = 'active'::public.municipality_status;

  if matching_count = 0 then
    raise exception using errcode = 'P0001', message = 'Teste cancelado: nenhuma Prefeitura Beta ativa em SP foi encontrada.';
  elsif matching_count > 1 then
    raise exception using errcode = 'P0001', message = 'Teste cancelado: mais de uma Prefeitura Beta ativa em SP foi encontrada.';
  end if;

  if alfa_id = beta_id then
    raise exception using errcode = 'P0001', message = 'Teste cancelado: Alfa e Beta resolveram para o mesmo município.';
  end if;

  select count(distinct role_assignment.user_id), (array_agg(distinct role_assignment.user_id))[1]
    into matching_count, superadmin_id
  from public.anchor_user_roles as role_assignment
  where role_assignment.role_scope = 'anchor'::public.role_scope
    and role_assignment.role_code = 'anchor_superadmin';

  if matching_count = 0 then
    raise exception using errcode = 'P0001', message = 'Teste cancelado: nenhum anchor_superadmin foi encontrado no DEV.';
  elsif matching_count > 1 then
    raise exception using errcode = 'P0001', message = 'Teste cancelado: mais de um anchor_superadmin foi encontrado no DEV.';
  end if;

  select
    count(distinct membership.user_id),
    (array_agg(distinct membership.user_id))[1],
    count(distinct membership.id),
    (array_agg(distinct membership.id))[1]
  into matching_count, beta_actor_id, membership_count, beta_membership_id
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

  if matching_count = 0 or membership_count = 0 then
    raise exception using errcode = 'P0001', message = 'Teste cancelado: nenhum grants_manager Beta ativo sem municipality_admin foi encontrado.';
  elsif matching_count > 1 or membership_count > 1 then
    raise exception using errcode = 'P0001', message = 'Teste cancelado: o ator grants_manager Beta ou sua membership não é inequívoco.';
  end if;

  if beta_actor_id = superadmin_id then
    raise exception using errcode = 'P0001', message = 'Teste cancelado: o ator Beta não pode ser o superadmin.';
  end if;

  if exists (
    select 1
    from public.municipality_members as membership
    where membership.user_id = beta_actor_id
      and membership.status = 'active'::public.membership_status
      and membership.municipality_id <> beta_id
  ) then
    raise exception using errcode = 'P0001', message = 'Teste cancelado: o ator Beta possui membership ativa em outro município.';
  end if;

  if exists (
    select 1
    from public.anchor_user_roles as role_assignment
    where role_assignment.user_id = beta_actor_id
  ) then
    raise exception using errcode = 'P0001', message = 'Teste cancelado: o ator Beta já possui papel global da Âncora.';
  end if;

  if exists (
    select 1
    from public.anchor_municipality_assignments as assignment
    where assignment.anchor_user_id = beta_actor_id
  ) then
    raise exception using errcode = 'P0001', message = 'Teste cancelado: o ator Beta já possui assignment Âncora; não amplie acesso existente.';
  end if;

  if not exists (
    select 1
    from public.app_roles as app_role
    where app_role.scope = 'municipality'::public.role_scope
      and app_role.code = 'auditor'
  ) or not exists (
    select 1
    from public.app_roles as app_role
    where app_role.scope = 'anchor'::public.role_scope
      and app_role.code = 'anchor_operator'
  ) then
    raise exception using errcode = 'P0001', message = 'Teste cancelado: os papéis auditor e anchor_operator devem existir no catálogo.';
  end if;

  perform set_config('app.municipality_opportunity_pending_test.superadmin_id', superadmin_id::text, true);
  perform set_config('app.municipality_opportunity_pending_test.beta_actor_id', beta_actor_id::text, true);
  perform set_config('app.municipality_opportunity_pending_test.beta_membership_id', beta_membership_id::text, true);
  perform set_config('app.municipality_opportunity_pending_test.alfa_id', alfa_id::text, true);
  perform set_config('app.municipality_opportunity_pending_test.beta_id', beta_id::text, true);
  perform set_config('app.municipality_opportunity_pending_test.published_one_id', published_one_id::text, true);
  perform set_config('app.municipality_opportunity_pending_test.published_two_id', published_two_id::text, true);
  perform set_config('app.municipality_opportunity_pending_test.unpublished_id', unpublished_id::text, true);
end;
$preflight$;

-- B) O superadmin simulado cria relações temporárias para que os dois cenários leiam dados reais sob RLS.
set local role authenticated;

do $seed_relations$
declare
  superadmin_id uuid := current_setting('app.municipality_opportunity_pending_test.superadmin_id', true)::uuid;
  alfa_id uuid := current_setting('app.municipality_opportunity_pending_test.alfa_id', true)::uuid;
  beta_id uuid := current_setting('app.municipality_opportunity_pending_test.beta_id', true)::uuid;
  published_one_id uuid := current_setting('app.municipality_opportunity_pending_test.published_one_id', true)::uuid;
  alfa_relation_id uuid;
  beta_relation_id uuid;
begin
  perform set_config('request.jwt.claim.sub', superadmin_id::text, true);

  insert into public.municipality_opportunities (municipality_id, opportunity_id, status, notes)
  values (alfa_id, published_one_id, 'analyzing', 'TESTE PENDENTE SEED ALFA')
  returning id into alfa_relation_id;

  insert into public.municipality_opportunities (municipality_id, opportunity_id, status, notes)
  values (beta_id, published_one_id, 'analyzing', 'TESTE PENDENTE SEED BETA')
  returning id into beta_relation_id;

  perform set_config('app.municipality_opportunity_pending_test.alfa_relation_id', alfa_relation_id::text, true);
  perform set_config('app.municipality_opportunity_pending_test.beta_relation_id', beta_relation_id::text, true);
end;
$seed_relations$;

reset role;

-- C) Fixture municipal read-only: a membership Beta continua ativa, mas todos os seus papéis são temporariamente substituídos por auditor.
do $prepare_readonly_fixture$
declare
  beta_membership_id uuid := current_setting('app.municipality_opportunity_pending_test.beta_membership_id', true)::uuid;
  superadmin_id uuid := current_setting('app.municipality_opportunity_pending_test.superadmin_id', true)::uuid;
  affected_rows integer;
begin
  delete from public.municipality_member_roles
  where membership_id = beta_membership_id;
  get diagnostics affected_rows = row_count;

  if affected_rows = 0 then
    raise exception using errcode = 'P0001', message = 'Teste cancelado: não foi possível remover temporariamente os papéis municipais do ator Beta.';
  end if;

  insert into public.municipality_member_roles (membership_id, role_scope, role_code, assigned_by)
  values (beta_membership_id, 'municipality'::public.role_scope, 'auditor', superadmin_id);
end;
$prepare_readonly_fixture$;

set local role authenticated;

do $readonly_tests$
declare
  beta_actor_id uuid := current_setting('app.municipality_opportunity_pending_test.beta_actor_id', true)::uuid;
  alfa_id uuid := current_setting('app.municipality_opportunity_pending_test.alfa_id', true)::uuid;
  beta_id uuid := current_setting('app.municipality_opportunity_pending_test.beta_id', true)::uuid;
  published_two_id uuid := current_setting('app.municipality_opportunity_pending_test.published_two_id', true)::uuid;
  alfa_relation_id uuid := current_setting('app.municipality_opportunity_pending_test.alfa_relation_id', true)::uuid;
  beta_relation_id uuid := current_setting('app.municipality_opportunity_pending_test.beta_relation_id', true)::uuid;
  visible_count integer;
  affected_rows integer;
begin
  perform set_config('request.jwt.claim.sub', beta_actor_id::text, true);

  select count(*) into visible_count
  from public.municipality_opportunities
  where id = beta_relation_id and municipality_id = beta_id;
  if visible_count <> 1 then
    raise exception 'FALHA: auditor Beta deveria ler a relação temporária da própria Beta.';
  end if;

  select count(*) into visible_count
  from public.municipality_opportunities
  where id = alfa_relation_id and municipality_id = alfa_id;
  if visible_count <> 0 then
    raise exception 'FALHA: auditor Beta leu relação temporária da Alfa.';
  end if;

  begin
    insert into public.municipality_opportunities (municipality_id, opportunity_id, status, notes)
    values (beta_id, published_two_id, 'analyzing', 'TESTE BLOQUEIO AUDITOR BETA INSERT');
    raise exception 'FALHA: auditor Beta inseriu relação municipal.';
  exception
    when insufficient_privilege then
      raise notice 'OK: auditor Beta não inseriu relação municipal.';
  end;

  update public.municipality_opportunities
     set notes = 'TESTE BLOQUEIO AUDITOR BETA UPDATE'
   where id = beta_relation_id and municipality_id = beta_id;
  get diagnostics affected_rows = row_count;
  if affected_rows <> 0 then
    raise exception 'FALHA: auditor Beta atualizou a própria relação.';
  end if;

  begin
    delete from public.municipality_opportunities
    where id = beta_relation_id and municipality_id = beta_id;
    raise exception 'FALHA: DELETE foi permitido para auditor Beta.';
  exception
    when insufficient_privilege then
      raise notice 'OK: DELETE foi bloqueado para auditor Beta.';
  end;

  select count(*) into visible_count
  from public.municipality_opportunity_audit
  where municipality_id = beta_id;
  if visible_count <> 1 then
    raise exception 'FALHA: auditor Beta deveria ler uma auditoria temporária da Beta, leu %.', visible_count;
  end if;

  select count(*) into visible_count
  from public.municipality_opportunity_audit
  where municipality_id = alfa_id;
  if visible_count <> 0 then
    raise exception 'FALHA: auditor Beta leu auditoria temporária da Alfa.';
  end if;

  begin
    insert into public.municipality_opportunity_audit (
      municipality_opportunity_id, municipality_id, opportunity_id, action, actor_user_id, old_data, new_data
    ) values (
      beta_relation_id, beta_id, published_two_id, 'insert', beta_actor_id, null,
      jsonb_build_object('scenario', 'auditor direto bloqueado')
    );
    raise exception 'FALHA: auditor Beta inseriu diretamente na auditoria.';
  exception
    when insufficient_privilege then
      raise notice 'OK: escrita direta na auditoria foi bloqueada para auditor Beta.';
  end;
end;
$readonly_tests$;

reset role;

-- D) Fixture anchor_operator: neutraliza a membership municipal e cria somente o assignment válido e aprovado para Alfa.
do $prepare_operator_fixture$
declare
  beta_actor_id uuid := current_setting('app.municipality_opportunity_pending_test.beta_actor_id', true)::uuid;
  beta_membership_id uuid := current_setting('app.municipality_opportunity_pending_test.beta_membership_id', true)::uuid;
  superadmin_id uuid := current_setting('app.municipality_opportunity_pending_test.superadmin_id', true)::uuid;
  alfa_id uuid := current_setting('app.municipality_opportunity_pending_test.alfa_id', true)::uuid;
  beta_id uuid := current_setting('app.municipality_opportunity_pending_test.beta_id', true)::uuid;
  valid_assignment_id uuid;

  affected_rows integer;
begin
  update public.municipality_members
     set status = 'suspended'::public.membership_status,
         deactivated_at = now()
   where id = beta_membership_id
     and user_id = beta_actor_id
     and status = 'active'::public.membership_status;
  get diagnostics affected_rows = row_count;

  if affected_rows <> 1 then
    raise exception using errcode = 'P0001', message = 'Teste cancelado: a membership Beta não foi neutralizada para o cenário anchor_operator.';
  end if;

  insert into public.anchor_user_roles (user_id, role_scope, role_code, assigned_by)
  values (beta_actor_id, 'anchor'::public.role_scope, 'anchor_operator', superadmin_id);

  insert into public.anchor_municipality_assignments (
    anchor_user_id, municipality_id, access_level, status, starts_at, expires_at,
    justification, assigned_by, approved_by, approved_at
  ) values (
    beta_actor_id, alfa_id, 'read_only'::public.anchor_assignment_access_level,
    'active'::public.anchor_assignment_status, now() - interval '1 hour', null,
    'Teste DEV: acesso read-only temporário do anchor_operator à Prefeitura Alfa.',
    superadmin_id, superadmin_id, now()
  ) returning id into valid_assignment_id;


  perform set_config('app.municipality_opportunity_pending_test.valid_assignment_id', valid_assignment_id::text, true);

end;
$prepare_operator_fixture$;

set local role authenticated;

do $operator_valid_tests$
declare
  beta_actor_id uuid := current_setting('app.municipality_opportunity_pending_test.beta_actor_id', true)::uuid;
  alfa_id uuid := current_setting('app.municipality_opportunity_pending_test.alfa_id', true)::uuid;
  beta_id uuid := current_setting('app.municipality_opportunity_pending_test.beta_id', true)::uuid;
  published_two_id uuid := current_setting('app.municipality_opportunity_pending_test.published_two_id', true)::uuid;
  alfa_relation_id uuid := current_setting('app.municipality_opportunity_pending_test.alfa_relation_id', true)::uuid;
  beta_relation_id uuid := current_setting('app.municipality_opportunity_pending_test.beta_relation_id', true)::uuid;
  visible_count integer;
  affected_rows integer;
begin
  perform set_config('request.jwt.claim.sub', beta_actor_id::text, true);

  select count(*) into visible_count
  from public.municipality_opportunities
  where id = alfa_relation_id and municipality_id = alfa_id;
  if visible_count <> 1 then
    raise exception 'FALHA: anchor_operator deveria ler a relação temporária da Alfa por assignment válido.';
  end if;

  select count(*) into visible_count
  from public.municipality_opportunities
  where id = beta_relation_id and municipality_id = beta_id;
  if visible_count <> 0 then
    raise exception 'FALHA: anchor_operator leu a relação temporária da Beta sem assignment válido.';
  end if;

  begin
    insert into public.municipality_opportunities (municipality_id, opportunity_id, status, notes)
    values (alfa_id, published_two_id, 'analyzing', 'TESTE BLOQUEIO ANCHOR_OPERATOR INSERT');
    raise exception 'FALHA: anchor_operator inseriu relação na Alfa.';
  exception
    when insufficient_privilege then
      raise notice 'OK: anchor_operator não inseriu relação na Alfa.';
  end;

  update public.municipality_opportunities
     set notes = 'TESTE BLOQUEIO ANCHOR_OPERATOR UPDATE'
   where id = alfa_relation_id and municipality_id = alfa_id;
  get diagnostics affected_rows = row_count;
  if affected_rows <> 0 then
    raise exception 'FALHA: anchor_operator atualizou relação na Alfa.';
  end if;

  begin
    delete from public.municipality_opportunities
    where id = alfa_relation_id and municipality_id = alfa_id;
    raise exception 'FALHA: DELETE foi permitido para anchor_operator.';
  exception
    when insufficient_privilege then
      raise notice 'OK: DELETE foi bloqueado para anchor_operator.';
  end;

  select count(*) into visible_count
  from public.municipality_opportunity_audit
  where municipality_id = alfa_id;
  if visible_count <> 1 then
    raise exception 'FALHA: anchor_operator deveria ler uma auditoria temporária da Alfa, leu %.', visible_count;
  end if;

  select count(*) into visible_count
  from public.municipality_opportunity_audit
  where municipality_id = beta_id;
  if visible_count <> 0 then
    raise exception 'FALHA: anchor_operator leu auditoria temporária da Beta.';
  end if;

  begin
    insert into public.municipality_opportunity_audit (
      municipality_opportunity_id, municipality_id, opportunity_id, action, actor_user_id, old_data, new_data
    ) values (
      alfa_relation_id, alfa_id, published_two_id, 'insert', beta_actor_id, null,
      jsonb_build_object('scenario', 'operator direto bloqueado')
    );
    raise exception 'FALHA: anchor_operator inseriu diretamente na auditoria.';
  exception
    when insufficient_privilege then
      raise notice 'OK: escrita direta na auditoria foi bloqueada para anchor_operator.';
  end;
end;
$operator_valid_tests$;

reset role;

-- E) Expira o único assignment Alfa antes de confirmar que um assignment inválido não mantém leitura nem escrita.
do $expire_valid_assignment$
declare
  valid_assignment_id uuid := current_setting('app.municipality_opportunity_pending_test.valid_assignment_id', true)::uuid;
  affected_rows integer;
begin
  update public.anchor_municipality_assignments
     set expires_at = now() - interval '1 minute'
   where id = valid_assignment_id
     and status = 'active'::public.anchor_assignment_status;
  get diagnostics affected_rows = row_count;

  if affected_rows <> 1 then
    raise exception using errcode = 'P0001', message = 'Teste cancelado: não foi possível expirar o assignment válido da Alfa.';
  end if;
end;
$expire_valid_assignment$;

set local role authenticated;

do $operator_expired_tests$
declare
  beta_actor_id uuid := current_setting('app.municipality_opportunity_pending_test.beta_actor_id', true)::uuid;
  alfa_id uuid := current_setting('app.municipality_opportunity_pending_test.alfa_id', true)::uuid;
  beta_id uuid := current_setting('app.municipality_opportunity_pending_test.beta_id', true)::uuid;
  published_two_id uuid := current_setting('app.municipality_opportunity_pending_test.published_two_id', true)::uuid;
  alfa_relation_id uuid := current_setting('app.municipality_opportunity_pending_test.alfa_relation_id', true)::uuid;
  beta_relation_id uuid := current_setting('app.municipality_opportunity_pending_test.beta_relation_id', true)::uuid;
  visible_count integer;
  affected_rows integer;
begin
  perform set_config('request.jwt.claim.sub', beta_actor_id::text, true);

  select count(*) into visible_count
  from public.municipality_opportunities
  where id = alfa_relation_id and municipality_id = alfa_id;
  if visible_count <> 0 then
    raise exception 'FALHA: assignment expirado ainda concedeu leitura da Alfa.';
  end if;

  select count(*) into visible_count
  from public.municipality_opportunities
  where id = beta_relation_id and municipality_id = beta_id;
  if visible_count <> 0 then
    raise exception 'FALHA: assignment expirado da Beta concedeu leitura da Beta.';
  end if;

  select count(*) into visible_count
  from public.municipality_opportunity_audit
  where municipality_id = alfa_id;
  if visible_count <> 0 then
    raise exception 'FALHA: assignment expirado ainda concedeu leitura da auditoria Alfa.';
  end if;

  select count(*) into visible_count
  from public.municipality_opportunity_audit
  where municipality_id = beta_id;
  if visible_count <> 0 then
    raise exception 'FALHA: assignment expirado concedeu leitura da auditoria Beta.';
  end if;

  begin
    insert into public.municipality_opportunities (municipality_id, opportunity_id, status, notes)
    values (alfa_id, published_two_id, 'analyzing', 'TESTE BLOQUEIO OPERATOR EXPIRADO INSERT');
    raise exception 'FALHA: anchor_operator com assignment expirado inseriu relação na Alfa.';
  exception
    when insufficient_privilege then
      raise notice 'OK: anchor_operator com assignment expirado não inseriu relação.';
  end;

  update public.municipality_opportunities
     set notes = 'TESTE BLOQUEIO OPERATOR EXPIRADO UPDATE'
   where id = alfa_relation_id and municipality_id = alfa_id;
  get diagnostics affected_rows = row_count;
  if affected_rows <> 0 then
    raise exception 'FALHA: anchor_operator com assignment expirado atualizou relação.';
  end if;

  begin
    delete from public.municipality_opportunities
    where id = alfa_relation_id and municipality_id = alfa_id;
    raise exception 'FALHA: DELETE foi permitido para anchor_operator com assignment expirado.';
  exception
    when insufficient_privilege then
      raise notice 'OK: DELETE permaneceu bloqueado para anchor_operator com assignment expirado.';
  end;
end;
$operator_expired_tests$;

rollback;

select
  'PASSOU' as status,
  'Os cenários municipal read-only e anchor_operator passaram, e o ROLLBACK preservou o DEV.' as mensagem;