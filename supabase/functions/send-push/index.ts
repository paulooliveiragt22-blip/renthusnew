import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.48.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
const FIREBASE_CLIENT_EMAIL = Deno.env.get("FIREBASE_CLIENT_EMAIL") ?? "";
const FIREBASE_PRIVATE_KEY = Deno.env.get("FIREBASE_PRIVATE_KEY") ?? "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

interface WebhookPayload {
  type: "INSERT";
  table: string;
  record: {
    id?: string;
    user_id?: string;
    title?: string;
    body?: string;
    channel?: string;
    type?: string;
    data?: unknown;
  };
}

interface DirectPayload {
  user_id?: string;
  title?: string;
  body?: string;
  channel?: string;
  type?: string;
  data?: unknown;
}

async function getFcmAccessToken(): Promise<string> {
  const privateKeyPem = FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n");
  const pemContents = privateKeyPem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const jwt = await create(
    { alg: "RS256", typ: "JWT" },
    {
      iss: FIREBASE_CLIENT_EMAIL,
      sub: FIREBASE_CLIENT_EMAIL,
      aud: "https://oauth2.googleapis.com/token",
      iat: getNumericDate(0),
      exp: getNumericDate(60 * 60),
      scope: "https://www.googleapis.com/auth/firebase.messaging",
    },
    key,
  );

  const tokenResp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenResp.ok) {
    const text = await tokenResp.text();
    throw new Error(`OAuth token failed: ${tokenResp.status} ${text}`);
  }

  const tokenData = await tokenResp.json();
  return tokenData.access_token as string;
}

function stringifyData(obj: Record<string, unknown>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(obj)) {
    out[k] = v == null ? "" : String(v);
  }
  return out;
}

function channelIdForType(type?: string): string {
  if (type === "chat_message" || type === "new_message") return "renthus_chat";
  switch (type) {
    case "job_status":
    case "new_candidate":
    case "new_quote":
    case "quote_accepted":
    case "quote_rejected":
    case "job_started":
    case "new_job":
    case "job_accepted":
    case "job_completed":
    case "job_cancelled":
    case "payment_received":
    case "payment_confirmed":
    case "payment_failed":
    case "review_received":
    case "dispute_opened":
    case "dispute_resolved":
      return "renthus_jobs";
    default:
      return "renthus_default";
  }
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    const rawBody = await req.json();

    let userId: string | undefined;
    let title: string | undefined;
    let body: string | undefined;
    let notifType: string | undefined;
    let notifData: unknown;
    let notifChannel: string | undefined;
    let notifId: string | undefined;

    if (rawBody.type === "INSERT" && rawBody.record) {
      const rec = (rawBody as WebhookPayload).record;
      userId = rec.user_id ?? undefined;
      title = rec.title ?? undefined;
      body = rec.body ?? undefined;
      notifType = rec.type ?? undefined;
      notifData = rec.data;
      notifChannel = rec.channel ?? undefined;
      notifId = rec.id ?? undefined;
    } else {
      const direct = rawBody as DirectPayload;
      userId = direct.user_id ?? undefined;
      title = direct.title ?? undefined;
      body = direct.body ?? undefined;
      notifType = direct.type ?? undefined;
      notifData = direct.data;
      notifChannel = direct.channel ?? undefined;
    }

    console.log("send-push: payload parsed:", {
      userId,
      title,
      notifType,
      notifId,
    });

    if (!userId) {
      return json({ sent: false, reason: "no_user_id" });
    }
    if (!title || !body) {
      return json({ sent: false, reason: "missing_title_or_body" });
    }

    if (
      !FIREBASE_PROJECT_ID ||
      !FIREBASE_CLIENT_EMAIL ||
      !FIREBASE_PRIVATE_KEY
    ) {
      console.error("send-push: Firebase credentials not configured");
      return json({ sent: false, reason: "fcm_credentials_missing" }, 500);
    }

    const { data: devices, error: devErr } = await supabase
      .from("user_devices")
      .select("fcm_token, platform")
      .eq("user_id", userId);

    if (devErr) {
      console.error("send-push: DB error:", devErr);
      return json({ sent: false, reason: "db_error" }, 500);
    }

    const tokens = (devices ?? [])
      .map((d) => ({
        token: d.fcm_token as string,
        platform: d.platform as string,
      }))
      .filter((t) => t.token && t.token.length > 0);

    if (tokens.length === 0) {
      console.log(`send-push: no FCM tokens for user ${userId}`);
      if (notifId) {
        await supabase
          .from("notifications")
          .update({ push_sent: false })
          .eq("id", notifId);
      }
      return json({ sent: false, reason: "no_tokens" });
    }

    let extraData: Record<string, unknown> = {};
    if (typeof notifData === "string") {
      try {
        extraData = JSON.parse(notifData);
      } catch {
        /* ignore */
      }
    } else if (notifData && typeof notifData === "object") {
      extraData = notifData as Record<string, unknown>;
    }

    const accessToken = await getFcmAccessToken();
    const channelId = channelIdForType(notifType);
    const dataPayload = stringifyData({
      ...extraData,
      type: notifType ?? "generic",
      channel: notifChannel ?? "app",
      ...(notifId ? { notification_id: notifId } : {}),
    });

    const invalidTokens: string[] = [];
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`;

    for (const t of tokens) {
      const message: Record<string, unknown> = {
        token: t.token,
        notification: { title, body },
        data: dataPayload,
        android: {
          priority: "high",
          notification: {
            channel_id: channelId,
            sound: "default",
          },
        },
        apns: {
          payload: { aps: { sound: "default", badge: 1 } },
        },
      };

      const fcmResp = await fetch(fcmUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({ message }),
      });

      if (!fcmResp.ok) {
        const fcmJson = await fcmResp.json().catch(() => ({}));
        const err = fcmJson.error as
          | { status?: string; message?: string }
          | undefined;
        const status = err?.status ?? "";
        const msg = String(err?.message ?? fcmResp.statusText);
        console.log(
          `send-push: FCM fail ...${t.token.slice(-8)}: ${status} ${msg}`,
        );

        if (
          status === "NOT_FOUND" ||
          status === "UNREGISTERED" ||
          status === "INVALID_ARGUMENT" ||
          msg.toLowerCase().includes("not found") ||
          msg.toLowerCase().includes("unregistered")
        ) {
          invalidTokens.push(t.token);
        }
      }
    }

    if (invalidTokens.length > 0) {
      await supabase
        .from("user_devices")
        .delete()
        .eq("user_id", userId)
        .in("fcm_token", invalidTokens);
      console.log(
        `send-push: removed ${invalidTokens.length} invalid token(s)`,
      );
    }

    if (notifId) {
      await supabase
        .from("notifications")
        .update({ push_sent: true, push_sent_at: new Date().toISOString() })
        .eq("id", notifId);
    }

    const result = {
      sent: true,
      total: tokens.length,
      success: tokens.length - invalidTokens.length,
      failed: invalidTokens.length,
    };
    console.log("send-push: result:", result);
    return json(result);
  } catch (e) {
    console.error("send-push error:", e);
    return json({ error: String(e) }, 500);
  }
});

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
