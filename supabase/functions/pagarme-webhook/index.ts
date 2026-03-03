// supabase/functions/pagarme-webhook/index.ts
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "GET" || req.method === "HEAD") return json({ ok: true });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  // Autenticação via ?secret= na URL (configurado no dashboard Pagar.me)
  const expectedSecret = Deno.env.get("PAGARME_WEBHOOK_SECRET") ?? "";
  const gotSecret = new URL(req.url).searchParams.get("secret") ?? "";
  if (!expectedSecret || gotSecret !== expectedSecret) {
    console.warn("Webhook auth failed. Got:", gotSecret ? "***" : "(empty)");
    return json({ error: "Unauthorized webhook" }, 401);
  }

  const rawBody = await req.text();
  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const eventType = (payload.type as string) ?? "";
  console.log(`Webhook recebido: type=${eventType}`);

  if (eventType !== "order.paid" && eventType !== "charge.paid") {
    console.log("Evento ignorado:", eventType);
    return json({ ok: true, skipped: true });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = (Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SERVICE_ROLE_KEY"))!;
  const supabase = createClient(supabaseUrl, serviceKey);

  const data = payload.data as Record<string, unknown>;

  let renthusPaymentId: string | undefined;
  let orderId: string | undefined;
  let paidAt: string | undefined;

  if (eventType === "order.paid") {
    orderId = data.id as string;
    const charges = (data.charges as Record<string, unknown>[]) ?? [];
    const charge = charges[0] ?? {};
    paidAt = charge.paid_at as string | undefined;
    const meta = charge.metadata as Record<string, string> | undefined;
    renthusPaymentId = meta?.renthus_payment_id;

    // Fallback: busca por gateway_transaction_id
    if (!renthusPaymentId && orderId) {
      const { data: p } = await supabase
        .from("payments")
        .select("id")
        .eq("gateway_transaction_id", orderId)
        .maybeSingle();
      renthusPaymentId = p?.id;
    }
  } else {
    // charge.paid
    const chargeData = data;
    orderId = chargeData.order_id as string | undefined;
    paidAt = chargeData.paid_at as string | undefined;
    const meta = chargeData.metadata as Record<string, string> | undefined;
    renthusPaymentId = meta?.renthus_payment_id;
  }

  if (!renthusPaymentId) {
    console.error("renthus_payment_id não encontrado — tentando por gateway_transaction_id:", orderId);
    return json({ error: "renthus_payment_id missing in metadata" }, 400);
  }

  // Busca payment
  const { data: payment, error: payErr } = await supabase
    .from("payments")
    .select("id, job_id, provider_id, client_id, status, amount_total")
    .eq("id", renthusPaymentId)
    .maybeSingle();

  if (payErr || !payment) {
    console.error("Payment não encontrado:", renthusPaymentId);
    return json({ error: "Payment not found" }, 404);
  }

  if (payment.status === "paid") {
    console.log("Payment já pago — ignorando duplicata:", renthusPaymentId);
    return json({ ok: true, duplicate: true });
  }

  const paidAtIso = paidAt
    ? new Date(paidAt.includes("T") ? paidAt : paidAt + "Z").toISOString()
    : new Date().toISOString();

  const existingMeta = (payment.gateway_metadata ?? {}) as Record<string, unknown>;
  const updatedMeta = {
    ...existingMeta,
    pagarme_webhook: {
      last_event_at: (payload.created_at as string) ?? new Date().toISOString(),
      last_event_type: eventType,
    },
  };

  // Atualiza payment → trigger apply_payment_paid_effects cuida do job
  const { error: updateErr } = await supabase
    .from("payments")
    .update({
      status: "paid",
      paid_at: paidAtIso,
      gateway_transaction_id: orderId ?? "",
      gateway_metadata: updatedMeta,
      updated_at: new Date().toISOString(),
    })
    .eq("id", renthusPaymentId);

  if (updateErr) {
    console.error("Erro ao atualizar payment:", updateErr.message);
    return json({ error: "Failed updating payment", details: updateErr.message }, 500);
  }

  // Notificações
  const { data: providerRow } = await supabase
    .from("providers")
    .select("user_id")
    .eq("id", payment.provider_id)
    .maybeSingle();

  const notifPayload = {
    type: "payment_paid",
    data: { amount: Number(payment.amount_total), job_id: payment.job_id, payment_id: renthusPaymentId },
  };

  const notifs: Record<string, unknown>[] = [];
  if (payment.client_id) notifs.push({ user_id: payment.client_id, ...notifPayload });
  if (providerRow?.user_id) notifs.push({ user_id: providerRow.user_id, ...notifPayload });
  if (notifs.length > 0) {
    const { error: notifErr } = await supabase.from("notifications").insert(notifs);
    if (notifErr) console.warn("Erro ao criar notificações:", notifErr.message);
  }

  console.log(`Pagamento ${renthusPaymentId} processado. Job ${payment.job_id} → accepted`);
  return json({ ok: true, payment_id: renthusPaymentId, job_id: payment.job_id });
});
