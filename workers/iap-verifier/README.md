# iap-verifier

A small, self-contained Cloudflare Worker that server-side verifies Android
in-app-purchase (IAP) receipts against the **Google Play Developer API**
(`androidpublisher` v3). Shared by several games:

| Game       | Package name                 |
|------------|------------------------------|
| Ace Pong   | `com.lifecharger.acepong`    |
| Pro Jigsaw | `com.lifecharger.projigsaw`  |
| Deathpin   | `com.lifecharger.deathpin`   |

Only those three package names are accepted (hard allowlist in
`src/index.js` → `ALLOWED_PACKAGES`), so the Worker can't be abused as an open
proxy to your Play account.

---

## How it works

1. Client app buys an IAP, gets a `purchaseToken` from Google Play Billing.
2. Client POSTs the token to this Worker's `/verify` (with the shared
   `X-API-Key`).
3. Worker mints a Google OAuth2 access token from your **service account**
   (JWT signed with RS256 via WebCrypto), caches it in memory until ~1 min
   before expiry, and calls the androidpublisher API.
4. Worker returns a normalized `{ valid, ... }` JSON. The client should trust
   **only** this server response, never the raw client-side purchase.

Nothing about the service account is ever returned to the caller. Missing
secrets fail closed (HTTP 500 `server_misconfigured`), never leaking contents.

---

## Owner steps to go live

Run these from this folder (`C:\Projects\iap-verifier`). You need
[wrangler](https://developers.cloudflare.com/workers/wrangler/) logged in to
your Cloudflare account (`wrangler login`).

### 1. Install dev deps (once)

```
npm install
```

### 2. Set the two secrets

```
wrangler secret put PLAY_SERVICE_ACCOUNT_JSON
```

Paste the **entire** Google Play Publish API service-account JSON key when
prompted. Your key file is at:

```
D:/keys/arcade-snake-488801-5ac9863bb0ab.json
```

(Open it, copy the whole JSON, paste at the prompt. It is stored as an
encrypted Cloudflare secret — it never lives in this repo.)

```
wrangler secret put API_KEY
```

Enter a long random shared secret. The client apps must send this exact value
in the `X-API-Key` header. Keep a copy somewhere safe (e.g. your keys vault).

### 3. Grant the service account permission in Play Console

The service account (`...@...gserviceaccount.com`, the `client_email` inside
that JSON key) must be allowed to read order/purchase data, or
`purchases.products.get` / `purchases.subscriptionsv2.get` will return 401/403.

In **Google Play Console**:

1. **Users and permissions** → **Invite new users** (or edit the existing
   service-account user — it may already be listed by its email).
2. Add it (account-level is simplest, or grant per-app for all three games).
3. Under **Account permissions**, enable at minimum:
   - **View app information and download bulk reports (read-only)**
   - **View financial data, orders, and cancellation survey responses**
   (These cover reading purchase state. "Manage orders and subscriptions" is
   only needed if you later refund/acknowledge from the server.)
4. Save. Permission changes can take a little while to propagate.

> Also make sure the **Google Play Android Developer API** is enabled in the
> Google Cloud project that owns the service account
> (console.cloud.google.com → APIs & Services → Library).

### 4. Deploy

```
wrangler deploy
```

Wrangler prints the deployed URL, e.g.:

```
https://iap-verifier.<your-subdomain>.workers.dev
```

That `*.workers.dev` URL is your endpoint base. (If you'd rather use a custom
domain, add a `route`/custom domain in the Cloudflare dashboard or a `routes`
entry in `wrangler.toml`.)

### 5. Smoke test

```
curl https://iap-verifier.<your-subdomain>.workers.dev/
# -> {"ok":true,"service":"iap-verifier"}
```

---

## API contract

### `GET /`

Health check. Returns `200` with `{"ok":true,"service":"iap-verifier"}`.
No auth required.

### `POST /verify`

**Headers**

| Header        | Value                          |
|---------------|--------------------------------|
| `Content-Type`| `application/json`             |
| `X-API-Key`   | the shared `API_KEY` secret    |

**Request body**

```json
{
  "packageName": "com.lifecharger.acepong",
  "productId": "remove_ads",
  "purchaseToken": "abcdef...",
  "type": "product"
}
```

- `type` is `"product"` (default) or `"subscription"`.
- For subscriptions, `productId` is not used in the API path (the token
  identifies the subscription) but you may still send it.

**Successful product response**

```json
{
  "valid": true,
  "type": "product",
  "purchaseState": 0,
  "consumptionState": 0,
  "acknowledged": false,
  "orderId": "GPA.xxxx-xxxx-xxxx-xxxxx",
  "purchaseTimeMillis": "1699999999999",
  "regionCode": "TR"
}
```

`valid` is `true` only when `purchaseState === 0` (Purchased) **and** the item
has not already been consumed (`consumptionState !== 1`).

**Successful subscription response**

```json
{
  "valid": true,
  "type": "subscription",
  "state": "SUBSCRIPTION_STATE_ACTIVE",
  "acknowledged": true,
  "latestOrderId": "GPA.xxxx-xxxx-xxxx-xxxxx",
  "startTime": "2026-08-01T00:00:00Z",
  "expiryTime": "2026-09-01T00:00:00Z"
}
```

`valid` is `true` when `state` is `SUBSCRIPTION_STATE_ACTIVE` or
`SUBSCRIPTION_STATE_IN_GRACE_PERIOD`.

**Error responses**

| HTTP | Body `error`            | Meaning                                             |
|------|-------------------------|-----------------------------------------------------|
| 400  | `invalid_json`          | Body wasn't valid JSON.                             |
| 400  | `missing_fields`        | `packageName`/`productId`/`purchaseToken` missing.  |
| 401  | `unauthorized`          | Missing/wrong `X-API-Key`.                          |
| 403  | `package_not_allowed`   | `packageName` not in the allowlist.                 |
| 500  | `server_misconfigured`  | A required secret isn't set on the Worker.          |
| 502  | `auth_failed`           | Couldn't mint a Google token (bad key / perms).     |
| 502  | `upstream_unreachable`  | Network error reaching Google.                      |
| 502  | `google_api_error`      | Google returned a non-404/410 error.                |
| 200  | `google_api_error` + `valid:false` | Google returned 404/410 (token not found / gone). |

The client should treat **only** `valid: true` as an entitlement.

---

## Example client call

```
curl -X POST https://iap-verifier.<subdomain>.workers.dev/verify \
  -H "Content-Type: application/json" \
  -H "X-API-Key: <the API_KEY you set>" \
  -d '{
    "packageName": "com.lifecharger.acepong",
    "productId": "remove_ads",
    "purchaseToken": "<token from Play Billing>",
    "type": "product"
  }'
```

---

## Files

- `src/index.js` — the Worker (fetch handler, auth gate, JWT signing, verify).
- `wrangler.toml` — Worker config; secrets documented but never stored here.
- `package.json` — wrangler devDependency + `dev`/`deploy` scripts.
- `.gitignore` — ignores `node_modules`, `.dev.vars`, key files, `.wrangler`.

## Notes / decisions

- **Subscription endpoint:** uses `purchases.subscriptionsv2.get` (the current
  recommended API) rather than the deprecated classic `subscriptions.get`.
- **Token caching** is per-isolate in memory, refreshed ~60s before expiry. A
  cold isolate simply mints a fresh token; no external cache needed.
- **Local dev:** you can put secrets in a `.dev.vars` file (gitignored) as
  `API_KEY=...` and `PLAY_SERVICE_ACCOUNT_JSON='{...}'` for `wrangler dev`.
