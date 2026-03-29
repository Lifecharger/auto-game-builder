/**
 * Auto Game Builder — Cloudflare Worker Proxy
 *
 * Reads the current tunnel URL from KV and proxies all requests to it.
 * This gives you a permanent URL that always points to your PC's server,
 * even when the tunnel URL changes on restart.
 *
 * KV binding: AGB_KV (stores "tunnel_url" key)
 */

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // Health check for the worker itself
    if (url.pathname === "/worker/health") {
      const tunnelUrl = await env.AGB_KV.get("tunnel_url");
      return Response.json({
        worker: "ok",
        tunnel_url: tunnelUrl || null,
        connected: !!tunnelUrl,
      });
    }

    // Get the current tunnel URL from KV
    const tunnelUrl = await env.AGB_KV.get("tunnel_url");
    if (!tunnelUrl) {
      return Response.json(
        {
          error: "Server offline",
          message: "No tunnel URL found. Make sure your PC server is running.",
        },
        { status: 503 }
      );
    }

    // Proxy the request to the tunnel
    const targetUrl = tunnelUrl + url.pathname + url.search;

    try {
      const proxyRequest = new Request(targetUrl, {
        method: request.method,
        headers: request.headers,
        body: request.method !== "GET" && request.method !== "HEAD"
          ? request.body
          : undefined,
      });

      const response = await fetch(proxyRequest);

      // Return the response with CORS headers for mobile app
      const newHeaders = new Headers(response.headers);
      newHeaders.set("Access-Control-Allow-Origin", "*");
      newHeaders.set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, PATCH, OPTIONS");
      newHeaders.set("Access-Control-Allow-Headers", "Content-Type, Accept, Authorization");

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
