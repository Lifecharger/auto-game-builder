"""characters_sync.py - mirror character asset libraries into the R2 bucket
`idols` (served at https://idols.lifechargergames.com/).

Layout (one folder per character, public vs private):

    <character>/manifest.json                      mutable, 6h + SWR cache
    <character>/public/<category>/<id>.<sha8>.<ext> immutable, 90 days
    <character>/private/<category>/<id>.<sha8>.<ext>
    characters.json                                root index of characters

Keys carry a content hash, so a changed file gets a NEW key and the manifest
points at it - clients never rely on TTL expiry (cache standard 2026-08-10).
The manifest maps logical ids to keys, so games only ever hard-code
`<base>/<character>/manifest.json`.

Usage:
    python characters_sync.py                 # sync every character
    python characters_sync.py bella lumina    # only these
    python characters_sync.py --dry-run       # list what would upload
    python characters_sync.py --force         # re-upload even if state says done
    python characters_sync.py --masters       # also push the big source masters

Uploads go through `wrangler r2 object put` (OAuth login), one object per
call. Progress is remembered in state/characters_sync_state.json next to
this script so re-runs only push new hashes. The Cloudflare key is never
needed here; nothing secret is written to disk.
"""
from __future__ import annotations

import argparse
import glob
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

BUCKET = "idols"
PUBLIC_BASE = "https://idols.lifechargergames.com"
CACHE_IMMUTABLE = "public, max-age=7776000, immutable"
CACHE_MANIFEST = "public, max-age=21600, stale-while-revalidate=86400"
WRANGLER = (shutil.which("wrangler.cmd") or shutil.which("wrangler")
            or r"C:\Users\caca_\AppData\Roaming\npm\wrangler.cmd")
HERE = os.path.dirname(os.path.abspath(__file__))
STATE_PATH = os.path.join(HERE, "state", "characters_sync_state.json")

BELLA = r"C:\Reusable Assets\Anime Girls\Bella"
ADSC = r"C:\Projects\Anime Dance Streamer Clicker"

MIME = {".webp": "image/webp", ".png": "image/png", ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg", ".mp4": "video/mp4", ".json": "application/json",
        ".ogg": "audio/ogg"}


def group(scope: str, category: str, pattern: str, id_of=None, masters=False):
    """One upload group: files matching `pattern` -> <scope>/<category>/."""
    return {"scope": scope, "category": category, "pattern": pattern,
            "id_of": id_of or (lambda p: os.path.splitext(os.path.basename(p))[0]),
            "masters": masters}


RIVALS_LIB = r"C:\Reusable Assets\Anime Girls\Rivals"


def rival_groups(idol: str):
    """ADSC's five dance-battle rivals (task 114, 2026-09-19): ten outfit
    loops + stills and a room per rival, keyed by the game's
    tools/process_rivals.py into Rivals/<idol>/game/. Supersedes the old
    Lumina Live files (idle loop, public dance, sprites, 5 outfits)."""
    game = os.path.join(RIVALS_LIB, idol, "game")
    lib = os.path.join(RIVALS_LIB, idol, "masters")
    return [
        group("private", "outfits", os.path.join(game, "outfits", "*.webp")),
        group("private", "rooms", os.path.join(game, "rooms", "room.webp"),
              id_of=lambda p: "room"),
        # masters (big, optional)
        group("private", "masters/stills", os.path.join(lib, "stills", "*.jpg"), masters=True),
        group("private", "masters/videos", os.path.join(lib, "videos", "*.mp4"), masters=True),
        group("private", "masters/rooms", os.path.join(lib, "room.jpg"), masters=True),
    ]


# ADSC rival stories (task 115): 6 stories x 5 scenes, each a looping clip
# plus the scene still shown while it loads. Ids are "<story>_scene<N>" and
# "<story>_scene<N>_still" in bella's `private.stories`.
RIVAL_STORIES = ("01_lumina_crown", "02_nox_after_dark", "03_saffron_sunset_fest",
                 "04_kira_rematch", "05_vesper_midnight_frost", "06_five_crowns")

