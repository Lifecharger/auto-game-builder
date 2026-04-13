"""
End-to-end Tripo3D pipeline: generate → rig → animate → download.

Runs the whole chain from a single command so you don't have to paste task_ids
between tripo_generate / tripo_rig / tripo_animate manually.

Usage:
    # Text-to-character full pipeline
    python tripo_pipeline.py --text "elven warrior in T-pose, black leather armor, long sword"

    # Image reference (e.g. an existing Grok 2D of Lyrienne)
    python tripo_pipeline.py --image ./projects/Lyrienne/01_south_base/lyrienne_south.png \
        --output ./projects/Lyrienne/3d/

    # Multi-view for best character consistency
    python tripo_pipeline.py --multi front.png back.png left.png right.png \
        --output ./projects/Lyrienne/3d/

    # Pick specific animations (default = all 11 biped)
    python tripo_pipeline.py --text "..." --anims idle walk run slash jump

    # Cheaper/faster path (lower quality, less credit cost)
    python tripo_pipeline.py --text "..." --draft

    # Mixamo-compatible rig instead of Tripo's own rig (skips --anims step;
    # you'll apply animations separately in Mixamo)
    python tripo_pipeline.py --text "..." --spec mixamo --skip-anims
"""
import argparse
import asyncio
import sys
from pathlib import Path

from tripo3d import RigSpec, RigType, Animation
from tripo_client import get_client, CHARACTER_DEFAULTS, DEFAULT_OUTPUT_DIR

BIPED_ANIMS = [
    Animation.IDLE, Animation.WALK, Animation.RUN, Animation.DIVE,
    Animation.CLIMB, Animation.JUMP, Animation.SLASH, Animation.SHOOT,
    Animation.HURT, Animation.FALL, Animation.TURN,
]
ANIM_BY_NAME = {a.name.lower(): a for a in Animation}


async def run(args):
    output_dir = Path(args.output or DEFAULT_OUTPUT_DIR)
    output_dir.mkdir(parents=True, exist_ok=True)

    async with get_client() as client:
        # ── Step 1: Generate ──
        params = dict(CHARACTER_DEFAULTS)
        if args.draft:
            params["geometry_quality"] = "standard"
            params["texture_quality"] = "standard"
        if args.turbo:
            params["model_version"] = "Turbo-v1.0-20250506"
            params["geometry_quality"] = "standard"
            params["texture_quality"] = "standard"

        print("=" * 60)
        print("STEP 1 — Generate base 3D model")
        print("=" * 60)
        if args.text:
            print(f"  text: {args.text[:80]}")
            gen_task_id = await client.text_to_model(prompt=args.text, **params)
        elif args.image:
            print(f"  image: {args.image}")
            gen_task_id = await client.image_to_model(
                image=args.image, orientation="align_image", **params)
        elif args.multi:
            print(f"  multi-view: {len(args.multi)} images")
            gen_task_id = await client.multiview_to_model(
                images=args.multi, orientation="align_image", **params)
        else:
            print("ERROR: need --text, --image, or --multi")
            sys.exit(1)
        print(f"  gen_task_id: {gen_task_id}")

        task = await client.wait_for_task(gen_task_id, verbose=True, polling_interval=3.0)
        if task.status.value != "success":
            print(f"FAILED at generate step: {task.status}")
            sys.exit(2)
        files = await client.download_task_models(task, str(output_dir))
        print(f"  downloaded: {[p for p in files.values() if p]}")

        if args.only_generate:
            print("\n--only-generate set — stopping here.")
            return

        # ── Step 2: Rig ──
        print()
        print("=" * 60)
        print("STEP 2 — Auto-rig model")
        print("=" * 60)
        rig_task_id = await client.rig_model(
            original_model_task_id=gen_task_id,
            out_format=args.format,
            rig_type=RigType.BIPED,
            spec=RigSpec(args.spec),
        )
        print(f"  rig_task_id: {rig_task_id}  (spec={args.spec})")
        task = await client.wait_for_task(rig_task_id, verbose=True, polling_interval=3.0)
        if task.status.value != "success":
            print(f"FAILED at rig step: {task.status}")
            sys.exit(2)
        files = await client.download_task_models(task, str(output_dir))
        print(f"  downloaded: {[p for p in files.values() if p]}")

        if args.skip_anims or args.spec == "mixamo":
            print("\nSkipping animations (mixamo rigs must be animated in Mixamo).")
            print(f"Rig task_id: {rig_task_id}")
            return

        # ── Step 3: Retarget animations ──
        if args.anims:
            anims = [ANIM_BY_NAME[n.lower()] for n in args.anims]
        else:
            anims = BIPED_ANIMS
        print()
        print("=" * 60)
        print(f"STEP 3 — Retarget {len(anims)} animation(s)")
        print("=" * 60)
        for a in anims:
            print(f"  - {a.name}")
        retarget_task_id = await client.retarget_animation(
            original_model_task_id=rig_task_id,
            animation=anims,
            out_format=args.format,
            bake_animation=True,
            export_with_geometry=True,
            animate_in_place=args.in_place,
        )
        print(f"  retarget_task_id: {retarget_task_id}")
        task = await client.wait_for_task(retarget_task_id, verbose=True, polling_interval=3.0)
        if task.status.value != "success":
            print(f"FAILED at animation step: {task.status}")
            sys.exit(2)
        files = await client.download_task_models(task, str(output_dir))
        print(f"  downloaded: {[p for p in files.values() if p]}")

        print()
        print("=" * 60)
        print("PIPELINE COMPLETE")
        print("=" * 60)
        print(f"Final animated model is in: {output_dir}")


def main():
    p = argparse.ArgumentParser(description="Full Tripo3D pipeline: generate → rig → animate")
    src = p.add_mutually_exclusive_group(required=True)
    src.add_argument("--text", help="Text prompt")
    src.add_argument("--image", help="Single reference image")
    src.add_argument("--multi", nargs="+", metavar="IMG", help="Multi-view images")
    p.add_argument("-o", "--output", help="Output directory")
    p.add_argument("--format", default="fbx", choices=["glb", "fbx"])
    p.add_argument("--spec", default="tripo", choices=["tripo", "mixamo"],
                   help="Rig spec. 'tripo' for auto-animation, 'mixamo' for Mixamo upload.")
    p.add_argument("--anims", nargs="+",
                   help=f"Animations to apply (default all 11). "
                        f"Valid: {' '.join(sorted(ANIM_BY_NAME.keys()))}")
    p.add_argument("--in-place", action="store_true", help="Lock root motion (recommended for game engines)")
    p.add_argument("--draft", action="store_true", help="Lower quality to save credits")
    p.add_argument("--turbo", action="store_true", help="Fastest model variant")
    p.add_argument("--only-generate", action="store_true", help="Stop after step 1")
    p.add_argument("--skip-anims", action="store_true", help="Stop after rigging")
    args = p.parse_args()
    asyncio.run(run(args))


if __name__ == "__main__":
    main()
