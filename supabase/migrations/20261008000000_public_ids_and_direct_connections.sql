-- Public DoseDiary IDs and bidirectional patient/caregiver invitations.

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
  FOR attempt IN 1..200 LOOP
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
DECLARE
  existing_id TEXT;
BEGIN
  SELECT p.public_id INTO existing_id
  FROM public.profiles p
  WHERE p.id = NEW.id;

  IF existing_id IS NOT NULL THEN
    NEW.public_id := existing_id;
  ELSIF NEW.public_id IS NULL OR NEW.public_id = '' THEN
    NEW.public_id := public.generate_dose_diary_public_id();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_assign_public_id ON public.profiles;
CREATE TRIGGER profiles_assign_public_id
BEFORE INSERT OR UPDATE OF public_id ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.set_dose_diary_public_id();

DO $$
DECLARE
  profile_row RECORD;
BEGIN
  FOR profile_row IN
    SELECT id FROM public.profiles WHERE public_id IS NULL ORDER BY created_at, id
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
    SELECT uid,
           COALESCE(raw_user_meta_data ->> 'full_name', SPLIT_PART(email, '@', 1), ''),
           public.generate_dose_diary_public_id()
    FROM auth.users
    WHERE id = uid
    RETURNING public_id INTO result;
  END IF;

  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.lookup_profile_by_public_id(target_public_id TEXT)
