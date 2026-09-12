# Kart Modu — Hot Card Games koleksiyon kartları, yerel hat (2026-09-08, AGB #321-#324)

## Current animation and delivery contract (2026-09-12, #363, #368-#370)

- MiniMax H3 is the default engine. Explicit collection engine choices remain supported;
  unavailable engines fail visibly instead of silently using another model.
- Idle uses one moderate gesture over 6 seconds. Victory uses one compact celebration
  over 2 seconds. Hands remain below shoulders, elbows near the torso, and all visible
  body parts remain within the reference framing. The final pose returns to the reference.
- MiniMax's native 17k+5 frame grid is mapped from the requested duration at 24 fps;
  final tag videos are timed to exactly 6/2 seconds. WebP victory sheets contain 24 frames
  at 12 fps in a 12x2 grid. Idle uses 72 frames in a 12x6 grid.
- Pool metadata stores the exact submitted combined prompt and engine. Temporary Windows
  preview locks during file moves are retried. Prior pool videos remain available.
- Card push tags the current still with local Ollama using the shared r2manager schema,
  inside the GPU lane. Metadata is cached by the still's SHA-256 in state.json and included
  in the manifest; there is no remote backfill and no EXIF mutation of card sources.
- Delivery's `cards` pool is administered by hotcardgames-scanner. Its CARD_ASSETS binding
  reads the hotcardgames bucket; the actual hotcardgames-assets manifest route shares the
  same rules KV. Hot Card Games, Hot Idle and Sentience send their `app` package and honor
  authoritative empty filtered catalogs. Direct R2 remains available for binary assets only.
- The September 12 regeneration excludes the Joker collection and all Joker ranks.
  Generation and WebP processing stop before the separate manual R2 push stage.

AGB'nin 5. kipi. Sıra: **Jigsaw | CBN | Kart | Karakter** (Kart, Karakter'den ÖNCE; Karakter sonda). Grok'a bağlı `Hot Card Games/tools/cardpipe`
hattının yerine geçer; çıktı sözleşmesi (R2 `hotcardgames`, manifest, sprite sheet) DEĞİŞMEZ. Anime koleksiyonu yok, hepsi realistic.


## 0. Dört aşama (kullanıcı tanımı, 2026-09-08 akşam) — ekranlar ve uçlar bu dörde göre
1. **Still üretimi** — koleksiyon oluşturunca 13 (+2) rütbe için 1'er still otomatik; ✎ Düzenle / ↻ Yeniden üret.
2. **Video üretimi** — still'den LTX-2.5 i2v 6 sn, jest seçimi; guard'lar; otomatik kabul.
3. **WebP üretimi** — SAM3 kesim (bu aşamada) + 12×6 sheet + thumb; guard'lar; "kontrol" rozeti.
4. **Push** — manifest üretimi bu adımın içinde (önce dosyalar, sonra manifest); onaylı, geri alınamaz.
Krupiyeler de aynı dört aşamadan geçer (avatar türü yok). **Gece modu:** "Hepsini yeniden canlandır" (54 kart + 3 krupiye) tek düğmeyle kuyruğa girer,
sabah 3. aşamaya kadar bitmiş olur; push sabah elle. Krupiyeler yeni yolla (`dealers/<ad>_sheet_v3`) yayınlanır ve Hot Card Games'te
gömülü scarlett'in yolunu değiştiren bir uygulama sürümü gerekir (ayrı task; manifest dealers v3'e geçmeden önce o sürüm çıkmalı).


