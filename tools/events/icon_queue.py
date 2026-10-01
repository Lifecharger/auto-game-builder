"""Hub icons (round 3) for every new event, sequential, on the second Grok profile."""
import os, subprocess, sys, time
import event_paths
EVENTS = sys.argv[1:] or ["winter_queen", "valentine", "summer", "spring_bunny", "cherry_blossom", "midsummer",
                          "carnival", "newyear", "season_spring", "season_summer", "season_winter"]
HERE = os.path.dirname(os.path.abspath(__file__))
env = event_paths.bro_env()
for ev in EVENTS:
    t = time.time(); print(f"===== {ev} {time.strftime('%H:%M')}", flush=True)
    r = subprocess.run([sys.executable, os.path.join(HERE, "game_pipeline.py"), ev, "--round", "3"],
                       capture_output=True, text=True, env=env)
    out = [l for l in r.stdout.splitlines() if "hub icon" in l or "pack v" in l or "WARN" in l]
    print("\n".join(out) or r.stdout[-400:] + r.stderr[-400:], flush=True)
    print(f"{ev}: exit {r.returncode} in {int(time.time()-t)} s", flush=True)
print("ICON QUEUE END", flush=True)
