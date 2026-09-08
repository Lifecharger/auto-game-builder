# Karakter hattı v2 — Base → Yönler → Skinler (2026-09-08, AGB #305-#307)

`design/karakter_modu.md` (rev3) üzerine gelen yeniden tasarım. Kullanıcı tarifi:

> Sıra bu olmalı: önce base + portre (vesikalık gibi, sadece yüz). Sonra base'in yönleri (2. adım).
> 3. adım skinler. İlk adım otomatik yürümeli: "karakter oluştur" deyince yönlere kadar 1 adetle her şeyi sıraya koymalı,
> onaya gerek yok. Base'lerden birini seçtiğimde portre, hikaye, yönler kendi oluşmaya başlamalı, hepsinden 1 adet kendi seçilmeli.
> Hepsi bitince kullanıcı görür, her yön altındaki yenile ile tek tek değiştirir. Bu kısımda animasyon yok.
> Her base standart bikini/underwear seviyesinde. Skin = kıyafet: kıyafet oluşturulur, sonra her yön giydirilir (2 görsel + prompt).
> Base'in kendisi de bir skin. Skinlerin her yönü olur, animasyon skin üstünde yapılır. Skin listesi = 1'deki karakter listesi gibi.
> "Görünüş seç" gereksiz: karakter kartında base'in South'u, skin listesinde skinin South'u görünür.

## 1. Kütüphane düzeni v2 (`character.root` = `C:\Reusable Assets\Realistic Women`)

```
<İsim>/
  character.json      {name, class, created, layout: 2, base: "base/base.png", portrait: "portrait/portrait.png",
                       prompt: {...}, padding, sprite_canvas, pipeline: {status: idle|running|done|error, op, started, finished, step}}
  card.md             hikaye kartı; card_proposals.json (öneriler, #299)
  candidates/         base adayları (bikini/underwear, Z-Image, Karakter Modu, neutral set)
  base/base.png       kabul edilen base = SOUTH görünüşü (kart görseli)
  base/dirs/<yön>.png            base'in 8 yönü (front.png = base.png kopyası) ; adaylar base/dirs/<yön>_NN.png
  portrait/portrait.png          KARE vesikalık (baş odaklı) ; adaylar portrait/portrait_NN.png
  skins/<slug>/skin.json         {slug, name, prompt, created}
  skins/<slug>/outfit.png        kıyafet referansı = giydirilmiş SOUTH (front) görseli
  skins/<slug>/dirs/<yön>.png    giydirilmiş 8 yön ; adaylar <yön>_NN.png
  skins/<slug>/anims/<yön>/<klip>/vNN/...   skin animasyonları (rev3 ile aynı iç düzen)
  anims.json          klip seti (sınıf preseti) — tüm skinler paylaşır
  anims/<yön>/<klip>/vNN/...    BASE skininin animasyonları (rev3 ile aynı)
```

