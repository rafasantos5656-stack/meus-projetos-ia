begin;

create extension if not exists pgcrypto;

create table public.projects (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references auth.users (id)
    on delete cascade,

  name text not null
    check (char_length(btrim(name)) > 0),

  description text not null
    check (char_length(btrim(description)) > 0),

  objective text not null
    check (char_length(btrim(objective)) > 0),

  status text not null default 'Ideia'
    check (status in ('Ideia', 'Em andamento', 'Pausado', 'Concluído')),

  priority text not null default 'Média'
    check (priority in ('Baixa', 'Média', 'Alta')),

  project_date date not null,

  category text null
    check (
      category is null
      or category in (
        'APEX Estratégia',
        'Âncora Gestão Pública',
        'Projetos de IA',
        'Clientes',
        'Pessoal',
        'Outros'
      )
    ),

  client_name text null
    check (
      client_name is null
      or char_length(btrim(client_name)) between 1 and 120
    ),

  responsible text null
    check (
      responsible is null
      or char_length(btrim(responsible)) between 1 and 120
    ),

  tags text[] null
    check (tags is null or cardinality(tags) <= 10),

  legacy_id text null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint projects_id_user_id_key unique (id, user_id)
);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),

  project_id uuid not null,

  user_id uuid not null
    references auth.users (id)
    on delete cascade,

  description text not null
    check (char_length(btrim(description)) > 0),

  completed boolean not null default false,
  due_date date null,
  legacy_id text null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint tasks_project_owner_fkey
    foreign key (project_id, user_id)
    references public.projects (id, user_id)
    on delete cascade
);

create unique index projects_user_legacy_id_unique
  on public.projects (user_id, legacy_id)
  where legacy_id is not null;

create unique index tasks_user_legacy_id_unique
  on public.tasks (user_id, legacy_id)
  where legacy_id is not null;

create index projects_user_created_at_idx
  on public.projects (user_id, created_at desc);

create index tasks_user_created_at_idx
  on public.tasks (user_id, created_at asc);

create index tasks_project_user_created_at_idx
  on public.tasks (project_id, user_id, created_at asc);

create or replace function public.legacy_touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger legacy_projects_touch_updated_at
  before update on public.projects
  for each row
  execute function public.legacy_touch_updated_at();

create trigger legacy_tasks_touch_updated_at
  before update on public.tasks
  for each row
  execute function public.legacy_touch_updated_at();

revoke all on table public.projects from anon;
revoke all on table public.tasks from anon;

grant select, insert, update, delete
  on table public.projects to authenticated;

grant select, insert, update, delete
  on table public.tasks to authenticated;

alter table public.projects enable row level security;
alter table public.tasks enable row level security;

create policy legacy_projects_select_own
  on public.projects
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy legacy_projects_insert_own
  on public.projects
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy legacy_projects_update_own
  on public.projects
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy legacy_projects_delete_own
  on public.projects
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

create policy legacy_tasks_select_own
  on public.tasks
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy legacy_tasks_insert_own
  on public.tasks
  for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1
      from public.projects project
      where project.id = project_id
        and project.user_id = (select auth.uid())
    )
  );

create policy legacy_tasks_update_own
  on public.tasks
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1
      from public.projects project
      where project.id = project_id
        and project.user_id = (select auth.uid())
    )
  );

create policy legacy_tasks_delete_own
  on public.tasks
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

commit;