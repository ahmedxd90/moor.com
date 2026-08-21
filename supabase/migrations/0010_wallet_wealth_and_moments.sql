-- Wallet economy, diamond rewards, wealth levels, top-up catalog, and real moments.

alter table public.room_wallets
  add column if not exists diamonds bigint not null default 0 check (diamonds >= 0),
  add column if not exists lifetime_spent_gold bigint not null default 0 check (lifetime_spent_gold >= 0),
  add column if not exists wealth_level integer not null default 0 check (wealth_level between 0 and 100),
  add column if not exists last_free_claim_at timestamptz;

create table if not exists public.wallet_topup_packages (
  id text primary key,
  gold_coins bigint not null check (gold_coins > 0),
  price_usd numeric(10,2) not null check (price_usd >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

insert into public.wallet_topup_packages (id, gold_coins, price_usd)
values
  ('gold_30000', 30000, 1.00),
  ('gold_150000', 150000, 5.00),
  ('gold_300000', 300000, 10.00)
on conflict (id) do update set
  gold_coins = excluded.gold_coins,
  price_usd = excluded.price_usd,
  is_active = true;

create table if not exists public.wallet_topup_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  package_id text not null references public.wallet_topup_packages(id),
  gold_coins bigint not null check (gold_coins > 0),
  price_usd numeric(10,2) not null check (price_usd >= 0),
  provider text not null default 'pending',
  provider_reference text,
  status text not null default 'pending' check (status in ('pending','paid','failed','cancelled')),
  created_at timestamptz not null default now(),
  paid_at timestamptz
);

create index if not exists wallet_topup_orders_user_created_idx
  on public.wallet_topup_orders (user_id, created_at desc);

alter table public.wallet_topup_packages enable row level security;
alter table public.wallet_topup_orders enable row level security;

drop policy if exists wallet_topup_packages_select_authenticated on public.wallet_topup_packages;
create policy wallet_topup_packages_select_authenticated
  on public.wallet_topup_packages for select to authenticated
  using (is_active = true);

drop policy if exists wallet_topup_orders_select_own on public.wallet_topup_orders;
create policy wallet_topup_orders_select_own
  on public.wallet_topup_orders for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists wallet_topup_orders_insert_own on public.wallet_topup_orders;
create policy wallet_topup_orders_insert_own
  on public.wallet_topup_orders for insert to authenticated
  with check (auth.uid() = user_id and status = 'pending');

drop policy if exists wallet_topup_orders_update_locked on public.wallet_topup_orders;
create policy wallet_topup_orders_update_locked
  on public.wallet_topup_orders for update to authenticated
  using (false) with check (false);

create or replace function public.calculate_wealth_level(p_spent bigint)
returns integer
language plpgsql
immutable
as $$
declare
  v_level integer := 0;
  v_threshold numeric := 10000;
  v_spent numeric := greatest(coalesce(p_spent, 0), 0);
begin
  while v_level < 100 and v_spent >= v_threshold loop
    v_level := v_level + 1;
    v_threshold := v_threshold * 3;
  end loop;
  return v_level;
end;
$$;

grant execute on function public.calculate_wealth_level(bigint) to authenticated;

drop function if exists public.get_my_wallet();
create function public.get_my_wallet()
returns table (
  gold_coins bigint,
  diamonds bigint,
  lifetime_spent_gold bigint,
  wealth_level integer,
  last_free_claim_at timestamptz
)
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
    select w.gold_coins, w.diamonds, w.lifetime_spent_gold,
           w.wealth_level, w.last_free_claim_at
    from public.room_wallets w
    where w.user_id = auth.uid();
end;
$$;

grant execute on function public.get_my_wallet() to authenticated;

create or replace function public.claim_free_gold()
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_last timestamptz;
  v_balance bigint;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول'; end if;
  insert into public.room_wallets (user_id) values (auth.uid()) on conflict (user_id) do nothing;
  select last_free_claim_at into v_last from public.room_wallets where user_id = auth.uid() for update;
  if v_last is not null and v_last > now() - interval '24 hours' then
    raise exception 'تم استخدام الشحن المجاني، حاول بعد 24 ساعة';
  end if;
  update public.room_wallets
  set gold_coins = gold_coins + 30000,
      last_free_claim_at = now(),
      updated_at = now()
  where user_id = auth.uid()
  returning gold_coins into v_balance;
  return v_balance;
end;
$$;

grant execute on function public.claim_free_gold() to authenticated;

create or replace function public.convert_diamonds_to_gold(p_diamonds bigint)
returns table (gold_coins bigint, diamonds bigint)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_amount bigint := greatest(coalesce(p_diamonds, 0), 0);
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول'; end if;
  if v_amount <= 0 then raise exception 'أدخل عدد الماس المراد تحويله'; end if;
  update public.room_wallets
  set diamonds = diamonds - v_amount,
      gold_coins = gold_coins + v_amount,
      updated_at = now()
  where user_id = auth.uid() and diamonds >= v_amount;
  if not found then raise exception 'رصيد الماس غير كافٍ'; end if;
  return query select w.gold_coins, w.diamonds from public.room_wallets w where w.user_id = auth.uid();
end;
$$;

grant execute on function public.convert_diamonds_to_gold(bigint) to authenticated;

create or replace function public.create_topup_order(p_package_id text)
returns public.wallet_topup_orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_package public.wallet_topup_packages;
  v_order public.wallet_topup_orders;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول'; end if;
  select * into v_package from public.wallet_topup_packages where id = p_package_id and is_active = true;
  if v_package.id is null then raise exception 'الباقة غير متاحة'; end if;
  insert into public.wallet_topup_orders (user_id, package_id, gold_coins, price_usd)
  values (auth.uid(), v_package.id, v_package.gold_coins, v_package.price_usd)
  returning * into v_order;
  return v_order;
end;
$$;

grant execute on function public.create_topup_order(text) to authenticated;

-- Receiver gets 70% of the sent gold as diamonds; sender spending drives wealth level.
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
  v_total bigint;
  v_gift public.room_gifts;
  v_quantity integer := greatest(1, least(coalesce(p_quantity, 1), 99));
  v_spent bigint;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول'; end if;
  if p_receiver_id is null then raise exception 'اختر مستلمًا للهدية'; end if;
  select c.price into v_price from public.room_gift_catalog c
    where c.gift_type = p_gift_type and c.is_active = true;
  if v_price is null then raise exception 'الهدية غير متاحة'; end if;
  v_total := v_price::bigint * v_quantity::bigint;
  insert into public.room_wallets (user_id) values (auth.uid()), (p_receiver_id) on conflict (user_id) do nothing;
  select w.gold_coins into v_balance from public.room_wallets w where w.user_id = auth.uid() for update;
  if v_balance < v_total then raise exception 'رصيد العملات الذهبية غير كافٍ'; end if;
  update public.room_wallets
  set gold_coins = gold_coins - v_total,
      lifetime_spent_gold = lifetime_spent_gold + v_total,
      wealth_level = public.calculate_wealth_level(lifetime_spent_gold + v_total),
      updated_at = now()
  where user_id = auth.uid()
  returning lifetime_spent_gold into v_spent;
  update public.room_wallets
  set diamonds = diamonds + floor(v_total * 0.70)::bigint,
      updated_at = now()
  where user_id = p_receiver_id;
  insert into public.room_gifts (room_id, sender_id, receiver_id, gift_type, quantity, unit_price)
  values (p_room_id, auth.uid(), p_receiver_id, p_gift_type, v_quantity, v_price)
  returning * into v_gift;
  return v_gift;
end;
$$;

grant execute on function public.send_room_gift(uuid, uuid, text, integer) to authenticated;

create table if not exists public.moments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null default '',
  media_url text,
  likes_count integer not null default 0,
  comments_count integer not null default 0,
  shares_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (char_length(content) <= 2000),
  check (content <> '' or coalesce(media_url, '') <> '')
);