Yön kimlikleri diskte değişmez (front/front_right/…); görünen adlar pusula (S/SE/E/NE/N/NW/W/SW, #301).
**Skin listesinde `base` da bir skindir** (slug `base`, dirs = `base/dirs/`, anims = `anims/`).

### Eski karakterlerin taşınması (layout 1 → 2, ilk `meta()` okumasında bir kez, geri dönüşsüz ama kayıpsız)
- `base/<slug>_base_master.png` → `base/base.png`; `character.json.base` güncellenir. Base yoksa `look` görseli base olur (kullanıcı sonra değiştirir).
- `outfits/<slug>_signature.png` + `turnaround/` (look'tan üretilmiş yönler) → `skins/signature/{outfit.png, dirs/}`; `anims/` → `skins/signature/anims/`
  (o animasyonlar signature görünüşünden üretildi). `dirs` alanı kaldırılır, `look` alanı kaldırılır.
- `base/dirs/` boş kalır; kullanıcı 2 Yön'de "Hepsini üret" der ya da pipeline `rebuild` çalıştırır.

## 2. Otomatik pipeline (sunucu, op kind `char-pipeline`) — BASE SEÇİMİYLE BAŞLAR

Kullanıcı kuralı: **base'i kullanıcı seçer** (Üretilenler'deki Karakter Modu görsellerinden ya da `candidates/`'tan); seçim anında
otomasyon başlar ve onaysız yürür.
- `POST /api/character/flow/create {name, class, job_id}` → karakter klasörü + o görsel base olur → pipeline op döner `{"name","op"}`.
  `job_id` yoksa (`prompt` verildiyse) yalnız 1 base adayı kuyruğa girer (`image_zimage`, Karakter Modu, neutral set) ve **otomatik
  seçilmez**; kullanıcı adayı "Base yap" ile seçince pipeline başlar. `prompt` da yoksa boş karakter (kullanıcı sonra aday ekler).
- `POST /pick {name, file, kind: "base"}` → `base/base.png` + `base/dirs/front.png`; eski `base/dirs/*`, `portrait/*`, kabul edilmemiş
  öneriler silinir; pipeline koşar, `{"name","kind","file","op"}` döner. `kind: "look"` → **400** ("look kaldırıldı, base seç").
- Pipeline adımları (hepsi 1 adet, otomatik kabul, comfy_gen kuyruğu `client="flow"`, `category=<isim>`):
  1. **Portre** (`edit_qwen`, PORTRAIT_PROMPT "tight head-and-shoulders passport-style portrait…") → çıktı üstten KARE kırpılır →
     `portrait/portrait_01.png` → `portrait/portrait.png`.
  2. **Hikaye**: `enrich` n=1 → öneri otomatik kabul → `card.md` (listede "KABUL").
  3. **Yönler**: 7 yön × 1 (`edit_qwen`, `yon_uret.PROMPTS`, #304) → `base/dirs/<yön>.png`.
  Op `total` = 1 + 1 + 7; `message` adımı söyler; `character.json.pipeline` güncellenir. Onay YOK.
- `POST /pipeline/rebuild {name, steps?: ["portrait","story","dirs"]}` → seçili adımlar yeniden.
- `POST /dirs {name, dirs, n, skin?: ""}` → `skin` boş = base yönleri, doluysa skin yönleri (§3). `POST /portrait {name, n}` → adaylar.
- `list` satırı: `{name, class, base, portrait, south_thumb: base, dirs (base'in), dir_candidates, dir_files, portraits, proposals, rev,
  pipeline: {...}, skins: [slug...], anims (base), candidates, candidate_files}` — `look`/`look_thumb` KALDIRILDI.

### İnce ayar: Düzenle (prompt ile) ve Yeniden üret
Kullanıcı ilk otomatik turdan sonra her öğeyi iki düğmeyle ayarlar:
- **Yeniden üret** (mevcut `dirs`/`portrait`/`skins/dirs`, n adet aday; tek adaysa otomatik kabul, birden çoksa seçici).
- **Düzenle**: `POST /api/character/flow/edit {name, target: "base"|"portrait"|"dir:<yön>"|"skin:<slug>:<yön>", prompt}` → op
  (`edit_qwen`, girdi = o hedefin KABUL EDİLMİŞ görseli, prompt = kullanıcının düzeltme cümlesi + KEEP kimlik/poz/fon cümlesi).
  Sonuç **otomatik kabul** edilir; eski görsel geri alınabilsin diye aday olarak saklanır (`<yön>_NN.png` / `portrait_NN.png` /
  base için `candidates/base_prev_NN.png`). Base düzenlenince pipeline adım 2-4 yeniden koşmaz (kullanıcı isterse `rebuild`).
Uygulama ve stüdyoda her yön/portre/base/skin-yön hücresinde **✎ Düzenle** (kısa prompt diyaloğu) ve **↻ Yeniden üret** bulunur.

## 3. Kıyafetler ve skinler (sunucu)

**Kıyafet kütüphanesi** karakterden bağımsızdır, `<root>/_outfits/<slug>.png` + `<slug>.json {slug, name, prompt, created}`; aynı kıyafet
birçok karaktere giydirilebilir, kullanıcı kıyafetleri saklar.
- `GET /outfits` → `{"outfits": [{slug, name, prompt, created, rel: "_outfits/<slug>.png"}]}` (thumb/file uçları `name="_outfits"` ile ya da
  ayrı `GET /outfits/thumb?slug=&size=` — ajan seçer, istemciler dokümandaki adı kullanır: **`GET /api/character/flow/outfits/thumb?slug=&size=`**).
- `POST /outfits/create {name, prompt}` → `{"slug","op"}` (op `char-outfit`, 1 iş): `image_zimage` (Karakter Modu değil, mode "free"),
  prompt = "<prompt>, a complete outfit displayed on an invisible ghost mannequin, front view, centered, plain solid flat uniform light
  gray seamless studio background, product photo, photorealistic, sharp focus" + negatif "person, face, hands, text, watermark".
  832×1472. `POST /outfits/edit {slug, prompt}` → ✎ (edit_qwen), `DELETE /outfit?slug=`.
- **Skin üret = kıyafet seçimi + karakterin base'i.** `POST /skins/create {name, outfit: <slug>, skin_name?}` → `{"slug","op"}`
  (op `char-skin`, total 1 + 7), skin slug = kıyafet slug'ı (aynı kıyafet tek skin; yeniden üretmek için önce sil):
  1. **South giydirme**: iki-görselli görev `wf_i2i_flux2_klein_9b_edit` (ComfyUI `I2I Flux2 Klein 9B Edit.json`, 2 LoadImage;
     `comfy_gen.workflow_inputs()` yuvalarını oku), girdiler = `base/base.png` + `_outfits/<slug>.png`, prompt = "Dress the woman in the
     first image in the outfit shown in the second image. Keep her face, hair, skin, body, standing pose, framing and background exactly;
     only the clothing changes." → `skins/<slug>/dirs/front.png` (otomatik kabul) ve `skins/<slug>/outfit.png` (kıyafet kopyası).
  2. **7 yön giydirme, sırayla**: aynı iki-görselli görev, girdiler = `base/dirs/<yön>.png` + giydirilmiş **South** (`dirs/front.png`),
     prompt = "Put the outfit worn by the woman in the second image onto the woman in the first image. Keep the first image's pose,
     camera angle, body, face, hair and background exactly; only the clothing changes." → `dirs/<yön>.png` otomatik kabul.
  9B VRAM'a sığmazsa `wf_i2i_flux2_klein_edit` (4B). Yuva sırası düğüm sırasına göredir — ajan doğrular ve "first/second" ifadesini ona
  göre yazar.
- `GET /skins?name=` → `{"skins": [{slug, name, outfit: <slug|"">, south: "<rel>", dirs: {yön: bool}, dir_candidates, dir_files,
  anims: {...}, rev}]}` — ilk eleman her zaman `base` (outfit "").
- `POST /skins/dirs {name, skin, dirs, n}` → seçili yönleri yeniden giydirir; `pick kind:"skin:<slug>:<yön>"` kabul eder, diğer adayları
  siler; `DELETE /skin?name=&skin=` (`base` silinemez). ✎ Düzenle: `edit target "skin:<slug>:<yön>"`.
- Animasyon uçlarına `skin: str = ""` alanı: `animate`, `anims_of`, `accept`, `version` (DELETE), `clip` (DELETE), `sprites`, `manken`.
  `skin=""` → base (`anims/`), doluysa `skins/<slug>/anims/`. Wan referansı = o skinin yön görseli. `list[].anims` base'i, `skins[].anims`
  her skini özetler.

## 4. Uygulama (Flutter, `app/lib/screens/character_flow_screen.dart` + servis)

Detay sekmeleri: **1 Karakter · 2 Yön · 3 Skinler**.
- **Liste**: kart görseli = base South (`base`), pusula rozetleri = base yönleri, `pipeline.status` çalışıyorsa ilerleme çubuğu,
  "skin N" sayacı. "Yeni karakter" akışı: isim + sınıf + kimlik prompt'u (veya Üretilenler'den iş) → `create` → op Sıra'da.
- **1 Karakter**: üstte portre (kare) + base (9:16) + sınıf; pipeline çubuğu; base adayları ızgarası → **"Base yap"** (tek düğme;
  "Görünüş yap" KALDIRILDI) → pick base → dönen op izlenir; "Yeni base adayı üret (n)"; portre adayları + "Portre üret"; hikaye
  önerileri paneli (#299) + "Hikayeyi zenginleştir". Yastıklama burada yok (#295).
- **2 Yön**: base'in 8 yönü pusula ızgarası (#292/#300 hücreleri, aday önizleme + rozet); her yönde yenile/sil; "Eksikleri üret";
  animasyon ikonları BURADA YOK (kullanıcı: bu kısımda animasyon yok). Hücre dokunma = aday seçici / büyük görüntü.
- **3 Skinler**: üstte **Kıyafetler** şeridi (kütüphane: küçük resim + ad; "+ Kıyafet üret" = ad + prompt → op; ✎ / sil), altında skin
  listesi (South thumb, ad, yön rozetleri, anim sayacı) — ilk satır **Base**; **"Skin üret"** = kıyafet seç (şeritten) → op (South +
  7 yön otomatik). Skin satırına dokun → skin detayı: pusula ızgarası (giydirilmiş yönler, yenile/sil/aday seç) + her yönde **anim / Mixamo**
  ikonları → mevcut animasyon ekranı `skin` bağlamıyla (i2v paneli, Mixamo paneli, sürümler, sprite; yastıklama seçici burada, #295).
  Servis: tüm animasyon çağrılarına `skin` parametresi.
- Snack/ilerleme: op'lar Sıra'da (#299); "Sıraya eklendi (N iş)".

## 5. Stüdyo (`C:\ComfyUI\scripts\uretim_studyosu.py`)
Aynı üç sekme: Karakter (portre + base adayları + öneriler), Yön (base pusulası, animasyon ikonları yok), Skinler (kıyafet kütüphanesi
şeridi + skin listesi + skin pusulası + animasyon; "Skin üret" = kıyafet seç). `look` kavramı ve "Görünüş yap" kalkar; kart görseli base South. Uçlar §2-§3.

## 6. Kurallar
- İstisnasız her iş kuyruk/şeritte (#299); ilk tur TAM otomatik (her şeyden 1 adet, otomatik seçim); kullanıcı bittiğinde Düzenle / Yeniden üret ile ince ayar yapar.
- Base her zaman bikini/underwear seviyesi (neutral set); base'i KULLANICI seçer, gerisi otomatik. Kıyafet karakterden bağımsız, yeniden kullanılabilir; skin = kıyafet + base.
- Geriye uyumluluk: eski `look`/`turnaround` verisi `skins/signature` olarak korunur, silinmez.
