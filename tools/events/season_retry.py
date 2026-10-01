import os, subprocess, sys
import event_paths
HERE = os.path.dirname(os.path.abspath(__file__))
bro = event_paths.bro_env()
jobs = sys.argv[1:]
for job in jobs:
    ev, rnd, prof = job.split(":")
    env = bro if prof == "bro" else dict(os.environ)
    log = event_paths.event_log(ev, f"_game_pipeline_r{rnd}.log")
    with open(log, "w", encoding="utf-8") as f:
        subprocess.run([sys.executable, os.path.join(HERE, "game_pipeline.py"), ev, "--round", rnd], stdout=f, stderr=subprocess.STDOUT, env=env)
    print(job, [l for l in open(log, encoding="utf-8", errors="ignore").read().splitlines() if "WARN" in l or "pack v" in l or "rig" in l or "no conversation" in l], flush=True)
