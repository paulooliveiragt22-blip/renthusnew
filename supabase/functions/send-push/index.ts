// supabase/functions/send-push/index.ts

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.48.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY") ?? ""; // Server key (legacy HTTP) do Firebase

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error("send-push: SUPABASE_URL ou SERVICE_ROLE_KEY não configurados.");
}

if (!FCM_SERVER_KEY) {
  console.error("send-push: FCM_SERVER_KEY não configurada. Nenhum push será enviado.");
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

interface NotificationRow {
  id?: string;
  user_id?: string | null; // usuário de destino
  title: string;
  body: string;
  channel: string; // "app"
  data?: unknown;  // string JSON, null ou objeto
}

serve(async (req) => {
  try {
    // Só POST
    if (req.method !== "POST") {
      return new Response("Method not allowed", {
        status: 405,
        headers: { "Content-Type": "text/plain" },
      });
    }

    // Garante JSON
    const contentType = req.headers.get("content-type") ?? "";
    if (!contentType.toLowerCase().includes("application/json")) {
      return new Response("Invalid content-type", {
        status: 400,
        headers: { "Content-Type": "text/plain" },
      });
    }

    // 1) JSON vindo do trigger (row_to_json(NEW))
    const notif = (await req.json()) as NotificationRow;
    console.log("send-push: payload recebido:", notif);

    if (!notif.user_id) {
      console.log("send-push: sem user_id, nada a fazer.");
      return new Response("no user_id", {
        status: 200,
        headers: { "Content-Type": "text/plain" },
      });
    }

    if (!notif.title || !notif.body) {
      console.log("send-push: título ou corpo vazios, ignorando.");
      return new Response("invalid notification", {
        status: 200,
        headers: { "Content-Type": "text/plain" },
      });
    }

    // 2) Monta o objeto extraData de forma segura
    let extraData: Record<string, unknown> = {};

    if (typeof notif.data === "string") {
      const trimmed = notif.data.trim();
      if (trimmed.length > 0) {
        try {
          extraData = JSON.parse(trimmed);
        } catch (e) {
          console.error("send-push: erro ao parsear data como JSON:", e);
          // segue com extraData = {}
        }
      }
    } else if (notif.data && typeof notif.data === "object") {
      extraData = notif.data as Record<string, unknown>;
    }

    // 3) Busca tokens do usuário na tabela public.user_devices
    const { data: devices, error: devErr } = await supabase
      .from("user_devices")
      .select("fcm_token")
      .eq("user_id", notif.user_id);

    if (devErr) {
      console.error("send-push: erro buscando user_devices:", devErr);
      return new Response("db error", {
        status: 500,
        headers: { "Content-Type": "text/plain" },
      });
    }

    const tokens =
      (devices ?? [])
        .map((d) => d.fcm_token as string | null)
        .filter((t): t is string => !!t && t.length > 0);

    if (tokens.length === 0) {
      console.log("send-push: usuário sem tokens FCM.");
      return new Response("no tokens", {
        status: 200,
        headers: { "Content-Type": "text/plain" },
      });
    }

    if (!FCM_SERVER_KEY) {
      console.error("send-push: FCM_SERVER_KEY não configurada, abortando envio.");
      return new Response("fcm key missing", {
        status: 500,
        headers: { "Content-Type": "text/plain" },
      });
    }

    // 4) Monta payload pro FCM (legacy HTTP)
    const payload = {
      registration_ids: tokens,
      notification: {
        title: notif.title,
        body: notif.body,
      },
      data: {
        ...extraData,
        type: (extraData["type"] as string | undefined) ?? "generic",
        channel: notif.channel ?? "app",
      },
    };

    console.log(
      `send-push: enviando para FCM. tokens=${tokens.length}, title="${notif.title}"`,
    );

    const fcmResp = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `key=${FCM_SERVER_KEY}`,
      },
      body: JSON.stringify(payload),
    });

    const fcmText = await fcmResp.text();
    console.log("send-push: resposta FCM status", fcmResp.status, fcmText);

    return new Response("ok", {
      status: 200,
      headers: { "Content-Type": "text/plain" },
    });
  } catch (e) {
    console.error("send-push error:", e);
    return new Response("error", {
      status: 500,
      headers: { "Content-Type": "text/plain" },
    });
  }
});
