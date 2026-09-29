-- ETAPA 20.3.19
-- Documentos e Checklist do Processo de Captacao
-- Estrutura multi-tenant para controlar exigencias documentais,
-- departamentos, responsaveis, prazos, validade e situacao.
-- Os arquivos fisicos/Storage serao tratados em camada propria.

begin;

create table public.municipality_funding_process_documents (
  id uuid primary key default gen_random_uuid(),

  municipality_id uuid not null,

  funding_process_id uuid not null,

  responsible_department_id uuid null,

  responsible_membership_id uuid null,

  document_name text not null,

  description text null,

  document_type text not null default 'other',

  is_required boolean not null default true,

  status text not null default 'pending',

  due_date date null,

  issued_at date null,

  expires_at date null,

  notes text null,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now(),

  constraint municipality_funding_process_documents_process_tenant_fkey
    foreign key (funding_process_id, municipality_id)
    references public.municipality_funding_processes (id, municipality_id)
    on delete cascade,

  constraint municipality_funding_process_documents_department_tenant_fkey
    foreign key (responsible_department_id, municipality_id)
    references public.municipality_departments (id, municipality_id)
    on delete restrict,

  constraint municipality_funding_process_documents_responsible_tenant_fkey
    foreign key (responsible_membership_id, municipality_id)
    references public.municipality_members (id, municipality_id)
    on delete restrict,

  constraint municipality_funding_process_documents_name_check
    check (
      char_length(btrim(document_name)) between 1 and 240
    ),

  constraint municipality_funding_process_documents_description_check
    check (
      description is null
      or char_length(btrim(description)) between 1 and 2000
    ),

  constraint municipality_funding_process_documents_type_check
    check (
      document_type in (
        'certificate',
        'declaration',
        'project',
        'budget',
        'technical',
        'legal',
        'accounting',
        'engineering',
        'authorization',
        'identification',
        'other'
      )
    ),

  constraint municipality_funding_process_documents_status_check
    check (
      status in (
        'pending',
        'requested',
        'received',
        'validated',
        'rejected',
        'waived'
      )
    ),

  constraint municipality_funding_process_documents_dates_check
    check (
      expires_at is null
      or issued_at is null
      or expires_at >= issued_at
    ),

  constraint municipality_funding_process_documents_notes_check
    check (
      notes is null
      or char_length(btrim(notes)) between 1 and 4000
    ),

  constraint municipality_funding_process_documents_id_municipality_key
    unique (id, municipality_id)
);

create index municipality_funding_process_documents_process_status_idx
  on public.municipality_funding_process_documents (
    funding_process_id,
    status
  );

create index municipality_funding_process_documents_municipality_due_idx
  on public.municipality_funding_process_documents (
    municipality_id,
    due_date
  )
  where due_date is not null;

create index municipality_funding_process_documents_expiration_idx
  on public.municipality_funding_process_documents (
    municipality_id,
    expires_at
  )
  where expires_at is not null;

create index municipality_funding_process_documents_department_idx
  on public.municipality_funding_process_documents (
    responsible_department_id,
    status
  )
  where responsible_department_id is not null;

create index municipality_funding_process_documents_responsible_idx
  on public.municipality_funding_process_documents (
    responsible_membership_id,
    status
  )
  where responsible_membership_id is not null;

-- Atualiza updated_at automaticamente.
create trigger municipality_funding_process_documents_touch_updated_at
  before update on public.municipality_funding_process_documents
  for each row
  execute function private.touch_updated_at();

-- Valida INSERT do item documental.
create or replace function private.validate_municipality_funding_process_document_insert()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
begin
  -- Se houver departamento responsavel, ele precisa estar ativo.
  if new.responsible_department_id is not null then
    if not exists (
      select 1
      from public.municipality_departments d
      where d.id = new.responsible_department_id
        and d.municipality_id = new.municipality_id
        and d.status = 'active'
    ) then
      raise exception
        'O departamento responsavel deve estar ativo e pertencer ao mesmo municipio.';
    end if;
  end if;

  -- Se houver servidor responsavel, sua membership precisa estar ativa.
  if new.responsible_membership_id is not null then
    if not exists (
      select 1
      from public.municipality_members mm
      where mm.id = new.responsible_membership_id
        and mm.municipality_id = new.municipality_id
        and mm.status = 'active'
    ) then
      raise exception
        'O responsavel deve possuir membership ativa no mesmo municipio.';
    end if;
  end if;

  return new;
