"""
Retarget Tripo3D built-in animations onto a rigged model.

Must be run AFTER tripo_rig.py with --spec tripo (NOT --spec mixamo).
The built-in animation library has 11 biped presets:
    idle, walk, run, dive, climb, jump, slash, shoot, hurt, fall, turn
Plus 5 non-biped presets (quadruped_walk, hexapod_walk, etc.)

Each retarget is a separate API call. This script can run them in sequence
to produce one output file per animation, OR combine them into a single
file if Tripo's API supports that (it does — you can pass a list).

Usage:
    # Apply all 11 biped animations as one batch → single GLB with all clips
    python tripo_animate.py <rigged_task_id>

    # Pick specific ones
    python tripo_animate.py <rigged_task_id> --anims idle walk run slash

    # Export as FBX instead of GLB
    python tripo_animate.py <rigged_task_id> --format fbx

    # Keep character rooted in place (good for game engines)
    python tripo_animate.py <rigged_task_id> --in-place
"""
import argparse
import asyncio
import sys
from pathlib import Path

from tripo3d import Animation
from tripo_client import get_client, DEFAULT_OUTPUT_DIR

# All biped animations in the SDK
BIPED_ANIMS = [
    Animation.IDLE, Animation.WALK, Animation.RUN, Animation.DIVE,
    Animation.CLIMB, Animation.JUMP, Animation.SLASH, Animation.SHOOT,
    Animation.HURT, Animation.FALL, Animation.TURN,
]

# Name → enum lookup for CLI args
ANIM_BY_NAME = {a.name.lower(): a for a in Animation}


async def run(args):
    async with get_client() as client:
        # Resolve which animations to apply
        if args.anims:
            try:
                anims = [ANIM_BY_NAME[name.lower()] for name in args.anims]
            except KeyError as e:
                print(f"Unknown animation: {e}. Valid names: {list(ANIM_BY_NAME.keys())}")
                sys.exit(1)
        else:
            anims = BIPED_ANIMS

        print(f"Retargeting {len(anims)} animation(s) onto rig {args.task_id}:")
        for a in anims:
            print(f"  - {a.name}")

        # Single call with a list of animations — Tripo returns one file with
        # all clips embedded (as multiple actions/clips in the FBX/GLB).
        retarget_task_id = await client.retarget_animation(
            original_model_task_id=args.task_id,
            animation=anims,
            out_format=args.format,
            bake_animation=True,
            export_with_geometry=True,
            animate_in_place=args.in_place,
        )
        print(f"  retarget_task_id: {retarget_task_id}")

        print("Waiting for retarget to complete...")
        task = await client.wait_for_task(retarget_task_id, verbose=True, polling_interval=3.0)
        if task.status.value != "success":
            print(f"FAILED: {task.status}")
            sys.exit(2)

        output_dir = Path(args.output or DEFAULT_OUTPUT_DIR)
        output_dir.mkdir(parents=True, exist_ok=True)
        files = await client.download_task_models(task, str(output_dir))
        for kind, path in files.items():
            if path:
                print(f"  {kind}: {path}")

        print("\nDONE. Animated model saved with all clips embedded.")
        print("Drop the .fbx or .glb into your game engine and play the clips by name.")


def main():
    p = argparse.ArgumentParser(description="Retarget Tripo3D built-in animations onto a rigged model")
    p.add_argument("task_id", help="Rigged model task_id from tripo_rig.py (must be --spec tripo)")
    p.add_argument("--anims", nargs="+",
                   help="Subset of animations to apply. Default: all 11 biped animations. "
                        f"Valid: {' '.join(sorted(ANIM_BY_NAME.keys()))}")
    p.add_argument("--format", default="fbx", choices=["glb", "fbx"],
                   help="Output format (default fbx for Unity/Unreal/Godot)")
    p.add_argument("--in-place", action="store_true",
                   help="Animate in place (character doesn't travel along root motion). "
                        "Recommended for 2.5D games where engine controls movement.")
    p.add_argument("-o", "--output", help="Output directory")
    args = p.parse_args()
    asyncio.run(run(args))


if __name__ == "__main__":
    main()
