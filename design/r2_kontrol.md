# Kovalar - R2 kova denetimi (#381)

AGB'nin akislari (jigsaw, CBN, kart, karakter) YEREL klasorleri gorur. Push'tan sonra kovada ne
oldugunu goremiyorduk: bir strike geldiginde nesneyi silmek icin wrangler'a, bir baslik yanlis
konduysa elle kopyalamaya, "yerelde var ama kovada yok mu?" sorusuna hicbir cevaba sahip degildik.
Kovalar kipi bu bosugu kapatir.

**Dagitim** (#363) NE sunulacagini secer (worker KV'sindeki kurallar). **Kovalar** kovada NE VAR
sorusunun cevabidir. Ikisi Delivery Mod'un iki sekmesidir; ucuncu istemci Uretim Studyosu'nun
"Kovalar" sekmesidir.

| Kat | Dosya |
|---|---|
| S3 istemcisi (stdlib, boto3 yok) | `tools/r2/r2_s3.py` |
| Kayit defteri | `server/config/r2_buckets.json` |
| Is mantigi | `server/core/r2_control.py` |
| Uclar | `server/api/server.py` -> `/api/r2/*` |
| Flutter | `app/lib/services/r2_control_service.dart`, `app/lib/screens/buckets_screen.dart` |
| Studyo | `C:/ComfyUI/scripts/uretim_studyosu.py` -> `Api.r2_*`, `R2Panel` |
| Testler | `server/tests/test_r2_control.py`, `app/test/r2_control_test.dart` |

## 1. Erisim

`r2.credentials_file` ayari (varsayilan `D:/keys/cloudflare_r2_s3_credentials.json`, ortam
degiskeni `R2_CREDENTIALS_FILE` oncelikli). Dosya DEPONUN DISINDADIR ve icerigi hicbir istemciye
inmez; telefon ve studyo yalniz AGB sunucusuyla konusur. `tools/r2/r2_s3.py` SigV4'u kendisi
imzalar (stdlib): `list_objects_v2`, `list_all`, `head_object`, `get_object` (Range destekli),
`copy_object` (MetadataDirective REPLACE ile), `delete_object`, `delete_objects`. Tek uygulamadir;
sunucu onu dosya yolundan yukler, kopyasini cikarmaz.

## 2. Uclar

| Metod | Yol | Ne yapar |
|---|---|---|
| GET | `/api/r2/buckets?refresh=&bucket=` | Kayit defteri + nesne sayisi / toplam bayt (diskte onbellekli, `refresh` yeniden sayar) |
| GET | `/api/r2/list?bucket=&prefix=&cursor=&limit=` | Klasor gibi gezinme: alt klasorler + nesneler (genel adres, `preview` bayragi) |
| GET | `/api/r2/head?bucket=&key=` | Basliklar + onbellek standardina uygunluk + ikiz anahtari |
| GET | `/api/r2/thumb?bucket=&key=&size=` | Kucuk JPEG onizleme; uygun degilse 415 + tipli "onizleme yok" |
| POST | `/api/r2/delete-plan` | Silmeden once: hangi kovada hangi anahtarlar gidecek |
| POST | `/api/r2/delete` | `{bucket, keys[], takedown, confirm}` - siler; GERI ALINAMAZ |
| POST | `/api/r2/copy` | `{src_bucket, dst_bucket, src_key\|src_prefix, dst_key\|dst_prefix}` - sunucu tarafi kopya, arka plan islemi |
| POST | `/api/r2/fix-headers` | `{bucket, prefix}` - sapan Cache-Control'u yerinde duzeltir, arka plan islemi |
| GET | `/api/r2/diff?rating=&collection=` | Yerel "Push edilmis" klasoru <-> kova |
| GET | `/api/r2/twin-diff?bucket=` | YENI kova <-> ESKI ikizi |
| GET | `/api/r2/audit?limit=` | Denetim defterinin sonu |
| GET | `/api/r2/ops`, `/api/r2/op/{id}` | Arka plan islemleri (akis op'lariyla ayni govde) |
| POST | `/api/r2/op/{id}/cancel` | Islemi iptal et |

Kimlik dogrulama diger uclarla aynidir (`X-API-Key`).

## 3. Guvenlik korkuluklari

* **Yazili onay.** `confirm` kova adiyla BIREBIR ayni olmali. Yanlis kovada yanlis secimle silmeyi
  bir yazim adimi durdurur.
* **500 anahtar siniri.** Tek cagrida daha fazlasi reddedilir.
* **"Onekle silme" yok.** Sunucu asla bir onegin altindakileri kendiliginden silmez; istemci once
  listeler, kullanici secer, anahtar listesi gonderilir. Ne silinecegi her zaman gorunur.
* **Kayitli kova.** `r2_buckets.json`'da olmayan bir kova adi hicbir cagrida kabul edilmez.
* **Denetim defteri.** `server/data/r2_audit.log` - yalniz eklenen JSON satirlari: zaman, istemci,
  eylem, kova, anahtarlar. Silme, takedown, kopya ve baslik onarimi buraya yazar.
* **Sayacli hat.** Onizleme bir gorseli BIR KEZ indirebilir; video, hareketli webp (VP8X ANIM biti)
  ve 2 MB ustu nesne indirilmez - tipli bir "onizleme yok" doner ve istemci ikon + boyut gosterir.
  Listeleme her satira `preview` bayragi koyar, istemciler onizlemeyi yalniz gorunen satirlar icin
  ve yalniz bayrak varken ister; onden yukleme yoktur.
* **Kopya hatti kullanmaz.** Kopya Cloudflare icinde calisir (`x-amz-copy-source`); bu makineden
  bayt gecmez. Baslik onarimi da nesneyi kendi uzerine REPLACE ile kopyalar.

## 4. Onbellek standardi (2026-08-10)

| Ne | Cache-Control |
|---|---|
| Varliklar (gorsel, video, sprite sheet) | `public, max-age=7776000, immutable` |
| `*.json` manifestler | `public, max-age=21600, stale-while-revalidate=86400` |
| `characters/*/relationships/` | bilerek DEGISKEN - deneme asamasi, son immutable gecise kadar dokunulmaz |

`head` her nesne icin `{kind, expected, actual, ok}` doner; `fix-headers` yalniz sapanlari,
Content-Type'i koruyarak yeniden yazar. Bosluk ve buyuk/kucuk harf farki sapma sayilmaz.

## 5. Ikiz esleme (ESKI kovalar 2026-10-20'de emekli)

Ay sonundaki emeklilige kadar bir takedown YENI ve ESKI kopyayi BIRLIKTE dusurmek zorundadir.
Esleme `r2_buckets.json`'da tek yerde tanimlidir; `{ad}` bir yol parcasini, `{ad...}` anahtarin
geri kalanini yakalar. Ters yon ayni kuraldan turetilir.

| Yeni kova | Anahtar | ESKI ikiz | Anahtar |
|---|---|---|---|
| `gallery-hot` | `collections/<k>/...` | `hotjigsaw` | `collections/<k>/...` |
| `gallery-family` | `collections/<k>/...` | `kidfriendlybucket` | `collections/<k>/...` |
| `cards` | `manifest.json`, `collections/...`, `dealers/...` | `hotcardgames` | ayni anahtarlar |
| `characters` | `<kiz>/relationships/<f>` | `hotcardgames` | `relationships/<kiz>/<f>` |
| `idols` | butun anahtarlar | `characters-v2` | ayni anahtarlar |
| `promo` | `cross-promo/<f>` | `hotjigsaw` | `promo/<f>` |

Kurali olmayan anahtar (`cards/shop_characters/...`, `characters/characters.json`) eslenmez ve
`unmapped` olarak raporlanir - esleme UYDURULMAZ. Bir eski kova iki yeni kovayi besleyebilir
(`hotjigsaw` -> `gallery-hot` + `promo`); ters eslemede hangi yeni kovaya gidecegi anahtardan
belli olur.

`twin-diff` ESKI kovanin yalniz ilgili oneklerini listeler (promo icin `promo/`, hepsini degil) ve
`missing_in_legacy` / `only_in_legacy` / `size_mismatch` / `unmapped` doner. Emeklilik listesinin
2. ve 6. adimlari (`C:/Cloudflare Workers/R2_MAP.md` §6) bu gorunumle denetlenir.

## 6. Farklar

* `diff?rating=hot|kid[&collection=]` - jigsaw akisinin yerel "Push edilmis" klasoru ile kovayi
  karsilastirir. Yerel duzen `<koleksiyon>/<n>.jpg` kova anahtari `collections/<koleksiyon>/images/<n>.jpg`
  olur (`.mp4` -> `videos/`, `.webp` -> `videos_webp/`, `.mp3` -> `music/`). `.json` yan dosyasi
  yerel kayittir, karsilastirmaya girmez. Gri thumb agaci (`collections/<k>/thumbs/`) kovada
  uretilir, yerelde hic olmaz - `derived_in_bucket` olarak AYRI raporlanir, yoksa 1300 satirin
  arasinda gercek bir eksik gozden kacar.
* `twin-diff?bucket=` - yukaridaki esleme uzerinden yeni kova ile eski ikizi.

## 7. r2manager'dan tasinan son parcalar

`tools/r2manager` masaustu araci calisir durumda kalir ama artik AGB'nin gerisindedir. Bu is
sirasinda kalan dort ozellik de sunucuya tasindi (`server/core/jigsaw_flow.py`):

| r2manager | AGB |
|---|---|
| `match_videos` / `_do_match` | `match_videos(rating)` + `POST /api/jigsaw/flow/match`. Bayti bayta ayni gorselleri siler, her gorselin ve her videonun ILK karesinden 64x64 gri onizleme cikarir, MSE < 2000 ciftlerini hataya gore siralar, once her gorsele bir birincil video verir (videosuz gorsel, videosu olan gorselin fazlasina video kaptirmaz), artanlari `-extraN` yapar, eslesmeyenleri `orphan_N.mp4` adlandirir. cv2 yerine PIL + ffmpeg. |
| `reject_selected` | `remove()` artik TAM demeti siler (`-extraN` videolar ve yan dosyalari dahil); `bundle()` + `GET /api/jigsaw/flow/bundle` onay penceresine listeyi verir. |
| `accept_keep_names` | `accept(..., keep_names=True)` + `POST /api/jigsaw/flow/accept {"keep_names": true}`. Numarayi baska bir varlik tutuyorsa varlik ATLANIR, uzerine yazilmaz. |
| `encode_missing_webps` | `webp_missing()` artik staging KOKUNU dolasir (1000 satirlik liste sayfasina bagli degil), gorseli kalmamis videoyu da bulur, `-extra` videolari atlar; `GET /api/jigsaw/flow/webp` sayiyi onceden verir. |

## 8. Neyi yapmaz

* Dosya YUKLEMEZ. Kovaya yazmak akislarin isidir (`/flow/push`, kart hatti, `upload_relationships.py`).
* Kova olusturmaz / silmez, custom domain ya da worker yonetmez - bunlar Cloudflare panelinin isi.
* Kayit defterinde olmayan kovayi gostermez. Yeni bir kova acildiginda `r2_buckets.json`'a bir satir
  eklenir (ad, alan adi, rol, ne tuttugu, varsa ikizi) ve `R2_MAP.md` §1 ile birlikte guncellenir.
