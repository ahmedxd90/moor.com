# Supabase integration

The connected Supabase project already contains the initial Saki schema and migrations. The Flutter app uses the existing `user_profiles`, `voice_rooms`, `voice_room_members`, `posts`, `stories`, `conversations`, `messages`, and `notifications` tables. Do not apply a second bootstrap schema over that project. Add future changes as new migrations after checking the existing schema first.
