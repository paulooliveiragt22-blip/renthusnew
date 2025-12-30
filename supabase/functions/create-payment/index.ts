// supabase/functions/create-payment/index.ts
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

type Payer = {
    name: string;
    email?: string | null;
    document: string; // CPF (somente números)
    phone?: string | null; // DDD + número
};

type BillingAddress = {
    zip_code: string;
    street: string;
    number: string;
    complement?: string | null;
    neighborhood: string;
    city: string;
    state: string; // UF
    country?: string; // BR
};

type Body = {
    job_id: string;
    quote_id: string;
    payment_method?: "pix" | "card" | string;

    payer?: Payer;
    billing_address?: BillingAddress | null;

    // card-only
    card_token?: string | null;

    // força criar novo pagamento substituindo pending anterior
    force_new?: boolean | null;
};

function json(status: number, payload: unknown) {
    return new Response(JSON.stringify(payload), {
        status,
        headers: { "Content-Type": "application/json" },
    });
}

function digitsOnly(v: string) {
    return (v ?? "").replace(/[^\d]/g, "");
}

function isValidEmail(v: string) {
    if (!v) return false;
    return v.includes("@") && v.includes(".");
}

function isValidUF(uf: string) {
    return /^[A-Z]{2}$/.test(uf);
}

function normalizePhoneBR(raw: string) {
    const d = digitsOnly(raw ?? "");
    if (d.length < 10 || d.length > 11) return null;
    return d;
}

function normalizeBillingAddressForCard(addr: BillingAddress): BillingAddress {
    const zip = digitsOnly((addr.zip_code ?? "").toString());
    const street = (addr.street ?? "").trim();
    const number = (addr.number ?? "").trim();
    const neighborhood = (addr.neighborhood ?? "").trim();
    const city = (addr.city ?? "").trim();
    const state = (addr.state ?? "").toString().trim().toUpperCase();

    if (zip.length !== 8) throw new Error("billing_address.zip_code must have 8 digits");
    if (!street) throw new Error("billing_address.street is required");
    if (!number) throw new Error("billing_address.number is required");
    if (!neighborhood) throw new Error("billing_address.neighborhood is required");
    if (!city) throw new Error("billing_address.city is required");
    if (!isValidUF(state)) throw new Error("billing_address.state must be a valid UF (ex: MT)");

    return {
        zip_code: zip,
        street,
        number,
        complement: (addr.complement ?? "").toString().trim() || null,
        neighborhood,
        city,
        state,
        country: "BR",
    };
}

function normalizeBillingAddressForPix(addr: BillingAddress): BillingAddress | null {
    const state = (addr.state ?? "").toString().trim().toUpperCase();
    const zip = digitsOnly((addr.zip_code ?? "").toString());

    const hasAny =
        zip ||
        (addr.street ?? "").trim() ||
        (addr.number ?? "").trim() ||
        (addr.neighborhood ?? "").trim() ||
        (addr.city ?? "").trim() ||
        state;

    if (!hasAny) return null;

    return {
        zip_code: zip,
        street: (addr.street ?? "").toString().trim(),
        number: (addr.number ?? "").toString().trim(),
        complement: (addr.complement ?? "").toString().trim() || null,
        neighborhood: (addr.neighborhood ?? "").toString().trim(),
        city: (addr.city ?? "").toString().trim(),
        state,
        country: (addr.country ?? "BR").toString().trim() || "BR",
    };
}

function basicAuth(secretKey: string) {
    const token = btoa(`${secretKey}:`);
    return `Basic ${token}`;
}

function safeStr(v: unknown) {
    const s = (v ?? "").toString();
    return s.trim();
}

/**
 * Pagar.me Core v5: billing_address (card) costuma aceitar:
 * { line_1, line_2?, zip_code, city, state, country }
 */
