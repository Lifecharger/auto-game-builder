"""Generate the missing `Generic` videos for the Hot Jigsaw bucket.

Every image in the bucket is supposed to have a `videos/<n>.mp4` twin so the
app has something to play behind the puzzle. A few hundred never got one. This
driver walks that gap lowest-number-first: it pulls the still out of R2, runs
Grok image-to-video over it, and leaves the image+video pair in the r2manager
`_Incoming` folder for a human to Save Accept (which keeps the filename, so the
video pairs back onto the same number).

It stops as soon as Grok says the account is out of generations — the weekly
quota is the natural end of a run, not an error.

    python rescue_hotjigsaw_videos.py                # next 30
    python rescue_hotjigsaw_videos.py --count 10
    python rescue_hotjigsaw_videos.py --dry-run      # just print the queue

What counts as "already handled":
  * the r2manager rescue ledger (authoritative — the bucket manifest is
    edge-cached, so a video pushed minutes ago can still read as missing), and
  * an <n>.jpg with an <n>.mp4 beside it anywhere in the pipeline tree.
"""
import argparse
import json
import re
import sys
import time
import urllib.request
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from grok_animate import GrokLimitReached, animate  # noqa: E402

PIPELINE_ROOT = Path.home() / "Desktop" / "Asset Generation Pipeline"
INCOMING = PIPELINE_ROOT / "_Incoming"
RESCUE_LEDGER = PIPELINE_ROOT / "rescue_ledger.json"
STATUS_FILE = INCOMING / "RESCUE_STATUS.md"
# Where a rescued pair can legitimately sit: Save Accept moves it out of
# _Incoming into staging, and pushing moves it on again.
PAIR_SEARCH_ROOTS = (
    INCOMING,
    PIPELINE_ROOT / "Hot Jigsaw",
    PIPELINE_ROOT / "Hot Jigsaw - Pushed",
)

MANIFEST_URL = "https://hotjigsaw-scanner.lifecharger.workers.dev/collections"
IMAGE_URL = ("https://pub-dafcf9ea956d4cc794d0af36dc2ff3f7.r2.dev"
             "/collections/Generic/images/{n}.jpg")
COLLECTION_ID = "Generic"

# r2.dev and the Worker /proxy/ route both answer 403 to non-browser agents.
BROWSER_UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
              "(KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36")

# Style-neutral on purpose: the Generic collection mixes photoreal portraits,
# anime art and landscapes, so anything that names a look ("cinematic film
# grain", "anime shading") fights half the source material. This asks only for
# motion that any still can carry.
ANIMATION_PROMPT = (
    "Bring this picture gently to life: slow subtle camera drift, soft natural "
    "movement in hair, fabric, water and foliage, calm ambient light shift. "
    "Keep the original composition, colours and art style exactly as they are. "
    "No cuts, no new subjects, no text."
)

DEFAULT_COUNT = 30
# A dead browser session fails identically every time and there is no quota
# message to catch it by, so bail out instead of grinding through the queue.
# Keep this tight: a silent stall means a real problem worth looking at, and at
# 240s per doomed attempt a loose guard just burns an hour proving it.
MAX_CONSECUTIVE_FAILURES = 3
IMAGE_DOWNLOAD_TIMEOUT = 120
MIN_IMAGE_BYTES = 10_000


