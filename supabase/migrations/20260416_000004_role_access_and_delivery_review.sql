alter table public.profiles
  add column if not exists approved_roles text[] not null default array['customer'],
  add column if not exists owner_application_status text not null default 'not_applied',
  add column if not exists rider_application_status text not null default 'not_applied',
  add column if not exists owner_application_data jsonb not null default '{}'::jsonb,
  add column if not exists rider_application_data jsonb not null default '{}'::jsonb;

update public.profiles
set approved_roles = case
  when role = 'owner' then array['customer', 'owner']
  when role = 'rider' then array['customer', 'rider']
  else array['customer']
end
where approved_roles = array['customer'];

update public.profiles
set owner_application_status = case when role = 'owner' then 'approved' else owner_application_status end,
    rider_application_status = case when role = 'rider' then 'approved' else rider_application_status end;

alter table public.profiles
  drop constraint if exists profiles_owner_application_status_check,
  add constraint profiles_owner_application_status_check
    check (owner_application_status in ('not_applied', 'pending', 'approved', 'rejected', 'suspended'));

alter table public.profiles
  drop constraint if exists profiles_rider_application_status_check,
  add constraint profiles_rider_application_status_check
    check (rider_application_status in ('not_applied', 'pending', 'approved', 'rejected', 'suspended'));

alter table public.orders
  drop constraint if exists orders_status_check,
  add constraint orders_status_check
    check (
      status in (
        'pending',
        'confirmed',
        'preparing',
        'ready',
        'picked_up',
        'delivering',
        'delivered_pending_proof_review',
        'delivered',
        'cancelled'
      )
    );

alter table public.deliveries
  drop constraint if exists deliveries_status_check,
  add constraint deliveries_status_check
    check (
      status in (
        'confirmed',
        'picked_up',
        'delivering',
        'delivered_pending_proof_review',
        'delivered',
        'cancelled'
      )
    );
