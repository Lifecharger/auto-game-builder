"""Run game_pipeline.py for several events one after another on the SECOND Grok profile."""
import subprocess, sys, time, os
import event_paths
EVENTS = sys.argv[1:] or ["valentine", "newyear", "midsummer", "carnival", "spring_bunny"]
HERE = os.path.dirname(os.path.abspath(__file__))
env = event_paths.bro_env()
for ev in EVENTS:
    t = time.time(); print(f"===== {ev} {time.strftime('%H:%M')}", flush=True)
    log = event_paths.event_log(ev, "_game_pipeline.log")
    os.makedirs(os.path.dirname(log), exist_ok=True)
    with open(log, "w", encoding="utf-8") as f:
        r = subprocess.run([sys.executable, os.path.join(HERE, "game_pipeline.py"), ev], stdout=f, stderr=subprocess.STDOUT, text=True, env=env)
    print("\n".join(open(log, encoding="utf-8", errors="ignore").read().splitlines()[-5:]), flush=True)
    print(f"{ev}: exit {r.returncode} in {int(time.time()-t)} s", flush=True)
print("GAME QUEUE END", flush=True)
