-- Complete, idempotent patient/caregiver connections and live presence.
-- Run this entire file in the Supabase SQL Editor after public IDs are enabled.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS phone_number TEXT,
  ADD COLUMN IF NOT EXISTS live_latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS live_longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS live_location TEXT,
  ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS public.caregiver_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  caregiver_email TEXT NOT NULL,
  relationship TEXT NOT NULL DEFAULT 'Family member',
  status TEXT NOT NULL DEFAULT 'pending',
  token TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.caregiver_invitations
  ADD COLUMN IF NOT EXISTS caregiver_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS sender_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS receiver_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS sender_role TEXT,
  ADD COLUMN IF NOT EXISTS sender_name TEXT,
  ADD COLUMN IF NOT EXISTS receiver_name TEXT;

CREATE TABLE IF NOT EXISTS public.caregiver_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invitation_id UUID NOT NULL REFERENCES public.caregiver_invitations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  caregiver_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  perm_view_schedule BOOLEAN NOT NULL DEFAULT FALSE,
  perm_view_history BOOLEAN NOT NULL DEFAULT FALSE,
  perm_view_refills BOOLEAN NOT NULL DEFAULT FALSE,
  perm_view_adherence BOOLEAN NOT NULL DEFAULT FALSE,
  alert_important_only BOOLEAN NOT NULL DEFAULT TRUE,
  retry_count INTEGER NOT NULL DEFAULT 2,
  grace_period_minutes INTEGER NOT NULL DEFAULT 30,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, caregiver_id)
);

CREATE TABLE IF NOT EXISTS public.patient_caregiver_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  caregiver_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  relationship TEXT NOT NULL DEFAULT 'Caregiver',
  invitation_id UUID REFERENCES public.caregiver_invitations(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (patient_user_id, caregiver_user_id)
);

