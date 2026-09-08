"""ComfyUI UI-formatindaki is akisini API formatina cevirir.  (gorev #326)

- alt-grafikleri (subgraph) yerinde acar, sinir yuvalarini ADA gore esler
- bypass (mode 4) dugumleri gecirir, mute (mode 2) dugumleri eler
- Primitive* dugumlerini sabit degere indirger (baglantiliysa gecis yapar)
- widget degerlerini ComfyUI /object_info'daki GERCEK widget sirasina gore esler
  (yeni frontend widget adlarini node["inputs"] icine yazmiyor; sirf oraya bakan
  eski surum unet_name / steps / height gibi zorunlu alanlari dusuruyordu)
- V3 dinamik girisleri (COMFY_DYNAMICCOMBO_V3 alt widget'lari, COMFY_AUTOGROW_V3
  cogul girisleri) tanir
- duz (alt-grafiksiz) is akislarinda prompt/seed/olcu override'larini yazar
- validate_graph() ile /prompt'a gonderMEDEN once eksik zorunlu girisleri bulur

Canonical dosya: C:/ComfyUI/scripts/wf2api.py
AGB deposundaki tools/character/wf2api.py bunun birebir kopyasidir.
"""
import itertools
import json
import os
import tempfile
import urllib.request

PRIMITIVES = {"PrimitiveInt", "PrimitiveFloat", "PrimitiveString",
              "PrimitiveStringMultiline", "PrimitiveBoolean", "PrimitiveNode"}
SKIP = {"MarkdownNote", "Note", "Reroute", "PreviewAny"}
MUTE, BYPASS = 2, 4

# Kok (cikti) dugumleri: grafik bunlardan geriye dogru uretilir.
_OUT_PREFIX = ("Save",)
_OUT_TYPES = {"PreviewImage", "VHS_VideoCombine"}

# Metin promptu tasiyan widget adlari (pozitif/negatif enjeksiyonu icin)
_TEXT_WIDGETS = ("text", "prompt", "positive_prompt", "clip_l", "t5xxl",
                 "text_g", "text_l")
# Adiyla birebir eslesince dogrudan yazilabilecek override anahtarlari
_DIRECT_OVERRIDES = ("prompt", "positive_prompt", "negative_prompt",
                     "seed", "noise_seed", "duration", "frame_rate",
                     "prompt_enhance", "enable_turbo_mode")

_WIDGET_TYPES = ("INT", "FLOAT", "STRING", "BOOLEAN", "COMBO",
                 "COMFY_DYNAMICCOMBO_V3")
DYNCOMBO = "COMFY_DYNAMICCOMBO_V3"
AUTOGROW = "COMFY_AUTOGROW_V3"

_uid = itertools.count(1)


# --------------------------------------------------------------- object_info
_SPECS = None
_SPEC_CACHE = os.path.join(tempfile.gettempdir(), "wf2api_object_info.json")


def _comfy_url() -> str:
    return (os.environ.get("COMFYUI_URL") or "http://127.0.0.1:8188").rstrip("/")


def _spec_type(spec) -> str:
    t = spec[0] if isinstance(spec, (list, tuple)) and spec else None
    if isinstance(t, (list, tuple)):
        return "COMBO"
    return t if isinstance(t, str) else "*"


def _spec_opts(spec) -> dict:
    if isinstance(spec, (list, tuple)) and len(spec) > 1 and isinstance(spec[1], dict):
        return spec[1]
    return {}


def _is_widget_spec(spec) -> bool:
    """Giris tanimi widget mi (kullanicidan deger alir) yoksa salt baglanti mi."""
    if not isinstance(spec, (list, tuple)) or not spec:
        return False
    opts = _spec_opts(spec)
    if opts.get("forceInput"):
        return False
    if opts.get("widgetType"):              # birlesik tur ("FLOAT,INT") ama widget
        return True
    t = spec[0]
    if isinstance(t, (list, tuple)):        # combo (secenek listesi)
        return True
    return isinstance(t, str) and t in _WIDGET_TYPES


