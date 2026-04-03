"""
Meshy AI — Remesh (optimize/retopologize 3D model)

Usage:
  # From task ID
  python meshy_remesh.py --task-id TASK_ID --polycount 10000 --output ./output

  # From local model
  python meshy_remesh.py --model ./model.glb --polycount 5000 --topology quad --output ./output

  # Format conversion only
  python meshy_remesh.py --task-id TASK_ID --convert-only --formats glb fbx --output ./output
"""

import argparse
import os
from meshy_client import post, poll_task, download_task_models, model_to_base64


def main():
    parser = argparse.ArgumentParser(description="Meshy Remesh")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--task-id", help="Input task ID")
    group.add_argument("--model", help="Path or URL to 3D model")

    parser.add_argument("--topology", choices=["quad", "triangle"])
    parser.add_argument("--polycount", type=int, help="Target polycount (100-300000)")
    parser.add_argument("--resize-height", type=float, help="Resize to height in meters")
    parser.add_argument("--auto-size", action="store_true", help="AI estimates real-world height")
    parser.add_argument("--origin", choices=["bottom", "center"])
    parser.add_argument("--convert-only", action="store_true", help="Only convert format")
    parser.add_argument("--formats", nargs="+", choices=["glb", "obj", "fbx", "stl", "usdz", "blend"])
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

    if args.topology:
        payload["topology"] = args.topology
    if args.polycount:
        payload["target_polycount"] = args.polycount
    if args.resize_height:
        payload["resize_height"] = args.resize_height
    if args.auto_size:
        payload["auto_size"] = True
    if args.origin:
        payload["origin_at"] = args.origin
    if args.convert_only:
        payload["convert_format_only"] = True
    if args.formats:
        payload["target_formats"] = args.formats

    print("Creating remesh task...")
    result = post("/openapi/v1/remesh", payload)
    task_id = result["result"]
    print(f"Task ID: {task_id}")

    if args.no_wait:
        return

    print("Waiting for remesh...")
    task = poll_task("/openapi/v1/remesh", task_id)
    name = args.name or "remeshed"

    if not args.no_download:
        download_task_models(task, args.output, name, args.formats or ["glb"])


if __name__ == "__main__":
    main()
