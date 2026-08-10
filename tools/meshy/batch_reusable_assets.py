"""
Batch-generate generic reusable 3D assets (text-to-3D preview + refine)
into C:\\Reusable Assets\\3D Models\\Meshy\\<category>\\<slug>.glb

Resume-safe: progress tracked in manifest.json next to the output.
Stops gracefully when Meshy credits run out.

Usage:
  python batch_reusable_assets.py            # run everything pending
  python batch_reusable_assets.py --limit 1  # smoke test (first pending item)
"""

import argparse
import json
import sys
import time
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).parent))
from meshy_client import API_BASE, get_api_key, download_model  # noqa: E402

OUTPUT_ROOT = Path(r"C:\Reusable Assets\3D Models\Meshy")
MANIFEST = OUTPUT_ROOT / "manifest.json"
ENDPOINT = f"{API_BASE}/openapi/v2/text-to-3d"
WAVE_SIZE = 5
POLL_INTERVAL = 15
TASK_TIMEOUT = 2400  # per task, seconds

STYLE = "stylized low-poly cartoon game asset, vibrant colors, clean silhouette, single object on plain background"

# (category, slug, description)
ASSETS = [
    # --- nature (30) ---
    ("nature", "oak_tree", "large oak tree with round leafy green canopy and thick trunk"),
    ("nature", "pine_tree", "tall pine tree with layered conical dark green foliage"),
    ("nature", "palm_tree", "tropical palm tree with curved trunk and fan leaves"),
    ("nature", "birch_tree", "slender birch tree with white bark and light green leaves"),
    ("nature", "dead_tree", "bare dead tree with twisted leafless branches"),
    ("nature", "willow_tree", "weeping willow tree with long drooping branches"),
    ("nature", "snowy_pine", "pine tree covered in white snow"),
    ("nature", "autumn_maple", "maple tree with orange and red autumn leaves"),
    ("nature", "cactus", "tall saguaro desert cactus with two arms"),
    ("nature", "bamboo_clump", "clump of green bamboo stalks with leaves"),
    ("nature", "bush", "round green garden bush"),
    ("nature", "flowering_bush", "green bush with pink flowers"),
    ("nature", "rock_boulder", "large round gray rock boulder"),
    ("nature", "rock_cluster", "cluster of three gray rocks of different sizes"),
    ("nature", "mossy_rock", "gray rock covered with green moss patches"),
    ("nature", "crystal_cluster", "cluster of glowing purple crystal shards growing from rock"),
    ("nature", "ice_rock", "jagged blue ice boulder"),
    ("nature", "tree_stump", "cut tree stump with visible growth rings"),
    ("nature", "fallen_log", "fallen tree log with moss"),
    ("nature", "mushroom_red", "red mushroom with white spots"),
    ("nature", "mushroom_cluster", "cluster of small brown mushrooms"),
    ("nature", "flower_patch", "patch of colorful wildflowers with green leaves"),
    ("nature", "sunflower", "tall sunflower with big yellow bloom"),
    ("nature", "grass_tuft", "tuft of green grass blades"),
    ("nature", "fern", "green fern plant with arching fronds"),
    ("nature", "cattail_reeds", "cluster of cattail reeds with brown tops"),
    ("nature", "vine_plant", "climbing green vine plant on a small trellis"),
    ("nature", "potted_plant", "leafy green plant in a terracotta pot"),
    ("nature", "hay_bale", "round golden hay bale"),
    ("nature", "pumpkin", "plump orange pumpkin with green stem"),
    # --- vehicles (26) ---
    ("vehicles", "sedan_car", "compact sedan car with rounded friendly proportions"),
    ("vehicles", "sports_car", "sleek red sports car"),
    ("vehicles", "taxi", "yellow taxi cab with roof sign"),
    ("vehicles", "police_car", "black and white police car with light bar"),
    ("vehicles", "ambulance", "white ambulance van with red cross"),
    ("vehicles", "fire_truck", "red fire truck with ladder"),
    ("vehicles", "school_bus", "yellow school bus"),
    ("vehicles", "city_bus", "blue city bus"),
    ("vehicles", "pickup_truck", "sturdy pickup truck with open bed"),
    ("vehicles", "delivery_van", "white delivery van"),
    ("vehicles", "semi_truck", "semi truck cab with cargo trailer"),
    ("vehicles", "garbage_truck", "green garbage truck"),
    ("vehicles", "tractor", "red farm tractor with big rear wheels"),
    ("vehicles", "forklift", "yellow warehouse forklift"),
    ("vehicles", "motorcycle", "sport motorcycle"),
    ("vehicles", "scooter", "cute retro scooter"),
    ("vehicles", "bicycle", "classic bicycle with basket"),
    ("vehicles", "go_kart", "small racing go-kart"),
    ("vehicles", "rowboat", "small wooden rowboat with oars"),
    ("vehicles", "sailboat", "sailboat with white sail"),
    ("vehicles", "speedboat", "sleek speedboat"),
    ("vehicles", "fishing_boat", "small fishing boat with cabin"),
    ("vehicles", "helicopter", "compact helicopter"),
    ("vehicles", "small_airplane", "small propeller airplane"),
    ("vehicles", "hot_air_balloon", "colorful striped hot air balloon with basket"),
    ("vehicles", "train_locomotive", "vintage steam train locomotive"),
    # --- buildings (25) ---
    ("buildings", "small_house", "cozy small house with red roof and chimney"),
    ("buildings", "cottage", "stone cottage with thatched roof"),
    ("buildings", "two_story_house", "two story suburban house with garage"),
    ("buildings", "apartment_building", "five story apartment building with balconies"),
    ("buildings", "skyscraper", "modern glass skyscraper tower"),
    ("buildings", "office_building", "mid-rise office building"),
    ("buildings", "shop_storefront", "small shop with striped awning and display window"),
    ("buildings", "cafe", "cozy corner cafe with outdoor sign"),
    ("buildings", "bakery", "bakery shop with bread sign"),
    ("buildings", "gas_station", "gas station with canopy and pumps"),
    ("buildings", "barn", "red farm barn with white trim"),
    ("buildings", "windmill", "old stone windmill with wooden blades"),
    ("buildings", "lighthouse", "red and white striped lighthouse"),
    ("buildings", "castle_tower", "medieval stone castle tower with battlements"),
    ("buildings", "castle_gate", "medieval castle gatehouse with wooden gate"),
    ("buildings", "medieval_house", "medieval half-timbered house"),
    ("buildings", "church", "small church with steeple"),
    ("buildings", "school_building", "brick school building with clock"),
    ("buildings", "hospital", "hospital building with red cross sign"),
    ("buildings", "police_station", "police station building"),
    ("buildings", "fire_station", "fire station with big red garage door"),
    ("buildings", "market_stall", "wooden market stall with striped canopy and vegetables"),
    ("buildings", "warehouse", "industrial warehouse with metal roof"),
    ("buildings", "greenhouse", "glass greenhouse with plants inside"),
    ("buildings", "water_tower", "water tower on steel legs"),
    # --- street props (25) ---
    ("street", "lamp_post", "vintage street lamp post"),
    ("street", "traffic_light", "traffic light on pole"),
    ("street", "stop_sign", "red stop sign on pole"),
    ("street", "street_sign", "green street name sign on pole"),
    ("street", "park_bench", "wooden park bench with metal frame"),
    ("street", "trash_can", "green public trash can"),
    ("street", "fire_hydrant", "red fire hydrant"),
    ("street", "mailbox", "blue public mailbox"),
    ("street", "bus_stop", "bus stop shelter with glass panels"),
    ("street", "wood_fence", "wooden picket fence section"),
    ("street", "metal_fence", "wrought iron fence section"),
    ("street", "brick_wall", "brick wall section"),
    ("street", "road_barrier", "orange and white striped road barrier"),
    ("street", "traffic_cone", "orange traffic cone"),
    ("street", "phone_booth", "red telephone booth"),
    ("street", "fountain", "round stone fountain with water tiers"),
    ("street", "statue", "stone statue of a knight on a pedestal"),
    ("street", "flower_pot_large", "large decorative flower pot with flowers"),
    ("street", "picnic_table", "wooden picnic table with benches"),
    ("street", "swing_set", "playground swing set with two swings"),
    ("street", "playground_slide", "colorful playground slide"),
    ("street", "seesaw", "playground seesaw"),
    ("street", "food_cart", "street food cart with umbrella"),
    ("street", "newspaper_stand", "small newspaper kiosk"),
    ("street", "bollard", "short metal bollard post"),
    # --- props / containers (20) ---
    ("props", "wooden_crate", "wooden crate with metal corners"),
    ("props", "wooden_barrel", "wooden barrel with metal bands"),
    ("props", "metal_barrel", "red metal oil barrel"),
    ("props", "treasure_chest", "wooden treasure chest with gold trim"),
    ("props", "cardboard_box", "plain cardboard box"),
    ("props", "sack_bag", "burlap sack bag tied with rope"),
    ("props", "basket", "woven wicker basket"),
    ("props", "clay_pot", "round clay pot"),
    ("props", "vase", "decorative blue ceramic vase"),
    ("props", "bucket", "metal bucket with handle"),
    ("props", "anvil", "blacksmith iron anvil"),
    ("props", "campfire", "campfire with logs and stones"),
    ("props", "tent", "green camping tent"),
    ("props", "wooden_ladder", "wooden ladder"),
    ("props", "wheelbarrow", "wooden wheelbarrow"),
    ("props", "cart_wagon", "wooden cart wagon with two wheels"),
    ("props", "water_well", "stone water well with wooden roof and bucket"),
    ("props", "signpost", "wooden signpost with two direction arrows"),
    ("props", "torch", "wooden torch with flame"),
    ("props", "lantern", "old metal lantern"),
    # --- furniture (15) ---
    ("furniture", "dining_table", "round wooden dining table"),
    ("furniture", "wooden_chair", "simple wooden chair"),
    ("furniture", "armchair", "cozy red armchair"),
    ("furniture", "sofa", "blue three-seat sofa"),
    ("furniture", "bed", "wooden bed with blue blanket and pillow"),
    ("furniture", "bookshelf", "wooden bookshelf filled with colorful books"),
    ("furniture", "wardrobe", "wooden wardrobe with double doors"),
    ("furniture", "desk", "wooden writing desk with drawers"),
    ("furniture", "stool", "round wooden stool"),
    ("furniture", "kitchen_counter", "kitchen counter with sink"),
    ("furniture", "refrigerator", "retro mint-green refrigerator"),
    ("furniture", "television", "retro television on stand"),
    ("furniture", "floor_lamp", "floor lamp with fabric shade"),
    ("furniture", "fireplace", "stone fireplace with burning fire"),
    ("furniture", "standing_mirror", "standing oval mirror with wooden frame"),
    # --- fantasy (20) ---
    ("fantasy", "sword", "fantasy sword with ornate crossguard"),
    ("fantasy", "shield", "round wooden shield with metal boss"),
    ("fantasy", "battle_axe", "double-headed battle axe"),
    ("fantasy", "bow", "wooden recurve bow"),
    ("fantasy", "quiver", "leather quiver with arrows"),
    ("fantasy", "spear", "spear with steel tip"),
    ("fantasy", "war_hammer", "heavy two-handed war hammer"),
    ("fantasy", "dagger", "curved dagger with jeweled hilt"),
    ("fantasy", "magic_staff", "wizard staff with glowing blue orb"),
    ("fantasy", "magic_wand", "magic wand with star tip"),
    ("fantasy", "potion_bottle", "round potion bottle with glowing pink liquid and cork"),
    ("fantasy", "spellbook", "open spellbook with glowing runes"),
    ("fantasy", "coin_pile", "pile of gold coins"),
    ("fantasy", "gem_diamond", "large cut blue diamond gem"),
    ("fantasy", "crown", "golden royal crown with jewels"),
    ("fantasy", "ornate_key", "large ornate golden key"),
    ("fantasy", "skull", "cartoon skull"),
    ("fantasy", "gravestone", "stone gravestone with cross"),
    ("fantasy", "cauldron", "black iron cauldron with green bubbling liquid"),
    ("fantasy", "crystal_ball", "crystal ball on ornate stand"),
    # --- food (10) ---
    ("food", "apple", "shiny red apple"),
    ("food", "burger", "stacked cheeseburger with lettuce and tomato"),
    ("food", "pizza", "whole pizza with pepperoni"),
    ("food", "cake", "birthday cake with pink frosting and candles"),
    ("food", "ice_cream", "ice cream cone with two scoops"),
    ("food", "bread_loaf", "loaf of crusty bread"),
    ("food", "cheese_wedge", "yellow cheese wedge with holes"),
    ("food", "watermelon_slice", "watermelon slice"),
    ("food", "coffee_cup", "coffee cup with saucer"),
    ("food", "donut", "donut with pink frosting and sprinkles"),
    # --- sci-fi (15) ---
    ("scifi", "scifi_crate", "futuristic sci-fi supply crate with glowing panels"),
    ("scifi", "energy_barrel", "sci-fi barrel with glowing green energy core"),
    ("scifi", "laser_turret", "small sci-fi laser turret"),
    ("scifi", "rocket", "cartoon space rocket with fins"),
    ("scifi", "ufo", "flying saucer ufo with dome"),
    ("scifi", "robot_drone", "small hovering robot drone"),
    ("scifi", "satellite_dish", "satellite dish on mount"),
    ("scifi", "control_console", "sci-fi control console with screens and buttons"),
    ("scifi", "teleporter_pad", "round sci-fi teleporter pad with glowing ring"),
    ("scifi", "scifi_door", "sci-fi sliding door frame"),
    ("scifi", "antenna_tower", "communications antenna tower"),
    ("scifi", "solar_panel", "solar panel on stand"),
    ("scifi", "oxygen_tank", "sci-fi oxygen tank"),
    ("scifi", "space_capsule", "small space capsule pod"),
    ("scifi", "hover_bike", "futuristic hover bike"),
    # --- game pickups / misc (14) ---
    ("game", "gold_coin", "gold coin with star emblem"),
    ("game", "star_pickup", "shiny golden star pickup"),
    ("game", "heart_pickup", "glossy red heart pickup"),
    ("game", "simple_key", "simple golden key"),
    ("game", "bomb", "round black bomb with lit fuse"),
    ("game", "balloon", "red party balloon on string"),
    ("game", "gift_box", "gift box with ribbon bow"),
    ("game", "dice", "white six-sided dice"),
    ("game", "chess_knight", "chess knight piece"),
    ("game", "trophy", "golden trophy cup"),
    ("game", "medal", "gold medal with ribbon"),
    ("game", "flag_banner", "flag banner on pole"),
    ("game", "archery_target", "archery target on stand"),
    ("game", "checkpoint_flag", "checkpoint flag on pole"),
    # --- animals (10, overshoot buffer — batch stops when credits run out) ---
    ("animals", "dog", "friendly cartoon dog standing"),
    ("animals", "cat", "cute cartoon cat sitting"),
    ("animals", "horse", "cartoon horse standing"),
    ("animals", "cow", "cartoon cow standing"),
    ("animals", "chicken", "cartoon chicken"),
    ("animals", "sheep", "fluffy cartoon sheep"),
    ("animals", "pig", "cartoon pig"),
    ("animals", "duck", "cartoon duck"),
    ("animals", "deer", "cartoon deer with antlers"),
    ("animals", "fox", "cartoon fox standing"),
]


