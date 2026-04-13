"""
Auto-rig a previously-generated Tripo3D model.

Must be run AFTER tripo_generate.py — takes the task_id from that step.

Key choice: --spec
    - "mixamo" → rig with a Mixamo-compatible skeleton (use this if you plan to
                 use any Mixamo animations; also plays well with Godot/Unity retargeting)
    - "tripo"  → Tripo's own rig (default; required for retargeting Tripo's
                 built-in Animation presets via tripo_animate.py)

You usually want "tripo" for auto-animation via tripo_animate.py, and "mixamo"
if you're going to upload to Mixamo manually.

Usage:
    python tripo_rig.py <task_id>
    python tripo_rig.py <task_id> --spec mixamo
    python tripo_rig.py <task_id> --format fbx
    python tripo_rig.py <task_id> -o ./projects/Lyrienne/3d/
"""
import argparse
import asyncio
import sys
from pathlib import Path

from tripo3d import RigSpec, RigType
from tripo_client import get_client, DEFAULT_OUTPUT_DIR


async def run(args):
    async with get_client() as client:
        # Sanity check first — tripo has a check_riggable endpoint
        print(f"Checking if task {args.task_id} is riggable...")
        try:
            check_task_id = await client.check_riggable(args.task_id)
            check_task = await client.wait_for_task(check_task_id, polling_interval=2.0)
            riggable = getattr(check_task.output, "riggable", None) if check_task.output else None
            print(f"  riggable: {riggable}")
            if riggable is False:
                print("ERROR: Tripo says this model cannot be rigged automatically.")
                sys.exit(3)
        except Exception as e:
            print(f"  (check_riggable failed: {e} — continuing anyway)")

        # Submit rig task
        print(f"Submitting rig task: spec={args.spec}, rig_type={args.rig_type}, out_format={args.format}")
        rig_task_id = await client.rig_model(
            original_model_task_id=args.task_id,
            out_format=args.format,
            rig_type=RigType(args.rig_type),
            spec=RigSpec(args.spec),
        )
        print(f"  rig_task_id: {rig_task_id}")

        print("Waiting for rigging to complete...")
        task = await client.wait_for_task(rig_task_id, verbose=True, polling_interval=3.0)
        if task.status.value != "success":
            print(f"FAILED: {task.status}")
            sys.exit(2)

        # Download
        output_dir = Path(args.output or DEFAULT_OUTPUT_DIR)
        output_dir.mkdir(parents=True, exist_ok=True)
        files = await client.download_task_models(task, str(output_dir))
        for kind, path in files.items():
            if path:
                print(f"  {kind}: {path}")

        print(f"\nDONE. rig_task_id={rig_task_id}")
        print(f"(Feed this rig_task_id to tripo_animate.py next)")
        return rig_task_id


def main():
    p = argparse.ArgumentParser(description="Auto-rig a Tripo3D model")
    p.add_argument("task_id", help="Original model task_id from tripo_generate.py")
    p.add_argument("--spec", default="tripo", choices=["tripo", "mixamo"],
                   help="Rig skeleton spec. Use 'tripo' for auto-animation, 'mixamo' for Mixamo upload.")
    p.add_argument("--rig-type", dest="rig_type", default="biped",
                   choices=["biped", "quadruped", "hexapod", "octopod", "avian", "serpentine", "aquatic", "others"])
    p.add_argument("--format", default="glb", choices=["glb", "fbx"],
                   help="Export format (default glb, use fbx for Mixamo/Unity)")
    p.add_argument("-o", "--output", help="Output directory")
    args = p.parse_args()
    asyncio.run(run(args))


if __name__ == "__main__":
    main()
