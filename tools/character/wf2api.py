"""ComfyUI UI-formatindaki is akisini API formatina cevirir.

- alt-grafikleri (subgraph) yerinde acar
- Primitive* dugumlerini sabit degere indirger (baglantiliysa gecis yapar)
- widget degerlerini dugumun inputs sirasina gore esler
"""
import json, itertools

PRIMITIVES = {"PrimitiveInt", "PrimitiveFloat", "PrimitiveString",
              "PrimitiveStringMultiline", "PrimitiveBoolean", "PrimitiveNode"}
SKIP = {"MarkdownNote", "Note", "Reroute", "PreviewAny"}
_uid = itertools.count(1)


def _widget_map(node):
    """widget-tipli input adi -> deger"""
    names = [i["name"] for i in (node.get("inputs") or []) if i.get("widget")]
    vals = list(node.get("widgets_values") or [])
    out, vi = {}, 0
    for n in names:
        if vi >= len(vals):
            break
        out[n] = vals[vi]; vi += 1
        # seed benzeri alanlarda frontend ekstra bir kontrol widget'i tutar
        if n in ("seed", "noise_seed") and vi < len(vals) and \
           isinstance(vals[vi], str) and vals[vi] in ("fixed", "increment", "decrement", "randomize"):
            vi += 1
    return out


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


def convert(wf: dict, overrides: dict) -> dict:
    subgraphs = {s["id"]: s for s in (wf.get("definitions", {}) or {}).get("subgraphs", []) or []}
    api = {}

    def resolve(ctx, link_id):
        """link -> ('ref',(uid,slot)) | ('val',deger)"""
        l = ctx.links.get(link_id)
        if l is None:
            return None
        oid, oslot = l["origin_id"], l["origin_slot"]
        if oid in (-10,):                       # alt-grafik girisi
            return ctx.boundary.get(oslot)
        src = ctx.nodes.get(oid)
        if src is None:
            return None
        if src["type"] in PRIMITIVES:
            inp = (src.get("inputs") or [])
            if inp and inp[0].get("link") is not None:   # gecis
                return resolve(ctx, inp[0]["link"])
            wv = src.get("widgets_values") or []
            return ("val", wv[0] if wv else None)
        if src["type"] in SKIP:
            inp = (src.get("inputs") or [])
            return resolve(ctx, inp[0]["link"]) if inp and inp[0].get("link") else None
        uid = emit(ctx, src)
        return ("ref", (uid, oslot)) if uid else None

    def emit(ctx, node):
        nid = node["id"]
        if nid in ctx.emitted:
            return ctx.emitted[nid]
        t = node["type"]
        if t in SKIP or t in PRIMITIVES:
            return None
        if t in subgraphs:
            return emit_subgraph(ctx, node, subgraphs[t])
        uid = str(next(_uid))
        ctx.emitted[nid] = uid
        wm = _widget_map(node)
        inputs = {}
        for inp in (node.get("inputs") or []):
            name = inp["name"]
            if inp.get("link") is not None:
                r = resolve(ctx, inp["link"])
                if r is None: continue
                inputs[name] = list(r[1]) if r[0] == "ref" else r[1]
            elif name in wm:
                inputs[name] = wm[name]
        api[uid] = {"class_type": t, "inputs": inputs,
                    "_meta": {"title": node.get("title") or t}}
        return uid

    def emit_subgraph(ctx, host, sg):
        """host dugumunun sinir degerlerini cozup alt-grafigi acar."""
        wm = _widget_map(host)
        boundary = {}
        for slot, sgin in enumerate(sg.get("inputs") or []):
            hin = (host.get("inputs") or [])[slot] if slot < len(host.get("inputs") or []) else None
            if hin is None:
                continue
            keys = [k for k in (sgin.get("label"), sgin.get("name")) if k]
            hit = next((k for k in keys if k in overrides), None)
            if hit is not None:
                boundary[slot] = ("val", overrides[hit]); continue
            if hin.get("link") is not None:
                r = resolve(ctx, hin["link"])
                if r: boundary[slot] = r
            elif hin["name"] in wm:
                boundary[slot] = ("val", wm[hin["name"]])
        inner = Ctx(sg.get("nodes", []), sg.get("links", []), boundary, subgraphs)
        # cikis: -20'ye giden link
        out_uid = None
        for l in sg.get("links", []):
            if l.get("target_id") == -20:
                r = resolve(inner, l["id"])
                if r and r[0] == "ref":
                    out_uid = r[1][0]
        ctx.emitted[host["id"]] = out_uid
        return out_uid

    root = Ctx(wf.get("nodes", []), wf.get("links", []), {}, subgraphs)
    # cikti dugumlerinden geriye dogru uret
    for n in wf.get("nodes", []):
        if n["type"].startswith(("SaveImage", "SaveVideo", "SaveAudio", "SaveAnimated")) or            n["type"] in ("PreviewImage", "VHS_VideoCombine"):
            emit(root, n)
    return api


if __name__ == "__main__":
    import sys
    wf = json.load(open(sys.argv[1], encoding="utf-8"))
    ov = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
    g = convert(wf, ov)
    print(json.dumps(g, ensure_ascii=False, indent=1))
