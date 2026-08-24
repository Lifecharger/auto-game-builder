/**
 * iap-verifier — Cloudflare Worker
 *
 * Verifies Android in-app-purchase (IAP) receipts against the Google Play
 * Developer API (androidpublisher v3). Shared by several games:
 *   - Ace Pong    (com.lifecharger.acepong)
 *   - Pro Jigsaw  (com.lifecharger.projigsaw)
 *   - Deathpin    (com.lifecharger.deathpin)
 *
 * Endpoints:
 *   GET  /        -> health check (200)
 *   POST /verify  -> verify a purchase token
 *
 * Security:
 *   - Callers must present a shared secret in the `X-API-Key` header,
 *     matched against the `API_KEY` secret. Missing/wrong -> 401.
 *   - `packageName` is restricted to a hard allowlist so this can't be
 *     abused as an open proxy to the Play API.
 *
 * Secrets (set via `wrangler secret put`, never hardcoded):
 *   - PLAY_SERVICE_ACCOUNT_JSON : full service-account JSON key, as a string.
 *   - API_KEY                   : shared secret the client apps send.
 *
 * Nothing about the service account is ever returned to the caller.
 */

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/** Only these package names may be verified. Prevents open-proxy abuse. */
const ALLOWED_PACKAGES = new Set([
  "com.lifecharger.acepong",
  "com.lifecharger.projigsaw",
  "com.lifecharger.deathpin",
]);

/** OAuth2 scope required to read purchase/order data. */
const ANDROIDPUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher";

/** Google token endpoint. */
const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";

/** Base URL for the androidpublisher v3 API. */
const ANDROIDPUBLISHER_BASE =
  "https://androidpublisher.googleapis.com/androidpublisher/v3";

// ---------------------------------------------------------------------------
// In-memory access-token cache
// ---------------------------------------------------------------------------
//
// Workers isolates are reused across requests, so an in-memory cache is a cheap
// way to avoid minting a fresh JWT/OAuth token on every call. The cache lives
// only for the lifetime of the isolate — that's fine; a cold isolate just mints
// a new token. We refresh a little before actual expiry to avoid edge races.

let cachedToken = null; // { accessToken: string, expiresAt: number(ms epoch) }
const TOKEN_EARLY_REFRESH_MS = 60 * 1000; // refresh 60s before expiry

// ---------------------------------------------------------------------------
// Worker entry point
// ---------------------------------------------------------------------------

export default {
  /**
   * @param {Request} request
   * @param {Record<string, string>} env
   */
  async fetch(request, env) {
    const url = new URL(request.url);

    // Health check — cheap, unauthenticated, no secrets touched.
    if (request.method === "GET" && url.pathname === "/") {
      return json({ ok: true, service: "iap-verifier" }, 200);
    }

    if (request.method === "POST" && url.pathname === "/verify") {
      return handleVerify(request, env);
    }

    return json({ error: "not_found" }, 404);
  },
};

// ---------------------------------------------------------------------------
// /verify handler
// ---------------------------------------------------------------------------

/**
 * @param {Request} request
 * @param {Record<string, string>} env
 */
