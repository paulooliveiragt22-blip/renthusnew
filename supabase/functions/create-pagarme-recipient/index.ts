import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

type Body = {
  provider_id: string;
};

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
        `id, user_id, full_name, cpf, mother_name, birthdate,
         monthly_income, professional_occupation, phone,
         address_street, address_number, address_complement,
         address_district, address_city, address_state, address_cep,
         address_reference, bank_code, bank_branch_number,
         bank_branch_check_digit, bank_account_number,
         bank_account_check_digit, bank_account_type, bank_holder_name,
         verification_status`
      )
      .eq("id", provider_id)
      .single();

    if (pErr || !provider) {
      return json({ error: "Provider not found" }, 404);
    }

    if (
      provider.verification_status !== "documents_approved" &&
      provider.verification_status !== "documents_submitted"
    ) {
      return json(
        { error: `Invalid status: ${provider.verification_status}` },
        400
      );
    }

    const { data: authUser } = await supabase.auth.admin.getUserById(
      provider.user_id
    );
    const email = authUser?.user?.email ?? "sem-email@renthus.com.br";

    const cpfClean = (provider.cpf ?? "").replace(/\D/g, "");
    const phoneClean = (provider.phone ?? "").replace(/\D/g, "");
    const ddd = phoneClean.substring(0, 2) || "66";
    const phoneNumber = phoneClean.substring(2) || "999999999";

    const complementary =
      provider.address_complement?.trim() || "SN";
    const referencePoint =
      provider.address_reference?.trim() || "Próximo ao centro";
    const zipCode = (provider.address_cep ?? "").replace(/\D/g, "");

    const recipientBody = {
      code: provider.id,
      register_information: {
        name: provider.full_name || "Prestador",
        email,
        document: cpfClean,
        type: "individual",
        mother_name: provider.mother_name || "Não informado",
        birthdate: provider.birthdate
          ? `${provider.birthdate}T00:00:00`
          : "1990-01-01T00:00:00",
        monthly_income: provider.monthly_income ?? 300000,
        professional_occupation:
          provider.professional_occupation || "Prestador de serviços",
        address: {
          street: provider.address_street || "Rua não informada",
          complementary,
          street_number: provider.address_number || "SN",
          neighborhood: provider.address_district || "Centro",
          city: provider.address_city || "Sorriso",
          state: (provider.address_state || "MT").substring(0, 2).toUpperCase(),
          zip_code: zipCode || "78890000",
          reference_point: referencePoint,
        },
        phone_numbers: [
          {
            ddd,
            number: phoneNumber,
            type: "mobile",
          },
        ],
      },
      default_bank_account: {
        holder_name: provider.bank_holder_name || provider.full_name || "Titular",
        holder_type: "individual",
        holder_document: cpfClean,
        bank: (provider.bank_code || "").padStart(3, "0"),
        branch_number: provider.bank_branch_number || "0001",
        branch_check_digit: provider.bank_branch_check_digit || "",
        account_number: provider.bank_account_number || "",
        account_check_digit: provider.bank_account_check_digit || "0",
        type: provider.bank_account_type || "checking",
      },
      transfer_settings: {
        transfer_enabled: true,
        transfer_interval: "Daily",
        transfer_day: 0,
      },
      automatic_anticipation_settings: {
        enabled: false,
        type: "full",
        volume_percentage: 0,
        delay: null,
      },
    };

    const basicAuth = btoa(`${pagarmeKey}:`);

    const pagarmeRes = await fetch(
      "https://api.pagar.me/core/v5/recipients",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Basic ${basicAuth}`,
        },
        body: JSON.stringify(recipientBody),
      }
    );

    const pagarmeData = await pagarmeRes.json();

    if (!pagarmeRes.ok) {
      await supabase.from("provider_verification_log").insert({
        provider_id,
        old_status: provider.verification_status,
        new_status: provider.verification_status,
        reason: `Pagar.me error: ${JSON.stringify(pagarmeData)}`,
      });
      return json(
        { error: "Pagar.me error", details: pagarmeData },
        pagarmeRes.status
      );
    }

    const recipientId = pagarmeData.id;
    const recipientStatus = pagarmeData.status;

    // O trigger auto_activate_provider detecta pagarme_recipient_status = 'active'
    // + verification_status = 'documents_approved' e seta verification_status = 'active'
    const { error: updateErr } = await supabase
      .from("providers")
      .update({
        pagarme_recipient_id: recipientId,
        pagarme_recipient_status: recipientStatus,
      })
      .eq("id", provider_id);

    if (updateErr) {
      return json({ error: "Failed to update provider", details: updateErr }, 500);
    }

    await supabase.from("provider_verification_log").insert({
      provider_id,
      old_status: provider.verification_status,
      new_status: "active",
      reason: `Recipient criado: ${recipientId}`,
    });

    return json({
      success: true,
      recipient_id: recipientId,
      recipient_status: recipientStatus,
    });
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
