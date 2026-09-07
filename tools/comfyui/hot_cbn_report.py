"""Contact sheet for the Hot CBN (reveal) flow: every asset under the Hot CBN root
on one page — source, line-art page, numbered template, reveal video, metrics —
and a tap-to-reveal board driven by the real 02_regions.png id map.

    python hot_cbn_report.py [out.html]
"""
from __future__ import annotations

import base64
import html
import json
import sys
from pathlib import Path

import cv2

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hot_cbn import OUT_ROOT  # noqa: E402

THUMB = 640
BOARD = 900          # id map / source / page are embedded at this long side for the board


def jpg_uri(png: Path, width: int = THUMB, q: int = 82) -> str:
    im = cv2.imread(str(png))
    if im is None:
        return ""
    h, w = im.shape[:2]
    s = width / max(h, w)
    if s < 1:
        im = cv2.resize(im, (int(w * s), int(h * s)), interpolation=cv2.INTER_AREA)
    ok, buf = cv2.imencode(".jpg", im, [cv2.IMWRITE_JPEG_QUALITY, q])
    return "data:image/jpeg;base64," + base64.b64encode(buf.tobytes()).decode() if ok else ""


def idmap_uri(png: Path, width: int = BOARD) -> tuple[str, int, int]:
    """Region ids must survive scaling: nearest-neighbour + lossless PNG."""
    im = cv2.imread(str(png))
    h, w = im.shape[:2]
    s = width / max(h, w)
    if s < 1:
        im = cv2.resize(im, (int(w * s), int(h * s)), interpolation=cv2.INTER_NEAREST)
    ok, buf = cv2.imencode(".png", im, [cv2.IMWRITE_PNG_COMPRESSION, 9])
    return "data:image/png;base64," + base64.b64encode(buf.tobytes()).decode(), im.shape[1], im.shape[0]


def mp4_uri(p: Path, height: int = 640) -> str:
    """Embedded copy of the reveal video, shrunk so six assets stay well under
    the 16 MB page cap (the full-size mp4 stays beside the asset)."""
    if not p.exists():
        return ""
    small = p.with_name("_reveal_small.mp4")
    if not small.exists() or small.stat().st_mtime < p.stat().st_mtime:
        import shutil
        import subprocess
        ff = shutil.which("ffmpeg")
        if not ff:
            return ""
        subprocess.run([ff, "-y", "-loglevel", "error", "-i", str(p), "-vf", f"scale=-2:{height}",
                        "-c:v", "libx264", "-crf", "28", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(small)], check=True)
    return "data:video/mp4;base64," + base64.b64encode(small.read_bytes()).decode()


