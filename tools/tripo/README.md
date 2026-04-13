# Tripo3D tools

Two parallel code paths for generating 3D assets via Tripo3D — pick based on which subscription tier you want to spend credits from.

## Path A — Official SDK (`tsk_*` API key)

Uses `https://api.tripo3d.ai` via the `tripo3d` Python SDK. Credits come from the Tripo **API** billing pool (separate from the Studio subscription).

| Script | Purpose |
|---|---|
| `tripo_client.py` | Shared helpers — loads the `tsk_*` key, exposes `get_client()`, defaults for character generation (PBR + quad topology + Mixamo rig spec). |
| `tripo_generate.py` | Text-to-3D or image-to-3D generation |
| `tripo_rig.py` | Auto-rig a generated mesh |
| `tripo_animate.py` | Apply animations to a rigged mesh |
| `tripo_pipeline.py` | End-to-end: generate → rig → animate in one call |

Key location:
1. `TRIPO_API_KEY` env var, else
2. Gitignored `server/config/mcp_servers.json` under `tripo._api_key`, else
3. Legacy local `tripo_config.json` (gitignored).

Quick check:
```bash
cd "/c/Projects/Auto Game Builder/tools/tripo"
python tripo_client.py --check-balance
```

## Path B — Studio API (browser-scraped Bearer JWT)

Uses `https://api.tripo3d.ai/v2/studio/*` — the same backend the web UI at `studio.tripo3d.ai` talks to. Credits come from the **Studio** subscription (e.g. Professional: 3000/month). This is usually the preferred path since Studio credits are cheaper per-model than the API tier.

| Script | Purpose |
|---|---|
| `tripo_studio_api.py` | Client for `/v2/studio/*` endpoints — text-to-3D, polling, project fetch, balance. |
| `refresh_studio_token.py` | Attaches to a running CDP Chrome, reloads the Studio tab, sniffs the `Authorization: Bearer eyJ...` header, saves it to `tripo_studio_token.json`. Use this whenever the JWT expires. |
| `tripo_capture.py` | Alternative: full Playwright-driven capture that launches its own Chrome at `~/.tripo-capture-profile`. Dumps all network traffic for reverse-engineering new endpoints. |
| `tripo_capture_cdp.py` | Same but attaches to an already-running CDP Chrome (like `refresh_studio_token.py`, but saves full request/response dumps instead of just the JWT). |

Key location:
1. `TRIPO_STUDIO_TOKEN` env var, else
2. `tripo_studio_token.json` next to the script (gitignored).

When the JWT expires:
```bash
# Launch (or re-use) a CDP Chrome logged into studio.tripo3d.ai
python ../chrome/chrome_cdp_launcher.py --profile tripo --port 9222 \
    --start-url https://studio.tripo3d.ai/

# Refresh the token
python refresh_studio_token.py

# Verify
python tripo_studio_api.py --balance
```

The `tripo` CDP profile persists at `~/.chrome-cdp-profiles/tripo/` so you only log into the site once ever. See `../CHROME_CDP_HOWTO.md` for the full capture how-to.

## Gitignored files in this folder

- `tripo_config.json` — legacy `tsk_*` key fallback
- `tripo_studio_token.json` — active JWT bearer
- `tripo_capture.json`, `tripo_generate_capture.json` — raw network captures from reverse-engineering sessions

Never commit any of these.
