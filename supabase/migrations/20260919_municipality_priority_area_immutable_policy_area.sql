-- Corrige o privilégio de UPDATE de municipality_priority_areas sem alterar RLS,
-- policies, triggers ou auditoria. policy_area_id permanece disponível apenas no INSERT.
-- Depende de 20260918_municipality_profile_capacity_write.sql.

begin;

-- Remove UPDATE amplo e por coluna que poderia alcançar PUBLIC, anon ou
-- authenticated. Isso neutraliza grants anteriores antes da concessão mínima.
revoke update on table public.municipality_priority_areas from public, anon, authenticated;
revoke update (
  id,
  municipality_id,
  policy_area_id,
  priority_level,
  notes,
  status,
  created_at,
  updated_at
) on table public.municipality_priority_areas from public, anon, authenticated;

-- Somente authenticated recebe os campos de negócio editáveis previstos.
grant update (
  priority_level,
  notes,
  status
) on table public.municipality_priority_areas to authenticated;

commit;