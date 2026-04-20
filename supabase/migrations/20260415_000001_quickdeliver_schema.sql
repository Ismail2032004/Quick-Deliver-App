create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  email text not null unique,
  role text not null default 'customer' check (role in ('customer', 'owner', 'rider')),
  phone_number text,
  avatar_url text,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.businesses (
  id text primary key,
  owner_id uuid not null references public.profiles (id) on delete cascade,
  name text not null,
  description text not null default '',
  address text not null default '',
  latitude numeric(10, 7) not null default 0,
  longitude numeric(10, 7) not null default 0,
  category text not null default '',
  image_url text not null default '',
  phone_number text not null default '',
  rating numeric(3, 2) not null default 0,
  estimated_delivery_minutes integer not null default 30,
  tags text[] not null default '{}',
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.products (
  id text primary key,
  business_id text not null references public.businesses (id) on delete cascade,
  name text not null,
  description text not null default '',
  price numeric(10, 2) not null default 0,
  image_url text not null default '',
  category text not null default '',
  is_available boolean not null default true,
  preparation_minutes integer not null default 10,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.orders (
  id text primary key,
  business_id text not null references public.businesses (id) on delete restrict,
  business_name text not null default '',
  customer_id uuid not null references public.profiles (id) on delete restrict,
  customer_name text not null default '',
  rider_id uuid references public.profiles (id) on delete set null,
  rider_name text,
  status text not null default 'pending' check (
    status in ('pending', 'confirmed', 'preparing', 'ready', 'picked_up', 'delivering', 'delivered', 'cancelled')
  ),
  delivery_address text not null,
  customer_phone text not null default '',
  business_phone text not null default '',
  rider_phone text,
  note text,
  tracking_enabled boolean not null default false,
  pickup_proof_image_url text,
  delivery_proof_image_url text,
  total_amount numeric(10, 2) not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id text not null references public.orders (id) on delete cascade,
  product_id text,
  product_name text not null,
  unit_price numeric(10, 2) not null default 0,
  quantity integer not null default 1,
  image_url text
);

create table if not exists public.deliveries (
  id uuid primary key default gen_random_uuid(),
  order_id text not null unique references public.orders (id) on delete cascade,
  rider_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'confirmed' check (
    status in ('confirmed', 'picked_up', 'delivering', 'delivered', 'cancelled')
  ),
  assigned_at timestamptz not null default timezone('utc', now()),
  picked_up_at timestamptz,
  delivered_at timestamptz
);

create table if not exists public.rider_locations (
  rider_id uuid primary key references public.profiles (id) on delete cascade,
  rider_name text not null default '',
  latitude numeric(10, 7) not null,
  longitude numeric(10, 7) not null,
  order_id text references public.orders (id) on delete set null,
  is_active boolean not null default true,
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.notifications (
  id text primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  body text not null,
  type text not null default 'order_status',
  order_id text references public.orders (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  is_read boolean not null default false
);

create index if not exists idx_profiles_role on public.profiles (role);
create index if not exists idx_businesses_owner_id on public.businesses (owner_id);
create index if not exists idx_products_business_id on public.products (business_id);
create index if not exists idx_orders_customer_id on public.orders (customer_id);
create index if not exists idx_orders_business_id on public.orders (business_id);
create index if not exists idx_orders_rider_id on public.orders (rider_id);
create index if not exists idx_orders_status on public.orders (status);
create index if not exists idx_orders_created_at on public.orders (created_at desc);
create index if not exists idx_order_items_order_id on public.order_items (order_id);
create index if not exists idx_deliveries_rider_id on public.deliveries (rider_id);
create index if not exists idx_notifications_user_id on public.notifications (user_id, created_at desc);
create index if not exists idx_rider_locations_order_id on public.rider_locations (order_id);

create or replace function public.is_business_owner(target_business_id text)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.businesses b
    where b.id = target_business_id
      and b.owner_id = auth.uid()
  );
$$;

create or replace function public.can_access_order(target_order_id text)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.orders o
    join public.businesses b on b.id = o.business_id
    where o.id = target_order_id
      and (
        o.customer_id = auth.uid()
        or o.rider_id = auth.uid()
        or b.owner_id = auth.uid()
      )
  );
$$;

alter table public.profiles enable row level security;
alter table public.businesses enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.deliveries enable row level security;
alter table public.rider_locations enable row level security;
alter table public.notifications enable row level security;

drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated"
on public.profiles
for select
to authenticated
using (true);

drop policy if exists "profiles_upsert_self" on public.profiles;
create policy "profiles_upsert_self"
on public.profiles
for all
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "businesses_read_authenticated" on public.businesses;
create policy "businesses_read_authenticated"
on public.businesses
for select
to authenticated
using (true);

drop policy if exists "businesses_manage_owner" on public.businesses;
create policy "businesses_manage_owner"
on public.businesses
for all
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

drop policy if exists "products_read_authenticated" on public.products;
create policy "products_read_authenticated"
on public.products
for select
to authenticated
using (true);

drop policy if exists "products_manage_owner" on public.products;
create policy "products_manage_owner"
on public.products
for all
to authenticated
using (public.is_business_owner(business_id))
with check (public.is_business_owner(business_id));

drop policy if exists "orders_read_participants" on public.orders;
create policy "orders_read_participants"
on public.orders
for select
to authenticated
using (
  customer_id = auth.uid()
  or rider_id = auth.uid()
  or public.is_business_owner(business_id)
);

drop policy if exists "orders_insert_customer" on public.orders;
create policy "orders_insert_customer"
on public.orders
for insert
to authenticated
with check (customer_id = auth.uid());

drop policy if exists "orders_update_participants" on public.orders;
create policy "orders_update_participants"
on public.orders
for update
to authenticated
using (
  customer_id = auth.uid()
  or rider_id = auth.uid()
  or public.is_business_owner(business_id)
)
with check (
  customer_id = auth.uid()
  or rider_id = auth.uid()
  or public.is_business_owner(business_id)
);

drop policy if exists "order_items_read_participants" on public.order_items;
create policy "order_items_read_participants"
on public.order_items
for select
to authenticated
using (public.can_access_order(order_id));

drop policy if exists "order_items_insert_participants" on public.order_items;
create policy "order_items_insert_participants"
on public.order_items
for insert
to authenticated
with check (public.can_access_order(order_id));

drop policy if exists "order_items_update_participants" on public.order_items;
create policy "order_items_update_participants"
on public.order_items
for update
to authenticated
using (public.can_access_order(order_id))
with check (public.can_access_order(order_id));

drop policy if exists "deliveries_read_participants" on public.deliveries;
create policy "deliveries_read_participants"
on public.deliveries
for select
to authenticated
using (
  rider_id = auth.uid()
  or exists (
    select 1
    from public.orders o
    join public.businesses b on b.id = o.business_id
    where o.id = deliveries.order_id
      and b.owner_id = auth.uid()
  )
);

drop policy if exists "deliveries_manage_owner_or_rider" on public.deliveries;
create policy "deliveries_manage_owner_or_rider"
on public.deliveries
for all
to authenticated
using (
  rider_id = auth.uid()
  or exists (
    select 1
    from public.orders o
    join public.businesses b on b.id = o.business_id
    where o.id = deliveries.order_id
      and b.owner_id = auth.uid()
  )
)
with check (
  rider_id = auth.uid()
  or exists (
    select 1
    from public.orders o
    join public.businesses b on b.id = o.business_id
    where o.id = deliveries.order_id
      and b.owner_id = auth.uid()
  )
);

drop policy if exists "rider_locations_read_authenticated" on public.rider_locations;
create policy "rider_locations_read_authenticated"
on public.rider_locations
for select
to authenticated
using (true);

drop policy if exists "rider_locations_manage_self" on public.rider_locations;
create policy "rider_locations_manage_self"
on public.rider_locations
for all
to authenticated
using (rider_id = auth.uid())
with check (rider_id = auth.uid());

drop policy if exists "notifications_read_self" on public.notifications;
create policy "notifications_read_self"
on public.notifications
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "notifications_insert_authenticated" on public.notifications;
create policy "notifications_insert_authenticated"
on public.notifications
for insert
to authenticated
with check (true);

drop policy if exists "notifications_update_self" on public.notifications;
create policy "notifications_update_self"
on public.notifications
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

insert into storage.buckets (id, name, public)
values
  ('profile-avatars', 'profile-avatars', true),
  ('business-images', 'business-images', true),
  ('product-images', 'product-images', true),
  ('delivery-proofs', 'delivery-proofs', true)
on conflict (id) do nothing;
