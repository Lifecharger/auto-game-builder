"""Copy each live girl/npc clip revision back over its plain source strip, so the NEXT repack starts from
the cleaned pixels (repack_assets re-pads every clip of a rig from `<anim>_<dir>_<n>f.webp`; a fix that
only wrote `.rN.webp` is lost on the next repack).

    python sync_rig_sources.py <event> [<event> ...]
"""
from __future__ import annotations

import json
import re
import shutil
import sys

from build_v2_pack import ROOT


def sync(event: str) -> int:
    pack = json.loads((ROOT / event / "pack.json").read_text(encoding="utf-8"))
    n = 0
    for rig_name in ("girl", "npc"):
        rig = pack.get(rig_name) or {}
        folder = ROOT / event / rig_name
        for anim, dirs in rig.get("animations", {}).items():
            for direction, row in dirs.items():
                name = row["file"].split("/")[-1]
                live = folder / name
                plain = folder / re.sub(r"\.r\d+\.webp$", ".webp", name)
                if live.exists() and live != plain and plain.exists():
                    shutil.copyfile(live, plain)
                    n += 1
    return n


if __name__ == "__main__":
    for ev in sys.argv[1:]:
        print(ev, sync(ev), "clips synced")
