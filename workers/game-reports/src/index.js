/**
 * game-reports — Cloudflare Worker + D1 + R2
 *
 * A single shared bug-report / suggestion inbox for the whole Lifecharger game
 * portfolio. Every game POSTs to /report with its own package name; the Auto
 * Game Builder (AGB) backend pulls reports by polling /reports, downloads any
 * screenshots, then DELETEs each one — so D1 and R2 stay a transient inbox and
 * AGB is the durable archive.
 *
 * Endpoints:
 *   GET    /health                     -> 200 "ok"            (public)
 *   POST   /report                     -> submit a report     (public, package-gated)
 *          multipart/form-data:
 *            package      (com.lifecharger.*)   required
 *            category     (bug|suggestion|other) required
 *            message      (text)                required
 *            app_version, platform, install_id  optional
 *            shot0, shot1, shot2  (image files)  optional, <= 3
 *   GET    /reports?limit=N            -> list pending reports (auth: X-API-Key)
 *   GET    /reports/:id/shot/:idx      -> stream one screenshot(auth: X-API-Key)
 *   DELETE /reports/:id                -> erase row + its shots (auth: X-API-Key)
 *
 * Access model:
 *   - /report is public but only accepts `com.lifecharger.*` packages, caps the
 *     body at 5 MB, and allows at most 3 screenshots. It is write-only; nothing
 *     is read back through it. A new game needs no worker change.
 *   - /reports* (read/delete) require the shared secret in `X-API-Key`, matched
 *     against the API_KEY secret. Only AGB holds that key.
 *
 * Secrets (via `wrangler secret put`, never hardcoded):
 *   - API_KEY : shared secret AGB presents to pull/delete.
 */

const PACKAGE_PREFIX = "com.lifecharger.";
const MAX_BODY_BYTES = 5 * 1024 * 1024; // 5 MB per submission
const MAX_SHOTS = 3;
const MAX_MESSAGE_LEN = 4000;
const MAX_STRING_LEN = 128;
const MAX_META_BYTES = 4096;
const CATEGORIES = new Set(["bug", "suggestion", "other"]);
const SHOT_TYPES = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
};

const json = (status, body) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

const clamp = (v, n) => (typeof v === "string" ? v.slice(0, n) : "");

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const { pathname } = url;

    if (request.method === "GET" && pathname === "/health") {
      return new Response("ok", { status: 200 });
    }

    if (request.method === "POST" && pathname === "/report") {
      try {
        return await handleSubmit(request, env);
      } catch (err) {
        console.error("submit failed", err);
        return json(500, { error: "internal" });
      }
    }

    // --- Authenticated read/delete (AGB only) -------------------------------
    if (pathname === "/reports" || pathname.startsWith("/reports/")) {
      if (!authed(request, env)) return json(401, { error: "unauthorized" });
      try {
        if (request.method === "GET" && pathname === "/reports") {
          return await handleList(url, env);
        }
        const shotMatch = pathname.match(/^\/reports\/([^/]+)\/shot\/(\d+)$/);
        if (request.method === "GET" && shotMatch) {
          return await handleShot(shotMatch[1], Number(shotMatch[2]), env);
        }
        const idMatch = pathname.match(/^\/reports\/([^/]+)$/);
        if (request.method === "DELETE" && idMatch) {
          return await handleDelete(idMatch[1], env);
        }
      } catch (err) {
        console.error("read/delete failed", err);
        return json(500, { error: "internal" });
      }
    }

    return json(404, { error: "not_found" });
  },
};

// ---------------------------------------------------------------------------
// POST /report  (public, package-gated)
// ---------------------------------------------------------------------------

