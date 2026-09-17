"""RVM+isnet passes in one memory-safe sequence, appending to chain_matte.log:
stills (forced onto the current recipe), then the review redos that must not
wait for the overnight chain. The chain handles every other loop."""
import os, subprocess, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
LOG = r"C:/Reusable Assets/Images/Hot Idle/relationships/chain_matte.log"
STEPS = (["matte_loops.py", "--stills", "--force"],
         ["matte_loops.py", "ava", "--levels", "2,4,7", "--force"],
         ["matte_loops.py", "luna", "--levels", "2", "--force"])
for args in STEPS:
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(f"\n=== {time.strftime('%H:%M:%S')} rvm_now {' '.join(args)}\n"); f.flush()
        subprocess.run([sys.executable, *args], cwd=HERE, stdout=f, stderr=subprocess.STDOUT)
with open(LOG, "a", encoding="utf-8") as f:
    f.write(f"\n=== {time.strftime('%H:%M:%S')} RVM_NOW DONE\n")
