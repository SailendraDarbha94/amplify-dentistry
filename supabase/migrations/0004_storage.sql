-- 0004_storage.sql
-- Supabase Storage bucket for clinic media (photos, radiographs, signatures, PDFs).
-- Object paths are '<clinic_id>/<patient_id>/<file>' (see docs/research/03-architecture-and-data.md).
-- Access is granted to active members of the clinic whose id is the first path segment.
-- Bucket is private: the app reads through signed URLs.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'clinic-media',
  'clinic-media',
  false,
  52428800, -- 50 MiB per object; CBCT volumes go through the capture bridge, not the phone
  array[
    'image/jpeg', 'image/png', 'image/webp', 'image/heic',
    'application/pdf', 'application/dicom', 'model/stl', 'application/octet-stream'
  ]
)
on conflict (id) do nothing;

-- First path segment of the object name, compared as text so malformed paths never raise on cast.
create policy clinic_media_select_member on storage.objects
  for select to authenticated
  using (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] in (select id::text from app.current_clinic_ids() as t (id))
  );

create policy clinic_media_insert_member on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] in (select id::text from app.current_clinic_ids() as t (id))
  );

create policy clinic_media_update_member on storage.objects
  for update to authenticated
  using (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] in (select id::text from app.current_clinic_ids() as t (id))
  )
  with check (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] in (select id::text from app.current_clinic_ids() as t (id))
  );

-- Only the owner dentist may remove media (image_records metadata stays; deletes are audited by the client).
create policy clinic_media_delete_owner on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] in (select id::text from app.clinic_ids_with_role('ownerDentist') as t (id))
  );
