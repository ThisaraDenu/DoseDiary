-- Retain occurrence keys so deleting history never regenerates scheduled doses.
ALTER TABLE public.dose_occurrences
  ADD COLUMN IF NOT EXISTS history_deleted_at TIMESTAMPTZ;