end;
$$;

create trigger municipality_funding_process_documents_validate_insert
  before insert on public.municipality_funding_process_documents
  for each row
  execute function private.validate_municipality_funding_process_document_insert();

-- Valida UPDATE e protege os campos estruturais.
create or replace function private.validate_municipality_funding_process_document_update()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
begin
  if new.municipality_id is distinct from old.municipality_id then
    raise exception
      'municipality_id do documento do processo e imutavel.';
  end if;

  if new.funding_process_id is distinct from old.funding_process_id then
    raise exception
      'funding_process_id do documento do processo e imutavel.';
  end if;

  if new.responsible_department_id is not null then
    if not exists (
      select 1
      from public.municipality_departments d
      where d.id = new.responsible_department_id
        and d.municipality_id = new.municipality_id
        and d.status = 'active'
    ) then
      raise exception
        'O departamento responsavel deve estar ativo e pertencer ao mesmo municipio.';
    end if;
  end if;

  if new.responsible_membership_id is not null then
    if not exists (
      select 1
      from public.municipality_members mm
      where mm.id = new.responsible_membership_id
        and mm.municipality_id = new.municipality_id
        and mm.status = 'active'
    ) then
      raise exception
        'O responsavel deve possuir membership ativa no mesmo municipio.';
    end if;
  end if;

  return new;
end;
$$;

create trigger municipality_funding_process_documents_validate_update
  before update on public.municipality_funding_process_documents
  for each row
  execute function private.validate_municipality_funding_process_document_update();

-- RLS e privilegios.
alter table public.municipality_funding_process_documents
  enable row level security;

alter table public.municipality_funding_process_documents
  force row level security;

revoke all
  on table public.municipality_funding_process_documents
  from anon, authenticated;

grant select
  on table public.municipality_funding_process_documents
  to authenticated;

grant insert (
  municipality_id,
  funding_process_id,
  responsible_department_id,
  responsible_membership_id,
  document_name,
  description,
  document_type,
  is_required,
  status,
  due_date,
  issued_at,
  expires_at,
  notes
)
  on table public.municipality_funding_process_documents
  to authenticated;

grant update (
  responsible_department_id,
  responsible_membership_id,
  document_name,
  description,
  document_type,
  is_required,
  status,
  due_date,
  issued_at,
  expires_at,
  notes
)
  on table public.municipality_funding_process_documents
  to authenticated;

-- Leitura apenas para usuarios com acesso aos metadados do tenant.
create policy municipality_funding_process_documents_select
  on public.municipality_funding_process_documents
  for select
  to authenticated
  using (
    private.has_tenant_metadata_access(municipality_id)
  );

-- Criacao somente por quem pode administrar o processo de captacao.
create policy municipality_funding_process_documents_insert
  on public.municipality_funding_process_documents
  for insert
  to authenticated
  with check (
    private.can_manage_municipality_funding_process(municipality_id)
  );

-- Alteracao somente por quem pode administrar o processo de captacao.
create policy municipality_funding_process_documents_update
  on public.municipality_funding_process_documents
  for update
  to authenticated
  using (
    private.can_manage_municipality_funding_process(municipality_id)
  )
  with check (
    private.can_manage_municipality_funding_process(municipality_id)
  );

-- DELETE permanece deliberadamente sem grant e sem policy.
-- O historico documental nao deve desaparecer por exclusao comum.

