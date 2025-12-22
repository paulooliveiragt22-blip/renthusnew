// supabase/functions/create-payment/index.ts
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

type Body = {
    job_id: string;
    quote_id: string;
};

Deno.serve(async (req) => {
    try {
        if (req.method !== "POST") {
            return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405 });
        }

        const authHeader = req.headers.get("Authorization") ?? "";
        if (!authHeader.startsWith("Bearer ")) {
            return new Response(JSON.stringify({ error: "Missing bearer token" }), { status: 401 });
        }

        const { job_id, quote_id } = (await req.json()) as Body;

        if (!job_id || !quote_id) {
            return new Response(JSON.stringify({ error: "job_id and quote_id are required" }), { status: 400 });
        }

        const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
        const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
        const serviceKey = Deno.env.get("SERVICE_ROLE_KEY")!;

        // client "as user" (pra validar auth)
        const supabaseUser = createClient(supabaseUrl, anonKey, {
            global: { headers: { Authorization: authHeader } },
        });

        const { data: userData, error: userErr } = await supabaseUser.auth.getUser();
        if (userErr || !userData.user) {
            return new Response(JSON.stringify({ error: "Invalid user" }), { status: 401 });
        }
        const userId = userData.user.id;

        // client service_role (fonte da verdade, ignora RLS)
        const supabaseAdmin = createClient(supabaseUrl, serviceKey);

        // 1) valida job do cliente e estado do job (ainda não pago)
        const { data: job, error: jobErr } = await supabaseAdmin
            .from("jobs")
            .select("id, client_id, provider_id, status, payment_status")
            .eq("id", job_id)
            .maybeSingle();

        if (jobErr || !job) {
            return new Response(JSON.stringify({ error: "Job not found" }), { status: 404 });
        }
        if (job.client_id !== userId) {
            return new Response(JSON.stringify({ error: "Not your job" }), { status: 403 });
        }
        if (job.provider_id) {
            return new Response(JSON.stringify({ error: "Job already has provider" }), { status: 409 });
        }
        if (job.payment_status === "paid") {
            return new Response(JSON.stringify({ error: "Job already paid" }), { status: 409 });
        }

        // 2) pega quote e valida vínculo
        const { data: quote, error: quoteErr } = await supabaseAdmin
            .from("job_quotes")
            .select("id, job_id, provider_id, approximate_price")
            .eq("id", quote_id)
            .maybeSingle();

        if (quoteErr || !quote) {
            return new Response(JSON.stringify({ error: "Quote not found" }), { status: 404 });
        }
        if (quote.job_id !== job_id) {
            return new Response(JSON.stringify({ error: "Quote does not belong to this job" }), { status: 400 });
        }

        const amountTotal = Number(quote.approximate_price);
        if (!Number.isFinite(amountTotal) || amountTotal <= 0) {
            return new Response(JSON.stringify({ error: "Invalid quote amount" }), { status: 400 });
        }

        // 3) impede duplicidade: se já existe payment ativo pro job, não cria outro
        const { data: existing, error: exErr } = await supabaseAdmin
            .from("payments")
            .select("id, status")
            .eq("job_id", job_id)
            .in("status", ["pending", "paid"])
            .limit(1);

        if (exErr) {
            return new Response(JSON.stringify({ error: "Failed checking existing payment" }), { status: 500 });
        }
        if (existing && existing.length > 0) {
            return new Response(JSON.stringify({ error: "Payment already exists", payment: existing[0] }), { status: 409 });
        }

        // 4) cria payment pending (trigger split 85/15 cuida do resto)
        const { data: payment, error: payErr } = await supabaseAdmin
            .from("payments")
            .insert({
                job_id,
                client_id: userId,          // ✅ ADD AQUI
                provider_id: quote.provider_id,
                amount_total: amountTotal,
                status: "pending",
                payment_method: "mvp_manual",
            })

            .select("id, job_id, provider_id, amount_total, amount_platform, amount_provider, status, created_at")
            .single();

        if (payErr) {
            return new Response(JSON.stringify({ error: "Failed creating payment", details: payErr.message }), { status: 500 });
        }

        return new Response(JSON.stringify({ ok: true, payment }), {
            status: 200,
            headers: { "Content-Type": "application/json" },
        });
    } catch (e) {
        return new Response(JSON.stringify({ error: "Unexpected error", details: String(e) }), {
            status: 500,
            headers: { "Content-Type": "application/json" },
        });
    }
});
