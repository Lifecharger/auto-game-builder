# Karakter hattı v2 — Base → Yönler → Skinler (2026-09-08, AGB #305-#307)

`design/karakter_modu.md` (rev3) üzerine gelen yeniden tasarım. Kullanıcı tarifi:

> Sıra bu olmalı: önce base + portre (vesikalık gibi, sadece yüz). Sonra base'in yönleri (2. adım).
> 3. adım skinler. İlk adım otomatik yürümeli: "karakter oluştur" deyince yönlere kadar 1 adetle her şeyi sıraya koymalı,
> onaya gerek yok. Base'lerden birini seçtiğimde portre, hikaye, yönler kendi oluşmaya başlamalı, hepsinden 1 adet kendi seçilmeli.
> Hepsi bitince kullanıcı görür, her yön altındaki yenile ile tek tek değiştirir. Bu kısımda animasyon yok.
> Her base standart bikini/underwear seviyesinde. Skin = kıyafet: kıyafet oluşturulur, sonra kullanıcı skin sayfasından yönleri South'tan döndürtür (#328/#329: tek görsel, Qwen Edit).
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
  2. **7 yön (#328; #329: artık `POST /skins/dirs` ile kullanıcı tetikler, skin oluşturmada koşmaz)**: giydirilmiş **South** (`dirs/front.png`) tek görselli Qwen Image Edit "döndür" işine girer —
     base yönlerini üreten `_yon_job` ile birebir aynı (yön kamera cümlesi + KEEP "exact same outfit and accessories" kilidi)
     → `dirs/<yön>.png` otomatik kabul. Base yönleri skin için girdi DEĞİLDİR. Eski iki-görselli "base yönü + giydirilmiş South"
     giydirmesi yön değiştiremiyordu: ön yönlerde South'u kopyalıyor, yan/arka yönlerde çıplak base'i bırakıyordu (task #328).
  9B VRAM'a sığmazsa `wf_i2i_flux2_klein_edit` (4B). Yuva sırası düğüm sırasına göredir — ajan doğrular ve "first/second" ifadesini ona
  göre yazar.
- **#329 Kıyafet çıkar**: `POST /outfits/extract {name, category?, kind?, job_id? | rating+stage+item_id, note?}` → `{"slug","op"}`.
  Kaynak: her kipten comfy_gen işi (Üretilenler galerisi, tek seçim) YA DA Jigsaw akışı incoming/staging/pushed öğesi. edit_qwen tek
  görsel, kuyruk; kişi silinir, kıyafet içi boş (görünmez manken) ürün karesi olarak `_outfits/<slug>.png` yazılır (`source` alanı kayıtta).
  Uygulama: galeri araç çubuğu + Jigsaw akışı alt çubuğu "Kiyafet cikar" düğmesi, ortak `showOutfitExtractDialog`.
- **#329 Kıyafet şeridi**: kıyafete TEK dokunuş menü açar (skin üret / düzenle / sil); dokunur dokunmaz skin başlamaz.
- `GET /skins?name=` → `{"skins": [{slug, name, outfit: <slug|"">, south: "<rel>", dirs: {yön: bool}, dir_candidates, dir_files,
  anims: {...}, rev}]}` — ilk eleman her zaman `base` (outfit "").
- `POST /skins/dirs {name, skin, dirs, n}` → seçili yönleri yeniden giydirir; `pick kind:"skin:<slug>:<yön>"` kabul eder, diğer adayları
  siler; `DELETE /skin?name=&skin=` (`base` silinemez). ✎ Düzenle: `edit target "skin:<slug>:<yön>"`.
- Animasyon uçlarına `skin: str = ""` alanı: `animate`, `anims_of`, `accept`, `version` (DELETE), `clip` (DELETE), `sprites`, `manken`.
  `skin=""` → base (`anims/`), doluysa `skins/<slug>/anims/`. Wan referansı = o skinin yön görseli. `list[].anims` base'i, `skins[].anims`
  her skini özetler.


## 3b. Gardırop v2 — kategoriler ve parça kombinasyonu (AGB #312-#313)

Kullanıcı: "kıyafet kısmını kategorilendirelim: üst, alt, çorap, aksesuar, ayakkabı, set, silah, şapka, kafalık… birkaç parçayı
birlikte seçme (üste tişört, alta etek), set üretimi de olsun set olmayan da". Hot modifier ve şablonlar #312'de eklendi.

**Kütüphane kaydı** `_outfits/<slug>.json`: `{slug, name, prompt, style: ""|"hot", template, category, created}`.
Kategoriler (sabit id'ler): `set, top, bottom, shoes, socks, accessory, hat, headgear, weapon, other`. Kategorisi olmayan eski kayıt = `set`.
- Üretim prompt'u kategoriye göre: giysi/ayakkabı/çorap/şapka → "a <parça>, displayed on an invisible ghost mannequin, front view,
  centered, plain light gray seamless background, product photo"; `weapon`/`accessory`/`headgear` → "a <parça>, product photo, centered,
  plain solid light gray seamless background, no person, no mannequin". Hot modifier yalnız giysi kategorilerine eklenir.
- `OUTFIT_TEMPLATES` her şablona `category` alır; yeni şablonlar: **top** (tişört, crop top, bluz, korse, askılı, kazak, ceket),
  **bottom** (mini etek, jean, şort, tayt, uzun etek, deri pantolon), **shoes** (topuklu, çizme, spor ayakkabı, diz üstü çizme),
  **socks** (jartiyerli çorap, diz altı çorap, file çorap), **hat** (cadı şapkası, taç, tiara, bere, şapka), **headgear** (tavşan kulağı,
  kedi kulağı, boynuz, hale, saç bandı), **accessory** (kolye, gözlük, eldiven, kanat, pelerin, atkı, kemer, küpe), **weapon** (kılıç,
  büyük kılıç, hançer, asa, yay, mızrak, balta, kalkan, tabanca, tüfek, orak, çekiç). Mevcut günlük/fantastik/etkinlik şablonları = `set`.
- `GET /outfits?category=` (boş = hepsi) ve `GET /outfits/templates` → `{"categories": [{id,label}], "templates": [{id,label,group,
  category,prompt}], "styles": [...]}`; `POST /outfits/create {name, prompt, style, template, category}` (şablon seçildiyse kategori
  şablondan gelir).

**Skin üret = set VEYA parça kombinasyonu (+ base).** `POST /skins/create {name, skin_name?, outfit?: <set slug>, pieces?: [slug…]}`
→ `{"slug","op"}`; slug = `skin_name` slug'ı, yoksa set slug'ı, o da yoksa parçalardan türetilir (`top_x+bottom_y`).
- Op adımları (hepsi kuyrukta, otomatik kabul): South = base; `outfit` varsa önce set giydirilir (iki-görselli, §3); sonra `pieces`
  kategori sırasıyla **sırayla** uygulanır: top → bottom → socks → shoes → hat → headgear → accessory(ler) → weapon(lar); her parça bir
  iki-görselli düzenleme (girdi 1 = o anki South, girdi 2 = parça görseli) ve kategoriye özel prompt:
  giysi: "Put the <kategori adı> from the second image on the woman in the first image; keep her face, hair, skin, body, pose,
  framing, background and all her other clothing exactly; only add/replace that garment." · hat/headgear: "…on her head…" ·
  accessory: "…wear the accessory from the second image…" · weapon: "…hold the weapon from the second image in her hand(s) in a
  natural ready grip; keep pose otherwise…". **#329: yön üretilmez** — skin oluşturma South'ta biter, op `total` = adım sayısı. 7 yön skin sayfasındaki "Eksikleri uret" ile (`POST /skins/dirs`, §3.2) South'tan üretilir.
- `skin.json`: `{slug, name, outfit, pieces: [...], created}`; `GET /skins` satırları `outfit` ve `pieces` taşır.
- ✎ Düzenle / ↻ Yeniden üret skin yönlerinde aynen; ayrıca South'u tek parçayla yeniden giydirmek için `POST /skins/dirs` `dirs: ["front"]`.

**Uygulama / stüdyo:** Kıyafetler şeridi kategori çipleriyle süzülür (Hepsi · Set · Üst · Alt · Ayakkabı · Çorap · Şapka · Kafalık ·
Aksesuar · Silah); "Kıyafet üret" penceresinde kategori seçimi + o kategorinin şablonları + prompt + Hot. **"Skin üret"** bir
**birleştirici** açar: skin adı; "Set" satırı (bir set seç ya da boş); kategori satırları (top/bottom/shoes/socks/hat/headgear tek
seçim, accessory/weapon çoklu); en altta özet ("base + set X + tişört + etek + kılıç") ve Üret → `skinCreate(name, skinName, outfit,
pieces)` → snack "Sıraya eklendi (N iş)".


## 3c. Karakter türü — Female (varsayılan) · Male · Animal · Machine (AGB #314)

Kullanıcı: "Yeni karakter derken Female, Male, Animal, Machine desek ve ona göre üretsek? Oyunda köpek lazım olursa gibi. Female
varsayılan. Kıyafet üretimi de her kategorinin (türün) kendi içinde olsun."

**Veri:** `character.json.kind ∈ {female, male, animal, machine}` (yoksa `female`). `create {name, class, kind, prompt|job_id}`;
`list` satırları `kind` taşır. Kütüphane kökü aynı; tür klasör değil alan.

**Prompt'lar türe göre** (sunucu `KIND_PROFILES[kind]`, tek yerde):
| | female | male | animal | machine |
|---|---|---|---|---|
| özne | "woman" | "man" | kullanıcının kimlik prompt'undaki hayvan ("dog", "wolf"…) yoksa "animal" | "robot" |
| base nötr set | siyah bikini (mevcut) | siyah boxer, çıplak gövde | giysisiz, doğal tüy/deri, dört ayak üstünde ya da doğal duruş | çıplak gövde/şasi, ek zırh ve boya yok |
| KEEP kilidi | "same woman: face, hair, skin, body" | "same man: face, hair, beard, skin, body" | "same animal: species, fur pattern, colours, body shape" | "same robot: chassis shape, panels, joints, colours" |
| portre | baş-omuz vesikalık | aynı | baş yakın plan (kafa + boyun) | kafa/sensör ünitesi yakın plan |
| yönler | mevcut PROMPTS (özne ve zamir `{subject}`/`{pron}` ile üretilir) | aynı | "the {animal}"; profil/arka açıklamaları aynı mantık | "the robot" |
| hikaye | mevcut | mevcut | "hayvan karakter: tür, huy, sahibi/rolü" | "makine: model, işlev, yapımcısı" |
| animasyon | manken + Wan + i2v | aynı | yalnız i2v (manken/Mixamo insansı) — Mixamo düğmeleri gizli | yalnız i2v (insansı mech ise kullanıcı açar) |
Kural: `feedback_no_minors_no_chibi` her türde geçerli (yetişkin insan; hayvan/makine için çocuksu/chibi yok).

**Gardırop türe göre:** kıyafet kaydında `kind` alanı (yoksa `female`); `GET /outfits?kind=&category=`; `POST /outfits/create` +`kind`.
Üretim prompt'u: female/male → hayalet manken (male için "male ghost mannequin"); animal → "pet costume / harness / collar / bandana /
cape sized for a <animal>, displayed on an invisible animal mannequin, product photo"; machine → "attachment kit for a robot: armor
plating / paint scheme / weapon mount / antenna / jetpack, product photo, no robot". Şablonlar `kind` alır: mevcutlar female;
**male** (tişört-jean, takım elbise, deri ceket, şövalye zırhı, büyücü cübbesi, okçu, barbar, Santa, korsan, polis, itfaiyeci, doktor…),
**animal** (tasma, koşum, bandana, pelerin, şapka, Santa kostümü, süper kahraman pelerini, zırh, eyer, kanat), **machine** (zırh plakası,
boya kiti, silah montajı, anten, jetpack, kalkan jeneratörü, LED şeridi). Hot modifier yalnız female/male giysilerinde.
Skin birleştirici karakterin türüne göre süzer; giydirme prompt'ları özneyi türden alır ("Put the harness from the second image on the
dog in the first image…").

**Uygulama / stüdyo:** "Yeni karakter" (ve Üretilenler'den "Karakter yap") penceresinde **Tür** seçimi (Kadın · Erkek · Hayvan · Makine),
varsayılan Kadın; sınıf listesi türe göre (hayvan: pet/mount/beast; makine: drone/mech/turret; insan: mevcut). Karakter kartı ve detay
başlığında tür rozeti. Kıyafetler şeridi ve "Kıyafet üret" penceresi karakterin türüne kilitli (tür seçici gösterir, varsayılan karakterin
türü). 3 Skinler'de animasyon düğmeleri türe göre (animal/machine: yalnız i2v).

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
  #329: yalnız South otomatik, yönler skin sayfasından). Skin satırına dokun → skin detayı: pusula ızgarası (giydirilmiş yönler, yenile/sil/aday seç) + her yönde **anim / Mixamo**
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

## #330/#331 — 4 sekme, Gardırop + RPG giydirme (2026-09-09)
- Karakter sayfası **4 sekme**: `1 Karakter · 2 Yön · 3 Gardırop · 4 Skinler`. Stüdyoda da aynı (WardrobePanel + SkinPanel).
- **3 Gardırop**: üstte **RPG giydirme paneli** — ortada seçili base'in South'u, solda yuvalar (Kafa=hat, Kafalık=headgear, Üst, Alt, Çorap),
  sağda (Set, Ayakkabı, Kolluk/Aksesuar=accessory çoklu, Silah çoklu). Yuvaya dokun → o kategorinin 3'lü seçicisi; basılı tut → büyüt.
  **Base seçici** (aynı türdeki karakterler): skin, seçili karakterin olur. Altında `Skin üret (South)` + `Kıyafet çıkar`; altında
  kategori çipleri + **katalog 3'lü ızgara** (dokun = menü: giydir/büyüt/skin üret/düzenle/sil; basılı tut = büyüt).
- **Skin üret** = `POST /skins/create {name: <base seçici>, skin_name?, outfit: <set yuvası>, pieces: [<yuvalar giydirme sırasıyla>]}` →
  yalnız South (#329). **4 Skinler** yalnız base + skinler; yönler skin sayfasından.
- Uygulama: `widgets/equip_panel.dart` (EquipSelection, EquipPanel, OutfitCatalogGrid, showSlotPicker, showOutfitPreview,
  pickGeneratedImage), `character_flow_screen.dart` `_tabGardirop/_makeSkinFromEquip/_extractFromWardrobe`.
  Stüdyo: `WardrobePanel` (katalog satırda 8), `SkinComposer` base seçici (`base_var`).

## #334 — Skin sayfasında "South'u daha da düzenle" (2026-09-09)
- Skin detayı > Yönler, pusulanın altında bağımsız düğme. Dialog: düzeltme cümlesi + isteğe bağlı kıyafet (3'lü katalog, aynı tür).
- `POST /skins/edit {name, skin, prompt, outfit?}` → op (`char-edit`). `outfit` boşsa `edit(name, "skin:<slug>:front", prompt)` (tek görselli
  edit_qwen + KEEP kilidi); doluysa iki görselli giydirme (Görsel 1 = South, Görsel 2 = kıyafet) + cümle + kategoriye özel parça istemi
  (`piece_prompt`, tam boy/başlık koruma kilidi dahil). Sonuç otomatik kabul, eski South `dirs/front_NN.png` adayı olarak saklanır.
- Base skini: yalnız metin (`dir:front`); kıyafet için Gardırop'tan yeni skin. Yönler değiştikten sonra South'tan yeniden üretilmeli.
- Stüdyo: 4 Skinler çubuğunda "South'u duzenle (+kiyafet)" (Api.char_skin_edit). Uygulama: `_editSouthFurther`, `skinEditSouth`.
