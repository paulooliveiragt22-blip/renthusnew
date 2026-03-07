// supabase/functions/check-payment/index.ts
// Consulta o status do pedido diretamente na API do Pagar.me e atualiza o banco se pago.
// Chamado pelo app durante polling quando o webhook não chega a tempo.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) return json({ error: "Missing bearer token" }, 401);

  const body = await req.json() as { payment_id?: string; job_id?: string; sandbox?: boolean };
  const { payment_id, job_id, sandbox = false } = body;

  if (!payment_id && !job_id) return json({ error: "payment_id or job_id required" }, 400);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = (Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SERVICE_ROLE_KEY"))!;

  // Valida usuário autenticado
  const supabaseUser = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await supabaseUser.auth.getUser();
  if (userErr || !userData.user) return json({ error: "Invalid user" }, 401);

  const supabaseAdmin = createClient(supabaseUrl, serviceKey);

  // Busca payment
  let query = supabaseAdmin
    .from("payments")
    .select("id, job_id, provider_id, client_id, status, gateway_transaction_id, gateway_metadata, amount_total")
    .in("status", ["pending"]);

  if (payment_id) query = query.eq("id", payment_id);
  else query = query.eq("job_id", job_id!);

  const { data: payment, error: payErr } = await query.maybeSingle();

  if (payErr || !payment) {
    // Pode já estar pago
    const { data: paidPayment } = await supabaseAdmin
      .from("payments")
      .select("id, status")
      .eq(payment_id ? "id" : "job_id", payment_id ?? job_id!)
      .eq("status", "paid")
      .maybeSingle();

    if (paidPayment) return json({ ok: true, status: "paid", already_paid: true });
    return json({ error: "Payment not found or not pending" }, 404);
  }

  const orderId = payment.gateway_transaction_id as string | undefined;
  if (!orderId) {
    return json({ ok: true, status: payment.status, message: "No gateway_transaction_id yet" });
  }

  // Consulta Pagar.me
  const pagarmeKey = sandbox
    ? (Deno.env.get("PAGARME_SANDBOX_KEY") ?? Deno.env.get("PAGARME_SECRET_KEY")!)
    : Deno.env.get("PAGARME_SECRET_KEY")!;

  const basicAuth = btoa(`${pagarmeKey}:`);
  const pagarmeRes = await fetch(`https://api.pagar.me/core/v5/orders/${orderId}`, {
    headers: { Authorization: `Basic ${basicAuth}` },
  });

  if (!pagarmeRes.ok) {
    console.error("Pagar.me API error:", pagarmeRes.status);
    return json({ ok: false, error: "Failed to query Pagar.me", status: payment.status });
  }

  const order = await pagarmeRes.json() as Record<string, unknown>;
  const orderStatus = order.status as string;
  console.log(`Pagar.me order ${orderId} status: ${orderStatus}`);

  if (orderStatus !== "paid") {
    return json({ ok: true, status: payment.status, pagarme_status: orderStatus });
  }

  // Extrai paid_at da charge
  const charges = (order.charges as Record<string, unknown>[]) ?? [];
  const charge = charges[0] ?? {};
  const paidAtRaw = charge.paid_at as string | undefined;
  const paidAt = paidAtRaw
    ? new Date(paidAtRaw.includes("T") ? paidAtRaw : paidAtRaw + "Z").toISOString()
    : new Date().toISOString();

  const existingMeta = (payment.gateway_metadata ?? {}) as Record<string, unknown>;
  const updatedMeta = {
    ...existingMeta,
    pagarme_check: { checked_at: new Date().toISOString(), order_status: orderStatus },
  };

  // Atualiza payment → trigger apply_payment_paid_effects cuida do job
  const { error: updateErr } = await supabaseAdmin
    .from("payments")
    .update({
      status: "paid",
      paid_at: paidAt,
      gateway_metadata: updatedMeta,
      updated_at: new Date().toISOString(),
    })
    .eq("id", payment.id);

  if (updateErr) {
    console.error("Erro ao atualizar payment:", updateErr.message);
    return json({ error: "Failed updating payment", details: updateErr.message }, 500);
  }

  console.log(`Payment ${payment.id} marcado como paid via check-payment (fallback).`);
  return json({ ok: true, status: "paid", payment_id: payment.id, job_id: payment.job_id });
});
