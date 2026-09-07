"""Generate the missing `Generic` videos for the Hot Jigsaw bucket with LTX-2.5.

Successor of `tools/grok/rescue_hotjigsaw_videos.py`: same gap, same ledger,
same status report — but the video comes from the local ComfyUI (LTX-2.5 I2V,
the engine the jigsaw flow already uses) instead of Grok, so there is no
weekly quota and the run simply continues until nothing is left to rescue.

Because the number is fixed by the bucket (the video must pair back onto the
existing `<n>.jpg`), there is nothing for a human to renumber: the finished
triple `<n>.jpg / <n>.mp4 / <n>.webp` is written straight into the staging
pool (`<pool>/Generic/`), exactly where r2manager's *Save Accept* would have
put it, and the number is added to the rescue ledger. Pushing is still the
user's job.

    python rescue_hotjigsaw_videos_ltx.py                # everything left
    python rescue_hotjigsaw_videos_ltx.py --count 10
    python rescue_hotjigsaw_videos_ltx.py --dry-run      # just print the queue

Paths come from AGB's `server/config/settings.json` (`jigsaw.pool_root`,
`jigsaw.pushed_root`, `comfyui.root`, `comfyui.url`) or the matching env vars
(JIGSAW_POOL_ROOT, JIGSAW_PUSHED_ROOT, COMFYUI_ROOT, COMFYUI_URL) — never from
this file, the repo is public.
"""
import argparse
import json
import os
import random
import re
import shutil
import sys
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
AGB_ROOT = HERE.parent.parent
SETTINGS = AGB_ROOT / "server" / "config" / "settings.json"


def _setting(key: str, env: str, default: str = "") -> str:
    v = os.environ.get(env, "").strip()
    if v:
        return v
    try:
        d = json.loads(SETTINGS.read_text(encoding="utf-8")) or {}
        for part in key.split("."):
            d = (d or {}).get(part)
        if isinstance(d, str) and d.strip():
            return d.strip()
    except Exception:
        pass
    return default


POOL_ROOT = Path(_setting("jigsaw.pool_root", "JIGSAW_POOL_ROOT"))
PUSHED_ROOT = Path(_setting("jigsaw.pushed_root", "JIGSAW_PUSHED_ROOT"))
COMFY_ROOT = Path(_setting("comfyui.root", "COMFYUI_ROOT"))
COMFY_URL = _setting("comfyui.url", "COMFYUI_URL", "http://127.0.0.1:8188").rstrip("/")

PIPELINE_ROOT = POOL_ROOT.parent
INCOMING = PIPELINE_ROOT / "_Incoming"
WORK_DIR = INCOMING / "_ltx_rescue"           # half-finished items live here only
RESCUE_LEDGER = PIPELINE_ROOT / "rescue_ledger.json"
STATUS_FILE = INCOMING / "RESCUE_STATUS.md"
PAIR_SEARCH_ROOTS = (INCOMING, POOL_ROOT, PUSHED_ROOT)

COMFY_IN = COMFY_ROOT / "input"
COMFY_OUT = COMFY_ROOT / "output"
WORKFLOW = COMFY_ROOT / "user" / "default" / "workflows" / "LTX2.5 I2V.json"

MANIFEST_URL = "https://hotjigsaw-scanner.lifecharger.workers.dev/collections"
IMAGE_URL = ("https://pub-dafcf9ea956d4cc794d0af36dc2ff3f7.r2.dev"
             "/collections/Generic/images/{n}.jpg")
COLLECTION_ID = "Generic"

# r2.dev and the Worker /proxy/ route both answer 403 to non-browser agents.
BROWSER_UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
              "(KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36")

# Style-neutral on purpose: the Generic collection mixes photoreal portraits,
# anime art and landscapes, so anything that names a look fights half the
# source material. Written as a live scene rather than a list of don'ts —
# LTX answers cautious "tiny, slow, careful" prompts with a dead frame.
ANIMATION_PROMPT = (
    "The picture comes alive: the camera drifts slowly forward, hair, fabric, "
    "water and foliage sway in a soft breeze, the light shifts gently across "
    "the scene, the subject breathes and makes small natural movements. "
    "Same composition, same colours, same art style throughout, one continuous "
    "shot, no text."
)

