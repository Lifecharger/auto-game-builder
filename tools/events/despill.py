"""Make green-dominant pixels transparent in one live pack asset (effects whose own colour
is not green but that came back with green blobs). python despill.py <event> <key> [...]"""
import io, json, re, sys
import numpy as np
from PIL import Image
sys.path.insert(0, "C:/Projects/Auto Game Builder/tools/r2")
import r2_s3
from build_v2_pack import BUCKET, CACHE_IMG, CACHE_JSON, MIRROR, ROOT
from pack_lock import pack_lock

event, keys = sys.argv[1], sys.argv[2:]
with pack_lock(event):
    pack = json.loads(r2_s3.get_object(BUCKET, f"minigames/v2/{event}/pack.json"))
    base = pack["base"]
    rev = max(int(m) for m in re.findall(r"\.r(\d+)\.webp", json.dumps(pack))) + 1
    for key in keys:
        row = pack["assets"][key]
        im = Image.open(io.BytesIO(r2_s3.get_object(BUCKET, row["file"]))).convert("RGBA")
        a = np.asarray(im).astype(np.int32)
        r, g, b = a[..., 0], a[..., 1], a[..., 2]
        green = (g > r + 30) & (g > b + 30)
        a[..., 3] = np.where(green, 0, a[..., 3])
        # soften: pull remaining green tint toward gold
        out = Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")
        name = f"{key}.r{rev}.webp"
        dst = ROOT / event / name
        out.save(dst, "WEBP", quality=88, method=6)
        row["file"] = base + name
        row["bytes"] = dst.stat().st_size
        r2_s3._call("PUT", BUCKET, base + name, headers={"content-type": "image/webp", "cache-control": CACHE_IMG}, body=dst.read_bytes())
        print(key, "cleaned", green.mean().round(3))
    pack["version"] += 1
    body = json.dumps(pack, ensure_ascii=False, indent=1).encode()
    (ROOT / event / "pack.json").write_bytes(body)
    r2_s3._call("PUT", BUCKET, base + "pack.json", headers={"content-type": "application/json", "cache-control": CACHE_JSON}, body=body)
    print("pack v", pack["version"])
