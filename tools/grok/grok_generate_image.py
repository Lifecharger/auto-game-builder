"""
Generate images using Grok (xAI) via WebSocket API with browser cookies.

Usage:
    python grok_generate_image.py -d "a knight fighting a dragon" -o knight.png
    python grok_generate_image.py -d "cute pixel art cat" --aspect 1:1 -o cat.png
    python grok_generate_image.py -d "fantasy landscape" --aspect 16:9 -o landscape.png
    python grok_generate_image.py -d "elven warrior" --pro -o warrior.png        # NEW: quality mode (Imagine v3 / pro)
    python grok_generate_image.py -d "neon cyberpunk" --model aurora -o cyber.png  # NEW: pick model

Aspect ratios: 2:3, 3:2, 16:9, 9:16, 1:1, 4:3, 3:4
Models: imagine (default), aurora, flux
"""
import argparse
import json
import os
import sys
import uuid
import time
import threading
import websocket

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
HISTORY_FILE = os.path.join(_SCRIPT_DIR, "grok_download_history.json")
# Generated images land in the r2manager Incoming folder so the review UI picks
# them up directly. Kept out of ~/Downloads on purpose — that folder is used for
# other things and must stay free of pipeline clutter.
DOWNLOADS_DIR = os.environ.get("GROK_OUTPUT_DIR") or os.path.join(
    os.path.expanduser("~"), "Desktop", "Asset Generation Pipeline", "_Incoming"
)


def get_cookies() -> dict:
    with open(HISTORY_FILE, "r") as f:
        return json.load(f).get("cached_cookies", {})


