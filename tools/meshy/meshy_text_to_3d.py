"""
Meshy AI — Text to 3D (preview + refine)

Usage:
  # Preview
  python meshy_text_to_3d.py preview "A fantasy sword" --pose t-pose --output ./output

  # Refine from preview
  python meshy_text_to_3d.py refine PREVIEW_TASK_ID --output ./output

  # Preview + auto-refine
  python meshy_text_to_3d.py preview "A fantasy sword" --pose t-pose --refine --output ./output
"""

import argparse
import sys
from meshy_client import post, poll_task, download_task_models


def create_preview(args) -> str:
    payload = {
        "mode": "preview",
        "prompt": args.prompt,
    }
    if args.pose:
        payload["pose_mode"] = args.pose
    if args.model_type:
        payload["model_type"] = args.model_type
    if args.ai_model:
        payload["ai_model"] = args.ai_model
    if args.art_style:
        payload["art_style"] = args.art_style
    if args.topology:
        payload["topology"] = args.topology
    if args.polycount:
        payload["target_polycount"] = args.polycount
    if args.symmetry:
        payload["symmetry_mode"] = args.symmetry
    if args.formats:
        payload["target_formats"] = args.formats
    if args.auto_size:
        payload["auto_size"] = True
    if args.origin:
        payload["origin_at"] = args.origin

    print(f"Creating preview: {args.prompt[:80]}...")
    result = post("/openapi/v2/text-to-3d", payload)
    task_id = result["result"]
    print(f"Task ID: {task_id}")
    return task_id


def create_refine(preview_task_id: str, args) -> str:
    payload = {
        "mode": "refine",
        "preview_task_id": preview_task_id,
    }
    if args.enable_pbr:
        payload["enable_pbr"] = True
    if hasattr(args, "texture_prompt") and args.texture_prompt:
        payload["texture_prompt"] = args.texture_prompt
    if args.ai_model:
        payload["ai_model"] = args.ai_model
    if args.formats:
        payload["target_formats"] = args.formats

    print(f"Creating refine for preview {preview_task_id}...")
    result = post("/openapi/v2/text-to-3d", payload)
    task_id = result["result"]
    print(f"Refine Task ID: {task_id}")
    return task_id


def main():
    parser = argparse.ArgumentParser(description="Meshy Text to 3D")
    sub = parser.add_subparsers(dest="mode", required=True)

    # Preview
    p_preview = sub.add_parser("preview")
    p_preview.add_argument("prompt", help="Object description (max 600 chars)")
    p_preview.add_argument("--pose", choices=["t-pose", "a-pose"], help="Pose mode")
    p_preview.add_argument("--model-type", choices=["standard", "lowpoly"])
    p_preview.add_argument("--ai-model", choices=["meshy-5", "meshy-6", "latest"])
    p_preview.add_argument("--art-style", choices=["realistic", "sculpture"])
    p_preview.add_argument("--topology", choices=["quad", "triangle"])
    p_preview.add_argument("--polycount", type=int, help="Target polycount (100-300000)")
    p_preview.add_argument("--symmetry", choices=["off", "auto", "on"])
    p_preview.add_argument("--formats", nargs="+", choices=["glb", "obj", "fbx", "stl", "usdz"])
    p_preview.add_argument("--auto-size", action="store_true")
    p_preview.add_argument("--origin", choices=["bottom", "center"])
    p_preview.add_argument("--refine", action="store_true", help="Auto-refine after preview")
    p_preview.add_argument("--enable-pbr", action="store_true")
    p_preview.add_argument("--texture-prompt", help="Texture guidance for refine")
    p_preview.add_argument("--output", "-o", default=".", help="Output directory")
    p_preview.add_argument("--name", "-n", help="Output filename prefix")
    p_preview.add_argument("--no-download", action="store_true")
    p_preview.add_argument("--no-wait", action="store_true")

    # Refine
    p_refine = sub.add_parser("refine")
    p_refine.add_argument("preview_task_id", help="Preview task ID to refine")
    p_refine.add_argument("--ai-model", choices=["meshy-5", "meshy-6", "latest"])
    p_refine.add_argument("--enable-pbr", action="store_true")
    p_refine.add_argument("--texture-prompt", help="Texture guidance")
    p_refine.add_argument("--formats", nargs="+", choices=["glb", "obj", "fbx", "stl", "usdz"])
    p_refine.add_argument("--output", "-o", default=".", help="Output directory")
    p_refine.add_argument("--name", "-n", help="Output filename prefix")
    p_refine.add_argument("--no-download", action="store_true")
    p_refine.add_argument("--no-wait", action="store_true")

    args = parser.parse_args()
    endpoint = "/openapi/v2/text-to-3d"

    if args.mode == "preview":
        task_id = create_preview(args)
        if args.no_wait:
            print(f"Preview task queued: {task_id}")
            return

        print("Waiting for preview...")
        task = poll_task(endpoint, task_id)
        name = args.name or "preview"

        if not args.no_download:
            download_task_models(task, args.output, name, args.formats or ["glb"])

        if args.refine:
            refine_id = create_refine(task_id, args)
            print("Waiting for refine...")
            refine_task = poll_task(endpoint, refine_id)
            refine_name = (args.name or "model") + "_refined"
            if not args.no_download:
                download_task_models(refine_task, args.output, refine_name, args.formats or ["glb"])

    elif args.mode == "refine":
        refine_id = create_refine(args.preview_task_id, args)
        if args.no_wait:
            print(f"Refine task queued: {refine_id}")
            return

        print("Waiting for refine...")
        refine_task = poll_task(endpoint, refine_id)
        name = args.name or "refined"
        if not args.no_download:
            download_task_models(refine_task, args.output, name, args.formats or ["glb"])


if __name__ == "__main__":
    main()