# ADSC music (task 129): `music_loop` stays inside the APK so audio starts on
# first launch with no network; these six stream and are cached on disk like
# the art. Ids are the file stems, which is what AudioService asks for.
ADSC_STREAMED_MUSIC = ("music_kawaii", "music_citypop", "music_idol",
                       "battle_edm", "battle_hyper", "battle_neon")


CHARACTERS = {
    "bella": {
        "game": "Anime Dance Streamer Clicker",
        "groups": [
            group("public", "base", os.path.join(BELLA, "base", "bella_base_cutout.png"),
                  id_of=lambda p: "base_cutout"),
            group("public", "base", os.path.join(BELLA, "base", "bella_app_icon.png"),
                  id_of=lambda p: "app_icon"),
            group("public", "cutouts", os.path.join(ADSC, "assets", "outfits_cutout", "*.webp")),
            group("public", "dances", os.path.join(ADSC, "assets", "dances", "*.webp")),
            # Task 89: the second, SULTRY loop per outfit. Never bundled in
            # the APK - the game streams these from `public/dances_sultry`,
            # so they live in the character library, not in assets/.
            group("public", "dances_sultry",
                  os.path.join(BELLA, "dances_sultry_loops", "*.webp")),
            group("public", "stills", os.path.join(ADSC, "assets", "outfits", "*.webp")),
            group("public", "rooms", os.path.join(ADSC, "assets", "rooms", "*.webp")),
            group("public", "icons", os.path.join(ADSC, "assets", "ui", "cloth", "*.png")),
            # prestige-gated Private Room story gallery (tasks 61, 82, 83).
            # One clip + one tile poster per level, per story; the poster id is
            # the clip id plus "_poster" so a client asks for it in the same
            # category. Adding a story = one more name in this list.
            *[g for story in ("beach", "shopping", "winter", "catninja", "gothic")
              for g in (
                  group("private", "gallery",
                        os.path.join(BELLA, "private_gallery", story, "*.mp4"),
                        id_of=(lambda p, s=story: s + "_" + os.path.splitext(os.path.basename(p))[0])),
                  group("private", "gallery",
                        os.path.join(BELLA, "private_gallery", story, "*_poster.webp"),
                        id_of=(lambda p, s=story: s + "_" + os.path.splitext(os.path.basename(p))[0])),
              )],
            # Campaign story plates (task 128): 73 WebP illustrations, one per
            # page. Only the opening chapter's three ship in the APK; the rest
            # stream from here, and the ids are the plate names story.json
            # already uses.
            group("private", "story",
                  os.path.join(ADSC, "assets", "story", "*.webp")),
            *[group("private", "music",
                    os.path.join(ADSC, "assets", "audio", t + ".ogg"))
              for t in ADSC_STREAMED_MUSIC],
            *[group("private", "stories",
                    os.path.join(BELLA, "stories", story, pattern),
                    id_of=(lambda p, s=story: s + "_" + os.path.splitext(os.path.basename(p))[0]))
              for story in RIVAL_STORIES
              for pattern in ("scene*.mp4", "scene*_still.webp")],
            # masters (big, optional)
            group("public", "masters/outfits", os.path.join(BELLA, "outfits", "*.png"), masters=True),
            group("public", "masters/outfits_chroma", os.path.join(BELLA, "outfits_chroma", "*.png"), masters=True),
            group("public", "masters/dances_480p", os.path.join(BELLA, "dances_chroma", "*.mp4"), masters=True),
            group("public", "masters/dances_720p", os.path.join(BELLA, "dances_chroma_hd", "*.mp4"), masters=True),
            group("public", "masters/dances_sultry_720p", os.path.join(BELLA, "dances_sultry_chroma_hd", "*.mp4"), masters=True),
            group("public", "masters/rooms", os.path.join(BELLA, "rooms", "r*.png"), masters=True),
        ],
    },
    **{idol: {"game": "Anime Dance Streamer Clicker", "groups": rival_groups(idol)}
       for idol in ("lumina", "nox", "saffron", "kira", "vesper")},
}


