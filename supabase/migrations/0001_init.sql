-- Pomlist 初始化迁移：To-Do、任务钟、会话任务快照
create extension if not exists pgcrypto;

create table if not exists public.todos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 200),
  subject text,
  notes text,
  priority integer not null default 2 check (priority between 1 and 3),
  due_at timestamptz,
  status text not null default 'pending' check (status in ('pending', 'completed', 'archived')),
  completed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint todos_id_user_unique unique (id, user_id)
);

create table if not exists public.focus_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  state text not null default 'active' check (state in ('active', 'ended')),
  started_at timestamptz not null default timezone('utc', now()),
  ended_at timestamptz,
  elapsed_seconds integer not null default 0 check (elapsed_seconds >= 0),
  total_task_count integer not null default 0 check (total_task_count >= 0),
  completed_task_count integer not null default 0 check (completed_task_count >= 0 and completed_task_count <= total_task_count),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint focus_sessions_ended_requires_end_time check (
    (state = 'active' and ended_at is null)
    or
    (state = 'ended' and ended_at is not null)
  ),
  constraint focus_sessions_id_user_unique unique (id, user_id)
);

create table if not exists public.session_task_refs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  session_id uuid not null,
  todo_id uuid not null,
  title_snapshot text not null check (char_length(btrim(title_snapshot)) between 1 and 200),
  order_index integer not null default 0 check (order_index >= 0),
  is_completed_in_session boolean not null default false,
  completed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint session_task_refs_unique_pair unique (session_id, todo_id),
  constraint session_task_refs_session_owner_fk
    foreign key (session_id, user_id) references public.focus_sessions(id, user_id) on delete cascade,
  constraint session_task_refs_todo_owner_fk
    foreign key (todo_id, user_id) references public.todos(id, user_id) on delete cascade
);

-- 单用户只允许一个 active 任务钟
create unique index if not exists focus_sessions_one_active_per_user_idx
  on public.focus_sessions (user_id)
  where state = 'active';

create index if not exists todos_user_status_idx
  on public.todos (user_id, status);

create index if not exists todos_user_due_at_idx
  on public.todos (user_id, due_at asc);

create index if not exists focus_sessions_user_state_idx
  on public.focus_sessions (user_id, state);

create index if not exists focus_sessions_user_ended_at_idx
  on public.focus_sessions (user_id, ended_at desc);

create index if not exists session_task_refs_user_session_idx
  on public.session_task_refs (user_id, session_id);

create index if not exists session_task_refs_order_idx
  on public.session_task_refs (session_id, order_index asc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists set_updated_at_todos on public.todos;
create trigger set_updated_at_todos
before update on public.todos
for each row
execute procedure public.set_updated_at();

drop trigger if exists set_updated_at_focus_sessions on public.focus_sessions;
create trigger set_updated_at_focus_sessions
before update on public.focus_sessions
for each row
execute procedure public.set_updated_at();

drop trigger if exists set_updated_at_session_task_refs on public.session_task_refs;
create trigger set_updated_at_session_task_refs
before update on public.session_task_refs
for each row
execute procedure public.set_updated_at();

alter table public.todos enable row level security;
alter table public.focus_sessions enable row level security;
alter table public.session_task_refs enable row level security;

drop policy if exists "todos_select_own" on public.todos;
create policy "todos_select_own"
on public.todos
for select
using (user_id = auth.uid());

drop policy if exists "todos_insert_own" on public.todos;
create policy "todos_insert_own"
on public.todos
for insert
with check (user_id = auth.uid());

drop policy if exists "todos_update_own" on public.todos;
create policy "todos_update_own"
on public.todos
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "todos_delete_own" on public.todos;
create policy "todos_delete_own"
on public.todos
for delete
using (user_id = auth.uid());

drop policy if exists "focus_sessions_select_own" on public.focus_sessions;
create policy "focus_sessions_select_own"
on public.focus_sessions
for select
using (user_id = auth.uid());

drop policy if exists "focus_sessions_insert_own" on public.focus_sessions;
create policy "focus_sessions_insert_own"
on public.focus_sessions
for insert
with check (user_id = auth.uid());

drop policy if exists "focus_sessions_update_own" on public.focus_sessions;
create policy "focus_sessions_update_own"
on public.focus_sessions
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "focus_sessions_delete_own" on public.focus_sessions;
create policy "focus_sessions_delete_own"
on public.focus_sessions
for delete
using (user_id = auth.uid());

drop policy if exists "session_task_refs_select_own" on public.session_task_refs;
create policy "session_task_refs_select_own"
on public.session_task_refs
for select
using (user_id = auth.uid());

drop policy if exists "session_task_refs_insert_own" on public.session_task_refs;
create policy "session_task_refs_insert_own"
on public.session_task_refs
for insert
with check (user_id = auth.uid());

drop policy if exists "session_task_refs_update_own" on public.session_task_refs;
create policy "session_task_refs_update_own"
on public.session_task_refs
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "session_task_refs_delete_own" on public.session_task_refs;
create policy "session_task_refs_delete_own"
on public.session_task_refs
for delete
using (user_id = auth.uid());

grant select, insert, update, delete on public.todos to authenticated;
grant select, insert, update, delete on public.focus_sessions to authenticated;
grant select, insert, update, delete on public.session_task_refs to authenticated;