function toPagarmeBillingAddress(addr: BillingAddress) {
    const line_1 = `${(addr.street ?? "").trim()}, ${(addr.number ?? "").trim()} - ${(addr.neighborhood ?? "").trim()}`.trim();
    const line_2 = (addr.complement ?? "").toString().trim() || undefined;

    return {
        line_1,
        ...(line_2 ? { line_2 } : {}),
        zip_code: digitsOnly((addr.zip_code ?? "").toString()),
        city: (addr.city ?? "").toString().trim(),
        state: (addr.state ?? "").toString().trim().toUpperCase(),
        country: (addr.country ?? "BR").toString().trim() || "BR",
    };
}

/**
 * ✅ Gateway (cartão) exige:
 * credit_card.billing.value + credit_card.billing.address (street/number/etc)
 */
function toGatewayBillingAddress(addr: BillingAddress) {
    return {
        zip_code: digitsOnly((addr.zip_code ?? "").toString()),
        street: (addr.street ?? "").toString().trim(),
        number: (addr.number ?? "").toString().trim(),
        neighborhood: (addr.neighborhood ?? "").toString().trim(),
        city: (addr.city ?? "").toString().trim(),
        state: (addr.state ?? "").toString().trim().toUpperCase(),
        country: (addr.country ?? "BR").toString().trim() || "BR",
        ...(safeStr(addr.complement ?? "") ? { complement: safeStr(addr.complement) } : {}),
    };
}

function extractPixFromPagarme(order: any) {
    const charge = order?.charges?.[0] ?? order?.charge ?? null;
    const tx = charge?.last_transaction ?? charge?.transactions?.[0] ?? charge?.transaction ?? null;

    const qrFromObj =
        safeStr(tx?.qr_code?.emv) ||
        safeStr(tx?.qr_code?.code) ||
        safeStr(tx?.qr_code?.qr_code) ||
        "";

    const qr_code =
        safeStr(tx?.qr_code) && safeStr(tx?.qr_code) !== "[object Object]"
            ? safeStr(tx?.qr_code)
            : qrFromObj || safeStr(tx?.pix_qr_code) || safeStr(tx?.emv) || null;

    const qr_code_url =
        safeStr(tx?.qr_code_url) ||
        safeStr(tx?.qr_code?.qr_code_url) ||
        safeStr(tx?.qr_code?.url) ||
        safeStr(tx?.pix_qr_code_url) ||
        safeStr(tx?.qr_code_url_png) ||
        null;

    const expires_at = safeStr(tx?.expires_at) || safeStr(tx?.pix_expiration_date) || safeStr(charge?.due_at) || null;

    return {
        order_id: safeStr(order?.id) || null,
        charge_id: safeStr(charge?.id) || null,
        transaction_id: safeStr(tx?.id) || null,
        pix: {
            qr_code: qr_code || null,
            qr_code_url: qr_code_url || null,
            expires_at: expires_at || null,
            copy_paste: qr_code || null,
        },
    };
}

function extractCardFromPagarme(order: any) {
    const charge = order?.charges?.[0] ?? order?.charge ?? null;
    const tx = charge?.last_transaction ?? charge?.transactions?.[0] ?? charge?.transaction ?? null;

    const order_status = safeStr(order?.status).toLowerCase() || null;
    const charge_status = safeStr(charge?.status).toLowerCase() || null;

    const brand = safeStr(tx?.card?.brand) || safeStr(tx?.credit_card?.card?.brand) || null;
    const last4 =
        safeStr(tx?.card?.last_four_digits) ||
        safeStr(tx?.credit_card?.card?.last_four_digits) ||
        safeStr(tx?.card?.last4) ||
        null;

    return {
        order_id: safeStr(order?.id) || null,
        charge_id: safeStr(charge?.id) || null,
        transaction_id: safeStr(tx?.id) || null,
        status: {
            order: order_status,
            charge: charge_status,
            transaction: safeStr(tx?.status).toLowerCase() || null,
        },
        card: { brand, last4 },
    };
}

