-- Store the connected patient's account email and gender on the caregiver's
-- allocation record. Access remains limited by allocated_patients RLS.

ALTER TABLE public.allocated_patients
  ADD COLUMN IF NOT EXISTS patient_email TEXT,
  ADD COLUMN IF NOT EXISTS gender TEXT;

CREATE OR REPLACE FUNCTION public.hydrate_allocated_patient_account()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  resolved_email TEXT;
  resolved_gender TEXT;
BEGIN
  IF NEW.patient_user_id IS NOT NULL THEN
    SELECT auth_user.email, profile.gender
    INTO resolved_email, resolved_gender
    FROM public.profiles profile
    LEFT JOIN auth.users auth_user ON auth_user.id = profile.id
    WHERE profile.id = NEW.patient_user_id;

    NEW.patient_email := resolved_email;
    NEW.gender := resolved_gender;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS allocated_patients_hydrate_account
  ON public.allocated_patients;

CREATE TRIGGER allocated_patients_hydrate_account
BEFORE INSERT OR UPDATE OF patient_user_id
ON public.allocated_patients
FOR EACH ROW
EXECUTE FUNCTION public.hydrate_allocated_patient_account();

UPDATE public.allocated_patients allocation
SET patient_email = auth_user.email,
    gender = profile.gender
FROM public.profiles profile
LEFT JOIN auth.users auth_user ON auth_user.id = profile.id
WHERE allocation.patient_user_id = profile.id;

CREATE OR REPLACE FUNCTION public.sync_patient_gender_to_allocations()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.allocated_patients
  SET gender = NEW.gender
  WHERE patient_user_id = NEW.id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_sync_patient_gender
  ON public.profiles;

CREATE TRIGGER profiles_sync_patient_gender
AFTER UPDATE OF gender
ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.sync_patient_gender_to_allocations();
