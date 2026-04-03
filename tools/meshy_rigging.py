"""
Meshy AI — Auto-Rigging

Usage:
  # From task ID
  python meshy_rigging.py --task-id TASK_ID --output ./output

  # From local model
  python meshy_rigging.py --model ./character.glb --height 1.7 --output ./output
"""

import argparse
import os
from meshy_client import post, poll_task, download_model, model_to_base64


def main():
    parser = argparse.ArgumentParser(description="Meshy Auto-Rigging")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--task-id", help="Input task ID")
    group.add_argument("--model", help="Path or URL to GLB model")

    parser.add_argument("--height", type=float, default=1.7, help="Character height in meters (default: 1.7)")
    parser.add_argument("--output", "-o", default=".", help="Output directory")
    parser.add_argument("--name", "-n", help="Output filename prefix")
    parser.add_argument("--no-download", action="store_true")
    parser.add_argument("--no-wait", action="store_true")

    args = parser.parse_args()

    payload = {"height_meters": args.height}
    if args.task_id:
        payload["input_task_id"] = args.task_id
    elif args.model:
        if os.path.isfile(args.model):
            payload["model_url"] = model_to_base64(args.model)
        else:
            payload["model_url"] = args.model

    print("Creating rigging task...")
    result = post("/openapi/v1/rigging", payload)
    task_id = result["result"]
    print(f"Task ID: {task_id}")

    if args.no_wait:
        return

    print("Waiting for rigging...")
    task = poll_task("/openapi/v1/rigging", task_id)
    name = args.name or "rigged"

    if not args.no_download:
        out = args.output
        os.makedirs(out, exist_ok=True)

        # Download rigged character
        if task.get("rigged_character_glb_url"):
            download_model(task["rigged_character_glb_url"], os.path.join(out, f"{name}.glb"))
        if task.get("rigged_character_fbx_url"):
            download_model(task["rigged_character_fbx_url"], os.path.join(out, f"{name}.fbx"))

        # Download basic animations
        anims = task.get("basic_animations", {})
        for anim_name in ["walking", "running"]:
            glb_key = f"{anim_name}_glb_url"
            fbx_key = f"{anim_name}_fbx_url"
            if anims.get(glb_key):
                download_model(anims[glb_key], os.path.join(out, f"{name}_{anim_name}.glb"))
            if anims.get(fbx_key):
                download_model(anims[fbx_key], os.path.join(out, f"{name}_{anim_name}.fbx"))

    print(f"\nRigging task ID (for animations): {task_id}")


if __name__ == "__main__":
    main()
