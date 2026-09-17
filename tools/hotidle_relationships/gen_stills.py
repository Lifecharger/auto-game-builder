"""Hot Idle Relationships: level stills for every cashier (design/relationships.md 9).

Runs every image through the AGB generate API (task ``edit_qwen`` = Qwen Image
Edit 2511 turbo), so each job holds the GPU lane and shows up in the Sira
screen like any other production job. Resume-safe: a level whose master PNG
already exists is skipped, so the script can be re-run after a crash or to
fill in rejected levels (delete the PNG, re-run).

    python gen_stills.py                 # all 15 girls, levels 2-10
    python gen_stills.py ava luna        # only these girls
    python gen_stills.py ava --levels 7,8,9,10
    python gen_stills.py --sheet         # contact sheet(s) only, no generation
    python gen_stills.py --scenes        # portrait paintings: L<n>.png -> L<n>_scene.png
    python gen_stills.py --loops         # LTX-2.5 loops: L<n>.png -> L<n>_loop.mp4 (levels 2-10)

Masters land in  C:/Reusable Assets/Images/Hot Idle/relationships/<girl>/L<n>.png
Scene portraits   .../<girl>/L<n>_scene.png  (the painting the player paints and hangs;
                  same outfit, set in ladders.json scenes[level]; user 2026-09-14)
Contact sheets in C:/Reusable Assets/Images/Hot Idle/relationships/_sheets/<girl>.jpg
"""
from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import random
import shutil
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
API = "http://localhost:8000"
KEY_FILE = r"D:/keys/agb_api_key.txt"
REFS = r"C:/Reusable Assets/Images/Hot Idle/cashiers_side/refs"
DEST = r"C:/Reusable Assets/Images/Hot Idle/relationships"
TASK = "edit_qwen"
LOOP_TASK = "video_ltx_flf"      # LTX-2.5 first frame = last frame -> seamless loop
LOOP_W, LOOP_H, LOOP_SECONDS = 704, 1280, 6

# The ten frames of the collection wall (Hot Idle lib/screens/
# collection_gallery_screen.dart kCollectionFrameRects, fractions of the
# 720x1280 room). Level n hangs in frame n. Portraits and their living loops
# are generated AT THE FRAME'S ASPECT (user 2026-09-16: "do generation best
# per frame, and animate per frame too"), so the wall shows the whole picture
# with BoxFit.cover and nothing is cropped or left bare. Frames 6, 7 and 10
# are landscape.
FRAME_RECTS = [
    (0.0806, 0.1656, 0.2542, 0.2961), (0.4028, 0.1742, 0.6000, 0.3180),
    (0.7514, 0.1508, 0.9306, 0.2812), (0.0722, 0.3695, 0.2653, 0.5062),
    (0.4042, 0.4047, 0.6000, 0.5437), (0.7431, 0.3578, 0.9306, 0.4414),
    (0.7347, 0.5078, 0.9431, 0.6117), (0.0764, 0.5758, 0.2667, 0.7047),
    (0.4000, 0.6227, 0.6028, 0.7664), (0.7333, 0.6781, 0.9472, 0.7828),
]


# Measured from the transparent openings of collection_gallery_bg.png itself
# (alpha < 8, connected components, 2026-09-16): width x height in px. They
# agree with FRAME_RECTS within 1 px; these are the exact targets.
FRAME_OPENINGS = [(126, 167), (143, 185), (129, 168), (140, 176), (142, 179),
                  (136, 108), (151, 134), (138, 165), (146, 185), (155, 135)]


_ORDER: dict | None = None


def delivered_level(girl: str, gen_level: int) -> int:
    """File numbers are generation numbers; the wall level comes from
    order.json (delivered level -> source key, 'base' = the L1 files). The
    frame shape, gesture and heat all belong to the DELIVERED level."""
    global _ORDER
    if _ORDER is None:
        with open(os.path.join(HERE, "order.json"), encoding="utf-8") as f:
            _ORDER = json.load(f)["order"]
    key = "base" if gen_level == 1 else f"L{gen_level}"
    keys = _ORDER.get(girl)
    return keys.index(key) + 1 if keys and key in keys else gen_level


