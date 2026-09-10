"""#353: Jigsaw karistiricisi - TUTARLI rastgele secim (tek kaynak, uc istemci de bunu cagirir).

Sorun: 14 alan birbirinden bagimsiz cekilince "hemsire + samuray + yildirimli
firtina + gotik katedral + bikini" cikiyordu. Burada secenek dosyasindaki
`etiketler` (secenek metni -> etiket) ve `karistirici` (sira, olasilik, kimlik
agirliklari) bloklari okunur ve alanlar SIRAYLA, onceki secimlerle uyumlu
adaylardan cekilir:

  hot:  mekan -> kimlik (meslek VEYA fantazi VEYA yok) -> donem -> hava/isik
        -> kiyafet (+renk; kimlik varsa bos - kimlik kiyafeti belirler) -> poz
        (mekanda o prop varsa) -> aci -> gorunus (sac/goz/irk/ifade)
  kid:  konu -> mekan (konu tam sahneyse bos) -> stil (fantastik konu foto
        olmaz) -> hava -> palet

Kilitli alanlar sabit kalir ve diger alanlari kisitlar (bikini kilitliyse
plaj/havuz mekan gelir, mekan kilitliyse hava ona gore). Etiketsiz secenek
(kullanicinin sonradan ekledigi) her yerde serbesttir - dosya bozulmaz.

Ciktinin sekli istemcinin yerel roll()'u ile ayni: {alan: metin|""}.
"""
from __future__ import annotations

import random

from . import jigsaw_flow as JF


class _Etiket:
    __slots__ = ("flags", "need", "era", "prop", "vibe")

    def __init__(self, metin: str = ""):
        self.flags, self.need, self.era, self.prop, self.vibe = set(), set(), set(), set(), set()
        for p in (metin or "").split():
            if p.startswith("need:"):
                self.need.add(p[5:])
            elif p.startswith("era:"):
                self.era.add(p[4:])
            elif p.startswith("prop:"):
                self.prop.add(p[5:])
            elif p.startswith("vibe:"):
                self.vibe.add(p[5:])
            else:
                self.flags.add(p)

    @property
    def bos(self) -> bool:
        return not (self.flags or self.need or self.era or self.prop or self.vibe)


_BOS = _Etiket()


def _profil(rating: str) -> dict:
    prof = (JF.profiles().get("profiles") or {}).get(rating)
    if not isinstance(prof, dict):
        raise ValueError("bilinmeyen derece: %s" % rating)
    return prof


def _etik(prof: dict, alan: str, deger: str) -> _Etiket:
    if not deger:
        return _BOS
    return _Etiket(((prof.get("etiketler") or {}).get(alan) or {}).get(deger, ""))


def _kesisir(a: set, b: set) -> bool:
    return not a or not b or bool(a & b)


# --------------------------------------------------------------- HOT kurallari
def _hot_loc_ok(prof: dict, alan: str, deger: str, loc: str) -> bool:
    """`alan=deger` secimi `loc` mekaniyla uyumlu mu."""
    if not loc or not deger:
        return True
    lt, t = _etik(prof, "location", loc), _etik(prof, alan, deger)
    if lt.bos or t.bos:
        return True
    ic = "in" in lt.flags
    zaman = "day" if "day" in lt.flags else ("night" if "night" in lt.flags else "any")
    if alan == "weather":
        if "in_ok" in t.flags:
            if not ic:
                return False
        elif ic:
            return False
        if "day" in t.flags and zaman == "night":
            return False
        if "night" in t.flags and zaman == "day":
            return False
        return _kesisir(t.need, lt.vibe)
    if alan == "job":
        if lt.era and "modern" not in lt.era:
            return False
        return _kesisir(t.need, lt.vibe)
    if alan in ("fantasy", "theme"):
        if not _kesisir(t.era, lt.era):
            return False
        if "night" in t.flags and zaman == "day":
            return False
        return _kesisir(t.need, lt.vibe)
    if alan == "outfit":
        if "warm_only" in t.flags and "snow" in lt.vibe:
            return False
        return _kesisir(t.need, lt.vibe)
    if alan == "pose":
        if t.prop and not (t.prop & lt.prop):
            return False
        if "out" in t.flags and ic:
            return False
        if "day" in t.flags and zaman == "night":
            return False
        return _kesisir(t.need, lt.vibe)
    if alan == "angle":
        if "in" in t.flags and not ic:
            return False
        return _kesisir(t.need, lt.vibe)
    return True


