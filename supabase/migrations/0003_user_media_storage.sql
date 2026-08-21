insert into storage.buckets (id, name, public)
values ('user-media', 'user-media', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "user media upload own folder" on storage.objects;
drop policy if exists "user media update own folder" on storage.objects;
drop policy if exists "user media delete own folder" on storage.objects;
drop policy if exists "user media read own folder" on storage.objects;

create policy "user media upload own folder"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'user-media'
  and split_part(name, '/', 1) = auth.uid()::text
);

create policy "user media update own folder"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'user-media'
  and split_part(name, '/', 1) = auth.uid()::text
)
with check (
  bucket_id = 'user-media'
  and split_part(name, '/', 1) = auth.uid()::text
);

create policy "user media delete own folder"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'user-media'
  and split_part(name, '/', 1) = auth.uid()::text
);

create policy "user media read own folder"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'user-media'
  and split_part(name, '/', 1) = auth.uid()::text
);