async function handleSubmit(request, env) {
  const length = Number(request.headers.get("content-length") || 0);
  if (length > MAX_BODY_BYTES) return json(413, { error: "too_large" });

  const ctype = (request.headers.get("content-type") || "").toLowerCase();

  // Two intake shapes: multipart/form-data (Flutter's image upload) and
  // application/json (easy for Godot / Unity / anything without a multipart
  // helper — screenshots arrive as base64 in a `shots` array).
  let fields, shots;
  try {
    if (ctype.includes("application/json")) {
      ({ fields, shots } = await readJsonBody(request));
    } else {
      ({ fields, shots } = await readMultipartBody(request));
    }
  } catch (e) {
    return json(400, { error: e === "bad_json" ? "bad_json" : "bad_form" });
  }

  const pkg = fields.package;
  if (!pkg || !pkg.startsWith(PACKAGE_PREFIX)) {
    return json(403, { error: "package_not_allowed" });
  }
  const category = fields.category;
  if (!CATEGORIES.has(category)) return json(400, { error: "bad_category" });
  const message = (fields.message || "").trim();
  if (!message) return json(400, { error: "empty_message" });

  const appVersion = fields.app_version || "unknown";
  const platform = fields.platform || "unknown";
  const installId = fields.install_id || "unknown";
  const metaJson = normalizeMeta(fields.meta);

  const id = crypto.randomUUID();
  const now = Date.now();
  const shotKeys = [];
  for (let i = 0; i < shots.length && i < MAX_SHOTS; i++) {
    const ext = SHOT_TYPES[shots[i].type];
    if (!ext) continue;
    const bytes = shots[i].bytes;
    const len = bytes.byteLength != null ? bytes.byteLength : (bytes.length || 0);
    if (!len) continue;
    const key = `reports/${id}/${i}.${ext}`;
    await env.BUCKET.put(key, bytes, { httpMetadata: { contentType: shots[i].type } });
    shotKeys.push(key);
  }

  await env.DB.prepare(
    "INSERT INTO reports (id, received_at, package, category, message, app_version, platform, install_id, shots, meta) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
  )
    .bind(id, now, pkg, category, message, appVersion, platform, installId, JSON.stringify(shotKeys), metaJson)
    .run();

  return json(200, { ok: true, id, shots: shotKeys.length });
}

async function readMultipartBody(request) {
  let form;
  try {
    form = await request.formData();
  } catch {
    throw "bad_form";
  }
  const fields = {
    package: clamp(form.get("package"), MAX_STRING_LEN),
    category: clamp(form.get("category"), MAX_STRING_LEN),
    message: clamp(form.get("message"), MAX_MESSAGE_LEN),
    app_version: clamp(form.get("app_version"), MAX_STRING_LEN),
    platform: clamp(form.get("platform"), MAX_STRING_LEN),
    install_id: clamp(form.get("install_id"), MAX_STRING_LEN),
    meta: form.get("meta"),
  };
  const shots = [];
  const files = [];
  for (const key of ["shot0", "shot1", "shot2", "shot"]) {
    for (const val of form.getAll(key)) {
      if (val && typeof val === "object" && typeof val.arrayBuffer === "function") {
        files.push(val);
      }
    }
  }
  for (const f of files.slice(0, MAX_SHOTS)) {
    const type = (f.type || "").toLowerCase();
    if (!SHOT_TYPES[type]) continue;
    shots.push({ bytes: await f.arrayBuffer(), type });
  }
  return { fields, shots };
}

async function readJsonBody(request) {
  let body;
  try {
    body = await request.json();
  } catch {
    throw "bad_json";
  }
  if (!body || typeof body !== "object") throw "bad_json";
  const fields = {
    package: clamp(body.package, MAX_STRING_LEN),
    category: clamp(body.category, MAX_STRING_LEN),
    message: clamp(body.message, MAX_MESSAGE_LEN),
    app_version: clamp(body.app_version, MAX_STRING_LEN),
    platform: clamp(body.platform, MAX_STRING_LEN),
    install_id: clamp(body.install_id, MAX_STRING_LEN),
    meta: body.meta,
  };
  const shots = [];
  const arr = Array.isArray(body.shots) ? body.shots.slice(0, MAX_SHOTS) : [];
  for (const s of arr) {
    if (!s || typeof s.data !== "string") continue;
    const type = (s.type || "image/jpeg").toLowerCase();
    if (!SHOT_TYPES[type]) continue;
    try {
      const bytes = base64ToBytes(s.data);
      if (bytes.length) shots.push({ bytes, type });
    } catch {
      /* skip malformed base64 */
    }
  }
  return { fields, shots };
}

