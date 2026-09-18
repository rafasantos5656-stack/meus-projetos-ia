-- ETAPA 19.5 — Verificação manual read-only de capacidade municipal.
-- Execute somente no SQL Editor do Supabase DEV após os testes manuais.
-- Não contém escrita, DDL, alteração de permissões ou chamadas administrativas.

with capacity_profiles as (
  select
    m.name as municipality_name,
    cp.municipality_id,
    cp.accepts_counterpart,
    cp.counterpart_capacity_level,
    cp.counterpart_notes,
    cp.overall_notes,
    cp.created_at,
    cp.updated_at
  from public.municipality_capacity_profiles as cp
  join public.municipalities as m on m.id = cp.municipality_id
),
capability_assessments as (
  select
    m.name as municipality_name,
    ca.id as record_id,
    ca.municipality_id,
    cd.code as capability_dimension_code,
    cd.name as capability_dimension_name,
    ca.capacity_level,
    ca.notes,
    ca.created_at,
    ca.updated_at
  from public.municipality_capability_assessments as ca
  join public.municipalities as m on m.id = ca.municipality_id
  join public.capability_dimensions as cd on cd.id = ca.capability_dimension_id
),
municipality_counts as (
  select
    m.name as municipality_name,
    m.id as municipality_id,
    count(distinct cp.municipality_id)::bigint as capacity_profile_count,
    count(ca.id)::bigint as capability_assessment_count
  from public.municipalities as m
  left join public.municipality_capacity_profiles as cp on cp.municipality_id = m.id
  left join public.municipality_capability_assessments as ca on ca.municipality_id = m.id
  group by m.id, m.name
),
audit_events as (
  select
    m.name as municipality_name,
    audit.municipality_id,
    audit.entity_type,
    audit.record_id,
    audit.action,
    audit.actor_user_id,
    audit.created_at,
    audit.old_data,
    audit.new_data
  from public.municipality_profile_capacity_audit as audit
  join public.municipalities as m on m.id = audit.municipality_id
  where audit.entity_type in (
    'municipality_capacity_profiles',
    'municipality_capability_assessments'
  )
),
audit_summary as (
  select
    municipality_name,
    municipality_id,
    entity_type,
    action,
    count(*)::bigint as audit_event_count
  from audit_events
  group by municipality_name, municipality_id, entity_type, action
),
verification_rows as (
  select
    10 as section_order,
    'A. Perfil geral de capacidade'::text as section,
    cp.created_at as chronological_at,
    cp.municipality_name,
    cp.municipality_id,
    null::uuid as record_id,
    null::text as entity_type,
    null::text as capability_dimension_code,
    null::text as capability_dimension_name,
    null::text as capacity_level,
    cp.accepts_counterpart,
    cp.counterpart_capacity_level,
    cp.counterpart_notes,
    cp.overall_notes,
    null::text as notes,
    cp.created_at,
    cp.updated_at,
    null::text as action,
    null::uuid as actor_user_id,
    null::jsonb as old_data,
    null::jsonb as new_data,
    null::bigint as capacity_profile_count,
    null::bigint as capability_assessment_count,
    null::bigint as audit_event_count
  from capacity_profiles as cp

  union all

  select
    20,
    'B. Avaliações técnicas'::text,
    ca.created_at,
    ca.municipality_name,
    ca.municipality_id,
    ca.record_id,
    'municipality_capability_assessments'::text,
    ca.capability_dimension_code,
    ca.capability_dimension_name,
    ca.capacity_level,
    null::boolean,
    null::text,
    null::text,
    null::text,
    ca.notes,
    ca.created_at,
    ca.updated_at,
    null::text,
    null::uuid,
    null::jsonb,
    null::jsonb,
    null::bigint,
    null::bigint,
    null::bigint
  from capability_assessments as ca

  union all

  select
    30,
    'C. Contagem por município (isolamento)'::text,
    null::timestamptz,
    mc.municipality_name,
    mc.municipality_id,
    null::uuid,
    null::text,
    null::text,
    null::text,
    null::text,
    null::boolean,
    null::text,
    null::text,
    null::text,
    null::text,
    null::timestamptz,
    null::timestamptz,
    null::text,
    null::uuid,
    null::jsonb,
    null::jsonb,
    mc.capacity_profile_count,
    mc.capability_assessment_count,
    null::bigint
  from municipality_counts as mc

  union all

  select
    40,
    'D. Eventos de auditoria (cronológico)'::text,
    ae.created_at,
    ae.municipality_name,
    ae.municipality_id,
    ae.record_id,
    ae.entity_type,
    null::text,
    null::text,
    null::text,
    null::boolean,
    null::text,
    null::text,
    null::text,
    null::text,
    ae.created_at,
    null::timestamptz,
    ae.action,
    ae.actor_user_id,
    ae.old_data,
    ae.new_data,
    null::bigint,
    null::bigint,
    null::bigint
  from audit_events as ae

  union all

  select
    50,
    'E. Resumo de auditoria por município/entidade/ação'::text,
    null::timestamptz,
    asu.municipality_name,
    asu.municipality_id,
    null::uuid,
    asu.entity_type,
    null::text,
    null::text,
    null::text,
    null::boolean,
    null::text,
    null::text,
    null::text,
    null::text,
    null::timestamptz,
    null::timestamptz,
    asu.action,
    null::uuid,
    null::jsonb,
    null::jsonb,
    null::bigint,
    null::bigint,
    asu.audit_event_count
  from audit_summary as asu
)
select
  section,
  municipality_name,
  municipality_id,
  record_id,
  entity_type,
  capability_dimension_code,
  capability_dimension_name,
  capacity_level,
  accepts_counterpart,
  counterpart_capacity_level,
  counterpart_notes,
  overall_notes,
  notes,
  created_at,
  updated_at,
  action,
  actor_user_id,
  old_data,
  new_data,
  capacity_profile_count,
  capability_assessment_count,
  audit_event_count
from verification_rows
order by section_order, chronological_at nulls last, municipality_name, entity_type, action;