def _default_of(spec):
    """Bir widget girisinin varsayilan degeri (yoksa None)."""
    opts = _spec_opts(spec)
    if "default" in opts:
        return opts["default"]
    if _spec_type(spec) == DYNCOMBO:
        for op in opts.get("options") or []:
            if isinstance(op, dict) and "key" in op:
                return op["key"]
    return None


def _widget_entries(inp: dict, order: dict, prefix: str = "") -> list:
    """Bir giris bolumunun widget agaci.

    Her oge: {"n": tam_ad, "c": kontrol_widgeti_var_mi, "r": zorunlu_mu,
              "d": varsayilan, "o": {secenek: [alt ogeler]}}
    COMFY_DYNAMICCOMBO_V3 seciline gore ALT widget'lar acilir; bunlar
    widgets_values listesinde ust widget'in hemen ardindan gelir ve API
    grafiginde "ust.alt" adiyla durur.
    """
    out = []
    for sec in ("required", "optional"):
        d = inp.get(sec) or {}
        keys = order.get(sec) or list(d.keys())
        for k in keys:
            spec = d.get(k)
            if spec is None or not _is_widget_spec(spec):
                continue
            opts = _spec_opts(spec)
            e = {"n": prefix + k, "c": bool(opts.get("control_after_generate")),
                 "r": sec == "required", "d": _default_of(spec)}
            if _spec_type(spec) == DYNCOMBO:
                alt = {}
                for op in opts.get("options") or []:
                    if isinstance(op, dict) and "key" in op:
                        alt[op["key"]] = _widget_entries(op.get("inputs") or {}, {},
                                                         prefix + k + ".")
                if alt:
                    e["o"] = alt
            out.append(e)
    return out


def _compact(info: dict) -> dict:
    """object_info kaydini kucuk bir tanima indirger (combo listeleri atilir)."""
    inp = info.get("input") or {}
    order = info.get("input_order") or {}
    required = []
    for k in (order.get("required") or list((inp.get("required") or {}).keys())):
        spec = (inp.get("required") or {}).get(k)
        if spec is None:
            continue
        if _spec_type(spec) == AUTOGROW:
            continue                     # cogul giris: "values.a", "images.image1"...
        required.append([k, "widget" if _is_widget_spec(spec) else "link", _spec_type(spec)])
    return {"widgets": _widget_entries(inp, order), "required": required,
            "output_node": bool(info.get("output_node"))}


def class_specs(refresh: bool = False) -> dict:
    """Sinif adi -> sikistirilmis tanim (widget agaci + zorunlu girisler).

    ComfyUI ayaktaysa /object_info'dan alinir ve TEMP'e onbelleklenir; kapaliysa
    onbellek kullanilir. Ikisi de yoksa bos sozluk doner ve donusturucu eski,
    dugumun kendi bildirdigi widget adlarina dayanan davranisa duser.
    """
    global _SPECS
    if _SPECS is not None and not refresh:
        return _SPECS
    data = None
    try:
        with urllib.request.urlopen(_comfy_url() + "/object_info", timeout=120) as fh:
            raw = json.load(fh)
        data = {k: _compact(v) for k, v in (raw or {}).items() if isinstance(v, dict)}
        try:
            with open(_SPEC_CACHE, "w", encoding="utf-8") as fh:
                json.dump(data, fh)
        except OSError as e:
            print("[wf2api] object_info onbellegi yazilamadi: %s" % e)
    except Exception as e:
        print("[wf2api] object_info alinamadi (%s), onbellek deneniyor" % e)
        try:
            with open(_SPEC_CACHE, encoding="utf-8") as fh:
                data = json.load(fh)
        except Exception as e2:
            print("[wf2api] onbellek de yok: %s" % e2)
            data = {}
    _SPECS = data or {}
    return _SPECS


