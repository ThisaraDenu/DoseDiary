-- Optional medication images stored in a public, user-owned bucket.

ALTER TABLE public.medications
  ADD COLUMN IF NOT EXISTS image_url TEXT;

INSERT INTO storage.buckets (id, name, public)
VALUES ('medication-images', 'medication-images', TRUE)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;

DROP POLICY IF EXISTS medication_images_public_read ON storage.objects;
CREATE POLICY medication_images_public_read
  ON storage.objects FOR SELECT
  USING (bucket_id = 'medication-images');

DROP POLICY IF EXISTS medication_images_owner_insert ON storage.objects;
CREATE POLICY medication_images_owner_insert
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'medication-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS medication_images_owner_update ON storage.objects;
CREATE POLICY medication_images_owner_update
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'medication-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'medication-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS medication_images_owner_delete ON storage.objects;
CREATE POLICY medication_images_owner_delete
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'medication-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