# Same clip spec the AGB jigsaw flow sends to LTX (comfy_gen: video_ltx). The
# frame SIZE follows the source: Generic mixes portrait, landscape and square
# stills, and forcing 704x1280 on a landscape one makes LTX centre-crop it
# (task #268 — the "head cut off" beach clips).
DURATION, FPS = 5, 24
PIXEL_BUDGET = 704 * 1280
LONG_SIDE_MAX = 1280
STEP = 32                       # LTX wants both sides in multiples of 32


def video_size_for(image: Path) -> tuple[int, int]:
    """(w, h) keeping the still's aspect within the pixel budget."""
    from PIL import Image
    with Image.open(image) as im:
        w, h = im.size
    scale = (PIXEL_BUDGET / float(w * h)) ** 0.5
    if max(w, h) * scale > LONG_SIDE_MAX:
        scale = LONG_SIDE_MAX / float(max(w, h))
    return (max(STEP, int(round(w * scale / STEP)) * STEP),
            max(STEP, int(round(h * scale / STEP)) * STEP))


JOB_TIMEOUT = 5400          # one clip; LTX takes 4-6 min, leave room for cold loads
POLL_SECONDS = 5

MAX_CONSECUTIVE_FAILURES = 3
IMAGE_DOWNLOAD_TIMEOUT = 120
MIN_IMAGE_BYTES = 10_000


# ----------------------------------------------------------------- discovery
def fetch_missing_numbers() -> list[int]:
    """Numbers in the Generic collection whose videoUrls entry is null."""
    req = urllib.request.Request(MANIFEST_URL, headers={"User-Agent": BROWSER_UA})
    with urllib.request.urlopen(req, timeout=IMAGE_DOWNLOAD_TIMEOUT) as resp:
        manifest = json.loads(resp.read().decode("utf-8"))

    generic = next((c for c in manifest.get("collections", [])
                    if c.get("id", "").lower() == COLLECTION_ID.lower()), None)
    if generic is None:
        raise RuntimeError(f"{COLLECTION_ID} collection missing from the manifest")

    missing = []
    for url, video in zip(generic.get("imageUrls", []), generic.get("videoUrls", [])):
        if video:
            continue
        match = re.search(r"/(\d+)\.[A-Za-z0-9]+$", url)
        if match:
            missing.append(int(match.group(1)))
    return sorted(missing)


def load_ledger() -> set[int]:
    if not RESCUE_LEDGER.exists():
        return set()
    try:
        return set(json.loads(RESCUE_LEDGER.read_text(encoding="utf-8")).get("handled", []))
    except (OSError, ValueError) as e:
        print(f"WARNING: could not read the rescue ledger ({e}) — treating it as empty")
        return set()


def ledger_add(number: int) -> None:
    """Same shape r2manager writes on Save Accept, so both tools agree."""
    handled = load_ledger()
    handled.add(number)
    tmp = RESCUE_LEDGER.with_suffix(".json.tmp")
    tmp.write_text(json.dumps({"handled": sorted(handled),
                               "updated": datetime.now().isoformat(timespec="seconds")},
                              indent=2), encoding="utf-8")
    tmp.replace(RESCUE_LEDGER)


def pairs_on_disk() -> set[int]:
    """Numbers that already have an image+video pair somewhere in the tree."""
    found: set[int] = set()
    for root in PAIR_SEARCH_ROOTS:
        if not root.exists():
            continue
        for image in root.rglob("*.jpg"):
            if not image.stem.isdigit():
                continue
            if any(image.with_suffix(ext).exists() for ext in (".mp4", ".webm", ".mov")):
                found.add(int(image.stem))
    return found


def as_ranges(numbers) -> str:
    """[1,2,3,7] -> '1-3, 7' — the compact form the status report uses."""
    numbers = sorted(numbers)
    if not numbers:
        return "_none_"
    runs: list[tuple[int, int]] = []
    for n in numbers:
        if runs and n == runs[-1][1] + 1:
            runs[-1] = (runs[-1][0], n)
        else:
            runs.append((n, n))
    return ", ".join(str(a) if a == b else f"{a}-{b}" for a, b in runs)


def download_image(number: int, dest: Path) -> bool:
    url = IMAGE_URL.format(n=number)
    req = urllib.request.Request(url, headers={"User-Agent": BROWSER_UA})
    try:
        with urllib.request.urlopen(req, timeout=IMAGE_DOWNLOAD_TIMEOUT) as resp:
            body = resp.read()
    except Exception as e:
        print(f"  download failed: {e}")
        return False
    if len(body) < MIN_IMAGE_BYTES:
        print(f"  download too small ({len(body)} bytes) — skipping")
        return False
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(body)
    print(f"  image {len(body) // 1024} KB -> {dest.name}")
    return True


