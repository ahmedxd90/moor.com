-- Live room features: seats, chat messages, gifts, reactions, and owner settings.

alter table public.voice_room_members
  add column if not exists seat_index integer,
  add column if not exists is_muted boolean not null default false,
  add column if not exists is_speaking boolean not null default false;

create index if not exists voice_room_members_room_active_idx
  on public.voice_room_members (room_id, seat_index)
  where left_at is null;

create table if not exists public.room_messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.voice_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null,
  message_type text not null default 'text',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists room_messages_room_created_idx
  on public.room_messages (room_id, created_at desc);

create table if not exists public.room_gifts (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.voice_rooms(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  receiver_id uuid references auth.users(id) on delete set null,
  gift_type text not null default 'rose',
  quantity integer not null default 1 check (quantity > 0 and quantity <= 99),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists room_gifts_room_created_idx
  on public.room_gifts (room_id, created_at desc);

create table if not exists public.room_seat_reactions (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.voice_rooms(id) on delete cascade,
  seat_index integer not null check (seat_index >= 0 and seat_index <= 49),
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction text not null,
  created_at timestamptz not null default now()
);

create index if not exists room_seat_reactions_room_created_idx
  on public.room_seat_reactions (room_id, created_at desc);

alter table public.room_messages enable row level security;
alter table public.room_gifts enable row level security;
alter table public.room_seat_reactions enable row level security;

-- Active members are visible inside a room; users can only join/update their own row.
drop policy if exists voice_room_members_select_active on public.voice_room_members;
create policy voice_room_members_select_active
  on public.voice_room_members for select
  to authenticated
  using (left_at is null);

drop policy if exists voice_room_members_insert_own on public.voice_room_members;
create policy voice_room_members_insert_own
  on public.voice_room_members for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists voice_room_members_update_own_or_owner on public.voice_room_members;
create policy voice_room_members_update_own_or_owner
  on public.voice_room_members for update
  to authenticated
  using (
    auth.uid() = user_id
    or exists (
      select 1 from public.voice_rooms
      where voice_rooms.id = voice_room_members.room_id
        and voice_rooms.owner_id = auth.uid()
    )
  )
  with check (
    auth.uid() = user_id
    or exists (
      select 1 from public.voice_rooms
      where voice_rooms.id = voice_room_members.room_id
        and voice_rooms.owner_id = auth.uid()
    )
  );

drop policy if exists voice_room_members_delete_own_or_owner on public.voice_room_members;
create policy voice_room_members_delete_own_or_owner
  on public.voice_room_members for delete
  to authenticated
  using (
    auth.uid() = user_id
    or exists (
      select 1 from public.voice_rooms
      where voice_rooms.id = voice_room_members.room_id
        and voice_rooms.owner_id = auth.uid()
    )
  );

drop policy if exists room_messages_select_authenticated on public.room_messages;
create policy room_messages_select_authenticated
  on public.room_messages for select
  to authenticated
  using (true);

drop policy if exists room_messages_insert_own on public.room_messages;
create policy room_messages_insert_own
  on public.room_messages for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists room_messages_update_own on public.room_messages;
create policy room_messages_update_own
  on public.room_messages for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists room_messages_delete_own on public.room_messages;
create policy room_messages_delete_own
  on public.room_messages for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists room_gifts_select_authenticated on public.room_gifts;
create policy room_gifts_select_authenticated
  on public.room_gifts for select
  to authenticated
  using (true);

drop policy if exists room_gifts_insert_own on public.room_gifts;
create policy room_gifts_insert_own
  on public.room_gifts for insert
  to authenticated
  with check (auth.uid() = sender_id);

drop policy if exists room_seat_reactions_select_authenticated on public.room_seat_reactions;
create policy room_seat_reactions_select_authenticated
  on public.room_seat_reactions for select
  to authenticated
  using (true);

drop policy if exists room_seat_reactions_insert_own on public.room_seat_reactions;
create policy room_seat_reactions_insert_own
  on public.room_seat_reactions for insert
  to authenticated
  with check (auth.uid() = user_id);

-- Default room settings are stored alongside the room to preserve compatibility with existing rows.
update public.voice_rooms
set metadata = jsonb_set(
  jsonb_set(
    coalesce(metadata, '{}'::jsonb),
    '{seat_count}',
    to_jsonb(coalesce((metadata->>'seat_count')::integer, 10)),
    true
  ),
  '{settings}',
  coalesce(metadata->'settings', '{"allow_member_mic": false, "announcement": "", "member_fee": 0}'::jsonb),
  true
)
where metadata is null
   or not (metadata ? 'seat_count')
   or not (metadata ? 'settings');