### Tür seçimi: iki seçenek — **Normal (kart)** · **Krupiye**
- **Normal:** tam boy 2:3 (832×1248 still, 448×672 sheet), koleksiyon = 13 rütbe (+2 joker), formül roster v5.
- **Krupiye:** krupiyeye uygun üretim: **bel üstü** kadraj (masaya oturmuş/masanın arkasında ayakta, eller masada, kameraya bakıyor),
  krupiye kıyafeti (yelek/papyon/kumarhane üniforması ya da tema: noir kırmızı elbise, sakura…), 2:3 still 832×1248, sheet mevcut krupiye
  geometrisi 320×480 (v1 uyumu) — `dealers_v3` ile 448×672'ye geçilebilir. Jestler: idle (nefes, hafif baş), shuffle (kart karıştırma),
  deal (kart dağıtma), wink, smile. Kimlik: `_Dealers/<ad>/` tek öğe (rütbe yok). Manifest `dealers[]`.
- Avatar türü bu modda YOK (avatarlar mevcut assets/avatars ile kalır).


### Çözünürlük (kullanıcı: "webp'ler çok düşük çözünürlüklü duruyor") — v3 geometrisi
- Sheet karesi **512×768** (ızgara 12×6 → 6144×4608; WebP 16383 sınırı içinde), 12 fps, 72 kare, q 85.
- Statik thumb **640×960** (ilk kare) — tahta/ızgara/koleksiyon bunu çizer; eski 300×450 kalitesizliğin asıl kaynağıydı.
- Yeni **hi-res still** `still.webp` **832×1248** (q 90) — kart detay sahnesi ve mağaza büyük görünüm; manifest kart şemasına `still` alanı eklenir.
- Video master: LTX-2.5 çıktısı 832×1248 (still ile aynı); sheet'e LANCZOS ile 512×768. Eski Grok masterları 448×672 → yeniden canlandırma yolu zaten
  still'den başladığı için v3 masterlar da 832×1248 olur.
- Krupiye: sheet 320×480 (v1) → `dealers_v3` ile 512×768; thumb 640×960; still 832×1248.
- Uygulama (Hot Card Games, ayrı task): `sprite.grid_decode_max_width` 1920 → 3072, board 1280 → 1536; thumb boyutunu manifest'ten oku (`thumbW/thumbH`);
  detay sahnesinde `still` göster, animasyon üstüne binsin; bellek: ızgarada aynı anda animasyonlu kart sayısı 6 → 4.

- **Diğer tüketiciler:** Hot Idle (`lib/minigames/common/hcg_figures.dart`) ve Sentience (`avatar_catalog_service.dart`) aynı manifest'i çeker;
  v3 alanları (frameW/frameH/thumbW/thumbH/still) manifest'ten okunmalı, sabit 448×672 varsayımı kaldırılmalı — Hot Idle ve Sentience'ta ayrı task'lar.
  Manifest v3 geriye uyumlu: eski alanlar aynen kalır, yeni alanlar eklenir.

