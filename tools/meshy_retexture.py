"""
Meshy AI — Retexture (apply new textures to existing 3D model)

Usage:
  # From task ID
  python meshy_retexture.py --task-id TASK_ID --style "medieval stone texture" --output ./output

  # From local model file
  python meshy_retexture.py --model ./model.glb --style "cartoon colorful" --output ./output

  # From style image
  python meshy_retexture.py --task-id TASK_ID --style-image ./reference.png --output ./output
"""

import argparse
from meshy_client import post, poll_task, download_task_models, model_to_base64, image_to_base64
import os


def main():
    parser = argparse.ArgumentParser(description="Meshy Retexture")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--task-id", help="Input task ID from prior 3D generation")
    group.add_argument("--model", help="Path or URL to 3D model file")

    style_group = parser.add_mutually_exclusive_group(required=True)
    style_group.add_argument("--style", help="Text style prompt (max 600 chars)")
    style_group.add_argument("--style-image", help="Style reference image path or URL")

    parser.add_argument("--ai-model", choices=["meshy-5", "meshy-6", "latest"])
    parser.add_argument("--enable-pbr", action="store_true")
    parser.add_argument("--keep-uv", action="store_true", default=True, help="Preserve original UVs (default: true)")
    parser.add_argument("--no-keep-uv", action="store_true", help="Don't preserve original UVs")
    parser.add_argument("--formats", nargs="+", choices=["glb", "obj", "fbx", "stl", "usdz"])
    parser.add_argument("--output", "-o", default=".", help="Output directory")
    parser.add_argument("--name", "-n", help="Output filename prefix")
    parser.add_argument("--no-download", action="store_true")
    parser.add_argument("--no-wait", action="store_true")

    args = parser.parse_args()

    payload = {}
    if args.task_id:
        payload["input_task_id"] = args.task_id
    elif args.model:
        if os.path.isfile(args.model):
            payload["model_url"] = model_to_base64(args.model)
        else:
            payload["model_url"] = args.model

    if args.style:
        payload["text_style_prompt"] = args.style
    elif args.style_image:
        if os.path.isfile(args.style_image):
            payload["image_style_url"] = image_to_base64(args.style_image)
        else:
            payload["image_style_url"] = args.style_image

    if args.ai_model:
        payload["ai_model"] = args.ai_model
    if args.enable_pbr:
        payload["enable_pbr"] = True
    if args.no_keep_uv:
        payload["enable_original_uv"] = False
    if args.formats:
        payload["target_formats"] = args.formats

    print("Creating retexture task...")
    result = post("/openapi/v1/retexture", payload)
    task_id = result["result"]
    print(f"Task ID: {task_id}")

    if args.no_wait:
        return

    print("Waiting for retexture...")
    task = poll_task("/openapi/v1/retexture", task_id)
    name = args.name or "retextured"

    if not args.no_download:
        download_task_models(task, args.output, name, args.formats or ["glb"])


if __name__ == "__main__":
    main()
