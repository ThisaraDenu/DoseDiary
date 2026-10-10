-- Allow caregivers with adherence permission to read the patient occurrence
-- records needed to calculate a seven-day adherence summary.

DROP POLICY IF EXISTS caregivers_view_patient_adherence_occurrences
  ON public.dose_occurrences;

CREATE POLICY caregivers_view_patient_adherence_occurrences
  ON public.dose_occurrences FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.caregiver_permissions cp
      WHERE cp.user_id = dose_occurrences.user_id
        AND cp.caregiver_id = auth.uid()
        AND cp.perm_view_adherence = TRUE
    )
  );
