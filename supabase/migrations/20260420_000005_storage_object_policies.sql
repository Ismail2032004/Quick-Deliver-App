drop policy if exists "delivery_proofs_read_public" on storage.objects;
create policy "delivery_proofs_read_public"
on storage.objects
for select
to public
using (bucket_id = 'delivery-proofs');

drop policy if exists "delivery_proofs_manage_participants" on storage.objects;
create policy "delivery_proofs_manage_participants"
on storage.objects
for all
to authenticated
using (
  bucket_id = 'delivery-proofs'
  and public.can_access_order((storage.foldername(name))[1])
)
with check (
  bucket_id = 'delivery-proofs'
  and public.can_access_order((storage.foldername(name))[1])
);

drop policy if exists "profile_avatars_read_public" on storage.objects;
create policy "profile_avatars_read_public"
on storage.objects
for select
to public
using (bucket_id = 'profile-avatars');

drop policy if exists "profile_avatars_manage_self" on storage.objects;
create policy "profile_avatars_manage_self"
on storage.objects
for all
to authenticated
using (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "business_images_read_public" on storage.objects;
create policy "business_images_read_public"
on storage.objects
for select
to public
using (bucket_id = 'business-images');

drop policy if exists "business_images_manage_owner" on storage.objects;
create policy "business_images_manage_owner"
on storage.objects
for all
to authenticated
using (
  bucket_id = 'business-images'
  and public.is_business_owner((storage.foldername(name))[1])
)
with check (
  bucket_id = 'business-images'
  and public.is_business_owner((storage.foldername(name))[1])
);

drop policy if exists "product_images_read_public" on storage.objects;
create policy "product_images_read_public"
on storage.objects
for select
to public
using (bucket_id = 'product-images');

drop policy if exists "product_images_manage_owner" on storage.objects;
create policy "product_images_manage_owner"
on storage.objects
for all
to authenticated
using (
  bucket_id = 'product-images'
  and public.is_business_owner((storage.foldername(name))[1])
)
with check (
  bucket_id = 'product-images'
  and public.is_business_owner((storage.foldername(name))[1])
);
