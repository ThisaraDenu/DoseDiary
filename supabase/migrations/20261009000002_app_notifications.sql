CREATE TABLE IF NOT EXISTS public.app_notifications (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sender_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  type TEXT NOT NULL,
  priority TEXT NOT NULL DEFAULT 'normal',
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  source_id TEXT,
  route TEXT,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_notifications_user_created
ON public.app_notifications(user_id, created_at DESC);

ALTER TABLE public.app_notifications ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE
ON public.app_notifications TO authenticated;

DROP POLICY IF EXISTS recipients_view_notifications
ON public.app_notifications;
CREATE POLICY recipients_view_notifications
ON public.app_notifications FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS recipients_update_notifications
ON public.app_notifications;
CREATE POLICY recipients_update_notifications
ON public.app_notifications FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS recipients_delete_notifications
ON public.app_notifications;
CREATE POLICY recipients_delete_notifications
ON public.app_notifications FOR DELETE
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS participants_create_notifications
ON public.app_notifications;
CREATE POLICY participants_create_notifications
ON public.app_notifications FOR INSERT
WITH CHECK (
  auth.uid() = user_id
  OR (
    auth.uid() = sender_user_id
    AND EXISTS (
      SELECT 1
      FROM public.patient_caregiver_links AS link
      WHERE link.status = 'active'
        AND (
          (link.patient_user_id = auth.uid()
            AND link.caregiver_user_id = app_notifications.user_id)
          OR
          (link.caregiver_user_id = auth.uid()
            AND link.patient_user_id = app_notifications.user_id)
        )
    )
  )
);

NOTIFY pgrst, 'reload schema';