def sha1(path: str) -> str:
    h = hashlib.sha1()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def load_state() -> dict:
    if os.path.isfile(STATE_PATH):
        return json.load(open(STATE_PATH, encoding="utf-8"))
    return {"uploaded": {}}


def save_state(state: dict):
    os.makedirs(os.path.dirname(STATE_PATH), exist_ok=True)
    tmp = STATE_PATH + ".tmp"
    json.dump(state, open(tmp, "w", encoding="utf-8"), indent=1)
    os.replace(tmp, STATE_PATH)


def put(key: str, path: str, cache: str, dry: bool) -> bool:
    ext = os.path.splitext(path)[1].lower()
    cmd = [WRANGLER, "r2", "object", "put", f"{BUCKET}/{key}", "--remote",
           "--file", path, "--content-type", MIME.get(ext, "application/octet-stream"),
           "--cache-control", cache]
    if dry:
        print("  would put", key, f"({os.path.getsize(path)/1e6:.1f} MB)")
        return True
    for attempt in range(3):
        r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
        if r.returncode == 0:
            return True
        print(f"  retry {attempt + 1} for {key}: {(r.stderr or r.stdout).strip()[-200:]}")
        time.sleep(3)
    return False


def sync_character(name: str, spec: dict, state: dict, dry: bool, force: bool, masters: bool) -> dict:
    manifest = {"character": name, "game": spec["game"], "base": PUBLIC_BASE,
                "generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "public": {}, "private": {}}
    total = 0
    for g in spec["groups"]:
        if g["masters"] and not masters:
            continue
        files = sorted(glob.glob(g["pattern"]))
        for path in files:
            if os.path.getsize(path) == 0:
                print(f"  SKIP 0-byte {path}")
                continue
            digest = sha1(path)
            ext = os.path.splitext(path)[1].lower()
            logical = g["id_of"](path)
            key = f"{name}/{g['scope']}/{g['category']}/{logical}.{digest[:8]}{ext}"
            entry = {"key": key, "url": f"{PUBLIC_BASE}/{key}",
                     "bytes": os.path.getsize(path), "sha1": digest}
            manifest[g["scope"]].setdefault(g["category"], {})[logical] = entry
            # The key embeds the content hash, so "key already pushed" is proof.
            if not force and key in state["uploaded"]:
                continue
            ok = put(key, path, CACHE_IMMUTABLE, dry)
            if ok and not dry:
                state["uploaded"][key] = digest
                save_state(state)
                total += entry["bytes"]
                print(f"  {key}  {entry['bytes']/1e6:.1f} MB")
            elif not ok:
                print(f"  FAILED {key}")
    # manifest (mutable key, short cache)
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as tf:
        json.dump(manifest, tf, indent=1)
        tmp = tf.name
    try:
        put(f"{name}/manifest.json", tmp, CACHE_MANIFEST, dry)
    finally:
        os.unlink(tmp)
    n = sum(len(v) for scope in ("public", "private") for v in manifest[scope].values())
    print(f"{name}: {n} assets in manifest, uploaded {total/1e6:.1f} MB this run")
    return manifest


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("characters", nargs="*")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--masters", action="store_true", help="also upload source masters")
    a = ap.parse_args()
    names = a.characters or list(CHARACTERS)
    state = load_state()
    index = {"base": PUBLIC_BASE, "characters": {}}
    for name in names:
        spec = CHARACTERS[name]
        print(f"== {name} ({spec['game']})")
        m = sync_character(name, spec, state, a.dry_run, a.force, a.masters)
        index["characters"][name] = {"game": spec["game"], "manifest": f"{PUBLIC_BASE}/{name}/manifest.json",
                                     "public_categories": sorted(m["public"]),
                                     "private_categories": sorted(m["private"])}
    if not a.characters:  # full run: refresh the root index too
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as tf:
            json.dump(index, tf, indent=1)
            tmp = tf.name
        try:
            put("characters.json", tmp, CACHE_MANIFEST, a.dry_run)
        finally:
            os.unlink(tmp)
    print("done")


if __name__ == "__main__":
    sys.exit(main())
