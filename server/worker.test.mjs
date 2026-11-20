import worker from "./worker.js";
import assert from "node:assert/strict";
const store = new Map();
const env = { AILE: {
  async get(k, t) { const v = store.get(k); return v == null ? null : (t === "json" ? JSON.parse(v) : v); },
  async put(k, v) { store.set(k, v); }, async delete(k) { store.delete(k); } } };
const call = (method, path, body) => worker.fetch(new Request("https://x" + path, { method, body: body && JSON.stringify(body) }), env);
const code = "K7M2QX9P", secret = "0123456789abcdef0123456789abcdef";
let r = await call("GET", "/v1/status/" + code); assert.equal(r.status, 404);
r = await call("POST", "/v1/share", { code, secret, name: "Annem", days: { "2026-11-20": ["sabah", "ogle", "hack"], "x": ["ogle"] } });
assert.equal(r.status, 200);
r = await call("GET", "/v1/status/" + code); assert.equal(r.status, 200);
const s = await r.json(); assert.equal(s.name, "Annem"); assert.deepEqual(s.days, { "2026-11-20": ["sabah", "ogle"] }); assert.ok(!("secretHash" in s));
r = await call("POST", "/v1/share", { code, secret: "ffffffffffffffffffffffffffffffff", name: "Kötü" }); assert.equal(r.status, 403);
r = await call("POST", "/v1/unshare", { code, secret: "yanlis" }); assert.equal(r.status, 403);
r = await call("POST", "/v1/unshare", { code, secret }); assert.equal(r.status, 200);
r = await call("GET", "/v1/status/" + code); assert.equal(r.status, 404);
r = await call("GET", "/v1/status/abc"); assert.equal(r.status, 400);
r = await worker.fetch(new Request("https://x/v1/share", { method: "POST", body: "x".repeat(5000) }), env); assert.equal(r.status, 400);
console.log("worker testleri geçti");