def frame_aspect(level: int) -> float:
    w, h = FRAME_OPENINGS[level - 1]
    return w / h


def _fit(aspect: float, long_side: int, step: int) -> tuple[int, int]:
    """(w, h) with the long side fixed and the short side rounded to `step`."""
    if aspect < 1:
        return max(step, round(long_side * aspect / step) * step), long_side
    return long_side, max(step, round(long_side / aspect / step) * step)


def scene_size(level: int) -> tuple[int, int]:
    """Qwen output for the level's painting: long side 1392, multiples of 16."""
    return _fit(frame_aspect(level), 1392, 16)


def scene_loop_size(level: int) -> tuple[int, int]:
    """MiniMax H3 size for the level's living portrait: multiples of 32, long
    side 864 (the H3 Kart preset is 576x864), at the frame's aspect."""
    return _fit(frame_aspect(level), 864, 32)


def scene_canvas(src: str, level: int, dst: str) -> str:
    """Input for the level's portrait: the still on a white canvas at the
    frame's size. The Qwen edit workflow keeps the input size, so this is
    how the output gets the frame's aspect. Portrait frames take the whole
    figure; landscape frames take the upper 62 % of the still (head to upper
    thigh) enlarged, so she stays big in a small wide frame."""
    from PIL import Image
    w, h = scene_size(level)
    im = Image.open(src).convert("RGB")
    if frame_aspect(level) > 1:
        im = im.crop((0, 0, im.width, round(im.height * 0.62)))
    scale = h / im.height
    im = im.resize((round(im.width * scale), h), Image.LANCZOS)
    if im.width > w:
        left = (im.width - w) // 2
        im = im.crop((left, 0, left + w, h))
    canvas = Image.new("RGB", (w, h), (255, 255, 255))
    canvas.paste(im, ((w - im.width) // 2, 0))
    canvas.save(dst)
    return dst


def shape_hint(level: int) -> str:
    return ("a wide landscape composition, her upper body or three-quarter figure with the "
            "place visible around her" if frame_aspect(level) > 1
            else "a three-quarter or full body composition")
CLIENT = "hotidle-relationships"

# No negative prompt (user rule 2026-09-14): with the turbo LoRA the edit runs at
# CFG 1, so negatives do nothing; everything the picture must hold is said
# positively in FRAME.
NEGATIVE = ""

FRAME = ("Full body standing pose facing the camera, feet visible, centred, plain pure "
         "white studio background, soft even studio lighting, photorealistic, sharp, "
         "high detail. Adult woman with natural light makeup and natural skin tone on her cheeks. Keep the exact {identity}, same body proportions and "
         "the same framing. Change only her clothes, pose and expression.")


def _key() -> str:
    env = os.environ.get("AGB_API_KEY")
    if env:
        return env.strip()
    try:
        with open(KEY_FILE, encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        sys.exit("AGB API key: set AGB_API_KEY or create " + KEY_FILE)


def _req(method: str, path: str, payload: dict | None = None) -> dict:
    data = json.dumps(payload).encode() if payload is not None else None
    r = urllib.request.Request(API + path, data=data, method=method, headers={
        "Content-Type": "application/json", "X-API-Key": _key()})
    with urllib.request.urlopen(r, timeout=120) as resp:
        return json.loads(resp.read())


def is_base_level(girl: str, level: int, bank: dict) -> bool:
    """'__base__' in ladders.json = the original cashier outfit (post-rename)."""
    return bank["girls"][girl]["levels"].get(str(level)) == "__base__"


def prompt_for(girl: str, level: int, bank: dict) -> str:
    g = bank["girls"][girl]
    outfit = g["levels"][str(level)]
    expression = bank["expression"][str(level)]
    return (f"She now wears {outfit}. Her expression: {expression}. "
            + FRAME.format(identity=g["identity"]))


SCENE = ("Place her in {scene}; the scene fills the whole picture edge to edge, no white "
         "areas remain. She keeps the exact same outfit, the exact {identity}, same hair and "
         "body. Her expression: {expression}. She is the centre of {shape}, looking at the "
         "camera. Photorealistic, cinematic natural lighting, rich detail, a finished "
         "portrait photograph.")


def scene_prompt_for(girl: str, level: int, bank: dict) -> str:
    g = bank["girls"][girl]
    return SCENE.format(scene=g["scenes"][str(level)], identity=g["identity"],
                        expression=bank["expression"][str(level)],
                        shape=shape_hint(delivered_level(girl, level)))


LOOP = ("{motion} Photorealistic video of the same woman in the same outfit, plain white "
        "studio background, full body in frame, smooth natural motion, soft even studio "
        "lighting, she is constantly in motion.")


MOTION_OVERRIDE: str | None = None   # --motion: one-off text for a redo


def loop_prompt_for(level: int, bank: dict) -> str:
    return LOOP.format(motion=MOTION_OVERRIDE or bank["motion"][str(level)])


# Living portraits (user 2026-09-16: "start making videos of all the drawings,
# complete freedom"): every portrait painting gets a gentle 6 s loop, first and
# last frame = the painting, so it hangs in her collection window and breathes.
# The camera never moves (a painting does not zoom), she stays in her pose and
# only small things live: breath, hair, fabric, a glance, and the scene's own
# ambience (waves, city lights, leaves).
# v2 (same day): the first batch had almost no visible motion once shown in
# a small wall frame. Now: no loop anchor (plain image-to-video) and the same
# big, clearly visible whole-body motion as the outfit loops (ladders.json
# motion bank), set in the scene, with the scene's ambience alive.
SCENE_LOOP = ("{motion} {spice}Photorealistic video of the same woman in the same outfit in "
              "{scene}. Natural, relaxed, lifelike movement: she shifts her weight, sways a "
              "little, touches her hair, her expression changes as she looks at the camera; "
              "the camera drifts slowly; {ambience}. Cinematic lighting, high detail.")

# v3 (user: "we dont need big motion... be normal"): natural motion, the
# level's gesture from the motion bank, with the "always in motion" pushes
# stripped, and a light touch of heat at the top levels.
SCENE_SPICE = {
    "7": "Flirty and playful. ",
    "8": "Sensual, with an inviting look. ",
    "9": "Seductive: a slow sensual sway, a smouldering gaze. ",
    "10": "Very seductive: a slow, sexy dance for the camera, smouldering eye contact. ",
}
SCENE_TASK = "video_minimax"   # MiniMax H3 image-to-video (user 2026-09-16: "go for minimax route for all"), first frame only, no loop

SCENE_GESTURE = {
    "1": "she glances at the viewer and gives a small polite smile.",
    "2": "she looks up at the viewer with a warm smile and a slight tilt of the head.",
    "3": "she smiles playfully at the viewer and tucks a strand of hair behind her ear.",
    "4": "she gives the viewer a slow, confident smile.",
    "5": "she holds the viewer's gaze with a knowing half-smile.",
    "6": "she turns her eyes to the viewer with a soft, inviting smile.",
    "7": "she gives the viewer a slow wink and a teasing smile.",
    "8": "she holds a lingering, flirtatious gaze on the viewer, lips slightly parted.",
    "9": "she slowly runs a hand through her hair, sultry gaze locked on the viewer.",
    "10": "she gives the viewer a slow, sultry look and a faint smile, breathing slowly.",
}

_AMBIENCE = [
    (("wave", "beach", "sea", "ocean", "yacht"), "waves roll and sparkle gently behind her"),
    (("pool", "water"), "the water ripples and glints softly"),
    (("night", "city lights", "rooftop", "neon"), "city lights twinkle softly in the distance"),
    (("casino", "spotlight", "stage", "club"), "soft spotlights drift slowly across the room"),
    (("courtyard", "garden", "park", "forest", "tree"), "leaves drift slowly in the air"),
    (("golden hour", "sunset", "sunrise", "window"), "warm light shifts slowly across the scene"),
    (("rain",), "rain streaks slowly down the glass"),
    (("snow", "winter"), "snowflakes drift slowly down"),
    (("fire", "candle", "lantern"), "candlelight flickers softly"),
]


def scene_loop_prompt_for(girl: str, level: int, bank: dict) -> str:
    scene = bank["girls"][girl]["scenes"][str(level)]
    low = scene.lower()
    ambience = "the light in the scene shifts very slowly"
    for keys, text in _AMBIENCE:
        if any(k in low for k in keys):
            ambience = text
            break
    # the motion bank starts at level 2 (level 1 used to be the bundled desk loop)
    motion = MOTION_OVERRIDE or bank["motion"].get(str(level)) or (
        "She greets the camera with a small wave and a polite smile, then stands relaxed, "
        "shifting her weight and glancing around the room.")
    for push in (", always in motion", " always in motion", ", hips never still", ", constantly in motion",
                 "constantly in motion, ", "she is constantly in motion"):
        motion = motion.replace(push, "")
    return SCENE_LOOP.format(motion=motion,
                             spice=SCENE_SPICE.get(str(delivered_level(girl, level)), ""),
                             scene=scene, ambience=ambience)


def generate_scene_loop(girl: str, level: int, bank: dict, seed: int | None = None) -> str | None:
    """L<n>_scene.png -> L<n>_scene_loop.mp4 (living portrait, at the frame's aspect)."""
    out_dir = os.path.join(DEST, girl)
    return _render_loop(girl, f"L{level}_scene_loop", os.path.join(out_dir, f"L{level}_scene.png"),
                        scene_loop_prompt_for(girl, level, bank), seed,
                        size=scene_loop_size(delivered_level(girl, level)), task=SCENE_TASK)


def generate_loop(girl: str, level: int, bank: dict, seed: int | None = None,
                  base: bool = False) -> str | None:
    """One LTX-2.5 loop from the level still: first and last frame are the still
    itself so the clip closes on itself (user 2026-09-14: dance, wink, whatever).

    base=True re-renders the ORIGINAL cashier outfit (user 2026-09-15: the old
    180x320 desk loops are too small): source = her reference photo, motion =
    the level that outfit now occupies in order.json, output base_loop.mp4."""
    out_dir = os.path.join(DEST, girl)
    tag = "base_loop" if base else f"L{level}_loop"
    still = (os.path.join(out_dir, "base.png") if base
             else os.path.join(out_dir, f"L{level}.png"))
    return _render_loop(girl, tag, still, loop_prompt_for(level, bank), seed)


def _render_loop(girl: str, tag: str, still: str, prompt: str, seed: int | None = None,
                 size: tuple[int, int] = (LOOP_W, LOOP_H), task: str = LOOP_TASK) -> str | None:
    """LTX-2.5 first frame = last frame render of `still` -> <girl>/<tag>.mp4."""
    out_dir = os.path.join(DEST, girl)
    dst = os.path.join(out_dir, f"{tag}.mp4")
    if os.path.isfile(dst):
        print(f"  {girl} {tag}: var, atlandi", flush=True)
        return dst
    if not os.path.isfile(still):
        print(f"  {girl} {tag}: still yok, once still uret", flush=True)
        return None
    seed = seed or random.randint(1, 2**31 - 1)
    try:
        payload = {
            "task": task, "prompt": prompt,
            "negative": "", "seed": seed, "turbo": True,
            "width": size[0], "height": size[1], "duration": LOOP_SECONDS,
            "client": CLIENT, "mode": "free",
        }
        if task == LOOP_TASK:
            payload["inputs"] = {"image_1": {"path": still}, "image_2": {"path": still}}
        else:
            payload["image_path"] = still
        job = _req("POST", "/api/generate", payload)
    except urllib.error.HTTPError as e:
        print(f"  {girl} {tag}: gonderim hatasi {e.code} {e.read().decode()[:300]}", flush=True)
        return None
    jid = job.get("id") or job.get("job", {}).get("id")
    t0 = time.time()
    print(f"  {girl} {tag}: kuyrukta {jid} (seed {seed})", flush=True)
    while True:
        time.sleep(10)
        try:
            j = _req("GET", f"/api/generate/{jid}")
        except (urllib.error.URLError, OSError):
            continue
        st = j.get("status")
        if st == "done" and j.get("file") and os.path.isfile(j["file"]):
            shutil.copy(j["file"], dst)
            print(f"  {girl} {tag}: TAMAM {time.time() - t0:.0f}s -> {dst}", flush=True)
            return dst
        if st in ("error", "cancelled"):
            print(f"  {girl} {tag}: {st} {j.get('error')}", flush=True)
            return None
        if time.time() - t0 > 3 * 3600:
            print(f"  {girl} {tag}: zaman asimi", flush=True)
            return None


BASE_REDO = ("Recreate this exact photo at high resolution: the same woman, the exact "
             "{identity}, wearing exactly the same outfit, same pose, same framing, plain "
             "pure white studio background, soft even studio lighting, photorealistic, "
             "sharp, high detail. Adult woman with natural light makeup. Change nothing.")


def generate_base_still(girl: str, bank: dict, seed: int | None = None) -> str | None:
    """Sharp full-size re-render of the ORIGINAL outfit (user 2026-09-15: the
    540x960 reference is an upscale of a 180x320 frame). Output base.png; it is
    then the source for base_cut.png and base_loop.mp4."""
    out_dir = os.path.join(DEST, girl)
    os.makedirs(out_dir, exist_ok=True)
    dst = os.path.join(out_dir, "base.png")
    if os.path.isfile(dst):
        print(f"  {girl} base: var, atlandi", flush=True)
        return dst
    ref = os.path.join(REFS, f"{girl}_ref.jpg")
    seed = seed or random.randint(1, 2**31 - 1)
    prompt = BASE_REDO.format(identity=bank["girls"][girl]["identity"])
    try:
        job = _req("POST", "/api/generate", {
            "task": TASK, "prompt": prompt, "negative": "", "seed": seed, "turbo": True,
            "width": 752, "height": 1392,
            "image_path": ref, "client": CLIENT, "mode": "free"})
    except urllib.error.HTTPError as e:
        print(f"  {girl} base: gonderim hatasi {e.code} {e.read().decode()[:300]}", flush=True)
        return None
    jid = job.get("id") or job.get("job", {}).get("id")
    t0 = time.time()
    print(f"  {girl} base: kuyrukta {jid} (seed {seed})", flush=True)
    while True:
        time.sleep(5)
        try:
            j = _req("GET", f"/api/generate/{jid}")
        except (urllib.error.URLError, OSError):
            continue
        st = j.get("status")
        if st == "done" and j.get("file") and os.path.isfile(j["file"]):
            shutil.copy(j["file"], dst)
            print(f"  {girl} base: TAMAM {time.time() - t0:.0f}s -> {dst}", flush=True)
            return dst
        if st in ("error", "cancelled"):
            print(f"  {girl} base: {st} {j.get('error')}", flush=True)
            return None
        if time.time() - t0 > 4 * 3600:
            print(f"  {girl} base: zaman asimi", flush=True)
            return None


def generate(girl: str, level: int, bank: dict, seed: int | None = None,
             scene: bool = False) -> str | None:
    """One still (white background) or, with scene=True, the portrait painting
    made FROM that still so the outfit and face carry over exactly."""
    out_dir = os.path.join(DEST, girl)
    os.makedirs(out_dir, exist_ok=True)
    tag = f"L{level}_scene" if scene else f"L{level}"
    dst = os.path.join(out_dir, f"{tag}.png")
    if os.path.isfile(dst):
        print(f"  {girl} {tag}: var, atlandi", flush=True)
        return dst
    if scene:
        # Since the 2026-09-16 rename every level's portrait comes from its own
        # still, L<n>.png (the original outfit is a re-rendered still too).
        ref = os.path.join(out_dir, f"L{level}.png")
        if not os.path.isfile(ref):
            print(f"  {girl} {tag}: still yok, once still uret", flush=True)
            return None
        prompt = scene_prompt_for(girl, level, bank)
        # per-frame canvas (2026-09-16): the edit keeps the input's size
        ref = scene_canvas(ref, delivered_level(girl, level), os.path.join(out_dir, f"_canvas_L{level}.png"))
    else:
        ref = os.path.join(REFS, f"{girl}_ref.jpg")
        if not os.path.isfile(ref):
            print(f"  {girl}: referans yok ({ref})", flush=True)
            return None
        prompt = prompt_for(girl, level, bank)
    seed = seed or random.randint(1, 2**31 - 1)
    try:
        payload = {
            "task": TASK, "prompt": prompt,
            "negative": NEGATIVE, "seed": seed, "turbo": True,
            "image_path": ref, "client": CLIENT, "mode": "free",
        }
        job = _req("POST", "/api/generate", payload)
    except urllib.error.HTTPError as e:
        print(f"  {girl} {tag}: gonderim hatasi {e.code} {e.read().decode()[:300]}", flush=True)
        return None
    jid = job.get("id") or job.get("job", {}).get("id")
    t0 = time.time()
    print(f"  {girl} {tag}: kuyrukta {jid} (seed {seed})", flush=True)
    while True:
        time.sleep(5)
        try:
            j = _req("GET", f"/api/generate/{jid}")
        except (urllib.error.URLError, OSError):
            continue
        st = j.get("status")
        if st == "done" and j.get("file") and os.path.isfile(j["file"]):
            shutil.copy(j["file"], dst)
            if scene:
                # Qwen snaps to ~1 MP on a 16 px grid; make the ratio exact.
                import importlib.util as _ilu
                _sp = _ilu.spec_from_file_location("crop_scenes", os.path.join(HERE, "crop_scenes.py"))
                _cs = _ilu.module_from_spec(_sp); _sp.loader.exec_module(_cs)
                _cs.crop_to_frame(dst, delivered_level(girl, level))
            print(f"  {girl} {tag}: TAMAM {time.time() - t0:.0f}s -> {dst}", flush=True)
            return dst
        if st in ("error", "cancelled"):
            print(f"  {girl} {tag}: {st} {j.get('error')}", flush=True)
            return None
        # The lane is shared: a job can sit an hour behind another client's
        # batch before it even starts, so the wait is generous (4 h).
        if time.time() - t0 > 4 * 3600:
            print(f"  {girl} {tag}: zaman asimi", flush=True)
            return None


def contact_sheet(girl: str, scene: bool = False) -> str | None:
    from PIL import Image, ImageDraw
    cells = []
    ref = os.path.join(REFS, f"{girl}_ref.jpg")
    if os.path.isfile(ref) and not scene:
        cells.append(("L1", ref))
    for level in range(1 if scene else 2, 11):
        p = os.path.join(DEST, girl, f"L{level}{'_scene' if scene else ''}.png")
        if os.path.isfile(p):
            cells.append((f"L{level}{' scene' if scene else ''}", p))
    if not cells:
        return None
    w, h = 300, 534
    sheet = Image.new("RGB", (w * 5, (h + 24) * 2), "white")
    dr = ImageDraw.Draw(sheet)
    for i, (label, p) in enumerate(cells):
        im = Image.open(p).convert("RGB")
        im.thumbnail((w, h))
        x, y = (i % 5) * w, (i // 5) * (h + 24)
        sheet.paste(im, (x + (w - im.width) // 2, y + 24))
        dr.text((x + 6, y + 5), f"{girl} {label}", fill="black")
    out_dir = os.path.join(DEST, "_sheets")
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, f"{girl}{'_scenes' if scene else ''}.jpg")
    sheet.save(out, quality=88)
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("girls", nargs="*")
    ap.add_argument("--levels", default="2,3,4,5,6,7,8,9,10")
    ap.add_argument("--sheet", action="store_true", help="contact sheets only")
    ap.add_argument("--scenes", action="store_true",
                    help="portrait paintings from the stills (L<n>.png -> L<n>_scene.png)")
    ap.add_argument("--loops", action="store_true",
                    help="LTX-2.5 loops from the stills (L<n>.png -> L<n>_loop.mp4)")
    ap.add_argument("--base-stills", action="store_true",
                    help="sharp full-size re-render of the original outfit (reference -> base.png)")
    ap.add_argument("--scene-loops", action="store_true",
                    help="living portraits: LTX-2.5 loops from the paintings (L<n>_scene.png -> L<n>_scene_loop.mp4)")
    ap.add_argument("--base-loops", action="store_true",
                    help="re-render the original outfit loops (reference -> base_loop.mp4)")
    ap.add_argument("--motion", default="",
                    help="override the motion text for this run (redo of one clip)")
    ap.add_argument("--inflight", type=int, default=4,
                    help="jobs kept queued at once. The lane is FIFO and shared: a "
                         "one-at-a-time submitter gets one slot per batch another "
                         "client dumps in, so we keep a few queued too (default 4)")
    a = ap.parse_args()
    global MOTION_OVERRIDE
    MOTION_OVERRIDE = a.motion or None
    with open(os.path.join(HERE, "ladders.json"), encoding="utf-8") as f:
        bank = json.load(f)
    girls = a.girls or list(bank["girls"])
    levels = [int(x) for x in a.levels.split(",") if x.strip()]
    if (a.scenes or a.scene_loops) and a.levels == "2,3,4,5,6,7,8,9,10":
        levels = [1] + levels          # portraits exist for level 1 too
    if a.sheet:
        for g in girls:
            print(contact_sheet(g, scene=a.scenes))
        return
    if a.base_stills:
        with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, a.inflight)) as pool:
            res = list(pool.map(lambda g: generate_base_still(g, bank), girls))
        print("BITTI; basarisiz:", [g for g, r in zip(girls, res) if r is None] or "yok", flush=True)
        return
    if a.base_loops:
        with open(os.path.join(HERE, "order.json"), encoding="utf-8") as f:
            ranking = json.load(f)["order"]
        jobs_b = [(g, ranking[g].index("base") + 1) for g in girls]
        print(f"{len(jobs_b)} base loops (inflight {a.inflight})", flush=True)
        with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, a.inflight)) as pool:
            res = list(pool.map(lambda j: generate_loop(j[0], j[1], bank, base=True), jobs_b))
        print("BITTI; basarisiz:", [f"{g} base" for (g, _), r in zip(jobs_b, res) if r is None] or "yok",
              flush=True)
        return
    print(f"{len(girls)} kiz x {len(levels)} seviye -> {DEST} (inflight {a.inflight})",
          flush=True)
    failed: list[str] = []

    def one(girl: str, lv: int) -> str | None:
        if a.scene_loops:
            return None if generate_scene_loop(girl, lv, bank) is None else "ok"
        if a.loops:
            return None if generate_loop(girl, lv, bank) is None else "ok"
        return None if generate(girl, lv, bank, scene=a.scenes) is None else "ok"

    # A few jobs stay queued at once so the shared FIFO lane alternates between
    # us and other clients instead of starving the one-at-a-time submitter.
    jobs = [(g, lv) for g in girls for lv in levels]
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, a.inflight)) as pool:
        results = {pool.submit(one, g, lv): (g, lv) for g, lv in jobs}
        for fut in concurrent.futures.as_completed(results):
            g, lv = results[fut]
            if fut.result() is None:
                failed.append(f"{g} L{lv}{' loop' if a.loops else ''}")
    for g in (girls if not a.scene_loops else []):
        sheet = contact_sheet(g, scene=a.scenes)
        if sheet:
            print(f"  {g}: kontak sayfasi {sheet}", flush=True)
    print("BITTI; basarisiz:", failed or "yok", flush=True)


if __name__ == "__main__":
    main()