class CreditsExhausted(Exception):
    pass


def api_headers():
    return {"Authorization": f"Bearer {get_api_key()}", "Content-Type": "application/json"}


def api_post(payload: dict) -> dict:
    r = requests.post(ENDPOINT, headers=api_headers(), json=payload, timeout=60)
    if r.status_code >= 400:
        text = r.text.lower()
        if r.status_code == 402 or "credit" in text or "insufficient" in text:
            raise CreditsExhausted(r.text)
        raise RuntimeError(f"POST {r.status_code}: {r.text}")
    return r.json()


def api_get_task(task_id: str) -> dict:
    r = requests.get(f"{ENDPOINT}/{task_id}", headers=api_headers(), timeout=60)
    if r.status_code >= 400:
        raise RuntimeError(f"GET {r.status_code}: {r.text}")
    return r.json()


def get_balance() -> int:
    r = requests.get(f"{API_BASE}/openapi/v1/balance", headers=api_headers(), timeout=60)
    if r.status_code >= 400:
        return -1
    return r.json().get("balance", -1)


def load_manifest() -> dict:
    if MANIFEST.is_file():
        return json.loads(MANIFEST.read_text(encoding="utf-8"))
    return {}


def save_manifest(m: dict):
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(m, indent=2), encoding="utf-8")