/** Normalize a meta value (object or JSON string) to a bounded JSON string. */
function normalizeMeta(v) {
  let obj = null;
  if (v && typeof v === "object" && !Array.isArray(v)) {
    obj = v;
  } else if (typeof v === "string" && v.length && v.length <= MAX_META_BYTES) {
    try {
      const parsed = JSON.parse(v);
      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) obj = parsed;
    } catch {
      /* ignore */
    }
  }
  if (!obj) return "{}";
  let out = JSON.stringify(obj);
  if (out.length > MAX_META_BYTES) out = "{}";
  return out;
}

/** Decode base64 (optionally a data: URL) to a Uint8Array. */
function base64ToBytes(b64) {
  const comma = b64.indexOf(",");
  const raw = b64.startsWith("data:") && comma !== -1 ? b64.slice(comma + 1) : b64;
  const binary = atob(raw);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

// ---------------------------------------------------------------------------
// GET /reports?limit=N  (auth)
// ---------------------------------------------------------------------------

async function handleList(url, env) {
  let limit = Number(url.searchParams.get("limit") || 50);
  if (!Number.isFinite(limit) || limit <= 0) limit = 50;
  if (limit > 200) limit = 200;

  const { results } = await env.DB.prepare(
    "SELECT id, received_at, package, category, message, app_version, platform, install_id, shots, meta FROM reports ORDER BY received_at ASC LIMIT ?"
  )
    .bind(limit)
    .all();

  const reports = (results || []).map((r) => ({
    id: r.id,
    received_at: r.received_at,
    package: r.package,
    category: r.category,
    message: r.message,
    app_version: r.app_version,
    platform: r.platform,
    install_id: r.install_id,
    shot_count: safeShots(r.shots).length,
    meta: safeMeta(r.meta),
  }));

  return json(200, { reports });
}

// ---------------------------------------------------------------------------
// GET /reports/:id/shot/:idx  (auth)
// ---------------------------------------------------------------------------

async function handleShot(id, idx, env) {
  const row = await env.DB.prepare("SELECT shots FROM reports WHERE id = ?")
    .bind(id)
    .first();
  if (!row) return json(404, { error: "not_found" });
  const keys = safeShots(row.shots);
  if (idx < 0 || idx >= keys.length) return json(404, { error: "no_shot" });

  const obj = await env.BUCKET.get(keys[idx]);
  if (!obj) return json(404, { error: "shot_missing" });

  const headers = new Headers();
  obj.writeHttpMetadata(headers);
  headers.set("cache-control", "no-store");
  return new Response(obj.body, { status: 200, headers });
}

// ---------------------------------------------------------------------------
// DELETE /reports/:id  (auth) — erase row + its R2 objects
// ---------------------------------------------------------------------------

async function handleDelete(id, env) {
  const row = await env.DB.prepare("SELECT shots FROM reports WHERE id = ?")
    .bind(id)
    .first();
  if (!row) return json(200, { ok: true, already_gone: true });

  const keys = safeShots(row.shots);
  for (const key of keys) {
    try {
      await env.BUCKET.delete(key);
    } catch (err) {
      console.error("r2 delete failed", key, err);
    }
  }
  await env.DB.prepare("DELETE FROM reports WHERE id = ?").bind(id).run();
  return json(200, { ok: true });
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

function safeShots(v) {
  try {
    const arr = JSON.parse(v || "[]");
    return Array.isArray(arr) ? arr : [];
  } catch {
    return [];
  }
}

function safeMeta(v) {
  try {
    const obj = JSON.parse(v || "{}");
    return obj && typeof obj === "object" && !Array.isArray(obj) ? obj : {};
  } catch {
    return {};
  }
}

function authed(request, env) {
  if (!env.API_KEY) {
    console.error("API_KEY secret not set");
    return false;
  }
  return timingSafeEqual(request.headers.get("X-API-Key") || "", env.API_KEY);
}

function timingSafeEqual(a, b) {
  if (typeof a !== "string" || typeof b !== "string") return false;
  if (a.length !== b.length) return false;
  let mismatch = 0;
  for (let i = 0; i < a.length; i++) mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return mismatch === 0;
}
