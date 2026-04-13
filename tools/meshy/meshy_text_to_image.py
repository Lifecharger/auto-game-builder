"""
Meshy AI — Text to Image (generate concept art / reference images)

Usage:
  python meshy_text_to_image.py "A fantasy elf warrior" --pose t-pose --output ./output

  # Multi-view (front/side/back)
  python meshy_text_to_image.py "A fantasy elf warrior" --multi-view --output ./output

  # Pro model
  python meshy_text_to_image.py "A fantasy elf warrior" --pro --output ./output
"""

import argparse
import os
from meshy_client import post, poll_task, download_model


def main():
    parser = argparse.ArgumentParser(description="Meshy Text to Image")
    parser.add_argument("prompt", help="Image description")
    parser.add_argument("--pose", choices=["t-pose", "a-pose"], help="Pose mode")
    parser.add_argument("--multi-view", action="store_true", help="Generate multi-angle views")
    parser.add_argument("--pro", action="store_true", help="Use nano-banana-pro model")
    parser.add_argument("--aspect", choices=["1:1", "16:9", "9:16", "4:3", "3:4"], default="1:1")
    parser.add_argument("--output", "-o", default=".", help="Output directory")
    parser.add_argument("--name", "-n", help="Output filename prefix")
    parser.add_argument("--no-download", action="store_true")
    parser.add_argument("--no-wait", action="store_true")

    args = parser.parse_args()

    payload = {
        "ai_model": "nano-banana-pro" if args.pro else "nano-banana",
        "prompt": args.prompt,
    }
    if args.pose:
        payload["pose_mode"] = args.pose
    if args.multi_view:
        payload["generate_multi_view"] = True
    elif args.aspect != "1:1":
        payload["aspect_ratio"] = args.aspect

    print(f"Creating text-to-image: {args.prompt[:80]}...")
    result = post("/openapi/v1/text-to-image", payload)
    task_id = result["result"]
    print(f"Task ID: {task_id}")

    if args.no_wait:
        return

    print("Waiting for generation...")
    task = poll_task("/openapi/v1/text-to-image", task_id)
    name = args.name or "image"

    if not args.no_download:
        os.makedirs(args.output, exist_ok=True)
        image_urls = task.get("image_urls", [])
        for i, url in enumerate(image_urls):
            suffix = f"_view{i}" if len(image_urls) > 1 else ""
            download_model(url, os.path.join(args.output, f"{name}{suffix}.png"))


if __name__ == "__main__":
    main()
