-- Restringe a edição de avaliações técnicas aos campos de negócio mutáveis.
-- capability_dimension_id permanece disponível apenas no INSERT.
-- Depende de 20260918_municipality_profile_capacity_write.sql.

begin;

-- Remove UPDATE amplo e por coluna que poderia alcançar PUBLIC, anon ou
-- authenticated. Isso neutraliza grants anteriores antes da concessão mínima.
revoke update on table public.municipality_capability_assessments from public, anon, authenticated;
revoke update (
  id,
  municipality_id,
  capability_dimension_id,
  capacity_level,
  notes,
  created_at,
  updated_at
) on table public.municipality_capability_assessments from public, anon, authenticated;

-- Somente os campos de avaliação previstos permanecem editáveis.
grant update (
  capacity_level,
  notes
) on table public.municipality_capability_assessments to authenticated;

commit;