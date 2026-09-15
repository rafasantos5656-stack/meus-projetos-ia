-- DEV ONLY — teste transacional de escrita controlada do Perfil e Capacidade.
-- Execute somente no SQL Editor administrativo do Supabase DEV.
-- O teste simula RLS com SET LOCAL ROLE authenticated e request.jwt.claim.sub.
-- Nenhuma credencial, token de sessão ou UUID fixo é usado. O script termina em ROLLBACK.

begin;

-- Resolve identidades e dependências por papéis e dados estáveis já existentes.
-- O teste é cancelado antes de qualquer escrita caso o ambiente seja ambíguo.
do $setup$
declare
  superadmin_id uuid;
  alfa_admin_id uuid;
  beta_read_only_id uuid;
  alfa_id uuid;
  beta_id uuid;
  alfa_department_id uuid;
  beta_department_id uuid;
  matching_count integer;
begin
  select count(distinct role_assignment.user_id), (array_agg(distinct role_assignment.user_id))[1]
    into matching_count, superadmin_id
  from public.anchor_user_roles as role_assignment
  where role_assignment.role_scope = 'anchor'::public.role_scope
    and role_assignment.role_code = 'anchor_superadmin';

  if matching_count <> 1 then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: deve existir exatamente um anchor_superadmin no DEV.';
  end if;

  select municipality.id
    into alfa_id
  from public.municipalities as municipality
  where lower(btrim(municipality.name)) = lower('Prefeitura Alfa')
    and municipality.state = 'SP'
  order by municipality.created_at, municipality.id
  limit 1;

  select municipality.id
    into beta_id
  from public.municipalities as municipality
  where lower(btrim(municipality.name)) = lower('Prefeitura Beta')
    and municipality.state = 'SP'
  order by municipality.created_at, municipality.id
  limit 1;

  if alfa_id is null or beta_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: Prefeitura Alfa e Prefeitura Beta ativas devem existir no DEV.';
  end if;

  if alfa_id = beta_id then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: Alfa e Beta precisam ser municípios distintos.';
  end if;

  select count(distinct membership.user_id), (array_agg(distinct membership.user_id))[1]
    into matching_count, alfa_admin_id
  from public.municipality_members as membership
  join public.municipality_member_roles as role_assignment
    on role_assignment.membership_id = membership.id
  where membership.municipality_id = alfa_id
    and membership.status = 'active'::public.membership_status
    and role_assignment.role_scope = 'municipality'::public.role_scope
    and role_assignment.role_code = 'municipality_admin';

  if matching_count <> 1 then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: deve existir exatamente um municipality_admin ativo na Prefeitura Alfa.';
  end if;

  select count(distinct membership.user_id), (array_agg(distinct membership.user_id))[1]
    into matching_count, beta_read_only_id
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

  if matching_count <> 1 then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: deve existir exatamente um grants_manager ativo sem municipality_admin na Prefeitura Beta.';
  end if;

  if superadmin_id = alfa_admin_id
    or superadmin_id = beta_read_only_id
    or alfa_admin_id = beta_read_only_id then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: superadmin, municipality_admin Alfa e grants_manager Beta devem ser usuários DEV distintos.';
  end if;

  select department.id
    into alfa_department_id
  from public.municipality_departments as department
  where department.municipality_id = alfa_id
    and department.status = 'active'
  order by department.created_at, department.id
  limit 1;

  select department.id
    into beta_department_id
  from public.municipality_departments as department
  where department.municipality_id = beta_id
    and department.status = 'active'
  order by department.created_at, department.id
  limit 1;

  if alfa_department_id is null or beta_department_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: Alfa e Beta precisam possuir pelo menos uma unidade administrativa ativa.';
  end if;

  -- Evita tocar em combinações que tenham sido preenchidas em teste anterior ou
  -- durante evolução manual posterior da plataforma.
  if exists (
    select 1
    from public.municipality_priority_areas as priority_area
    join public.policy_areas as policy_area
      on policy_area.id = priority_area.policy_area_id
    where priority_area.municipality_id = alfa_id
      and policy_area.code in ('health', 'culture')
  ) or exists (
    select 1
    from public.municipality_capacity_profiles as capacity_profile
    where capacity_profile.municipality_id = alfa_id
  ) or exists (
    select 1
    from public.municipality_capability_assessments as assessment
    join public.capability_dimensions as dimension
      on dimension.id = assessment.capability_dimension_id
    where assessment.municipality_id = alfa_id
      and dimension.code = 'grants_management'
  ) or exists (
    select 1
    from public.municipality_priority_areas as priority_area
    join public.policy_areas as policy_area
      on policy_area.id = priority_area.policy_area_id
    where priority_area.municipality_id = beta_id
      and policy_area.code in ('education', 'culture')
  ) or exists (
    select 1
    from public.municipality_demands as demand
    where demand.municipality_id in (alfa_id, beta_id)
      and demand.title in (
        'TESTE RLS PERFIL CAPACIDADE ALFA',
        'TESTE RLS PERFIL CAPACIDADE BETA'
      )
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: encontrou dados com as combinações reservadas para o teste. Não altere dados; revise antes de repetir.';
  end if;

  perform set_config('app.profile_capacity_test.superadmin_id', superadmin_id::text, true);
  perform set_config('app.profile_capacity_test.alfa_admin_id', alfa_admin_id::text, true);
  perform set_config('app.profile_capacity_test.beta_read_only_id', beta_read_only_id::text, true);
  perform set_config('app.profile_capacity_test.alfa_id', alfa_id::text, true);
  perform set_config('app.profile_capacity_test.beta_id', beta_id::text, true);
  perform set_config('app.profile_capacity_test.alfa_department_id', alfa_department_id::text, true);
  perform set_config('app.profile_capacity_test.beta_department_id', beta_department_id::text, true);

  raise notice 'Pré-condições OK: identidades e dependências Alfa/Beta foram resolvidas sem UUID fixo.';
end;
$setup$;

-- A partir deste ponto, cada operação passa por grants e RLS do papel
-- authenticated. O sub é alternado somente na transação administrativa de teste.
set local role authenticated;

do $tests$
declare
  superadmin_id uuid := current_setting('app.profile_capacity_test.superadmin_id', true)::uuid;
  alfa_admin_id uuid := current_setting('app.profile_capacity_test.alfa_admin_id', true)::uuid;
  beta_read_only_id uuid := current_setting('app.profile_capacity_test.beta_read_only_id', true)::uuid;
  alfa_id uuid := current_setting('app.profile_capacity_test.alfa_id', true)::uuid;
  beta_id uuid := current_setting('app.profile_capacity_test.beta_id', true)::uuid;
  alfa_department_id uuid := current_setting('app.profile_capacity_test.alfa_department_id', true)::uuid;
  beta_department_id uuid := current_setting('app.profile_capacity_test.beta_department_id', true)::uuid;
  policy_health_id uuid;
  policy_education_id uuid;
  policy_culture_id uuid;
  policy_housing_id uuid;
  policy_agriculture_id uuid;
  dimension_grants_id uuid;
  dimension_legal_id uuid;
  priority_id uuid;
  alfa_admin_priority_id uuid;
  assessment_id uuid;
  demand_alfa_id uuid;
  demand_beta_id uuid;
  audit_count_before integer;
  audit_count_after integer;
  affected_rows integer;
begin
  if superadmin_id is null
    or alfa_admin_id is null
    or beta_read_only_id is null
    or alfa_id is null
    or beta_id is null
    or alfa_department_id is null
    or beta_department_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: parâmetros de sessão do setup não estão disponíveis.';
  end if;

  select id into policy_health_id from public.policy_areas where code = 'health';
  select id into policy_education_id from public.policy_areas where code = 'education';
  select id into policy_culture_id from public.policy_areas where code = 'culture';
  select id into policy_housing_id from public.policy_areas where code = 'housing';
  select id into policy_agriculture_id from public.policy_areas where code = 'agriculture';
  select id into dimension_grants_id from public.capability_dimensions where code = 'grants_management';
  select id into dimension_legal_id from public.capability_dimensions where code = 'legal';

  if policy_health_id is null
    or policy_education_id is null
    or policy_culture_id is null
    or policy_housing_id is null
    or policy_agriculture_id is null
    or dimension_grants_id is null
    or dimension_legal_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'Teste cancelado: seeds canônicos necessários não foram encontrados.';
  end if;

  -- A) anchor_superadmin cria e atualiza as quatro entidades da Prefeitura Alfa.
  perform set_config('request.jwt.claim.sub', superadmin_id::text, true);

  insert into public.municipality_priority_areas (
    municipality_id, policy_area_id, priority_level, notes, status
  ) values (
    alfa_id, policy_health_id, 'low', 'TESTE TRANSACIONAL', 'active'
  )
  returning id into priority_id;

  update public.municipality_priority_areas
     set priority_level = 'high',
         notes = 'TESTE TRANSACIONAL ATUALIZADO'
   where id = priority_id;

  update public.municipality_priority_areas
     set status = 'inactive'
   where id = priority_id;

  update public.municipality_priority_areas
     set status = 'active'
   where id = priority_id;

  insert into public.municipality_capacity_profiles (
    municipality_id,
    accepts_counterpart,
    counterpart_capacity_level,
    counterpart_notes,
    overall_notes
  ) values (
    alfa_id,
    null,
    'not_informed',
    'TESTE TRANSACIONAL',
    'TESTE TRANSACIONAL'
  );

  update public.municipality_capacity_profiles
     set accepts_counterpart = true,
         counterpart_capacity_level = 'possible'
   where municipality_id = alfa_id;

  insert into public.municipality_capability_assessments (
    municipality_id, capability_dimension_id, capacity_level, notes
  ) values (
    alfa_id, dimension_grants_id, 'not_informed', 'TESTE TRANSACIONAL'
  )
  returning id into assessment_id;

  update public.municipality_capability_assessments
     set capacity_level = 'adequate'
   where id = assessment_id;

  insert into public.municipality_demands (
    municipality_id,
    policy_area_id,
    department_id,
    title,
    description,
    status,
    priority_level,
    notes
  ) values (
    alfa_id,
    policy_health_id,
    alfa_department_id,
    'TESTE RLS PERFIL CAPACIDADE ALFA',
    'TESTE TRANSACIONAL',
    'identified',
    'medium',
    'TESTE TRANSACIONAL'
  )
  returning id into demand_alfa_id;

  update public.municipality_demands
     set description = 'TESTE TRANSACIONAL ATUALIZADO',
         status = 'active'
   where id = demand_alfa_id;

  update public.municipality_demands
     set status = 'inactive'
   where id = demand_alfa_id;

  update public.municipality_demands
     set status = 'active'
   where id = demand_alfa_id;

  -- Uma demanda Beta criada pelo superadmin é usada somente como alvo de
  -- tentativas cross-tenant de update pelos usuários Alfa/Beta.
  insert into public.municipality_demands (
    municipality_id,
    policy_area_id,
    department_id,
    title,
    description,
    status,
    priority_level,
    notes
  ) values (
    beta_id,
    policy_housing_id,
    beta_department_id,
    'TESTE RLS PERFIL CAPACIDADE BETA',
    'TESTE TRANSACIONAL',
    'identified',
    'medium',
    'TESTE TRANSACIONAL'
  )
  returning id into demand_beta_id;

  -- B) Restrições de domínio e a FK composta devem rejeitar entradas inválidas.
  begin
    insert into public.municipality_priority_areas (
      municipality_id, policy_area_id, priority_level, status
    ) values (
      alfa_id, policy_housing_id, 'critical', 'active'
    );
    raise exception 'FALHA: priority_level inválido foi aceito.';
  exception
    when check_violation then
      raise notice 'OK: priority_level inválido foi bloqueado.';
  end;

  begin
    insert into public.municipality_capability_assessments (
      municipality_id, capability_dimension_id, capacity_level
    ) values (
      alfa_id, dimension_legal_id, 'critical'
    );
    raise exception 'FALHA: capacity_level inválido foi aceito.';
  exception
    when check_violation then
      raise notice 'OK: capacity_level inválido foi bloqueado.';
  end;

  begin
    insert into public.municipality_demands (
      municipality_id, policy_area_id, department_id, title, status, priority_level
    ) values (
      alfa_id, policy_agriculture_id, alfa_department_id,
      'TESTE STATUS INVÁLIDO', 'invalid', 'medium'
    );
    raise exception 'FALHA: status inválido foi aceito.';
  exception
    when check_violation then
      raise notice 'OK: status inválido foi bloqueado.';
  end;

  begin
    insert into public.municipality_demands (
      municipality_id, policy_area_id, department_id, title, status, priority_level
    ) values (
      alfa_id, policy_agriculture_id, beta_department_id,
      'TESTE FK CRUZADA', 'identified', 'medium'
    );
    raise exception 'FALHA: department_id Beta foi aceito em demanda Alfa.';
  exception
    when foreign_key_violation then
      raise notice 'OK: FK composta bloqueou department_id de outro município.';
  end;

  -- C) municipality_admin Alfa insere e atualiza somente registros da própria Prefeitura.
  perform set_config('request.jwt.claim.sub', alfa_admin_id::text, true);

  insert into public.municipality_priority_areas (
    municipality_id, policy_area_id, priority_level, notes, status
  ) values (
    alfa_id, policy_culture_id, 'medium',
    'TESTE INSERT MUNICIPALITY_ADMIN ALFA', 'active'
  )
  returning id into alfa_admin_priority_id;

  if not exists (
    select 1
    from public.municipality_priority_areas as priority_area
    where priority_area.id = alfa_admin_priority_id
      and priority_area.municipality_id = alfa_id
      and priority_area.policy_area_id = policy_culture_id
  ) then
    raise exception 'FALHA: municipality_admin Alfa não criou a prioridade temporária na própria Prefeitura.';
  end if;
  raise notice 'OK: municipality_admin Alfa inseriu prioridade temporária na própria Prefeitura.';

  update public.municipality_priority_areas
     set notes = 'ATUALIZADO POR MUNICIPALITY_ADMIN'
   where id = priority_id;

  update public.municipality_capacity_profiles
     set overall_notes = 'ATUALIZADO POR MUNICIPALITY_ADMIN'
   where municipality_id = alfa_id;

  update public.municipality_capability_assessments
     set notes = 'ATUALIZADO POR MUNICIPALITY_ADMIN'
   where id = assessment_id;

  update public.municipality_demands
     set notes = 'ATUALIZADO POR MUNICIPALITY_ADMIN'
   where id = demand_alfa_id;

  if (
    select count(distinct audit.entity_type)
    from public.municipality_profile_capacity_audit as audit
    where audit.municipality_id = alfa_id
      and audit.actor_user_id = alfa_admin_id
      and audit.entity_type in (
        'municipality_priority_areas',
        'municipality_capacity_profiles',
        'municipality_capability_assessments',
        'municipality_demands'
      )
  ) <> 4 then
    raise exception 'FALHA: auditoria do municipality_admin Alfa não cobriu as quatro entidades.';
  end if;

  if not exists (
    select 1
    from public.municipality_profile_capacity_audit as audit
    where audit.municipality_id = alfa_id
      and audit.entity_type = 'municipality_priority_areas'
      and audit.record_id = priority_id
      and audit.actor_user_id = alfa_admin_id
      and audit.action = 'update'
      and audit.old_data is not null
      and audit.new_data is not null
      and audit.old_data is distinct from audit.new_data
      and audit.old_data ->> 'notes' = 'TESTE TRANSACIONAL ATUALIZADO'
      and audit.new_data ->> 'notes' = 'ATUALIZADO POR MUNICIPALITY_ADMIN'
  ) then
    raise exception 'FALHA: auditoria do update da prioridade não registrou ator, payload anterior e payload novo corretamente.';
  end if;
  raise notice 'OK: auditoria de update da prioridade contém actor, old_data e new_data corretos.';

  -- O usuário Alfa não pode mudar municipality_id, inserir em Beta nem atualizar
  -- uma linha Beta que não é visível pelas policies de UPDATE.
  begin
    update public.municipality_priority_areas
       set municipality_id = beta_id
     where id = priority_id;
    raise exception 'FALHA: municipality_id foi alterado por authenticated.';
  exception
    when insufficient_privilege then
      raise notice 'OK: municipality_id é imutável para authenticated.';
  end;

  begin
    insert into public.municipality_priority_areas (
      municipality_id, policy_area_id, priority_level, status
    ) values (
      beta_id, policy_education_id, 'low', 'active'
    );
    raise exception 'FALHA: municipality_admin Alfa inseriu prioridade na Beta.';
  exception
    when insufficient_privilege then
      raise notice 'OK: municipality_admin Alfa não inseriu na Beta.';
  end;

  update public.municipality_demands
     set notes = 'FALHA CROSS TENANT'
   where id = demand_beta_id;
  get diagnostics affected_rows = row_count;

  if affected_rows <> 0 then
    raise exception 'FALHA: municipality_admin Alfa atualizou demanda da Beta.';
  end if;
  raise notice 'OK: municipality_admin Alfa não atualizou demanda da Beta.';

  -- O municipality_admin usa o papel authenticated e pode ler as próprias linhas,
  -- mas não recebe DELETE. Cada tentativa deve falhar por privilégio/RLS ou deixar
  -- a linha intacta, sem nunca excluir registro algum.
  begin
    delete from public.municipality_priority_areas where id = priority_id;
    get diagnostics affected_rows = row_count;
    if affected_rows <> 0 then
      raise exception 'FALHA: municipality_admin Alfa excluiu uma prioridade.';
    end if;
    if not exists (select 1 from public.municipality_priority_areas where id = priority_id) then
      raise exception 'FALHA: prioridade não permaneceu após tentativa de DELETE.';
    end if;
    raise notice 'OK: DELETE de prioridade foi bloqueado por RLS sem remover a linha.';
  exception
    when insufficient_privilege then
      if not exists (select 1 from public.municipality_priority_areas where id = priority_id) then
        raise exception 'FALHA: prioridade não permaneceu após DELETE sem privilégio.';
      end if;
      raise notice 'OK: DELETE de prioridade foi bloqueado por ausência de privilégio.';
  end;

  begin
    delete from public.municipality_capacity_profiles where municipality_id = alfa_id;
    get diagnostics affected_rows = row_count;
    if affected_rows <> 0 then
      raise exception 'FALHA: municipality_admin Alfa excluiu o perfil de capacidade.';
    end if;
    if not exists (select 1 from public.municipality_capacity_profiles where municipality_id = alfa_id) then
      raise exception 'FALHA: perfil de capacidade não permaneceu após tentativa de DELETE.';
    end if;
    raise notice 'OK: DELETE de perfil de capacidade foi bloqueado por RLS sem remover a linha.';
  exception
    when insufficient_privilege then
      if not exists (select 1 from public.municipality_capacity_profiles where municipality_id = alfa_id) then
        raise exception 'FALHA: perfil de capacidade não permaneceu após DELETE sem privilégio.';
      end if;
      raise notice 'OK: DELETE de perfil de capacidade foi bloqueado por ausência de privilégio.';
  end;

  begin
    delete from public.municipality_capability_assessments where id = assessment_id;
    get diagnostics affected_rows = row_count;
    if affected_rows <> 0 then
      raise exception 'FALHA: municipality_admin Alfa excluiu uma avaliação de capacidade.';
    end if;
    if not exists (select 1 from public.municipality_capability_assessments where id = assessment_id) then
      raise exception 'FALHA: avaliação de capacidade não permaneceu após tentativa de DELETE.';
    end if;
    raise notice 'OK: DELETE de avaliação de capacidade foi bloqueado por RLS sem remover a linha.';
  exception
    when insufficient_privilege then
      if not exists (select 1 from public.municipality_capability_assessments where id = assessment_id) then
        raise exception 'FALHA: avaliação de capacidade não permaneceu após DELETE sem privilégio.';
      end if;
      raise notice 'OK: DELETE de avaliação de capacidade foi bloqueado por ausência de privilégio.';
  end;

  begin
    delete from public.municipality_demands where id = demand_alfa_id;
    get diagnostics affected_rows = row_count;
    if affected_rows <> 0 then
      raise exception 'FALHA: municipality_admin Alfa excluiu uma demanda.';
    end if;
    if not exists (select 1 from public.municipality_demands where id = demand_alfa_id) then
      raise exception 'FALHA: demanda não permaneceu após tentativa de DELETE.';
    end if;
    raise notice 'OK: DELETE de demanda foi bloqueado por RLS sem remover a linha.';
  exception
    when insufficient_privilege then
      if not exists (select 1 from public.municipality_demands where id = demand_alfa_id) then
        raise exception 'FALHA: demanda não permaneceu após DELETE sem privilégio.';
      end if;
      raise notice 'OK: DELETE de demanda foi bloqueado por ausência de privilégio.';
  end;

  -- D) grants_manager Beta é somente leitura: não atualiza Beta nem Alfa e não
  -- consegue inserir dados no próprio município.
  perform set_config('request.jwt.claim.sub', beta_read_only_id::text, true);

  update public.municipality_demands
     set notes = 'FALHA BETA OWN WRITE'
   where id = demand_beta_id;
  get diagnostics affected_rows = row_count;

  if affected_rows <> 0 then
    raise exception 'FALHA: grants_manager Beta atualizou a própria demanda.';
  end if;

  update public.municipality_demands
     set notes = 'FALHA BETA CROSS WRITE'
   where id = demand_alfa_id;
  get diagnostics affected_rows = row_count;

  if affected_rows <> 0 then
    raise exception 'FALHA: grants_manager Beta atualizou demanda da Alfa.';
  end if;

  begin
    delete from public.municipality_demands where id = demand_beta_id;
    get diagnostics affected_rows = row_count;
    if affected_rows <> 0 then
      raise exception 'FALHA: grants_manager Beta excluiu a própria demanda.';
    end if;
    if not exists (select 1 from public.municipality_demands where id = demand_beta_id) then
      raise exception 'FALHA: demanda Beta não permaneceu após tentativa de DELETE.';
    end if;
    raise notice 'OK: grants_manager Beta não excluiu a própria demanda por RLS.';
  exception
    when insufficient_privilege then
      if not exists (select 1 from public.municipality_demands where id = demand_beta_id) then
        raise exception 'FALHA: demanda Beta não permaneceu após DELETE sem privilégio.';
      end if;
      raise notice 'OK: grants_manager Beta não possui privilégio de DELETE.';
  end;

  begin
    insert into public.municipality_priority_areas (
      municipality_id, policy_area_id, priority_level, status
    ) values (
      beta_id, policy_culture_id, 'low', 'active'
    );
    raise exception 'FALHA: grants_manager Beta inseriu prioridade.';
  exception
    when insufficient_privilege then
      raise notice 'OK: grants_manager Beta permaneceu somente leitura.';
  end;

  -- E) O usuário autenticado não possui nenhuma via direta de escrita no histórico.
  perform set_config('request.jwt.claim.sub', superadmin_id::text, true);

  begin
    insert into public.municipality_profile_capacity_audit (
      municipality_id,
      entity_type,
      record_id,
      actor_user_id,
      action,
      old_data,
      new_data
    ) values (
      alfa_id,
      'municipality_priority_areas',
      priority_id,
      superadmin_id,
      'insert',
      null,
      '{}'::jsonb
    );
    raise exception 'FALHA: authenticated escreveu diretamente na auditoria.';
  exception
    when insufficient_privilege then
      raise notice 'OK: escrita direta na auditoria foi bloqueada.';
  end;

  -- F) A auditoria deve conter origem, ator, payload e ações corretas.
  if not exists (
    select 1
    from public.municipality_profile_capacity_audit as audit
    where audit.municipality_id = alfa_id
      and audit.entity_type = 'municipality_priority_areas'
      and audit.record_id = priority_id
      and audit.actor_user_id = superadmin_id
      and audit.action = 'insert'
      and audit.old_data is null
      and audit.new_data is not null
  ) then
    raise exception 'FALHA: auditoria de insert da prioridade não foi encontrada.';
  end if;

  if not exists (
    select 1
    from public.municipality_profile_capacity_audit as audit
    where audit.municipality_id = alfa_id
      and audit.entity_type = 'municipality_priority_areas'
      and audit.record_id = priority_id
      and audit.action in ('activate', 'deactivate')
  ) then
    raise exception 'FALHA: auditoria de ativação/inativação da prioridade não foi encontrada.';
  end if;

  if not exists (
    select 1
    from public.municipality_profile_capacity_audit as audit
    where audit.municipality_id = alfa_id
      and audit.entity_type = 'municipality_demands'
      and audit.record_id = demand_alfa_id
      and audit.action in ('activate', 'deactivate')
  ) then
    raise exception 'FALHA: auditoria de ativação/inativação da demanda não foi encontrada.';
  end if;

  if not exists (
    select 1
    from public.municipality_profile_capacity_audit as audit
    where audit.municipality_id = alfa_id
      and audit.entity_type = 'municipality_capacity_profiles'
      and audit.record_id = alfa_id
      and audit.actor_user_id = superadmin_id
      and audit.action = 'insert'
      and audit.old_data is null
      and audit.new_data is not null
  ) then
    raise exception 'FALHA: record_id do capacity profile não foi auditado como municipality_id.';
  end if;

  -- G) Update sem mudança funcional não pode criar uma linha extra no histórico.
  select count(*) into audit_count_before
  from public.municipality_profile_capacity_audit as audit
  where audit.entity_type = 'municipality_priority_areas'
    and audit.record_id = priority_id;

  update public.municipality_priority_areas
     set priority_level = priority_level
   where id = priority_id;

  select count(*) into audit_count_after
  from public.municipality_profile_capacity_audit as audit
  where audit.entity_type = 'municipality_priority_areas'
    and audit.record_id = priority_id;

  if audit_count_after <> audit_count_before then
    raise exception 'FALHA: update sem mudança funcional gerou auditoria.';
  end if;

  raise notice 'SUCESSO: superadmin escreveu nas quatro tabelas, municipality_admin Alfa escreveu apenas na Alfa, grants_manager Beta permaneceu leitura, constraints/RLS/auditoria foram validadas.';
end;
$tests$;

rollback;

select
  'PASSOU' as status,
  'Todos os testes críticos da Etapa 19.3 foram aprovados e o ROLLBACK preservou o DEV.' as mensagem;
