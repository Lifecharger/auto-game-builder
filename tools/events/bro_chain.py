"""Round-2 jobs on the SECOND Grok profile, one at a time, after icon_queue."""
import os, subprocess, sys, time
import event_paths
EVENTS = sys.argv[1:]
HERE = os.path.dirname(os.path.abspath(__file__))
env = event_paths.bro_env()
def busy():
    o = subprocess.run(["powershell", "-NoProfile", "-Command",
        "(Get-CimInstance Win32_Process -Filter \"name='python.exe'\" | Where-Object { $_.CommandLine -match 'icon_queue.py' }).Count"],
        capture_output=True, text=True).stdout.strip()
    return o not in ("", "0")
while busy():
    time.sleep(30)
for ev in EVENTS:
    t = time.time(); print(f"===== {ev} {time.strftime('%H:%M')}", flush=True)
    log = event_paths.event_log(ev, "_game_pipeline_r2.log")
    with open(log, "w", encoding="utf-8") as f:
        subprocess.run([sys.executable, os.path.join(HERE, "game_pipeline.py"), ev, "--round", "2"], stdout=f, stderr=subprocess.STDOUT, env=env)
    print("\n".join(l for l in open(log, encoding="utf-8", errors="ignore").read().splitlines() if "WARN" in l or "pack v" in l or "rig" in l), flush=True)
    print(f"{ev}: {int(time.time()-t)} s", flush=True)
print("BRO CHAIN END", flush=True)
