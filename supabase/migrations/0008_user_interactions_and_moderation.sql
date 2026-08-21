-- User profiles, social actions, owner moderation, seat invites, reports, and direct chat.

create table if not exists public.user_follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  following_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);

create table if not exists public.room_moderators (
  room_id uuid not null references public.voice_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  assigned_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

create table if not exists public.room_bans (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.voice_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete restrict,
  reason text not null default '',
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  unique (room_id, user_id)
);

create table if not exists public.room_chat_mutes (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.voice_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete restrict,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  unique (room_id, user_id)
);

create table if not exists public.room_seat_invites (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.voice_rooms(id) on delete cascade,
  inviter_id uuid not null references auth.users(id) on delete cascade,
  invitee_id uuid not null references auth.users(id) on delete cascade,
  seat_index integer not null check (seat_index >= 0 and seat_index <= 49),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected', 'expired')),
  expires_at timestamptz not null default (now() + interval '5 minutes'),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (inviter_id <> invitee_id)
);

create index if not exists room_seat_invites_recipient_idx
  on public.room_seat_invites (invitee_id, status, created_at desc);

create table if not exists public.user_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  target_user_id uuid not null references auth.users(id) on delete cascade,
  room_id uuid references public.voice_rooms(id) on delete set null,
  reason text not null default '',
  status text not null default 'open' check (status in ('open', 'reviewed', 'closed')),
  created_at timestamptz not null default now()
);

create table if not exists public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  receiver_id uuid not null references auth.users(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  check (sender_id <> receiver_id)
);

create index if not exists direct_messages_pair_created_idx
  on public.direct_messages (sender_id, receiver_id, created_at desc);
create index if not exists direct_messages_receiver_created_idx
  on public.direct_messages (receiver_id, created_at desc);

create or replace function public.is_room_owner_or_moderator(
  p_room_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1 from public.voice_rooms
    where id = p_room_id and owner_id = p_user_id
  ) or exists (
    select 1 from public.room_moderators
    where room_id = p_room_id and user_id = p_user_id
  );
$$;

create or replace function public.is_room_banned(
  p_room_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1 from public.room_bans
    where room_id = p_room_id
      and user_id = p_user_id
      and (expires_at is null or expires_at > now())
  );
$$;

create or replace function public.is_room_chat_muted(
  p_room_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1 from public.room_chat_mutes
    where room_id = p_room_id
      and user_id = p_user_id
      and (expires_at is null or expires_at > now())
  );
$$;

create or replace function public.set_room_moderator(
  p_room_id uuid,
  p_user_id uuid,
  p_enabled boolean
)
returns boolean
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  if not exists (
    select 1 from public.voice_rooms
    where id = p_room_id and owner_id = auth.uid()
  ) then
    raise exception 'owner_only';
  end if;
  if p_enabled then
    insert into public.room_moderators(room_id, user_id, assigned_by)
    values (p_room_id, p_user_id, auth.uid())
    on conflict (room_id, user_id) do update set assigned_by = excluded.assigned_by;
  else
    delete from public.room_moderators
    where room_id = p_room_id and user_id = p_user_id;
  end if;
  return p_enabled;
end;
$$;

create or replace function public.send_room_seat_invite(
  p_room_id uuid,
  p_invitee_id uuid,
  p_seat_index integer
)
returns uuid
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_id uuid;
  v_seat_count integer;
begin
  if not public.is_room_owner_or_moderator(p_room_id, auth.uid()) then
    raise exception 'moderator_only';
  end if;
  select coalesce((metadata->>'seat_count')::integer, 10)
    into v_seat_count
  from public.voice_rooms where id = p_room_id;
  if p_seat_index < 0 or p_seat_index >= v_seat_count then
    raise exception 'invalid_seat';
  end if;
  if exists (
    select 1 from public.voice_room_members
    where room_id = p_room_id and seat_index = p_seat_index and left_at is null
  ) then
    raise exception 'seat_occupied';
  end if;
  insert into public.room_seat_invites(room_id, inviter_id, invitee_id, seat_index)
  values (p_room_id, auth.uid(), p_invitee_id, p_seat_index)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.respond_room_seat_invite(
  p_invite_id uuid,
  p_accept boolean
)
returns boolean
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_invite public.room_seat_invites%rowtype;
begin
  select * into v_invite
  from public.room_seat_invites
  where id = p_invite_id and invitee_id = auth.uid()
  for update;
  if not found or v_invite.status <> 'pending' then
    raise exception 'invite_not_pending';
  end if;
  if v_invite.expires_at <= now() then
    update public.room_seat_invites set status = 'expired', responded_at = now()
    where id = p_invite_id;
    return false;
  end if;
  if not p_accept then
    update public.room_seat_invites set status = 'rejected', responded_at = now()
    where id = p_invite_id;
    return false;
  end if;
  if exists (
    select 1 from public.voice_room_members
    where room_id = v_invite.room_id
      and seat_index = v_invite.seat_index
      and left_at is null
  ) then
    raise exception 'seat_occupied';
  end if;
  update public.voice_room_members
  set seat_index = v_invite.seat_index, is_muted = false, is_speaking = true
  where room_id = v_invite.room_id and user_id = auth.uid() and left_at is null;
  if not found then
    raise exception 'member_not_in_room';
  end if;
  update public.room_seat_invites set status = 'accepted', responded_at = now()
  where id = p_invite_id;
  return true;
end;
$$;

alter table public.user_follows enable row level security;
alter table public.room_moderators enable row level security;
alter table public.room_bans enable row level security;
alter table public.room_chat_mutes enable row level security;
alter table public.room_seat_invites enable row level security;
alter table public.user_reports enable row level security;
alter table public.direct_messages enable row level security;