# ------------------------------------------------------------------ comfyui
def _post(path: str, payload: dict) -> dict:
    req = urllib.request.Request(COMFY_URL + path, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=180).read())


def _get(path: str) -> dict:
    return json.loads(urllib.request.urlopen(COMFY_URL + path, timeout=180).read())


def comfy_up() -> bool:
    try:
        urllib.request.urlopen(COMFY_URL + "/system_stats", timeout=3).read()
        return True
    except Exception:
        return False


def _converter():
    scripts = str(COMFY_ROOT / "scripts")
    if scripts not in sys.path:
        sys.path.insert(0, scripts)
    from wf2api import convert  # noqa: WPS433 — lives beside ComfyUI, not in this repo
    return convert


def animate(image: Path, number: int) -> Path | None:
    """One LTX-2.5 image-to-video job, straight to ComfyUI. Returns the mp4."""
    convert = _converter()
    wf = json.loads(WORKFLOW.read_text(encoding="utf-8"))
    seed = random.randint(1, 2 ** 31)
    width, height = video_size_for(image)
    print(f"  frame {width}x{height} for the {image.stem} still")
    graph = convert(wf, {"prompt": ANIMATION_PROMPT, "width": width, "height": height,
                         "duration": DURATION, "frame_rate": FPS,
                         "prompt_enhance": False, "noise_seed": seed, "seed": seed})

    img_name = f"rescue_{number}{image.suffix}"
    COMFY_IN.mkdir(parents=True, exist_ok=True)
    shutil.copy(image, COMFY_IN / img_name)
    for n in graph.values():
        ct = n["class_type"]
        if ct == "LoadImage":
            n["inputs"]["image"] = img_name
        if ct.startswith("SaveVideo"):
            n["inputs"]["filename_prefix"] = f"rescue_ltx/{number}"

    try:
        pid = _post("/prompt", {"prompt": graph, "client_id": f"rescue-{uuid.uuid4()}"})["prompt_id"]
    except urllib.error.HTTPError as e:
        print(f"  comfy refused the job: {e.read().decode(errors='replace')[:400]}")
        return None

    t0 = time.time()
    while time.time() - t0 < JOB_TIMEOUT:
        time.sleep(POLL_SECONDS)
        try:
            hist = _get(f"/history/{pid}")
        except Exception:
            continue
        if pid not in hist:
            continue
        st = hist[pid].get("status", {})
        if st.get("status_str") == "error":
            msgs = [m for m in st.get("messages", []) if m and m[0] == "execution_error"]
            print(f"  comfy error: {json.dumps(msgs, ensure_ascii=False)[:400]}")
            return None
        for _k, o in hist[pid].get("outputs", {}).items():
            for key in ("videos", "gifs", "images"):
                for f in o.get(key, []) or []:
                    src = COMFY_OUT / f.get("subfolder", "") / f["filename"]
                    if src.is_file() and src.suffix.lower() in (".mp4", ".webm", ".mov"):
                        print(f"  video ready in {time.time() - t0:.0f}s ({src.stat().st_size // 1024} KB)")
                        return src
        print("  job finished without a video file")
        return None
    print("  timed out waiting for ComfyUI")
    return None


def encode_webp(src: Path, dest: Path) -> tuple[bool, str]:
    """The bucket's own WebP encoder (same settings r2manager + AGB use)."""
    tools = str(AGB_ROOT / "tools" / "hotidle_wall_webp")
    if tools not in sys.path:
        sys.path.insert(0, tools)
    from encode_upload import encode_file  # noqa: WPS433
    return encode_file(src, dest)


