# game-reports

A single **shared** bug-report / suggestion inbox for the whole Lifecharger game
portfolio. One worker, one D1 table, one R2 bucket — every game POSTs to the same
endpoint with its own package name, and the Auto Game Builder (AGB) backend pulls
reports and routes them to the right app by package.

It is a **transient inbox**: AGB pulls each report, downloads its screenshots,
then DELETEs it here (row + R2 objects). AGB is the durable archive; D1/R2 only
hold what has not been collected yet, so storage stays tiny.

## Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/health` | — | health check |
| POST | `/report` | package-gated | a game submits a report (multipart) |
| GET | `/reports?limit=N` | `X-API-Key` | AGB lists pending reports |
| GET | `/reports/:id/shot/:idx` | `X-API-Key` | AGB fetches one screenshot |
| DELETE | `/reports/:id` | `X-API-Key` | AGB erases a report + its shots |

### POST /report (multipart/form-data)

- `package` — must start with `com.lifecharger.` (else 403). New games need no change.
- `category` — `bug` | `suggestion` | `other`
- `message` — user text (<= 4000 chars)
- `app_version`, `platform`, `install_id` — optional metadata
- `shot0`, `shot1`, `shot2` — optional image files (jpg/png/webp), <= 3
- Whole submission capped at **5 MB**.

## Storage

- **D1** `game-reports` (binding `DB`) — `reports` table, schema in `schema.sql`.
- **R2** `game-reports` (binding `BUCKET`) — screenshots at `reports/<id>/<idx>.<ext>`.

## Setup / deploy

```bash
npm install
wrangler d1 execute game-reports --remote --file=schema.sql   # once
wrangler secret put API_KEY                                    # the key AGB presents
wrangler deploy
```

The `API_KEY` secret gates the read/delete endpoints; only AGB holds it. `/report`
is intentionally keyless (mobile clients can't safely hold a secret) and defended
by the package prefix + size/count limits instead.
