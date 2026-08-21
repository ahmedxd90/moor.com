-- Enable realtime events for all live-room surfaces.

do $$
begin
  alter publication supabase_realtime add table public.voice_room_members;
exception when duplicate_object then
  null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.room_messages;
exception when duplicate_object then
  null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.room_gifts;
exception when duplicate_object then
  null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.room_seat_reactions;
exception when duplicate_object then
  null;
end $$;
