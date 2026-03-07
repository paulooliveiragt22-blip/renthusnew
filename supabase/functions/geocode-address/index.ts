import { serve } from "https://deno.land/std@0.192.0/http/server.ts";

const GOOGLE_API_KEY = Deno.env.get("GOOGLE_GEOCODING_KEY");
const NOMINATIM_UA = "RenthusService/1.0 (contact: suporte@renthus.com)";

function normalizeQuery(q: string) {
    const raw = q.trim();
    if (!raw) return raw;
    if (!raw.toLowerCase().includes("brasil")) return `${raw}, Brasil`;
    return raw;
}

async function geocodeWithGoogle(query: string) {
    if (!GOOGLE_API_KEY) return null;

    const url =
        "https://maps.googleapis.com/maps/api/geocode/json" +
        `?address=${encodeURIComponent(query)}` +
        `&key=${GOOGLE_API_KEY}`;

    const res = await fetch(url);
    const data = await res.json();

    if (data.status !== "OK" || !data.results?.length) return null;

    const loc = data.results[0].geometry.location;
    return { lat: loc.lat, lng: loc.lng, provider: "google" as const };
}

async function geocodeWithNominatim(query: string) {
    const url =
        `https://nominatim.openstreetmap.org/search?` +
        `q=${encodeURIComponent(query)}` +
        `&format=json&limit=1&addressdetails=0`;

    const res = await fetch(url, { headers: { "User-Agent": NOMINATIM_UA } });
    if (!res.ok) return null;

    const data = await res.json();
    if (!Array.isArray(data) || data.length === 0) return null;

    const item = data[0];
    const lat = Number(item.lat);
    const lng = Number(item.lon);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;

    return { lat, lng, provider: "nominatim" as const };
}

serve(async (req) => {
    try {
        const body = await req.json().catch(() => ({}));
        const queryRaw = (body?.query ?? "").toString();

        if (!queryRaw.trim()) {
            return new Response(JSON.stringify({ error: "Query não informada" }), {
                status: 400,
                headers: { "Content-Type": "application/json" },
            });
        }

        const query = normalizeQuery(queryRaw);

        // Tentativa 1: query completa
        let result = await geocodeWithGoogle(query);
        if (!result) result = await geocodeWithNominatim(query);

        // Tentativa 2: bairro + cidade + estado
        if (!result && body.city && body.state) {
            const q2 = body.district
                ? `${body.district}, ${body.city}, ${body.state}, Brasil`
                : `${body.city}, ${body.state}, Brasil`;
            result = await geocodeWithGoogle(q2) ?? await geocodeWithNominatim(q2);
        }

        // Tentativa 3: só cidade + estado (sempre funciona para distância aproximada)
        if (!result && body.city && body.state) {
            const q3 = `${body.city}, ${body.state}, Brasil`;
            result = await geocodeWithGoogle(q3) ?? await geocodeWithNominatim(q3);
        }

        // ✅ não encontrado = 200 (não vira FunctionException no Flutter)
        if (!result) {
            return new Response(JSON.stringify({ found: false }), {
                status: 200,
                headers: { "Content-Type": "application/json" },
            });
        }

        return new Response(
            JSON.stringify({
                found: true,
                lat: result.lat,
                lng: result.lng,
                provider: result.provider,
                normalized_query: query,
            }),
            { status: 200, headers: { "Content-Type": "application/json" } },
        );
    } catch (_e) {
        return new Response(
            JSON.stringify({ error: "Erro ao geocodificar endereço" }),
            { status: 500, headers: { "Content-Type": "application/json" } },
        );
    }
});