async function handleVerify(request, env) {
  // --- Ensure required secrets are configured (fail closed, don't leak) -----
  if (!env.API_KEY || !env.PLAY_SERVICE_ACCOUNT_JSON) {
    // Log server-side only; never echo secret material to the client.
    console.error("Missing required secret(s): API_KEY / PLAY_SERVICE_ACCOUNT_JSON");
    return json({ error: "server_misconfigured" }, 500);
  }

  // --- Authenticate the caller ---------------------------------------------
  const presentedKey = request.headers.get("X-API-Key") || "";
  if (!timingSafeEqual(presentedKey, env.API_KEY)) {
    return json({ error: "unauthorized" }, 401);
  }

  // --- Parse and validate the body -----------------------------------------
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const { packageName, productId, purchaseToken, type } = body || {};

  if (
    typeof packageName !== "string" ||
    typeof productId !== "string" ||
    typeof purchaseToken !== "string" ||
    !packageName ||
    !productId ||
    !purchaseToken
  ) {
    return json(
      { error: "missing_fields", detail: "packageName, productId, purchaseToken are required" },
      400
    );
  }

  const purchaseType = type === "subscription" ? "subscription" : "product";

  // --- Allowlist enforcement (anti open-proxy) -----------------------------
  if (!ALLOWED_PACKAGES.has(packageName)) {
    return json({ error: "package_not_allowed" }, 403);
  }

  // --- Get a Google access token -------------------------------------------
  let accessToken;
  try {
    accessToken = await getAccessToken(env);
  } catch (err) {
    console.error("Failed to obtain Google access token:", err && err.message);
    return json({ error: "auth_failed" }, 502);
  }

  // --- Build the androidpublisher request ----------------------------------
  const encodedPkg = encodeURIComponent(packageName);
  const encodedProduct = encodeURIComponent(productId);
  const encodedToken = encodeURIComponent(purchaseToken);

  let apiUrl;
  if (purchaseType === "subscription") {
    // purchases.subscriptionsv2.get — the current recommended endpoint.
    // Note: subscriptionsv2 does NOT take a productId in the path; the token
    // alone identifies the subscription purchase.
    apiUrl = `${ANDROIDPUBLISHER_BASE}/applications/${encodedPkg}/purchases/subscriptionsv2/tokens/${encodedToken}`;
  } else {
    // purchases.products.get
    apiUrl = `${ANDROIDPUBLISHER_BASE}/applications/${encodedPkg}/purchases/products/${encodedProduct}/tokens/${encodedToken}`;
  }

  // --- Call Google ----------------------------------------------------------
  let googleResp;
  try {
    googleResp = await fetch(apiUrl, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
  } catch (err) {
    console.error("Google API fetch threw:", err && err.message);
    return json({ error: "upstream_unreachable" }, 502);
  }

  const raw = await safeJson(googleResp);

  if (!googleResp.ok) {
    // Surface a sanitized error. Google's own message is generally safe to
    // relay (it never contains our credentials), but we keep it compact.
    const gMessage =
      (raw && raw.error && (raw.error.message || raw.error.status)) || "google_api_error";
    console.error("Google API non-200:", googleResp.status, gMessage);
    return json(
      {
        valid: false,
        error: "google_api_error",
        status: googleResp.status,
        detail: gMessage,
      },
      // 404 from Google usually means "token/purchase not found" -> treat as a
      // client-visible 200-with-valid:false would hide the distinction, so we
      // pass a 200 wrapper but valid:false; other statuses bubble as 502.
      googleResp.status === 404 || googleResp.status === 410 ? 200 : 502
    );
  }

  // --- Normalize the response ----------------------------------------------
  const normalized =
    purchaseType === "subscription"
      ? normalizeSubscription(raw)
      : normalizeProduct(raw);

  return json(normalized, 200);
}

// ---------------------------------------------------------------------------
// Normalizers — return only fields we deem safe, plus a computed `valid`.
// ---------------------------------------------------------------------------

/**
 * Normalize a products.get response.
 * Docs: purchaseState 0=Purchased, 1=Canceled, 2=Pending
 *       consumptionState 0=Yet to be consumed, 1=Consumed
 *       acknowledgementState 0=Yet to be acknowledged, 1=Acknowledged
 *
 * valid = purchased AND not pending AND not already consumed.
 */
function normalizeProduct(raw) {
  const purchaseState = raw ? raw.purchaseState : undefined;
  const consumptionState = raw ? raw.consumptionState : undefined;
  const acknowledgementState = raw ? raw.acknowledgementState : undefined;

  const purchased = purchaseState === 0;
  const consumed = consumptionState === 1;

  return {
    valid: purchased && !consumed,
    type: "product",
    purchaseState,
    consumptionState,
    acknowledged: acknowledgementState === 1,
    // Extra safe fields useful to the client for reconciliation:
    orderId: raw ? raw.orderId : undefined,
    purchaseTimeMillis: raw ? raw.purchaseTimeMillis : undefined,
    regionCode: raw ? raw.regionCode : undefined,
  };
}

/**
 * Normalize a subscriptionsv2.get response.
 * Docs: subscriptionState is a string enum, e.g.
 *   SUBSCRIPTION_STATE_ACTIVE, SUBSCRIPTION_STATE_IN_GRACE_PERIOD,
 *   SUBSCRIPTION_STATE_CANCELED, SUBSCRIPTION_STATE_EXPIRED,
 *   SUBSCRIPTION_STATE_ON_HOLD, SUBSCRIPTION_STATE_PAUSED,
 *   SUBSCRIPTION_STATE_PENDING.
 * acknowledgementState: ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED / _PENDING.
 *
 * valid = state is ACTIVE or IN_GRACE_PERIOD (entitlement still granted).
 */
function normalizeSubscription(raw) {
  const state = raw ? raw.subscriptionState : undefined;
  const ackState = raw ? raw.acknowledgementState : undefined;

  const entitled =
    state === "SUBSCRIPTION_STATE_ACTIVE" ||
    state === "SUBSCRIPTION_STATE_IN_GRACE_PERIOD";

  return {
    valid: entitled,
    type: "subscription",
    state,
    acknowledged: ackState === "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
    // Safe reconciliation fields (subscriptionsv2 shape):
    latestOrderId: raw ? raw.latestOrderId : undefined,
    startTime: raw ? raw.startTime : undefined,
    // lineItems carries per-item expiry; expose expiry only, not the full blob.
    expiryTime:
      raw && Array.isArray(raw.lineItems) && raw.lineItems.length
        ? raw.lineItems[raw.lineItems.length - 1].expiryTime
        : undefined,
  };
}

// ---------------------------------------------------------------------------
// Google OAuth2 — service-account JWT (RS256) -> access token
// ---------------------------------------------------------------------------

/**
 * Return a valid access token, minting (and caching) a new one if needed.
 * @param {Record<string, string>} env
 * @returns {Promise<string>}
 */
async function getAccessToken(env) {
  const now = Date.now();
  if (cachedToken && cachedToken.expiresAt - TOKEN_EARLY_REFRESH_MS > now) {
    return cachedToken.accessToken;
  }

  const sa = parseServiceAccount(env.PLAY_SERVICE_ACCOUNT_JSON);
  const assertion = await createSignedJwt(sa);

  const resp = await fetch(GOOGLE_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  const data = await safeJson(resp);
  if (!resp.ok || !data || !data.access_token) {
    const detail = data && data.error_description ? data.error_description : resp.status;
    throw new Error(`token_exchange_failed: ${detail}`);
  }

  const expiresInMs = (Number(data.expires_in) || 3600) * 1000;
  cachedToken = {
    accessToken: data.access_token,
    expiresAt: now + expiresInMs,
  };
  return cachedToken.accessToken;
}

/**
 * Parse the service-account JSON secret. Throws a generic error (never echoes
 * the contents) if it's malformed or missing the private key.
 * @param {string} jsonStr
 */
function parseServiceAccount(jsonStr) {
  let sa;
  try {
    sa = JSON.parse(jsonStr);
  } catch {
    throw new Error("service_account_json_malformed");
  }
  if (!sa || !sa.client_email || !sa.private_key) {
    throw new Error("service_account_missing_fields");
  }
  return sa;
}

/**
 * Build and RS256-sign a Google OAuth2 JWT assertion using WebCrypto.
 * @param {{client_email: string, private_key: string}} sa
 * @returns {Promise<string>} the signed JWT (header.payload.signature)
 */
async function createSignedJwt(sa) {
  const nowSec = Math.floor(Date.now() / 1000);

  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: sa.client_email,
    scope: ANDROIDPUBLISHER_SCOPE,
    aud: GOOGLE_TOKEN_URL,
    iat: nowSec,
    exp: nowSec + 3600, // Google caps assertion lifetime at 1h
  };

  const encHeader = base64UrlEncode(new TextEncoder().encode(JSON.stringify(header)));
  const encPayload = base64UrlEncode(new TextEncoder().encode(JSON.stringify(payload)));
  const signingInput = `${encHeader}.${encPayload}`;

  const key = await importPrivateKey(sa.private_key);
  const signature = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5" },
    key,
    new TextEncoder().encode(signingInput)
  );

  const encSignature = base64UrlEncode(new Uint8Array(signature));
  return `${signingInput}.${encSignature}`;
}