create index if not exists moments_created_idx on public.moments (created_at desc);
create index if not exists moments_user_created_idx on public.moments (user_id, created_at desc);

create table if not exists public.moment_likes (
  moment_id uuid not null references public.moments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (moment_id, user_id)
);

create table if not exists public.moment_comments (
  id uuid primary key default gen_random_uuid(),
  moment_id uuid not null references public.moments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 500),
  created_at timestamptz not null default now()
);

create table if not exists public.moment_shares (
  id uuid primary key default gen_random_uuid(),
  moment_id uuid not null references public.moments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (moment_id, user_id)
);

alter table public.moments enable row level security;
alter table public.moment_likes enable row level security;
alter table public.moment_comments enable row level security;
alter table public.moment_shares enable row level security;

drop policy if exists moments_select_authenticated on public.moments;
create policy moments_select_authenticated on public.moments for select to authenticated using (true);
drop policy if exists moments_insert_own on public.moments;
create policy moments_insert_own on public.moments for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists moments_update_own on public.moments;
create policy moments_update_own on public.moments for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists moments_delete_own on public.moments;
create policy moments_delete_own on public.moments for delete to authenticated using (auth.uid() = user_id);

drop policy if exists moment_likes_select_authenticated on public.moment_likes;
create policy moment_likes_select_authenticated on public.moment_likes for select to authenticated using (true);
drop policy if exists moment_likes_insert_own on public.moment_likes;
create policy moment_likes_insert_own on public.moment_likes for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists moment_likes_delete_own on public.moment_likes;
create policy moment_likes_delete_own on public.moment_likes for delete to authenticated using (auth.uid() = user_id);