def _hot_cift_ok(prof: dict, a: str, va: str, b: str, vb: str) -> bool:
    """Iki dolu secim birbiriyle uyumlu mu (simetrik)."""
    if not va or not vb or a == b:
        return True
    if a == "location":
        return _hot_loc_ok(prof, b, vb, va)
    if b == "location":
        return _hot_loc_ok(prof, a, va, vb)
    ta, tb = _etik(prof, a, va), _etik(prof, b, vb)
    cift = {a, b}
    if cift == {"job", "fantasy"}:
        return False                                  # en fazla bir kimlik
    if "outfit" in cift and cift & {"job", "fantasy"}:
        return False                                  # kimlik kiyafeti belirler
    if "outfit_color" in cift and cift & {"job", "fantasy"}:
        return False
    if cift == {"theme", "job"}:
        tt = ta if a == "theme" else tb
        return not tt.era or "modern" in tt.era
    if cift == {"theme", "fantasy"}:
        return _kesisir(ta.era, tb.era)
    if cift == {"weather", "outfit"}:
        tw, to = (ta, tb) if a == "weather" else (tb, ta)
        return not ("cold" in tw.flags and "warm_only" in to.flags)
    if cift == {"weather", "pose"}:
        tw, tp = (ta, tb) if a == "weather" else (tb, ta)
        if "day" in tp.flags and "night" in tw.flags:
            return False
        if "out" in tp.flags and "in_ok" in tw.flags:
            return False
        return True
    if cift == {"weather", "fantasy"}:
        tw, tf = (ta, tb) if a == "weather" else (tb, ta)
        vw = va if a == "weather" else vb
        if "storm" in tf.flags and not ("storm" in vw or "lightning" in vw):
            return False
        if "night" in tf.flags and "day" in tw.flags:
            return False
        return True
    if cift == {"weather", "theme"}:
        tw, tt = (ta, tb) if a == "weather" else (tb, ta)
        return True
    if "hair" in cift:
        th = ta if a == "hair" else tb
        diger, td = (b, tb) if a == "hair" else (a, ta)
        if "fancy" in th.flags:
            if diger == "theme" and "natural_hair" in td.flags:
                return False
            if diger == "job":
                return False
    return True


# --------------------------------------------------------------- KID kurallari
def _kid_cift_ok(prof: dict, a: str, va: str, b: str, vb: str) -> bool:
    if not va or not vb or a == b:
        return True
    ta, tb = _etik(prof, a, va), _etik(prof, b, vb)
    cift = {a, b}
    if cift == {"subject", "location"}:
        ts, tl = (ta, tb) if a == "subject" else (tb, ta)
        if "scene" in ts.flags:
            return False                              # konu zaten tam sahne
        if ts.need and not (ts.need & tl.vibe):
            return False
        if tl.vibe and tl.vibe <= {"water"} and "water" not in ts.need:
            return False                              # kedi su altinda olmaz
        if tl.vibe and tl.vibe <= {"sky"} and "sky" not in ts.need:
            return False
        return True
    if cift == {"subject", "style"}:
        ts, tst = (ta, tb) if a == "subject" else (tb, ta)
        return not ("fantasy" in ts.flags and "photo" in tst.flags)
    if cift == {"mood", "location"}:
        tm, tl = (ta, tb) if a == "mood" else (tb, ta)
        if "snow" in tm.flags and tl.vibe and not (tl.vibe & {"snow", "nature", "urban", "home"}):
            return False
        if "night" in tm.flags and tl.vibe and tl.vibe <= {"home"}:
            return True
        return True
    if cift == {"mood", "subject"}:
        tm, ts = (ta, tb) if a == "mood" else (tb, ta)
        if "snow" in tm.flags and ts.need and not (ts.need & {"snow", "nature", "home", "urban"}):
            return False
        return True
    return True


