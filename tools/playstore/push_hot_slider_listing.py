"""Hot Slider only: materialize fastlane locale files from translations_hot_slider.py
and push the 8 translated locales to the Google Play listing.

One-off counterpart of push_listings.py (which handles three apps). Same
materialize logic and 30/80/4000 validation; only com.lifecharger.hotslider is
touched. After the commit the listing is read back and the locale set is printed.

Run: python "C:/Projects/Auto Game Builder/tools/playstore/push_hot_slider_listing.py"
"""
import sys
from pathlib import Path
from google.oauth2 import service_account
from googleapiclient.discovery import build

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))

import translations_hot_slider as t_slider

SA_KEY = "D:/keys/arcade-snake-488801-35f27b42dfb3.json"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]

PACKAGE = "com.lifecharger.hotslider"
PROJECT_DIR = "C:/Projects/Hot Slider"
LOCALES = ["es-ES", "de-DE", "ja-JP", "hi-IN", "bn-BD", "fr-FR", "pt-BR", "tr-TR"]


def materialize(project_dir: str, translations: dict) -> None:
    """Write fastlane files for every locale in translations dict (same as push_listings.py)."""
    for locale, blob in translations.items():
        base = Path(project_dir) / "fastlane" / "metadata" / "android" / locale
        base.mkdir(parents=True, exist_ok=True)
        (base / "title.txt").write_text(blob["title"] + "\n", encoding="utf-8")
        (base / "short_description.txt").write_text(blob["short"] + "\n", encoding="utf-8")
        (base / "full_description.txt").write_text(blob["full"] + "\n", encoding="utf-8")


def read_fastlane(project_dir: str, locale: str) -> dict:
    base = Path(project_dir) / "fastlane" / "metadata" / "android" / locale
    return {
        "title": (base / "title.txt").read_text(encoding="utf-8").strip(),
        "short": (base / "short_description.txt").read_text(encoding="utf-8").strip(),
        "full":  (base / "full_description.txt").read_text(encoding="utf-8").strip(),
    }


def main() -> int:
    materialize(PROJECT_DIR, t_slider.TRANSLATIONS)
    print(f"[Hot Slider] wrote fastlane files for {len(t_slider.TRANSLATIONS)} locales")

    # Validate every locale before touching the API.
    blobs = {}
    for locale in LOCALES:
        blob = read_fastlane(PROJECT_DIR, locale)
        lens = (len(blob["title"]), len(blob["short"]), len(blob["full"]))
        if lens[0] > 30 or lens[1] > 80 or lens[2] > 4000:
            print(f"  [{locale}] over limits: title={lens[0]}/30, short={lens[1]}/80, full={lens[2]}/4000")
            return 1
        print(f"  [{locale}] valid ({lens[0]}c / {lens[1]}c / {lens[2]}c)")
        blobs[locale] = blob

    creds = service_account.Credentials.from_service_account_file(SA_KEY, scopes=SCOPES)
    service = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)

    edit = service.edits().insert(packageName=PACKAGE, body={}).execute()
    edit_id = edit["id"]
    for locale, blob in blobs.items():
        service.edits().listings().update(
            packageName=PACKAGE,
            editId=edit_id,
            language=locale,
            body={
                "language": locale,
                "title": blob["title"],
                "shortDescription": blob["short"],
                "fullDescription": blob["full"],
            },
        ).execute()
        print(f"  [{locale}] uploaded")
    service.edits().commit(packageName=PACKAGE, editId=edit_id).execute()
    print(f"  -> committed edit {edit_id}")

    # Read back and confirm.
    verify = service.edits().insert(packageName=PACKAGE, body={}).execute()
    listings = service.edits().listings().list(packageName=PACKAGE, editId=verify["id"]).execute()
    service.edits().delete(packageName=PACKAGE, editId=verify["id"]).execute()
    found = {l["language"]: l for l in listings.get("listings", [])}
    print(f"\nListing now has {len(found)} locales: {sorted(found)}")
    ok = True
    for locale, blob in blobs.items():
        live = found.get(locale)
        match = live is not None and live.get("fullDescription", "").strip() == blob["full"]
        print(f"  [{locale}] full description {'matches' if match else 'MISMATCH'} "
              f"({len(live.get('fullDescription', '')) if live else 0}c)")
        ok = ok and match
    return 0 if ok and "en-US" in found else 1


if __name__ == "__main__":
    sys.exit(main())
