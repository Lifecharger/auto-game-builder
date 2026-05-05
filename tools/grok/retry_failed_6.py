"""Retry the 6 animations that failed in the first batch."""
import subprocess
import sys
import os

GROK_DIR = os.path.dirname(os.path.abspath(__file__))
DOWNLOADS = r"C:\Users\caca_\Downloads\grok-generated"

STATIC_CAM = "Static fixed camera locked in place, no camera movement, no zoom, no pan, no parallax, no dolly, locked frame."

# Same girl data subset (only the failed ones)
RETRIES = [
    {"name": "bombshell back-idle", "img": "bombshell_topdown_3.png", "type": "back-idle",
     "hair": "fiery red wavy", "paint_color": "vibrant rainbow neon"},
    {"name": "bombshell back-shoot", "img": "bombshell_topdown_3.png", "type": "back-shoot",
     "hair": "fiery red wavy", "paint_color": "vibrant rainbow neon"},
    {"name": "bombshell back-victory", "img": "bombshell_topdown_3.png", "type": "back-victory",
     "hair": "fiery red wavy", "paint_color": "vibrant rainbow neon"},
    {"name": "bombshell front-idle", "img": "bombshell_p_1.png", "type": "front-idle",
     "hair": "fiery red wavy", "paint_color": "vibrant rainbow neon"},
    {"name": "ice_queen back-idle", "img": "ice_queen_topdown_1.png", "type": "back-idle",
     "hair": "platinum white ponytail", "paint_color": "glowing electric blue"},
    {"name": "sun_pilot front-idle", "img": "sun_pilot_p_1.png", "type": "front-idle",
     "hair": "long wavy golden blonde", "paint_color": "glowing yellow gold"},
]


def prompt_for(t, hair, paint_color):
    if t == "back-idle":
        return (f"{STATIC_CAM} Smooth seamless idle loop for vertical space shooter player sprite. "
                f"Character viewed from behind hovering in space. Her {hair} hair sways softly side to side, "
                f"body breathes subtly up and down, outfit fabric flutters gently, paint blaster gun stays steady aimed "
                f"straight up, stars twinkle faintly. Very subtle motion, calm ready stance.")
    if t == "back-shoot":
        return (f"{STATIC_CAM} Action shoot animation. Character fires the paint blaster gun straight UPWARD. "
                f"{paint_color} paint blasts and splatters powerfully out of the muzzle streaming up to the top of frame, "
                f"paint trails arc upward, bright muzzle flash glow. Slight recoil pulses through her body, "
                f"{hair} hair whips from the recoil wind, intense firing motion, paint particles fly.")
    if t == "back-victory":
        return (f"{STATIC_CAM} Victory celebration. Character slowly rotates 180 degrees to face the camera, "
                f"{hair} hair swirls beautifully in the rotation, body twists gracefully. Once facing camera "
                f"she smiles confidently, winks one eye flirtatiously, then blows a kiss to the viewer bringing one "
                f"hand near her lips with fingers extended palm forward sending the kiss outward, paint blaster casually "
                f"held aside. Sassy playful celebration dance, deep space nebula glows around her.")
    if t == "front-idle":
        return (f"{STATIC_CAM} Smooth seamless menu idle loop. Character stands facing camera. "
                f"Only her body moves: {hair} hair sways gently with soft breeze, body breathes subtly, "
                f"chest rises and falls, eyes blink occasionally, lips smile softly, outfit fabric flutters gently. "
                f"Paint blaster gun held steady. Very subtle calm motion suitable for a main menu portrait.")
    raise ValueError(t)


def main():
    submitted = 0
    failed = 0
    for r in RETRIES:
        img = os.path.join(DOWNLOADS, r["img"])
        prompt = prompt_for(r["type"], r["hair"], r["paint_color"])
        print(f"\n>>> {r['name']}\n")
        cmd = [sys.executable, os.path.join(GROK_DIR, "grok_animate.py"),
               "--no-download", "-i", img, "-d", prompt]
        rc = subprocess.run(cmd, cwd=GROK_DIR).returncode
        if rc == 0:
            print(f"  ++ {r['name']} OK")
            submitted += 1
        else:
            print(f"  !! {r['name']} FAILED")
            failed += 1
    print(f"\nDONE. Submitted: {submitted}, Failed: {failed}")


if __name__ == "__main__":
    main()