function extractGatewayErrorMessage(orderOrCharge: any): string | null {
    const charge = orderOrCharge?.charges?.[0] ?? orderOrCharge?.charge ?? orderOrCharge ?? null;
    const tx = charge?.last_transaction ?? charge?.transactions?.[0] ?? charge?.transaction ?? null;

    const msg =
        safeStr(tx?.gateway_response?.errors?.[0]?.message) ||
        safeStr(tx?.gateway_response?.error) ||
        safeStr(charge?.last_transaction?.gateway_response?.errors?.[0]?.message) ||
        safeStr(orderOrCharge?.message) ||
        "";

    return msg || null;
}

function isPaidStatus(s: string) {
    const x = (s ?? "").toLowerCase();
    return x === "paid";
}
function isFailedStatus(s: string) {
    const x = (s ?? "").toLowerCase();
    return x === "failed";
}

function buildPendingConflictMessage(existingMethod: "pix" | "card", requested: "pix" | "card") {
    const existingLabel = existingMethod === "pix" ? "Pix" : "cartão";
    const requestedLabel = requested === "pix" ? "Pix" : "cartão";
    return `Você já tem um pagamento pendente por ${existingLabel}. Deseja continuar nele ou trocar para ${requestedLabel}?`;
}

Deno.serve(async (req) => {
    try {
        if (req.method !== "POST") return json(405, { error: "Method not allowed" });

        const authHeader = req.headers.get("Authorization") ?? "";
        if (!authHeader.startsWith("Bearer ")) return json(401, { error: "Missing bearer token" });

        const body = (await req.json()) as Body;

        const job_id = safeStr(body.job_id);
        const quote_id = safeStr(body.quote_id);

        const methodRaw = safeStr(body.payment_method ?? "pix").toLowerCase();
        const payment_method: "pix" | "card" = methodRaw === "card" ? "card" : "pix";

        const force_new = Boolean(body.force_new);

        if (!job_id || !quote_id) return json(400, { error: "job_id and quote_id are required" });

        const payer = body.payer;
        if (!payer) return json(400, { error: "payer is required" });

        const payerName = safeStr(payer.name);
        const payerEmail = safeStr(payer.email ?? "");
        const payerDoc = digitsOnly(safeStr(payer.document));

        const payerPhoneDigits = normalizePhoneBR(safeStr(payer.phone ?? ""));
        if (!payerPhoneDigits) {
            return json(400, { error: "payer.phone is required (DDD + number) with 10 or 11 digits" });
        }
        const payerPhoneArea = payerPhoneDigits.slice(0, 2);
        const payerPhoneNumber = payerPhoneDigits.slice(2);

        if (!payerName) return json(400, { error: "payer.name is required" });
        if (payerDoc.length !== 11) return json(400, { error: "payer.document must be CPF with 11 digits" });

        if (!payerEmail || !isValidEmail(payerEmail)) {
            return json(400, { error: "payer.email is required and must be valid" });
        }

        const card_token = safeStr(body.card_token ?? "");
        if (payment_method === "card" && !card_token) {
            return json(400, { error: "card_token is required for card payments" });
        }

        let billing_address: BillingAddress | null = null;
        if (body.billing_address) billing_address = body.billing_address;

        if (payment_method === "card") {
            if (!billing_address) return json(400, { error: "billing_address is required for card payments" });
            try {
                billing_address = normalizeBillingAddressForCard(billing_address);
            } catch (e) {
                return json(400, { error: String((e as any)?.message ?? e) });
            }
        } else {
            if (billing_address) billing_address = normalizeBillingAddressForPix(billing_address);
        }

        // env
        const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
        const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
        const serviceKey = Deno.env.get("SERVICE_ROLE_KEY")!;

        const PAGARME_SECRET_KEY = Deno.env.get("PAGARME_SECRET_KEY")!;
        const PLATFORM_RECIPIENT_ID = Deno.env.get("PAGARME_PLATFORM_RECIPIENT_ID")!;
        const PIX_EXPIRES_IN_SECONDS = Number(Deno.env.get("PIX_EXPIRES_IN_SECONDS") ?? "3600");

        if (!PLATFORM_RECIPIENT_ID) {
            return json(500, { error: "Missing PAGARME_PLATFORM_RECIPIENT_ID secret" });
        }

        // user client
        const supabaseUser = createClient(supabaseUrl, anonKey, {
            global: { headers: { Authorization: authHeader } },
        });

        const { data: userData, error: userErr } = await supabaseUser.auth.getUser();
        if (userErr || !userData.user) return json(401, { error: "Invalid user" });
        const userId = userData.user.id;

        // admin client
        const supabaseAdmin = createClient(supabaseUrl, serviceKey);

        // 1) validar job
        const { data: job, error: jobErr } = await supabaseAdmin
            .from("jobs")
            .select("id, client_id, provider_id, payment_status, job_code")
            .eq("id", job_id)
            .maybeSingle();

        if (jobErr || !job) return json(404, { error: "Job not found" });
        if (job.client_id !== userId) return json(403, { error: "Not your job" });
        if (job.payment_status === "paid") return json(409, { error: "Job already paid" });

        // 2) quote
        const { data: quote, error: quoteErr } = await supabaseAdmin
            .from("job_quotes")
            .select("id, job_id, provider_id, approximate_price")
            .eq("id", quote_id)
            .maybeSingle();

        if (quoteErr || !quote) return json(404, { error: "Quote not found" });
        if (quote.job_id !== job_id) return json(400, { error: "Quote does not belong to this job" });

        if (job.provider_id && job.provider_id !== quote.provider_id) {
            return json(409, { error: "Job already assigned to a different provider" });
        }

        const amountTotal = Number(quote.approximate_price);
        if (!Number.isFinite(amountTotal) || amountTotal <= 0) return json(400, { error: "Invalid quote amount" });

        const amountCents = Math.round(amountTotal * 100);
        if (amountCents <= 0) return json(400, { error: "Invalid amount cents" });

        // 3) provider recipient
        const { data: provider, error: provErr } = await supabaseAdmin
            .from("providers")
            .select("id, pagarme_recipient_id, full_name")
            .eq("id", quote.provider_id)
            .maybeSingle();

        if (provErr || !provider) return json(400, { error: "Provider not found" });
        if (!provider.pagarme_recipient_id) {
            return json(400, { error: "Provider missing pagarme_recipient_id (split requires recipient)" });
        }

        // 0) Idempotência por job+quote (paid sempre bloqueia; pending depende)
        const { data: existingPayments, error: exErr } = await supabaseAdmin
            .from("payments")
            .select("id, status, payment_method, gateway_metadata, created_at, gateway_transaction_id")
            .eq("job_id", job_id)
            .eq("quote_id", quote_id)
            .in("status", ["pending", "paid"])
            .order("created_at", { ascending: false })
            .limit(10);

        if (exErr) return json(500, { error: "Failed checking existing payment" });

        if (existingPayments && existingPayments.length > 0) {
            const paidOne = existingPayments.find((p: any) => safeStr(p.status).toLowerCase() === "paid");
            if (paidOne) {
                return json(200, {
                    ok: true,
                    idempotent: true,
                    payment: { id: paidOne.id, status: paidOne.status, created_at: paidOne.created_at },
                    pix: paidOne.gateway_metadata?.pix ?? null,
                    card: paidOne.gateway_metadata?.card ?? null,
                });
            }

            const pendingLatest = existingPayments.find((p: any) => safeStr(p.status).toLowerCase() === "pending") ?? null;

            if (pendingLatest) {
                const pendingMethod = safeStr(pendingLatest.payment_method).toLowerCase() === "card" ? "card" : "pix";
                const gm = pendingLatest.gateway_metadata ?? {};

                if (force_new) {
                    const replacedMeta = {
                        ...(gm ?? {}),
                        replaced: true,
                        replaced_at: new Date().toISOString(),
                        replaced_reason: "user_force_new",
                        replaced_requested_method: payment_method,
                    };

                    await supabaseAdmin
                        .from("payments")
                        .update({
                            status: "failed",
                            gateway_metadata: replacedMeta,
                        })
                        .eq("id", pendingLatest.id);
                } else {
                    if (pendingMethod === payment_method) {
                        if (payment_method === "pix") {
                            const existingPix = gm?.pix ?? null;
                            const hasQr = safeStr(existingPix?.qr_code ?? existingPix?.copy_paste ?? "").length > 0;
                            if (hasQr) {
                                const pix = {
                                    ...existingPix,
                                    copy_paste: existingPix?.copy_paste ?? existingPix?.qr_code ?? null,
                                    qr_code: existingPix?.qr_code ?? existingPix?.copy_paste ?? null,
                                };
                                return json(200, {
                                    ok: true,
                                    idempotent: true,
                                    payment: { id: pendingLatest.id, status: "pending", created_at: pendingLatest.created_at },
                                    pix,
                                });
                            }
                        } else {
                            const orderId = safeStr(gm?.pagarme?.order_id ?? gm?.pagarme_order_id ?? "");
                            const chargeId = safeStr(gm?.pagarme?.charge_id ?? "");
                            if (orderId || chargeId) {
                                return json(200, {
                                    ok: true,
                                    idempotent: true,
                                    payment: { id: pendingLatest.id, status: "pending", created_at: pendingLatest.created_at },
                                    card: gm?.card ?? { status: gm?.card_status ?? "pending" },
                                    pix: null,
                                });
                            }
                        }
                    } else {
                        return json(409, {
                            ok: false,
                            code: "PENDING_EXISTS",
                            message: buildPendingConflictMessage(pendingMethod, payment_method),
                            pending: {
                                id: pendingLatest.id,
                                method: pendingMethod,
                                created_at: pendingLatest.created_at,
                                pix: gm?.pix ?? null,
                                card: gm?.card ?? null,
                            },
                        });
                    }
                }
            }
        }

        // 4) gateway_metadata inicial (não salva card_token)
        const gateway_metadata: any = {
            payer: {
                name: payerName,
                email: payerEmail || null,
                document: payerDoc,
                phone: payerPhoneDigits,
            },
            billing_address: billing_address,
            payment_method,
            card: payment_method === "card" ? { has_token: true } : null,
            created_via: "app_checkout",
            force_new: force_new ? true : false,
        };

        // 5) cria payment pending
        const { data: payment, error: payErr } = await supabaseAdmin
            .from("payments")
            .insert({
                job_id,
                quote_id,
                client_id: userId,
                provider_id: quote.provider_id,
                amount_total: amountTotal,
                status: "pending",
                payment_method: payment_method,
                gateway: "pagarme",
                gateway_metadata,
            })
            .select("id, job_id, quote_id, provider_id, amount_total, amount_platform, amount_provider, status, created_at")
            .single();

        if (payErr || !payment) {
            return json(500, { error: "Failed creating payment", details: payErr?.message ?? "unknown" });
        }

        // 6) Base order body
        const pagarmeBase: any = {
            items: [
                {
                    amount: amountCents,
                    description: `Serviço Renthus ${job.job_code ?? job_id}`,
                    quantity: 1,
                    code: payment.id,
                },
            ],
            customer: {
                name: payerName,
                type: "individual",
                document: payerDoc,
                email: payerEmail,
                phones: {
                    mobile_phone: {
                        country_code: "55",
                        area_code: payerPhoneArea,
                        number: payerPhoneNumber,
                    },
                },
            },
            metadata: {
                renthus_payment_id: payment.id,
                job_id,
                quote_id,
            },
        };

        // 7) PIX
        if (payment_method === "pix") {
            const pagarmeBody: any = {
                ...pagarmeBase,
                payments: [
                    {
                        payment_method: "pix",
                        pix: {
                            expires_in: PIX_EXPIRES_IN_SECONDS,
                            additional_information: [
                                { name: "Pagamento", value: "Renthus Service" },
                                { name: "Job", value: String(job.job_code ?? job_id) },
                            ],
                        },
                        split: [
                            {
                                amount: 85,
                                type: "percentage",
                                recipient_id: provider.pagarme_recipient_id,
                                options: {
                                    charge_processing_fee: true,
                                    charge_remainder_fee: true,
                                    liable: true,
                                },
                            },
                            {
                                amount: 15,
                                type: "percentage",
                                recipient_id: PLATFORM_RECIPIENT_ID,
                                options: {
                                    charge_processing_fee: false,
                                    charge_remainder_fee: false,
                                    liable: false,
                                },
                            },
                        ],
                    },
                ],
            };

            const pagarmeResp = await fetch("https://api.pagar.me/core/v5/orders", {
                method: "POST",
                headers: {
                    Authorization: basicAuth(PAGARME_SECRET_KEY),
                    "Content-Type": "application/json",
                },
                body: JSON.stringify(pagarmeBody),
            });

            const pagarmeJson = await pagarmeResp.json();

            if (!pagarmeResp.ok) {
                await supabaseAdmin
                    .from("payments")
                    .update({
                        status: "failed",
                        gateway_metadata: { ...gateway_metadata, pagarme_error: pagarmeJson },
                    })
                    .eq("id", payment.id);

                const msg = extractGatewayErrorMessage(pagarmeJson) ?? "Pagar.me error creating pix order";
                return json(400, { error: msg, details: pagarmeJson });
            }

            const orderStatus = safeStr(pagarmeJson?.status).toLowerCase();
            const chargeStatus = safeStr(pagarmeJson?.charges?.[0]?.status).toLowerCase();

            if (isFailedStatus(orderStatus) || isFailedStatus(chargeStatus)) {
                const msg = extractGatewayErrorMessage(pagarmeJson) ?? "Pix failed at gateway";

                const updatedMetadata = {
                    ...gateway_metadata,
                    pagarme_raw: pagarmeJson,
                    pagarme_error_message: msg,
                };

                await supabaseAdmin
                    .from("payments")
                    .update({
                        status: "failed",
                        gateway_metadata: updatedMetadata,
                    })
                    .eq("id", payment.id);

                return json(400, { error: msg });
            }

            const extracted = extractPixFromPagarme(pagarmeJson);

            const updatedMetadata = {
                ...gateway_metadata,
                pagarme: {
                    order_id: extracted.order_id,
                    charge_id: extracted.charge_id,
                    transaction_id: extracted.transaction_id,
                },
                pix: extracted.pix,
            };

            await supabaseAdmin
                .from("payments")
                .update({
                    gateway_transaction_id: extracted.order_id,
                    gateway_metadata: updatedMetadata,
                })
                .eq("id", payment.id);

            return json(200, {
                ok: true,
                payment: { ...payment, gateway_transaction_id: extracted.order_id },
                pix: extracted.pix,
            });
        }

        // 8) CARD (Core v5 + exigência do gateway: billing.value)
        const billingValue = amountCents;
        const pagarmeBillingAddress = toPagarmeBillingAddress(billing_address!);
        const gatewayBillingAddress = toGatewayBillingAddress(billing_address!);

        const cardOrderBody: any = {
            ...pagarmeBase,
            payments: [
                {
                    payment_method: "credit_card",

                    // ✅ recomendado para o gateway validar corretamente
                    amount: amountCents,

                    credit_card: {
                        operation_type: "auth_and_capture",
                        card_token: card_token,
                        installments: 1,
                        statement_descriptor: "RENTHUS",

                        // ✅ DESATIVA antifraude no sandbox/testes (evita reprovação "antifraud_response.reproved")
                        antifraud_enabled: false,

                        // ✅ EXIGIDO pelo gateway (erro: billing.value required)
                        billing: {
                            value: billingValue,
                            address: gatewayBillingAddress,
                        },

                        // ✅ mantém billing_address para validações v5
                        card: {
                            billing_address: pagarmeBillingAddress,
                        },
                    },

                    split: [
                        {
                            amount: 85,
                            type: "percentage",
                            recipient_id: provider.pagarme_recipient_id,
                            options: {
                                charge_processing_fee: true,
                                charge_remainder_fee: true,
                                liable: true,
                            },
                        },
                        {
                            amount: 15,
                            type: "percentage",
                            recipient_id: PLATFORM_RECIPIENT_ID,
                            options: {
                                charge_processing_fee: false,
                                charge_remainder_fee: false,
                                liable: false,
                            },
                        },
                    ],
                },
            ],
        };

        const cardResp = await fetch("https://api.pagar.me/core/v5/orders", {
            method: "POST",
            headers: {
                Authorization: basicAuth(PAGARME_SECRET_KEY),
                "Content-Type": "application/json",
            },
            body: JSON.stringify(cardOrderBody),
        });

        const cardJson = await cardResp.json();

        if (!cardResp.ok) {
            await supabaseAdmin
                .from("payments")
                .update({
                    status: "failed",
                    gateway_metadata: { ...gateway_metadata, pagarme_error: cardJson },
                })
                .eq("id", payment.id);

            const msg = extractGatewayErrorMessage(cardJson) ?? "Pagar.me error creating card order";
            return json(400, { error: msg, details: cardJson });
        }

        const extractedCard = extractCardFromPagarme(cardJson);

        const orderStatus = safeStr(cardJson?.status).toLowerCase();
        const chargeStatus = safeStr(cardJson?.charges?.[0]?.status).toLowerCase();

        if (isFailedStatus(orderStatus) || isFailedStatus(chargeStatus)) {
            const msg = extractGatewayErrorMessage(cardJson) ?? "Card failed at gateway";

            const updatedMetadata = {
                ...gateway_metadata,
                pagarme_raw: cardJson,
                pagarme: {
                    order_id: extractedCard.order_id,
                    charge_id: extractedCard.charge_id,
                    transaction_id: extractedCard.transaction_id,
                },
                card: {
                    ...(gateway_metadata.card ?? {}),
                    status: extractedCard.status,
                    brand: extractedCard.card.brand,
                    last4: extractedCard.card.last4,
                },
                pagarme_error_message: msg,
            };

            await supabaseAdmin
                .from("payments")
                .update({
                    status: "failed",
                    gateway_transaction_id: extractedCard.order_id,
                    gateway_metadata: updatedMetadata,
                })
                .eq("id", payment.id);

            return json(400, { error: msg, details: cardJson });
        }

        const shouldBePaid = isPaidStatus(orderStatus) || isPaidStatus(chargeStatus);

        const updatedMetadata = {
            ...gateway_metadata,
            pagarme_raw: cardJson,
            pagarme: {
                order_id: extractedCard.order_id,
                charge_id: extractedCard.charge_id,
                transaction_id: extractedCard.transaction_id,
            },
            card: {
                ...(gateway_metadata.card ?? {}),
                status: extractedCard.status,
                brand: extractedCard.card.brand,
                last4: extractedCard.card.last4,
            },
        };

        await supabaseAdmin
            .from("payments")
            .update({
                status: shouldBePaid ? "paid" : "pending",
                gateway_transaction_id: extractedCard.order_id,
                gateway_metadata: updatedMetadata,
            })
            .eq("id", payment.id);

        if (!job.provider_id) {
            await supabaseAdmin.from("jobs").update({ provider_id: quote.provider_id }).eq("id", job_id);
        }

        if (shouldBePaid) {
            await supabaseAdmin.from("jobs").update({ payment_status: "paid" }).eq("id", job_id);
        }

        return json(200, {
            ok: true,
            payment: {
                ...payment,
                status: shouldBePaid ? "paid" : "pending",
                gateway_transaction_id: extractedCard.order_id,
            },
            pix: null,
            card: {
                order_id: extractedCard.order_id,
                charge_id: extractedCard.charge_id,
                transaction_id: extractedCard.transaction_id,
                status: extractedCard.status,
                brand: extractedCard.card.brand,
                last4: extractedCard.card.last4,
            },
        });
    } catch (e) {
        return json(500, { error: "Unexpected error", details: String(e) });
    }
});