def fetch_missing_numbers() -> list[int]:
    """Numbers in the Generic collection whose videoUrls entry is null."""
    req = urllib.request.Request(MANIFEST_URL, headers={"User-Agent": BROWSER_UA})
    with urllib.request.urlopen(req, timeout=IMAGE_DOWNLOAD_TIMEOUT) as resp:
        manifest = json.loads(resp.read().decode("utf-8"))

    collections = manifest.get("collections", [])
    generic = next((c for c in collections
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


def as_ranges(numbers: list[int]) -> str:
    """[1,2,3,7] -> '1-3, 7' — the compact form the status report uses."""
    if not numbers:
        return "_none_"
    runs: list[tuple[int, int]] = []
    for n in sorted(numbers):
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


def write_status(total_missing: int, rescued: list[int], refused: list[int],
                 failed: list[int], remaining: list[int]) -> None:
    next_ten = ", ".join(str(n) for n in remaining[:10]) or "_none_"
    STATUS_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATUS_FILE.write_text(f"""# Rescue status

Updated {datetime.now().strftime('%Y-%m-%d %H:%M')}.

Videos being generated for `{COLLECTION_ID}` images that have none in R2.
Source list: `C:\\Projects\\Hot Jigsaw\\docs\\missing_videos.md`
Driver: `Auto Game Builder\\tools\\grok\\rescue_hotjigsaw_videos.py`

| | count |
|---|---|
| rescued (pair on disk or in the ledger) | **{len(rescued)}** |
| refused by Grok | **{len(refused)}** |
| failed | **{len(failed)}** |
| still to rescue | **{len(remaining)}** |
| missing in the bucket right now | {total_missing} |

## Rescued

Numbers with an image + video pair on disk, or already Save Accepted. Those
not yet pushed still read as missing in the bucket.

{as_ranges(rescued)}

## Refused by Grok

{as_ranges(refused)}

## Failed

{as_ranges(failed)}

## Still to rescue

{len(remaining)} images. Next 10 lowest: {next_ten}

```
{as_ranges(remaining)}
```
""", encoding="utf-8")


def main() -> int:
    # Progress goes through Grok's own error text, which carries characters the
    # Windows console codepage cannot encode. A print that raises inside the
    # generation loop is charged as a failed item and throws away a video that
    # was already rendered — i.e. it silently burns quota. Never let output
    # encoding decide whether a generation survives.
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass

    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--count", type=int, default=DEFAULT_COUNT,
                        help=f"How many to attempt (default {DEFAULT_COUNT})")
    parser.add_argument("--length", type=int, default=6, choices=[6, 10],
                        help="Video length in seconds (default 6 = cheapest)")
    parser.add_argument("--resolution", default="480p", choices=["480p", "720p"])
    parser.add_argument("--show-browser", action="store_true")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print the queue and the status report, generate nothing")
    args = parser.parse_args()

    missing = fetch_missing_numbers()
    handled = load_ledger() | pairs_on_disk()
    queue = [n for n in missing if n not in handled]

    print(f"{len(missing)} missing in the bucket, {len(handled & set(missing))} already "
          f"handled locally, {len(queue)} to rescue")

    rescued_now: list[int] = []
    refused: list[int] = []
    failed: list[int] = []

    if args.dry_run:
        print(f"Next {min(args.count, len(queue))}: "
              f"{', '.join(str(n) for n in queue[:args.count])}")
        write_status(len(missing), sorted(handled & set(missing)), refused, failed, queue)
        return 0

    targets = queue[:args.count]
    limit_reached = False
    consecutive_failures = 0

    for index, number in enumerate(targets, start=1):
        print(f"\n=== [{index}/{len(targets)}] {number} " + "=" * 40)
        image = INCOMING / f"{number}.jpg"
        video = INCOMING / f"{number}.mp4"

        if not image.exists() and not download_image(number, image):
            failed.append(number)
            consecutive_failures += 1
            if consecutive_failures >= MAX_CONSECUTIVE_FAILURES:
                print("Too many consecutive failures — stopping.")
                break
            continue

        try:
            saved = animate(str(image), ANIMATION_PROMPT,
                            video_length=args.length, resolution=args.resolution,
                            headless=not args.show_browser, output_path=str(video))
        except GrokLimitReached as e:
            print(f"\nWeekly quota reached ({e}) — stopping after "
                  f"{len(rescued_now)} rescued.")
            image.unlink(missing_ok=True)
            limit_reached = True
            break
        except Exception as e:
            print(f"  generation error: {e}")
            saved = None

        if saved:
            rescued_now.append(number)
            consecutive_failures = 0
        else:
            # Leave no half-bundle behind: a lone still in _Incoming looks like
            # a normal pending image to r2manager and would be accepted without
            # the video it was downloaded for.
            image.unlink(missing_ok=True)
            failed.append(number)
            consecutive_failures += 1

        handled = load_ledger() | pairs_on_disk()
        write_status(len(missing), sorted(handled & set(missing)), refused, failed,
                     [n for n in missing if n not in handled])

        if consecutive_failures >= MAX_CONSECUTIVE_FAILURES:
            print("Too many consecutive failures — stopping.")
            break
        time.sleep(2)

    handled = load_ledger() | pairs_on_disk()
    remaining = [n for n in missing if n not in handled]
    write_status(len(missing), sorted(handled & set(missing)), refused, failed, remaining)

    print(f"\nRescued {len(rescued_now)}: {as_ranges(rescued_now)}")
    if failed:
        print(f"Failed {len(failed)}: {as_ranges(failed)}")
    print(f"Still to rescue: {len(remaining)}")
    print(f"Status report: {STATUS_FILE}")
    return 2 if limit_reached else 0


if __name__ == "__main__":
    sys.exit(main())