drop policy if exists user_follows_select_own on public.user_follows;
create policy user_follows_select_own on public.user_follows for select to authenticated
  using (auth.uid() = follower_id or auth.uid() = following_id);
drop policy if exists user_follows_insert_own on public.user_follows;
create policy user_follows_insert_own on public.user_follows for insert to authenticated
  with check (auth.uid() = follower_id and follower_id <> following_id);
drop policy if exists user_follows_delete_own on public.user_follows;
create policy user_follows_delete_own on public.user_follows for delete to authenticated
  using (auth.uid() = follower_id);

drop policy if exists room_moderators_select_authenticated on public.room_moderators;
create policy room_moderators_select_authenticated on public.room_moderators for select to authenticated
  using (true);
drop policy if exists room_moderators_manage_owner on public.room_moderators;
create policy room_moderators_manage_owner on public.room_moderators for all to authenticated
  using (exists (select 1 from public.voice_rooms r where r.id = public.room_moderators.room_id and r.owner_id = auth.uid()))
  with check (exists (select 1 from public.voice_rooms r where r.id = public.room_moderators.room_id and r.owner_id = auth.uid()));

drop policy if exists room_bans_select_authenticated on public.room_bans;
create policy room_bans_select_authenticated on public.room_bans for select to authenticated using (true);
drop policy if exists room_bans_manage_moderator on public.room_bans;
create policy room_bans_manage_moderator on public.room_bans for all to authenticated
  using (public.is_room_owner_or_moderator(room_id, auth.uid()))
  with check (public.is_room_owner_or_moderator(room_id, auth.uid()) and auth.uid() = created_by);

drop policy if exists room_chat_mutes_select_authenticated on public.room_chat_mutes;
create policy room_chat_mutes_select_authenticated on public.room_chat_mutes for select to authenticated using (true);
drop policy if exists room_chat_mutes_manage_moderator on public.room_chat_mutes;
create policy room_chat_mutes_manage_moderator on public.room_chat_mutes for all to authenticated
  using (public.is_room_owner_or_moderator(room_id, auth.uid()))
  with check (public.is_room_owner_or_moderator(room_id, auth.uid()) and auth.uid() = created_by);

drop policy if exists room_seat_invites_select_participants on public.room_seat_invites;
create policy room_seat_invites_select_participants on public.room_seat_invites for select to authenticated
  using (auth.uid() = invitee_id or auth.uid() = inviter_id or public.is_room_owner_or_moderator(room_id, auth.uid()));
drop policy if exists room_seat_invites_insert_moderator on public.room_seat_invites;
create policy room_seat_invites_insert_moderator on public.room_seat_invites for insert to authenticated
  with check (public.is_room_owner_or_moderator(room_id, auth.uid()) and auth.uid() = inviter_id);
drop policy if exists room_seat_invites_update_recipient on public.room_seat_invites;
create policy room_seat_invites_update_recipient on public.room_seat_invites for update to authenticated
  using (auth.uid() = invitee_id or public.is_room_owner_or_moderator(room_id, auth.uid()))
  with check (auth.uid() = invitee_id or public.is_room_owner_or_moderator(room_id, auth.uid()));

drop policy if exists user_reports_insert_own on public.user_reports;
create policy user_reports_insert_own on public.user_reports for insert to authenticated
  with check (auth.uid() = reporter_id and reporter_id <> target_user_id);
drop policy if exists user_reports_select_own on public.user_reports;
create policy user_reports_select_own on public.user_reports for select to authenticated
  using (auth.uid() = reporter_id);

drop policy if exists direct_messages_select_participant on public.direct_messages;
create policy direct_messages_select_participant on public.direct_messages for select to authenticated
  using (auth.uid() = sender_id or auth.uid() = receiver_id);
drop policy if exists direct_messages_insert_sender on public.direct_messages;
create policy direct_messages_insert_sender on public.direct_messages for insert to authenticated
  with check (auth.uid() = sender_id and sender_id <> receiver_id);
drop policy if exists direct_messages_update_sender on public.direct_messages;
create policy direct_messages_update_sender on public.direct_messages for update to authenticated
  using (auth.uid() = sender_id or auth.uid() = receiver_id)
  with check (auth.uid() = sender_id or auth.uid() = receiver_id);
drop policy if exists direct_messages_delete_sender on public.direct_messages;
create policy direct_messages_delete_sender on public.direct_messages for delete to authenticated
  using (auth.uid() = sender_id);

drop policy if exists voice_room_members_insert_own on public.voice_room_members;
create policy voice_room_members_insert_own on public.voice_room_members for insert to authenticated
  with check (auth.uid() = user_id and not public.is_room_banned(room_id, auth.uid()));
drop policy if exists voice_room_members_update_own_or_owner on public.voice_room_members;
create policy voice_room_members_update_own_or_owner on public.voice_room_members for update to authenticated
  using (
    (auth.uid() = user_id and not public.is_room_banned(room_id, auth.uid()))
    or public.is_room_owner_or_moderator(room_id, auth.uid())
  )
  with check (
    (auth.uid() = user_id and not public.is_room_banned(room_id, auth.uid()))
    or public.is_room_owner_or_moderator(room_id, auth.uid())
  );

drop policy if exists room_messages_insert_own on public.room_messages;
create policy room_messages_insert_own on public.room_messages for insert to authenticated
  with check (auth.uid() = user_id and not public.is_room_banned(room_id, auth.uid()) and not public.is_room_chat_muted(room_id, auth.uid()));
