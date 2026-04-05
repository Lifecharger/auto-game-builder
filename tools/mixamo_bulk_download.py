"""
Mixamo Bulk Animation Downloader v3 — Fixed model-id, page-by-page

Fetches product detail to get numeric model-id, then exports.
Skips already downloaded files. Resilient to network drops.
"""

import argparse
import json
import os
import time
import sys
import urllib.request
import urllib.error


MIXAMO_API = "https://www.mixamo.com/api/v1"


def api_get(url, headers):
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def api_post(url, data, headers):
    body = json.dumps(data).encode("utf-8")
    h = dict(headers)
    h["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=body, headers=h, method="POST")
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def download_file(url, filepath):
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req, timeout=120) as resp:
        with open(filepath, "wb") as f:
            while True:
                chunk = resp.read(8192)
                if not chunk:
                    break
                f.write(chunk)


def safe_filename(name):
    return "".join(c if c.isalnum() or c in " -_" else "_" for c in name).strip()


def get_product_detail(headers, product_id, character_id):
    """Fetch product detail to get the numeric model-id."""
    url = f"{MIXAMO_API}/products/{product_id}?similar=0&character_id={character_id}"
    return api_get(url, headers)


def request_and_download(headers, character_id, anim, output_dir):
    """Get detail, request export, poll, download."""
    anim_name = anim.get("description", "unknown").strip()
    anim_id = anim.get("id", "")
    anim_type = anim.get("type", "Motion")
    safe_name = safe_filename(anim_name)
    filepath = os.path.join(output_dir, f"{safe_name}.fbx")

    # Skip if already downloaded
    if os.path.exists(filepath) and os.path.getsize(filepath) > 1000:
        return "skip", filepath

    # Get product detail to find numeric model-id
    detail = get_product_detail(headers, anim_id, character_id)

    if anim_type == "MotionPack":
        # For packs, use all motions
        motions = detail.get("details", {}).get("motions", [])
        gms_hash = []
        for m in motions:
            gh = m.get("gms_hash", {})
            gms_hash.append({
                "model-id": gh.get("model-id"),
                "mirror": False,
                "trim": [0, 100],
                "overdrive": 0,
                "params": ",".join(str(p[1]) for p in gh.get("params", [])) or "0",
                "arm-space": 0,
                "inplace": False,
            })
        export_type = "Motion"
    else:
        # Single motion
        gms = detail.get("details", {}).get("gms_hash", {})
        model_id = gms.get("model-id")
        if not model_id:
            return "fail", "no model-id"

        gms_hash = [{
            "model-id": model_id,
            "mirror": False,
            "trim": [0, 100],
            "overdrive": 0,
            "params": ",".join(str(p[1]) for p in gms.get("params", [])) or "0",
            "arm-space": 0,
            "inplace": False,
        }]
        export_type = "Motion"

    # Request export
    export_data = {
        "character_id": character_id,
        "gms_hash": gms_hash,
        "preferences": {
            "format": "fbx7_2019",
            "skin": "false",
            "fps": "30",
            "reducekf": "0",
        },
        "type": export_type,
        "product_name": anim_name,
    }

    result = api_post(f"{MIXAMO_API}/animations/export", export_data, headers)

    # Poll for completion
    for attempt in range(60):  # max ~2 minutes
        time.sleep(2)
        try:
            monitor = api_get(
                f"{MIXAMO_API}/characters/{character_id}/monitor",
                headers
            )
            if monitor.get("status") == "completed":
                download_url = monitor.get("job_result", "")
                if download_url:
                    download_file(download_url, filepath)
                    return "ok", filepath
                return "fail", "no download URL"
            elif monitor.get("status") == "failed":
                return "fail", "export failed"
        except Exception:
            pass

    return "fail", "timeout"


def main():
    parser = argparse.ArgumentParser(description="Mixamo bulk download v3")
    parser.add_argument("--token", required=True)
    parser.add_argument("--character", required=True)
    parser.add_argument("--output", "-o", default="C:/Reusable Assets/Animations/Mixamo")
    parser.add_argument("--delay", type=float, default=2)
    parser.add_argument("--limit-per-page", type=int, default=96)
    parser.add_argument("--start-page", type=int, default=1)
    parser.add_argument("--search", default="")
    parser.add_argument("--skip-packs", action="store_true", help="Skip MotionPacks (download singles only)")

    args = parser.parse_args()
    os.makedirs(args.output, exist_ok=True)

    headers = {
        "Authorization": args.token,
        "X-Api-Key": "mixamo2",
        "Accept": "application/json",
        "User-Agent": "Mozilla/5.0",
    }

    page = args.start_page
    total_downloaded = 0
    total_skipped = 0
    total_failed = 0

    print(f"Starting Mixamo bulk download v3...")
    print(f"Output: {args.output}")
    print(f"Delay: {args.delay}s | Skip packs: {args.skip_packs}")
    print(flush=True)

    while True:
        url = f"{MIXAMO_API}/products?page={page}&limit={args.limit_per_page}&order=&type=Motion&query={args.search}"
        try:
            result = api_get(url, headers)
        except urllib.error.HTTPError as e:
            if e.code == 401:
                print(f"\nToken expired! Restart — skips already downloaded.")
                break
            print(f"\nHTTP {e.code} on page {page}. Retry in 10s...")
            time.sleep(10)
            continue
        except Exception as e:
            print(f"\nNetwork error page {page}: {e}. Retry in 10s...")
            time.sleep(10)
            continue

        animations = result.get("results", [])
        pagination = result.get("pagination", {})
        total = pagination.get("num_results", "?")
        num_pages = pagination.get("num_pages", 1)

        if not animations:
            break

        print(f"\n=== Page {page}/{num_pages} ({total} total) ===", flush=True)

        for i, anim in enumerate(animations):
            anim_name = anim.get("description", "unknown").strip()
            anim_type = anim.get("type", "Motion")
            idx = (page - 1) * args.limit_per_page + i + 1

            if args.skip_packs and anim_type == "MotionPack":
                print(f"[{idx}/{total}] {anim_name} — SKIP (pack)", flush=True)
                total_skipped += 1
                continue

            print(f"[{idx}/{total}] {anim_name}...", end=" ", flush=True)

            try:
                status, info = request_and_download(
                    headers, args.character, anim, args.output
                )
                if status == "skip":
                    print("SKIP (exists)", flush=True)
                    total_skipped += 1
                elif status == "ok":
                    size_kb = os.path.getsize(info) / 1024
                    print(f"OK ({size_kb:.0f} KB)", flush=True)
                    total_downloaded += 1
                else:
                    print(f"FAILED ({info})", flush=True)
                    total_failed += 1
            except urllib.error.HTTPError as e:
                if e.code == 429:
                    print("RATE LIMITED — 30s wait...", flush=True)
                    time.sleep(30)
                elif e.code == 401:
                    print("\nToken expired! Restart — skips downloaded files.")
                    sys.exit(1)
                else:
                    print(f"HTTP {e.code}", flush=True)
                total_failed += 1
            except Exception as e:
                print(f"ERROR: {e}", flush=True)
                total_failed += 1

            time.sleep(args.delay)

        page += 1
        if page > num_pages:
            break

    print(f"\n{'='*50}")
    print(f"DONE! Downloaded: {total_downloaded}, Skipped: {total_skipped}, Failed: {total_failed}")
    print(f"Output: {args.output}")


if __name__ == "__main__":
    main()