def generate_images(
    prompt: str,
    aspect_ratio: str = "2:3",
    count: int = 2,
    output: str = None,
    pro: bool = False,
    model: str = None,
    output_dir: str = None,
) -> list[str]:
    cookies = get_cookies()
    if not cookies.get("sso"):
        print("ERROR: No Grok SSO cookies found. Run grok downloader first or log into grok.com in Chrome.")
        sys.exit(1)

    cookie_str = "; ".join(f"{k}={v}" for k, v in cookies.items())
    request_id = str(uuid.uuid4())

    image_map = {}  # image_id -> url (dedup by ID, keep latest)
    done_event = threading.Event()
    error_msg = [None]

    def on_message(ws, message):
        try:
            data = json.loads(message)
            msg_type = data.get("type", "")

            if msg_type == "image" or "url" in data:
                url = data.get("url", "")
                if url:
                    parts = url.rstrip("/").split("/")
                    img_id = parts[-1].split(".")[0] if parts else url
                    if img_id not in image_map:
                        image_map[img_id] = url
                        print(f"  Image {len(image_map)} received")
                    else:
                        image_map[img_id] = url  # keep latest URL

            elif msg_type == "error":
                error_msg[0] = data.get("err_msg", data.get("message", str(data)))
                print(f"  ERROR: {error_msg[0]}")
                done_event.set()

            elif msg_type == "done" or msg_type == "complete":
                done_event.set()

        except json.JSONDecodeError:
            pass

    def on_error(ws, error):
        # Connection lost after images received is normal (server closes after delivery)
        if image_map:
            done_event.set()
            return
        error_msg[0] = str(error)
        print(f"  WebSocket error: {error}")
        done_event.set()

    def on_close(ws, close_status, close_msg):
        done_event.set()

    def on_open(ws):
        # Payload schema mirrors ImagineImageGenSession from grok.com frontend
        # (chunk ad82299705f18bc6.js). New fields vs the original 2024 protocol:
        #   - image_model_name : "imagine" | "aurora" | "flux"  (server default if omitted)
        #   - enable_pro       : true → "quality" mode (new high-quality model)
        #   - enable_side_by_side, last_prompt : extras shipped by current frontend
        properties = {
            "section_count": 0,
            "is_kids_mode": False,
            "enable_nsfw": True,
            "skip_upsampler": False,
            "enable_side_by_side": False,
            "is_initial": False,
            "aspect_ratio": aspect_ratio,
        }
        if model:
            properties["image_model_name"] = model
        if pro:
            properties["enable_pro"] = True
        msg = {
            "type": "conversation.item.create",
            "timestamp": int(time.time() * 1000),
            "item": {
                "type": "message",
                "content": [
                    {
                        "requestId": request_id,
                        "text": prompt,
                        "type": "input_text",
                        "properties": properties,
                    }
                ]
            }
        }
        ws.send(json.dumps(msg))
        mode_label = "QUALITY (pro)" if pro else "SPEED"
        model_label = model or "default"
        print(f"  Request sent [{mode_label}, model={model_label}], waiting for images...")

    print(f"Generating: {prompt} (aspect: {aspect_ratio})")

    ws = websocket.WebSocketApp(
        "wss://grok.com/ws/imagine/listen",
        header={
            "Origin": "https://grok.com",
            "Cookie": cookie_str,
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
        },
        on_open=on_open,
        on_message=on_message,
        on_error=on_error,
        on_close=on_close,
    )

    ws_thread = threading.Thread(target=ws.run_forever, daemon=True)
    ws_thread.start()
    # Wait for the done signal. Images stream in one by one, so a batch that has
    # only partially arrived must not be cut short — keep waiting while new
    # images keep showing up, and give up once the stream has gone quiet.
    QUIET_SECS = 25
    HARD_LIMIT = 180
    start = time.time()
    seen = 0
    last_new = start
    while not done_event.wait(timeout=1):
        now = time.time()
        if len(image_map) > seen:
            seen = len(image_map)
            last_new = now
        if seen and now - last_new >= QUIET_SECS:
            print(f"  No done signal received, but {seen} image(s) ready and the stream went quiet. Proceeding...")
            break
        if now - start >= HARD_LIMIT:
            print(f"  Timed out after {HARD_LIMIT}s with {seen} image(s).")
            break
    ws.close()

    results = list(image_map.values())

    if error_msg[0] and not results:
        print(f"Generation failed: {error_msg[0]}")
        return []

    if not results:
        print("No images received (timeout or empty response)")
        return []

    print(f"  {len(results)} final image(s) ready, downloading...")

    # Download the images
    import requests
    save_dir = output_dir or DOWNLOADS_DIR
    os.makedirs(save_dir, exist_ok=True)
    saved = []

    for i, url in enumerate(results):
        if output:
            base, ext = os.path.splitext(output)
            ext = ext or ".png"
            if len(results) > 1:
                filepath = os.path.join(save_dir, f"{base}_{i+1}{ext}")
            else:
                filepath = os.path.join(save_dir, f"{base}{ext}")
        else:
            filepath = os.path.join(save_dir, f"grok_{request_id[:8]}_{i+1}.png")

        dl_headers = {}
        if "assets.grok.com" in url:
            dl_headers["Cookie"] = cookie_str
        # The CDN lags behind the websocket notification — a freshly announced
        # image can 404 for a few seconds before it is actually served.
        last_err = None
        for attempt in range(6):
            try:
                resp = requests.get(url, headers=dl_headers, timeout=60)
                resp.raise_for_status()
                with open(filepath, "wb") as f:
                    f.write(resp.content)
                saved.append(filepath)
                print(f"  Saved: {filepath}")
                last_err = None
                break
            except Exception as e:
                last_err = e
                time.sleep(2 * (attempt + 1))
        if last_err is not None:
            print(f"  Download failed for image {i+1}: {last_err}")

    print(f"Done. {len(saved)} image(s) saved to {save_dir}")
    return saved


def main():
    parser = argparse.ArgumentParser(description="Generate images with Grok AI")
    parser.add_argument("--description", "-d", required=True, help="Image description/prompt")
    parser.add_argument("--output", "-o", default=None, help="Output filename (saved in grok-generated/)")
    parser.add_argument("--aspect", default="2:3", choices=["2:3", "3:2", "16:9", "9:16", "1:1", "4:3", "3:4"])
    parser.add_argument("--count", type=int, default=2, help="Number of images (default 2)")
    parser.add_argument("--pro", action="store_true",
                        help="Enable QUALITY mode (new high-quality model, follows prompts much better)")
    parser.add_argument("--model", default=None, choices=["imagine", "aurora", "flux"],
                        help="Force a specific image model (default: server picks)")
    args = parser.parse_args()

    generate_images(args.description, args.aspect, args.count, args.output, pro=args.pro, model=args.model)


if __name__ == "__main__":
    main()
