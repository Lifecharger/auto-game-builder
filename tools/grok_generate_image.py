"""
Generate images using Grok (xAI) via WebSocket API with browser cookies.

Usage:
    python "C:/General Tools/grok_generate_image.py" -d "a knight fighting a dragon" -o knight.png
    python "C:/General Tools/grok_generate_image.py" -d "cute pixel art cat" --aspect 1:1 -o cat.png
    python "C:/General Tools/grok_generate_image.py" -d "fantasy landscape" --aspect 16:9 --count 4 -o landscape.png

Aspect ratios: 2:3, 3:2, 16:9, 9:16, 1:1, 4:3, 3:4
"""
import argparse
import json
import os
import sys
import uuid
import time
import threading
import websocket

HISTORY_FILE = r"C:\AppManager\config\grok_download_history.json"
DOWNLOADS_DIR = os.path.join(os.path.expanduser("~"), "Downloads", "grok-generated")


def get_cookies() -> dict:
    with open(HISTORY_FILE, "r") as f:
        return json.load(f).get("cached_cookies", {})


def generate_images(prompt: str, aspect_ratio: str = "2:3", count: int = 2, output: str = None) -> list[str]:
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
                        "properties": {
                            "section_count": 0,
                            "is_kids_mode": False,
                            "enable_nsfw": False,
                            "skip_upsampler": False,
                            "is_initial": False,
                            "aspect_ratio": aspect_ratio,
                        }
                    }
                ]
            }
        }
        ws.send(json.dumps(msg))
        print(f"  Request sent, waiting for images...")

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
    # Wait for done signal, but if images arrived and no done signal, use short timeout
    done_event.wait(timeout=15)
    if not done_event.is_set() and image_map:
        print(f"  No done signal received, but {len(image_map)} image(s) ready. Proceeding...")
    elif not done_event.is_set():
        # No images yet, wait longer
        done_event.wait(timeout=105)
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
    os.makedirs(DOWNLOADS_DIR, exist_ok=True)
    saved = []

    for i, url in enumerate(results):
        if output:
            base, ext = os.path.splitext(output)
            ext = ext or ".png"
            if len(results) > 1:
                filepath = os.path.join(DOWNLOADS_DIR, f"{base}_{i+1}{ext}")
            else:
                filepath = os.path.join(DOWNLOADS_DIR, f"{base}{ext}")
        else:
            filepath = os.path.join(DOWNLOADS_DIR, f"grok_{request_id[:8]}_{i+1}.png")

        try:
            dl_headers = {}
            if "assets.grok.com" in url:
                dl_headers["Cookie"] = cookie_str
            resp = requests.get(url, headers=dl_headers, timeout=60)
            resp.raise_for_status()
            with open(filepath, "wb") as f:
                f.write(resp.content)
            saved.append(filepath)
            print(f"  Saved: {filepath}")
        except Exception as e:
            print(f"  Download failed for image {i+1}: {e}")

    print(f"Done. {len(saved)} image(s) saved to {DOWNLOADS_DIR}")
    return saved


def main():
    parser = argparse.ArgumentParser(description="Generate images with Grok AI")
    parser.add_argument("--description", "-d", required=True, help="Image description/prompt")
    parser.add_argument("--output", "-o", default=None, help="Output filename (saved in grok-generated/)")
    parser.add_argument("--aspect", default="2:3", choices=["2:3", "3:2", "16:9", "9:16", "1:1", "4:3", "3:4"])
    parser.add_argument("--count", type=int, default=2, help="Number of images (default 2)")
    args = parser.parse_args()

    generate_images(args.description, args.aspect, args.count, args.output)


if __name__ == "__main__":
    main()