-- Auditoria imutavel dos itens documentais.
create table public.municipality_funding_process_document_audit (
  id uuid primary key default gen_random_uuid(),

  funding_process_document_id uuid not null,

  municipality_id uuid not null,

  action text not null,

  actor_user_id uuid null
    references auth.users (id)
    on delete set null,

  old_data jsonb null,

  new_data jsonb null,

  created_at timestamptz not null default now(),

  constraint municipality_funding_process_document_audit_document_fkey
    foreign key (funding_process_document_id, municipality_id)
    references public.municipality_funding_process_documents (
      id,
      municipality_id
    )
    on delete restrict,

  constraint municipality_funding_process_document_audit_action_check
    check (
      action in ('insert', 'update')
    ),

  constraint municipality_funding_process_document_audit_payload_check
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

create index municipality_funding_process_document_audit_document_idx
  on public.municipality_funding_process_document_audit (
    funding_process_document_id,
    created_at desc
  );

create index municipality_funding_process_document_audit_municipality_idx
  on public.municipality_funding_process_document_audit (
    municipality_id,
    created_at desc
  );

create or replace function private.audit_municipality_funding_process_document_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.municipality_funding_process_document_audit (
      funding_process_document_id,
      municipality_id,
      action,
      actor_user_id,
      old_data,
      new_data
    ) values (
      new.id,
      new.municipality_id,
      'insert',
      auth.uid(),
      null,
      to_jsonb(new)
    );

    return new;
  end if;

  if tg_op = 'UPDATE' then
    insert into public.municipality_funding_process_document_audit (
      funding_process_document_id,
      municipality_id,
      action,
      actor_user_id,
      old_data,
      new_data
    ) values (
      new.id,
      new.municipality_id,
      'update',
      auth.uid(),
      to_jsonb(old),
      to_jsonb(new)
    );

    return new;
  end if;

  raise exception
    'Operacao de auditoria documental nao suportada: %.',
    tg_op;
end;
$$;

create trigger municipality_funding_process_documents_audit_insert
  after insert on public.municipality_funding_process_documents
  for each row
  execute function private.audit_municipality_funding_process_document_change();

create trigger municipality_funding_process_documents_audit_update
  after update on public.municipality_funding_process_documents
  for each row
  when (old is distinct from new)
  execute function private.audit_municipality_funding_process_document_change();

-- A auditoria pode ser consultada pelo tenant, mas nunca alterada diretamente.
alter table public.municipality_funding_process_document_audit
  enable row level security;

alter table public.municipality_funding_process_document_audit
  force row level security;

revoke all
  on table public.municipality_funding_process_document_audit
  from anon, authenticated;

grant select
  on table public.municipality_funding_process_document_audit
  to authenticated;

create policy municipality_funding_process_document_audit_select
  on public.municipality_funding_process_document_audit
  for select
  to authenticated
  using (
    private.has_tenant_metadata_access(municipality_id)
  );

-- Sem INSERT, UPDATE ou DELETE para authenticated.
-- Os registros desta tabela sao produzidos exclusivamente pelo trigger.

-- Documentacao do schema.
comment on table public.municipality_funding_process_documents is
  'Checklist documental dos processos de captacao municipais. Controla exigencias, responsaveis, departamentos, prazos, validade e status sem armazenar o arquivo fisico.';

comment on column public.municipality_funding_process_documents.municipality_id is
  'Tenant proprietario do item documental.';

comment on column public.municipality_funding_process_documents.funding_process_id is
  'Processo de captacao ao qual o item documental pertence.';

comment on column public.municipality_funding_process_documents.responsible_department_id is
  'Departamento municipal responsavel pelo fornecimento ou acompanhamento do documento.';

comment on column public.municipality_funding_process_documents.responsible_membership_id is
  'Membership ativa do usuario responsavel pelo item documental.';

comment on column public.municipality_funding_process_documents.document_name is
  'Nome funcional do documento ou exigencia documental.';

comment on column public.municipality_funding_process_documents.document_type is
  'Categoria funcional do documento para organizacao, filtros e automacoes futuras.';

comment on column public.municipality_funding_process_documents.is_required is
  'Indica se o documento e obrigatorio para o processo.';

comment on column public.municipality_funding_process_documents.status is
  'Situacao operacional do item: pending, requested, received, validated, rejected ou waived.';

comment on column public.municipality_funding_process_documents.due_date is
  'Prazo interno para obtencao, entrega ou regularizacao do documento.';

comment on column public.municipality_funding_process_documents.issued_at is
  'Data de emissao do documento apresentado, quando aplicavel.';

comment on column public.municipality_funding_process_documents.expires_at is
  'Data de validade do documento apresentado, quando aplicavel.';

comment on table public.municipality_funding_process_document_audit is
  'Auditoria imutavel das inclusoes e alteracoes dos itens documentais dos processos de captacao.';

commit;
