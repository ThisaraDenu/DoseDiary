-- ==============================================================================
-- DoseDiary PostgreSQL Schema & Row Level Security (RLS) Policies
-- Supports Supabase & PowerSync SQLite Bidirectional Cloud Replication
-- ==============================================================================

-- 1. Profiles Table (Extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL DEFAULT '',
    avatar_url TEXT,
    preferred_language TEXT NOT NULL DEFAULT 'en' CHECK (preferred_language IN ('en', 'si', 'ta')),
    text_scale_factor NUMERIC(3, 2) NOT NULL DEFAULT 1.00,
    simple_wording BOOLEAN NOT NULL DEFAULT FALSE,
    notification_sound BOOLEAN NOT NULL DEFAULT TRUE,
    notification_vibration BOOLEAN NOT NULL DEFAULT TRUE,
    privacy_safe_previews BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Medications Table
CREATE TABLE IF NOT EXISTS public.medications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    strength NUMERIC NOT NULL DEFAULT 0,
    strength_unit TEXT NOT NULL DEFAULT 'mg',
    amount_per_dose NUMERIC NOT NULL DEFAULT 1,
    dose_unit TEXT NOT NULL DEFAULT 'tablet(s)',
    instructions TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_as_needed BOOLEAN NOT NULL DEFAULT FALSE,
    quantity_on_hand NUMERIC NOT NULL DEFAULT 0,
    quantity_unit TEXT NOT NULL DEFAULT 'tablet(s)',
    refill_reminder_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    refill_threshold_qty NUMERIC,
    refill_reminder_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Schedules Table
CREATE TABLE IF NOT EXISTS public.schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    medication_id UUID NOT NULL REFERENCES public.medications(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    times_of_day TEXT[] NOT NULL DEFAULT '{}',
    frequency_type TEXT NOT NULL DEFAULT 'daily',
    repeat_days INTEGER[],
    start_date DATE NOT NULL,
    end_date DATE,
    timezone TEXT NOT NULL DEFAULT 'UTC',
    rrule TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    superseded_at TIMESTAMPTZ
);

-- 4. Dose Occurrences Table (Concrete scheduled instances)
CREATE TABLE IF NOT EXISTS public.dose_occurrences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id UUID NOT NULL REFERENCES public.schedules(id) ON DELETE CASCADE,
    medication_id UUID NOT NULL REFERENCES public.medications(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    scheduled_at TIMESTAMPTZ NOT NULL,
    local_date DATE NOT NULL,
    occurrence_key TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'taken', 'missed', 'skipped', 'overdue', 'snoozed')),
    snooze_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Dose Events Table (Immutable Audit Log)
CREATE TABLE IF NOT EXISTS public.dose_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    occurrence_id UUID NOT NULL REFERENCES public.dose_occurrences(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    action TEXT NOT NULL CHECK (action IN ('taken', 'missed', 'skipped', 'snoozed', 'undo', 'correction')),
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    snooze_until TIMESTAMPTZ,
    skip_reason TEXT,
    client_id UUID NOT NULL UNIQUE, -- Client idempotency key
    caregiver_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. Stock Events Table (Refills and deductions log)
CREATE TABLE IF NOT EXISTS public.stock_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    medication_id UUID NOT NULL REFERENCES public.medications(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK (event_type IN ('refill', 'deduction', 'correction', 'undo')),
    quantity_delta NUMERIC NOT NULL,
    quantity_after NUMERIC NOT NULL,
    dose_event_id UUID REFERENCES public.dose_events(id) ON DELETE SET NULL,
    client_id UUID NOT NULL UNIQUE,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. Caregiver Invitations Table
CREATE TABLE IF NOT EXISTS public.caregiver_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    caregiver_email TEXT NOT NULL,
    relationship TEXT NOT NULL DEFAULT 'Family member',
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'expired', 'revoked')),
    token TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. Caregiver Permissions Table
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

-- 9. Caregiver Alerts Table (Escalation records)
CREATE TABLE IF NOT EXISTS public.caregiver_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    occurrence_id UUID NOT NULL REFERENCES public.dose_occurrences(id) ON DELETE CASCADE,
    caregiver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'acknowledged', 'resolved')),
    sent_at TIMESTAMPTZ,
    acknowledged_at TIMESTAMPTZ,
    fcm_message_id TEXT,
    client_id UUID NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 10. Notification Attempts Table
