"""Push every store/listing/<locale>.md file of a project to its Google Play listing.

`push_listings.py` hard-codes the Hot Slider / Hot Jigsaw / Hot Charm listings in
Python dicts. This script instead reads the Markdown listing files that
Sentience and Auto Game Builder keep under `store/listing/`, so a listing is
edited in one place (the .md file) and pushed from there.

File format (one file per Play locale, named `<locale>.md`, e.g. `en-US.md`,
`pt-PT.md`, `ja-JP.md`):

    # Title
    Auto Game Builder

    # Short Description
    Remote control your dev PC from your phone.

    # Full Description
    Auto Game Builder is the companion app for ...

Headings must be exactly `# Title`, `# Short Description` and `# Full
Description`, each on its own line. Everything between one heading and the next
is that field's value, stripped of surrounding blank lines. Google Play limits
are enforced before anything is sent: title 30, short description 80, full
description 4000 characters.

All locales found in the directory go into a single Play edit, which is then
validated and committed, so either every locale lands or none does.

Usage
-----
Dry run (parses and prints lengths, contacts no API at all)::

    python tools/playstore/push_md_listings.py \
        --project "C:/Projects/Auto Game Builder/app" \
        --package com.lifecharger.appmanager \
        --dry-run

Real upload::

    python tools/playstore/push_md_listings.py \
        --project "C:/Projects/Auto Game Builder/app" \
        --package com.lifecharger.appmanager

Options
-------
--project     Project root that contains `store/listing/` (required).
--package     Play package name, e.g. com.lifecharger.appmanager (required).
--listing-dir Override the listing directory (default `<project>/store/listing`).
--locales     Space-separated subset of locales to push (default: every .md
              file in the listing directory).
--service-account
              Service-account JSON key (default D:/keys/arcade-snake-488801-35f27b42dfb3.json).
--dry-run     Parse and validate only; never touches the Play API.

Requires `google-api-python-client` and `google-auth` (already used by the other
scripts in this folder).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

DEFAULT_SERVICE_ACCOUNT = "D:/keys/arcade-snake-488801-35f27b42dfb3.json"

# Google Play listing limits.
MAX_TITLE = 30
MAX_SHORT = 80
MAX_FULL = 4000

FIELDS = ("Title", "Short Description", "Full Description")
_HEADING_RE = re.compile(r"^# (Title|Short Description|Full Description)\s*$", re.M)


class ListingError(Exception):
    """A listing file is missing a section or breaks a Play length limit."""


def parse_listing(md: str, source: str) -> dict[str, str]:
    """Split a listing Markdown file into its three fields.

    Raises ListingError when a heading is missing, duplicated, or a field is
    empty. `source` only shows up in error messages.
    """
    parts = _HEADING_RE.split(md)
    if len(parts) < 2:
        raise ListingError(f"{source}: no '# Title' / '# Short Description' / "
                           f"'# Full Description' headings found")
    if parts[0].strip():
        raise ListingError(f"{source}: unexpected text before the first heading")

    found: dict[str, str] = {}
    for i in range(1, len(parts), 2):
        name, value = parts[i], parts[i + 1].strip()
        if name in found:
            raise ListingError(f"{source}: duplicate '# {name}' heading")
        found[name] = value

    missing = [f for f in FIELDS if f not in found]
    if missing:
        raise ListingError(f"{source}: missing heading(s): "
                           + ", ".join(f"# {m}" for m in missing))
    empty = [f for f in FIELDS if not found[f]]
    if empty:
        raise ListingError(f"{source}: empty section(s): "
                           + ", ".join(f"# {e}" for e in empty))

    return {
        "title": found["Title"],
        "short": found["Short Description"],
        "full": found["Full Description"],
    }


def validate_lengths(listing: dict[str, str], source: str) -> None:
    """Enforce the Play 30 / 80 / 4000 character limits."""
    over = []
    for field, limit, label in (
        ("title", MAX_TITLE, "title"),
        ("short", MAX_SHORT, "short description"),
        ("full", MAX_FULL, "full description"),
    ):
        n = len(listing[field])
        if n > limit:
            over.append(f"{label} is {n} chars (max {limit}, {n - limit} over)")
    if over:
        raise ListingError(f"{source}: " + "; ".join(over))


def load_listings(listing_dir: Path, locales: list[str] | None) -> dict[str, dict[str, str]]:
    """Read and validate every requested locale under `listing_dir`."""
    if not listing_dir.is_dir():
        raise ListingError(f"listing directory not found: {listing_dir}")

    if locales:
        paths = []
        for loc in locales:
            p = listing_dir / f"{loc}.md"
            if not p.is_file():
                raise ListingError(f"no listing file for locale {loc}: {p}")
            paths.append(p)
    else:
        paths = sorted(listing_dir.glob("*.md"))
        if not paths:
            raise ListingError(f"no *.md listing files in {listing_dir}")

    out: dict[str, dict[str, str]] = {}
    errors: list[str] = []
    for p in paths:
        locale = p.stem
        try:
            listing = parse_listing(p.read_text(encoding="utf-8"), p.name)
            validate_lengths(listing, p.name)
        except ListingError as exc:
            errors.append(str(exc))
            continue
        out[locale] = listing

    if errors:
        raise ListingError("\n".join(errors))
    return out


def report(listings: dict[str, dict[str, str]]) -> None:
    print(f"{'locale':<10} {'title':>7} {'short':>7} {'full':>7}   title")
    print("-" * 72)
    for locale, l in listings.items():
        print(f"{locale:<10} {len(l['title']):>5}/{MAX_TITLE} "
              f"{len(l['short']):>5}/{MAX_SHORT} {len(l['full']):>5}/{MAX_FULL}   "
              f"{l['title']}")


def push(package: str, listings: dict[str, dict[str, str]], service_account_file: str) -> None:
    """Upload every locale in one Play edit, then validate and commit it."""
    from google.oauth2 import service_account
    from googleapiclient.discovery import build

    creds = service_account.Credentials.from_service_account_file(
        service_account_file,
        scopes=["https://www.googleapis.com/auth/androidpublisher"],
    )
    svc = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)

    edit_id = svc.edits().insert(packageName=package, body={}).execute()["id"]
    print(f"edit {edit_id} opened for {package}")

    existing = [
        l["language"]
        for l in svc.edits().listings()
        .list(packageName=package, editId=edit_id).execute().get("listings", [])
    ]
    print("existing locales:", ", ".join(sorted(existing)) or "(none)")

    for locale, l in listings.items():
        svc.edits().listings().update(
            packageName=package,
            editId=edit_id,
            language=locale,
            body={
                "language": locale,
                "title": l["title"],
                "shortDescription": l["short"],
                "fullDescription": l["full"],
            },
        ).execute()
        verb = "updated" if locale in existing else "created"
        print(f"  {verb} {locale}")

    svc.edits().validate(packageName=package, editId=edit_id).execute()
    svc.edits().commit(packageName=package, editId=edit_id).execute()
    print(f"committed {len(listings)} locale(s)")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description="Push store/listing/<locale>.md files to a Google Play listing.")
    ap.add_argument("--project", required=True,
                    help="project root containing store/listing/")
    ap.add_argument("--package", required=True,
                    help="Play package name, e.g. com.lifecharger.appmanager")
    ap.add_argument("--listing-dir", default=None,
                    help="override the listing directory (default <project>/store/listing)")
    ap.add_argument("--locales", nargs="*", default=None,
                    help="subset of locales to push (default: all *.md in the directory)")
    ap.add_argument("--service-account", default=DEFAULT_SERVICE_ACCOUNT,
                    help=f"service-account JSON key (default {DEFAULT_SERVICE_ACCOUNT})")
    ap.add_argument("--dry-run", action="store_true",
                    help="parse and validate only; do not contact the Play API")
    args = ap.parse_args(argv)

    listing_dir = (Path(args.listing_dir) if args.listing_dir
                   else Path(args.project) / "store" / "listing")

    try:
        listings = load_listings(listing_dir, args.locales)
    except ListingError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(f"{len(listings)} locale(s) parsed from {listing_dir}")
    report(listings)

    if args.dry_run:
        print("\ndry run - nothing uploaded")
        return 0

    try:
        push(args.package, listings, args.service_account)
    except FileNotFoundError:
        print(f"error: service account key not found: {args.service_account}",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
