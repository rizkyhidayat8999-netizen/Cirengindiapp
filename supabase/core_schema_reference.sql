create extension if not exists pgcrypto;

create sequence if not exists public.ci_order_seq start 1001;

create or replace function public.ci_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.member_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  email text not null,
  full_name text not null,
  phone text,
  birth_date date,
  status text not null default 'active' check (status in ('active','suspended','disabled')),
  level text not null default 'Classic' check (level in ('Classic','Silver','Gold','Platinum')),
  referral_code text not null,
  referred_by uuid references public.member_profiles(user_id) on delete set null,
  avatar_path text,
  marketing_notifications boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists member_profiles_username_lower_uidx on public.member_profiles(lower(username));
create unique index if not exists member_profiles_email_lower_uidx on public.member_profiles(lower(email));
create unique index if not exists member_profiles_referral_code_uidx on public.member_profiles(referral_code);

create table if not exists public.staff_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role text not null default 'staff' check (role in ('owner','admin','staff')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.ci_is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.staff_profiles s
    where s.user_id = auth.uid() and s.active
  );
$$;
revoke all on function public.ci_is_staff() from public;
grant execute on function public.ci_is_staff() to authenticated;

create table if not exists public.ci_categories (
  id uuid primary key default gen_random_uuid(),
  source_key text unique,
  name text not null,
  slug text not null unique,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ci_products (
  id uuid primary key default gen_random_uuid(),
  source_key text unique,
  category_id uuid not null references public.ci_categories(id),
  slug text not null unique,
  name text not null,
  description text,
  base_price integer not null default 0 check (base_price >= 0),
  image_path text,
  active boolean not null default true,
  best_seller boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists ci_products_category_idx on public.ci_products(category_id,active,sort_order);

create table if not exists public.ci_product_variants (
  id uuid primary key default gen_random_uuid(),
  source_key text unique,
  product_id uuid not null references public.ci_products(id) on delete cascade,
  sku text unique,
  name text not null,
  price integer not null check (price >= 0),
  stock integer not null default 0 check (stock >= 0),
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(product_id,name)
);
create index if not exists ci_variants_product_idx on public.ci_product_variants(product_id,active,sort_order);

create table if not exists public.ci_banners (
  id uuid primary key default gen_random_uuid(),
  source_key text unique,
  title text not null,
  subtitle text,
  kind text,
  image_path text,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ci_couriers (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  flat_fee integer not null default 0 check (flat_fee >= 0),
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


create table if not exists public.ci_courier_contacts (
  courier_id uuid primary key references public.ci_couriers(id) on delete cascade,
  whatsapp text,
  updated_at timestamptz not null default now()
);

create table if not exists public.ci_addresses (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.member_profiles(user_id) on delete cascade,
  label text,
  recipient_name text not null,
  phone text not null,
  address_line text not null,
  city text not null,
  province text not null,
  postal_code text,
  latitude numeric(10,7),
  longitude numeric(10,7),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists ci_addresses_member_idx on public.ci_addresses(member_id,is_default desc,created_at desc);

create table if not exists public.ci_carts (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null unique references public.member_profiles(user_id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ci_cart_items (
  id uuid primary key default gen_random_uuid(),
  cart_id uuid not null references public.ci_carts(id) on delete cascade,
  variant_id uuid not null references public.ci_product_variants(id),
  quantity integer not null check (quantity > 0 and quantity <= 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(cart_id,variant_id)
);
create index if not exists ci_cart_items_cart_idx on public.ci_cart_items(cart_id);

create table if not exists public.ci_orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  member_id uuid not null references public.member_profiles(user_id),
  fulfillment_type text not null default 'delivery' check (fulfillment_type in ('delivery','pickup')),
  address_id uuid references public.ci_addresses(id) on delete set null,
  address_snapshot jsonb,
  courier_id uuid references public.ci_couriers(id) on delete set null,
  status text not null default 'pending' check (status in ('pending','processing','shipped','completed','cancelled')),
  subtotal integer not null check (subtotal >= 0),
  shipping_fee integer not null default 0 check (shipping_fee >= 0),
  total integer not null check (total >= 0),
  notes text,
  completed_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists ci_orders_member_idx on public.ci_orders(member_id,created_at desc);
create index if not exists ci_orders_status_idx on public.ci_orders(status,created_at desc);

create table if not exists public.ci_order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.ci_orders(id) on delete cascade,
  product_id uuid references public.ci_products(id) on delete set null,
  variant_id uuid references public.ci_product_variants(id) on delete set null,
  product_name text not null,
  variant_name text,
  sku text,
  unit_price integer not null check (unit_price >= 0),
  quantity integer not null check (quantity > 0),
  line_total integer not null check (line_total >= 0),
  created_at timestamptz not null default now()
);
create index if not exists ci_order_items_order_idx on public.ci_order_items(order_id);

create table if not exists public.ci_payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.ci_orders(id) on delete cascade,
  method text not null default 'cod' check (method in ('cod')),
  status text not null default 'pending' check (status in ('pending','paid','cancelled')),
  amount integer not null check (amount >= 0),
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ci_refunds (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.ci_orders(id) on delete cascade,
  payment_id uuid references public.ci_payments(id) on delete set null,
  amount integer not null check (amount >= 0),
  reason text,
  status text not null default 'pending' check (status in ('pending','approved','rejected','completed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ci_point_ledger (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.member_profiles(user_id) on delete cascade,
  delta integer not null check (delta <> 0),
  reason text not null,
  order_id uuid references public.ci_orders(id) on delete set null,
  redemption_id uuid,
  note text,
  created_at timestamptz not null default now()
);
create index if not exists ci_point_ledger_member_idx on public.ci_point_ledger(member_id,created_at desc);
create unique index if not exists ci_point_ledger_order_unique on public.ci_point_ledger(order_id)
where order_id is not null and reason = 'order_completed';

create table if not exists public.ci_rewards (
  id uuid primary key default gen_random_uuid(),
  source_key text unique,
  product_name text not null,
  variant_name text,
  points_cost integer not null check (points_cost > 0),
  stock integer not null default 0 check (stock >= 0),
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(product_name,variant_name)
);

create table if not exists public.ci_reward_redemptions (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.member_profiles(user_id) on delete cascade,
  reward_id uuid not null references public.ci_rewards(id),
  points_spent integer not null check (points_spent > 0),
  status text not null default 'pending' check (status in ('pending','fulfilled','cancelled')),
  fulfilled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.ci_point_ledger drop constraint if exists ci_point_ledger_redemption_id_fkey;
alter table public.ci_point_ledger add constraint ci_point_ledger_redemption_id_fkey foreign key (redemption_id) references public.ci_reward_redemptions(id) on delete set null;

create table if not exists public.ci_notifications (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.member_profiles(user_id) on delete cascade,
  kind text not null default 'general',
  title text not null,
  body text not null,
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists ci_notifications_member_idx on public.ci_notifications(member_id,created_at desc);

create table if not exists public.ci_device_tokens (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.member_profiles(user_id) on delete cascade,
  token text not null unique,
  platform text not null default 'android',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ci_app_settings (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.ci_auth_rate_limits (
  key_hash text not null,
  action text not null,
  window_start timestamptz not null,
  attempts integer not null default 1,
  primary key(key_hash,action)
);

create table if not exists public.ci_audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text,
  entity_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists ci_audit_logs_created_idx on public.ci_audit_logs(created_at desc);

-- Updated-at triggers
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'member_profiles','staff_profiles','ci_categories','ci_products','ci_product_variants','ci_banners',
    'ci_couriers','ci_addresses','ci_carts','ci_cart_items','ci_orders','ci_payments','ci_refunds',
    'ci_rewards','ci_reward_redemptions','ci_device_tokens'
  ] LOOP
    EXECUTE format('drop trigger if exists %I_updated_at on public.%I',t,t);
    EXECUTE format('create trigger %I_updated_at before update on public.%I for each row execute function public.ci_set_updated_at()',t,t);
  END LOOP;
END $$;

create or replace function public.ci_profile_after_insert()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  insert into public.ci_carts(member_id) values (new.user_id)
  on conflict (member_id) do nothing;
  return new;
end;
$$;
drop trigger if exists member_profiles_create_cart on public.member_profiles;
create trigger member_profiles_create_cart after insert on public.member_profiles
for each row execute function public.ci_profile_after_insert();

-- RLS
alter table public.member_profiles enable row level security;
alter table public.staff_profiles enable row level security;
alter table public.ci_categories enable row level security;
alter table public.ci_products enable row level security;
alter table public.ci_product_variants enable row level security;
alter table public.ci_banners enable row level security;
alter table public.ci_couriers enable row level security;
alter table public.ci_courier_contacts enable row level security;
alter table public.ci_addresses enable row level security;
alter table public.ci_carts enable row level security;
alter table public.ci_cart_items enable row level security;
alter table public.ci_orders enable row level security;
alter table public.ci_order_items enable row level security;
alter table public.ci_payments enable row level security;
alter table public.ci_refunds enable row level security;
alter table public.ci_point_ledger enable row level security;
alter table public.ci_rewards enable row level security;
alter table public.ci_reward_redemptions enable row level security;
alter table public.ci_notifications enable row level security;
alter table public.ci_device_tokens enable row level security;
alter table public.ci_app_settings enable row level security;
alter table public.ci_auth_rate_limits enable row level security;
alter table public.ci_audit_logs enable row level security;

-- Member and staff identity policies
drop policy if exists member_profiles_read_self_or_staff on public.member_profiles;
create policy member_profiles_read_self_or_staff on public.member_profiles for select to authenticated
using (user_id = auth.uid() or public.ci_is_staff());

drop policy if exists staff_profiles_read_self_or_staff on public.staff_profiles;
create policy staff_profiles_read_self_or_staff on public.staff_profiles for select to authenticated
using (user_id = auth.uid() or public.ci_is_staff());

-- Public catalog read
drop policy if exists ci_categories_public_read on public.ci_categories;
create policy ci_categories_public_read on public.ci_categories for select to anon,authenticated using (active);
drop policy if exists ci_categories_staff_read on public.ci_categories;
create policy ci_categories_staff_read on public.ci_categories for select to authenticated using (public.ci_is_staff());

drop policy if exists ci_products_public_read on public.ci_products;
create policy ci_products_public_read on public.ci_products for select to anon,authenticated using (active);
drop policy if exists ci_products_staff_read on public.ci_products;
create policy ci_products_staff_read on public.ci_products for select to authenticated using (public.ci_is_staff());

drop policy if exists ci_variants_public_read on public.ci_product_variants;
create policy ci_variants_public_read on public.ci_product_variants for select to anon,authenticated using (active);
drop policy if exists ci_variants_staff_read on public.ci_product_variants;
create policy ci_variants_staff_read on public.ci_product_variants for select to authenticated using (public.ci_is_staff());

drop policy if exists ci_banners_public_read on public.ci_banners;
create policy ci_banners_public_read on public.ci_banners for select to anon,authenticated using (active);
drop policy if exists ci_banners_staff_read on public.ci_banners;
create policy ci_banners_staff_read on public.ci_banners for select to authenticated using (public.ci_is_staff());

drop policy if exists ci_couriers_public_read on public.ci_couriers;
create policy ci_couriers_public_read on public.ci_couriers for select to anon,authenticated using (active);
drop policy if exists ci_couriers_staff_read on public.ci_couriers;
create policy ci_couriers_staff_read on public.ci_couriers for select to authenticated using (public.ci_is_staff());

drop policy if exists ci_courier_contacts_staff_read on public.ci_courier_contacts;
create policy ci_courier_contacts_staff_read on public.ci_courier_contacts for select to authenticated using (public.ci_is_staff());

drop policy if exists ci_rewards_public_read on public.ci_rewards;
create policy ci_rewards_public_read on public.ci_rewards for select to anon,authenticated using (active);
drop policy if exists ci_rewards_staff_read on public.ci_rewards;
create policy ci_rewards_staff_read on public.ci_rewards for select to authenticated using (public.ci_is_staff());

-- Own data policies
drop policy if exists ci_addresses_own_all on public.ci_addresses;
create policy ci_addresses_own_all on public.ci_addresses for all to authenticated
using (member_id = auth.uid() or public.ci_is_staff())
with check (member_id = auth.uid() or public.ci_is_staff());

drop policy if exists ci_carts_own_read on public.ci_carts;
create policy ci_carts_own_read on public.ci_carts for select to authenticated
using (member_id = auth.uid() or public.ci_is_staff());

drop policy if exists ci_cart_items_own_read on public.ci_cart_items;
create policy ci_cart_items_own_read on public.ci_cart_items for select to authenticated
using (exists(select 1 from public.ci_carts c where c.id=cart_id and (c.member_id=auth.uid() or public.ci_is_staff())));

drop policy if exists ci_orders_own_read on public.ci_orders;
create policy ci_orders_own_read on public.ci_orders for select to authenticated
using (member_id = auth.uid() or public.ci_is_staff());

drop policy if exists ci_order_items_own_read on public.ci_order_items;
create policy ci_order_items_own_read on public.ci_order_items for select to authenticated
using (exists(select 1 from public.ci_orders o where o.id=order_id and (o.member_id=auth.uid() or public.ci_is_staff())));

drop policy if exists ci_payments_own_read on public.ci_payments;
create policy ci_payments_own_read on public.ci_payments for select to authenticated
using (exists(select 1 from public.ci_orders o where o.id=order_id and (o.member_id=auth.uid() or public.ci_is_staff())));

drop policy if exists ci_refunds_staff_read on public.ci_refunds;
create policy ci_refunds_staff_read on public.ci_refunds for select to authenticated using (public.ci_is_staff());

drop policy if exists ci_points_own_read on public.ci_point_ledger;
create policy ci_points_own_read on public.ci_point_ledger for select to authenticated
using (member_id=auth.uid() or public.ci_is_staff());

drop policy if exists ci_redemptions_own_read on public.ci_reward_redemptions;
create policy ci_redemptions_own_read on public.ci_reward_redemptions for select to authenticated
using (member_id=auth.uid() or public.ci_is_staff());

drop policy if exists ci_notifications_own_read on public.ci_notifications;
create policy ci_notifications_own_read on public.ci_notifications for select to authenticated
using (member_id=auth.uid() or public.ci_is_staff());
drop policy if exists ci_device_tokens_own_all on public.ci_device_tokens;
create policy ci_device_tokens_own_all on public.ci_device_tokens for all to authenticated
using (member_id=auth.uid() or public.ci_is_staff()) with check (member_id=auth.uid() or public.ci_is_staff());

drop policy if exists ci_settings_public_read on public.ci_app_settings;
create policy ci_settings_public_read on public.ci_app_settings for select to anon,authenticated
using (key in ('business','payment_methods','points_rules','promo_pudding','packages','member_levels'));
drop policy if exists ci_settings_staff_read on public.ci_app_settings;
create policy ci_settings_staff_read on public.ci_app_settings for select to authenticated using (public.ci_is_staff());

drop policy if exists ci_audit_staff_read on public.ci_audit_logs;
create policy ci_audit_staff_read on public.ci_audit_logs for select to authenticated using (public.ci_is_staff());

-- No client policy for auth rate limits; Edge Function service role only.

-- Basic grants
revoke all on public.ci_auth_rate_limits from anon,authenticated;
revoke all on public.ci_audit_logs from anon;