CREATE TABLE IF NOT EXISTS public.notification_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    occurrence_id UUID NOT NULL REFERENCES public.dose_occurrences(id) ON DELETE CASCADE,
    attempt_number INTEGER NOT NULL DEFAULT 1,
    scheduled_at TIMESTAMPTZ NOT NULL,
    delivered_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'delivered', 'failed', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 11. Devices Table (FCM push token registry)
CREATE TABLE IF NOT EXISTS public.devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
    app_version TEXT,
    last_seen TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, fcm_token)
);

-- Indexes for performant filtering
CREATE INDEX IF NOT EXISTS idx_medications_user ON public.medications(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_dose_occurrences_user_date ON public.dose_occurrences(user_id, local_date);
CREATE INDEX IF NOT EXISTS idx_dose_occurrences_scheduled ON public.dose_occurrences(scheduled_at, status);
CREATE INDEX IF NOT EXISTS idx_dose_events_occurrence ON public.dose_events(occurrence_id);
CREATE INDEX IF NOT EXISTS idx_caregiver_perm_caregiver ON public.caregiver_permissions(caregiver_id);
CREATE INDEX IF NOT EXISTS idx_caregiver_alerts_status ON public.caregiver_alerts(caregiver_id, status);

-- Enable Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dose_occurrences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dose_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.caregiver_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.caregiver_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.caregiver_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;

-- ── RLS Policies ─────────────────────────────────────────────────────────────

-- Profiles: Users can view and update their own profile
CREATE POLICY "Users can manage own profile"
    ON public.profiles FOR ALL
    USING (auth.uid() = id);

-- Medications: Users manage own medications; Caregivers can view if permitted
CREATE POLICY "Users manage own medications"
    ON public.medications FOR ALL
    USING (auth.uid() = user_id);

CREATE POLICY "Caregivers view permitted patient medications"
    ON public.medications FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.caregiver_permissions cp
            WHERE cp.user_id = medications.user_id
              AND cp.caregiver_id = auth.uid()
              AND (cp.perm_view_schedule = TRUE OR cp.perm_view_refills = TRUE)
        )
    );

-- Schedules: Users manage own schedules; Caregivers can view if perm_view_schedule = true
CREATE POLICY "Users manage own schedules"
    ON public.schedules FOR ALL
    USING (auth.uid() = user_id);

CREATE POLICY "Caregivers view patient schedules"
    ON public.schedules FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.caregiver_permissions cp
            WHERE cp.user_id = schedules.user_id
              AND cp.caregiver_id = auth.uid()
              AND cp.perm_view_schedule = TRUE
        )
    );

-- Dose Occurrences: Users manage own occurrences; Caregivers view schedule or history
CREATE POLICY "Users manage own occurrences"
    ON public.dose_occurrences FOR ALL
    USING (auth.uid() = user_id);

CREATE POLICY "Caregivers view patient occurrences"
    ON public.dose_occurrences FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.caregiver_permissions cp
            WHERE cp.user_id = dose_occurrences.user_id
              AND cp.caregiver_id = auth.uid()
              AND (cp.perm_view_schedule = TRUE OR cp.perm_view_history = TRUE)
        )
    );

-- Caregiver Permissions: Users manage permissions for their caregivers; Caregivers view own permissions
CREATE POLICY "Users manage own caregiver permissions"
    ON public.caregiver_permissions FOR ALL
    USING (auth.uid() = user_id);

CREATE POLICY "Caregivers view own granted permissions"
    ON public.caregiver_permissions FOR SELECT
    USING (auth.uid() = caregiver_id);

-- Caregiver Alerts: Caregivers can view and acknowledge alerts assigned to them
CREATE POLICY "Caregivers view their alerts"
    ON public.caregiver_alerts FOR SELECT
    USING (auth.uid() = caregiver_id);

CREATE POLICY "Caregivers update their alert acknowledgment"
    ON public.caregiver_alerts FOR UPDATE
    USING (auth.uid() = caregiver_id);

-- Devices: Users manage their registered push devices
CREATE POLICY "Users manage own push devices"
    ON public.devices FOR ALL
    USING (auth.uid() = user_id);