drop policy if exists moment_comments_select_authenticated on public.moment_comments;
create policy moment_comments_select_authenticated on public.moment_comments for select to authenticated using (true);
drop policy if exists moment_comments_insert_own on public.moment_comments;
create policy moment_comments_insert_own on public.moment_comments for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists moment_comments_delete_own on public.moment_comments;
create policy moment_comments_delete_own on public.moment_comments for delete to authenticated using (auth.uid() = user_id);

drop policy if exists moment_shares_select_authenticated on public.moment_shares;
create policy moment_shares_select_authenticated on public.moment_shares for select to authenticated using (true);
drop policy if exists moment_shares_insert_own on public.moment_shares;
create policy moment_shares_insert_own on public.moment_shares for insert to authenticated with check (auth.uid() = user_id);

create or replace function public.touch_moment_counts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if TG_TABLE_NAME = 'moment_likes' then
    update public.moments set likes_count = (select count(*) from public.moment_likes where moment_id = coalesce(new.moment_id, old.moment_id)) where id = coalesce(new.moment_id, old.moment_id);
  elsif TG_TABLE_NAME = 'moment_comments' then
    update public.moments set comments_count = (select count(*) from public.moment_comments where moment_id = coalesce(new.moment_id, old.moment_id)) where id = coalesce(new.moment_id, old.moment_id);
  elsif TG_TABLE_NAME = 'moment_shares' then
    update public.moments set shares_count = (select count(*) from public.moment_shares where moment_id = coalesce(new.moment_id, old.moment_id)) where id = coalesce(new.moment_id, old.moment_id);
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists moment_likes_counts on public.moment_likes;
create trigger moment_likes_counts after insert or delete on public.moment_likes for each row execute function public.touch_moment_counts();
drop trigger if exists moment_comments_counts on public.moment_comments;
create trigger moment_comments_counts after insert or delete on public.moment_comments for each row execute function public.touch_moment_counts();
drop trigger if exists moment_shares_counts on public.moment_shares;
create trigger moment_shares_counts after insert or delete on public.moment_shares for each row execute function public.touch_moment_counts();

-- Realtime is best effort: a repeated add is ignored.
do $$
declare
  v_table text;
begin
  foreach v_table in array array['moments','moment_likes','moment_comments','moment_shares'] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', v_table);
    exception when duplicate_object then null;
    end;
  end loop;
end;
$$;
