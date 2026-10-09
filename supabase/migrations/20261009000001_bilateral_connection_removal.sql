-- Allow either participant to remove a patient-caregiver connection.
-- Account records remain intact; only the relationship, permissions, and
-- allocation cards are removed from both users.

DROP POLICY IF EXISTS caregivers_manage_allocated_patients
ON public.allocated_patients;

DROP POLICY IF EXISTS caregivers_view_allocated_patients
ON public.allocated_patients;

CREATE POLICY caregivers_view_allocated_patients
ON public.allocated_patients
FOR SELECT
USING (auth.uid() = caregiver_id);

DROP POLICY IF EXISTS patients_manage_allocated_caregivers
ON public.allocated_caregivers;

DROP POLICY IF EXISTS patients_view_allocated_caregivers
ON public.allocated_caregivers;

CREATE POLICY patients_view_allocated_caregivers
ON public.allocated_caregivers
FOR SELECT
USING (auth.uid()::TEXT = patient_id);

CREATE OR REPLACE FUNCTION public.remove_patient_caregiver_connection(
  target_user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  actor_user_id UUID := auth.uid();
  linked_patient_id UUID;
  linked_caregiver_id UUID;
  linked_invitation_id UUID;
BEGIN
  IF actor_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  SELECT
    link.patient_user_id,
    link.caregiver_user_id,
    link.invitation_id
  INTO
    linked_patient_id,
    linked_caregiver_id,
    linked_invitation_id
  FROM public.patient_caregiver_links AS link
  WHERE
    (link.patient_user_id = actor_user_id
      AND link.caregiver_user_id = target_user_id)
    OR
    (link.caregiver_user_id = actor_user_id
      AND link.patient_user_id = target_user_id)
  LIMIT 1;

  IF linked_patient_id IS NULL OR linked_caregiver_id IS NULL THEN
    RAISE EXCEPTION 'No patient-caregiver connection was found.';
  END IF;

  UPDATE public.patient_caregiver_links
  SET status = 'revoked', updated_at = NOW()
  WHERE patient_user_id = linked_patient_id
    AND caregiver_user_id = linked_caregiver_id;

  IF linked_invitation_id IS NOT NULL THEN
    UPDATE public.caregiver_invitations
    SET status = 'revoked', updated_at = NOW()
    WHERE id = linked_invitation_id;
  END IF;

  DELETE FROM public.caregiver_permissions
  WHERE user_id = linked_patient_id
    AND caregiver_id = linked_caregiver_id;

  DELETE FROM public.allocated_patients
  WHERE caregiver_id = linked_caregiver_id
    AND patient_user_id = linked_patient_id;

  DELETE FROM public.allocated_caregivers
  WHERE patient_id = linked_patient_id::TEXT
    AND caregiver_user_id = linked_caregiver_id;
END;
$$;

REVOKE ALL
ON FUNCTION public.remove_patient_caregiver_connection(UUID)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.remove_patient_caregiver_connection(UUID)
TO authenticated;

NOTIFY pgrst, 'reload schema';
