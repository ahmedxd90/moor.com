alter table public.user_profiles
  add column if not exists saki_id bigint;

alter table public.user_profiles
  drop constraint if exists user_profiles_saki_id_digits_check;

alter table public.user_profiles
  add constraint user_profiles_saki_id_digits_check
  check (saki_id is null or saki_id between 100000000 and 999999999);

create sequence if not exists public.saki_id_seq
  as bigint
  start with 876431253
  increment by 1
  minvalue 876431253
  maxvalue 999999999
  no cycle;

create unique index if not exists user_profiles_saki_id_unique
  on public.user_profiles (saki_id)
  where saki_id is not null;

create or replace function public.ensure_my_saki_id()
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  result_id bigint;
begin
  if auth.uid() is null then
    raise exception using message = 'not_authenticated';
  end if;

  select saki_id
    into result_id
    from public.user_profiles
   where auth_user_id = auth.uid()
   for update;

  if result_id is null then
    update public.user_profiles
       set saki_id = nextval('public.saki_id_seq'),
           updated_at = now()
     where auth_user_id = auth.uid()
     returning saki_id into result_id;
  end if;

  if result_id is null then
    insert into public.user_profiles (auth_user_id, saki_id, data)
    values (auth.uid(), nextval('public.saki_id_seq'), '{}'::jsonb)
    returning saki_id into result_id;
  end if;

  return result_id;
end;
$$;

revoke all on function public.ensure_my_saki_id() from public;
grant execute on function public.ensure_my_saki_id() to authenticated;
