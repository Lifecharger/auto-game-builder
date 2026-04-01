/**
 * Auto Game Builder — Cloudflare Worker Proxy
 *
 * Reads the current tunnel URL from KV and proxies all requests to it.
 * This gives you a permanent URL that always points to your PC's server,
 * even when the tunnel URL changes on restart.
 *
 * Security:
 *  - Validates X-API-Key header on every request (stored as worker secret)
 *  - Verifies HMAC signature of tunnel URL to prevent KV poisoning
 *
 * KV binding: AGB_KV (stores "tunnel_url" and "tunnel_sig" keys)
 * Secrets: API_KEY, HMAC_SECRET (set via `wrangler secret put`)
 */

async function verifyHmac(secret, url, signature) {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(url));
  const hex = [...new Uint8Array(sig)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return hex === signature;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // CORS preflight — always allow
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods":
            "GET, POST, PUT, DELETE, PATCH, OPTIONS",
          "Access-Control-Allow-Headers":
            "Content-Type, Accept, Authorization, X-API-Key",
          "Access-Control-Max-Age": "86400",
        },
      });
    }

    // Health check for the worker itself (no auth required)
    if (url.pathname === "/worker/health") {
      const tunnelUrl = await env.AGB_KV.get("tunnel_url");
      return Response.json({
        worker: "ok",
        tunnel_url: tunnelUrl ? "[set]" : null,
        connected: !!tunnelUrl,
      });
    }

    // ── API Key check ──────────────────────────────────────────
    const expectedKey = env.API_KEY || "";
    if (expectedKey) {
      const providedKey = request.headers.get("X-API-Key") || "";
      if (providedKey !== expectedKey) {
        return Response.json(
          { error: "Unauthorized", message: "Invalid or missing API key" },
          { status: 401 }
        );
      }
    }

    // ── Get and verify tunnel URL ──────────────────────────────
    const tunnelUrl = await env.AGB_KV.get("tunnel_url");
    if (!tunnelUrl) {
      return Response.json(
        {
          error: "Server offline",
          message:
            "No tunnel URL found. Make sure your PC server is running.",
        },
        { status: 503 }
      );
    }

    // Verify HMAC signature to prevent KV poisoning
    const hmacSecret = env.HMAC_SECRET || "";
    if (hmacSecret) {
      const tunnelSig = await env.AGB_KV.get("tunnel_sig");
      if (!tunnelSig) {
        return Response.json(
          {
            error: "Security error",
            message: "Tunnel URL signature missing — possible tampering",
          },
          { status: 502 }
        );
      }
      const valid = await verifyHmac(hmacSecret, tunnelUrl, tunnelSig);
      if (!valid) {
        return Response.json(
          {
            error: "Security error",
            message: "Tunnel URL signature invalid — possible tampering",
          },
          { status: 502 }
        );
      }
    }

    // ── Proxy the request to the tunnel ────────────────────────
    const targetUrl = tunnelUrl + url.pathname + url.search;

    try {
      const proxyRequest = new Request(targetUrl, {
        method: request.method,
        headers: request.headers,
        body:
          request.method !== "GET" && request.method !== "HEAD"
            ? request.body
            : undefined,
      });

      const response = await fetch(proxyRequest);

      // Return the response with CORS headers for mobile app
      const newHeaders = new Headers(response.headers);
      newHeaders.set("Access-Control-Allow-Origin", "*");
      newHeaders.set(
        "Access-Control-Allow-Methods",
        "GET, POST, PUT, DELETE, PATCH, OPTIONS"
      );
      newHeaders.set(
        "Access-Control-Allow-Headers",
        "Content-Type, Accept, Authorization, X-API-Key"
      );

      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: newHeaders,
      });
    } catch (err) {
      return Response.json(
        {
          error: "Proxy failed",
          message: `Could not reach server: ${err.message}`,
        },
        { status: 502 }
      );
    }
  },
};
