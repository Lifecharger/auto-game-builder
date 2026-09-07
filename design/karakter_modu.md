# Karakter Modu — üretim hattına 4. kip (2026-09-08, rev3: 8 YÖN + yuvarlak Yön ekranı + 2 animasyon yolu)

Hot Clash pivotu (Almost a Hero tarzı 2D idle kadın battler) ve sonraki oyunlar için **isimli, gerçekçi, yeniden kullanılabilir
kadın karakterler** üretir. Diğer kiplerin (Jigsaw/CBN) kabul-etiket-push kalıbını **kopyalamaz**; kendi üç aşamalı akışı vardır:

1. **Karakter** — aday üret → birini kabul et → isim ver → karakter klasörü oluşur.
2. **8 Yön** — kabul edilen görselden 8 görünüş (Qwen Image Edit 2511): front, front_right, right, back_right, back, back_left, left, front_left → her yön için aday seç (front = kabul edilen görselin kendisi).
3. **Animasyonlar** — sınıf presetinden klip seti → her yön için manken (Blender) → Wan Animate 2 → **kabul/ret** → kabul edilen video
   karelere ayrılır → **SAM3 her karede karakteri ayrıştırır** (CBN'deki SAM3 altyapısı, prompt "woman"; isnet yalnız yedek/kenar rötuşu)
   → WebP anim + sheet.

Kanıtlanmış zincir (2026-09-07, Freya): Z-Image base → Mixamo manken → Wan Animate 2 → isnet → WebP. Scriptler
`tools/character/` altında (ComfyUI/scripts'ten taşındı): `mixamo_manken_render.py` (Blender 5.2 headless), `wan_animate2.py`,
`sprite_cikart.py`, `yon_uret.py`, `karakter_adaylari.py`. Sunucu bunları **kütüphane** olarak çağırır (CBN'de kid_cbn/hot_cbn gibi). SAM3 kare-kare ayrıştırma için `tools/comfyui/kid_cbn.py`'deki
SAM3 yükleme/maske kodu paylaşılır (yeni `tools/character/sam_frames.py`).

## Kütüphane düzeni (`character.root`, varsayılan `C:\Reusable Assets\Realistic Women`)
```
<İsim>/
  card.md                 isim, yaş, köken, hikâye, kişilik, rol, görünüm kilidi (Freya/Vesper/Ivy örnekleri mevcut)
  character.json          {name, class, created, look: "outfits/<x>.png", base: "base/<x>.png", prompt: {...}, dirs: {front,...,front_left}}
  candidates/             üretilen adaylar (kabul edilmemiş)
  base/<name>_base_master.png      nötr kimlik görseli (siyah bikini, beyaz fon) — isteğe bağlı
  outfits/<name>_signature.png     animasyona giren görünüş (kostüm)
  turnaround/{front,front_right,right,back_right,back,back_left,left,front_left}.png   + adaylar right_01.png ...
  anims.json              klip seti: prop, canvas, groups, clips{fbx,pose,prop}
  anims/<yön>/<klip>/            YÖN üst klasördür: kullanıcı bir yöne tıklayınca o yönün animasyonlarını görür
      v01/{manken.mp4, manken.json, wan.mp4, wan.json(seed,prompt)}   her "üret" yeni bir sürüm açar, sınırsız
      v02/...
      meta.json              {"accepted": "v02"}  kabul edilen sürüm (tek); ret edilenler silinmez, sadece kabul değildir
      frames/*.png, anim.webp, sheet.png, sprite.json   yalnız kabul edilen sürümden üretilir (SAM3 kare kare)
```
8 yön ve manken kamera azimutu (saat yönü, karakterin SAĞINA doğru): front 0°, front_right 45°, right 90°, back_right 135°, back 180°,
back_left 225°, left 270°, front_left 315° (mannequin `facing()` ile klip yönü normalize edilir). Sabit sıra: DIRS listesi sunucuda tek yerde tanımlı (`character_flow.DIRS`), uygulama bu sırayı sunucudan alır (`GET /api/character/flow/dirs_list`).
Her yönün Wan referansı = o yönün turnaround görseli (kırpma yok, `letterbox` kenar-uzatma ile kare tuvale).

## Sunucu (`server/core/comfy_gen.py`, yeni `server/core/character_flow.py`)
- `MODES["character"]`: label "Karakter Modu", profiles "character", aspects False, 832×1472 varsayılan (still).
  **Pozitif 2 şablonu** (kullanıcı şartı: fon hem still hem videoda kolay silinebilsin):
  `"{} standing straight facing the camera, neutral relaxed pose, arms at her sides, full body from head to feet with empty
  space above and below, plain solid flat uniform light gray seamless studio background, no floor shadow, no gradient, even
  soft lighting, photorealistic, sharp focus, 85mm"` — `{}` = 1. prompt (kimlik + kostüm). Video pose-prompt'larında da aynı fon cümlesi.
- Profil dosyası `server/config/character_options.json` (app'te `assets/karakter_secenekler.json` kopyası): class (warrior/mage/archer/rogue/healer/...),
  hair, eyes, skin, body, outfit, prop (sword/staff/bow/dagger/none), set (neutral|costume). Seçimler 1. prompta eklenir (Jigsaw'daki MERGE mantığı).
- `character_flow.py` op defteri jigsaw/cbn ile ortak (`/op/{id}`). Uçlar:
  - `GET  /api/character/flow/list` → [{name, class, look_thumb, dirs:{front..left: bool}, anims:{clip:{dir:{manken,wan,sprite}}}, candidates:n}]
  - `POST /api/character/flow/create {name, class, job_id | file}` → klasör ağacı, character.json, card.md iskeleti, anims.json = sınıf preseti
  - `POST /api/character/flow/stage {name, job_ids}` → job çıktılarını `candidates/`'a kopyala
  - `POST /api/character/flow/pick {name, file, kind: look|base|dir:<yön>}`
  - `GET  /api/character/flow/dirs_list` → [{id, label, azimuth}] 8 yön, sabit sıra
  - `POST /api/character/flow/dirs {name, dirs:[...7 yön...], n}` → op: yon_uret (Qwen Edit; 3/4 yönler için "three-quarter view from her front-right" gibi net kamera cümleleri) → `turnaround/<yön>_<nn>.png`
  - `GET/PUT /api/character/flow/anims {name}` → anims.json; `GET /api/character/flow/mixamo?q=` → arşivde klip ara (1975 FBX)
  - `POST /api/character/flow/manken {name, clips, dirs}` → op (Blender, CPU; gpu seridi ALMAZ)
  - `POST /api/character/flow/animate {name, dir, clips, n}` → op (Wan Animate 2; **gpu_lane** üzerinden, tek tek; kuyruk kontrolü); her klip için n YENİ sürüm (v03, v04...) açar, manken yoksa önce render eder
  - `GET  /api/character/flow/anims_of?name=&dir=` → o yönün klipleri ve sürümleri [{clip, versions:[{v, has_wan, seed}], accepted, has_sprite}]
  - `POST /api/character/flow/accept {name, dir, clip, version}` → meta.json accepted (yeniden kabul serbest; eski sprite silinir)
  - `DELETE /api/character/flow/version {name, dir, clip, version}` → sürümü sil
  - `POST /api/character/flow/sprites {name, dir, clips}` → op (kabul edilmiş sürümler: ffmpeg kareler → SAM3 kare kare maske (gpu_lane, tek yükleme ile parti) → RGBA kareler → anim.webp + sheet.png)
  - `GET /api/character/flow/thumb|file?name=&rel=` ; `GET/PUT /api/character/flow/card {name}`
  - Aşamalı parti kuralı (CBN #281 gibi): bir aşama seçili tüm klip×yön için toplu koşar; model yükle/boşalt tekrarı olmaz.
- Sınıf presetleri `server/config/character_presets.json`: warrior (Great Sword Idle/Slash/High Spin/Impact + Falling Back Death + Cheering, prop sword 0.95),
  mage (Standing Idle 01 / Standing 1H Magic Attack 01 / Standing 2H Magic Area Attack 01 / Hit Reaction / Standing Death Backward 01 / Cheering, staff 1.5),
  archer (Standing Aim Idle 01 / Standing Aim Recoil / Standing Aim Overdraw / Hit Reaction / Standing Death Forward 01 / Cheering, bow 1.4).
  Klip adları Mixamo arşivindeki tam dosya adı (`[hash]` ekli). Gruplar: stand = idle/attack/hit ortak tuval; skill, death, win ayrı.

## Uygulama (Flutter, `app/lib`)
- `GenerateMode` listesine sunucudan gelen "character" (profiles=character) — Üretim ekranında sınıf/set + detay dropdown'ları.
- Üretilenler: "Karakter Modu" filtresi; seçili işlerde **"Karakter yap"** (yeni isim → create) ve **"Adaylara ekle"** (mevcut karakter → stage).
- Hat (FlowHub): Jigsaw | CBN | **Karakter** → `CharacterFlowScreen`:
  - Liste: karakter kartları (look thumb, sınıf, 8 yön rozeti (pusula düzeni), animasyon ilerleme).
  - Detay sekmeleri: **1 Karakter** (adaylar ızgarası → Görünüş yap / Base yap; kart düzenle), **2 Yön** (8 kutu, pusula/ızgara düzeni; her yön için aday üret (n), seç, yeniden üret; "Hepsini üret"),
    **3 Animasyon**: önce 8 yön düğmesi (pusula düzeni, her birinde kabul edilmiş/toplam sayaç) → bir yöne tıklayınca O YÖNÜN klip listesi;
    her klip satırı sürümlerini (v01, v02…) küçük video kartları olarak gösterir: oynat, **Kabul et** (tek kabul), Sil, **+ Üret (n)** yeni sürüm;
    üstte parti düğmeleri: **Üret** (seçili klipler × n), **Sprite çıkar** (kabul edilmiş olanlar); klip ekle/çıkar, Mixamo ara; sprite hazırsa anim.webp önizleme.
- Op'lar `/op/{id}` ile izlenir (CBN ekranındaki aynı bileşen). `flutter analyze` 0 hata.

## Masaüstü stüdyosu (`C:\ComfyUI\scripts\uretim_studyosu.py`)
- Kip radyosu sunucudan otomatik gelir. Akış sekmeleri: Karakter kipinde 2-3-4 yerine **Karakter / Yön / Animasyon** (aynı uçlar, aynı op takibi; 8 yön).

## Notlar
- ComfyUI paylaşımlı: her GPU işi kuyruğa, restart yok (memory: feedback-comfyui-shared). Wan işleri sırasında RAM 2 GB'a düşüyor; sayfalama 32-64 GB sabitlendi.
- Blender: `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` (FFMPEG çıktısı yok → PNG + ffmpeg). isnet modeli `~/.u2net/isnet-general-use.onnx`, onnxruntime ComfyUI venv'inde.
- Manken kamera: kare tuval (640), pad 0.06, `sensor_fit=VERTICAL`; prop uç noktası bbox'a dahil; skill ayrı tuval (spin 4.5 m'ye açılıyor).
- Freya/Vesper/Ivy klasörleri ve anims.json'ları hazır örnek veridir; `Freya/anim_tests/` prototip çıktıları.


## rev3 (2026-09-08 01:00) — kullanıcının Yön ekranı tarifi (bağlayıcı)

**Tam karakter üretimi:** bir karakterin *base* (nötr kimlik, tam boy), *portre* (baş-omuz yakın plan) ve *tam boy görünüş (look)* sürümleri
olmalı; hikâyesi (card.md) olmalı ve **Ollama ile zenginleştirme** düğmesi olmalı (`POST /api/character/flow/card/enrich {name}` →
yerel Ollama `gemma3:12b`, girdi: sınıf + prompt + mevcut kart; çıktı: kartın hikâye/kişilik/rol bölümlerini genişletir; kullanıcı onaylar).
Portre: `POST /api/character/flow/portrait {name, n}` → Qwen Image Edit ile look'tan "head and shoulders portrait, same face" → `portrait/portrait_NN.png`, seçilen `portrait.png`.

**Yön ekranı = YUVARLAK düzen:** ortada base karakter (ve altında/yanında portre), çevresinde pusula gibi 8 yön küçük resmi
(küçük görünebilir; basınca büyük açılır). Her yönde **Kabul / Ret** durumu (kabul edilmemiş yön animasyona giremez).
Her küçük resmin (8 yön + base + portre) ALTINDA 4 küçük İKON düğme, yazı yok:
1. 🎞 **Film şeridi = "Anim üret"**: saf AI i2v (Wan 2.2 i2v / LTX-2.5 i2v, mevcut comfy_gen video hattı). Prompt = kullanıcının yazdığı hareket +
   kipin **pozitif 2 video şablonu** ("static locked camera, the character stays fully inside the frame from head to feet at all times,
   never leaves or touches the frame edges, plain solid flat uniform light gray seamless background, no floor shadow, even lighting").
   Uç: `POST /api/character/flow/animate {name, dir, mode: "i2v", prompt, n, engine?}` → aynı sürüm klasörü düzeni (`anims/<yön>/<klip>/vNN`, klip adı kullanıcı verir veya prompt'tan türetilir).
2. 🦴 **3D iskelet = "Mixamo ile üret"**: manken yolu (bu dokümandaki Blender → Wan Animate 2 zinciri). Klip Mixamo kütüphanesinden (1975 FBX) seçilmek zorunda:
   **arama kutusu + liste** (`GET /api/character/flow/mixamo?q=`), seçilen klip(ler) + n → `POST animate {mode: "mixamo", clips, n}`.
3. 🔄 **Yenile = yalnız o yönü yeniden üret** (`POST dirs {name, dirs:[tek yön], n}`; base/portre için de aynı: base → yeniden aday, portre → `portrait`).
4. 🗑 **Çöp = sil** (o yönün görselini/adayını siler; `DELETE /api/character/flow/dir {name, dir}`).
Her düğme, kullanıcı beğenene kadar defalarca basılabilir; yeni üretim eskisini silmez, aday listesine ekler (kabul edilen tek).
Animasyon üretme düğmeleri **animasyon ekranını** o yön seçili açar (3. sekme, yön filtreli).

Sunucu ekleri: `POST card/enrich`, `POST portrait`, `DELETE dir`, `animate.mode = i2v | mixamo`, `GET mixamo?q=` (ad + hash, sayfalı).
Masaüstü stüdyo aynı yuvarlak düzeni ve 4 ikonu uygular.

## rev4 (2026-09-08 01:10) — dokunma davranışı ve animasyon ekranı
- Küçük resim (8 yön + base + portre): **tek dokunuş = o yönün animasyon ekranını aç** (yön filtreli 3. sekme); **basılı tutma = büyük göster**
  (tam ekran önizleme). 4 ikon düğme bunun dışında, kendi işlevleriyle.
- **Her karakterin her yönü ayrı animasyon kümesidir**: `anims/<yön>/<klip>/vNN` zaten yön altında; ekran da yön başına listeler, yönler arası karışmaz.
- Animasyon ekranında telefon **anim.webp**'yi gösterir (döngü); her WebP kartının ALTINDA düğmeler: **▶ Videoyu izle** (kabul edilen sürümün wan.mp4'ü,
  `GET file?rel=anims/<yön>/<klip>/vNN/wan.mp4`), **Sürümler** (v01, v02… kabul et / sil / +üret), **Sprite'ı yeniden çıkar**, **Sil**.
  Sprite henüz yoksa kart kabul edilen sürümün ilk karesini gösterir ve "Sprite çıkar" düğmesi öne çıkar.

## rev5 (2026-09-08 01:30) — "Yastıklama ile üret" seçeneği
- Animasyon üretirken (özellikle 🎞 i2v yolunda) **Yastıklama** seçeneği: yok / %10 / %20 / %30 (`animate.padding`, 0-0.3).
  Referans görsel kenar-uzatma (edge-replicate, band bırakmaz) ile küçültülüp tuvale yerleştirilir → karakter tuvalin daha azını kaplar,
  hareket için pay kalır, kadraj dışına taşma azalır. %20 ve üstünde tuval 832×832'ye çıkar (karakter küçüldüğü için çözünürlük telafisi).
- Manken yolunda yastıklama zaten otomatik (birleşik bbox + pad); seçenek yalnız ek pay ekler.
- Sprite çıkarma tuvali kırpmaz; yastıklama tüm klipler için aynı tutulmalı (karakter başına varsayılan `character.json`'da saklanır).

## rev6 (2026-09-08) — yastıklamalı kliplerde SAM sonrası ölçek eşitleme
- Sprite aşaması, arka plan gittikten SONRA kareleri normalize eder: RGBA kare, **sabit kenar payı** kadar kırpılır (içerik bbox'ına göre DEĞİL;
  pivot ve karakter ölçeği tüm kliplerde aynı kalsın), sonra karakterin standart sprite tuvaline (`character.json` `sprite_canvas`, vars. 640) ölçeklenir.
  Yastıklamasız kliplerle aynı kare boyutu ve aynı karakter büyüklüğü elde edilir; WebP + sheet bundan üretilir.
- Büyütme: RGB için ComfyUI upscale modeli (4x-UltraSharp/RealESRGAN, models/upscale_models) gpu_lane içinde parti halinde; alfa kanalı Lanczos ile ayrı ölçeklenip
  birleştirilir. Küçültmede düz Lanczos. `sprite.json` içine `padding`, `scale`, `canvas` yazılır.

## rev7 (2026-09-08) — silah/uzantı kesilmez
- Kırpma hiçbir zaman içerik kesmez: karakter ÖLÇEĞİ sabittir (yastıklamadan türetilir), ama kesim sonrası tüm karelerin **alfa birleşim kutusu**
  standart tuvala sığmıyorsa karakter küçültülmez; **tuval pivot etrafında simetrik büyütülür** (örn. 640×640 → 640×768 veya 768×640).
  Pivot = tuval merkezi (ayak çizgisi meta'da), oyun tuval boyutunu `sprite.json`'dan okur. Aynı karakterin klipleri farklı tuval boyutunda olabilir ama aynı ölçek ve pivottadır.
- SAM istemi silahı kapsar: karakter sınıfının prop'una göre "woman holding a sword/staff/bow"; ayrıca "sword"/"staff"/"bow" maskesi ayrıca alınıp
  karakter maskesiyle BİRLEŞTİRİLİR (bağlantılı bileşen: karakter maskesine değen parçalar). Kopuk parçalar (ok, mermi) da kliple aynı tuvalde kalır.

## rev8 (2026-09-08) — Ollama animasyon asistanı
- `POST /api/character/flow/prompt/expand {name, dir, text, mode}` → yerel Ollama (`gemma3:12b`, gpu_lane dışı kısa istek):
  - `mode: i2v` → `{prompt}`: kullanıcının kısa isteğini ("idle", "tekme", "zafer") karakterin sınıfı/silahı/yönü/görünüşüyle tam bir hareket tarifine
    genişletir (yalnız vücut hareketi; kamera, fon, yeni nesne, kıyafet değişimi YASAK — sistem istemi). Sabit kamera + düz fon şablonu KOD tarafından sonuna eklenir.
  - `mode: mixamo` → `{clips: [{name, hash, filename, why}]}`: 1975 klip adında anahtar kelime araması + Ollama sıralaması, en iyi 8 aday.
- Uygulama/stüdyo: animasyon diyaloğunda "Ollama ile genişlet" (sihirli değnek ikonu); sonuç DÜZENLENEBİLİR metin kutusuna gelir, kullanıcı onaylayıp gönderir.
  Mixamo diyaloğunda kısa istek → aday listesi → seçim. Ollama yoksa düğme pasif, düz metin akışı çalışmaya devam eder.
