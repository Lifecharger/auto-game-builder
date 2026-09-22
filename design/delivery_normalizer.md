# Delivery normalizer — tag everything, serve by rules, block from AGB (#385)

Goal, in the user's words: *every image must be tagged like the gallery-hot ones, served that way,
and blockable from AGB — the old ones too*. Three content buckets of the Hot line are in scope:

| Pool (normalizer) | Pool (Delivery Mod) | Bucket | What it holds |
|---|---|---|---|
| `gallery-hot` | `jigsaw` | `gallery-hot` | puzzle collections, `event_*` included |
| `cards` | `cards` | `cards` | card decks, jokers, dealers |
| `events` | `events` | `events` | the event host Celeste's `L<n>` looks |

Three things make that true: **one tag schema**, **one index the worker reads**, and **two
independent filters** (field rules + a manual block list).

## 1. One tag schema, one tagger

The schema is `tools/r2manager/tagging_schema.py` (`_OLLAMA_TAG_SCHEMA`) — the same 24 fields the
pushed Hot Jigsaw assets have carried since the Asset Generation Pipeline. Nothing else is accepted:
a missing field, a value outside an enum or a score outside 1–5 is a **report line, never a
default** (`asset_normalizer.validate_tags`).

The tagger is the **local Ollama vision model only** (`jigsaw_flow._ollama_cfg`), never a cloud
model. Every GPU job goes through the lane: the normalizer takes **one** `gpu_lane` ticket for a
whole batch (`jigsaw_flow._tag_batch`), keeps the model resident for the batch (`keep_alive: 10m`)
and releases it at the end — 2000 images must not mean 2000 tickets.

Worker-side field names are the short ones (`rating`, `safety`, `voyeur`, `skin`, `adult`, `racy`,
`violence`, `camera`, `view`, `pose`, `framing`, `mood`, `context` in `subject_fields`; `coverage`,
`fit`, `risk`, `flags`, `body`, `clothing`, `style`, `setting`, `focus` in `title_fields`).
`asset_normalizer.fields_from_tags` is the only place that mapping lives.

## 2. Index mechanism per pool — one per pool, on purpose

| Pool | Where the tags live | Where the worker reads them |
|---|---|---|
| `gallery-hot` | **EXIF inside the JPG** (`exif_writer`: XPKeywords / XPSubject / XPTitle), every image is a `.jpg` so EXIF is reliable | KV `IMAGE_METADATA` → `serve_index_<collection>`, **written by the server**, read by the worker |
| `cards` | `metadata` on the card / dealer entry **inside `manifest.json`** | the same `manifest.json` the worker already reads — no second source, and the tags are **stripped from the served catalogue** once filtering is done (510 KB → 81 KB; a player needs the art, not the rating fields) |
| `events` | sidecar **`_meta/host.json`** in the bucket (`{updated, levels: {"<n>": {...}}}`) | the same object; the events worker has no KV binding, so its rules and block live in the bucket too |

Why not EXIF everywhere: the cards and events art is WebP (animated, and for cards a `cols × rows`
sprite sheet), where EXIF is not dependable. There is no `_still_*` key in the `cards` bucket
(checked 2026-09-22), so the tag source for a card or dealer is the **first frame of the sheet**,
cropped to `frameW × frameH`; for a host look it is the first frame of `host/L<n>.webp`.

`serve_index_<collection>` is authoritative and never expires. The worker's own one-hour rebuild
from `metadata_rich_*` now lives under `serve_index_cache_<collection>`, and only that cache key is
dropped by `/sentience/process-metadata` — the normalizer's index is never clobbered.
`/serve-reindex` keeps the authoritative index in step for the names it re-reads.

## 3. Rules apply everywhere now

Before #385 only the `Generic` pool was filtered; finished collections were untouched. Now
`applyServeRules` walks **every** collection that has an index. A collection with **no index yet is
left alone** — a missing index must never hide content. Blocking is the deliberate switch for that.

## 4. Manual block list

KV / bucket key `serve_block`:

```json
{ "updated": 1758500000000,
  "global": { "pictures": ["generic/1.jpg"], "collections": ["ice_queen"],
              "cards": ["gothic_vampire_a"], "decks": ["jokers_vol1"], "hostLevels": ["7"] },
  "apps":   { "com.lifecharger.hotidle": { "...same lists..." } } }
```

* An app's effective block is **`global` ∪ `apps[<package>]`**. Global wins everywhere.
* Ids are trimmed, de-duplicated and **lowercased** by the worker; `updated` is stamped by the
  worker, never by a client.
