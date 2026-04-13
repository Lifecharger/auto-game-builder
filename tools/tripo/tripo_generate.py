"""
Generate a 3D character via Tripo3D API.

Supports three input modes:
    --text   "prompt"                  text-to-3D
    --image  path/or/url               single-image-to-3D
    --multi  front.png [back.png ...]  multi-view-to-3D (best character consistency)

Outputs GLB by default. Pair with tripo_rig.py + tripo_animate.py next.

Usage:
    python tripo_generate.py --text "elven warrior, T-pose, black leather armor, long sword"
    python tripo_generate.py --image lyrienne_south.png -o ./projects/Lyrienne/3d/
    python tripo_generate.py --multi south.png east.png west.png north.png -o ./projects/Lyrienne/3d/
    python tripo_generate.py --text "..." --draft     # cheaper "draft" run
    python tripo_generate.py --text "..." --turbo     # fastest model version
"""
import argparse
import asyncio
import os
import sys
from pathlib import Path

from tripo_client import get_client, CHARACTER_DEFAULTS, DEFAULT_OUTPUT_DIR


async def run(args):
    async with get_client() as client:
        # Override defaults if user asked for turbo / draft
        params = dict(CHARACTER_DEFAULTS)
        if args.turbo:
            params["model_version"] = "Turbo-v1.0-20250506"
            params["geometry_quality"] = "standard"
            params["texture_quality"] = "standard"
        if args.draft:
            # Draft = cheapest path. Tripo's "draft" is basically the non-turbo
            # standard-quality generation; can be refined later via refine_model.
            params["geometry_quality"] = "standard"
            params["texture_quality"] = "standard"
        if args.no_texture:
            params["texture"] = False
            params["pbr"] = False
        if args.face_limit:
            params["face_limit"] = args.face_limit

        # Kick off the right task type
        if args.text:
            print(f"Submitting text-to-3D...\n  prompt: {args.text[:100]}...")
            task_id = await client.text_to_model(prompt=args.text, **params)
        elif args.image:
            print(f"Submitting image-to-3D...\n  image: {args.image}")
            # Strip character-only params that aren't supported by image_to_model
            # (quad + smart_low_poly + all in image_to_model's supported set)
            task_id = await client.image_to_model(
                image=args.image,
                orientation="align_image",  # align to the reference image
                **params,
            )
        elif args.multi:
            print(f"Submitting multi-view-to-3D...\n  images: {len(args.multi)}")
            task_id = await client.multiview_to_model(
                images=args.multi,
                orientation="align_image",
                **params,
            )
        else:
            print("ERROR: must pass --text, --image, or --multi")
            sys.exit(1)

        print(f"  task_id: {task_id}")

        # Poll until done
        print("Waiting for generation to complete (2-3 min typical)...")
        task = await client.wait_for_task(task_id, verbose=True, polling_interval=3.0)

        if task.status.value != "success":
            print(f"FAILED: status={task.status}, msg={task.output}")
            sys.exit(2)

        # Download
        output_dir = Path(args.output or DEFAULT_OUTPUT_DIR)
        output_dir.mkdir(parents=True, exist_ok=True)
        print(f"Downloading to {output_dir}...")
        files = await client.download_task_models(task, str(output_dir))
        for kind, path in files.items():
            if path:
                print(f"  {kind}: {path}")

        # Print the task_id so downstream tools (tripo_rig, tripo_animate) can use it
        print(f"\nDONE. task_id={task_id}")
        print(f"(Feed this task_id to tripo_rig.py next)")
        return task_id


def main():
    p = argparse.ArgumentParser(description="Generate a 3D character via Tripo3D")
    src = p.add_mutually_exclusive_group(required=True)
    src.add_argument("--text", help='Text prompt, e.g. "elven warrior in T-pose"')
    src.add_argument("--image", help="Path or URL to a single reference image")
    src.add_argument("--multi", nargs="+", metavar="IMG",
                     help="Multiple reference views (front back left right)")
    p.add_argument("-o", "--output", help="Output directory (default ~/Downloads/tripo3d-output/)")
    p.add_argument("--turbo", action="store_true", help="Use Turbo model (fastest, cheapest)")
    p.add_argument("--draft", action="store_true", help="Use standard-quality (cheaper than detailed)")
    p.add_argument("--no-texture", action="store_true", help="Skip texturing (geometry only)")
    p.add_argument("--face-limit", type=int, help="Max face count (for lower-poly output)")
    args = p.parse_args()

    asyncio.run(run(args))


if __name__ == "__main__":
    main()
