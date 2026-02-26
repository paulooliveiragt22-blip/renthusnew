import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

type Body = {
  provider_id: string;
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return json({ error: "Missing bearer token" }, 401);
    }

    const { provider_id } = (await req.json()) as Body;
    if (!provider_id) {
      return json({ error: "provider_id is required" }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SERVICE_ROLE_KEY")!;
    const pagarmeKey = Deno.env.get("PAGARME_SECRET_KEY");

    if (!pagarmeKey) {
      return json({ error: "PAGARME_SECRET_KEY not configured" }, 500);
    }

    const supabase = createClient(supabaseUrl, serviceKey);

    const { data: provider, error: pErr } = await supabase
      .from("providers")
      .select(
        "id, cpf, bank_code, bank_branch_number, bank_branch_check_digit, " +
          "bank_account_number, bank_account_check_digit, bank_account_type, " +
          "bank_holder_name, pagarme_recipient_id"
      )
      .eq("id", provider_id)
      .single();

    if (pErr || !provider) {
      return json({ error: "Provider not found" }, 404);
    }

    const recipientId = provider.pagarme_recipient_id as string | null;
    if (!recipientId || recipientId.trim() === "") {
      return json(
        { error: "Provider has no Pagar.me recipient yet" },
        400
      );
    }

    const cpfClean = (provider.cpf ?? "").replace(/\D/g, "");
    const bankBody = {
      holder_name:
        provider.bank_holder_name?.trim() || "Titular",
      holder_type: "individual" as const,
      holder_document: cpfClean || "00000000000",
      bank: (provider.bank_code ?? "").toString().padStart(3, "0"),
      branch_number: (provider.bank_branch_number ?? "0001").toString(),
      branch_check_digit:
        (provider.bank_branch_check_digit ?? "").toString(),
      account_number: (provider.bank_account_number ?? "").toString(),
      account_check_digit:
        (provider.bank_account_check_digit ?? "0").toString(),
      type: (provider.bank_account_type === "savings"
        ? "savings"
        : "checking") as "checking" | "savings",
    };

    const basicAuth = btoa(`${pagarmeKey}:`);
    const url = `https://api.pagar.me/core/v5/recipients/${recipientId}/default-bank-account`;

    const pagarmeRes = await fetch(url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Basic ${basicAuth}`,
      },
      body: JSON.stringify(bankBody),
    });

    const pagarmeData = await pagarmeRes.json();

    if (!pagarmeRes.ok) {
      // 403 geralmente indica IP não permitido: Pagar.me → Segurança → Allow List
      return json(
        {
          error: "Pagar.me error",
          details: pagarmeData,
          hint: "Se 403: no dashboard Pagar.me → Segurança → Allow List, adicione os IPs do Supabase Edge.",
        },
        pagarmeRes.status
      );
    }

    return json({
      success: true,
      message: "Default bank account updated",
    });
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});
