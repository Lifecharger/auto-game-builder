"""One-off (2026-09-16, user: "fix your naming issues first"): rename every
master so <girl>/L<n>.* means GAME LEVEL n. Until now file numbers were
generation numbers and order.json mapped delivered level -> source key
('base' = the original cashier outfit, whose portrait was L1_scene). That
indirection produced wrong frame shapes; it ends here.

    python rename_to_game_levels.py --dry     # show the plan
    python rename_to_game_levels.py           # do it (files, ladders.json, order.json)

After this: order.json is the identity for every girl, ladders.json levels/
scenes are keyed by game level ('__base__' marks the original outfit), the
living portraits are parked to start from scratch, and _canvas files are
dropped (regenerable).
"""
import json
import os
import shutil
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = r"C:/Reusable Assets/Images/Hot Idle/relationships"
SUFFIXES = [".png", "_cut.png", "_scene.png", "_loop.mp4", "_loop_rgba.webm", "_scene_loop.mp4"]


def src_names(key: str) -> list[str]:
    if key == "base":
        return ["base.png", "base_cut.png", "L1_scene.png", "base_loop.mp4", "base_loop_rgba.webm", "L1_scene_loop.mp4"]
    return [f"{key}{s}" for s in SUFFIXES]


def main() -> None:
    dry = "--dry" in sys.argv
    order = json.load(open(os.path.join(HERE, "order.json"), encoding="utf-8"))["order"]
    bank = json.load(open(os.path.join(HERE, "ladders.json"), encoding="utf-8"))
    stamp = time.strftime("%m%d%H%M")
    park = os.path.join(ROOT, "_redo", f"scene_loops_before_rename_{stamp}")
    moves = 0
    for girl, keys in order.items():
        d = os.path.join(ROOT, girl)
        if not os.path.isdir(d):
            continue
        plan = []   # (src, dst)
        for n, key in enumerate(keys, 1):
            for src, suf in zip(src_names(key), SUFFIXES):
                sp = os.path.join(d, src)
                if os.path.isfile(sp):
                    plan.append((sp, os.path.join(d, f"L{n}{suf}")))
        # two-phase: stage everything, then place, so L2->L1 and base->L4 never collide
        stage = os.path.join(d, "_stage_rename")
        if dry:
            for sp, dp in plan:
                if os.path.basename(sp) != os.path.basename(dp):
                    print(f"  {girl}: {os.path.basename(sp)} -> {os.path.basename(dp)}")
        else:
            os.makedirs(stage, exist_ok=True)
            staged = []
            for sp, dp in plan:
                tmp = os.path.join(stage, os.path.basename(dp))
                shutil.move(sp, tmp)
                staged.append((tmp, dp))
            for tmp, dp in staged:
                shutil.move(tmp, dp)
                moves += 1
            os.rmdir(stage)
            # living portraits start from scratch; canvases are regenerable
            for f in os.listdir(d):
                p = os.path.join(d, f)
                if f.endswith("_scene_loop.mp4"):
                    os.makedirs(park, exist_ok=True)
                    shutil.move(p, os.path.join(park, f"{girl}_{f}"))
                elif f.startswith("_canvas_"):
                    os.remove(p)
        # ladders: levels + scenes keyed by game level
        g = bank["girls"][girl]
        new_levels, new_scenes = {}, {}
        for n, key in enumerate(keys, 1):
            gen = "1" if key == "base" else key[1:]
            new_levels[str(n)] = "__base__" if key == "base" else g["levels"].get(gen, "")
            new_scenes[str(n)] = g["scenes"].get(gen, "")
        g["levels"], g["scenes"] = new_levels, new_scenes
    if dry:
        print("dry run: nothing changed")
        return
    bank["_naming"] = ("2026-09-16: levels/scenes keyed by GAME level; '__base__' = the original "
                       "cashier outfit (still made by --base-stills from the reference). Files "
                       "<girl>/L<n>.* are game levels; order.json is the identity.")
    with open(os.path.join(HERE, "ladders.json"), "w", encoding="utf-8") as f:
        json.dump(bank, f, ensure_ascii=False, indent=2)
    identity = {g: [f"L{n}" for n in range(1, 11)] for g in order}
    with open(os.path.join(HERE, "order.json"), "w", encoding="utf-8") as f:
        json.dump({"_note": "identity since 2026-09-16: file L<n> = game level n", "order": identity}, f, indent=1)
    print(f"renamed {moves} files; ladders.json and order.json rewritten; living portraits parked in {park}")


if __name__ == "__main__":
    main()
