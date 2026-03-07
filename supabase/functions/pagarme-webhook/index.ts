// supabase/functions/pagarme-webhook/index.ts
//
// Eventos tratados:
//   order.paid            → marca payment como paid; trigger aceita o job
//   order.payment_failed  → marca payment como failed; notifica cliente
//   charge.paid           → parcela de crédito: registra no metadata (sem alterar status/job)
//   order.waiting_payment → apenas loga; sem ação (payment já está pending)
//   outros                → retorna 200 e loga (evita reenvio desnecessário)
//
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function toIso(raw: string | undefined): string {
  if (!raw) return new Date().toISOString();
  return new Date(raw.includes("T") ? raw : raw + "Z").toISOString();
}

/** Resolve renthus_payment_id a partir do metadata ou gateway_transaction_id. */
async function resolvePaymentId(
  supabase: ReturnType<typeof createClient>,
  meta: Record<string, string> | undefined,
  orderId: string | undefined,
): Promise<string | undefined> {
  if (meta?.renthus_payment_id) return meta.renthus_payment_id;
  if (!orderId) return undefined;
  const { data } = await supabase
    .from("payments")
    .select("id")
    .eq("gateway_transaction_id", orderId)
    .maybeSingle();
  return data?.id;
}

// ── Handler principal ─────────────────────────────────────────────────────────

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

  // Eventos não mapeados → 200 sem reprocessamento
  const knownEvents = ["order.paid", "order.payment_failed", "charge.paid", "order.waiting_payment"];
  if (!knownEvents.includes(eventType)) {
    console.log("Evento não mapeado:", eventType);
    return json({ ok: true, skipped: true, event: eventType });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = (Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SERVICE_ROLE_KEY"))!;
  const supabase = createClient(supabaseUrl, serviceKey);
  const data = payload.data as Record<string, unknown>;

  // ── order.waiting_payment ─────────────────────────────────────────────────
  if (eventType === "order.waiting_payment") {
    const orderId = data.id as string | undefined;
    console.log(`order.waiting_payment: orderId=${orderId} — payment já está pending, sem ação.`);
    return json({ ok: true, event: eventType });
  }

  // ── order.payment_failed ──────────────────────────────────────────────────
  if (eventType === "order.payment_failed") {
    const orderId = data.id as string | undefined;
    const orderMeta = data.metadata as Record<string, string> | undefined;
    const renthusPaymentId = await resolvePaymentId(supabase, orderMeta, orderId);

    if (!renthusPaymentId) {
      console.error("order.payment_failed: renthus_payment_id não encontrado. orderId:", orderId);
      return json({ ok: true, warning: "payment_id_not_found" });
    }

    const { data: payment } = await supabase
      .from("payments")
      .select("id, job_id, client_id, status")
      .eq("id", renthusPaymentId)
      .maybeSingle();

    if (!payment || payment.status === "paid") {
      console.log("order.payment_failed: payment não encontrado ou já pago — ignorando.");
      return json({ ok: true, skipped: true });
    }

    await supabase
      .from("payments")
      .update({ status: "failed", updated_at: new Date().toISOString() })
      .eq("id", renthusPaymentId);

    if (payment.client_id) {
      await supabase.from("notifications").insert({
        user_id: payment.client_id,
        type: "payment_failed",
        title: "Pagamento não aprovado",
        body: "Pagamento não aprovado. Tente novamente.",
        data: { job_id: payment.job_id, payment_id: renthusPaymentId },
      });
    }

    console.log(`order.payment_failed: payment ${renthusPaymentId} → failed.`);
    return json({ ok: true, event: eventType, payment_id: renthusPaymentId });
  }

  // ── charge.paid ───────────────────────────────────────────────────────────
  // Para PIX: charge.paid + order.paid chegam juntos; idempotência pelo status.
  // Para crédito parcelado: order.paid aceita o job; cada charge.paid subsequente
  // registra uma parcela no metadata sem alterar status/job.
  if (eventType === "charge.paid") {
    const chargeId  = data.id as string | undefined;
    const orderId   = data.order_id as string | undefined;
    const paidAt    = data.paid_at as string | undefined;
    const paidCents = data.paid_amount as number | undefined;
    const chargeMeta = data.metadata as Record<string, string> | undefined;
    const installmentNum = (data.installment as number | undefined) ?? 1;

    const renthusPaymentId = await resolvePaymentId(supabase, chargeMeta, orderId);
    if (!renthusPaymentId) {
      console.warn("charge.paid: renthus_payment_id não encontrado. orderId:", orderId);
      return json({ ok: true, warning: "payment_id_not_found" });
    }

    const { data: payment } = await supabase
      .from("payments")
      .select("id, job_id, client_id, provider_id, status, amount_total, gateway_metadata, metadata")
      .eq("id", renthusPaymentId)
      .maybeSingle();

    if (!payment) {
      console.error("charge.paid: payment não encontrado:", renthusPaymentId);
      return json({ ok: true, warning: "payment_not_found" });
    }

    if (payment.status === "paid") {
      // Parcela de crédito: registra no metadata sem alterar status/job
      const currentMeta = (payment.metadata ?? {}) as Record<string, unknown>;
      const parcelas = (currentMeta.parcelas_recebidas as unknown[]) ?? [];
      parcelas.push({
        numero: installmentNum,
        valor_centavos: paidCents,
        charge_id: chargeId,
        data: toIso(paidAt),
      });

      await supabase
        .from("payments")
        .update({
          metadata: { ...currentMeta, parcelas_recebidas: parcelas },
          updated_at: new Date().toISOString(),
        })
        .eq("id", renthusPaymentId);

      console.log(`charge.paid: parcela ${installmentNum} registrada em metadata do payment ${renthusPaymentId}.`);
      return json({ ok: true, event: eventType, installment: installmentNum });
    }

    // Payment ainda não pago (ex: PIX charge.paid chegou antes do order.paid)
    // Trata como order.paid para garantir confirmação
    console.log(`charge.paid: payment ${renthusPaymentId} ainda pending — tratando como confirmação.`);
    await _markPaid(supabase, payment, orderId, paidAt, eventType, payload);
    return json({ ok: true, event: eventType, payment_id: renthusPaymentId });
  }

  // ── order.paid ────────────────────────────────────────────────────────────
  {
    const orderId = data.id as string | undefined;
    const charges = (data.charges as Record<string, unknown>[]) ?? [];
    const charge  = charges[0] ?? {};
    const paidAt  = charge.paid_at as string | undefined;

    // Tenta metadata no order → na charge → por gateway_transaction_id
    const orderMeta  = data.metadata as Record<string, string> | undefined;
    const chargeMeta = charge.metadata as Record<string, string> | undefined;
    let renthusPaymentId = await resolvePaymentId(supabase, orderMeta, undefined);
    if (!renthusPaymentId) renthusPaymentId = await resolvePaymentId(supabase, chargeMeta, orderId);

    if (!renthusPaymentId) {
      console.error("order.paid: renthus_payment_id não encontrado. orderId:", orderId);
      return json({ error: "renthus_payment_id missing in metadata" }, 400);
    }

    const { data: payment, error: payErr } = await supabase
      .from("payments")
      .select("id, job_id, client_id, provider_id, status, amount_total, gateway_metadata, metadata")
      .eq("id", renthusPaymentId)
      .maybeSingle();

    if (payErr || !payment) {
      console.error("order.paid: payment não encontrado:", renthusPaymentId);
      return json({ error: "Payment not found" }, 404);
    }

    if (payment.status === "paid") {
      console.log("order.paid: payment já pago — ignorando duplicata:", renthusPaymentId);
      return json({ ok: true, duplicate: true });
    }

    await _markPaid(supabase, payment, orderId, paidAt, eventType, payload);
    console.log(`order.paid: payment ${renthusPaymentId} → paid. Job ${payment.job_id} → accepted (via trigger).`);
    return json({ ok: true, payment_id: renthusPaymentId, job_id: payment.job_id });
  }
});