# ------------------------------------------------------------- widget esleme
def _flat(entries, wv, expand: bool, linked: set, skip_linked: bool, seq=None) -> list:
    """Widget agacindan duz bir ad dizilimi uretir (None = kontrol widget'i).

    expand=True ise dinamik combo'larin secili secenegi acilir; secim
    widgets_values'tan okundugu icin dizilim soldan saga uretilir - bu yuzden
    ozyineleme AYNI listeye yazar, yoksa alt widget'larin konumu kayar.
    """
    if seq is None:
        seq = []
    for e in entries:
        if skip_linked and e["n"] in linked:
            continue
        secim = wv[len(seq)] if len(seq) < len(wv) else None
        seq.append(e["n"])
        if e["c"]:
            seq.append(None)
        if expand and e.get("o"):
            alt = e["o"].get(secim)
            if alt:
                _flat(alt, wv, expand, linked, skip_linked, seq)
    return seq


# Alt-grafik sinir yuvalarinda widget sayilan turler (gerisi baglantidir)
_SG_WIDGET_TYPES = {"STRING", "INT", "FLOAT", "BOOLEAN", "COMBO"}


def sg_widget_order(sg: dict) -> list:
    """Alt-grafik host dugumunun widgets_values sirasi = sinir girislerinin sirasi.

    Host, sinir girislerinin bir kismini ARAYUZDE gostermeyebilir ama degerlerini
    yine de widgets_values icinde tutar; o yuzden sira host["inputs"]'tan degil
    alt-grafik tanimindan okunur (gorev #326).
    """
    return [i.get("name") for i in (sg.get("inputs") or [])
            if str(i.get("type") or "").upper() in _SG_WIDGET_TYPES and i.get("name")]


def _widget_map(node, specs=None, sg_order=None):
    """Dugumun widget adi -> deger sozlugu.

    widgets_values DUZ bir listedir; hangi degerin hangi girise ait oldugu ancak
    dugum sinifinin widget SIRASI bilinerek cozulur. Frontend surumune gore
    baglantiya cevrilmis widget'lar listede kalabilir ya da kalmayabilir, dinamik
    alt widget'lar acik ya da kapali olabilir; birkac aday dizilim uretip
    uzunluga gore dogrusunu seceriz.
    """
    wv = node.get("widgets_values")
    if isinstance(wv, dict):                      # bazi surumler sozluk yazar
        return dict(wv)
    wv = list(wv or [])
    if not wv:
        return {}
    ins = node.get("inputs") or []
    declared = [i.get("name") for i in ins if i.get("widget") and i.get("name")]
    linked = {i.get("name") for i in ins if i.get("widget") and i.get("link") is not None}

    cands = []
    sp = (specs if specs is not None else class_specs()).get(node.get("type"))
    if sp and sp.get("widgets"):
        for expand in (True, False):
            for skip_linked in (False, True):
                cands.append(_flat(sp["widgets"], wv, expand, linked, skip_linked))
    if sg_order:
        cands.append(list(sg_order))
    if declared:
        # object_info yoksa (alt-grafik host dugumu, kurulu olmayan sinif)
        eski = []
        for n in declared:
            eski.append(n)
            if n in ("seed", "noise_seed"):
                eski.append(None)
        cands.append(declared)
        cands.append(eski)

    seq = next((c for c in cands if len(c) == len(wv)), None)
    if seq is None:
        seq = cands[0] if cands else []
    out = {}
    for i, name in enumerate(seq):
        if i >= len(wv):
            break
        if name:
            out[name] = wv[i]
    return out


def _varsayilan_doldur(entries, inputs) -> None:
    """Eksik ZORUNLU widget'lari object_info varsayilaniyla doldurur.

    Is akisi dugumun eski surumuyle kaydedilmisse yeni eklenen widget hic
    yoktur (ornek: ImageScaleToTotalPixels.resolution_steps) ya da dinamik
    combo'nun secili secenegi bir alt alan ister (SaveVideo format=auto ->
    format.codec). Frontend acildiginda ne yapiyorsa onu yapariz.
    """
    for e in entries:
        if e.get("r") and e["n"] not in inputs and e.get("d") is not None:
            inputs[e["n"]] = e["d"]
        secim = inputs.get(e["n"])
        if not isinstance(secim, (str, int, float, bool)):
            continue                      # baglanti verilmis: secenegi bilemeyiz
        alt = (e.get("o") or {}).get(secim)
        if alt:
            _varsayilan_doldur(alt, inputs)


