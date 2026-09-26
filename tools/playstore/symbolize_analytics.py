"""Symbolize every app_error our first-party analytics holds.

    python symbolize_analytics.py [--since YYYY-MM-DD] [--out DIR]

One row per (app, version, signature) from the analytics D1 (read through
wrangler in the analytics worker folder, WORKER below), each stack decoded to
function + file:line with the NDK's llvm-symbolizer against the build's
archived symbols (server/data/symbols/<package>/<versionCode>/, task #332),
picking the ABI file whose GNU build id matches the stack's build_id.
(`flutter symbolize` cannot read Flutter 3.47 stacks: "Cannot locate isolate
instructions section".) Output: <out>/<app>.md."""
import json
import os
import re
import subprocess

_HERE = os.path.dirname(os.path.abspath(__file__))
SYM = os.path.normpath(os.path.join(_HERE, "..", "..", "server", "data", "symbols"))
import argparse
_ap = argparse.ArgumentParser()
_ap.add_argument("--since", default="2026-09-01")
_ap.add_argument("--out", default=os.path.join(_HERE, "out", "errors"))
_args = _ap.parse_args()
OUT = _args.out
WORKER = os.environ.get("LC_ANALYTICS_WORKER", os.path.join(os.path.expanduser("~"), "..", "..", "Cloudflare Workers", "analytics"))
os.makedirs(OUT, exist_ok=True)

SQL = ("SELECT app, app_version AS version, json_extract(props,'$.dim') AS sig, json_extract(props,'$.source') AS source, "
       "COUNT(*) AS n, COUNT(DISTINCT install_id) AS installs, MAX(day) AS last_day, "
       "MAX(CASE WHEN json_extract(props,'$.stack') LIKE '%#0%' THEN json_extract(props,'$.stack') END) AS stack "
       "FROM events WHERE event='app_error' AND day>='" + _args.since + "' GROUP BY app, app_version, sig ORDER BY app, n DESC")
r = subprocess.run(["npx.cmd", "wrangler", "d1", "execute", "analytics", "--remote", "--json", "--command", SQL],
                   cwd=WORKER, capture_output=True, text=True, encoding="utf-8")
rows = json.loads(r.stdout)[0]["results"]
print("rows", len(rows))


def _ndk_bin():
    sdk = os.environ.get("ANDROID_HOME") or os.path.expandvars("%LOCALAPPDATA%/Android/Sdk")
    ndks = sorted(os.listdir(os.path.join(sdk, "ndk")))
    return os.path.join(sdk, "ndk", ndks[-1], "toolchains", "llvm", "prebuilt", "windows-x86_64", "bin")


BIN = _ndk_bin()
_ids = {}


def build_id(path):
    if path not in _ids:
        out = subprocess.run([BIN + "/llvm-readelf.exe", "-n", path], capture_output=True, text=True).stdout
        m = re.search(r"Build ID: ([0-9a-f]+)", out)
        _ids[path] = m.group(1) if m else ""
    return _ids[path]


def symbolize(app, version, stack):
    code = version.split("+")[-1]
    d = os.path.join(SYM, app, code)
    if not os.path.isdir(d):
        return None, f"(no symbols for {app} versionCode {code})"
    m = re.search(r"build_id: '([0-9a-f]+)'", stack)
    want = m.group(1) if m else ""
    files = [os.path.join(d, f) for f in os.listdir(d) if f.endswith(".symbols")]
    match = [f for f in files if build_id(f) == want]
    if not match:
        return None, f"(no symbols file with build id {want} in {code})"
    f = match[0]
    addrs = re.findall(r"virt ([0-9a-f]+)", stack)
    out = subprocess.run([BIN + "/llvm-symbolizer.exe", "--obj=" + f, "--no-inlines"] + ["0x" + x for x in addrs],
                         capture_output=True, text=True, encoding="utf-8", errors="replace").stdout
    frames = []
    for i, blk in enumerate([b for b in out.strip().split(chr(10)*2) if b.strip()]):
        lines = blk.strip().splitlines()
        fn = lines[0] if lines else "?"
        loc = lines[1] if len(lines) > 1 else ""
        loc = re.sub(r"^.*?/(lib|Pub/Cache/hosted/pub.dev)/", r"/", loc.replace("\\", "/"))
        frames.append(f"#{i:02d} {fn}  ({loc})")
    return os.path.basename(f), chr(10).join(frames)


by_app = {}
for row in rows:
    by_app.setdefault(row["app"], []).append(row)

for app, items in by_app.items():
    short = app.split(".")[-1]
    out = [f"# {app}: {len(items)} (version, signature) rows\n"]
    for it in items:
        out.append(f"## {it['sig']} | v{it['version']} | {it['n']}x | {it['installs']} installs | {it['source']} | last {it['last_day']}")
        st = it.get("stack")
        if not st:
            out.append("(no frames captured)\n")
            continue
        if "build_id" not in st:
            out.append("```\n" + st + "\n```\n")
            continue
        f, text = symbolize(app, it["version"], st)
        frames = [l.strip() for l in text.splitlines() if l.strip().startswith("#")]
        own = [l for l in frames if f"package:{short}" in l or "package:hot_" in l or ("package:" in l and "package:flutter/" not in l)]
        out.append(f"symbols: {f}\n```\n" + "\n".join(own[:8] or frames[:8] or [text.strip()[:400]]) + "\n```\n")
    open(os.path.join(OUT, short + ".md"), "w", encoding="utf-8").write("\n".join(out))
    print(short, len(items), flush=True)
