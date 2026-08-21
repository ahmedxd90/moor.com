-- Realtime for user invitations and direct conversations.

do $$
begin
  begin
    alter publication supabase_realtime add table public.room_seat_invites;
  exception when duplicate_object then
    null;
  end;
  begin
    alter publication supabase_realtime add table public.direct_messages;
  exception when duplicate_object then
    null;
  end;
end;
$$;
