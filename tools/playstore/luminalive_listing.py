"""Push the Lumina Live store listing via the Play Developer API.

Listing texts are read from the markdown files the game repo owns
(``store/listing/<play-locale>.md``) so the store copy has exactly one source
of truth. One edit: contact details, en-US + tr-TR listing texts, app icon,
feature graphic, phone screenshots, then commit. Rerunnable (each run replaces
the listing).

Graphics are uploaded to en-US only; Play falls back to the default language's
graphics for every listing that has none of its own.

Run: python "C:/Projects/Auto Game Builder/tools/playstore/luminalive_listing.py"
"""
import os
import re
from pathlib import Path

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

SA_KEY = "D:/keys/arcade-snake-488801-5ac9863bb0ab.json"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
PACKAGE = "com.lifecharger.luminalive"
STORE = Path(r"C:\Projects\Lumina Live\store")
LISTING_DIR = STORE / "listing"

# Support address shown on the Play store page.
CONTACT_EMAIL = "support@lifechargergames.com"

# Play Console hard limits.
TITLE_MAX = 30
SHORT_MAX = 80
FULL_MAX = 4000

# Play language codes; each one is `<code>.md` in LISTING_DIR.
LOCALES = ("en-US", "tr-TR")

# Sentience listing format: `# Title`, `# Short Description`, `# Full
# Description`, each heading alone on its line, value = everything up to the
# next heading.
_HEADING_RE = re.compile(r"^# (Title|Short Description|Full Description)\s*$", re.M)
_FIELDS = (("Title", "title", TITLE_MAX),
           ("Short Description", "shortDescription", SHORT_MAX),
           ("Full Description", "fullDescription", FULL_MAX))


def parse_listing(path):
    """Return {title, shortDescription, fullDescription} from a listing .md."""
    parts = _HEADING_RE.split(path.read_text(encoding="utf-8"))
    if parts[0].strip():
        raise ValueError(f"{path.name}: text before the first '# ' heading")

    sections = {}
    for heading, body in zip(parts[1::2], parts[2::2]):
        if heading in sections:
            raise ValueError(f"{path.name}: duplicate '# {heading}' heading")
        sections[heading] = body.strip()

    out = {}
    for heading, field, limit in _FIELDS:
        value = sections.get(heading, "")
        if not value:
            raise ValueError(f"{path.name}: missing or empty '# {heading}'")
        if len(value) > limit:
            raise ValueError(
                f"{path.name}: {field} is {len(value)} chars, limit {limit}")
        out[field] = value
    return out


def load_all():
    """Parse every listing up front so a bad file never opens a Play edit."""
    bodies = {}
    for lang in LOCALES:
        path = LISTING_DIR / f"{lang}.md"
        if not path.is_file():
            raise FileNotFoundError(f"missing listing file: {path}")
        listing = parse_listing(path)
        bodies[lang] = {"language": lang, **listing}
        print(f"{lang}: {path.name} -> title {len(listing['title'])}, "
              f"short {len(listing['shortDescription'])}, "
              f"full {len(listing['fullDescription'])}")
    return bodies


def main() -> int:
    bodies = load_all()

    creds = service_account.Credentials.from_service_account_file(SA_KEY, scopes=SCOPES)
    svc = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)
    edits = svc.edits()

    edit_id = edits.insert(packageName=PACKAGE, body={}).execute()["id"]
    print("edit:", edit_id)

    # Keep the rest of the contact block (website, phone, default language) and
    # only replace the support address.
    details = edits.details().get(packageName=PACKAGE, editId=edit_id).execute()
    details["contactEmail"] = CONTACT_EMAIL
    edits.details().update(
        packageName=PACKAGE, editId=edit_id, body=details).execute()
    print("contact email:", CONTACT_EMAIL)

    for lang, body in bodies.items():
        edits.listings().update(
            packageName=PACKAGE, editId=edit_id, language=lang, body=body,
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

    clear("icon"); upload("icon", str(STORE / "icon_512.png"))
    clear("featureGraphic"); upload("featureGraphic", str(STORE / "feature_graphic.png"))
    clear("phoneScreenshots")
    shots_dir = STORE / "screenshots"
    for shot in sorted(p for p in shots_dir.iterdir() if p.suffix == ".png"):
        upload("phoneScreenshots", str(shot))

    edits.commit(packageName=PACKAGE, editId=edit_id).execute()
    print("COMMITTED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
