"""Wait until no process whose command line contains PATTERN runs, then run season_retry jobs."""
import subprocess, sys, time, os
pattern, jobs = sys.argv[1], sys.argv[2:]
def alive():
    o = subprocess.run(["powershell", "-NoProfile", "-Command",
        f"(Get-CimInstance Win32_Process -Filter \"name='python.exe'\" | Where-Object {{ $_.CommandLine -match '{pattern}' -and $_.CommandLine -notmatch 'after.py' }}).Count"],
        capture_output=True, text=True).stdout.strip()
    return o not in ("", "0")
while alive():
    time.sleep(30)
subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "season_retry.py"), *jobs])
