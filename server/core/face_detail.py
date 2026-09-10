"""Yuz rotusu - tam boy karede kucuk kalan yuzu ayri gecirir (#351).

Neden gerekli: kart still'i 832x1248 ve figur TAM BOY isteniyor, o yuzden yuz
kabaca 100x130 piksele dusuyor. Modelin detay butcesinin cogu govdeye ve
kiyafete gidiyor; "guzel kadin" derdinin en zayif halkasi yuz oluyor. Cozunurlugu
buyutmeden yuz kalitesini artirmanin en ucuz yolu: yuzu kirp, buyut, ayri bir
gecisten gecir, geri yapistir.

SIRALAMA KRITIK: video still'den uretiliyor, sheet de videodan kesiliyor. Yuz
rotusu STILL asamasinda yapilmali, sonra yapilirsa bosa gider.

Yontem (yeni bagimlilik YOK):
  1. Yuz kutusu - ComfyUI'deki SDPoseFaceBBoxes yerine burada basit ve saglam
     bir yol: karenin ust bolgesinde ten rengi yogunlugundan yuz kutusu cikarilir.
     Basarisiz olursa figurun ust %18'i kullanilir (tam boy portrede yuz oradadir).
  2. Kutu kare haline getirilip 1024'e buyutulur (LANCZOS).
  3. edit_qwen ile "ayni kadin, ayni yuz - sadece detay" gecisi (kimlik korur).
  4. Kenarlari yumusatilarak geri yapistirilir (feather), boylece dikis olmaz.

Basarisiz olursa still'e DOKUNULMAZ - rotus istege bagli bir iyilestirmedir.
"""

from __future__ import annotations

import os

# Qwen Edit'e giden talimat: kimligi korumasi sart, yoksa kart baska birine doner.
FACE_PROMPT = (
    "Enhance this face to high quality: sharp detailed eyes with clear catchlights, "
    "crisp eyelashes and eyebrows, smooth even skin with natural pores, defined lips, "
    "clean symmetrical features, professional beauty retouching. "
    "Keep the EXACT same woman, the same identity, the same face shape, the same eye "
    "colour, the same hair, the same makeup style, the same expression and the same "
    "head angle. Do not change who she is."
)
FACE_NEG = ("different person, different face, changed identity, plastic skin, waxy, "
            "airbrushed blur, distorted features, extra eyes, deformed, cartoon, anime, "
            "3d render, watermark, text")

FACE_SIZE = 1024          # yuz gecisinin calisma cozunurlugu
FEATHER = 24              # geri yapistirmada yumusatma bandi (piksel)


def face_box(png: str) -> tuple[int, int, int, int] | None:
    """Yuz kutusu (x0, y0, x1, y1) - bulunamazsa None.

    Duz gri studyo fonu sayesinde once figur bulunur; yuz figurun ust bolumunde
    ten renginin en yogun oldugu yerdir.
    """
    try:
        from PIL import Image
    except Exception:
        return None
    try:
        with Image.open(png) as f:
            im = f.convert("RGB")
    except Exception:
        return None
    W, H = im.size
    px = im.load()
    gri = im.convert("L").load()
    kose = [gri[2, 2], gri[W - 3, 2], gri[2, H - 3], gri[W - 3, H - 3]]
    fon = sum(kose) / 4.0

    # 1) figur kutusu
    adim = max(1, W // 220)
    xs, ys = [], []
    for y in range(0, H, adim):
        for x in range(0, W, adim):
            if abs(gri[x, y] - fon) > 26:
                xs.append(x)
                ys.append(y)
    if len(xs) < 60:
        return None
    fx0, fx1, fy0, fy1 = min(xs), max(xs), min(ys), max(ys)
    boy = fy1 - fy0
    if boy < H * 0.2:
        return None

    # 2) figurun ust %22'sinde ten rengi yogunlugu -> yuz merkezi
    ust, alt = fy0, fy0 + int(boy * 0.22)
    ten_x, ten_y = [], []
    for y in range(ust, min(alt, H), max(1, adim // 2)):
        for x in range(fx0, fx1, max(1, adim // 2)):
            r, g, b = px[x, y]
            # kaba ten filtresi: kirmizi baskin, mavi en dusuk, cok koyu degil
            if r > 60 and r >= g >= b and (r - b) > 12 and (r - g) < 90:
                ten_x.append(x)
                ten_y.append(y)
    if len(ten_x) >= 40:
        cx = sorted(ten_x)[len(ten_x) // 2]
        cy = sorted(ten_y)[len(ten_y) // 2]
    else:
        cx, cy = (fx0 + fx1) // 2, fy0 + int(boy * 0.09)

    # 3) yuz kutusu: figur boyunun ~%15'i kadar kare
    yari = max(28, int(boy * 0.085))
    x0, y0 = max(0, cx - yari), max(0, cy - yari)
    x1, y1 = min(W, cx + yari), min(H, cy + yari)
    if (x1 - x0) < 40 or (y1 - y0) < 40:
        return None
    return (x0, y0, x1, y1)


def crop_face(png: str, dest: str, box: tuple[int, int, int, int]) -> str:
    """Yuzu kirpar ve FACE_SIZE'a buyutur (gecis bu cozunurlukte calisir)."""
    from PIL import Image
    with Image.open(png) as f:
        im = f.convert("RGB")
    kirp = im.crop(box).resize((FACE_SIZE, FACE_SIZE), Image.LANCZOS)
    kirp.save(dest, "PNG")
    return dest


def paste_face(png: str, yeni_yuz: str, box: tuple[int, int, int, int]) -> str:
    """Islenmis yuzu yumusak kenarla geri yapistirir (dikis gorunmez)."""
    from PIL import Image, ImageDraw, ImageFilter
    with Image.open(png) as f:
        taban = f.convert("RGB")
    with Image.open(yeni_yuz) as f:
        yuz = f.convert("RGB")
    w, h = box[2] - box[0], box[3] - box[1]
    yuz = yuz.resize((w, h), Image.LANCZOS)
    maske = Image.new("L", (w, h), 0)
    ImageDraw.Draw(maske).rounded_rectangle(
        (FEATHER // 2, FEATHER // 2, w - FEATHER // 2, h - FEATHER // 2),
        radius=FEATHER, fill=255)
    maske = maske.filter(ImageFilter.GaussianBlur(FEATHER / 2.0))
    taban.paste(yuz, (box[0], box[1]), maske)
    taban.save(png, "PNG")
    return png


def plan(png: str) -> dict:
    """Rotus yapilabilir mi + kutu bilgisi (uretim yapmaz, sadece olcer)."""
    b = face_box(png)
    if not b:
        return {"ok": False, "note": "yuz bulunamadi"}
    return {"ok": True, "box": list(b), "size": [b[2] - b[0], b[3] - b[1]]}
