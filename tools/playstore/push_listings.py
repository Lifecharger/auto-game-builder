"""Write fastlane locale files from translations_*.py and push all locales to Google Play.

Reads translations from translations_hot_slider.py / translations_hot_jigsaw.py /
translations_hot_charm.py (8 locales each), writes them to each project's
fastlane/metadata/android/<locale>/, then pushes every locale (including en-US
which already lives in fastlane) to the Google Play listing via the
androidpublisher v3 API.

Run: python "C:/Projects/Auto Game Builder/tools/playstore/push_listings.py"
"""
import sys
from pathlib import Path
from google.oauth2 import service_account
from googleapiclient.discovery import build

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))

import translations_hot_slider as t_slider
import translations_hot_jigsaw as t_jigsaw
import translations_hot_charm  as t_charm

SA_KEY = "D:/keys/arcade-snake-488801-35f27b42dfb3.json"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]

APPS = [
    ("Hot Slider", "com.lifecharger.hotslider", "C:/Projects/Hot Slider", t_slider.TRANSLATIONS),
    ("Hot Jigsaw", "com.lifecharger.hotjigsaw", "C:/Projects/Hot Jigsaw", t_jigsaw.TRANSLATIONS),
    ("Hot Charm",  "com.lifecharger.hotcharm",  "C:/Projects/Hot Charm",  t_charm.TRANSLATIONS),
]

ALL_LOCALES = ["en-US", "es-ES", "de-DE", "ja-JP", "hi-IN", "bn-BD", "fr-FR", "pt-BR", "tr-TR"]


def materialize(project_dir: str, translations: dict) -> None:
    """Write fastlane files for every locale in translations dict."""
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
    for name, _, project_dir, translations in APPS:
        materialize(project_dir, translations)
        print(f"[{name}] wrote fastlane files for {len(translations)} locales")

    creds = service_account.Credentials.from_service_account_file(SA_KEY, scopes=SCOPES)
    service = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)

    exit_code = 0
    for name, package, project_dir, _ in APPS:
        print(f"\n=== {name} ({package}) ===")
        try:
            edit = service.edits().insert(packageName=package, body={}).execute()
            edit_id = edit["id"]
            for locale in ALL_LOCALES:
                try:
                    blob = read_fastlane(project_dir, locale)
                    lens = (len(blob["title"]), len(blob["short"]), len(blob["full"]))
                    if lens[0] > 30 or lens[1] > 80 or lens[2] > 4000:
                        raise ValueError(f"over limits: title={lens[0]}/30, short={lens[1]}/80, full={lens[2]}/4000")
                    service.edits().listings().update(
                        packageName=package,
                        editId=edit_id,
                        language=locale,
                        body={
                            "language": locale,
                            "title": blob["title"],
                            "shortDescription": blob["short"],
                            "fullDescription": blob["full"],
                        },
                    ).execute()
                    print(f"  [{locale}] OK  ({lens[0]}c / {lens[1]}c / {lens[2]}c)")
                except FileNotFoundError as e:
                    print(f"  [{locale}] SKIP (missing: {e.filename})")
                except Exception as e:
                    print(f"  [{locale}] FAILED: {e}")
                    exit_code = 1
            service.edits().commit(packageName=package, editId=edit_id).execute()
            print(f"  -> committed edit {edit_id}")
        except Exception as e:
            print(f"  FAILED to create/commit edit: {e}")
            exit_code = 1
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