CREATE TABLE IF NOT EXISTS public.allocated_patients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  caregiver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  patient_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  full_name TEXT NOT NULL,
  relationship TEXT NOT NULL DEFAULT 'Patient',
  avatar_url TEXT,
  location TEXT NOT NULL DEFAULT 'Location unavailable',
  last_active TEXT NOT NULL DEFAULT 'Active now',
  phone_battery INTEGER NOT NULL DEFAULT 85,
  battery_status TEXT NOT NULL DEFAULT 'Balanced',
  smart_hub_status TEXT NOT NULL DEFAULT 'Not connected',
  phone_number TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.allocated_patients
  ADD COLUMN IF NOT EXISTS patient_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS location TEXT NOT NULL DEFAULT 'Location unavailable',
  ADD COLUMN IF NOT EXISTS last_active TEXT NOT NULL DEFAULT 'Active now',
  ADD COLUMN IF NOT EXISTS phone_battery INTEGER NOT NULL DEFAULT 85,
  ADD COLUMN IF NOT EXISTS battery_status TEXT NOT NULL DEFAULT 'Balanced',
  ADD COLUMN IF NOT EXISTS smart_hub_status TEXT NOT NULL DEFAULT 'Not connected',
  ADD COLUMN IF NOT EXISTS phone_number TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE TABLE IF NOT EXISTS public.allocated_caregivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id TEXT NOT NULL,
  caregiver_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  full_name TEXT NOT NULL,
  relationship TEXT NOT NULL DEFAULT 'Caregiver',
  avatar_url TEXT,
  location TEXT NOT NULL DEFAULT 'Location unavailable',
  last_active TEXT NOT NULL DEFAULT 'Active now',
  phone_battery INTEGER NOT NULL DEFAULT 84,
  battery_status TEXT NOT NULL DEFAULT 'Balanced',
  smart_hub_status TEXT NOT NULL DEFAULT 'Not connected',
  phone_number TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.allocated_caregivers
  ADD COLUMN IF NOT EXISTS caregiver_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS location TEXT NOT NULL DEFAULT 'Location unavailable',
  ADD COLUMN IF NOT EXISTS last_active TEXT NOT NULL DEFAULT 'Active now',
  ADD COLUMN IF NOT EXISTS phone_battery INTEGER NOT NULL DEFAULT 84,
  ADD COLUMN IF NOT EXISTS battery_status TEXT NOT NULL DEFAULT 'Balanced',
  ADD COLUMN IF NOT EXISTS smart_hub_status TEXT NOT NULL DEFAULT 'Not connected',
  ADD COLUMN IF NOT EXISTS phone_number TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_connection_inv_receiver
  ON public.caregiver_invitations(receiver_user_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_connection_inv_sender
  ON public.caregiver_invitations(sender_user_id, status, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS connection_invitation_pending_pair
  ON public.caregiver_invitations(user_id, caregiver_user_id)
  WHERE status = 'pending' AND caregiver_user_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS allocated_patients_link_unique
  ON public.allocated_patients(caregiver_id, patient_user_id)
  WHERE patient_user_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS allocated_caregivers_link_unique
  ON public.allocated_caregivers(patient_id, caregiver_user_id)
  WHERE caregiver_user_id IS NOT NULL;

ALTER TABLE public.caregiver_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patient_caregiver_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.allocated_patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.allocated_caregivers ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.caregiver_invitations TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.patient_caregiver_links TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.allocated_patients TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.allocated_caregivers TO authenticated;

DROP POLICY IF EXISTS participants_view_connection_invitations ON public.caregiver_invitations;
DROP POLICY IF EXISTS senders_create_connection_invitations ON public.caregiver_invitations;
DROP POLICY IF EXISTS receivers_update_connection_invitations ON public.caregiver_invitations;
CREATE POLICY participants_view_connection_invitations
  ON public.caregiver_invitations FOR SELECT
  USING (auth.uid() IN (user_id, caregiver_user_id, sender_user_id, receiver_user_id));
CREATE POLICY senders_create_connection_invitations
  ON public.caregiver_invitations FOR INSERT
  WITH CHECK (auth.uid() = sender_user_id);
CREATE POLICY receivers_update_connection_invitations
  ON public.caregiver_invitations FOR UPDATE
  USING (auth.uid() = receiver_user_id)
  WITH CHECK (auth.uid() = receiver_user_id);

DROP POLICY IF EXISTS participants_view_patient_caregiver_links ON public.patient_caregiver_links;
CREATE POLICY participants_view_patient_caregiver_links
  ON public.patient_caregiver_links FOR SELECT
  USING (auth.uid() IN (patient_user_id, caregiver_user_id));

DROP POLICY IF EXISTS caregivers_manage_allocated_patients ON public.allocated_patients;
CREATE POLICY caregivers_manage_allocated_patients
  ON public.allocated_patients FOR ALL
  USING (auth.uid() = caregiver_id)
  WITH CHECK (auth.uid() = caregiver_id);

DROP POLICY IF EXISTS patients_manage_allocated_caregivers ON public.allocated_caregivers;
CREATE POLICY patients_manage_allocated_caregivers
  ON public.allocated_caregivers FOR ALL
  USING (auth.uid()::TEXT = patient_id)
  WITH CHECK (auth.uid()::TEXT = patient_id);

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
  INTO receiver_display_name FROM public.profiles WHERE id = target_id;

  INSERT INTO public.caregiver_invitations(
    user_id, caregiver_email, caregiver_user_id,
    sender_user_id, receiver_user_id, sender_role,
    sender_name, receiver_name, relationship,
    status, token, expires_at
  ) VALUES (
    patient_id, COALESCE(caregiver_email, ''), caregiver_id,
    sender_id, target_id, normalized_role,
    sender_display_name, receiver_display_name,
    COALESCE(NULLIF(TRIM(relationship_label), ''), 'Family member'),
    'pending', gen_random_uuid()::TEXT, NOW() + INTERVAL '7 days'
  )
  RETURNING * INTO created_invitation;

  RETURN TO_JSONB(created_invitation);
END;
$$;

CREATE OR REPLACE FUNCTION public.update_my_presence(
  p_latitude DOUBLE PRECISION DEFAULT NULL,
  p_longitude DOUBLE PRECISION DEFAULT NULL,
  p_location_label TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  uid UUID := auth.uid();
  updated_profile public.profiles;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  UPDATE public.profiles
  SET live_latitude = COALESCE(p_latitude, live_latitude),
      live_longitude = COALESCE(p_longitude, live_longitude),
      live_location = COALESCE(NULLIF(TRIM(p_location_label), ''), live_location),
      last_active_at = NOW(),
      updated_at = NOW()
  WHERE id = uid
  RETURNING * INTO updated_profile;

  IF updated_profile.id IS NULL THEN
    RAISE EXCEPTION 'Profile not found for the signed-in account.';
  END IF;

  RETURN JSONB_BUILD_OBJECT(
    'last_active_at', updated_profile.last_active_at,
    'location', updated_profile.live_location
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_profile_presence_to_connections()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.allocated_patients
  SET full_name = COALESCE(NULLIF(NEW.full_name, ''), full_name),
      avatar_url = NEW.avatar_url,
      phone_number = NEW.phone_number,
      location = COALESCE(NULLIF(NEW.live_location, ''), location),
      last_active = COALESCE(NEW.last_active_at::TEXT, last_active)
  WHERE patient_user_id = NEW.id;

  UPDATE public.allocated_caregivers
  SET full_name = COALESCE(NULLIF(NEW.full_name, ''), full_name),
      avatar_url = NEW.avatar_url,
      phone_number = NEW.phone_number,
      location = COALESCE(NULLIF(NEW.live_location, ''), location),
      last_active = COALESCE(NEW.last_active_at::TEXT, last_active)
  WHERE caregiver_user_id = NEW.id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_sync_connection_presence ON public.profiles;
CREATE TRIGGER profiles_sync_connection_presence
AFTER UPDATE OF full_name, avatar_url, phone_number,
  live_location, live_latitude, live_longitude, last_active_at
ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.sync_profile_presence_to_connections();

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

  response_status := CASE
    WHEN accept_invitation THEN 'accepted'
    ELSE 'declined'
  END;

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

  IF patient_profile.id IS NULL OR caregiver_profile.id IS NULL THEN
    RAISE EXCEPTION 'Both users must have a completed profile.';
  END IF;

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
    relationship, avatar_url, location, last_active, phone_number
  ) VALUES (
    invitation.caregiver_user_id,
    invitation.user_id,
    COALESCE(NULLIF(patient_profile.full_name, ''), 'Patient'),
    invitation.relationship,
    patient_profile.avatar_url,
    COALESCE(NULLIF(patient_profile.live_location, ''), 'Location unavailable'),
    COALESCE(patient_profile.last_active_at::TEXT, NOW()::TEXT),
    patient_profile.phone_number
  )
  ON CONFLICT (caregiver_id, patient_user_id) WHERE patient_user_id IS NOT NULL
  DO UPDATE SET
    full_name = EXCLUDED.full_name,
    relationship = EXCLUDED.relationship,
    avatar_url = EXCLUDED.avatar_url,
    location = EXCLUDED.location,
    last_active = EXCLUDED.last_active,
    phone_number = EXCLUDED.phone_number;

  INSERT INTO public.allocated_caregivers(
    patient_id, caregiver_user_id, full_name,
    relationship, avatar_url, location, last_active, phone_number
  ) VALUES (
    invitation.user_id::TEXT,
    invitation.caregiver_user_id,
    COALESCE(NULLIF(caregiver_profile.full_name, ''), 'Caregiver'),
    invitation.relationship,
    caregiver_profile.avatar_url,
    COALESCE(NULLIF(caregiver_profile.live_location, ''), 'Location unavailable'),
    COALESCE(caregiver_profile.last_active_at::TEXT, NOW()::TEXT),
    caregiver_profile.phone_number
  )
  ON CONFLICT (patient_id, caregiver_user_id) WHERE caregiver_user_id IS NOT NULL
  DO UPDATE SET
    full_name = EXCLUDED.full_name,
    relationship = EXCLUDED.relationship,
    avatar_url = EXCLUDED.avatar_url,
    location = EXCLUDED.location,
    last_active = EXCLUDED.last_active,
    phone_number = EXCLUDED.phone_number;

  RETURN TO_JSONB(invitation);
END;
$$;

REVOKE ALL ON FUNCTION public.create_connection_invitation(TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.respond_to_connection_invitation(UUID, BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.update_my_presence(DOUBLE PRECISION, DOUBLE PRECISION, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_connection_invitation(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_to_connection_invitation(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_my_presence(DOUBLE PRECISION, DOUBLE PRECISION, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
