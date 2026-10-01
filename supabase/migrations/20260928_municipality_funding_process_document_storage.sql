-- ETAPA 20.3.20B
-- Supabase Storage para arquivos dos documentos dos processos de captacao.
-- Bucket privado e infraestrutura de acesso multi-tenant.
--
-- Caminho canonico:
-- {municipality_id}/{funding_process_id}/{document_id}/{file_id}

insert into storage.buckets (
  id,
  name,
  public
)
values (
  'municipality-funding-process-documents',
  'municipality-funding-process-documents',
  false
)
on conflict (id) do update
set
  name = excluded.name,
  public = false;


-- Conversao segura de texto para UUID.
-- Retorna NULL para valores invalidos em vez de propagar erro pela policy RLS.
create or replace function private.try_parse_uuid(
  p_value text
)
returns uuid
language plpgsql
immutable
security invoker
set search_path = pg_catalog
as $$
begin
  return p_value::uuid;
exception
  when invalid_text_representation then
    return null;
end;
$$;

revoke all on function private.try_parse_uuid(text)
from public;

grant execute on function private.try_parse_uuid(text)
to authenticated;

-- Valida se um objeto do Storage corresponde exatamente aos metadados
-- registrados para o arquivo, documento, processo e municipio.
create or replace function private.is_valid_funding_document_storage_object(
  p_bucket_id text,
  p_object_name text
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select exists (
    select 1
    from public.municipality_funding_process_document_files as f
    join public.municipality_funding_process_documents as d
      on d.id = f.funding_process_document_id
     and d.municipality_id = f.municipality_id
    where f.storage_bucket = p_bucket_id
      and f.storage_object_path = p_object_name
      and p_bucket_id = 'municipality-funding-process-documents'
      and p_object_name =
        f.municipality_id::text || '/' ||
        d.funding_process_id::text || '/' ||
        d.id::text || '/' ||
        f.id::text
  );
$$;

revoke all on function private.is_valid_funding_document_storage_object(text, text)
from public;

grant execute on function private.is_valid_funding_document_storage_object(text, text)
to authenticated;


-- Policies do bucket privado.
-- SELECT: usuarios com acesso aos metadados do municipio.
drop policy if exists "funding_document_storage_select"
on storage.objects;

create policy "funding_document_storage_select"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'municipality-funding-process-documents'
  and private.is_valid_funding_document_storage_object(
    bucket_id,
    name
  )
  and private.has_tenant_metadata_access(
    private.try_parse_uuid((storage.foldername(name))[1])
  )
);

-- INSERT: somente usuarios autorizados a gerenciar o processo municipal.
drop policy if exists "funding_document_storage_insert"
on storage.objects;

create policy "funding_document_storage_insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'municipality-funding-process-documents'
  and private.is_valid_funding_document_storage_object(
    bucket_id,
    name
  )
  and private.can_manage_municipality_funding_process(
    private.try_parse_uuid((storage.foldername(name))[1])
  )
);
