"""Contact sheet for the Kid CBN flow: every asset under <proto root> on one
HTML page — source, SAM segments, flat preview, numbered template, metrics and
the real asset.svg made interactive (tap a colour, tap its regions).

    python kid_cbn_report.py                 # -> <proto root>/_report.html
    python kid_cbn_report.py out.html

Images are embedded as data URIs (downscaled) so the page is self-contained.
"""
from __future__ import annotations

import base64
import html
import json
import sys
from pathlib import Path

import cv2

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kid_cbn import OUT_ROOT  # noqa: E402

THUMB = 640


def data_uri(png: Path, width: int = THUMB) -> str:
    im = cv2.imread(str(png))
    if im is None:
        return ""
    h, w = im.shape[:2]
    if w > width:
        im = cv2.resize(im, (width, int(h * width / w)), interpolation=cv2.INTER_AREA)
    ok, buf = cv2.imencode(".jpg", im, [cv2.IMWRITE_JPEG_QUALITY, 82])
    return "data:image/jpeg;base64," + base64.b64encode(buf.tobytes()).decode() if ok else ""


def main() -> int:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else OUT_ROOT / "_report.html"
    assets = []
    for d in sorted(OUT_ROOT.iterdir()):
        j = d / "asset.json"
        if d.is_dir() and j.exists():
            assets.append((d, json.loads(j.read_text(encoding="utf-8"))))
    if not assets:
        print("no assets under", OUT_ROOT)
        return 1

    cards = []
    for i, (d, a) in enumerate(assets):
        m = a["metrics"]
        pal = "".join(f'<button type="button" data-c="{p["id"]}"><i style="background:{p["hex"]}"></i>{p["id"]}</button>'
                      for p in a["palette"])
        svg = (d / "asset.svg").read_text(encoding="utf-8")
        svg = svg.replace('<svg ', f'<svg id="svg{i}" class="cbn" ', 1).replace(f'width="{a["width"]}" height="{a["height"]}"', "")
        verdict = "pass" if m["verdict"] == "pass" else "fail"
        segs = ", ".join(m.get("segments", []))
        cards.append(f'''
<section class="asset" data-i="{i}">
  <header>
    <div>
      <span class="pill {verdict}">{verdict.upper()}</span>
      <span class="pill neutral">{html.escape(a["profile"])} · {html.escape(a["aspect"])} · {a["width"]}×{a["height"]}</span>
    </div>
    <h2>{html.escape(a["subject"])}</h2>
    <p class="metrics"><b>{m["regions"]}</b> bölge · <b>{m["colors"]}</b> renk · numaralı <b>{m["labeled_regions"]}</b> · en küçük bölge <b>{m["min_region_px"]}</b> px · en büyük <b>{int(m["largest_region_share"]*100)}%</b></p>
    <p class="segs">SAM bölümleri: {html.escape(segs)}</p>
  </header>
  <div class="grid">
    <figure><img src="{data_uri(d / '00_source.png')}" alt=""><figcaption>Z-Image kaynağı</figcaption></figure>
    <figure><img src="{data_uri(d / '01_segments.png')}" alt=""><figcaption>SAM 3.1 bölümleri</figcaption></figure>
    <figure><img src="{data_uri(d / '03_preview.png')}" alt=""><figcaption>Düz renk + çizgi (bitmiş hâli)</figcaption></figure>
    <figure><img src="{data_uri(d / '04_numbered.png')}" alt=""><figcaption>Numaralı şablon</figcaption></figure>
  </div>
  <div class="play">
    <div class="board">{svg}</div>
    <div class="side">
      <div class="eyebrow">asset.svg — dokun ve boya</div>
      <div class="legend">{pal}</div>
      <div class="status">Bir renk seç, sonra numarasını taşıyan bölgelere dokun.</div>
      <button type="button" class="reset">Sıfırla</button>
    </div>
  </div>
</section>''')

    passed = sum(1 for _d, a in assets if a["metrics"]["verdict"] == "pass")
    page = f'''<title>Kid CBN Kontak Sayfası</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,600;12..96,800&family=Manrope:wght@400;600;700&family=JetBrains+Mono:wght@500&display=swap">
<style>
:root {{ --paper:#f7f8fa; --paper-2:#eef0f4; --ink:#17191d; --ink-2:#4a4f59; --ink-3:#8a909c; --rule:#d9dce3; --accent:#2f5bea; --ok:#1f8a4c; --bad:#c43d3d; }}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{ --paper:#14161a; --paper-2:#1c1f25; --ink:#eef0f4; --ink-2:#b7bcc7; --ink-3:#7d8493; --rule:#2c3038; --accent:#6f8ff5; --ok:#4fc47f; --bad:#ef6b6b; }} }}
:root[data-theme="dark"] {{ --paper:#14161a; --paper-2:#1c1f25; --ink:#eef0f4; --ink-2:#b7bcc7; --ink-3:#7d8493; --rule:#2c3038; --accent:#6f8ff5; --ok:#4fc47f; --bad:#ef6b6b; }}
* {{ box-sizing:border-box }}
body {{ margin:0; background:var(--paper); color:var(--ink); font-family:"Manrope",system-ui,sans-serif; font-size:15px; line-height:1.5 }}
.wrap {{ max-width:1080px; margin:0 auto; padding:28px 18px 80px }}
h1,h2 {{ font-family:"Bricolage Grotesque","Manrope",sans-serif; margin:0; text-wrap:balance; line-height:1.15 }}
h1 {{ font-size:clamp(30px,5vw,44px); font-weight:800; letter-spacing:-.02em }}
h2 {{ font-size:21px; font-weight:600; margin-top:8px }}
.eyebrow {{ font-size:12px; letter-spacing:.12em; text-transform:uppercase; color:var(--ink-3); font-weight:700 }}
.lede {{ color:var(--ink-2); max-width:70ch; margin:12px 0 0 }}
.summary {{ display:flex; gap:10px; flex-wrap:wrap; margin-top:16px }}
.summary div {{ background:var(--paper-2); border-radius:10px; padding:10px 14px; font-family:"JetBrains Mono",monospace; font-size:13px }}
.summary b {{ font-size:20px; font-family:"Bricolage Grotesque",sans-serif; display:block }}
.asset {{ margin-top:44px; padding-top:22px; border-top:2px solid var(--ink) }}
.pill {{ display:inline-block; font-size:11px; font-weight:700; padding:2px 9px; border-radius:999px; letter-spacing:.04em; margin-right:6px }}
.pill.pass {{ background:color-mix(in srgb,var(--ok) 16%,transparent); color:var(--ok) }}
.pill.fail {{ background:color-mix(in srgb,var(--bad) 16%,transparent); color:var(--bad) }}
.pill.neutral {{ background:var(--paper-2); color:var(--ink-2) }}
.metrics {{ margin:6px 0 0; color:var(--ink-2) }} .metrics b {{ color:var(--ink); font-variant-numeric:tabular-nums }}
.segs {{ margin:2px 0 0; color:var(--ink-3); font-size:12.5px; font-family:"JetBrains Mono",monospace }}
.grid {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(200px,1fr)); gap:10px; margin-top:16px }}
figure {{ margin:0; background:var(--paper-2); border-radius:10px; overflow:hidden }}
figure img {{ display:block; width:100%; height:auto }}
figcaption {{ font-size:12px; color:var(--ink-2); padding:6px 10px }}
.play {{ display:grid; grid-template-columns:minmax(0,1fr) 220px; gap:16px; margin-top:16px; background:var(--paper-2); border-radius:12px; padding:14px }}
@media (max-width:720px) {{ .play {{ grid-template-columns:1fr }} }}
.board svg {{ width:100%; height:auto; display:block; background:#fff; border-radius:8px; touch-action:manipulation }}
.board svg #regions path {{ cursor:pointer; transition:fill-opacity .2s }}
.board svg #regions path.filled {{ fill-opacity:1 }}
.legend {{ display:grid; grid-template-columns:repeat(4,1fr); gap:6px; margin-top:8px }}
.legend button {{ display:flex; align-items:center; gap:6px; border:2px solid transparent; background:var(--paper); color:var(--ink); border-radius:8px; padding:4px 6px; cursor:pointer; font:600 12px "JetBrains Mono",monospace }}
.legend button[aria-pressed="true"] {{ border-color:var(--ink) }}
.legend button.done {{ opacity:.45; text-decoration:line-through }}
.legend button:focus-visible {{ outline:2px solid var(--accent); outline-offset:2px }}
.legend i {{ width:18px; height:18px; border-radius:5px; border:1px solid rgba(0,0,0,.15); flex:none }}
.status {{ font-size:12.5px; color:var(--ink-2); margin-top:10px; min-height:2.6em }}
.reset {{ margin-top:8px; border:1px solid var(--rule); background:transparent; color:var(--ink); border-radius:8px; padding:5px 10px; cursor:pointer; font:600 12px "Manrope",sans-serif }}
@media (prefers-reduced-motion: reduce) {{ .board svg #regions path {{ transition:none }} }}
</style>
<div class="wrap">
  <div class="eyebrow">Auto Game Builder · Kid CBN · görev #271</div>
  <h1>Prompt → düz görsel → SAM 3.1 → bölgeler</h1>
  <p class="lede">Tamamı yerel: Z-Image-Turbo kaynağı çizdi, SAM 3.1 nesneleri ayırdı (kavram listesi görselden Opus ile çıkarıldı), bölgeler ton/kromaya göre kesildi — gölge bölmedi, çizilmiş kontur bölge olmadı. Her varlığın gerçek <code>asset.svg</code>'si aşağıda oynanabilir.</p>
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
  var svg = sec.querySelector("svg.cbn"), legend = sec.querySelector(".legend"), status = sec.querySelector(".status");
  var paths = Array.prototype.slice.call(svg.querySelectorAll("#regions path"));
  var selected = null;
  function remaining(c) {{ return paths.filter(function (p) {{ return p.dataset.c === c && !p.classList.contains("filled"); }}).length; }}
  function render() {{
    Array.prototype.forEach.call(legend.children, function (b) {{
      b.setAttribute("aria-pressed", String(selected === b.dataset.c));
      b.classList.toggle("done", remaining(b.dataset.c) === 0);
    }});
  }}
  Array.prototype.forEach.call(legend.children, function (b) {{
    b.addEventListener("click", function () {{ selected = b.dataset.c; status.textContent = selected + " numaralı bölgelere dokun (" + remaining(selected) + " kaldı)."; render(); }});
  }});
  paths.forEach(function (p) {{
    p.addEventListener("click", function () {{
      if (p.classList.contains("filled")) return;
      if (selected === null) {{ status.textContent = "Önce paletten bir renk seç."; return; }}
      if (p.dataset.c === selected) {{
        p.classList.add("filled");
        var left = remaining(selected);
        status.textContent = left ? left + " bölge kaldı." : "Bu renk bitti.";
        if (paths.every(function (x) {{ return x.classList.contains("filled"); }})) status.textContent = "Tamamlandı.";
      }} else {{
        status.textContent = "Bu bölge " + p.dataset.c + " numara.";
      }}
      render();
    }});
  }});
  sec.querySelector(".reset").addEventListener("click", function () {{ paths.forEach(function (p) {{ p.classList.remove("filled"); }}); selected = null; status.textContent = "Sıfırlandı."; render(); }});
  render();
}});
</script>
'''
    out.write_text(page, encoding="utf-8")
    print(f"{len(assets)} assets ({passed} pass) -> {out}  ({out.stat().st_size // 1024} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
