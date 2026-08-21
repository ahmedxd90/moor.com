# External sources and integration notes

## Official Supabase sources

1. Flutter quickstart: https://supabase.com/docs/guides/getting-started/quickstarts/flutter
   The current guide initializes `supabase_flutter` with the project URL and publishable key, recommends build-time configuration for Flutter, and notes that Android release builds need the INTERNET permission.

2. Flutter client reference: https://supabase.com/docs/reference/dart/introduction
   The current Dart reference documents the `supabase_flutter` client, database queries, Realtime subscriptions, Storage, Auth, and RPC calls.

3. Row Level Security: https://supabase.com/docs/guides/database/postgres/row-level-security
   Exposed tables should have RLS enabled, client roles should receive only required grants, and policies should use `auth.uid()` with explicit authenticated/anon roles.

4. Realtime authorization: https://supabase.com/docs/guides/realtime/authorization
   Private Realtime channels require authorization policies on `realtime.messages`; Postgres Changes are additionally constrained by the table's RLS policies.

## Connected Supabase project observations

The connected project reference is `uhaugikrudchlunaufjj` and its URL is `https://uhaugikrudchlunaufjj.supabase.co`. It is active and healthy. The project already contains migrations and an existing core schema; the first Flutter milestone should use the existing tables rather than applying a duplicate bootstrap schema.

Relevant existing tables for the first milestone include `user_profiles`, `voice_rooms`, `voice_room_members`, `posts`, `stories`, `conversations`, `messages`, and `notifications`. The current `user_profiles` table stores profile fields inside a JSONB `data` column keyed by `auth_user_id`. The current `voice_rooms` table includes `id`, `owner_id`, `name`, `country_code`, `cover_url`, `status`, `metadata`, and `created_at`; `voice_room_members` uses `(room_id, user_id)` as its primary key and includes `role`, `joined_at`, and `left_at`.
