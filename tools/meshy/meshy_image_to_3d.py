"""
Meshy AI — Image to 3D

Usage:
  # From local file
  python meshy_image_to_3d.py ./character.png --pose t-pose --output ./output

  # From URL
  python meshy_image_to_3d.py "https://example.com/img.png" --pose t-pose --output ./output

  # Multiple images
  python meshy_image_to_3d.py front.png side.png back.png --pose t-pose --multi --output ./output
"""

import argparse
import os
from meshy_client import post, poll_task, download_task_models, image_to_base64


def create_single(args) -> str:
    image = args.images[0]
    if os.path.isfile(image):
        image = image_to_base64(image)

    payload = {"image_url": image}
    _add_common_params(payload, args)

    print(f"Creating image-to-3D task...")
    result = post("/openapi/v1/image-to-3d", payload)
    task_id = result["result"]
    print(f"Task ID: {task_id}")
    return task_id


def create_multi(args) -> str:
    urls = []
    for img in args.images:
        if os.path.isfile(img):
            urls.append(image_to_base64(img))
        else:
            urls.append(img)

    payload = {"image_urls": urls}
    _add_common_params(payload, args)

    print(f"Creating multi-image-to-3D task ({len(urls)} images)...")
    result = post("/openapi/v1/multi-image-to-3d", payload)
    task_id = result["result"]
    print(f"Task ID: {task_id}")
    return task_id


def _add_common_params(payload, args):
    if args.pose:
        payload["pose_mode"] = args.pose
    if args.model_type:
        payload["model_type"] = args.model_type
    if args.ai_model:
        payload["ai_model"] = args.ai_model
    if args.topology:
        payload["topology"] = args.topology
    if args.polycount:
        payload["target_polycount"] = args.polycount
    if args.symmetry:
        payload["symmetry_mode"] = args.symmetry
    if args.enable_pbr:
        payload["enable_pbr"] = True
    if args.texture_prompt:
        payload["texture_prompt"] = args.texture_prompt
    if args.no_texture:
        payload["should_texture"] = False
    if args.formats:
        payload["target_formats"] = args.formats
    if args.auto_size:
        payload["auto_size"] = True
    if args.origin:
        payload["origin_at"] = args.origin
    if args.no_enhancement:
        payload["image_enhancement"] = False


def main():
    parser = argparse.ArgumentParser(description="Meshy Image to 3D")
    parser.add_argument("images", nargs="+", help="Image path(s) or URL(s)")
    parser.add_argument("--multi", action="store_true", help="Use multi-image endpoint (1-4 images)")
    parser.add_argument("--pose", choices=["t-pose", "a-pose"], help="Pose mode")
    parser.add_argument("--model-type", choices=["standard", "lowpoly"])
    parser.add_argument("--ai-model", choices=["meshy-5", "meshy-6", "latest"])
    parser.add_argument("--topology", choices=["quad", "triangle"])
    parser.add_argument("--polycount", type=int, help="Target polycount (100-300000)")
    parser.add_argument("--symmetry", choices=["off", "auto", "on"])
    parser.add_argument("--enable-pbr", action="store_true")
    parser.add_argument("--texture-prompt", help="Texture guidance (max 600 chars)")
    parser.add_argument("--no-texture", action="store_true", help="Skip texture generation")
    parser.add_argument("--no-enhancement", action="store_true", help="Disable image enhancement")
    parser.add_argument("--formats", nargs="+", choices=["glb", "obj", "fbx", "stl", "usdz"])
    parser.add_argument("--auto-size", action="store_true")
    parser.add_argument("--origin", choices=["bottom", "center"])
    parser.add_argument("--output", "-o", default=".", help="Output directory")
    parser.add_argument("--name", "-n", help="Output filename prefix")
    parser.add_argument("--no-download", action="store_true")
    parser.add_argument("--no-wait", action="store_true")

    args = parser.parse_args()

    if args.multi or len(args.images) > 1:
        task_id = create_multi(args)
        endpoint = "/openapi/v1/multi-image-to-3d"
    else:
        task_id = create_single(args)
        endpoint = "/openapi/v1/image-to-3d"

    if args.no_wait:
        print(f"Task queued: {task_id}")
        return

    print("Waiting for generation...")
    task = poll_task(endpoint, task_id)
    name = args.name or "model"

    if not args.no_download:
        download_task_models(task, args.output, name, args.formats or ["glb"])


if __name__ == "__main__":
    main()
