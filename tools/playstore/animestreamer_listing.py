"""Push the Anime Dance Streamer store listing via the Play Developer API.

Listing texts are read from the markdown files the game repo owns
(``store/listing_<lang>.md``) so the store copy has exactly one source of
truth. One edit: en-US + tr-TR + es-ES + de-DE listing texts, app icon,
feature graphic, phone screenshots, then commit. Rerunnable (each run
replaces the listing).

Graphics are uploaded to en-US only; Play falls back to the default
language's graphics for every listing that has none of its own.

Run: python "C:/Projects/Auto Game Builder/tools/playstore/animestreamer_listing.py"
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
PACKAGE = "com.lifecharger.animestreamer"
STORE = Path(r"C:\Projects\Anime Dance Streamer Clicker\store")

# Play Console hard limits.
TITLE_MAX = 30
SHORT_MAX = 80
FULL_MAX = 4000

# Play language code -> markdown file in STORE.
LISTINGS = {
    "en-US": "listing_en.md",
    "tr-TR": "listing_tr.md",
    "es-ES": "listing_es.md",
    "de-DE": "listing_de.md",
}

# A field header is a whole line of bold text ("**Short description (80):**");
# its value is the rest of that line plus every line up to the next header.
# Labels are localized, so the three fields are taken by ORDER, not by name.
_FIELD_RE = re.compile(r"^\*\*(?P<label>[^*]+?)\*\*[ \t]*(?P<inline>.*)$")
_FIELD_COUNT = 3


def parse_listing(path):
    """Return (title, short, full) from a store/listing_*.md file."""
    sections = []
    for line in path.read_text(encoding="utf-8").splitlines():
        m = _FIELD_RE.match(line)
        if m:
            sections.append((m.group("label"), [m.group("inline")]))
        elif sections:
            sections[-1][1].append(line)

    if len(sections) != _FIELD_COUNT:
        labels = [s[0] for s in sections]
        raise ValueError(
            f"{path.name}: expected {_FIELD_COUNT} bold field headers "
            f"(name / short / full), found {len(sections)}: {labels}")

    title, short, full = ("\n".join(body).strip() for _, body in sections)
    for field, value, limit in (("title", title, TITLE_MAX),
                                ("shortDescription", short, SHORT_MAX),
                                ("fullDescription", full, FULL_MAX)):
        if not value:
            raise ValueError(f"{path.name}: {field} is empty")
        if len(value) > limit:
            raise ValueError(
                f"{path.name}: {field} is {len(value)} chars, limit {limit}")
    return title, short, full


def load_all():
    """Parse every listing up front so a bad file never opens a Play edit."""
    out = {}
    for lang, filename in LISTINGS.items():
        path = STORE / filename
        if not path.is_file():
            raise FileNotFoundError(f"missing listing file: {path}")
        title, short, full = parse_listing(path)
        out[lang] = {"language": lang, "title": title,
                     "shortDescription": short, "fullDescription": full}
        print(f"{lang}: {filename} -> title {len(title)}, "
              f"short {len(short)}, full {len(full)}")
    return out


def main() -> int:
    bodies = load_all()

    creds = service_account.Credentials.from_service_account_file(SA_KEY, scopes=SCOPES)
    svc = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)
    edits = svc.edits()

    edit_id = edits.insert(packageName=PACKAGE, body={}).execute()["id"]
    print("edit:", edit_id)

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
