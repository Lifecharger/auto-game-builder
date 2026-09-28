"""Run a folder of Imagine-agent briefs one after another on this Grok profile.

    python run_brief_queue.py <brief folder> [--glob "D*_DESTE.txt"] [--minutes 80] [--only D01,D02]

Each brief is started with grok_agent.py (Imagine AGENT mode) and watched for --minutes; the agent's
own log (conversation id, every saved image/video and its TAG when the agent echoed it) is written
next to the brief as <brief>.run.log, and a line per brief goes to _queue.log. A brief whose
.run.log already shows a conversation AND at least one video is skipped, so the queue can be
re-run after a stop. It stops early when Grok reports the account is out of generations.
Outputs land in the usual Grok download folders (images/, videos/ by UUID); nothing is published.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT_OF_QUOTA = re.compile(r"out of (credits|generations)|no generations left|limit reached|rate limit",
                          re.I)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("folder")
    ap.add_argument("--glob", default="*.txt")
    ap.add_argument("--minutes", type=int, default=80)
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    folder = Path(args.folder)
    only = {x.strip() for x in args.only.split(",") if x.strip()}
    briefs = sorted(p for p in folder.glob(args.glob) if not p.name.endswith(".run.log"))
    if only:
        briefs = [b for b in briefs if b.name.split("_")[0] in only]
    qlog = folder / "_queue.log"
    for brief in briefs:
        log = brief.with_suffix(".run.log")
        if log.exists():
            txt = log.read_text(encoding="utf-8", errors="ignore")
            if "conversation:" in txt and re.search(r"video", txt, re.I):
                print(f"skip {brief.name} (already run)", flush=True)
                continue
        t0 = time.time()
        with open(log, "w", encoding="utf-8") as f:
            rc = subprocess.call([sys.executable, str(HERE / "grok_agent.py"), "start", "--brief", str(brief),
                                  "--watch", str(args.minutes)], stdout=f, stderr=subprocess.STDOUT,
                                 cwd=str(HERE))
        txt = log.read_text(encoding="utf-8", errors="ignore")
        n_img = len(re.findall(r"saved \S+\.(?:jpg|png|webp)", txt))
        n_vid = len(re.findall(r"saved \S+\.mp4", txt))
        line = (f"{time.strftime('%Y-%m-%d %H:%M')} {brief.name}: rc={rc} images={n_img} videos={n_vid} "
                f"{(time.time() - t0) / 60:.0f} min")
        print(line, flush=True)
        with open(qlog, "a", encoding="utf-8") as q:
            q.write(line + "\n")
        if OUT_OF_QUOTA.search(txt):
            print("Grok reports the quota is used up - stopping the queue.", flush=True)
            break


if __name__ == "__main__":
    main()