def main() -> int:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else OUT_ROOT / "_report.html"
    assets = []
    for d in sorted(OUT_ROOT.iterdir()):
        j = d / "asset.json"
        if d.is_dir() and j.exists() and not d.name.startswith("_"):
            assets.append((d, json.loads(j.read_text(encoding="utf-8"))))
    if not assets:
        print("no assets under", OUT_ROOT)
        return 1

    cards = []
    for i, (d, a) in enumerate(assets):
        m = a["metrics"]
        idm, bw, bh = idmap_uri(d / "02_regions.png")
        region_color = json.dumps([r["color"] for r in a["regions"]])
        pal = "".join(f'<button type="button" data-c="{p["id"]}" title="{p["hex"]}"><i style="background:{p["hex"]}"></i>{p["id"]}</button>'
                      for p in a["palette"])
        v = mp4_uri(d / "06_reveal.mp4")
        video = f'<video src="{v}" controls muted playsinline loop></video>' if v else "<p>video yok</p>"
        cards.append(f'''
<section class="asset" data-i="{i}">
  <header>
    <div><span class="pill {m["verdict"]}">{m["verdict"].upper()}</span>
      <span class="pill neutral">{html.escape(a.get("aspect", ""))} · {a["width"]}×{a["height"]}{" · havuz/kaynak dosya" if a.get("source") else " · Z-Image"}</span></div>
    <h2>{html.escape(a.get("subject") or Path(a.get("source", "")).name)}</h2>
    <p class="metrics"><b>{m["regions"]}</b> bölge · <b>{m["colors"]}</b> renk · numaralı <b>{m["labeled_regions"]}</b> · en küçük <b>{m["min_region_px"]}</b> px · en büyük <b>{int(m["largest_region_share"]*100)}%</b> · çizgi <b>{int(m["line_share"]*100)}%</b></p>
  </header>
  <div class="grid">
    <figure><img src="{jpg_uri(d / '00_source.png')}" alt=""><figcaption>Kaynak (sonuç)</figcaption></figure>
    <figure><img src="{jpg_uri(d / '05_lineart.png')}" alt=""><figcaption>Qwen çizgi sayfası + bölme çizgileri</figcaption></figure>
    <figure><img src="{jpg_uri(d / '04_numbered.png', 900, 88)}" alt=""><figcaption>Numaralı şablon</figcaption></figure>
    <figure class="vid">{video}<figcaption>06_reveal.mp4 — çizgi → boyama → sonuç</figcaption></figure>
  </div>
  <div class="play">
    <div class="board">
      <canvas width="{bw}" height="{bh}"></canvas>
      <img class="src" src="{jpg_uri(d / '00_source.png', BOARD, 88)}" alt="" hidden>
      <img class="page" src="{jpg_uri(d / '05_lineart.png', BOARD, 88)}" alt="" hidden>
      <img class="ids" src="{idm}" alt="" hidden>
      <script type="application/json" class="rc">{region_color}</script>
    </div>
    <div class="side">
      <div class="eyebrow">Dokun ve ortaya çıkar</div>
      <div class="legend">{pal}</div>
      <div class="status">Bir numara seç, sonra o numaralı bölgelere dokun; bölge kaynağın o parçasını gösterir.</div>
      <div class="row"><button type="button" class="reset">Sıfırla</button><button type="button" class="auto">Hepsini aç</button></div>
    </div>
  </div>
</section>''')

    passed = sum(1 for _d, a in assets if a["metrics"]["verdict"] == "pass")
    page = f'''<title>Hot CBN Kontak Sayfası</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,600;12..96,800&family=Manrope:wght@400;600;700&family=JetBrains+Mono:wght@500&display=swap">
<style>
:root {{ --paper:#f7f8fa; --paper-2:#eef0f4; --ink:#17191d; --ink-2:#4a4f59; --ink-3:#8a909c; --rule:#d9dce3; --accent:#8a3ffc; --ok:#1f8a4c; --bad:#c43d3d; }}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{ --paper:#15121c; --paper-2:#1f1a29; --ink:#f0ecf7; --ink-2:#bcb4cc; --ink-3:#847b96; --rule:#332c40; --accent:#b388ff; --ok:#4fc47f; --bad:#ef6b6b; }} }}
:root[data-theme="dark"] {{ --paper:#15121c; --paper-2:#1f1a29; --ink:#f0ecf7; --ink-2:#bcb4cc; --ink-3:#847b96; --rule:#332c40; --accent:#b388ff; --ok:#4fc47f; --bad:#ef6b6b; }}
* {{ box-sizing:border-box }}
body {{ margin:0; background:var(--paper); color:var(--ink); font-family:"Manrope",system-ui,sans-serif; font-size:15px; line-height:1.5 }}
.wrap {{ max-width:1100px; margin:0 auto; padding:28px 18px 80px }}
h1,h2 {{ font-family:"Bricolage Grotesque","Manrope",sans-serif; margin:0; text-wrap:balance; line-height:1.15 }}
h1 {{ font-size:clamp(30px,5vw,44px); font-weight:800; letter-spacing:-.02em }}
h2 {{ font-size:20px; font-weight:600; margin-top:8px }}
.eyebrow {{ font-size:12px; letter-spacing:.12em; text-transform:uppercase; color:var(--ink-3); font-weight:700 }}
.lede {{ color:var(--ink-2); max-width:72ch; margin:12px 0 0 }}
.summary {{ display:flex; gap:10px; flex-wrap:wrap; margin-top:16px }}
.summary div {{ background:var(--paper-2); border-radius:10px; padding:10px 14px; font-family:"JetBrains Mono",monospace; font-size:13px }}
.summary b {{ font-size:20px; font-family:"Bricolage Grotesque",sans-serif; display:block }}
.asset {{ margin-top:44px; padding-top:22px; border-top:2px solid var(--ink) }}
.pill {{ display:inline-block; font-size:11px; font-weight:700; padding:2px 9px; border-radius:999px; letter-spacing:.04em; margin-right:6px }}
.pill.pass {{ background:color-mix(in srgb,var(--ok) 16%,transparent); color:var(--ok) }}
.pill.fail {{ background:color-mix(in srgb,var(--bad) 16%,transparent); color:var(--bad) }}
.pill.neutral {{ background:var(--paper-2); color:var(--ink-2) }}
.metrics {{ margin:6px 0 0; color:var(--ink-2) }} .metrics b {{ color:var(--ink); font-variant-numeric:tabular-nums }}
.grid {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(210px,1fr)); gap:10px; margin-top:16px }}
figure {{ margin:0; background:var(--paper-2); border-radius:10px; overflow:hidden }}
figure img, figure video {{ display:block; width:100%; height:auto }}
figcaption {{ font-size:12px; color:var(--ink-2); padding:6px 10px }}
.play {{ display:grid; grid-template-columns:minmax(0,1fr) 250px; gap:16px; margin-top:16px; background:var(--paper-2); border-radius:12px; padding:14px }}
@media (max-width:720px) {{ .play {{ grid-template-columns:1fr }} }}
.board canvas {{ width:100%; height:auto; display:block; background:#fff; border-radius:8px; touch-action:manipulation; cursor:crosshair }}
.legend {{ display:grid; grid-template-columns:repeat(5,1fr); gap:5px; margin-top:8px; max-height:300px; overflow-y:auto }}
.legend button {{ display:flex; flex-direction:column; align-items:center; gap:2px; border:2px solid transparent; background:var(--paper); color:var(--ink); border-radius:8px; padding:4px 2px; cursor:pointer; font:600 11px "JetBrains Mono",monospace }}
.legend button[aria-pressed="true"] {{ border-color:var(--ink) }}
.legend button.done {{ opacity:.4 }}
.legend button:focus-visible {{ outline:2px solid var(--accent); outline-offset:2px }}
.legend i {{ width:26px; height:26px; border-radius:50%; border:1px solid rgba(0,0,0,.15) }}
.status {{ font-size:12.5px; color:var(--ink-2); margin-top:10px; min-height:2.6em }}
.row {{ display:flex; gap:6px; margin-top:8px }}
.row button {{ border:1px solid var(--rule); background:transparent; color:var(--ink); border-radius:8px; padding:5px 10px; cursor:pointer; font:600 12px "Manrope",sans-serif }}
</style>
<div class="wrap">
  <div class="eyebrow">Auto Game Builder · Hot CBN · görev #271</div>
  <h1>Çizgi sayfası → dokundukça ortaya çıkan resim</h1>
  <p class="lede">Yetişkin akışı: sonuç, bitmiş gölgeli resmin kendisi. Qwen Image Edit çizgi sayfasını çıkarıyor, Opus + SAM 3.1 nesneleri ayırıyor, çizgi hücreleri × bölümler × renk kümeleri bölgeleri veriyor; her numara bölgenin ortalama rengi (80'e kadar). Alttaki tahta gerçek <code>02_regions.png</code> ile çalışıyor: numarayı seç, bölgeye dokun.</p>
  <div class="summary">
    <div><b>{len(assets)}</b>varlık</div>
    <div><b>{passed}</b>ölçümü geçti</div>
    <div><b>{sum(a["metrics"]["regions"] for _d, a in assets)//len(assets)}</b>ort. bölge</div>
    <div><b>{sum(a["metrics"]["colors"] for _d, a in assets)//len(assets)}</b>ort. renk</div>
  </div>
  {"".join(cards)}
</div>
<script>
document.querySelectorAll(".asset").forEach(function (sec) {{
  var canvas = sec.querySelector("canvas"), ctx = canvas.getContext("2d");
  var srcImg = sec.querySelector("img.src"), pageImg = sec.querySelector("img.page"), idsImg = sec.querySelector("img.ids");
  var rc = JSON.parse(sec.querySelector("script.rc").textContent);
  var legend = sec.querySelector(".legend"), status = sec.querySelector(".status");
  var W = canvas.width, H = canvas.height, ids = null, srcData = null, pageData = null, filled = new Set(), selected = null;
  var remainingByColor = {{}};
  function ready() {{ return ids && srcData && pageData; }}
  function load(img, cb) {{ if (img.complete && img.naturalWidth) cb(); else img.addEventListener("load", cb); }}
  function grab(img) {{ var c = document.createElement("canvas"); c.width = W; c.height = H; var x = c.getContext("2d"); x.drawImage(img, 0, 0, W, H); return x.getImageData(0, 0, W, H); }}
  function init() {{
    if (!ready()) return;
    ctx.putImageData(pageData, 0, 0);
    remainingByColor = {{}};
    var seen = new Set();
    for (var p = 0; p < ids.length; p++) {{ var id = ids[p]; if (!seen.has(id)) {{ seen.add(id); var c = rc[id]; remainingByColor[c] = (remainingByColor[c] || 0) + 1; }} }}
    render();
  }}
  load(idsImg, function () {{ var d = grab(idsImg).data; ids = new Int32Array(W * H); for (var p = 0, q = 0; p < ids.length; p++, q += 4) ids[p] = (d[q] << 16) | (d[q + 1] << 8) | d[q + 2]; init(); }});
  load(srcImg, function () {{ srcData = grab(srcImg); init(); }});
  load(pageImg, function () {{ pageData = grab(pageImg); init(); }});
  function reveal(id) {{
    var out = ctx.getImageData(0, 0, W, H), o = out.data, s = srcData.data, pg = pageData.data;
    for (var p = 0, q = 0; p < ids.length; p++, q += 4) if (ids[p] === id) {{
      var dark = (pg[q] + pg[q + 1] + pg[q + 2]) < 200;      // keep the drawn line on top
      o[q] = dark ? s[q] * 0.15 : s[q]; o[q + 1] = dark ? s[q + 1] * 0.15 : s[q + 1]; o[q + 2] = dark ? s[q + 2] * 0.15 : s[q + 2]; o[q + 3] = 255;
    }}
    ctx.putImageData(out, 0, 0);
    filled.add(id);
    remainingByColor[rc[id]]--;
  }}
  function render() {{
    Array.prototype.forEach.call(legend.children, function (b) {{
      b.setAttribute("aria-pressed", String(selected === b.dataset.c));
      b.classList.toggle("done", (remainingByColor[b.dataset.c] || 0) === 0);
    }});
  }}
  Array.prototype.forEach.call(legend.children, function (b) {{
    b.addEventListener("click", function () {{ selected = b.dataset.c; status.textContent = selected + " numaralı bölgelere dokun (" + (remainingByColor[selected] || 0) + " kaldı)."; render(); }});
  }});
  canvas.addEventListener("click", function (e) {{
    if (!ready()) return;
    var r = canvas.getBoundingClientRect();
    var x = Math.floor((e.clientX - r.left) * W / r.width), y = Math.floor((e.clientY - r.top) * H / r.height);
    var id = ids[y * W + x];
    if (filled.has(id)) return;
    if (selected === null) {{ status.textContent = "Önce bir numara seç."; return; }}
    if (String(rc[id]) === selected) {{ reveal(id); status.textContent = (remainingByColor[selected] || 0) + " bölge kaldı."; }}
    else {{ status.textContent = "Bu bölge " + rc[id] + " numara."; }}
    render();
  }});
  sec.querySelector(".reset").addEventListener("click", function () {{ filled.clear(); selected = null; init(); status.textContent = "Sıfırlandı."; }});
  sec.querySelector(".auto").addEventListener("click", function () {{
    if (!ready()) return;
    var out = ctx.getImageData(0, 0, W, H), o = out.data, s = srcData.data, pg = pageData.data;
    for (var q = 0; q < o.length; q += 4) {{ var dark = (pg[q] + pg[q + 1] + pg[q + 2]) < 200; o[q] = dark ? s[q] * 0.15 : s[q]; o[q + 1] = dark ? s[q + 1] * 0.15 : s[q + 1]; o[q + 2] = dark ? s[q + 2] * 0.15 : s[q + 2]; }}
    ctx.putImageData(out, 0, 0); for (var k in remainingByColor) remainingByColor[k] = 0; render(); status.textContent = "Tamamı açıldı.";
  }});
}});
</script>
'''
    out.write_text(page, encoding="utf-8")
    print(f"{len(assets)} assets ({passed} pass) -> {out}  ({out.stat().st_size // 1024} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
