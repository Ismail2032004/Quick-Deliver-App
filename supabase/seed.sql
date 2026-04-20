with customer_profile as (
  insert into public.profiles (
    id, full_name, email, role, phone_number, approved_roles
  )
  select
    id,
    'Ama Boateng',
    'customer@quickdeliver.demo',
    'customer',
    '+233244100100',
    array['customer']
  from auth.users
  where email = 'customer@quickdeliver.demo'
  on conflict (id) do update
    set full_name = excluded.full_name,
        email = excluded.email,
        role = excluded.role,
        phone_number = excluded.phone_number,
        approved_roles = excluded.approved_roles
  returning id
),
owner_profile as (
  insert into public.profiles (
    id,
    full_name,
    email,
    role,
    phone_number,
    approved_roles,
    owner_application_status
  )
  select
    id,
    'Efua Market',
    'owner@quickdeliver.demo',
    'owner',
    '+233244200200',
    array['customer', 'owner'],
    'approved'
  from auth.users
  where email = 'owner@quickdeliver.demo'
  on conflict (id) do update
    set full_name = excluded.full_name,
        email = excluded.email,
        role = excluded.role,
        phone_number = excluded.phone_number,
        approved_roles = excluded.approved_roles,
        owner_application_status = excluded.owner_application_status
  returning id
),
rider_profile as (
  insert into public.profiles (
    id,
    full_name,
    email,
    role,
    phone_number,
    approved_roles,
    rider_application_status
  )
  select
    id,
    'Kojo Mensah',
    'rider@quickdeliver.demo',
    'rider',
    '+233244300300',
    array['customer', 'rider'],
    'approved'
  from auth.users
  where email = 'rider@quickdeliver.demo'
  on conflict (id) do update
    set full_name = excluded.full_name,
        email = excluded.email,
        role = excluded.role,
        phone_number = excluded.phone_number,
        approved_roles = excluded.approved_roles,
        rider_application_status = excluded.rider_application_status
  returning id
)
insert into public.businesses (
  id,
  owner_id,
  name,
  category,
  description,
  address,
  phone_number,
  image_url,
  rating,
  estimated_delivery_minutes,
  latitude,
  longitude,
  tags
)
select
  '3d9d1d9d-1111-4444-9999-111111111111',
  (select id from owner_profile limit 1),
  'Campus Bites',
  'Restaurant',
  'Fast casual meals, bowls, and fresh smoothies popular with university students.',
  '15 University Avenue, East Legon',
  '+233244000111',
  'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=900&q=80',
  4.8,
  24,
  5.6402,
  -0.1668,
  array['Top rated', 'Lunch deals', 'Fast prep']
where exists (select 1 from owner_profile)
on conflict (id) do nothing;

insert into public.businesses (
  id,
  owner_id,
  name,
  category,
  description,
  address,
  phone_number,
  image_url,
  rating,
  estimated_delivery_minutes,
  latitude,
  longitude,
  tags
)
select
  '4e9d1d9d-2222-4444-9999-222222222222',
  (select id from owner_profile limit 1),
  'City Pharmacy',
  'Pharmacy',
  'Trusted neighbourhood pharmacy for health essentials and urgent medicine pickups.',
  '7 Boundary Road, Shiashie',
  '+233244000222',
  'https://images.unsplash.com/photo-1587854692152-cbe660dbde88?auto=format&fit=crop&w=900&q=80',
  4.7,
  19,
  5.6389,
  -0.1712,
  array['Express', 'Medical', 'Essential care']
where exists (select 1 from owner_profile)
on conflict (id) do nothing;

insert into public.products (
  id,
  business_id,
  name,
  description,
  category,
  price,
  image_url,
  is_available,
  preparation_minutes
)
values
  (
    '11111111-1111-4111-8111-111111111111',
    '3d9d1d9d-1111-4444-9999-111111111111',
    'Chicken Jollof Bowl',
    'Smoky jollof rice, grilled chicken, plantain, and house slaw.',
    'Meals',
    38.00,
    'https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=900&q=80',
    true,
    18
  ),
  (
    '22222222-2222-4222-8222-222222222222',
    '3d9d1d9d-1111-4444-9999-111111111111',
    'Tropical Mango Smoothie',
    'Fresh mango, pineapple, yogurt, and a touch of ginger.',
    'Drinks',
    16.00,
    'https://images.unsplash.com/photo-1623065422902-30a2d299bbe4?auto=format&fit=crop&w=900&q=80',
    true,
    6
  ),
  (
    '33333333-3333-4333-8333-333333333333',
    '4e9d1d9d-2222-4444-9999-222222222222',
    'Pain Relief Pack',
    'Fast-access essentials for headache, body pain, and mild fever support.',
    'Medicine',
    28.50,
    'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?auto=format&fit=crop&w=900&q=80',
    true,
    8
  )
on conflict (id) do nothing;
