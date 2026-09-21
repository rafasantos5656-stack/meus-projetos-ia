-- SOMENTE DEV — fixtures globais fictícios para os testes da Etapa 20.3.
-- Não executar em PROD. Não cria usuários, municípios, memberships ou relações municipais.
-- Os códigos ANCHOR_DEV_TEST e OPP_DEV_* são reservados exclusivamente para este setup.

begin;

do $setup$
declare
  fixture_source_id uuid;
begin
  if exists (
    select 1
    from (values
      ('public.opportunity_sources'),
      ('public.opportunities'),
      ('public.opportunity_policy_areas'),
      ('public.opportunity_versions'),
      ('public.municipality_opportunities'),
      ('public.municipality_opportunity_audit')
    ) as required_table(qualified_name)
    where pg_catalog.to_regclass(required_table.qualified_name) is null
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'Setup cancelado: as tabelas da fundação global e municipal esperadas não existem no DEV.';
  end if;

  -- Este setup é pré-condição dos testes funcionais. Não restaura fixtures se já
  -- houver decisões municipais ou auditorias que possam depender delas.
  if exists (select 1 from public.municipality_opportunities)
     or exists (select 1 from public.municipality_opportunity_audit) then
    raise exception using
      errcode = 'P0001',
      message = 'Setup cancelado: municipality_opportunities ou sua auditoria já possuem registros. Revise antes de reexecutar.';
  end if;

  -- Evita que um código reservado de fonte seja reutilizado para oportunidades que
  -- não pertencem aos três fixtures canônicos abaixo.
  if exists (
    select 1
    from public.opportunities as opportunity
    join public.opportunity_sources as source on source.id = opportunity.source_id
    where source.code = 'ANCHOR_DEV_TEST'
      and opportunity.external_id not in (
        'OPP_DEV_PUBLISHED_001',
        'OPP_DEV_PUBLISHED_002',
        'OPP_DEV_UNPUBLISHED_001'
      )
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'Setup cancelado: ANCHOR_DEV_TEST possui oportunidade fora dos fixtures canônicos. Não sobrescreva dados sem revisão.';
  end if;

  -- A chave code é reservada para DEV; a reexecução restaura somente os valores
  -- canônicos desse fixture, sem alcançar fontes ou oportunidades de outro código.
  insert into public.opportunity_sources as source (
    code,
    name,
    sphere,
    official_base_url,
    active
  ) values (
    'ANCHOR_DEV_TEST',
    'Âncora DEV — Fonte de Teste',
    'other',
    'https://example.com/anchor-dev-test',
    true
  )
  on conflict (code) do update
    set name = excluded.name,
        sphere = excluded.sphere,
        official_base_url = excluded.official_base_url,
        active = excluded.active
  returning id into fixture_source_id;

  insert into public.opportunities as opportunity (
    source_id,
    external_id,
    sphere,
    granting_body,
    program_name,
    title,
    description,
    eligibility_summary,
    coverage_type,
    status,
    official_url,
    is_published
  ) values
    (
      fixture_source_id,
      'OPP_DEV_PUBLISHED_001',
      'other',
      'Âncora DEV',
      'Testes RLS — Etapa 20.3',
      'Oportunidade DEV Publicada 001',
      'Fixture fictício para validação de RLS municipal.',
      'Uso exclusivo em testes DEV.',
      'national',
      'open',
      'https://example.com/anchor-dev-test/opp-dev-published-001',
      true
    ),
    (
      fixture_source_id,
      'OPP_DEV_PUBLISHED_002',
      'other',
      'Âncora DEV',
      'Testes RLS — Etapa 20.3',
      'Oportunidade DEV Publicada 002',
      'Fixture fictício para validação de RLS municipal.',
      'Uso exclusivo em testes DEV.',
      'national',
      'open',
      'https://example.com/anchor-dev-test/opp-dev-published-002',
      true
    ),
    (
      fixture_source_id,
      'OPP_DEV_UNPUBLISHED_001',
      'other',
      'Âncora DEV',
      'Testes RLS — Etapa 20.3',
      'Oportunidade DEV Não Publicada 001',
      'Fixture fictício para validação do bloqueio de publicação.',
      'Uso exclusivo em testes DEV.',
      'national',
      'open',
      'https://example.com/anchor-dev-test/opp-dev-unpublished-001',
      false
    )
  on conflict (source_id, external_id) do update
    set sphere = excluded.sphere,
        granting_body = excluded.granting_body,
        program_name = excluded.program_name,
        title = excluded.title,
        description = excluded.description,
        eligibility_summary = excluded.eligibility_summary,
        coverage_type = excluded.coverage_type,
        status = excluded.status,
        official_url = excluded.official_url,
        is_published = excluded.is_published;

  if (
    select count(*)
    from public.opportunities as opportunity
    where opportunity.source_id = fixture_source_id
      and opportunity.external_id in (
        'OPP_DEV_PUBLISHED_001',
        'OPP_DEV_PUBLISHED_002',
        'OPP_DEV_UNPUBLISHED_001'
      )
  ) <> 3 then
    raise exception using
      errcode = 'P0001',
      message = 'Setup cancelado: não foi possível confirmar os três fixtures DEV esperados.';
  end if;
end;
$setup$;

commit;

select
  source.code as source_code,
  opportunity.external_id,
  opportunity.title,
  opportunity.is_published,
  opportunity.status
from public.opportunities as opportunity
join public.opportunity_sources as source on source.id = opportunity.source_id
where source.code = 'ANCHOR_DEV_TEST'
  and opportunity.external_id in (
    'OPP_DEV_PUBLISHED_001',
    'OPP_DEV_PUBLISHED_002',
    'OPP_DEV_UNPUBLISHED_001'
  )
order by opportunity.external_id;