# ------------------------------------------------------------------- report
def write_status(total_missing: int, rescued, failed, remaining) -> None:
    rescued, failed, remaining = sorted(rescued), sorted(failed), sorted(remaining)
    next_ten = ", ".join(str(n) for n in remaining[:10]) or "_none_"
    STATUS_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATUS_FILE.write_text(f"""# Rescue status

Updated {datetime.now().strftime('%Y-%m-%d %H:%M')}.

Videos being generated for `{COLLECTION_ID}` images that have none in R2.
Source list: `C:\\Projects\\Hot Jigsaw\\docs\\missing_videos.md`
Driver: `Auto Game Builder\\tools\\comfyui\\rescue_hotjigsaw_videos_ltx.py` (LTX-2.5, local)

| | count |
|---|---|
| rescued (triple in the pool or in the ledger) | **{len(rescued)}** |
| failed | **{len(failed)}** |
| still to rescue | **{len(remaining)}** |
| missing in the bucket right now | {total_missing} |

## Rescued

Numbers with an image + video pair on disk, or already in the ledger. Those
not yet pushed still read as missing in the bucket.

{as_ranges(rescued)}

## Failed

{as_ranges(failed)}

## Still to rescue

{len(remaining)} images. Next 10 lowest: {next_ten}

```
{as_ranges(remaining)}
```
""", encoding="utf-8")


# --------------------------------------------------------------------- main
def main() -> int:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass

    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--count", type=int, default=0,
                        help="How many to attempt (default: all that are left)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print the queue and the status report, generate nothing")
    args = parser.parse_args()

    for label, p in (("jigsaw.pool_root", POOL_ROOT), ("comfyui.root", COMFY_ROOT)):
        if not str(p) or not p.exists():
            print(f"{label} is not configured or does not exist: {p!s}")
            return 1
    if not WORKFLOW.exists():
        print(f"workflow missing: {WORKFLOW}")
        return 1

    missing = fetch_missing_numbers()
    handled = load_ledger() | pairs_on_disk()
    queue = [n for n in missing if n not in handled]
    print(f"{len(missing)} missing in the bucket, {len(handled & set(missing))} already "
          f"handled locally, {len(queue)} to rescue")

    failed: list[int] = []
    if args.dry_run:
        head = queue[:args.count] if args.count else queue
        print(f"Queue: {', '.join(str(n) for n in head)}")
        write_status(len(missing), handled & set(missing), failed, queue)
        return 0

    if not comfy_up():
        print(f"ComfyUI is not answering at {COMFY_URL} — start it first.")
        return 1

    targets = queue[:args.count] if args.count else queue
    pool = POOL_ROOT / COLLECTION_ID
    pool.mkdir(parents=True, exist_ok=True)
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    rescued_now: list[int] = []
    consecutive_failures = 0

    for index, number in enumerate(targets, start=1):
        print(f"\n=== [{index}/{len(targets)}] {number} " + "=" * 40, flush=True)
        image = WORK_DIR / f"{number}.jpg"
        video = WORK_DIR / f"{number}.mp4"
        webp = WORK_DIR / f"{number}.webp"

        ok = False
        pooled = pool / f"{number}.jpg"
        if not image.exists() and pooled.exists():
            shutil.copy(pooled, image)          # redo: the still is already local
        if image.exists() or download_image(number, image):
            src = animate(image, number)
            if src:
                shutil.copy(src, video)
                good, err = encode_webp(video, webp)
                if good:
                    ok = True
                else:
                    print(f"  webp failed: {err[:200]}")

        if ok:
            # Triple lands in the pool under its bucket number — the same place
            # and shape Save Accept produces, so r2manager pushes it unchanged.
            for f in (image, video, webp):
                shutil.move(str(f), pool / f.name)      # overwrites a redo's old files
            ledger_add(number)
            rescued_now.append(number)
            consecutive_failures = 0
            print(f"  -> {pool / image.name} (+mp4, +webp)")
        else:
            # Leave no half-bundle behind: a lone still would be mistaken for a
            # finished asset by the next pass.
            for f in (image, video, webp):
                f.unlink(missing_ok=True)
            failed.append(number)
            consecutive_failures += 1

        handled = load_ledger() | pairs_on_disk()
        write_status(len(missing), handled & set(missing), failed,
                     [n for n in missing if n not in handled])
        if consecutive_failures >= MAX_CONSECUTIVE_FAILURES:
            print("Too many consecutive failures — stopping.")
            break

    handled = load_ledger() | pairs_on_disk()
    remaining = [n for n in missing if n not in handled]
    write_status(len(missing), handled & set(missing), failed, remaining)
    print(f"\nRescued {len(rescued_now)}: {as_ranges(rescued_now)}")
    if failed:
        print(f"Failed {len(failed)}: {as_ranges(failed)}")
    print(f"Still to rescue: {len(remaining)}")
    print(f"Status report: {STATUS_FILE}")
    return 0 if not remaining else 2


if __name__ == "__main__":
    sys.exit(main())