def submit_preview(desc: str) -> str:
    payload = {
        "mode": "preview",
        "prompt": f"{desc}, {STYLE}",
        "ai_model": "latest",
        "topology": "triangle",
        "target_polycount": 6000,
        "symmetry_mode": "auto",
        "origin_at": "bottom",
    }
    return api_post(payload)["result"]


def submit_refine(preview_id: str) -> str:
    return api_post({"mode": "refine", "preview_task_id": preview_id})["result"]


def poll_wave(task_ids: dict) -> dict:
    """task_ids: {slug: task_id}. Returns {slug: task_dict_or_None}."""
    results = {}
    deadline = time.time() + TASK_TIMEOUT
    pending = dict(task_ids)
    while pending and time.time() < deadline:
        for slug, tid in list(pending.items()):
            try:
                task = api_get_task(tid)
            except Exception as e:
                print(f"  [{slug}] poll error (will retry): {e}", flush=True)
                continue
            status = task.get("status")
            if status == "SUCCEEDED":
                results[slug] = task
                del pending[slug]
                print(f"  [{slug}] SUCCEEDED", flush=True)
            elif status in ("FAILED", "CANCELED"):
                err = (task.get("task_error") or {}).get("message", status)
                print(f"  [{slug}] {status}: {err}", flush=True)
                results[slug] = None
                del pending[slug]
        if pending:
            time.sleep(POLL_INTERVAL)
    for slug in pending:
        print(f"  [{slug}] TIMEOUT after {TASK_TIMEOUT}s", flush=True)
        results[slug] = None
    return results


