"""Wait for one PID to exit, then run season_retry jobs (sequential on that profile)."""
import os, subprocess, sys, time
pid, jobs = int(sys.argv[1]), sys.argv[2:]
def alive(p):
    o = subprocess.run(["tasklist", "/FI", f"PID eq {p}"], capture_output=True, text=True).stdout
    return str(p) in o
while alive(pid):
    time.sleep(20)
subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "season_retry.py"), *jobs])
