"""Push the Anime Dance Streamer store listing via the Play Developer API.

One edit: en-US + tr-TR listing texts, app icon, feature graphic, phone
screenshots, then commit. Rerunnable (each run replaces the listing).

Run: python "C:/Projects/Auto Game Builder/tools/playstore/animestreamer_listing.py"
"""
import os

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

SA_KEY = "D:/keys/arcade-snake-488801-5ac9863bb0ab.json"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
PACKAGE = "com.lifecharger.animestreamer"
STORE = r"C:\Projects\Anime Dance Streamer Clicker\store"

EN_TITLE = "Anime Dance Streamer"
EN_SHORT = "Grow your anime streamer! Tap the beat, win dance battles, style 30+ outfits."
EN_FULL = """Meet Bella - a small streamer with a big dream. She starts her channel in a tiny run-down flat, and it's your job to produce her all the way to a sky palace stage!

TAP TO THE BEAT
Tap the stream to send hearts flying. Chain combos, land SUPER hits, and watch the viewer counter climb while payouts turn your hype into coins.

DANCE BATTLES
Challenge rival streamers to rhythm duels! Hit the beat zone with perfect timing, take the round, and earn crowns that unlock exclusive battle outfits.

30+ OUTFITS TO COLLECT
From cozy hoodies and tennis skirts to maid cafes, samurai blades, angel wings and holographic stage costumes - every outfit has its own style and matching hair. Unlock them with coins, crowns, or stage milestones and dress Bella your way.

MOVE INTO BETTER PLACES
Climb the property ladder one home at a time: from a bare flat with a mattress on the floor to a cozy nook, an RGB gamer den, a penthouse, a beach villa, a rooftop pool and finally your own sky palace.

GROW THE STREAM
Level up your gear: ring lights, dance coaches, pro mics and stage effects boost every tap, while chat mods, raids and the front page bring in viewers who cheer even while you're away.

MAKE IT YOURS
Four color themes, multiple languages, and a soundtrack made for dancing.

Start the stream. The night is yours."""

TR_TITLE = "Anime Dans Yayıncısı"
TR_SHORT = "Anime yayıncını büyüt! Ritme bas, dans kapışmalarını kazan, 30+ kıyafet aç."
TR_FULL = """Bella ile tanış - büyük hayalleri olan küçük bir yayıncı. Kanalını köhne, minicik bir dairede açıyor; onu bir gökyüzü sarayının sahnesine taşımak senin elinde!

RİTME BAS
Yayına dokun, kalpler havada uçuşsun. Komboları zincirle, SÜPER vuruşlar yakala ve izleyici sayacı yükselirken ödemelerin coşkuyu altına çevirmesini izle.

DANS KAPIŞMALARI
Rakip yayıncılara ritim düellosunda meydan oku! Vuruş bölgesini tam zamanında yakala, turu al ve yalnızca kapışmalarla açılan özel kıyafetlerin anahtarı olan taçları topla.

30+ KIYAFET SENİ BEKLİYOR
Rahat kapüşonlulardan tenis eteklerine, maid kafelerden samuray kılıçlarına, melek kanatlarından holografik sahne kostümlerine - her kıyafetin kendi tarzı ve ona uygun saç rengi var. Altınla, taçla ya da sahne aşamalarıyla aç; Bella'yı istediğin gibi giydir.

DAHA İYİ EVLERE TAŞIN
Emlak merdivenini adım adım tırman: yerde şilteli bomboş bir daireden sıcak bir yuvaya, RGB oyuncu inine, çatı katına, sahil villasına, teras havuzuna ve en sonunda kendi gökyüzü sarayına.

YAYINI BÜYÜT
Ekipmanını geliştir: ring ışıkları, dans koçları, profesyonel mikrofonlar ve sahne efektleri her dokunuşu güçlendirsin; moderatörler, raidler ve ana sayfa, sen yokken bile tezahürat yapan izleyiciler getirsin.

KENDİNE GÖRE ÖZELLEŞTİR
Dört renk teması, birden çok dil ve dans için yapılmış bir müzik.

Yayını başlat. Gece senin."""


def main() -> int:
    creds = service_account.Credentials.from_service_account_file(SA_KEY, scopes=SCOPES)
    svc = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)
    edits = svc.edits()

    edit_id = edits.insert(packageName=PACKAGE, body={}).execute()["id"]
    print("edit:", edit_id)

    for lang, title, short, full in [
        ("en-US", EN_TITLE, EN_SHORT, EN_FULL),
        ("tr-TR", TR_TITLE, TR_SHORT, TR_FULL),
    ]:
        edits.listings().update(
            packageName=PACKAGE, editId=edit_id, language=lang,
            body={"language": lang, "title": title,
                  "shortDescription": short, "fullDescription": full},
        ).execute()
        print(f"listing {lang}: ok")

    def upload(image_type, path, lang="en-US"):
        edits.images().upload(
            packageName=PACKAGE, editId=edit_id, language=lang,
            imageType=image_type,
            media_body=MediaFileUpload(path, mimetype="image/png"),
        ).execute()
        print(f"{image_type}: {os.path.basename(path)}")

    def clear(image_type, lang="en-US"):
        try:
            edits.images().deleteall(
                packageName=PACKAGE, editId=edit_id, language=lang,
                imageType=image_type).execute()
        except HttpError:
            pass

    clear("icon"); upload("icon", os.path.join(STORE, "icon_512.png"))
    clear("featureGraphic"); upload("featureGraphic", os.path.join(STORE, "feature_graphic.png"))
    clear("phoneScreenshots")
    shots_dir = os.path.join(STORE, "screenshots")
    shots = sorted(f for f in os.listdir(shots_dir) if f.endswith(".png"))
    for s in shots:
        upload("phoneScreenshots", os.path.join(shots_dir, s))

    edits.commit(packageName=PACKAGE, editId=edit_id).execute()
    print("COMMITTED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
