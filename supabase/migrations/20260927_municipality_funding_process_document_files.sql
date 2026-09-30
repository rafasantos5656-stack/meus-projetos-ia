-- ETAPA 20.3.20A
-- Metadados, versionamento, RLS e auditoria dos arquivos do checklist
-- de captacao. O Storage fisico permanece para a ETAPA 20.3.20B.
-- Execucao manual exclusiva no ambiente DEV apos revisao.

begin;

create table public.municipality_funding_process_document_files (
  id uuid primary key default gen_random_uuid(),
  municipality_id uuid not null,
  funding_process_document_id uuid not null,
  version_number integer not null,
  storage_bucket text not null
    default 'municipality-funding-process-documents',
  storage_object_path text not null,
  original_filename text not null,
  content_type text not null,
  byte_size bigint not null,
  checksum_sha256 text not null,
  is_current boolean not null,
  superseded_at timestamptz null,
  uploaded_by_user_id uuid null,
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint municipality_funding_process_document_files_municipality_fkey
    foreign key (municipality_id)
    references public.municipalities (id)
    on delete restrict,

  constraint municipality_funding_process_document_files_document_tenant_fkey
    foreign key (funding_process_document_id, municipality_id)
    references public.municipality_funding_process_documents (
      id,
      municipality_id
    )
    on delete restrict,

  constraint municipality_funding_process_document_files_uploaded_by_fkey
    foreign key (uploaded_by_user_id)
    references auth.users (id)
    on delete set null,

  constraint municipality_funding_process_document_files_id_municipality_key
    unique (id, municipality_id),

  constraint municipality_funding_process_document_files_document_version_key
    unique (funding_process_document_id, version_number),

  constraint municipality_funding_process_document_files_bucket_path_key
    unique (storage_bucket, storage_object_path),

  constraint municipality_funding_process_document_files_version_check
    check (version_number > 0),

  constraint municipality_funding_process_document_files_bucket_check
    check (storage_bucket = 'municipality-funding-process-documents'),

  constraint municipality_funding_process_document_files_filename_check
    check (char_length(btrim(original_filename)) between 1 and 240),

  constraint municipality_funding_process_document_files_content_type_check
    check (
      char_length(btrim(content_type)) between 1 and 200
      and position('/' in content_type) > 0
    ),

  constraint municipality_funding_process_document_files_byte_size_check
    check (byte_size >= 0),

  constraint municipality_funding_process_document_files_checksum_check
    check (checksum_sha256 ~ '^[0-9a-f]{64}$'),

  constraint municipality_funding_process_document_files_current_pair_check
    check (
      (is_current and superseded_at is null)
      or (not is_current and superseded_at is not null)
    ),

  constraint municipality_funding_process_document_files_path_prefix_check
    check (
      storage_object_path like (municipality_id::text || '/%')
    ),

  constraint municipality_funding_process_document_files_path_suffix_check
    check (
      storage_object_path like ('%/' || id::text)
    ),

  constraint municipality_funding_process_document_files_path_segments_check
    check (
      char_length(storage_object_path)
      - char_length(replace(storage_object_path, '/', '')) = 3
    ),

  constraint municipality_funding_process_document_files_notes_check
    check (
      notes is null
      or char_length(btrim(notes)) between 1 and 4000
    )
);

create unique index municipality_funding_process_document_files_current_idx
  on public.municipality_funding_process_document_files (
    funding_process_document_id
  )
  where is_current;

create index municipality_funding_process_document_files_document_version_idx
  on public.municipality_funding_process_document_files (
    funding_process_document_id,
    version_number desc
  );

create index municipality_funding_process_document_files_municipality_created_idx
  on public.municipality_funding_process_document_files (
    municipality_id,
    created_at desc
  );

-- Serializa uploads do mesmo item de checklist, deriva o tenant, gera a
-- versao, o path canonico e promove a nova linha a current.
create or replace function private.prepare_municipality_funding_process_document_file_insert()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  parent_document_id uuid;
  parent_municipality_id uuid;
  parent_funding_process_id uuid;
  next_version integer;
begin
  if new.id is null then
    new.id := gen_random_uuid();
  end if;

  select
    parent.id,
    parent.municipality_id,
    parent.funding_process_id
    into
      parent_document_id,
      parent_municipality_id,
      parent_funding_process_id
  from public.municipality_funding_process_documents as parent
  where parent.id = new.funding_process_document_id
  for update of parent;

  if parent_document_id is null then
    raise exception
      'O item documental informado nao existe.';
  end if;

  new.municipality_id := parent_municipality_id;
  new.funding_process_document_id := parent_document_id;
  new.storage_bucket := 'municipality-funding-process-documents';
  new.storage_object_path :=
    parent_municipality_id::text
    || '/'
    || parent_funding_process_id::text
    || '/'
    || parent_document_id::text
    || '/'
    || new.id::text;
  new.uploaded_by_user_id := (select auth.uid());
  new.is_current := true;
  new.superseded_at := null;

  select coalesce(max(existing.version_number), 0) + 1
    into next_version
  from public.municipality_funding_process_document_files as existing
  where existing.funding_process_document_id = parent_document_id;

  new.version_number := next_version;

  update public.municipality_funding_process_document_files as previous
     set is_current = false,
         superseded_at = now()
   where previous.funding_process_document_id = parent_document_id
     and previous.is_current;

  return new;