// ── Marca payment como paid e notifica cliente + prestador ───────────────────

async function _markPaid(
  supabase: ReturnType<typeof createClient>,
  payment: Record<string, unknown>,
  orderId: string | undefined,
  paidAt: string | undefined,
  eventType: string,
  payload: Record<string, unknown>,
) {
  const paidAtIso = toIso(paidAt);
  const existingGwMeta = (payment.gateway_metadata ?? {}) as Record<string, unknown>;
  const updatedGwMeta = {
    ...existingGwMeta,
    pagarme_webhook: {
      last_event_at: (payload.created_at as string) ?? new Date().toISOString(),
      last_event_type: eventType,
    },
  };

  await supabase
    .from("payments")
    .update({
      status: "paid",
      paid_at: paidAtIso,
      gateway_transaction_id: orderId ?? (existingGwMeta as Record<string, unknown>)?.pagarme?.order_id ?? "",
      gateway_metadata: updatedGwMeta,
      updated_at: new Date().toISOString(),
    })
    .eq("id", payment.id);

  // Notificações
  const { data: providerRow } = await supabase
    .from("providers")
    .select("user_id")
    .eq("id", payment.provider_id)
    .maybeSingle();

  const amountBrl = Number(payment.amount_total);
  const amountFmt = `R$ ${amountBrl.toFixed(2).replace(".", ",")}`;
  const paymentId = payment.id as string;
  const jobId     = payment.job_id as string;
  const clientId  = payment.client_id as string | undefined;

  const notifs: Record<string, unknown>[] = [];
  if (clientId) {
    notifs.push({
      user_id: clientId,
      type:    "payment_confirmed",
      title:   "Pagamento confirmado!",
      body:    `Seu pagamento de ${amountFmt} foi confirmado. O prestador já foi notificado.`,
      data:    { job_id: jobId, payment_id: paymentId, amount: amountBrl },
    });
  }
  if (providerRow?.user_id) {
    notifs.push({
      user_id: providerRow.user_id,
      type:    "payment_received",
      title:   "Você tem um novo serviço!",
      body:    `O cliente confirmou o pagamento de ${amountFmt}. Combine os detalhes pelo chat.`,
      data:    { job_id: jobId, payment_id: paymentId, amount: amountBrl },
    });
  }
  if (notifs.length > 0) {
    const { error: notifErr } = await supabase.from("notifications").insert(notifs);
    if (notifErr) console.warn("Erro ao criar notificações:", notifErr.message);
  }
}