def recover_interrupted(manifest: dict) -> int:
    """Finish items whose preview/refine was submitted but never downloaded
    (e.g. the batch process was killed mid-wave). Returns count recovered."""
    recovered = 0
    # Items with a refine already submitted: poll + download it.
    refine_ids = {
        slug: e["refine_id"] for slug, e in manifest.items()
        if e.get("refine_id") and e.get("status") != "downloaded"
    }
    # Items with only a preview submitted: submit refine from the existing preview.
    for slug, e in list(manifest.items()):
        if e.get("preview_id") and not e.get("refine_id") and e.get("status") not in ("downloaded", "failed"):
            try:
                task = api_get_task(e["preview_id"])
                if task.get("status") == "SUCCEEDED":
                    rid = submit_refine(e["preview_id"])
                    e.update({"refine_id": rid, "status": "refine_submitted"})
                    refine_ids[slug] = rid
                    print(f"  [recover:{slug}] refine {rid}", flush=True)
                else:
                    e.update({"status": "failed", "error": f"stale preview: {task.get('status')}"})
            except CreditsExhausted:
                raise
            except Exception as ex:
                e.update({"status": "failed", "error": f"recover: {ex}"})
    if not refine_ids:
        return 0
    print(f"=== Recovery: {sorted(refine_ids)} ===", flush=True)
    save_manifest(manifest)
    results = poll_wave(refine_ids)
    for slug, task in results.items():
        entry = manifest[slug]
        glb_url = ((task or {}).get("model_urls") or {}).get("glb")
        if not glb_url:
            entry.update({"status": "failed", "error": "recovery: refine failed/no glb"})
            continue
        out = OUTPUT_ROOT / entry["category"] / f"{slug}.glb"
        try:
            download_model(glb_url, str(out))
            entry.update({"status": "downloaded", "file": str(out)})
            entry.pop("error", None)
            recovered += 1
        except Exception as ex:
            entry.update({"status": "failed", "error": f"recovery download: {ex}"})
    save_manifest(manifest)
    return recovered


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0, help="Process at most N pending items")
    args = ap.parse_args()

    manifest = load_manifest()
    try:
        rec = recover_interrupted(manifest)
        if rec:
            print(f"Recovered {rec} interrupted item(s)", flush=True)
    except CreditsExhausted:
        print("*** CREDITS EXHAUSTED during recovery ***", flush=True)
        return
    pending = [
        (cat, slug, desc) for (cat, slug, desc) in ASSETS
        if manifest.get(slug, {}).get("status") != "downloaded"
    ]
    if args.limit:
        pending = pending[: args.limit]

    print(f"Balance: {get_balance()} credits | pending items: {len(pending)}", flush=True)

    done = failed = 0
    try:
        for i in range(0, len(pending), WAVE_SIZE):
            wave = pending[i : i + WAVE_SIZE]
            print(f"\n=== Wave {i // WAVE_SIZE + 1}: {[s for _, s, _ in wave]} ===", flush=True)

            # 1) submit previews
            preview_ids = {}
            for cat, slug, desc in wave:
                entry = manifest.setdefault(slug, {"category": cat, "prompt": desc})
                try:
                    pid = submit_preview(desc)
                    entry.update({"preview_id": pid, "status": "preview_submitted"})
                    preview_ids[slug] = pid
                    print(f"  [{slug}] preview {pid}", flush=True)
                except CreditsExhausted:
                    raise
                except Exception as e:
                    entry.update({"status": "failed", "error": f"preview submit: {e}"})
                    print(f"  [{slug}] preview submit FAILED: {e}", flush=True)
            save_manifest(manifest)

            # 2) poll previews
            preview_results = poll_wave(preview_ids)

            # 3) submit refines
            refine_ids = {}
            for slug, task in preview_results.items():
                if task is None:
                    manifest[slug].update({"status": "failed", "error": "preview failed/timeout"})
                    continue
                try:
                    rid = submit_refine(manifest[slug]["preview_id"])
                    manifest[slug].update({"refine_id": rid, "status": "refine_submitted"})
                    refine_ids[slug] = rid
                    print(f"  [{slug}] refine {rid}", flush=True)
                except CreditsExhausted:
                    raise
                except Exception as e:
                    manifest[slug].update({"status": "failed", "error": f"refine submit: {e}"})
                    print(f"  [{slug}] refine submit FAILED: {e}", flush=True)
            save_manifest(manifest)

            # 4) poll refines + download
            refine_results = poll_wave(refine_ids)
            for slug, task in refine_results.items():
                if task is None:
                    manifest[slug].update({"status": "failed", "error": "refine failed/timeout"})
                    failed += 1
                    continue
                cat = manifest[slug]["category"]
                glb_url = (task.get("model_urls") or {}).get("glb")
                if not glb_url:
                    manifest[slug].update({"status": "failed", "error": "no glb url"})
                    failed += 1
                    continue
                out = OUTPUT_ROOT / cat / f"{slug}.glb"
                try:
                    download_model(glb_url, str(out))
                    manifest[slug].update({"status": "downloaded", "file": str(out)})
                    manifest[slug].pop("error", None)
                    done += 1
                except Exception as e:
                    manifest[slug].update({"status": "failed", "error": f"download: {e}"})
                    failed += 1
            save_manifest(manifest)
            print(f"Progress: {done} downloaded, {failed} failed | balance: {get_balance()}", flush=True)
    except CreditsExhausted:
        print("\n*** CREDITS EXHAUSTED — stopping batch. ***", flush=True)
    finally:
        save_manifest(manifest)

    total_dl = sum(1 for v in manifest.values() if v.get("status") == "downloaded")
    print(f"\nDONE. This run: {done} downloaded, {failed} failed. "
          f"Total in library: {total_dl}. Final balance: {get_balance()}", flush=True)


if __name__ == "__main__":
    main()
