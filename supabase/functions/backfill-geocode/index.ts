/**
 * backfill-geocode
 *
 * Edge function de uso único para retroativamente geocodificar
 * todos os registros de job_addresses onde lat/lng estão NULL.
 *
 * Invocar via CLI:
 *   supabase functions invoke backfill-geocode --project-ref dqfejuakbtcxhymrxoqs
 */

import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GOOGLE_API_KEY = Deno.env.get("GOOGLE_GEOCODING_KEY");
const NOMINATIM_UA = "RenthusService/1.0 (contact: suporte@renthus.com)";

async function geocodeWithGoogle(query: string): Promise<{ lat: number; lng: number } | null> {
    if (!GOOGLE_API_KEY) return null;
    try {
        const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(query)}&key=${GOOGLE_API_KEY}`;
        const res = await fetch(url);
        const data = await res.json();
        if (data.status !== "OK" || !data.results?.length) return null;
        const loc = data.results[0].geometry.location;
        return { lat: loc.lat, lng: loc.lng };
    } catch {
        return null;
    }
}

async function geocodeWithNominatim(query: string): Promise<{ lat: number; lng: number } | null> {
    try {
        const url = `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(query)}&format=json&limit=1&addressdetails=0`;
        const res = await fetch(url, { headers: { "User-Agent": NOMINATIM_UA } });
        if (!res.ok) return null;
        const data = await res.json();
        if (!Array.isArray(data) || data.length === 0) return null;
        const lat = Number(data[0].lat);
        const lng = Number(data[0].lon);
        if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
        return { lat, lng };
    } catch {
        return null;
    }
}

async function tryGeocode(
    street: string,
    number: string,
    district: string,
    city: string,
    state: string,
    zipcode: string | null,
): Promise<{ lat: number; lng: number } | null> {
    const parts = [street, number, district, city, state];
    if (zipcode) parts.push(zipcode);
    parts.push("Brasil");
    const q1 = parts.filter(Boolean).join(", ");

    // Tentativa 1: endereço completo
    let result = await geocodeWithGoogle(q1) ?? await geocodeWithNominatim(q1);

    // Tentativa 2: bairro + cidade + estado
    if (!result && city && state) {
        const q2 = district
            ? `${district}, ${city}, ${state}, Brasil`
            : `${city}, ${state}, Brasil`;
        result = await geocodeWithGoogle(q2) ?? await geocodeWithNominatim(q2);
    }

    // Tentativa 3: só cidade + estado (sempre funciona para distância aproximada)
    if (!result && city && state) {
        const q3 = `${city}, ${state}, Brasil`;
        result = await geocodeWithGoogle(q3) ?? await geocodeWithNominatim(q3);
    }

    return result;
}

const delay = (ms: number) => new Promise((r) => setTimeout(r, ms));

serve(async () => {
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
        auth: { persistSession: false },
    });

    // Busca todos os registros de job_addresses com lat nulo
    const { data: rows, error } = await supabase
        .from("job_addresses")
        .select("job_id, street, number, district, city, state, zipcode")
        .is("lat", null);

    if (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { "Content-Type": "application/json" },
        });
    }

    const total = rows?.length ?? 0;
    console.log(`Backfill: ${total} registros com lat=NULL encontrados.`);

    const results: { job_id: string; status: string; lat?: number; lng?: number }[] = [];

    for (const row of rows ?? []) {
        // Respeita rate limit do Nominatim (1 req/s)
        await delay(1200);

        const coords = await tryGeocode(
            row.street ?? "",
            row.number ?? "",
            row.district ?? "",
            row.city ?? "",
            row.state ?? "",
            row.zipcode ?? null,
        );

        if (coords) {
            const { error: updateError } = await supabase
                .from("job_addresses")
                .update({ lat: coords.lat, lng: coords.lng })
                .eq("job_id", row.job_id);

            if (!updateError) {
                results.push({ job_id: row.job_id, status: "updated", lat: coords.lat, lng: coords.lng });
                console.log(`✅ job_id=${row.job_id} → lat=${coords.lat}, lng=${coords.lng}`);
            } else {
                results.push({ job_id: row.job_id, status: "update_error" });
                console.error(`❌ job_id=${row.job_id} update error: ${updateError.message}`);
            }
        } else {
            results.push({ job_id: row.job_id, status: "geocode_failed" });
            console.warn(`⚠️ job_id=${row.job_id} geocode falhou (${row.city}/${row.state})`);
        }
    }

    const updated = results.filter((r) => r.status === "updated").length;
    const failed = results.filter((r) => r.status !== "updated").length;

    return new Response(
        JSON.stringify({ total, updated, failed, results }),
        { status: 200, headers: { "Content-Type": "application/json" } },
    );
});
