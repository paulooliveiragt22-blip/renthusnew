// supabase/functions/create-payment/index.ts
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

type Body = {
  job_id: string;
  quote_id: string;
  sandbox?: boolean;
};

type PixData = {
  qr_code: string;
  copy_paste: string;
  expires_at: string;
  qr_code_url: string;
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) return json({ error: "Missing bearer token" }, 401);

    const body = (await req.json()) as Body;
    const { job_id, quote_id, sandbox = false } = body;
    if (!job_id || !quote_id) return json({ error: "job_id and quote_id are required" }, 400);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SERVICE_ROLE_KEY")!;

    // Seleciona key Pagar.me conforme ambiente
    const pagarmeKey = sandbox
      ? (Deno.env.get("PAGARME_SANDBOX_KEY") ?? Deno.env.get("PAGARME_SECRET_KEY")!)
      : Deno.env.get("PAGARME_SECRET_KEY")!;

    if (!pagarmeKey) return json({ error: "PAGARME_SECRET_KEY not configured" }, 500);

    const platformRecipientId = sandbox
      ? (Deno.env.get("PAGARME_SANDBOX_PLATFORM_RECIPIENT_ID") ?? Deno.env.get("PAGARME_PLATFORM_RECIPIENT_ID"))
      : Deno.env.get("PAGARME_PLATFORM_RECIPIENT_ID");

    console.log(`Pagar.me: ${pagarmeKey.startsWith("sk_test_") ? "SANDBOX" : "PRODUÇÃO"}`);

    // Valida usuário
    const supabaseUser = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await supabaseUser.auth.getUser();
    if (userErr || !userData.user) return json({ error: "Invalid user" }, 401);
    const userId = userData.user.id;
    const userEmail = userData.user.email ?? "";

    const supabaseAdmin = createClient(supabaseUrl, serviceKey);

    // 1) Valida job
    const { data: job, error: jobErr } = await supabaseAdmin
      .from("jobs")
      .select("id, client_id, provider_id, status, payment_status, job_code, title")
      .eq("id", job_id)
      .maybeSingle();

    if (jobErr || !job) return json({ error: "Job not found" }, 404);
    if (job.client_id !== userId) return json({ error: "Not your job" }, 403);
    if (job.provider_id) return json({ error: "Job already has provider" }, 409);
    if (job.payment_status === "paid") return json({ error: "Job already paid" }, 409);

    // 2) Valida quote
    const { data: quote, error: quoteErr } = await supabaseAdmin
      .from("job_quotes")
      .select("id, job_id, provider_id, approximate_price")
      .eq("id", quote_id)
      .maybeSingle();

    if (quoteErr || !quote) return json({ error: "Quote not found" }, 404);
    if (quote.job_id !== job_id) return json({ error: "Quote does not belong to this job" }, 400);

    const amountTotal = Number(quote.approximate_price);
    if (!Number.isFinite(amountTotal) || amountTotal <= 0) return json({ error: "Invalid quote amount" }, 400);

    // 3) Evita duplicidade — se já existe pending com PIX, reusa o QR
    const { data: existing, error: exErr } = await supabaseAdmin
      .from("payments")
      .select("id, status, gateway_metadata")
      .eq("job_id", job_id)
      .in("status", ["pending", "paid"])
      .limit(1);

    if (exErr) return json({ error: "Failed checking existing payment" }, 500);

    if (existing && existing.length > 0) {
      const prev = existing[0];
      const prevPix = (prev.gateway_metadata as Record<string, unknown> | null)?.pix as PixData | undefined;
      // PIX ainda válido: devolve o QR sem criar novo
      if (prev.status === "pending" && prevPix?.qr_code) {
        return json({ ok: true, payment: prev, pix: prevPix, reused: true });
      }
      return json({ error: "Payment already exists", payment: prev }, 409);
    }

    // 4) Busca dados do cliente para o customer do Pagar.me
    const { data: client } = await supabaseAdmin
      .from("clients")
      .select("full_name, phone, cpf, address_zip_code, address_street, address_number, address_district, address_state, city")
      .eq("user_id", userId)
      .maybeSingle()
      .catch(() => ({ data: null }));

    const clientRec = client as Record<string, string | null> | null;
    const clientName = clientRec?.full_name ?? "Cliente";
    const cpfClean = (clientRec?.cpf ?? "").replace(/\D/g, "");
    const phoneRaw = clientRec?.phone ?? "";
    const phoneClean = phoneRaw.replace(/\D/g, "");
    const phoneDdd = phoneClean.substring(0, 2) || "11";
    const phoneNumber = phoneClean.substring(2) || "999999999";

    // 5) Busca recipient_id do prestador
    const { data: provider, error: providerErr } = await supabaseAdmin
      .from("providers")
      .select("id, pagarme_recipient_id")
      .eq("id", quote.provider_id)
      .maybeSingle();

    if (providerErr || !provider) return json({ error: "Provider not found" }, 404);
    if (!provider.pagarme_recipient_id) {
      return json({ error: "Prestador ainda não cadastrado no gateway de pagamento. Aguarde a ativação." }, 422);
    }

    // 6) Cria registro pending para ter o ID antes de chamar o Pagar.me
    const amountPlatform = Number((amountTotal * 0.15).toFixed(2));
    const amountProvider = Number((amountTotal - amountPlatform).toFixed(2));

    const { data: payment, error: payErr } = await supabaseAdmin
      .from("payments")
      .insert({
        job_id,
        client_id: userId,
        provider_id: quote.provider_id,
        quote_id,
        amount_total: amountTotal,
        amount_platform: amountPlatform,
        amount_provider: amountProvider,
        payment_method: "pix",
        gateway: "pagarme",
        status: "pending",
      })
      .select("id, job_id, provider_id, amount_total, amount_provider, amount_platform, status")
      .single();

    if (payErr || !payment) return json({ error: "Failed creating payment", details: payErr?.message }, 500);

    // 7) Cria order PIX no Pagar.me
    const amountCents = Math.round(amountTotal * 100);
    const jobCode = (job.job_code as string | null) ?? job_id.substring(0, 8).toUpperCase();

    const splitConfig = (provider.pagarme_recipient_id && platformRecipientId)
      ? [
          {
            recipient_id: provider.pagarme_recipient_id,
            type: "percentage",
            amount: 85,
            options: { liable: true, charge_processing_fee: true, charge_remainder_fee: true },
          },
          {
            recipient_id: platformRecipientId,
            type: "percentage",
            amount: 15,
            options: { liable: false, charge_processing_fee: false, charge_remainder_fee: false },
          },
        ]
      : undefined;

    const orderBody = {
      code: jobCode,
      items: [{ code: payment.id, amount: amountCents, description: `Serviço Renthus ${jobCode}`, quantity: 1 }],
      customer: {
        name: clientName,
        email: userEmail,
        type: "individual",
        ...(cpfClean ? { document: cpfClean, document_type: "cpf" } : {}),
        phones: { mobile_phone: { country_code: "55", area_code: phoneDdd, number: phoneNumber } },
      },
      payments: [
        {
          payment_method: "pix",
          pix: { expires_in: 3600 },
          ...(splitConfig ? { split: splitConfig } : {}),
        },
      ],
      metadata: { job_id, quote_id, renthus_payment_id: payment.id },
    };

    const basicAuth = btoa(`${pagarmeKey}:`);
    const pagarmeRes = await fetch("https://api.pagar.me/core/v5/orders", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Basic ${basicAuth}` },
      body: JSON.stringify(orderBody),
    });

    const pagarmeData = await pagarmeRes.json() as Record<string, unknown>;

    if (!pagarmeRes.ok) {
      // Marca como failed para não bloquear retentativa do usuário
      await supabaseAdmin
        .from("payments")
        .update({ status: "failed", updated_at: new Date().toISOString() })
        .eq("id", payment.id);

      console.error("Pagar.me error:", JSON.stringify(pagarmeData));
      return json({ error: "Erro ao criar cobrança PIX. Tente novamente.", details: pagarmeData }, 422);
    }

    // 8) Extrai QR Code da resposta do Pagar.me
    const charges = (pagarmeData.charges as Record<string, unknown>[]) ?? [];
    const charge = charges[0] ?? {};
    const lastTx = (charge.last_transaction ?? {}) as Record<string, unknown>;

    const orderId = pagarmeData.id as string;
    const chargeId = charge.id as string;
    const txId = lastTx.id as string;
    const qrCode = (lastTx.qr_code as string) ?? "";
    const expiresAt = (lastTx.expires_at as string) ?? "";
    const qrCodeUrl = txId
      ? `https://api.pagar.me/core/v5/transactions/${txId}/qrcode?payment_method=pix`
      : "";

    const pixData: PixData = { qr_code: qrCode, copy_paste: qrCode, expires_at: expiresAt, qr_code_url: qrCodeUrl };

    const gatewayMetadata = {
      pix: pixData,
      pagarme: { order_id: orderId, charge_id: chargeId, transaction_id: txId },
      payer: { name: clientName, email: userEmail, phone: phoneRaw, document: cpfClean },
      created_via: "app_checkout",
      payment_method: "pix",
    };

    // 9) Atualiza payment com dados Pagar.me
    await supabaseAdmin
      .from("payments")
      .update({ gateway_transaction_id: orderId, gateway_metadata: gatewayMetadata, updated_at: new Date().toISOString() })
      .eq("id", payment.id);

    return json({ ok: true, payment: { ...payment, gateway_transaction_id: orderId }, pix: pixData });
  } catch (e) {
    console.error("Unexpected error:", e);
    return json({ error: "Unexpected error", details: String(e) }, 500);
  }
});
