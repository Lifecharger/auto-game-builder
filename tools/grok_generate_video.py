"""
Generate videos using Grok (xAI) via chat API with browser cookies.

Usage:
    python "C:/General Tools/grok_generate_video.py" -d "a cat riding a bicycle through a park"
    python "C:/General Tools/grok_generate_video.py" -d "ocean waves at sunset" --aspect 16:9 --length 10
    python "C:/General Tools/grok_generate_video.py" -d "knight fighting dragon" --resolution 720p -o fight.mp4

Aspect ratios: 2:3, 3:2, 16:9, 9:16, 1:1
Resolutions: 480p, 720p
Lengths: 6, 10 seconds
"""
import argparse
import json
import os
import sys
import uuid
import time
import requests

HISTORY_FILE = r"C:\AppManager\config\grok_download_history.json"
DOWNLOADS_DIR = os.path.join(os.path.expanduser("~"), "Downloads", "grok-generated")
CHAT_URL = "https://grok.com/rest/app-chat/conversations/new"
MEDIA_CREATE_URL = "https://grok.com/rest/media/post/create"


def get_cookies() -> dict:
    with open(HISTORY_FILE, "r") as f:
        return json.load(f).get("cached_cookies", {})


def make_headers(cookies: dict) -> dict:
    cookie_str = "; ".join(f"{k}={v}" for k, v in cookies.items())
    return {
        "Content-Type": "application/json",
        "Accept": "*/*",
        "Origin": "https://grok.com",
        "Referer": "https://grok.com/",
        "Cookie": cookie_str,
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
        "x-xai-request-id": str(uuid.uuid4()),
    }


def create_media_post(headers: dict, prompt: str) -> str:
    """Create a media post first (required for video generation)."""
    resp = requests.post(MEDIA_CREATE_URL, json={
        "mediaType": "MEDIA_POST_TYPE_VIDEO",
        "mediaUrl": "",
        "prompt": prompt,
    }, headers=headers, timeout=30)
    resp.raise_for_status()
    data = resp.json()
    post_id = data.get("id", data.get("postId", data.get("post_id", "")))
    if not post_id:
        # Try to extract from response
        for key in data:
            if "id" in key.lower():
                post_id = data[key]
                break
    return str(post_id)


