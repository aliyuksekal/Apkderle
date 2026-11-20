// Namaz Asistanı — "Annem Kıldı Mı?" aile takibi sunucusu (Cloudflare Worker + KV).
// Saklanan: paylaşım kodu, gösterilecek ad, son 7 günün "kıldım" işaretleri,
// gizli anahtarın SHA-256 özeti. Başka kişisel veri yok. Kayıt 90 gün sonra kendiliğinden silinir.

const CODE_RE = /^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$/;
const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;
const PRAYERS = new Set(["sabah", "ogle", "ikindi", "aksam", "yatsi"]);
const TTL = 60 * 60 * 24 * 90;

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "access-control-allow-origin": "*",
    },
  });

async function sha256(s) {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function readBody(req) {
  const text = await req.text();
  if (text.length > 4000) throw new Error("too_large");
  return JSON.parse(text);
}

function cleanDays(days) {
  const out = {};
  if (!days || typeof days !== "object") return out;
  const keys = Object.keys(days).filter((k) => DAY_RE.test(k)).sort().slice(-7);
  for (const k of keys) {
    const v = Array.isArray(days[k]) ? days[k] : [];
    out[k] = [...new Set(v.filter((p) => PRAYERS.has(p)))];
  }
  return out;
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    try {
      if (req.method === "GET" && url.pathname.startsWith("/v1/status/")) {
        const code = url.pathname.slice("/v1/status/".length);
        if (!CODE_RE.test(code)) return json({ error: "bad_code" }, 400);
        const rec = await env.AILE.get(code, "json");
        if (!rec) return json({ error: "not_found" }, 404);
        return json({ name: rec.name, days: rec.days, updatedAt: rec.updatedAt });
      }
      if (req.method === "POST" && url.pathname === "/v1/share") {
        const b = await readBody(req);
        if (!CODE_RE.test(b.code || "") || typeof b.secret !== "string" || b.secret.length < 16)
          return json({ error: "bad_request" }, 400);
        const hash = await sha256(b.secret);
        const old = await env.AILE.get(b.code, "json");
        if (old && old.secretHash !== hash) return json({ error: "forbidden" }, 403);
        const rec = {
          name: String(b.name || "").slice(0, 40),
          days: cleanDays(b.days),
          updatedAt: Date.now(),
          secretHash: hash,
        };
        await env.AILE.put(b.code, JSON.stringify(rec), { expirationTtl: TTL });
        return json({ ok: true });
      }
      if (req.method === "POST" && url.pathname === "/v1/unshare") {
        const b = await readBody(req);
        if (!CODE_RE.test(b.code || "")) return json({ error: "bad_request" }, 400);
        const old = await env.AILE.get(b.code, "json");
        if (!old) return json({ ok: true });
        if (old.secretHash !== (await sha256(String(b.secret || ""))))
          return json({ error: "forbidden" }, 403);
        await env.AILE.delete(b.code);
        return json({ ok: true });
      }
      if (url.pathname === "/") return json({ service: "namaz-aile", ok: true });
      return json({ error: "not_found" }, 404);
    } catch (e) {
      return json({ error: "bad_request" }, 400);
    }
  },
};