RETURNS TABLE(user_id UUID, public_id TEXT, full_name TEXT, avatar_url TEXT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.id, p.public_id, p.full_name, p.avatar_url
  FROM public.profiles p
  WHERE p.public_id = CASE
    WHEN TRIM(target_public_id) LIKE '#%' THEN TRIM(target_public_id)
    ELSE '#' || TRIM(target_public_id)
  END
    AND auth.uid() IS NOT NULL
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.ensure_public_id() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.lookup_profile_by_public_id(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ensure_public_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.lookup_profile_by_public_id(TEXT) TO authenticated;

ALTER TABLE public.caregiver_invitations
  ADD COLUMN IF NOT EXISTS caregiver_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS sender_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS receiver_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS sender_role TEXT,
  ADD COLUMN IF NOT EXISTS sender_name TEXT,
  ADD COLUMN IF NOT EXISTS receiver_name TEXT;

UPDATE public.caregiver_invitations invitation
SET caregiver_user_id = auth_user.id
FROM auth.users auth_user
WHERE invitation.caregiver_user_id IS NULL
  AND LOWER(auth_user.email) = LOWER(invitation.caregiver_email);

UPDATE public.caregiver_invitations
SET sender_user_id = COALESCE(sender_user_id, user_id),
    receiver_user_id = COALESCE(receiver_user_id, caregiver_user_id),
    sender_role = COALESCE(sender_role, 'patient')
WHERE sender_user_id IS NULL OR sender_role IS NULL;

ALTER TABLE public.caregiver_invitations
  DROP CONSTRAINT IF EXISTS caregiver_invitations_sender_role_check;
ALTER TABLE public.caregiver_invitations
  ADD CONSTRAINT caregiver_invitations_sender_role_check
  CHECK (sender_role IS NULL OR sender_role IN ('patient', 'caregiver'));

CREATE INDEX IF NOT EXISTS idx_caregiver_inv_receiver
  ON public.caregiver_invitations(receiver_user_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_caregiver_inv_sender
  ON public.caregiver_invitations(sender_user_id, status, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS caregiver_invitation_pending_pair
  ON public.caregiver_invitations(user_id, caregiver_user_id)
  WHERE status = 'pending' AND caregiver_user_id IS NOT NULL;

DROP POLICY IF EXISTS participants_view_caregiver_invitations
  ON public.caregiver_invitations;
DROP POLICY IF EXISTS senders_create_caregiver_invitations
  ON public.caregiver_invitations;
DROP POLICY IF EXISTS receivers_respond_to_caregiver_invitations
  ON public.caregiver_invitations;

CREATE POLICY participants_view_caregiver_invitations
  ON public.caregiver_invitations FOR SELECT
  USING (
    auth.uid() = user_id OR auth.uid() = caregiver_user_id OR
    auth.uid() = sender_user_id OR auth.uid() = receiver_user_id
  );

CREATE POLICY senders_create_caregiver_invitations
  ON public.caregiver_invitations FOR INSERT
  WITH CHECK (
    auth.uid() = sender_user_id AND
    auth.uid() IN (user_id, caregiver_user_id) AND
    receiver_user_id IN (user_id, caregiver_user_id)
  );

CREATE POLICY receivers_respond_to_caregiver_invitations
  ON public.caregiver_invitations FOR UPDATE
  USING (auth.uid() = receiver_user_id)
  WITH CHECK (auth.uid() = receiver_user_id);

CREATE UNIQUE INDEX IF NOT EXISTS allocated_patients_link_unique
  ON public.allocated_patients(caregiver_id, patient_user_id)
  WHERE patient_user_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS allocated_caregivers_link_unique
  ON public.allocated_caregivers(patient_id, caregiver_user_id)
  WHERE caregiver_user_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.create_connection_invitation(
  target_public_id TEXT,
  sender_role TEXT,
  relationship_label TEXT DEFAULT 'Family member'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  sender_id UUID := auth.uid();
  target_id UUID;
  normalized_public_id TEXT;
  normalized_role TEXT := LOWER(TRIM(sender_role));
  patient_id UUID;
  caregiver_id UUID;
  receiver_id UUID;
  caregiver_email TEXT;
  sender_display_name TEXT;
  receiver_display_name TEXT;
  created_invitation public.caregiver_invitations;
BEGIN
  IF sender_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;
  IF normalized_role NOT IN ('patient', 'caregiver') THEN
    RAISE EXCEPTION 'Choose whether you are connecting as patient or caregiver.';
  END IF;

  normalized_public_id := CASE
    WHEN TRIM(target_public_id) LIKE '#%' THEN TRIM(target_public_id)
    ELSE '#' || TRIM(target_public_id)
  END;

  SELECT id INTO target_id
  FROM public.profiles
  WHERE public_id = normalized_public_id;

  IF target_id IS NULL THEN
    RAISE EXCEPTION 'No DoseDiary user was found with that ID.';
  END IF;
  IF target_id = sender_id THEN
    RAISE EXCEPTION 'You cannot invite your own account.';
  END IF;

  IF normalized_role = 'patient' THEN
    patient_id := sender_id;
    caregiver_id := target_id;
  ELSE
    patient_id := target_id;
    caregiver_id := sender_id;
  END IF;
  receiver_id := target_id;

  IF EXISTS (
    SELECT 1 FROM public.patient_caregiver_links
    WHERE patient_user_id = patient_id
      AND caregiver_user_id = caregiver_id
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'These accounts are already connected.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.caregiver_invitations
    WHERE user_id = patient_id
      AND caregiver_user_id = caregiver_id
      AND status = 'pending'
  ) THEN
    RAISE EXCEPTION 'A connection invitation is already pending.';
  END IF;

  SELECT email INTO caregiver_email FROM auth.users WHERE id = caregiver_id;
  SELECT COALESCE(NULLIF(full_name, ''), 'DoseDiary user')
    INTO sender_display_name FROM public.profiles WHERE id = sender_id;
  SELECT COALESCE(NULLIF(full_name, ''), 'DoseDiary user')
    INTO receiver_display_name FROM public.profiles WHERE id = receiver_id;

  INSERT INTO public.caregiver_invitations(
    user_id, caregiver_email, caregiver_user_id,
    sender_user_id, receiver_user_id, sender_role,
    sender_name, receiver_name, relationship,
    status, token, expires_at
  ) VALUES (
    patient_id, caregiver_email, caregiver_id,
    sender_id, receiver_id, normalized_role,
    sender_display_name, receiver_display_name,
    COALESCE(NULLIF(TRIM(relationship_label), ''), 'Family member'),
    'pending', gen_random_uuid()::TEXT, NOW() + INTERVAL '7 days'
  )
  RETURNING * INTO created_invitation;

  RETURN TO_JSONB(created_invitation);
END;
$$;

REVOKE ALL ON FUNCTION public.create_connection_invitation(TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_connection_invitation(TEXT, TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.respond_to_connection_invitation(
  invitation_uuid UUID,
  accept_invitation BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  responder_id UUID := auth.uid();
  invitation public.caregiver_invitations;
  patient_profile public.profiles;
  caregiver_profile public.profiles;
  response_status TEXT;
BEGIN
  IF responder_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  SELECT * INTO invitation
  FROM public.caregiver_invitations
  WHERE id = invitation_uuid
  FOR UPDATE;

  IF invitation.id IS NULL THEN
    RAISE EXCEPTION 'Invitation does not exist.';
  END IF;
  IF invitation.receiver_user_id <> responder_id THEN
    RAISE EXCEPTION 'This invitation is not addressed to your account.';
  END IF;
  IF invitation.status <> 'pending' THEN
    RAISE EXCEPTION 'This invitation has already been answered.';
  END IF;

  response_status := CASE WHEN accept_invitation THEN 'accepted' ELSE 'declined' END;
  UPDATE public.caregiver_invitations
  SET status = response_status, updated_at = NOW()
  WHERE id = invitation_uuid
  RETURNING * INTO invitation;

  IF NOT accept_invitation THEN
    RETURN TO_JSONB(invitation);
  END IF;

  SELECT * INTO patient_profile
  FROM public.profiles WHERE id = invitation.user_id;
  SELECT * INTO caregiver_profile
  FROM public.profiles WHERE id = invitation.caregiver_user_id;

  INSERT INTO public.patient_caregiver_links(
    patient_user_id, caregiver_user_id, relationship, invitation_id, status
  ) VALUES (
    invitation.user_id, invitation.caregiver_user_id,
    invitation.relationship, invitation.id, 'active'
  )
  ON CONFLICT (patient_user_id, caregiver_user_id)
  DO UPDATE SET
    relationship = EXCLUDED.relationship,
    invitation_id = EXCLUDED.invitation_id,
    status = 'active',
    updated_at = NOW();

  INSERT INTO public.caregiver_permissions(
    invitation_id, user_id, caregiver_id,
    perm_view_schedule, perm_view_history,
    perm_view_refills, perm_view_adherence
  ) VALUES (
    invitation.id, invitation.user_id, invitation.caregiver_user_id,
    TRUE, TRUE, FALSE, TRUE
  )
  ON CONFLICT (user_id, caregiver_id)
  DO UPDATE SET
    invitation_id = EXCLUDED.invitation_id,
    perm_view_schedule = EXCLUDED.perm_view_schedule,
    perm_view_history = EXCLUDED.perm_view_history,
    perm_view_refills = EXCLUDED.perm_view_refills,
    perm_view_adherence = EXCLUDED.perm_view_adherence,
    updated_at = NOW();

  INSERT INTO public.allocated_patients(
    caregiver_id, patient_user_id, full_name,
    relationship, avatar_url, phone_number
  ) VALUES (
    invitation.caregiver_user_id,
    invitation.user_id,
    COALESCE(NULLIF(patient_profile.full_name, ''), 'Patient'),
    invitation.relationship,
    patient_profile.avatar_url,
    patient_profile.phone_number
  )
  ON CONFLICT (caregiver_id, patient_user_id) WHERE patient_user_id IS NOT NULL
  DO UPDATE SET
    full_name = EXCLUDED.full_name,
    relationship = EXCLUDED.relationship,
    avatar_url = EXCLUDED.avatar_url,
    phone_number = EXCLUDED.phone_number;

  INSERT INTO public.allocated_caregivers(
    patient_id, caregiver_user_id, full_name,
    relationship, avatar_url, phone_number
  ) VALUES (
    invitation.user_id::TEXT,
    invitation.caregiver_user_id,
    COALESCE(NULLIF(caregiver_profile.full_name, ''), 'Caregiver'),
    invitation.relationship,
    caregiver_profile.avatar_url,
    caregiver_profile.phone_number
  )
  ON CONFLICT (patient_id, caregiver_user_id) WHERE caregiver_user_id IS NOT NULL
  DO UPDATE SET
    full_name = EXCLUDED.full_name,
    relationship = EXCLUDED.relationship,
    avatar_url = EXCLUDED.avatar_url,
    phone_number = EXCLUDED.phone_number;

  RETURN TO_JSONB(invitation);
END;
$$;

REVOKE ALL ON FUNCTION public.respond_to_connection_invitation(UUID, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.respond_to_connection_invitation(UUID, BOOLEAN) TO authenticated;
