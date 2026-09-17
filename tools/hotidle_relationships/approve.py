"""Turn the review board's OK verdicts into deliveries.

    python approve.py <reviews_dir>      # dir of <girl>.json exported from the artifact db

1. Every item marked "ok" is added to approved.json (accumulates across runs;
   an item never leaves it unless removed by hand).
2. Newly approved stills/portraits/loops are encoded and uploaded with the
   90-day IMMUTABLE cache header (upload_relationships.py --approved).
3. build_review.py then drops approved items from the board (user 2026-09-16:
   "upload the ok givens and get rid of them from the artifact").

A loop is only uploaded when its final-recipe matte exists; otherwise it
stays approved-pending and goes up on the next run.
"""
import glob
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
APPROVED = os.path.join(HERE, "approved.json")


def main() -> None:
    reviews_dir = sys.argv[1]
    approved = {}
    if os.path.isfile(APPROVED):
        with open(APPROVED, encoding="utf-8") as f:
            approved = json.load(f)
    new = {}
    for path in glob.glob(os.path.join(reviews_dir, "*.json")):
        girl = os.path.splitext(os.path.basename(path))[0]
        with open(path, encoding="utf-8") as f:
            doc = json.load(f)
        items = (doc.get("data") or doc).get("items", {})
        for item_id, v in items.items():
            if v.get("verdict") == "ok" and item_id not in approved.get(girl, []):
                approved.setdefault(girl, []).append(item_id)
                new.setdefault(girl, []).append(item_id)
    for g in approved:
        approved[g] = sorted(set(approved[g]))
    with open(APPROVED + ".tmp", "w", encoding="utf-8") as f:
        json.dump(approved, f, indent=1, sort_keys=True)
    os.replace(APPROVED + ".tmp", APPROVED)
    total = sum(len(v) for v in approved.values())
    print(f"approved: {total} items ({sum(len(v) for v in new.values())} new)")
    kinds = sorted({i.split("_")[1] + "s" for v in approved.values() for i in v})
    if kinds:
        subprocess.run([sys.executable, os.path.join(HERE, "upload_relationships.py"),
                        *kinds, "--immutable", "--approved", APPROVED], cwd=HERE, check=False)


if __name__ == "__main__":
    main()
