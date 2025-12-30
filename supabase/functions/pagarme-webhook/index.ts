// supabase/functions/pagarme-webhook/index.ts
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

function json(status: number, payload: unknown) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

type PagarmeWebhook = {
  id?: string; // hook_...
  type?: string; // "order.paid"
  created_at?: string; // timestamp
  data?: {
    id?: string; // order_id => "or_..."
    status?: string; // "paid" etc
    charges?: Array<{
      id?: string; // charge_id => "ch_..."
      status?: string; // "paid"
      paid_at?: string; // timestamp
      last_transaction?: {
        id?: string; // transaction_id => "tran_..."
      };
    }>;
  };
};

Deno.serve(async (req) => {
  try {
    // Ping simples (alguns providers testam a URL)
    if (req.method === "GET" || req.method === "HEAD") {
      return json(200, { ok: true });
    }
    if (req.method !== "POST") {
      return json(405, { error: "Method not allowed" });
    }

    // ✅ Segurança do MVP: segredo na URL (?token=...)
    // Configure no Pagar.me:
    // https://<project>.functions.supabase.co/pagarme-webhook?token=<PAGARME_WEBHOOK_SECRET>
    const expectedSecret = Deno.env.get("PAGARME_WEBHOOK_SECRET") ?? "";
    const url = new URL(req.url);
    const gotSecret = url.searchParams.get("secret") ?? "";


    if (!expectedSecret || gotSecret !== expectedSecret) {
      return json(401, { error: "Unauthorized webhook" });
    }

    const payload = (await req.json()) as PagarmeWebhook;

    const eventType = (payload.type ?? "").toString();
    const orderId = (payload.data?.id ?? "").toString();

    console.log("PAGARME_WEBHOOK_RECEIVED", {
      type: eventType,
      order_id: orderId,
      hook_id: payload.id ?? null,
      created_at: payload.created_at ?? null,
    });

    if (!eventType || !orderId) {
      return json(400, { error: "Invalid webhook payload (missing type/data.id)" });
    }

    // Aceita apenas os eventos do MVP
    if (eventType !== "order.paid" && eventType !== "order.payment_failed") {
      return json(200, { ok: true, ignored: true, type: eventType });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceKey) {
      return json(500, {
        error: "Missing env vars",
        details: "SUPABASE_URL or SERVICE_ROLE_KEY not set",
      });
    }

    const supabaseAdmin = createClient(supabaseUrl, serviceKey);

    // Encontrar payment pelo order_id (gateway_transaction_id = order_id)
    // IMPORTANTE: no create-payment, salve gateway_transaction_id = order_id ("or_...")
    const { data: payment, error: findErr } = await supabaseAdmin
      .from("payments")
      .select("id, job_id, provider_id, status, gateway_metadata, gateway_transaction_id")
      .eq("gateway_transaction_id", orderId)
      .maybeSingle();

    if (findErr) {
      console.error("PAGARME_WEBHOOK_FIND_PAYMENT_ERROR", findErr);
      return json(500, { error: "Failed to find payment", details: findErr.message });
    }

    if (!payment) {
      console.warn("PAGARME_WEBHOOK_PAYMENT_NOT_FOUND", { order_id: orderId });
      // Retorna 200 pra evitar retries infinitos
      return json(200, { ok: true, not_found: true, order_id: orderId });
    }

    // Idempotência: se já está paid, não faz nada
    if (eventType === "order.paid" && payment.status === "paid") {
      return json(200, { ok: true, idempotent: true, payment_id: payment.id });
    }

    const firstCharge = payload.data?.charges?.[0];
    const paidAt = firstCharge?.paid_at ?? payload.created_at ?? new Date().toISOString();

    const baseMetadata = payment.gateway_metadata ?? {};
    const pagarmeMeta = (baseMetadata as any)?.pagarme ?? {};

    // ✅ order.paid  => payments.status = "paid"
    if (eventType === "order.paid") {
      const newMetadata = {
        ...baseMetadata,
        pagarme_webhook: {
          last_event_type: eventType,
          last_event_at: payload.created_at ?? null,
          // cuidado com tamanho; se precisar, remova o last_payload
          last_payload: payload,
        },
        pagarme: {
          ...pagarmeMeta,
          order_id: orderId,
          charge_id: firstCharge?.id ?? pagarmeMeta?.charge_id ?? null,
          transaction_id:
            firstCharge?.last_transaction?.id ?? pagarmeMeta?.transaction_id ?? null,
        },
      };

      const { error: updErr } = await supabaseAdmin
        .from("payments")
        .update({
          status: "paid",
          paid_at: paidAt,
          gateway_metadata: newMetadata,
        })
        .eq("id", payment.id);

      if (updErr) {
        console.error("PAGARME_WEBHOOK_UPDATE_PAYMENT_ERROR", updErr);
        return json(500, { error: "Failed to update payment to paid", details: updErr.message });
      }

      // Atualizar job (não falha o webhook se isso der problema)
      const { error: jobErr } = await supabaseAdmin
        .from("jobs")
        .update({
          payment_status: "paid",
          provider_id: payment.provider_id ?? null,
        })
        .eq("id", payment.job_id);

      if (jobErr) {
        console.error("PAGARME_WEBHOOK_UPDATE_JOB_ERROR", jobErr);
        return json(200, {
          ok: true,
          handled: true,
          type: eventType,
          payment_id: payment.id,
          job_update_error: jobErr.message,
        });
      }

      return json(200, { ok: true, handled: true, type: eventType, payment_id: payment.id });
    }

    // ✅ order.payment_failed => payments.status = "failed"
    {
      const newMetadata = {
        ...baseMetadata,
        pagarme_webhook: {
          last_event_type: eventType,
          last_event_at: payload.created_at ?? null,
          last_payload: payload,
        },
        pagarme: {
          ...pagarmeMeta,
          order_id: orderId,
        },
      };

      const { error: updErr } = await supabaseAdmin
        .from("payments")
        .update({
          status: "failed",
          gateway_metadata: newMetadata,
        })
        .eq("id", payment.id);

      if (updErr) {
        console.error("PAGARME_WEBHOOK_UPDATE_PAYMENT_FAILED_ERROR", updErr);
        return json(500, {
          error: "Failed to update payment after failure",
          details: updErr.message,
        });
      }

      return json(200, { ok: true, handled: true, type: eventType, payment_id: payment.id });
    }
  } catch (e) {
    console.error("PAGARME_WEBHOOK_UNEXPECTED_ERROR", e);
    return json(500, { error: "Unexpected error", details: String(e) });
  }
});