# ------------------------------------------------------------------- motor
def _uyumlu(rating: str, prof: dict, alan: str, deger: str, secim: dict) -> bool:
    ok = _hot_cift_ok if rating == "hot" else _kid_cift_ok
    return all(ok(prof, alan, deger, f2, v2) for f2, v2 in secim.items() if v2 and f2 != alan)


def roll(rating: str, values: dict | None = None, locks=None, n: int = 1) -> list[dict]:
    """n adet tutarli secim. `values` + `locks`: kilitli alanlar aynen korunur."""
    prof = _profil(rating)
    alanlar = [str(a[0]) for a in (prof.get("alanlar") or []) if isinstance(a, (list, tuple)) and a]
    sec = prof.get("secenekler") or {}
    kur = prof.get("karistirici") or {}
    sira = [a for a in (kur.get("sira") or alanlar) if a in alanlar] + \
           [a for a in alanlar if a not in (kur.get("sira") or [])]
    olas = kur.get("olasilik") or {}
    kimlik = kur.get("kimlik") or {"yok": 0.5, "job": 0.28, "fantasy": 0.22}
    kilit = {str(k) for k in (locks or [])}
    values = values or {}
    n = max(1, min(200, int(n or 1)))
    out = []
    for _ in range(n):
        secim = {a: (str(values.get(a) or "") if a in kilit else "") for a in alanlar}
        # --- hot: kimlik modu (meslek | fantazi | yok) - en fazla biri
        atla = set()
        if rating == "hot":
            if secim.get("job"):
                atla.update({"fantasy", "outfit", "outfit_color"})
            elif secim.get("fantasy"):
                atla.update({"job", "outfit", "outfit_color"})
            elif secim.get("outfit") or secim.get("outfit_color"):
                atla.update({"job", "fantasy"})
            else:
                r, top = random.random() * sum(kimlik.values()), 0.0
                mod = "yok"
                for ad, ag in kimlik.items():
                    top += float(ag)
                    if r <= top:
                        mod = ad
                        break
                if mod == "job":
                    atla.update({"fantasy", "outfit", "outfit_color"})
                elif mod == "fantasy":
                    atla.update({"job", "outfit", "outfit_color"})
                else:
                    atla.update({"job", "fantasy"})
        for alan in sira:
            if alan in kilit or alan in atla:
                continue
            havuz = [str(x) for x in (sec.get(alan) or []) if str(x).strip()]
            if not havuz:
                continue
            p = float(olas.get(alan, 1.0))
            if alan == "outfit_color" and not secim.get("outfit"):
                continue                                  # renk kiyafetsiz anlamsiz
            if rating == "kid" and alan == "location" and \
                    "scene" in _etik(prof, "subject", secim.get("subject", "")).flags:
                continue                                  # konu tam sahne
            if p < 1.0 and random.random() > p:
                continue
            adaylar = [v for v in havuz if _uyumlu(rating, prof, alan, v, secim)]
            if rating == "hot" and alan == "hair" and adaylar:
                # kimlik/donem dogal sac istemese de dogal sac agirlikli olsun
                dogal = [v for v in adaylar if "fancy" not in _etik(prof, "hair", v).flags]
                if dogal and random.random() < float(kur.get("dogal_sac_olasiligi", 0.85)):
                    adaylar = dogal
            if adaylar:
                secim[alan] = random.choice(adaylar)
        out.append(secim)
    return out


def check(rating: str, values: dict) -> list[str]:
    """Verilen secimdeki celismeleri listeler (istemci uyarisi / test icin)."""
    prof = _profil(rating)
    ok = _hot_cift_ok if rating == "hot" else _kid_cift_ok
    sorun = []
    alanlar = [a for a, v in values.items() if v]
    for i, a in enumerate(alanlar):
        for b in alanlar[i + 1:]:
            if not ok(prof, a, values[a], b, values[b]):
                sorun.append("%s=%s x %s=%s" % (a, values[a], b, values[b]))
    return sorun