class Ctx:
    """Bir grafik seviyesi: dugumler, linkler ve sinir cozucusu."""

    def __init__(self, nodes, links, boundary=None, subgraphs=None):
        self.nodes = {n["id"]: n for n in nodes}
        norm = {}
        for l in links:
            if isinstance(l, dict):
                norm[l["id"]] = l
            elif isinstance(l, (list, tuple)) and len(l) >= 5:
                norm[l[0]] = {"id": l[0], "origin_id": l[1], "origin_slot": l[2],
                              "target_id": l[3], "target_slot": l[4],
                              "type": l[5] if len(l) > 5 else None}
        self.links = norm
        self.boundary = boundary or {}      # slot -> ("ref",(uid,slot)) | ("val",deger)
        self.subgraphs = subgraphs or {}
        self.emitted = {}                   # node_id -> uid
        self.sg_out = {}                    # alt-grafik host id -> {slot: sonuc}


def convert(wf: dict, overrides: dict, specs: dict | None = None) -> dict:
    specs = class_specs() if specs is None else specs
    subgraphs = {s["id"]: s for s in (wf.get("definitions", {}) or {}).get("subgraphs", []) or []}
    api = {}

    def kaydedici(t) -> bool:
        """Kok sayilan cikti dugumu (dosyaya yazanlar)."""
        if not t or t in SKIP or t in PRIMITIVES or t in subgraphs:
            return False
        return t.startswith(_OUT_PREFIX) or t in _OUT_TYPES

    def cikti_dugumu(t) -> bool:
        """ComfyUI'nin cikti saydigi her dugum (onizlemeler dahil)."""
        if not t or t in SKIP or t in PRIMITIVES or t in subgraphs:
            return False
        sp = specs.get(t)
        return bool(sp and sp.get("output_node")) or kaydedici(t)

    def out_type(node, slot):
        outs = node.get("outputs") or []
        return outs[slot].get("type") if 0 <= slot < len(outs) else None

    def bypass(ctx, node, oslot, depth):
        """mode==4: dugum yok sayilir, cikis turune uyan girisi geciririz."""
        t = out_type(node, oslot)
        ins = [i for i in (node.get("inputs") or []) if i.get("link") is not None]
        cand = [i for i in ins if i.get("type") == t]
        if not cand and t is None:
            cand = ins
        for i in cand:
            r = resolve(ctx, i["link"], depth + 1)
            if r is not None:
                return r
        return None

    def resolve(ctx, link_id, depth=0):
        """link -> ('ref',(uid,slot)) | ('val',deger)"""
        if depth > 128:
            return None
        l = ctx.links.get(link_id)
        if l is None:
            return None
        oid, oslot = l["origin_id"], l["origin_slot"]
        if oid in (-10,):                       # alt-grafik girisi
            return ctx.boundary.get(oslot)
        src = ctx.nodes.get(oid)
        if src is None:
            return None
        mode = src.get("mode")
        if mode == MUTE:
            return None
        if mode == BYPASS:
            return bypass(ctx, src, oslot, depth)
        t = src["type"]
        if t in PRIMITIVES:
            inp = (src.get("inputs") or [])
            if inp and inp[0].get("link") is not None:   # gecis
                return resolve(ctx, inp[0]["link"], depth + 1)
            wv = src.get("widgets_values") or []
            return ("val", wv[0] if wv else None)
        if t in SKIP:
            inp = (src.get("inputs") or [])
            return resolve(ctx, inp[0]["link"], depth + 1) if inp and inp[0].get("link") else None
        if t in subgraphs:
            return emit_subgraph(ctx, src, subgraphs[t]).get(oslot)
        uid = emit(ctx, src)
        return ("ref", (uid, oslot)) if uid else None

    def emit(ctx, node):
        nid = node["id"]
        if nid in ctx.emitted:
            return ctx.emitted[nid]
        t = node["type"]
        if t in SKIP or t in PRIMITIVES or node.get("mode") in (MUTE, BYPASS):
            return None
        if t in subgraphs:
            emit_subgraph(ctx, node, subgraphs[t])
            return None
        uid = str(next(_uid))
        ctx.emitted[nid] = uid
        wm = _widget_map(node, specs)
        inputs = {}
        gorulen = set()
        for inp in (node.get("inputs") or []):
            name = inp.get("name")
            if not name:
                continue
            gorulen.add(name)
            if inp.get("link") is not None:
                r = resolve(ctx, inp["link"])
                if r is not None:
                    inputs[name] = list(r[1]) if r[0] == "ref" else r[1]
                    continue
                # baglanti cozulemedi (bypass/mute/acilmamis alt-grafik girisi)
                # -> dugumun kendi widget degeri gecerlidir
            if name in wm:
                inputs[name] = wm[name]
        # Yeni frontend widget adlarini inputs'a yazmiyor: object_info'dan
        # cozulen widget degerlerini de ekleriz.
        for name, val in wm.items():
            if name not in gorulen and name not in inputs:
                inputs[name] = val
        # Is akisi dugumun eski surumuyle kaydedilmisse yeni eklenen zorunlu
        # widget hic yoktur; frontend gibi varsayilanla doldururuz.
        _varsayilan_doldur((specs.get(t) or {}).get("widgets") or [], inputs)
        api[uid] = {"class_type": t, "inputs": inputs,
                    "_meta": {"title": node.get("title") or t}}
        return uid

    def emit_subgraph(ctx, host, sg):
        """host dugumunun sinir degerlerini cozup alt-grafigi acar.

        Sinir yuvalari ADA gore eslenir (eskiden SIRAYA gore eslenip yanlis
        dugume yaziliyordu). Host bir yuvayi acmamissa ic dugum kendi widget
        degerini kullanir.
        """
        if host["id"] in ctx.sg_out:
            return ctx.sg_out[host["id"]]
        ctx.sg_out[host["id"]] = {}          # ozyineleme koruma
        wm = _widget_map(host, specs, sg_widget_order(sg))
        hins = {}
        for i in (host.get("inputs") or []):
            if i.get("name"):
                hins.setdefault(i["name"], i)
            if i.get("label"):
                hins.setdefault(i["label"], i)
        boundary = {}
        for slot, sgin in enumerate(sg.get("inputs") or []):
            keys = [k for k in (sgin.get("label"), sgin.get("name")) if k]
            hit = next((k for k in keys if k in overrides), None)
            if hit is not None:
                boundary[slot] = ("val", overrides[hit])
                continue
            hin = next((hins[k] for k in keys if k in hins), None)
            if hin is not None and hin.get("link") is not None:
                r = resolve(ctx, hin["link"])
                if r:
                    boundary[slot] = r
                    continue
            # Host girisi arayuzde gizli olsa bile degeri widgets_values'ta durur
            ad = sgin.get("name")
            if ad in wm:
                boundary[slot] = ("val", wm[ad])
        inner = Ctx(sg.get("nodes", []), sg.get("links", []), boundary, subgraphs)
        outs = {}
        for l in sg.get("links", []):
            if not isinstance(l, dict) or l.get("target_id") != -20:
                continue
            r = resolve(inner, l["id"])
            if r is not None:
                outs[l.get("target_slot", 0)] = r
        # alt-grafigin icindeki kaydedici dugumler de calismali
        for n in sg.get("nodes", []):
            if kaydedici(n.get("type")) and n.get("mode") not in (MUTE, BYPASS):
                emit(inner, n)
        ctx.sg_out[host["id"]] = outs
        return outs

    def kokleri_uret(test) -> None:
        for n in wf.get("nodes", []):
            if n.get("mode") in (MUTE, BYPASS):
                continue
            t = n.get("type")
            if test(t):
                emit(root, n)
            elif t in subgraphs and any(
                    test(x.get("type")) and x.get("mode") not in (MUTE, BYPASS)
                    for x in subgraphs[t].get("nodes") or []):
                emit_subgraph(root, n, subgraphs[t])

    root = Ctx(wf.get("nodes", []), wf.get("links", []), {}, subgraphs)
    kokleri_uret(kaydedici)
    if not api:
        # Hicbir Save* yok (ornek: sadece MaskPreview tasiyan segment akisi)
        kokleri_uret(cikti_dugumu)
    _apply_overrides(api, overrides, specs)
    return api


