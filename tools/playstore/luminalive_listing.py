"""Push the Lumina Live store listing via the Play Developer API.

One edit: en-US + tr-TR listing texts, app icon, feature graphic, phone
screenshots, then commit. Rerunnable (each run replaces the listing).

Run: python "C:/Projects/Auto Game Builder/tools/playstore/luminalive_listing.py"
"""
import os

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

SA_KEY = "D:/keys/arcade-snake-488801-5ac9863bb0ab.json"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
PACKAGE = "com.lifecharger.luminalive"
STORE = r"C:\Projects\Lumina Live\store"

EN_TITLE = "Lumina Live"
EN_SHORT = "Neon idol stream clicker. Tap the beat, hype the room, go viral."
EN_FULL = """You produce the night. Lumina is live, the room is dark, and every tap on the stage sends hearts flying.

TAP THE STAGE
Hit the beat to earn hearts. Chain taps into combos, land SUPERCHAT crits, and watch the viewer counter climb while the chat pops off.

BUY THE ROOM
Pulse gloves, in-ear mixes, LED heels, fog cannons, holo backups, pyro cues and a world drop make every tap heavier. Lurkers, chat mods, superfans, clip farms, merch tables, collab desks and a stadium simulcast keep the hearts flowing while you're away from the stage.

THE CAST
Four idols, four sounds. Lumina keeps combos lingering, Nox holds the lurkers, Saffron brightens every tap, and Vesper makes superchats hit harder. Unlock them and choose who goes live.

GO VIRAL
Spend a run of hearts to bank fame. Upgrades reset, the cast stays, and every later tap and idle tick is multiplied. Chase the next clip that goes worldwide.

STUDIO
Sponsor breaks double your hearts for a minute, and time skips bank idle hours instantly.

Neon lights, a synth beat, and a stage that shakes when you land a crit. Go live."""

TR_TITLE = "Lumina Live"
TR_SHORT = "Neon idol yayın clicker'ı. Ritme bas, salonu coştur, viral ol."
TR_FULL = """Geceyi sen üretiyorsun. Lumina yayında, salon karanlık ve sahneye her dokunuş kalpleri havaya uçuruyor.

SAHNEYE DOKUN
Ritmi yakalayıp kalp kazan. Dokunuşları komboya zincirle, SUPERCHAT kritik vuruşlar yakala ve sohbet coşarken izleyici sayacının yükselişini izle.

SALONU SATIN AL
Nabız eldivenleri, kulak içi mix, LED topuklular, sis topları, holo yedekler, piro işaretleri ve dünya drop'u her dokunuşu ağırlaştırır. Lurker'lar, sohbet modları, süper hayranlar, klip çiftlikleri, ürün masaları, iş birliği masaları ve stadyum yayını sen sahneden uzaktayken bile kalpleri akıtır.

KADRO
Dört idol, dört ses. Lumina komboları uzatır, Nox lurker'ları tutar, Saffron her dokunuşu parlatır, Vesper superchat'leri daha sert vurdurur. Kilitlerini aç ve kimin yayına gireceğini seç.

VİRAL OL
Bir gecelik kalbi harcayıp şöhret biriktir. Geliştirmeler sıfırlanır, kadro kalır ve sonraki her dokunuş ve boş zaman kazancı katlanır. Dünyayı dolaşacak bir sonraki klibin peşine düş.

STÜDYO
Sponsor molaları kalplerini bir dakikalığına ikiye katlar, zaman atlamaları boşta geçen saatleri anında hesabına yazar.

Neon ışıklar, synth bir ritim ve kritik vurduğunda sallanan bir sahne. Yayına gir."""


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
    for s in sorted(f for f in os.listdir(shots_dir) if f.endswith(".png")):
        upload("phoneScreenshots", os.path.join(shots_dir, s))

    edits.commit(packageName=PACKAGE, editId=edit_id).execute()
    print("COMMITTED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
