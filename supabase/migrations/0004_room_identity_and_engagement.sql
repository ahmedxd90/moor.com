-- Numeric room identity and engagement history for the Flutter home feed.

create sequence if not exists public.room_id_seq
  as bigint
  start with 412976435
  increment by 1
  minvalue 100000000
  maxvalue 999999999
  no cycle;

alter table public.voice_rooms
  add column if not exists room_id bigint;

update public.voice_rooms
set room_id = nextval('public.room_id_seq')
where room_id is null;

alter table public.voice_rooms
  alter column room_id set default nextval('public.room_id_seq');

alter table public.voice_rooms
  alter column room_id set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'voice_rooms_room_id_six_to_nine_digits_check'
      and conrelid = 'public.voice_rooms'::regclass
  ) then
    alter table public.voice_rooms
      add constraint voice_rooms_room_id_six_to_nine_digits_check
      check (room_id >= 100000000 and room_id <= 999999999);
  end if;
end;
$$;

create unique index if not exists voice_rooms_room_id_unique
  on public.voice_rooms (room_id);

create table if not exists public.room_follows (
  room_id uuid not null references public.voice_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

create table if not exists public.room_visits (
  room_id uuid not null references public.voice_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  last_visited_at timestamptz not null default now(),
  visit_count integer not null default 1,
  primary key (room_id, user_id)
);

create index if not exists room_follows_user_created_idx
  on public.room_follows (user_id, created_at desc);

create index if not exists room_visits_user_last_visited_idx
  on public.room_visits (user_id, last_visited_at desc);

alter table public.room_follows enable row level security;
alter table public.room_visits enable row level security;

drop policy if exists room_follows_select_own on public.room_follows;
create policy room_follows_select_own
  on public.room_follows for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists room_follows_insert_own on public.room_follows;
create policy room_follows_insert_own
  on public.room_follows for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists room_follows_delete_own on public.room_follows;
create policy room_follows_delete_own
  on public.room_follows for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists room_visits_select_own on public.room_visits;
create policy room_visits_select_own
  on public.room_visits for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists room_visits_insert_own on public.room_visits;
create policy room_visits_insert_own
  on public.room_visits for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists room_visits_update_own on public.room_visits;
create policy room_visits_update_own
  on public.room_visits for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