# ------------------------------------------------------- override enjeksiyonu
def _apply_overrides(api: dict, overrides: dict, specs: dict) -> None:
    """Alt-grafiksiz is akislarinda prompt/seed/olcu degerlerini yazar.

    Alt-grafikli sablonlarda bu is sinir yuvalarinda yapilir; duz grafiklerde
    (T2I Chroma / Flux1 Schnell gibi) hicbir yere yazilmiyordu, uretim is
    akisinin kendi ornek promptuyla calisiyordu.
    """
    if not overrides:
        return

    def widgets(uid) -> set:
        sp = specs.get(api[uid]["class_type"])
        return {e["n"] for e in (sp or {}).get("widgets", [])}

    def islink(v) -> bool:
        return isinstance(v, list) and len(v) == 2 and isinstance(v[0], str)

    def yaz(uid, name, val) -> bool:
        n = api[uid]
        if name not in widgets(uid) or islink(n["inputs"].get(name)):
            return False
        n["inputs"][name] = val
        return True

    # 1) pozitif / negatif prompt: KSampler / CFGGuider gibi dugumlerin
    #    "positive" ve "negative" girislerinden geriye yurunur
    def metin_dugumu(uid, gorulen, depth=0):
        if uid in gorulen or depth > 12 or uid not in api:
            return None
        gorulen.add(uid)
        if widgets(uid) & set(_TEXT_WIDGETS):
            return uid
        for v in api[uid]["inputs"].values():
            if islink(v):
                r = metin_dugumu(v[0], gorulen, depth + 1)
                if r:
                    return r
        return None

    kullanilan = set()
    for rol, anahtar in (("positive", "prompt"), ("negative", "negative_prompt")):
        val = overrides.get(anahtar)
        if not isinstance(val, str) or not val.strip():
            continue
        for n in list(api.values()):
            src = n["inputs"].get(rol)
            if not islink(src):
                continue
            hedef = metin_dugumu(src[0], set())
            if not hedef or hedef in kullanilan:
                continue
            yazildi = [yaz(hedef, w, val) for w in _TEXT_WIDGETS if w in widgets(hedef)]
            if any(yazildi):
                kullanilan.add(hedef)

    # 2) adi birebir tutan widget'lar (seed, noise_seed, duration, ...)
    for uid in list(api):
        if uid in kullanilan:
            continue
        for k in _DIRECT_OVERRIDES:
            if k in overrides and overrides[k] is not None:
                yaz(uid, k, overrides[k])

    # 3) olcu: yalniz latent ureten / zamanlayici dugumlerde
    w, h = overrides.get("width"), overrides.get("height")
    if isinstance(w, int) and isinstance(h, int) and w > 0 and h > 0:
        for uid in list(api):
            ct = api[uid]["class_type"]
            if not (ct.startswith("Empty") or ct.endswith("Scheduler")):
                continue
            ws = widgets(uid)
            if "width" in ws and "height" in ws:
                yaz(uid, "width", w)
                yaz(uid, "height", h)


