-- Minimal standalone setup for DoseDiary public IDs.
-- Run this file by itself in the Supabase SQL Editor.

BEGIN;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS public_id TEXT;

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_public_id_format;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_public_id_format
  CHECK (public_id IS NULL OR public_id ~ '^#[0-9]{5}$');

CREATE UNIQUE INDEX IF NOT EXISTS profiles_public_id_unique
  ON public.profiles(public_id)
  WHERE public_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.generate_dose_diary_public_id()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  candidate TEXT;
BEGIN
  FOR attempt IN 1..500 LOOP
    candidate := '#' || LPAD(FLOOR(RANDOM() * 100000)::INTEGER::TEXT, 5, '0');
    IF NOT EXISTS (
      SELECT 1 FROM public.profiles WHERE public_id = candidate
    ) THEN
      RETURN candidate;
    END IF;
  END LOOP;

  RAISE EXCEPTION 'Could not allocate a unique DoseDiary ID.';
END;
$$;

CREATE OR REPLACE FUNCTION public.set_dose_diary_public_id()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.public_id IS NOT NULL THEN
    NEW.public_id := OLD.public_id;
  ELSIF NEW.public_id IS NULL OR NEW.public_id = '' THEN
    NEW.public_id := public.generate_dose_diary_public_id();
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_assign_public_id ON public.profiles;

CREATE TRIGGER profiles_assign_public_id
BEFORE INSERT OR UPDATE OF public_id ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.set_dose_diary_public_id();

DO $$
DECLARE
  profile_row RECORD;
BEGIN
  FOR profile_row IN
    SELECT id FROM public.profiles WHERE public_id IS NULL
  LOOP
    UPDATE public.profiles
    SET public_id = public.generate_dose_diary_public_id()
    WHERE id = profile_row.id;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.ensure_public_id()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  uid UUID := auth.uid();
  result TEXT;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  UPDATE public.profiles
  SET public_id = COALESCE(public_id, public.generate_dose_diary_public_id())
  WHERE id = uid
  RETURNING public_id INTO result;

  IF result IS NULL THEN
    INSERT INTO public.profiles(id, full_name, public_id)
    SELECT
      uid,
      COALESCE(raw_user_meta_data ->> 'full_name', SPLIT_PART(email, '@', 1), ''),
      public.generate_dose_diary_public_id()
    FROM auth.users
    WHERE id = uid
    ON CONFLICT (id) DO UPDATE
      SET public_id = COALESCE(public.profiles.public_id, EXCLUDED.public_id)
    RETURNING public_id INTO result;
  END IF;

  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.ensure_public_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ensure_public_id() TO authenticated;

COMMIT;
