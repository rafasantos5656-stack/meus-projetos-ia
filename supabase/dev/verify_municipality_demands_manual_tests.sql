-- Etapa 19.6.4 — verificador de demandas municipais e auditoria.
-- Uso manual exclusivo no Supabase DEV.
-- A consulta produz uma única tabela de resultados e somente efetua leitura.

with demand_counts as (
    select
        municipality.id as municipality_id,
        municipality.name as municipality_name,
        count(demand.id)::bigint as total_demands,
        count(demand.id) filter (where demand.status = 'identified')::bigint as identified_demands,
        count(demand.id) filter (where demand.status = 'planned')::bigint as planned_demands,
        count(demand.id) filter (where demand.status = 'in_preparation')::bigint as in_preparation_demands,
        count(demand.id) filter (where demand.status = 'active')::bigint as active_demands,
        count(demand.id) filter (where demand.status = 'paused')::bigint as paused_demands,
        count(demand.id) filter (where demand.status = 'inactive')::bigint as inactive_demands
    from public.municipalities as municipality
    left join public.municipality_demands as demand
        on demand.municipality_id = municipality.id
    group by municipality.id, municipality.name
),
demand_details as (
    select
        municipality.name as municipality_name,
        demand.title,
        coalesce(policy_area.name, 'Área não identificada') as policy_area_name,
        case
            when demand.department_id is null then 'Não definida'
            when department.id is null then 'Unidade indisponível'
            else department.name
        end as department_name,
        demand.priority_level,
        demand.status as demand_status,
        demand.description,
        demand.notes,
        demand.created_at,
        demand.updated_at
    from public.municipality_demands as demand
    join public.municipalities as municipality
        on municipality.id = demand.municipality_id
    left join public.policy_areas as policy_area
        on policy_area.id = demand.policy_area_id
    left join public.municipality_departments as department
        on department.id = demand.department_id
       and department.municipality_id = demand.municipality_id
),
audit_events as (
    select
        municipality.name as municipality_name,
        audit.action,
        audit.actor_user_id,
        audit.created_at as event_at,
        audit.old_data,
        audit.new_data
    from public.municipality_profile_capacity_audit as audit
    join public.municipalities as municipality
        on municipality.id = audit.municipality_id
    where audit.entity_type = 'municipality_demands'
),
audit_summary as (
    select
        municipality_name,
        action,
        count(*)::bigint as event_count
    from audit_events
    group by municipality_name, action
),
cross_tenant_consistency as (
    select
        count(*) filter (
            where demand.department_id is not null
              and department.id is null
        )::bigint as inconsistency_count
    from public.municipality_demands as demand
    left join public.municipality_departments as department
        on department.id = demand.department_id
       and department.municipality_id = demand.municipality_id
),
output_rows as (
    select
        10::integer as section_order,
        1::integer as item_order,
        'A — DEMANDAS POR MUNICÍPIO'::text as section,
        municipality_name as municipality,
        'Total de demandas'::text as item,
        total_demands as quantity,
        null::text as title,
        null::text as policy_area,
        null::text as department,
        null::text as priority_level,
        null::text as demand_status,
        null::text as description,
        null::text as notes,
        null::text as action,
        null::uuid as actor_user_id,
        null::timestamptz as event_at,
        null::timestamptz as created_at,
        null::timestamptz as updated_at,
        null::jsonb as old_data,
        null::jsonb as new_data
    from demand_counts

    union all

    select
        10, 2, 'A — DEMANDAS POR MUNICÍPIO', municipality_name,
        'Identificadas', identified_demands,
        null::text, null::text, null::text, null::text, null::text,
        null::text, null::text, null::text, null::uuid,
        null::timestamptz, null::timestamptz, null::timestamptz,
        null::jsonb, null::jsonb
    from demand_counts

    union all

    select
        10, 3, 'A — DEMANDAS POR MUNICÍPIO', municipality_name,
        'Planejadas', planned_demands,
        null::text, null::text, null::text, null::text, null::text,
        null::text, null::text, null::text, null::uuid,
        null::timestamptz, null::timestamptz, null::timestamptz,
        null::jsonb, null::jsonb
    from demand_counts

    union all

    select
        10, 4, 'A — DEMANDAS POR MUNICÍPIO', municipality_name,
        'Em preparação', in_preparation_demands,
        null::text, null::text, null::text, null::text, null::text,
        null::text, null::text, null::text, null::uuid,
        null::timestamptz, null::timestamptz, null::timestamptz,
        null::jsonb, null::jsonb
    from demand_counts

    union all

    select
        10, 5, 'A — DEMANDAS POR MUNICÍPIO', municipality_name,
        'Ativas', active_demands,
        null::text, null::text, null::text, null::text, null::text,
        null::text, null::text, null::text, null::uuid,
        null::timestamptz, null::timestamptz, null::timestamptz,
        null::jsonb, null::jsonb
    from demand_counts

    union all

    select
        10, 6, 'A — DEMANDAS POR MUNICÍPIO', municipality_name,
        'Pausadas', paused_demands,
        null::text, null::text, null::text, null::text, null::text,
        null::text, null::text, null::text, null::uuid,
        null::timestamptz, null::timestamptz, null::timestamptz,
        null::jsonb, null::jsonb
    from demand_counts

    union all

    select
        10, 7, 'A — DEMANDAS POR MUNICÍPIO', municipality_name,
        'Inativas', inactive_demands,
        null::text, null::text, null::text, null::text, null::text,
        null::text, null::text, null::text, null::uuid,
        null::timestamptz, null::timestamptz, null::timestamptz,
        null::jsonb, null::jsonb
    from demand_counts

    union all

    select
        20, row_number() over (order by municipality_name, title)::integer,
        'B — DETALHE DAS DEMANDAS', municipality_name,
        'Demanda cadastrada', null::bigint,
        title, policy_area_name, department_name, priority_level, demand_status,
        description, notes, null::text, null::uuid,
        null::timestamptz, created_at, updated_at, null::jsonb, null::jsonb
    from demand_details

    union all

    select
        30, row_number() over (order by event_at, municipality_name, action)::integer,
        'C — AUDITORIA DAS DEMANDAS', municipality_name,
        'Evento de auditoria', null::bigint,
        null::text, null::text, null::text, null::text, null::text,
        null::text, null::text, action, actor_user_id,
        event_at, event_at, null::timestamptz, old_data, new_data
    from audit_events

    union all

    select
        40, row_number() over (order by municipality_name, action)::integer,
        'D — RESUMO DA AUDITORIA', municipality_name,
        'Eventos de auditoria', event_count,
        null::text, null::text, null::text, null::text, null::text,
        null::text, null::text, action, null::uuid,
        null::timestamptz, null::timestamptz, null::timestamptz,
        null::jsonb, null::jsonb
    from audit_summary

    union all

    select
        50, 1, 'E — ISOLAMENTO', municipality_name,
        'Demandas associadas ao município', total_demands,
        null::text, null::text, null::text, null::text, null::text,
        null::text, null::text, null::text, null::uuid,
        null::timestamptz, null::timestamptz, null::timestamptz,
        null::jsonb, null::jsonb
    from demand_counts

    union all

    select
        50, 2, 'E — ISOLAMENTO', 'Todos os municípios',
        'Inconsistências de unidade entre municípios', inconsistency_count,
        null::text, null::text, null::text, null::text, null::text,
        null::text, null::text, null::text, null::uuid,
        null::timestamptz, null::timestamptz, null::timestamptz,
        null::jsonb, null::jsonb
    from cross_tenant_consistency
)
select
    section,
    municipality,
    item,
    quantity,
    title,
    policy_area,
    department,
    priority_level,
    demand_status,
    description,
    notes,
    action,
    actor_user_id,
    event_at,
    created_at,
    updated_at,
    old_data,
    new_data
from output_rows
order by section_order, municipality, item_order, event_at nulls last;