end;
$$;

revoke all
  on function private.prepare_municipality_funding_process_document_file_insert()
  from public;

create trigger municipality_funding_process_document_files_prepare_insert
  before insert on public.municipality_funding_process_document_files
  for each row
  execute function private.prepare_municipality_funding_process_document_file_insert();

-- UPDATE autenticado so pode alterar notes. O trigger de INSERT da proxima
-- versao pode apenas desativar a current anterior. ON DELETE SET NULL do
-- uploader e a unica outra mutacao estrutural admitida.
create or replace function private.validate_municipality_funding_process_document_file_update()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if old.is_current
     and not new.is_current
     and old.superseded_at is null
     and new.superseded_at is not null
     and new.id is not distinct from old.id
     and new.municipality_id is not distinct from old.municipality_id
     and new.funding_process_document_id
       is not distinct from old.funding_process_document_id
     and new.version_number is not distinct from old.version_number
     and new.storage_bucket is not distinct from old.storage_bucket
     and new.storage_object_path is not distinct from old.storage_object_path
     and new.original_filename is not distinct from old.original_filename
     and new.content_type is not distinct from old.content_type
     and new.byte_size is not distinct from old.byte_size
     and new.checksum_sha256 is not distinct from old.checksum_sha256
     and new.uploaded_by_user_id is not distinct from old.uploaded_by_user_id
     and new.notes is not distinct from old.notes
     and new.created_at is not distinct from old.created_at
  then
    return new;
  end if;

  if new.uploaded_by_user_id is null
     and old.uploaded_by_user_id is not null
     and new.id is not distinct from old.id
     and new.municipality_id is not distinct from old.municipality_id
     and new.funding_process_document_id
       is not distinct from old.funding_process_document_id
     and new.version_number is not distinct from old.version_number
     and new.storage_bucket is not distinct from old.storage_bucket
     and new.storage_object_path is not distinct from old.storage_object_path
     and new.original_filename is not distinct from old.original_filename
     and new.content_type is not distinct from old.content_type
     and new.byte_size is not distinct from old.byte_size
     and new.checksum_sha256 is not distinct from old.checksum_sha256
     and new.is_current is not distinct from old.is_current
     and new.superseded_at is not distinct from old.superseded_at
     and new.notes is not distinct from old.notes
     and new.created_at is not distinct from old.created_at
  then
    return new;
  end if;

  if new.id is distinct from old.id
     or new.municipality_id is distinct from old.municipality_id
     or new.funding_process_document_id
       is distinct from old.funding_process_document_id
     or new.version_number is distinct from old.version_number
     or new.storage_bucket is distinct from old.storage_bucket
     or new.storage_object_path is distinct from old.storage_object_path
     or new.original_filename is distinct from old.original_filename
     or new.content_type is distinct from old.content_type
     or new.byte_size is distinct from old.byte_size
     or new.checksum_sha256 is distinct from old.checksum_sha256
     or new.is_current is distinct from old.is_current
     or new.superseded_at is distinct from old.superseded_at
     or new.uploaded_by_user_id is distinct from old.uploaded_by_user_id
     or new.created_at is distinct from old.created_at
  then
    raise exception
      'Somente notes pode ser alterado apos a criacao da versao do arquivo.';
  end if;

  return new;
end;
$$;

revoke all
  on function private.validate_municipality_funding_process_document_file_update()
  from public;

create trigger municipality_funding_process_document_files_validate_update
  before update on public.municipality_funding_process_document_files
  for each row
  execute function private.validate_municipality_funding_process_document_file_update();

create trigger municipality_funding_process_document_files_touch_updated_at
  before update on public.municipality_funding_process_document_files
  for each row
  execute function private.touch_updated_at();

alter table public.municipality_funding_process_document_files
  enable row level security;

alter table public.municipality_funding_process_document_files
  force row level security;

revoke all
  on table public.municipality_funding_process_document_files
  from anon, authenticated;

grant select
  on table public.municipality_funding_process_document_files
  to authenticated;

grant insert (
  funding_process_document_id,
  original_filename,
  content_type,
  byte_size,
  checksum_sha256,
  notes
)
  on table public.municipality_funding_process_document_files
  to authenticated;

grant update (notes)
  on table public.municipality_funding_process_document_files
  to authenticated;

create policy municipality_funding_process_document_files_select
  on public.municipality_funding_process_document_files
  for select
  to authenticated
  using (
    private.has_tenant_metadata_access(municipality_id)
  );

