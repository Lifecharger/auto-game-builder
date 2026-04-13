"""
Meshy AI — Animation (animate a rigged model)

Usage:
  python meshy_animation.py RIG_TASK_ID ACTION_ID --output ./output

  # With FPS conversion
  python meshy_animation.py RIG_TASK_ID 0 --fps 60 --output ./output

  # Common action IDs:
  #   0 = Idle
  #   1 = Walking_Woman
  #   4 = Attack
  #   14 = Run_02
  #   22 = FunnyDancing_01
  #   25 = Agree_Gesture
  #   30 = Casual_Walk
  #   41 = Formal_Bow
  # Full list: https://docs.meshy.ai/en/api/animation-library
"""

import argparse
import os
from meshy_client import post, poll_task, download_model


def main():
    parser = argparse.ArgumentParser(description="Meshy Animation")
    parser.add_argument("rig_task_id", help="Completed rigging task ID")
    parser.add_argument("action_id", type=int, help="Animation ID from Meshy library")
    parser.add_argument("--fps", type=int, choices=[24, 25, 30, 60], help="Convert to target FPS")
    parser.add_argument("--output", "-o", default=".", help="Output directory")
    parser.add_argument("--name", "-n", help="Output filename prefix")
    parser.add_argument("--no-download", action="store_true")
    parser.add_argument("--no-wait", action="store_true")

    args = parser.parse_args()

    payload = {
        "rig_task_id": args.rig_task_id,
        "action_id": args.action_id,
    }
    if args.fps:
        payload["post_process"] = {
            "operation_type": "change_fps",
            "fps": args.fps,
        }

    print(f"Creating animation task (action {args.action_id})...")
    result = post("/openapi/v1/animations", payload)
    task_id = result["result"]
    print(f"Task ID: {task_id}")

    if args.no_wait:
        return

    print("Waiting for animation...")
    task = poll_task("/openapi/v1/animations", task_id)
    name = args.name or f"anim_{args.action_id}"

    if not args.no_download:
        out = args.output
        os.makedirs(out, exist_ok=True)

        if task.get("animation_glb_url"):
            download_model(task["animation_glb_url"], os.path.join(out, f"{name}.glb"))
        if task.get("animation_fbx_url"):
            download_model(task["animation_fbx_url"], os.path.join(out, f"{name}.fbx"))
        if task.get("processed_animation_fps_fbx_url"):
            download_model(task["processed_animation_fps_fbx_url"], os.path.join(out, f"{name}_{args.fps}fps.fbx"))


if __name__ == "__main__":
    main()