def generate_video(prompt: str, aspect_ratio: str = "3:2", resolution: str = "480p",
                   length: int = 6, output: str = None) -> str:
    cookies = get_cookies()
    if not cookies.get("sso"):
        print("ERROR: No Grok SSO cookies found. Run grok downloader first or log into grok.com in Chrome.")
        sys.exit(1)

    headers = make_headers(cookies)

    # Step 1: Create media post
    print(f"Creating media post...")
    try:
        post_id = create_media_post(headers, prompt)
        print(f"  Post ID: {post_id}")
    except Exception as e:
        print(f"  Failed to create media post: {e}")
        print("  Trying without media post...")
        post_id = str(uuid.uuid4())

    # Step 2: Send chat request with video config
    print(f"Generating video: {prompt}")
    print(f"  Settings: {aspect_ratio}, {resolution}, {length}s")

    body = {
        "deviceEnvInfo": {
            "darkModeEnabled": True,
            "devicePixelRatio": 2,
            "screenHeight": 1080,
            "screenWidth": 1920,
            "viewportHeight": 900,
            "viewportWidth": 1920,
        },
        "disableMemory": True,
        "disableSearch": True,
        "disableSelfHarmShortCircuit": False,
        "disableTextFollowUps": True,
        "enableImageGeneration": False,
        "enableImageStreaming": False,
        "enableSideBySide": False,
        "fileAttachments": [],
        "forceConcise": False,
        "forceSideBySide": False,
        "imageAttachments": [],
        "imageGenerationCount": 0,
        "isAsyncChat": False,
        "isReasoning": False,
        "message": f"{prompt} --mode=normal",
        "modelMode": None,
        "modelName": "grok-3",
        "responseMetadata": {
            "requestModelDetails": {"modelId": "grok-3"},
            "modelConfigOverride": {
                "videoGenModelConfig": {
                    "aspectRatio": aspect_ratio,
                    "parentPostId": post_id,
                    "resolutionName": resolution,
                    "videoLength": length,
                }
            }
        },
        "returnImageBytes": False,
        "returnRawGrokInXaiRequest": False,
        "sendFinalMetadata": True,
        "temporary": False,
        "toolOverrides": {"videoGen": True},
    }

    try:
        resp = requests.post(CHAT_URL, json=body, headers=headers, timeout=180, stream=True)
        resp.raise_for_status()
    except requests.exceptions.HTTPError as e:
        print(f"  API error: {e}")
        print(f"  Response: {resp.text[:500]}")
        return ""

    # Parse streaming response for video URL
    video_url = ""
    print("  Waiting for video generation (this takes 1-3 minutes)...")

    for line in resp.iter_lines(decode_unicode=True):
        if not line:
            continue
        try:
            data = json.loads(line)

            # Look for video URL in various response formats
            if "videoUrl" in str(data):
                # Deep search for video URL
                video_url = _find_value(data, "videoUrl") or _find_value(data, "video_url") or ""
                if video_url:
                    print(f"  Video URL found!")
                    break

            if "mediaUrl" in str(data):
                url = _find_value(data, "mediaUrl") or ""
                if url and (".mp4" in url or "video" in url):
                    video_url = url
                    print(f"  Video URL found!")
                    break

            # Check for share/public URLs
            if "imagine-public.x.ai" in str(data) or "share-videos" in str(data):
                for val in _find_all_strings(data):
                    if ".mp4" in val or "share-videos" in val:
                        video_url = val
                        print(f"  Video URL found!")
                        break
                if video_url:
                    break

            # Status updates
            msg = data.get("message", data.get("text", ""))
            if msg and isinstance(msg, str) and len(msg) < 200:
                print(f"  Status: {msg}")

        except json.JSONDecodeError:
            continue

    if not video_url:
        print("  No video URL found in response. Video may still be processing.")
        print("  Check grok.com/imagine for your video.")
        return ""

    # Download video
    os.makedirs(DOWNLOADS_DIR, exist_ok=True)
    if output:
        base, ext = os.path.splitext(output)
        filepath = os.path.join(DOWNLOADS_DIR, f"{base}{ext or '.mp4'}")
    else:
        filepath = os.path.join(DOWNLOADS_DIR, f"grok_video_{uuid.uuid4().hex[:8]}.mp4")

    print(f"  Downloading video...")
    cookie_str = "; ".join(f"{k}={v}" for k, v in cookies.items())
    dl_headers = {}
    if "assets.grok.com" in video_url:
        dl_headers["Cookie"] = cookie_str

    try:
        dl_resp = requests.get(video_url, headers=dl_headers, timeout=120)
        dl_resp.raise_for_status()
        with open(filepath, "wb") as f:
            f.write(dl_resp.content)
        print(f"  Saved: {filepath}")
        return filepath
    except Exception as e:
        print(f"  Download failed: {e}")
        print(f"  Direct URL: {video_url}")
        return ""


def _find_value(obj, key):
    """Recursively find a value by key in nested dict/list."""
    if isinstance(obj, dict):
        if key in obj:
            return obj[key]
        for v in obj.values():
            result = _find_value(v, key)
            if result:
                return result
    elif isinstance(obj, list):
        for item in obj:
            result = _find_value(item, key)
            if result:
                return result
    return None


def _find_all_strings(obj) -> list[str]:
    """Recursively find all string values."""
    strings = []
    if isinstance(obj, str):
        strings.append(obj)
    elif isinstance(obj, dict):
        for v in obj.values():
            strings.extend(_find_all_strings(v))
    elif isinstance(obj, list):
        for item in obj:
            strings.extend(_find_all_strings(item))
    return strings


def main():
    parser = argparse.ArgumentParser(description="Generate videos with Grok AI")
    parser.add_argument("--description", "-d", required=True, help="Video description/prompt")
    parser.add_argument("--output", "-o", default=None, help="Output filename")
    parser.add_argument("--aspect", default="3:2", choices=["2:3", "3:2", "16:9", "9:16", "1:1"])
    parser.add_argument("--resolution", default="480p", choices=["480p", "720p"])
    parser.add_argument("--length", type=int, default=6, choices=[6, 10], help="Video length in seconds")
    args = parser.parse_args()

    generate_video(args.description, args.aspect, args.resolution, args.length, args.output)


if __name__ == "__main__":
    main()
