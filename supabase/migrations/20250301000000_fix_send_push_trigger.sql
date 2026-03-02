-- Migration: Clean up legacy push notification triggers
-- 
-- IMPORTANT: Push notifications are now handled via Supabase Database Webhooks.
-- You MUST configure a Database Webhook in the Supabase Dashboard.
--
-- ============================================================================
-- INSTRUCTIONS TO CONFIGURE DATABASE WEBHOOK:
-- ============================================================================
-- 
-- 1. Go to Supabase Dashboard: https://app.supabase.com/project/kqzmjqegcmzqmxyefvfp
-- 
-- 2. Navigate to: Database > Webhooks
-- 
-- 3. Click "Create a new webhook" with these settings:
--    - Name: send-push-on-notification
--    - Table: notifications
--    - Schema: public
--    - Events: INSERT (check only INSERT)
--    - Type: Supabase Edge Function
--    - Edge Function: send-push
--    - HTTP Headers:
--      - Key: Authorization
--      - Value: Bearer YOUR_SERVICE_ROLE_KEY
--      (Get the service_role key from Project Settings > API)
--
-- 4. Click "Create webhook"
--
-- ============================================================================

-- First, drop the old disabled triggers that no longer work
DROP TRIGGER IF EXISTS notifications_after_insert_send_push ON public.notifications;
DROP TRIGGER IF EXISTS trg_send_push_on_notifications ON public.notifications;
DROP TRIGGER IF EXISTS trg_notify_new_notification ON public.notifications;
DROP TRIGGER IF EXISTS trg_send_push_on_notification_insert ON public.notifications;

-- Drop old stub functions
DROP FUNCTION IF EXISTS trigger_send_push() CASCADE;
DROP FUNCTION IF EXISTS call_edge_function_send_push() CASCADE;
DROP FUNCTION IF EXISTS notify_new_notification() CASCADE;
DROP FUNCTION IF EXISTS send_push_notification() CASCADE;

-- Add comment to notifications table documenting the webhook requirement
COMMENT ON TABLE public.notifications IS 
'Notification records. Push notifications are sent via Database Webhook -> send-push Edge Function.
Configure the webhook in Supabase Dashboard: Database > Webhooks.';
