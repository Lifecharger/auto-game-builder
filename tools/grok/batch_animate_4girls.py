"""Batch-submit all 16 animations for the 4 space-shooter girls.
Each girl: back-idle, back-shoot, back-victory, front-idle. Sequential."""
import subprocess
import sys
import os

GROK_DIR = os.path.dirname(os.path.abspath(__file__))
DOWNLOADS = r"C:\Users\caca_\Downloads\grok-generated"

STATIC_CAM = "Static fixed camera locked in place, no camera movement, no zoom, no pan, no parallax, no dolly, locked frame."

GIRLS = [
    {
        "name": "bombshell",
        "back": "bombshell_topdown_3.png",
        "front": "bombshell_p_1.png",
        "hair": "fiery red wavy",
        "outfit": "white paint-splattered tank top and denim shorts, red bandana, brown knee-high boots",
        "gun": "rainbow paint blaster",
        "paint_color": "vibrant rainbow neon",
    },
    {
        "name": "ice_queen",
        "back": "ice_queen_topdown_1.png",
        "front": "ice_queen_p_1.png",
        "hair": "platinum white ponytail",
        "outfit": "glossy black crop top with silver insignia, ultra short black pleated skirt, electric blue tech belt, black thigh-high boots",
        "gun": "chrome paint blaster",
        "paint_color": "glowing electric blue",
    },
    {
        "name": "sun_pilot",
        "back": "sun_pilot_topdown_2.png",
        "front": "sun_pilot_p_1.png",
        "hair": "long wavy golden blonde",
        "outfit": "white and gold captain crop top, white pleated skirt, gold belt, white thigh-high boots",
        "gun": "golden paint blaster",
        "paint_color": "glowing yellow gold",
    },
    {
        "name": "space_pirate",
        "back": "space_pirate_topdown_v2_2.png",
        "front": "space_pirate_p_1.png",
        "hair": "raven black with crimson red streaks",
        "outfit": "dark crimson and black skull-insignia crop top, black leather pleated skirt, red glowing belt, black thigh-high boots, tricorn pirate hat",
        "gun": "ornate skull paint blaster",
        "paint_color": "dark red",
    },
]


def submit(image_path, prompt, label):
    print(f"\n{'='*70}\n>>> {label}\n{'='*70}")
    cmd = [
        sys.executable, os.path.join(GROK_DIR, "grok_animate.py"),
        "--no-download",
        "-i", image_path,
        "-d", prompt,
    ]
    r = subprocess.run(cmd, cwd=GROK_DIR)
    if r.returncode != 0:
        print(f"  !! {label} FAILED (exit {r.returncode})")
        return False
    print(f"  ++ {label} submitted OK")
    return True


def main():
    submitted = 0
    failed = 0
    for g in GIRLS:
        back = os.path.join(DOWNLOADS, g["back"])
        front = os.path.join(DOWNLOADS, g["front"])

        # 1. Back idle (gameplay idle, hovering in space)
        ok = submit(back,
            f"{STATIC_CAM} Smooth seamless idle loop for vertical space shooter player sprite. "
            f"Character viewed from behind hovering in space. Her {g['hair']} hair sways softly side to side, "
            f"body breathes subtly up and down, outfit fabric flutters gently, paint blaster gun stays steady aimed "
            f"straight up, stars twinkle faintly. Very subtle motion, calm ready stance.",
            f"{g['name']} back-idle")
        submitted += 1 if ok else 0
        failed += 0 if ok else 1

        # 2. Back shoot (firing paint upward)
        ok = submit(back,
            f"{STATIC_CAM} Action shoot animation. Character fires the paint blaster gun straight UPWARD. "
            f"{g['paint_color']} paint blasts and splatters powerfully out of the muzzle streaming up to the top of frame, "
            f"paint trails arc upward, bright muzzle flash glow. Slight recoil pulses through her body, "
            f"{g['hair']} hair whips from the recoil wind, intense firing motion, paint particles fly.",
            f"{g['name']} back-shoot")
        submitted += 1 if ok else 0
        failed += 0 if ok else 1

        # 3. Back victory turn-around (turn to face camera, blow kiss)
        ok = submit(back,
            f"{STATIC_CAM} Victory celebration. Character slowly rotates 180 degrees to face the camera, "
            f"{g['hair']} hair swirls beautifully in the rotation, body twists gracefully. Once facing camera "
            f"she smiles confidently, winks one eye flirtatiously, then blows a kiss to the viewer bringing one "
            f"hand near her lips with fingers extended palm forward sending the kiss outward, paint blaster casually "
            f"held aside. Sassy playful celebration dance, deep space nebula glows around her.",
            f"{g['name']} back-victory")
        submitted += 1 if ok else 0
        failed += 0 if ok else 1

        # 4. Front idle (menu idle, standing facing camera)
        ok = submit(front,
            f"{STATIC_CAM} Smooth seamless menu idle loop. Character stands facing camera. "
            f"Only her body moves: {g['hair']} hair sways gently with soft breeze, body breathes subtly, "
            f"chest rises and falls, eyes blink occasionally, lips smile softly, outfit fabric flutters gently. "
            f"Paint blaster gun held steady. Very subtle calm motion suitable for a main menu portrait.",
            f"{g['name']} front-idle")
        submitted += 1 if ok else 0
        failed += 0 if ok else 1

    print(f"\n{'='*70}\nDONE. Submitted: {submitted}, Failed: {failed}\n{'='*70}")


if __name__ == "__main__":
    main()
