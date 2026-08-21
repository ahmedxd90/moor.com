-- Gift catalog, wallet balance, secure gift sending, and room rankings.

create table if not exists public.room_gift_catalog (
  gift_type text primary key,
  display_name text not null,
  category text not null default 'general',
  price integer not null check (price > 0),
  emoji text not null,
  asset_url text,
  is_active boolean not null default true
);

insert into public.room_gift_catalog (gift_type, display_name, category, price, emoji)
values
  ('rose', 'وردة', 'general', 10, '🌹'),
  ('heart', 'قلب', 'general', 50, '💖'),
  ('coffee', 'قهوة', 'general', 100, '☕'),
  ('crown', 'تاج', 'famous', 500, '👑'),
  ('diamond', 'ماسة', 'famous', 1000, '💎'),
  ('car', 'سيارة', 'famous', 2500, '🏎️'),
  ('saudi', 'علم السعودية', 'countries', 300, '🇸🇦'),
  ('uae', 'علم الإمارات', 'countries', 300, '🇦🇪'),
  ('egypt', 'علم مصر', 'countries', 300, '🇪🇬'),
  ('love_cp', 'ثنائي الحب', 'cp', 800, '💞'),
  ('ring', 'خاتم', 'cp', 1500, '💍'),
  ('bag', 'حقيبة ذهبية', 'bag', 5000, '👜')
on conflict (gift_type) do update set
  display_name = excluded.display_name,
  category = excluded.category,
  price = excluded.price,
  emoji = excluded.emoji,
  is_active = true;

alter table public.room_gifts
  add column if not exists unit_price integer not null default 0;

create table if not exists public.room_wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  gold_coins bigint not null default 0 check (gold_coins >= 0),
  updated_at timestamptz not null default now()
);

create index if not exists room_wallets_updated_idx
  on public.room_wallets (updated_at desc);

alter table public.room_gift_catalog enable row level security;
alter table public.room_wallets enable row level security;

drop policy if exists room_gift_catalog_select_authenticated on public.room_gift_catalog;
create policy room_gift_catalog_select_authenticated
  on public.room_gift_catalog for select
  to authenticated
  using (is_active = true);

drop policy if exists room_wallets_select_own on public.room_wallets;
create policy room_wallets_select_own
  on public.room_wallets for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists room_wallets_insert_own on public.room_wallets;
create policy room_wallets_insert_own
  on public.room_wallets for insert
  to authenticated
  with check (auth.uid() = user_id and gold_coins = 0);

drop policy if exists room_wallets_update_own on public.room_wallets;
create policy room_wallets_update_own
  on public.room_wallets for update
  to authenticated
  using (false)
  with check (false);

-- Gift rows are created through send_room_gift so the wallet is charged atomically.
drop policy if exists room_gifts_insert_own on public.room_gifts;
create policy room_gifts_insert_own
  on public.room_gifts for insert
  to authenticated
  with check (false);

create or replace function public.get_my_wallet()
returns table (gold_coins bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول';
  end if;

  insert into public.room_wallets (user_id)
  values (auth.uid())
  on conflict (user_id) do nothing;

  return query
    select w.gold_coins
    from public.room_wallets w
    where w.user_id = auth.uid();
end;
$$;

grant execute on function public.get_my_wallet() to authenticated;

create or replace function public.send_room_gift(
  p_room_id uuid,
  p_receiver_id uuid,
  p_gift_type text,
  p_quantity integer default 1
)
returns public.room_gifts
language plpgsql
security definer
set search_path = public
as $$
declare
  v_price integer;
  v_balance bigint;
  v_gift public.room_gifts;
  v_quantity integer := greatest(1, least(coalesce(p_quantity, 1), 99));
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول';
  end if;

  select c.price into v_price
  from public.room_gift_catalog c
  where c.gift_type = p_gift_type and c.is_active = true;

  if v_price is null then
    raise exception 'الهدية غير متاحة';
  end if;

  insert into public.room_wallets (user_id)
  values (auth.uid())
  on conflict (user_id) do nothing;

  select w.gold_coins into v_balance
  from public.room_wallets w
  where w.user_id = auth.uid()
  for update;

  if v_balance < (v_price::bigint * v_quantity::bigint) then
    raise exception 'رصيد العملات الذهبية غير كافٍ';
  end if;

  update public.room_wallets
  set gold_coins = gold_coins - (v_price::bigint * v_quantity::bigint),
      updated_at = now()
  where user_id = auth.uid();

  insert into public.room_gifts (
    room_id, sender_id, receiver_id, gift_type, quantity, unit_price
  ) values (
    p_room_id, auth.uid(), p_receiver_id, p_gift_type, v_quantity, v_price
  ) returning * into v_gift;

  return v_gift;
end;
$$;

grant execute on function public.send_room_gift(uuid, uuid, text, integer) to authenticated;

create or replace function public.room_gift_rankings(
  p_room_id uuid,
  p_period text default 'daily'
)
returns table (
  rank bigint,
  user_id uuid,
  total_coins bigint,
  total_gifts bigint
)
language sql
stable
security definer
set search_path = public
as $$
  with totals as (
    select
      g.sender_id as user_id,
      sum((coalesce(nullif(g.unit_price, 0), c.price)::bigint * g.quantity::bigint)) as total_coins,
      sum(g.quantity::bigint) as total_gifts
    from public.room_gifts g
    join public.room_gift_catalog c on c.gift_type = g.gift_type
    where g.room_id = p_room_id
      and g.created_at >= case
        when lower(coalesce(p_period, 'daily')) = 'weekly'
          then now() - interval '7 days'
        else now() - interval '1 day'
      end
    group by g.sender_id
  )
  select
    dense_rank() over (order by total_coins desc, user_id)::bigint as rank,
    user_id,
    total_coins::bigint,
    total_gifts::bigint
  from totals
  order by total_coins desc, user_id
  limit 20;
$$;

grant execute on function public.room_gift_rankings(uuid, text) to authenticated;