## 1. Çıktı sözleşmesi (mevcut, korunur)
- Kart varlığı = sprite sheet WebP: 6 sn, 12 fps, 72 kare; v2: kare 448×672 + thumb 300×450; **v3: kare 512×768 + thumb 640×960 + still 832×1248** (bkz. Çözünürlük).
- Manifest kart şeması: `{id, rank, rarity, price, sheet, thumb, frames, fps, cols, rows, frameW, frameH}`; koleksiyon `{id, name, style, cards[]}`;
  `dealers[]` aynı geometri (krupiye v1: 320×480; yeni yol açılmadan yeniden adlandırılmaz — APK'da gömülü scarlett).
- Rütbe sırası A K Q J 10 9 8 7 6 5 4 3 2; nadirlik A=epic, KQJ=rare, 2-10=common; joker legendary; fiyat 400/1200/3000/8000 (`roster.json`).
- **Önbellek kuralı:** istemciler dosya baytlarını sonsuza dek saklar; üstüne yazma yok, yol değişir (`_sheet_v3`), önce dosyalar sonra manifest.
- Bilinen sorunlar: chroma key ten yansıması/saç halesi, "yeşil kıyafet yasak", i2v kamera kayması (guard_firstframe + check_keying).

## 2. Kütüphane düzeni (`D:\Asset Generation Pipeline\Hot Card Games\`, settings `card.root`)
```
_Incoming Kart\<stem>.jpg (+.json)          1 → 2: Üretilenler'den sahnelenen 2:3 still (chroma yeşil)
<Koleksiyon>\collection.json                {id, name, theme, style: "realistic", ranks: {A:{...},...}, jokers, created}
<Koleksiyon>\<rütbe>\still.png              seçili still (832×1248)  + adaylar still_NN.png
<Koleksiyon>\<rütbe>\video.mp4              i2v master (448×672 ya da 832×1248 → sheet'e ölçeklenir)
<Koleksiyon>\<rütbe>\cut\alpha_%03d.png     SAM+chroma kesim kareleri (RGBA)
<Koleksiyon>\<rütbe>\sheet.webp thumb.webp  paket
<Koleksiyon>\_pushed.json                   R2'ye giden dosya adları + sürüm eki
_Dealers\<ad>\...  _Avatars\<ad>\...        aynı yapı (krupiye: bel üstü, avatar: kare)
```
Mevcut Grok masterları `C:\Projects\Hot Card Games\design\characters\<koleksiyon>\videos\<id>.mp4` → ilk kullanımda `card.root` altına
**kopyalanır** (kaynak silinmez), `collection.json` roster.json'dan türetilir (`_migrate_grok`).

## 3. Kesim: SAM3 (`tools/cardpipe_local/cut.py`, sunucu `card_flow.cut`) — YEŞİL EKRAN ARTIK GEREKMİYOR

Kullanıcı kararı: yeni üretimlerde chroma fon yok; still'ler karakter hattıyla aynı **düz açık gri stüdyo fonunda** üretilir, kesim yalnız SAM3.
Chroma alfa yalnız eski Grok masterları (yeşil fon) için `mode="hybrid"` seçeneğidir. Tool arayüzü: `cut_video(video, out_dir, mode="sam"|"hybrid",
concept="woman", fps=12, seconds=6) -> {frames_dir, sheet, thumb, metrics}`; `build_sheet(frames_dir, sheet, thumb, frame=(448,672), grid=(12,6))`.
1. ffmpeg → kareler (72 @ 12 fps, 6 sn; kaynak 12 fps değilse yeniden örneklenir).
2. **SAM3** "woman" (krupiye: "woman", avatar: "person") kare-kare (CBN'deki `kid_cbn.segment` altyapısı, tek yükleme ile parti);
   maske zamansal **3-kare medyan** (titreme), 2 px kapama.
3. **SAM kipi (varsayılan):** alfa = maske; kenar 2 px yumuşatma (guided/bilateral feather), saç için maske sınırında 3 px bandında
   luminance-fark tabanlı yumuşak alfa (düz gri fon sayesinde), fon rengi kenar bandından bastırılır (de-fringe).
4. **Hybrid kipi (eski yeşil masterlar):** chroma alfa (`check_keying` mantığı: köşelerden gerçek fon, sıkı 0.10) SAM maskesinin 4 px
   genişletilmiş alanı içinde, dışında 0; maske içinde `alpha_key < 0.15` (yeşil yansımayla silinmiş ten) 1'e çekilir; spill bastırma kenar bandında.
5. Guard'lar: ilk kare–still farkı (reframe), kare başına opak oran aralığı (zoom), maske kapsama sürekliliği. FAIL → op log, kart "kontrol" rozeti.
6. Sheet: 12×6, 448×672 (kaynak büyükse LANCZOS), WebP q≥80; thumb ilk kareden 300×450.
Yeni kural: **yeşil kıyafet yasağı ve yeşil fon KALKAR**; fon düz açık gri (SAM için yeterli, saç kenarı luminance ile).

### 3.1 Restill — eski yeşil still'leri düz gri fona taşıma (#325)
Yeniden canlandırma still'den başladığı için **yeşil still = yeşil video = `hybrid` kesim zorunluluğu**. Onun yerine still bir kez düzeltilir:
`cut.py: restill(still_path, out_path, bg=(212,212,208), mode="auto")` — tek karelik SAM3 maskesi → alfa (`bg_chroma > 0.06` ise `alpha_hybrid`,
değilse `alpha_sam`) → de-fringe + despill → **düz açık gri üzerine kompozit** (RGBA değil, RGB; kaynak boyut korunur). Kadın pikselleri değişmez.
Sunucu: `restill(collection|"all", kind, include_dealers, force)` op `card-restill`, koleksiyon başına **bir gpu_lane bileti** (kesimle aynı kural);
`still.png` → `still_green.png` **bir kez** yedeklenir (üstüne asla yazılmaz), gri hâl `still.png` olur, `rev` artar, `still.webp` yenilenir.
Zaten gri olan rütbe (`bg_chroma <= 0.06`) `force` verilmedikçe atlanır. **SAM kapsaması %5'in altındaysa ya da verdict düşerse still'e DOKUNULMAZ**
(Qwen otomatik çağrılmaz) — o rütbeler op mesajında "ELLE DÜZELT" olarak listelenir. `reanimate(..., restill_first=True)` video aşamasından önce çalıştırır.
Uç: `POST /api/card/flow/restill {collection, kind, include_dealers, force}` → `{op}`.

### 3.2 Realify — anime koleksiyonu gerçekçiye çevirme (#325)
Kart Modu'nda **anime yoktur**. Elde kalan anime koleksiyon (`neon_nurse`, `style: "anime"`) `realify(collection, kind, ranks)` op'u (`card-realify`)
ile çevrilir: rütbe başına bir `edit_qwen` işi (mode `free`, `client="flow"`), eski hâl `still_anime.png` olarak **bir kez** saklanır, sonuç `still.png`
olur; bütün rütbeler bitince `collection.json` `style` → `"realistic"` ve tema/prompt metinlerinden anime sözcüğü temizlenir.
**Koleksiyonun `id` ve `name` değeri asla değişmez** ("Neon Nurse" adıyla kalır). `reanimate(..., realify_first=True)` yalnız `style == "anime"` olan
koleksiyonlar için çalışır. Uç: `POST /api/card/flow/realify {collection, kind, ranks}` → `{op}`. Gece sırası: **realify → restill → reanimate**.

## 4. Üretim (yeni koleksiyonlar, tamamen yerel)
- **Kart kipi** `comfy_gen.MODES["card"]`: label "Kart Modu", 2:3 832×1248, `prompt2` = roster `style_prompts.realistic` + `base_prompt`
  (plain light gray seamless studio background, full body head to heels, centered, static), negatif = mevcut + "green clothing" YOK artık; profil dosyası
  `server/config/card_options.json` (`app/assets/kart_secenekler.json`): tema, ten, saç, kıyafet, poz, jest listeleri.
- **Koleksiyon oluştur** `POST /api/card/flow/collections {id, name, theme, jokers: 0|2}` → 13 (+2) rütbe için **1'er still** kuyruğa
  (`image_zimage`, mode card, `client="flow"`, `category=<koleksiyon>`), rütbe başına farklı görünüm (ten/saç/kıyafet/poz rotasyonu, #cardpipe v4
  kuralı), otomatik kabul → `<rütbe>/still.png`. Onaysız; ✎ Düzenle / ↻ Yeniden üret (karakter hattı kalıbı).
- **Animasyon** `POST /api/card/flow/animate {collection, ranks, gesture}`: LTX-2.5 i2v (`video_ltx` görevi), 6 sn, prompt = jest
  (`gesture_prompts`: idle/wink/kiss/hair/pose) + "locked static camera, no zoom, no push in, framing never changes, same scale, plain
  background stays flat" → `video.mp4`; guard'lar; otomatik kabul.
- **Kes + paketle** `POST /api/card/flow/cut {collection, ranks}` → §3; **Manifest** `POST /api/card/flow/manifest` (roster kuralları ile
  `out/manifest.json` eşdeğeri, sürüm eki `_v3`); **Push** `POST /api/card/flow/push {collection}` → R2 `hotcardgames` (wrangler, mevcut
  `upload_r2.py` mantığı), önce dosyalar sonra manifest. Push GERİ ALINAMAZ, ayrı düğme.
- **Mevcut 54 kart + 3 krupiye (kullanıcı kararı):** varsayılan yol **yeniden canlandırma**: seçili still (`design/characters/<kol>/selected/<id>.png`,
  768×1152; yoksa Grok videosunun ilk karesi) → LTX-2.5 i2v (§4 animasyon, jest idle/wink/...) → SAM kesim → `_sheet_v3`.
  `POST /api/card/flow/reanimate {collection|"all", gesture?}`. Yedek: `POST /api/card/flow/recut {collection|"all"}` = Grok videosunu hybrid
  kiple yeniden kes. Yeşil fonlu still'lerde SAM kipi de çalışır (fon rengi fark etmez). Krupiyeler DE yeniden canlandırılır (§0); v3 yolları manifest'e ancak uygulama sürümüyle girer.
- Hepsi comfy_gen kuyruğu / gpu_lane biletiyle (#299), Sıra'da görünür; op'lar `/api/card/flow/op/{id}`.

## 5. Uygulama / stüdyo
FlowHub: **Jigsaw | CBN | Kart | Karakter**. Kart ekranı: koleksiyon listesi (kapak = A kartının thumb'ı, 13 rütbe rozeti: still/video/sheet/push
durumları) → koleksiyon detayı: 13 (+joker) kart ızgarası 2:3 (still, video varsa oynatma işareti, sheet varsa ✓, push ✓), kart detayı: still |
video | kesim önizleme (sheet ilk kare, şeffaf zemin damalı) | ✎ Düzenle / ↻ Yeniden üret still / ↻ animasyon (jest seçimi) / Kes; koleksiyon düzeyinde
"Hepsini üret", "Hepsini animasyona sok", "Hepsini kes", "Manifest", "Push" (onaylı). Krupiye ve avatar sekmeleri aynı ekranın alt kipleri.
Üretilenler: "Kart Modu" filtresi + "Koleksiyona ekle" (seçili iş → rütbe). Stüdyo: aynı akış, aynı uçlar.

**#352 (2026-09-10) — erişim, silme, iptal:**
- **Koleksiyon Kartı** (tema + 16 yuva + model zimage|qwen + yüz rötuşu) tek ekrandır (`CardTemplatesScreen` / stüdyo `card_templates_dialog`).
  Uygulamada koleksiyon ekranının üst tema şeridi, app bar'daki ⚙ ve listedeki basılı-tut menüsü buraya gider; krupiyede de aynı (basılı tut).
  Eski küçük tema penceresi ve "Kaydet + prompt yaz" (LLM `rewrite-looks`) kaldırıldı — #345'ten beri still promptu şablon katmanlarından
  kurulur, LLM metni üretime girmiyordu. Koleksiyon oluşturma da LLM çağırmaz (`create`/`dealer_create`): şablonlar anında diske yazılır.
- **Silme:** `DELETE /api/card/flow/rank` rütbeyi boşa döndürür (still/aday/video/sheet/anim/state; klasör ve koleksiyon kalır, `_pushed.json`
  kaydı düşer); `DELETE /api/card/flow/collection?id&kind` koleksiyonu/krupiyeyi klasörüyle siler (R2 kalır, geri alınamaz). Uygulama: seçim
  çubuğu "Temizle", kart detayı çöp, koleksiyon/krupiye menüsü "Sil". Stüdyo: "Kartı temizle", "Koleksiyonu sil".
- **BACK yuvası rütbe değildir:** `_collection_ranks` `back/` klasörünü dışlar → animasyon/kesim/push/manifest/gece modu BACK'e dokunmaz.
- **Prompt kaydı:** kabul edilen still'in gerçek promptu `state.json still.prompt`; kart detayı önce onu, yoksa şablon önizlemesini gösterir.
- **Sıra iptali (tüm hat):** `POST /api/queue/cancel {ticket_id|op_id|job_id}` — bekleyen şerit bileti düşer (`gpu_lane.cancel_ticket`),
  op defterine bayrak (`jigsaw_flow.cancel_op`, `_op()` bir sonraki adımda `OpCancelled` fırlatır, durum `cancelled`), op'un açtığı comfy
  işleri (`_op_job` defteri + `_await_job`) kesilir. Uygulama Sıra ekranı her bilette "İptal"; stüdyo "Seçili bileti iptal et (şerit)".

## 6. Kurallar
- Yetişkin figürler, chibi/çocuk yok (`feedback_no_minors_no_chibi`); hot çizgisinin kalıbı (v5 formülü) korunur.
- Her iş kuyrukta (#299); ilk tur tam otomatik 1'er; ince ayar ✎/↻.
- R2 push ve manifest yalnız kullanıcı düğmesiyle; staging klasörü elle yüklenmez kuralı burada geçerli DEĞİL (push düğmesi var), ama push onay ister.

## #357 - Video havuzu, etiket atama, motor secimi, tekil silme (2026-09-10)

**Sorun.** "idle/wink" hem prompt sablonu hem animasyon adiydi; kullanici videoyu uretip
sonra "bu idle olsun, bu victory olsun" diyemiyordu. Ust bardaki tek cop butun rutbeyi
temizliyordu; bakilan still/video/webp tek basina silinemiyordu. Motor secimi yoktu.

**Model.**
- Havuz: `<rutbe>/videos/<vid>.mp4` + `<vid>.json` (prompt, gesture, engine, at, job, guard).
  `animate()` ciktisi once buraya girer; `pool_only` degilse `anim` etiketine atanir.
- Atama: `assign_video(collection, rank, kind, vid, tag)` havuz dosyasini etiket klasorune
  KOPYALAR (idle = rutbe koku, digerleri `anim/<tag>/`), eski sheet/thumb/cut'i siler,
  state'e `source=vid` yazar (idle icin pushed kaydi duser). Ayni video birden fazla
  etikete atanabilir. `videos_of()` her videonun `tags` listesini bu kaynaktan turetir.
- Motor: `collection.json.video_engine` = `ltx` | `wan`; `VIDEO_ENGINES` -> manifest gorevi.
  Hepsi FLF2V (ilk kare = son kare). MiniMax H3 #358'de kullanicinin istegiyle eklendi
  (`FLF2V MiniMax H3 Kart.json`, 576x864 sabit, 158 kare = 6.58 sn, iki LoadImage);
  etiket lisans uyarisi tasir (AB/UK/ABD/G.Kore dagitim yasak).
  Wan: `FLF2V Wan2.2 14B Kart.json` (Lightning dali acik), wf2api Wan dugumlerine
  width/height/length yazar (81 kare = 5 sn ust sinir).
- Tekil silme: `delete_asset(what=still|video|sheet, anim)`; havuza dokunmaz.

**Uclar.** `GET /api/card/flow/videos`, `POST /api/card/flow/video/assign`,
`DELETE /api/card/flow/video`, `DELETE /api/card/flow/asset`; `animate` body'de
`pool_only`, `engine`; `settings` body'de `video_engine`.

**Istemciler.** AGB: video penceresi (sablon -> metin, etiket, motor), Videolar seridi,
animasyon kutulari (+ Yeni), segment satirinda cop. Studyo: "Videolar (havuz)" penceresi,
"yalniz havuza" kutusu, ayarlarda motor, onizlemede "Secili gorunumu sil".

