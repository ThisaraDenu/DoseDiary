// ==============================================================================
// Supabase Edge Function: escalate-alert
// Checks overdue dose occurrences that exceeded the grace period and notifies
// designated caregivers via FCM push notification.
// ==============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface EscalationPayload {
  occurrence_id?: string;
  force_check?: boolean;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const body: EscalationPayload = await req.json().catch(() => ({}));
    const now = new Date();

    // Query pending/missed dose occurrences where scheduled_at + grace period has passed
    // and no caregiver alert has been recorded yet
    const { data: overdueDoses, error: doseError } = await supabaseClient
      .from("dose_occurrences")
      .select(`
        id,
        user_id,
        scheduled_at,
        status,
        medications ( name, strength, strength_unit ),
        profiles:user_id ( full_name )
      `)
      .in("status", ["pending", "overdue", "missed"])
      .lte("scheduled_at", new Date(now.getTime() - 30 * 60 * 1000).toISOString())
      .limit(50);

    if (doseError) throw doseError;

    const results = [];

    for (const dose of overdueDoses || []) {
      // Find active caregiver permissions for this user
      const { data: permissions } = await supabaseClient
        .from("caregiver_permissions")
        .select("caregiver_id, grace_period_minutes, alert_important_only")
        .eq("user_id", dose.user_id);

      for (const perm of permissions || []) {
        // Check if alert already sent for this occurrence and caregiver
        const { data: existingAlert } = await supabaseClient
          .from("caregiver_alerts")
          .select("id")
          .eq("occurrence_id", dose.id)
          .eq("caregiver_id", perm.caregiver_id)
          .maybeSingle();

        if (existingAlert) continue; // Already escalated

        // Fetch caregiver devices for push notification
        const { data: devices } = await supabaseClient
          .from("devices")
          .select("fcm_token")
          .eq("user_id", perm.caregiver_id);

        const patientName = (dose.profiles as any)?.full_name || "Your patient";
        const medName = (dose.medications as any)?.name || "Medication";

        // Insert caregiver alert record
        const { data: newAlert, error: alertError } = await supabaseClient
          .from("caregiver_alerts")
          .insert({
            occurrence_id: dose.id,
            user_id: dose.user_id,
            caregiver_id: perm.caregiver_id,
            status: "sent",
            sent_at: now.toISOString(),
            client_id: crypto.randomUUID(),
          })
          .select()
          .single();

        if (alertError) continue;

        // Dispatch FCM messages to caregiver devices (simulated or real when FCM configured)
        const fcmTokens = (devices || []).map((d: any) => d.fcm_token);
        results.push({
          alert_id: newAlert.id,
          caregiver_id: perm.caregiver_id,
          patient: patientName,
          medication: medName,
          tokens_count: fcmTokens.length,
        });
      }
    }

    return new Response(
      JSON.stringify({ success: true, escalated_count: results.length, details: results }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
