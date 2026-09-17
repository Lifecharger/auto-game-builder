"""When the GPU renders are done (no gen_stills.py alive), stop the sequential
chain and matte the remaining loops with N workers, one girl subset each.
Memory-safe only once LTX has released the RAM, hence the wait."""
import json, os, subprocess, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
LOG = r"C:/Reusable Assets/Images/Hot Idle/relationships/matte_parallel.log"
N = 3

def alive(pattern: str) -> bool:
    out = subprocess.run(["powershell", "-NoProfile", "-Command",
        "@(Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | Where-Object { $_.CommandLine -like '*%s*' }).Count" % pattern],
        capture_output=True, text=True).stdout.strip()
    return out not in ("", "0")

def kill(pattern: str) -> None:
    subprocess.run(["powershell", "-NoProfile", "-Command",
        "Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | Where-Object { $_.CommandLine -like '*%s*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }" % pattern])

while alive("gen_stills.py") or alive("rvm_now.py"):
    time.sleep(120)
kill("chain_matte.py")
kill("matte_loops.py")
girls = list(json.load(open(os.path.join(HERE, "ladders.json"), encoding="utf-8"))["girls"])
groups = [girls[i::N] for i in range(N)]
procs = []
for i, g in enumerate(groups):
    f = open(LOG.replace(".log", f"_{i}.log"), "a", encoding="utf-8")
    procs.append(subprocess.Popen([sys.executable, "matte_loops.py", *g], cwd=HERE, stdout=f, stderr=subprocess.STDOUT))
for p in procs:
    p.wait()
with open(LOG, "a", encoding="utf-8") as f:
    f.write(f"{time.strftime('%H:%M:%S')} PARALLEL DONE\n")