* It runs **after** the rules and after the event windows, so it can only ever remove.
* `updated` joins the edge-cache key (`_bv`), exactly like the rules' `_rv` — Save is live at once.
* Which lists a pool understands: `jigsaw` → `collections`, `pictures` (`<collection>/<file>`, the
  extension is optional); `cards` → `decks`, `cards` (the card or dealer `id`); `events` →
  `hostLevels` (the number, with or without the `L`).
* A blocked host level falls back to **L1**; if L1 is blocked too the client gets `host: null` and
  shows no host rather than a look nobody approved.

## 5. Endpoints

Server (`X-API-Key`, `server/api/server.py`):

| Method + path | Does |
|---|---|
| `GET /api/delivery/block?pool=` | the worker's block list + which lists this pool understands |
| `PUT /api/delivery/block?pool=` | replace it (body `{global, apps}`) — live at once |
| `GET /api/delivery/catalog?pool=` | the block browser's list: groups, counts, covers, per-item ids |
| `GET /api/normalize/pools` | the three pools with the bucket's image counts |
| `GET /api/normalize/status` | per pool: the running op's progress + the last report |
| `POST /api/normalize/run` | `{pool, dry_run, limit, force}` → `{op}` |
| `POST /api/normalize/cancel?op_id=` | cancel (same op registry as the jigsaw flow) |
| `GET /api/normalize/report?pool=` | the stored report(s) |

Workers (`X-Admin-Key: SERVE_ADMIN_KEY`) — all three now speak the same admin API:

| Worker | new endpoints |
|---|---|
| `gallery-hot` | `GET/PUT /serve-block`, `PUT /serve-index` (`{collection, index}`), `GET /serve-catalog`; `/serve-values` and `/serve-preview` accept `collection=*` and aggregate every indexed collection |
| `hotcardgames-scanner` (admin) + `cards` (serving) | `GET/PUT /serve-block`, `GET /serve-catalog` |
| `events` | `GET/PUT /serve-rules`, `GET/PUT /serve-block`, `GET /serve-values`, `GET /serve-preview`, `GET /serve-catalog` (stored in the bucket as `serve_rules.json` / `serve_block.json`) |

The worker is always the **reader** of the index; the server is the **writer**.

## 6. The normalizer run

`POST /api/normalize/run` starts one op per pool (`jigsaw_flow` op registry → progress in
`/api/queue`, cancel through `/api/queue/cancel` or `/api/normalize/cancel`). Per image:

1. enumerate from the **bucket listing** (the mirror can be stale, the bucket cannot);
2. take the bytes from the local mirror `D:/Reusable Assets/r2buckets/<bucket>/<key>` when the size
   matches, otherwise download and write them into the mirror (it stays byte-identical);
3. read the existing metadata and validate it — conforming means **skip** (resumable, and `force`
   re-tags anyway);
4. otherwise tag with Ollama through the lane, write EXIF (jpg) and upload the file back to the
   **same key** with the immutable cache header: same pixels, new EXIF, so the immutable cache is
   still honest about the bytes that matter;
5. publish the index: `PUT /serve-index` per collection, `manifest.json` for cards (re-read
   immediately before writing and only `metadata` merged, so a concurrent push is not clobbered),
   `_meta/host.json` for events.

The report per pool: `total`, `valid`, `tagged`, `failed`, `skipped`, per-group counts and a
`failures` list with a reason per id, stored in `server/data/normalize_reports.json`.
`dry_run: true` only reports.

## 7. Clients — parity is required

* **Server**: `server/core/asset_normalizer.py`, `server/core/delivery.py` (pool `events`,
  `block` / `save_block` / `put_serve_index` / `catalog`).
* **AGB app**: `app/lib/screens/delivery_screen.dart` — pool switch Jigsaw | Kartlar | Etkinlikler,
  a Normalize card (run / dry-run / live progress / last report) and an "Engelle" browser with
  thumbnails; `app/lib/services/delivery_service.dart` carries `DeliveryBlock`,
  `DeliveryCatalogItem` and `NormalizePool`.
* **Üretim Stüdyosu** (`C:/ComfyUI/scripts/uretim_studyosu.py`, Dağıtım tab): the same three pools,
  the same Normalize row and the same block browser — a thin client, all logic server-side.

Saving rules and saving the block happen together in both clients, so no request ever sees new
rules with an old block.

## 8. Tests

* `server/tests/test_asset_normalizer.py` — schema validation, the EXIF round trip
  (tag → EXIF → conforming index entry), the pipe parser matching the worker byte for byte, block
  list cleaning, pool/list declarations.
* `C:/Projects/Hot Card Games/assets-worker/test/serve_rules.test.js` — blocked deck / card leave
  every manifest, admin auth, de-duplication, preview counters, the block browser's list.
* `app/test/delivery_block_test.dart` — the block model's parse / toggle / round trip, the overview's
  block, the normalize status and the catalogue rows.