/**
 * Import a PEM PKCS#8 private key for RSASSA-PKCS1-v1_5 / SHA-256 signing.
 * @param {string} pem
 * @returns {Promise<CryptoKey>}
 */
async function importPrivateKey(pem) {
  // Service-account keys arrive as PKCS#8 PEM. Strip header/footer/newlines,
  // then base64-decode to DER. Handle escaped "\n" that can appear if the JSON
  // was double-encoded somewhere along the way.
  const normalized = pem.replace(/\\n/g, "\n");
  const pemBody = normalized
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");

  const der = base64ToUint8Array(pemBody);

  return crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
}

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

/** JSON response helper. */
function json(obj, status) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Parse JSON without throwing; returns null on failure. */
async function safeJson(resp) {
  try {
    return await resp.json();
  } catch {
    return null;
  }
}

/** base64url encode a Uint8Array. */
function base64UrlEncode(bytes) {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** Standard base64 (not url-safe) -> Uint8Array. */
function base64ToUint8Array(b64) {
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

/**
 * Constant-time-ish string comparison to avoid trivially leaking key length /
 * prefix via early-exit timing. Not cryptographically perfect on JS strings,
 * but adequate for a shared API key gate.
 */
function timingSafeEqual(a, b) {
  if (typeof a !== "string" || typeof b !== "string") return false;
  if (a.length !== b.length) return false;
  let mismatch = 0;
  for (let i = 0; i < a.length; i++) {
    mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return mismatch === 0;
}