# ------------------------------------------------------------- dogrulama
def validate_graph(graph: dict, specs: dict | None = None) -> list:
    """API grafigini ComfyUI'ye GONDERMEDEN once denetler.

    Doner: hata metinleri listesi (bos liste = grafik gecerli). ComfyUI'nin
    kendi dogrulamasinin bulacagi seyleri offline bulur: eksik zorunlu giris,
    baglanti bekleyen yere yazilmis deger, olmayan dugume giden baglanti,
    kurulu olmayan dugum sinifi, sayi alaninda metin.
    """
    specs = class_specs() if specs is None else specs
    hatalar = []
    if not graph:
        return ["grafik bos - cikti dugumu bulunamadi (hepsi bypass/mute olabilir)"]

    def islink(v):
        return isinstance(v, list) and len(v) == 2 and isinstance(v[0], str)

    def sirala(kv):
        return int(kv[0]) if str(kv[0]).isdigit() else 0

    for uid, node in sorted(graph.items(), key=sirala):
        ct = node.get("class_type")
        basl = (node.get("_meta") or {}).get("title") or ct
        sp = specs.get(ct)
        ins = node.get("inputs") or {}
        for name, v in ins.items():
            if islink(v) and v[0] not in graph:
                hatalar.append("#%s %s (%s): '%s' var olmayan #%s dugumune bagli"
                               % (uid, ct, basl, name, v[0]))
        if sp is None:
            if specs:
                hatalar.append("#%s %s (%s): ComfyUI'de boyle bir dugum yok "
                               "(eksik custom node?)" % (uid, ct, basl))
            continue
        for name, kind, typ in sp["required"]:
            if name not in ins:
                hatalar.append("#%s %s (%s): zorunlu giris eksik -> %s (%s)"
                               % (uid, ct, basl, name, typ))
                continue
            v = ins[name]
            if islink(v):
                continue
            kisa = repr(v)[:60]
            if kind == "link":
                hatalar.append("#%s %s (%s): '%s' bir %s baglantisi bekliyor, deger var (%s)"
                               % (uid, ct, basl, name, typ, kisa))
            elif typ in ("INT", "FLOAT") and (isinstance(v, bool)
                                              or not isinstance(v, (int, float))):
                hatalar.append("#%s %s (%s): '%s' sayi bekliyor, %s geldi (%s)"
                               % (uid, ct, basl, name, type(v).__name__, kisa))
            elif typ == "BOOLEAN" and not isinstance(v, bool):
                hatalar.append("#%s %s (%s): '%s' mantiksal deger bekliyor (%s)"
                               % (uid, ct, basl, name, kisa))
        # dinamik combo'nun secili secenegi kendi zorunlu alt widget'larini ister
        hatalar.extend(_alt_widget_kontrol(sp.get("widgets") or [], ins, uid, ct, basl))
    return hatalar


def _alt_widget_kontrol(entries, ins, uid, ct, basl) -> list:
    out = []
    for e in entries:
        if not e.get("o") or e["n"] not in ins:
            continue
        if not isinstance(ins[e["n"]], (str, int, float, bool)):
            continue                      # baglanti: secenek bilinemez
        alt = e["o"].get(ins[e["n"]])
        if not alt:
            continue
        for a in alt:
            if a.get("r") and a["n"] not in ins:
                out.append("#%s %s (%s): '%s=%s' secimi '%s' alanini zorunlu kiliyor"
                           % (uid, ct, basl, e["n"], ins[e["n"]], a["n"]))
        out.extend(_alt_widget_kontrol(alt, ins, uid, ct, basl))
    return out


if __name__ == "__main__":
    import sys
    wf = json.load(open(sys.argv[1], encoding="utf-8"))
    ov = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
    g = convert(wf, ov)
    sorun = validate_graph(g)
    if sorun:
        print("# DOGRULAMA HATALARI:", file=sys.stderr)
        for s in sorun:
            print("#   " + s, file=sys.stderr)
    print(json.dumps(g, ensure_ascii=False, indent=1))
