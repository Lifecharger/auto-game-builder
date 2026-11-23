// Lifecharger Cross-Promo Worker
// Supports both Android (Google Play) and Apple iOS (App Store).
const FILES_BASE = "https://promo.lifechargergames.com/";
const MANIFEST_KEY = "cross-promo/manifest.json";
const MUTABLE = "public, max-age=3600, stale-while-revalidate=86400";
const IMMUTABLE = "public, max-age=7776000, immutable";
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type"
};

export default {
  async fetch(request, env, ctx) {
    if (request.method === "OPTIONS") return new Response(null, { headers: CORS });
    if (request.method !== "GET" && request.method !== "HEAD") return json({ error: "Method not allowed" }, 405);
    const url = new URL(request.url);
    if (url.pathname === "/promo" || url.pathname === "/") return handlePromo(request, env, ctx, url);
    if (url.pathname.startsWith("/files/")) return handleFile(request, env, ctx, url);
    return json({ error: "Not found" }, 404);
  }
};

async function handlePromo(request, env, ctx, url) {
  const from = (url.searchParams.get("from") || "").trim();
  const platformParam = (url.searchParams.get("platform") || url.searchParams.get("os") || "").toLowerCase().trim();
  const ua = (request.headers.get("user-agent") || "").toLowerCase();
  
  // Platform detection: explicit param or user-agent fallback
  const isIos = platformParam === "ios" || platformParam === "apple" ||
    (!platformParam && (ua.includes("iphone") || ua.includes("ipad") || ua.includes("cfnetwork") || ua.includes("darwin")));

  const cache = caches.default;
  const cacheKey = new Request(`${url.origin}/promo?from=${encodeURIComponent(from)}&platform=${isIos ? "ios" : "android"}`);
  const cached = await cache.match(cacheKey);
  if (cached) return cached;

  const obj = await env.PROMO.get(MANIFEST_KEY);
  if (!obj) return json({ error: "promo manifest missing" }, 404);
  const manifest = await obj.json();
  const apps = Array.isArray(manifest.apps) ? manifest.apps : [];
  const caller = apps.find((a) => a.id === from);
  const allowMature = !!(caller && caller.mature);
  const referrer = encodeURIComponent(`utm_source=${from || "unknown"}&utm_medium=crosspromo`);

  let visibleApps = apps
    .filter((a) => a.listed !== false)
    .filter((a) => a.id !== from)
    .filter((a) => allowMature || !a.mature);

  if (isIos) {
    // Only show apps that have an Apple App Store presence
    visibleApps = visibleApps.filter((a) => !!(a.appleId || a.appStoreUrl || a.apple_app_id));
  }

  const visible = visibleApps.map((a) => {
    let storeUrl = "";
    if (isIos) {
      if (a.appStoreUrl) {
        storeUrl = a.appStoreUrl;
      } else if (a.appleId) {
        storeUrl = `https://apps.apple.com/app/id${a.appleId}`;
      } else if (a.apple_app_id) {
        storeUrl = `https://apps.apple.com/app/id${a.apple_app_id}`;
      }
    } else {
      storeUrl = a.playUrl || `https://play.google.com/store/apps/details?id=${a.id}&referrer=${referrer}`;
    }

    return {
      id: a.id,
      name: a.name,
      tagline: a.tagline || "",
      kind: a.kind === "tool" ? "tool" : "game",
      icon: FILES_BASE + a.icon,
      feature: FILES_BASE + a.feature,
      iconFallback: `${url.origin}/files/${a.icon}`,
      featureFallback: `${url.origin}/files/${a.feature}`,
      store: storeUrl,
      appleId: a.appleId || a.apple_app_id || null
    };
  });

  const response = json({
    version: manifest.version || 2,
    platform: isIos ? "ios" : "android",
    from,
    games: visible.filter((a) => a.kind === "game"),
    tools: visible.filter((a) => a.kind === "tool")
  }, 200, { "Cache-Control": MUTABLE });

  ctx.waitUntil(cache.put(cacheKey, response.clone()));
  return response;
}

async function handleFile(request, env, ctx, url) {
  const key = decodeURIComponent(url.pathname.slice("/files/".length));
  if (!key) return json({ error: "Missing key" }, 400);
  const cache = caches.default;
  const cacheKey = new Request(url.origin + url.pathname);
  const cached = await cache.match(cacheKey);
  if (cached) return cached;
  const obj = await env.PROMO.get(key);
  if (!obj) return json({ error: "Not found" }, 404);
  const headers = new Headers(CORS);
  obj.writeHttpMetadata(headers);
  headers.set("etag", obj.httpEtag);
  if (!headers.get("content-type")) {
    headers.set("content-type", key.endsWith(".webp") ? "image/webp" : key.endsWith(".json") ? "application/json" : "application/octet-stream");
  }
  headers.set("cache-control", key.endsWith(".json") ? MUTABLE : IMMUTABLE);
  const response = new Response(obj.body, { headers });
  ctx.waitUntil(cache.put(cacheKey, response.clone()));
  return response;
}

function json(body, status = 200, extra = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json", ...extra }
  });
}
