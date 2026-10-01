-- ==============================================================================
-- Migration: Many-to-Many Patient + Caregiver Relationship
-- One patient can have many caregivers; one caregiver can have many patients.
-- ==============================================================================

-- 1. Add patient_user_id to allocated_patients so each display-metadata row
--    optionally links back to a real auth.users / profiles row.
ALTER TABLE public.allocated_patients
  ADD COLUMN IF NOT EXISTS patient_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_allocated_patients_patient   ON public.allocated_patients(patient_user_id);
CREATE INDEX IF NOT EXISTS idx_allocated_patients_caregiver ON public.allocated_patients(caregiver_id);

-- 2. New junction table: patient_caregiver_links
--    Rows here represent an ACCEPTED caregiver relationship.
--    Both parties are real registered users.
CREATE TABLE IF NOT EXISTS public.patient_caregiver_links (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    caregiver_user_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    relationship        TEXT NOT NULL DEFAULT 'Caregiver',
    invitation_id       UUID REFERENCES public.caregiver_invitations(id) ON DELETE SET NULL,
    status              TEXT NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active', 'paused', 'revoked')),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (patient_user_id, caregiver_user_id)
);

CREATE INDEX IF NOT EXISTS idx_pcl_patient   ON public.patient_caregiver_links(patient_user_id);
CREATE INDEX IF NOT EXISTS idx_pcl_caregiver ON public.patient_caregiver_links(caregiver_user_id);
CREATE INDEX IF NOT EXISTS idx_pcl_status    ON public.patient_caregiver_links(status);

ALTER TABLE public.patient_caregiver_links ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patients manage own caregiver links"
    ON public.patient_caregiver_links FOR ALL
    USING (auth.uid() = patient_user_id);

CREATE POLICY "Caregivers view own patient links"
    ON public.patient_caregiver_links FOR SELECT
    USING (auth.uid() = caregiver_user_id);

CREATE POLICY "Caregivers update own patient links"
    ON public.patient_caregiver_links FOR UPDATE
    USING (auth.uid() = caregiver_user_id);

-- 3. Allocated Caregivers (Patient Mode Display)
--    Each row stores display metadata for a caregiver linked to a patient.
CREATE TABLE IF NOT EXISTS public.allocated_caregivers (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id          TEXT NOT NULL,
    caregiver_user_id   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    full_name           TEXT NOT NULL,
    relationship        TEXT NOT NULL DEFAULT 'Caregiver',
    avatar_url          TEXT,
    location            TEXT NOT NULL DEFAULT 'Colombo Home',
    last_active         TEXT NOT NULL DEFAULT 'Active now',
    phone_battery       INTEGER NOT NULL DEFAULT 84,
    battery_status      TEXT NOT NULL DEFAULT 'Balanced',
    smart_hub_status    TEXT NOT NULL DEFAULT 'Synced 2m ago',
    phone_number        TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_allocated_caregivers_patient   ON public.allocated_caregivers(patient_id);
CREATE INDEX IF NOT EXISTS idx_allocated_caregivers_caregiver ON public.allocated_caregivers(caregiver_user_id);

ALTER TABLE public.allocated_caregivers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patients manage own allocated caregivers"
    ON public.allocated_caregivers FOR ALL
    USING (auth.uid()::text = patient_id OR patient_id = 'demo-user-001');
