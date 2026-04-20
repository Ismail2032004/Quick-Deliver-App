alter table public.orders
add column if not exists destination_source text
  check (destination_source in ('manual', 'current_location'));

alter table public.orders
add column if not exists destination_latitude numeric(10, 7);

alter table public.orders
add column if not exists destination_longitude numeric(10, 7);

create index if not exists idx_orders_destination_source
on public.orders (destination_source);