create policy municipality_funding_process_document_files_insert
  on public.municipality_funding_process_document_files
  for insert
  to authenticated
  with check (
    private.can_manage_municipality_funding_process(municipality_id)
  );

create policy municipality_funding_process_document_files_update
  on public.municipality_funding_process_document_files
  for update
  to authenticated
  using (
    private.can_manage_municipality_funding_process(municipality_id)
  )
  with check (
    private.can_manage_municipality_funding_process(municipality_id)
  );

-- DELETE permanece deliberadamente sem grant e sem policy.

create table public.municipality_funding_process_document_file_audit (
  id uuid primary key default gen_random_uuid(),
  funding_process_document_file_id uuid not null,
  municipality_id uuid not null,
  action text not null,
  actor_user_id uuid null
    references auth.users (id)
    on delete set null,
  old_data jsonb null,
  new_data jsonb null,
  created_at timestamptz not null default now(),

  constraint municipality_funding_process_document_file_audit_file_fkey
    foreign key (funding_process_document_file_id, municipality_id)
    references public.municipality_funding_process_document_files (
      id,
      municipality_id
    )
    on delete restrict,

  constraint municipality_funding_process_document_file_audit_action_check
    check (action in ('insert', 'update')),

  constraint municipality_funding_process_document_file_audit_payload_check
    check (
      (
        action = 'insert'
        and old_data is null
        and new_data is not null
      )
      or
      (
        action = 'update'
        and old_data is not null
        and new_data is not null
      )
    )
);

create index municipality_funding_process_document_file_audit_file_idx
  on public.municipality_funding_process_document_file_audit (
    funding_process_document_file_id,
    created_at desc
  );

create index municipality_funding_process_document_file_audit_municipality_idx
  on public.municipality_funding_process_document_file_audit (
    municipality_id,
    created_at desc
  );

create or replace function private.audit_municipality_funding_process_document_file_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.municipality_funding_process_document_file_audit (
      funding_process_document_file_id,
      municipality_id,
      action,
      actor_user_id,
      old_data,
      new_data
    ) values (
      new.id,
      new.municipality_id,
      'insert',
      (select auth.uid()),
      null,
      to_jsonb(new)
    );

    return new;
  end if;

  if tg_op = 'UPDATE' then
    insert into public.municipality_funding_process_document_file_audit (
      funding_process_document_file_id,
      municipality_id,
      action,
      actor_user_id,
      old_data,
      new_data
    ) values (
      new.id,
      new.municipality_id,
      'update',
      (select auth.uid()),
      to_jsonb(old),
      to_jsonb(new)
    );

    return new;
  end if;

  raise exception
    'Operacao de auditoria de arquivo documental nao suportada: %.',
    tg_op;
end;
$$;

revoke all
  on function private.audit_municipality_funding_process_document_file_change()
  from public;

create trigger municipality_funding_process_document_files_audit_insert
  after insert on public.municipality_funding_process_document_files
  for each row
  execute function private.audit_municipality_funding_process_document_file_change();

create trigger municipality_funding_process_document_files_audit_update
  after update on public.municipality_funding_process_document_files
  for each row
  when (old is distinct from new)
  execute function private.audit_municipality_funding_process_document_file_change();

alter table public.municipality_funding_process_document_file_audit
  enable row level security;

alter table public.municipality_funding_process_document_file_audit
  force row level security;

revoke all
  on table public.municipality_funding_process_document_file_audit
  from anon, authenticated;

grant select
  on table public.municipality_funding_process_document_file_audit
  to authenticated;

create policy municipality_funding_process_document_file_audit_select
  on public.municipality_funding_process_document_file_audit
  for select
  to authenticated
  using (
    private.has_tenant_metadata_access(municipality_id)
  );

comment on table public.municipality_funding_process_document_files is
  'Versoes de arquivo vinculadas aos itens documentais dos processos municipais de captacao. O objeto fisico permanece para a etapa de Storage.';

comment on column public.municipality_funding_process_document_files.municipality_id is
  'Tenant derivado do item documental pai; nao e informado pelo cliente.';

comment on column public.municipality_funding_process_document_files.funding_process_document_id is
  'Item de checklist ao qual a versao de arquivo pertence.';

comment on column public.municipality_funding_process_document_files.version_number is
  'Numero monotonico da versao no documento, gerado pelo banco.';

comment on column public.municipality_funding_process_document_files.storage_bucket is
  'Nome logico do bucket futuro; nenhum bucket fisico e criado nesta etapa.';

comment on column public.municipality_funding_process_document_files.storage_object_path is
  'Caminho canonico municipality_id/funding_process_id/document_id/file_id, gerado pelo banco.';

comment on column public.municipality_funding_process_document_files.is_current is
  'Indica a unica versao vigente do item documental.';

comment on table public.municipality_funding_process_document_file_audit is
  'Auditoria imutavel das inclusoes e alteracoes das versoes de arquivo dos processos de captacao.';

commit;
