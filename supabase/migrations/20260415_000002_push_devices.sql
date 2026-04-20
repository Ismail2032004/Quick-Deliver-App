create table if not exists public.push_devices (
  token text primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  platform text not null default 'unknown',
  is_active boolean not null default true,
  last_seen_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_push_devices_user_id
on public.push_devices (user_id, updated_at desc);

alter table public.push_devices enable row level security;

drop policy if exists "push_devices_read_self" on public.push_devices;
create policy "push_devices_read_self"
on public.push_devices
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "push_devices_insert_self" on public.push_devices;
create policy "push_devices_insert_self"
on public.push_devices
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "push_devices_update_self" on public.push_devices;
create policy "push_devices_update_self"
on public.push_devices
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "push_devices_delete_self" on public.push_devices;
create policy "push_devices_delete_self"
on public.push_devices
for delete
to authenticated
using (user_id = auth.uid());
