// supabase/functions/disputes-cron/index.ts

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.48.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY =
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// IMPORTANTE: service role, para ignorar RLS nessa função
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

interface DisputeRow {
    id: string;
    job_id: string;
    opened_by_user_id: string | null;
    provider_status: string | null;
}

serve(async (req) => {
    // Só aceita POST (quando chamado pelo cron)
    if (req.method !== "POST") {
        return new Response("Method not allowed", { status: 405 });
    }

    const now = new Date().toISOString();
    console.log("disputes-cron rodando em:", now);

    // 1) Busca disputas que:
    // - estão abertas (status = 'open')
    // - já passaram do prazo (response_deadline_at <= agora)
    // - ainda não tiveram auto_refunded_at preenchido
    // - provider_status ainda é "pending" ou NULL (não respondeu)
    const { data: disputes, error } = await supabase
        .from("disputes")
        .select<"*,provider_status", DisputeRow>(
            "id, job_id, opened_by_user_id, provider_status",
        )
        .eq("status", "open")
        .lte("response_deadline_at", now)
        .is("auto_refunded_at", null)
        .or("provider_status.is.null,provider_status.eq.pending")
        .limit(100);

    if (error) {
        console.error("disputes-cron: erro ao buscar disputas:", error);
        return new Response("error querying disputes", { status: 500 });
    }

    if (!disputes || disputes.length === 0) {
        console.log("disputes-cron: nenhuma disputa para auto-reembolso.");
        return new Response(JSON.stringify({ processed: 0 }), {
            status: 200,
            headers: { "Content-Type": "application/json" },
        });
    }

    console.log(`disputes-cron: ${disputes.length} disputa(s) para processar.`);

    let processed = 0;

    for (const d of disputes) {
        try {
            const disputeId = d.id;
            const jobId = d.job_id;
            const userId = d.opened_by_user_id;

            console.log("Processando disputa:", disputeId, "job:", jobId);

            // 2) Atualiza a disputa para 'refunded' e preenche auto_refunded_at
            const { error: updDisputeErr } = await supabase
                .from("disputes")
                .update({
                    status: "refunded",
                    auto_refunded_at: now,
                })
                .eq("id", disputeId);

            if (updDisputeErr) {
                console.error(
                    "disputes-cron: erro ao atualizar disputes.status/refund:",
                    disputeId,
                    updDisputeErr,
                );
                continue; // pula essa disputa e segue para próxima
            }

            // 3) Atualiza o job para 'refunded'
            const { error: updJobErr } = await supabase
                .from("jobs")
                .update({
                    status: "refunded",
                })
                .eq("id", jobId);

            if (updJobErr) {
                console.error(
                    "disputes-cron: erro ao atualizar jobs.status:",
                    jobId,
                    updJobErr,
                );
                // continua mesmo assim, porque a disputa já foi marcada como refund
            }

            // 4) Notifica o cliente (quem abriu a disputa) – se houver
            if (userId) {
                const { error: notifErr } = await supabase.from("notifications").insert({
                    user_id: userId,
                    title: "Reembolso automático da disputa",
                    body:
                        "Seu problema não foi respondido no prazo. O pedido foi marcado para reembolso conforme as regras da Renthus.",
                    channel: "app",
                    data: {
                        type: "dispute_auto_refund",
                        dispute_id: disputeId,
                        job_id: jobId,
                    },
                });

                if (notifErr) {
                    console.error(
                        "disputes-cron: erro ao inserir notificação:",
                        notifErr,
                    );
                } else {
                    console.log(
                        "disputes-cron: notificação criada para usuário:",
                        userId,
                    );
                }
            }

            processed++;
        } catch (e) {
            console.error("disputes-cron: erro ao processar disputa:", d.id, e);
        }
    }

    console.log(`disputes-cron: processamento concluído. total=${processed}`);

    return new Response(JSON.stringify({ processed }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
    });
});
