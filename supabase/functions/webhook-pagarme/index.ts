// supabase/functions/webhook-pagarme/index.ts
//
// Recebe webhooks do Pagar.me (order.paid, charge.paid, charge.payment_failed)
// e atualiza payments + jobs + notifications.
//
// Configurar no Dashboard Pagar.me → Webhooks:
//   URL: https://dqfejuakbtcxhymrxoqs.supabase.co/functions/v1/webhook-pagarme
//   Eventos: order.paid, charge.paid, charge.payment_failed
//   Segredo: setar PAGARME_WEBHOOK_SECRET no Supabase Secrets
//
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Valida assinatura HMAC-SHA256 enviada pelo Pagar.me no header X-Hub-Signature */
async function verifySignature(rawBody: string, signatureHeader: string, secret: string): Promise<boolean> {
  try {
    const encoder = new TextEncoder();
    const key = await crypto.subtle.importKey(
      "raw",
      encoder.encode(secret),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"],
    );
    const sigBytes = await crypto.subtle.sign("HMAC", key, encoder.encode(rawBody));
    const computed = "sha256=" + Array.from(new Uint8Array(sigBytes))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");
    return computed === signatureHeader;
  } catch {
    return false;
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const rawBody = await req.text();
  let payload: Record<string, unknown>;

  try {
    payload = JSON.parse(rawBody);
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  // Valida assinatura se secret estiver configurado
  const webhookSecret = Deno.env.get("PAGARME_WEBHOOK_SECRET");
  if (webhookSecret) {
    const sigHeader = req.headers.get("X-Hub-Signature") ?? req.headers.get("x-pagarme-signature") ?? "";
    const valid = await verifySignature(rawBody, sigHeader, webhookSecret);
    if (!valid) {
      console.warn("Webhook signature mismatch. Header:", sigHeader);
      return json({ error: "Invalid signature" }, 401);
    }
  } else {
    console.warn("PAGARME_WEBHOOK_SECRET not set — skipping signature validation");
  }

  const eventType = payload.type as string | undefined;
  console.log(`Webhook recebido: type=${eventType}`);

  // Só processa eventos de pagamento bem-sucedido
  if (eventType !== "order.paid" && eventType !== "charge.paid") {
    console.log("Evento ignorado:", eventType);
    return json({ ok: true, skipped: true });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceKey);

  // Extrai dados do pedido e cobrança
  const data = payload.data as Record<string, unknown>;

  let renthusPaymentId: string | undefined;
  let orderId: string | undefined;
  let chargeId: string | undefined;
  let paidAt: string | undefined;
  let paidAmountCents: number | undefined;

  if (eventType === "order.paid") {
    orderId = data.id as string;
    const charges = (data.charges as Record<string, unknown>[]) ?? [];
    const charge = charges[0] ?? {};
    chargeId = charge.id as string;
    paidAt = charge.paid_at as string | undefined;
    paidAmountCents = charge.paid_amount as number | undefined;
    const meta = charge.metadata as Record<string, string> | undefined;
    renthusPaymentId = meta?.renthus_payment_id;
  } else {
    // charge.paid
    chargeId = data.id as string;
    orderId = data.order_id as string | undefined;
    paidAt = data.paid_at as string | undefined;
    paidAmountCents = data.paid_amount as number | undefined;
    const meta = data.metadata as Record<string, string> | undefined;
    renthusPaymentId = meta?.renthus_payment_id;
  }

  if (!renthusPaymentId) {
    console.error("renthus_payment_id não encontrado no metadata do webhook");
    return json({ error: "renthus_payment_id missing in metadata" }, 400);
  }

  // Busca payment no banco
  const { data: payment, error: payErr } = await supabase
    .from("payments")
    .select("id, job_id, provider_id, client_id, status, gateway_metadata, amount_total")
    .eq("id", renthusPaymentId)
    .maybeSingle();

  if (payErr || !payment) {
    console.error("Payment não encontrado:", renthusPaymentId);
    return json({ error: "Payment not found" }, 404);
  }

  if (payment.status === "paid") {
    console.log("Payment já marcado como paid — ignorando duplicata:", renthusPaymentId);
    return json({ ok: true, duplicate: true });
  }

  const paidAtIso = paidAt
    ? new Date(paidAt.includes("T") ? paidAt : paidAt + "Z").toISOString()
    : new Date().toISOString();

  // Mescla webhook payload no gateway_metadata existente
  const existingMeta = (payment.gateway_metadata ?? {}) as Record<string, unknown>;
  const updatedMeta = {
    ...existingMeta,
    pagarme_webhook: {
      last_payload: payload,
      last_event_at: (payload.created_at as string) ?? new Date().toISOString(),
      last_event_type: eventType,
    },
  };

  // 1) Atualiza payments
  const { error: updatePayErr } = await supabase
    .from("payments")
    .update({
      status: "paid",
      paid_at: paidAtIso,
      gateway_transaction_id: orderId ?? payment.gateway_metadata?.pagarme?.order_id,
      gateway_metadata: updatedMeta,
      updated_at: new Date().toISOString(),
    })
    .eq("id", renthusPaymentId);

  if (updatePayErr) {
    console.error("Erro ao atualizar payment:", updatePayErr.message);
    return json({ error: "Failed updating payment" }, 500);
  }

  // 2) Atualiza jobs
  const { data: job, error: jobErr } = await supabase
    .from("jobs")
    .select("id, client_id, status, amount_provider")
    .eq("id", payment.job_id)
    .maybeSingle();

  if (jobErr || !job) {
    console.error("Job não encontrado para payment:", payment.job_id);
    return json({ error: "Job not found" }, 404);
  }

  const amountProviderBrl = paidAmountCents != null
    ? Number(((paidAmountCents * 0.85) / 100).toFixed(2))
    : Number(payment.amount_total) * 0.85;

  const { error: updateJobErr } = await supabase
    .from("jobs")
    .update({
      payment_status: "paid",
      provider_id: payment.provider_id,
      status: "accepted",
      paid_at: paidAtIso,
      amount_provider: amountProviderBrl,
    })
    .eq("id", payment.job_id);

  if (updateJobErr) {
    console.error("Erro ao atualizar job:", updateJobErr.message);
    // Não retorna erro — payment já foi marcado como pago
  }

  // 3) Busca user_id do prestador para notificação
  const { data: providerRow } = await supabase
    .from("providers")
    .select("user_id")
    .eq("id", payment.provider_id)
    .maybeSingle();

  const providerUserId = providerRow?.user_id as string | undefined;

  // 4) Cria notificações para cliente e prestador
  const amountBrl = Number(payment.amount_total);
  const notifPayload = {
    type: "payment_paid",
    data: { amount: amountBrl, job_id: payment.job_id, payment_id: renthusPaymentId },
  };

  const notificationsToInsert: Record<string, unknown>[] = [
    { user_id: job.client_id, ...notifPayload },
  ];
  if (providerUserId) {
    notificationsToInsert.push({ user_id: providerUserId, ...notifPayload });
  }

  const { error: notifErr } = await supabase.from("notifications").insert(notificationsToInsert);
  if (notifErr) {
    console.warn("Erro ao criar notificações:", notifErr.message);
  }

  console.log(`Pagamento ${renthusPaymentId} processado com sucesso. Job ${payment.job_id} → accepted`);
  return json({ ok: true, payment_id: renthusPaymentId, job_id: payment.job_id });
});
