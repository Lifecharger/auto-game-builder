"""Sync a game's Google Play Games Services achievements and leaderboards
from a JSON spec, idempotently, through the Games Configuration API
(gamesConfiguration v1configuration).

    python tools/playgames/pgs_sync.py <spec.json> [--key-file KEY.json]
        [--application-id ID] [--dart-out lib/.../play_games_ids.dart]
        [--dry-run] [--no-icons] [--list]

The service-account key comes from --key-file or the PGS_SERVICE_ACCOUNT_KEY
environment variable (never hard-code it). The account needs access to the
Play Console developer account that owns the game.

Spec (store/playgames/achievements.json in the game project):

    {
      "applicationId": "1234567890",          # Play Games project id
      "defaultLocale": "en-US",
      "achievements": [{
        "key": "first_blood",                 # stable key - never rename
        "type": "STANDARD" | "INCREMENTAL",
        "steps": 10,                          # INCREMENTAL only
        "points": 5,                          # multiple of 5, total <= 1000
        "initialState": "REVEALED" | "HIDDEN",
        "sortRank": 1,
        "name": {"en-US": "...", "tr-TR": "..."},
        "description": {"en-US": "...", ...},
        "icon": "icons/first_blood.png"       # relative to the spec, 512x512
      }],
      "leaderboards": [{
        "key": "best_wave", "name": {...}, "icon": "...", "sortRank": 1,
        "scoreOrder": "LARGER_IS_BETTER", "scoreMin": 1, "scoreMax": 10000,
        "scoreFormat": {"numberFormatType": "NUMERIC", "numDecimalPlaces": 0,
                        "suffix": {"one": {...}, "other": {...}}}
      }]
    }

Idempotence: the console has no field for our key, so key -> console id is
kept next to the spec in `pgs_ids.json` (commit it). On the first run an
entry without a stored id is matched to an existing console entry by its
default-locale name before anything is inserted, so re-running after a
lost ids file does not duplicate. Existing entries are updated only when a
field differs; icons are re-uploaded only when the file's hash changes.
Achievement type and steps cannot change once published - edit a new key.

--dart-out writes a Dart id table (kPgsApplicationId, kPgsAchievementIds,
kPgsLeaderboardIds keyed by the spec keys) for Flutter games.

New or changed configs land as DRAFTS on the console; publish them from
Play Console -> Play Games Services -> Publishing (no API exists for that).
"""
import argparse
import hashlib
import json
import os
import re
import sys

SCOPE = 'https://www.googleapis.com/auth/androidpublisher'
UPLOAD_URLS = [
    # The image endpoint is no longer in the public discovery document but
    # the upload path is still served; try the API host, then the legacy one.
    'https://gamesconfiguration.googleapis.com/upload/games/v1configuration/images/{rid}/imageType/{kind}',
    'https://www.googleapis.com/upload/games/v1configuration/images/{rid}/imageType/{kind}',
]


def bundle(texts):
    return {
        'kind': 'gamesConfiguration#localizedStringBundle',
        'translations': [
            {'kind': 'gamesConfiguration#localizedString', 'locale': loc, 'value': val}
            for loc, val in sorted(texts.items())
        ],
    }


def bundle_map(b):
    return {t['locale']: t['value'] for t in (b or {}).get('translations', [])}


def default_name(entry_or_detail, locale, from_console=False):
    if from_console:
        names = bundle_map((entry_or_detail or {}).get('name'))
    else:
        names = entry_or_detail['name']
    return names.get(locale) or (next(iter(names.values())) if names else None)


# --------------------------------------------------------------------------
# Spec -> API bodies
# --------------------------------------------------------------------------

def achievement_body(a):
    kind = a['type']
    body = {
        'kind': 'gamesConfiguration#achievementConfiguration',
        'achievementType': kind,
        'initialState': a.get('initialState', 'REVEALED'),
        'draft': {
            'kind': 'gamesConfiguration#achievementConfigurationDetail',
            'name': bundle(a['name']),
            'description': bundle(a['description']),
            'pointValue': a['points'],
        },
    }
    if 'sortRank' in a:
        body['draft']['sortRank'] = a['sortRank']
    if kind == 'INCREMENTAL':
        body['stepsToUnlock'] = a['steps']
    return body


def leaderboard_body(lb):
    fmt = lb.get('scoreFormat', {'numberFormatType': 'NUMERIC'})
    score_format = {'numberFormatType': fmt.get('numberFormatType', 'NUMERIC')}
    if 'numDecimalPlaces' in fmt:
        score_format['numDecimalPlaces'] = fmt['numDecimalPlaces']
    elif score_format['numberFormatType'] == 'NUMERIC':
        # The API rejects a NUMERIC format without it ("No leaderboard score
        # format option specified").
        score_format['numDecimalPlaces'] = 0
    if 'currencyCode' in fmt:
        score_format['currencyCode'] = fmt['currencyCode']
    if fmt.get('suffix'):
        suffix = dict(fmt['suffix'])
        # CLDR gives fr/es/pt/it a "many" plural form; the API rejects the
        # suffix ("Localized string field is missing") unless it is present.
        if 'other' in suffix and 'many' not in suffix:
            suffix['many'] = suffix['other']
        score_format['suffix'] = {k: bundle(v) for k, v in suffix.items()}
    body = {
        'kind': 'gamesConfiguration#leaderboardConfiguration',
        'scoreOrder': lb.get('scoreOrder', 'LARGER_IS_BETTER'),
        'draft': {
            'kind': 'gamesConfiguration#leaderboardConfigurationDetail',
            'name': bundle(lb['name']),
            'scoreFormat': score_format,
        },
    }
    if 'sortRank' in lb:
        body['draft']['sortRank'] = lb['sortRank']
    if 'scoreMin' in lb:
        body['scoreMin'] = str(lb['scoreMin'])
    if 'scoreMax' in lb:
        body['scoreMax'] = str(lb['scoreMax'])
    return body


def _norm_detail(detail):
    """Comparable view of a draft detail (bundles as dicts, no kinds/urls)."""
    out = {}
    for k, v in (detail or {}).items():
        if k in ('kind', 'iconUrl'):
            continue
        if isinstance(v, dict) and 'translations' in v:
            out[k] = bundle_map(v)
        elif isinstance(v, dict):
            out[k] = _norm_detail(v)
        else:
            out[k] = v
    return out


def differs(current, wanted):
    """True when any field we manage differs from the console copy."""
    for k, v in wanted.items():
        if k == 'kind':
            continue
        if k == 'draft':
            cur = _norm_detail(current.get('draft') or current.get('published'))
            if cur != _norm_detail(v):
                return True
        elif str(current.get(k)) != str(v):
            return True
    return False


# --------------------------------------------------------------------------
# API
# --------------------------------------------------------------------------

def build_clients(key_file):
    from google.oauth2 import service_account
    from google.auth.transport.requests import AuthorizedSession
    from googleapiclient.discovery import build

    creds = service_account.Credentials.from_service_account_file(key_file, scopes=[SCOPE])
    service = build('gamesConfiguration', 'v1configuration', credentials=creds, cache_discovery=False)
    return service, AuthorizedSession(creds)


def list_all(resource, app_id):
    items, token = [], None
    while True:
        resp = resource.list(applicationId=app_id, maxResults=200, pageToken=token).execute()
        items.extend(resp.get('items', []))
        token = resp.get('nextPageToken')
        if not token:
            return items


def upload_icon(session, resource_id, kind, path):
    with open(path, 'rb') as f:
        data = f.read()
    errors = []
    for url in UPLOAD_URLS:
        resp = session.post(
            url.format(rid=resource_id, kind=kind),
            params={'uploadType': 'media'},
            data=data,
            headers={'Content-Type': 'image/png'},
        )
        if resp.ok:
            return resp.json().get('url', '')
        errors.append(f'{resp.status_code} {resp.text[:300]}')
    raise RuntimeError('icon upload failed: ' + ' | '.join(errors))


UNSUPPORTED_LOCALES = set()
MANUAL_ICONS = []
_LOCALE_RE = re.compile(r'The locale ([A-Za-z-]+) in the \w+ field is not supported')


def _strip_locales(obj):
    """Drops translations in locales the Play Games project does not list."""
    if isinstance(obj, dict):
        if 'translations' in obj:
            obj = dict(obj)
            obj['translations'] = [t for t in obj['translations'] if t['locale'] not in UNSUPPORTED_LOCALES]
            return obj
        return {k: _strip_locales(v) for k, v in obj.items()}
    return obj


def execute_with_locales(make_request, body):
    """Runs an insert/update; when the console rejects a locale the project
    has not added yet, drops that locale (remembered for the whole run) and
    retries, so everything else still syncs. Add the language in Play
    Console (Play Games Services -> Configuration -> translations) and
    re-run to fill the dropped translations in."""
    from googleapiclient.errors import HttpError

    while True:
        try:
            return make_request(_strip_locales(body)).execute()
        except HttpError as error:
            match = _LOCALE_RE.search(str(error))
            if error.resp.status != 400 or not match or match.group(1) in UNSUPPORTED_LOCALES:
                raise
            UNSUPPORTED_LOCALES.add(match.group(1))
            print(f'    locale {match.group(1)} not enabled on this Play Games project - skipped')


def sha(path):
    with open(path, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()


# --------------------------------------------------------------------------
# Sync
# --------------------------------------------------------------------------

def sync_kind(label, entries, resource, id_param, body_fn, icon_kind, *, app_id,
              locale, state, session, spec_dir, dry_run, icons):
    ids = state.setdefault(label, {})
    icon_hashes = state.setdefault('iconHashes', {})
    console = list_all(resource, app_id)
    by_id = {c['id']: c for c in console}
    by_name = {}
    for c in console:
        name = default_name(c.get('draft') or c.get('published'), locale, from_console=True)
        if name:
            by_name.setdefault(name, c)

    for entry in entries:
        key = entry['key']
        wanted = body_fn(entry)
        current = by_id.get(ids.get(key, ''))
        if current is None:
            current = by_name.get(default_name(entry, locale))
            if current is not None:
                print(f'  {label[:-1]} {key}: matched existing "{current["id"]}" by name')
        if current is None:
            print(f'  {label[:-1]} {key}: INSERT')
            if dry_run:
                continue
            current = execute_with_locales(
                lambda b: resource.insert(applicationId=app_id, body=b), wanted)
        elif differs(current, _strip_locales(wanted)):
            print(f'  {label[:-1]} {key}: UPDATE {current["id"]}')
            if not dry_run:
                body = dict(wanted)
                body['id'] = current['id']
                # Optimistic-concurrency token from the read; updates
                # without it are rejected (410 UpdateTokenInvalid).
                body['token'] = current.get('token', '')
                # Keep the icon the console already holds.
                icon_url = (current.get('draft') or {}).get('iconUrl')
                if icon_url:
                    body['draft'] = dict(body['draft'], iconUrl=icon_url)
                current = execute_with_locales(
                    lambda b: resource.update(**{id_param: current['id']}, body=b), body)
        else:
            print(f'  {label[:-1]} {key}: up to date ({current["id"]})')
        ids[key] = current['id']

        icon = entry.get('icon')
        if icons and icon:
            path = os.path.join(spec_dir, icon)
            digest = sha(path)
            has_icon = bool((current.get('draft') or current.get('published') or {}).get('iconUrl'))
            if icon_hashes.get(current['id']) == digest and has_icon:
                continue
            print(f'    icon {icon}: UPLOAD')
            if not dry_run:
                try:
                    upload_icon(session, current['id'], icon_kind, path)
                    icon_hashes[current['id']] = digest
                except RuntimeError as error:
                    # The image endpoint has been answering 503 since it left
                    # the discovery doc; list the icon for a console upload
                    # instead of aborting the whole sync.
                    print(f'    icon upload unavailable ({error}); upload it in Play Console')
                    MANUAL_ICONS.append((key, current['id'], path))


def write_dart(path, app_id, spec, state):
    ach = state.get('achievements', {})
    lbs = state.get('leaderboards', {})
    lines = [
        '// GENERATED by Auto Game Builder tools/playgames/pgs_sync.py from',
        '// store/playgames/achievements.json - re-run the sync instead of editing.',
        '//',
        "// Google Play Games Services ids, keyed by the spec's stable keys. An",
        '// empty id means "not created on the console yet": PlayGamesService skips',
        '// every call whose id is empty. The Play Games project id itself lives in',
        '// android/app/src/main/res/values/games_ids.xml (game_services_project_id).',
        '',
        '/// Play Games project (application) id.',
        f"const String kPgsApplicationId = '{app_id}';",
        '',
        '/// Achievement key -> Play Games achievement id.',
        'const Map<String, String> kPgsAchievementIds = {',
    ]
    lines += [f"  '{a['key']}': '{ach.get(a['key'], '')}'," for a in spec.get('achievements', [])]
    lines += ['};', '', '/// Leaderboard key -> Play Games leaderboard id.',
              'const Map<String, String> kPgsLeaderboardIds = {']
    lines += [f"  '{lb['key']}': '{lbs.get(lb['key'], '')}'," for lb in spec.get('leaderboards', [])]
    lines += ['};', '']
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines))
    print(f'wrote {path}')


def validate(spec):
    total = 0
    keys = set()
    for a in spec.get('achievements', []):
        if a['key'] in keys:
            raise SystemExit(f'duplicate key {a["key"]}')
        keys.add(a['key'])
        if a['points'] % 5 or not 0 <= a['points'] <= 200:
            raise SystemExit(f'{a["key"]}: points must be a multiple of 5 in 0..200')
        if a['type'] == 'INCREMENTAL' and not 2 <= a.get('steps', 0) <= 10000:
            raise SystemExit(f'{a["key"]}: INCREMENTAL needs steps in 2..10000')
        total += a['points']
    if total > 1000:
        raise SystemExit(f'total points {total} > 1000')
    for lb in spec.get('leaderboards', []):
        if lb['key'] in keys:
            raise SystemExit(f'duplicate key {lb["key"]}')
        keys.add(lb['key'])


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('spec')
    ap.add_argument('--key-file', default=os.environ.get('PGS_SERVICE_ACCOUNT_KEY'))
    ap.add_argument('--application-id')
    ap.add_argument('--ids-file', help='default: pgs_ids.json next to the spec')
    ap.add_argument('--dart-out')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--no-icons', action='store_true')
    ap.add_argument('--list', action='store_true', help='print what the console holds and exit')
    args = ap.parse_args()

    spec_path = os.path.abspath(args.spec)
    spec_dir = os.path.dirname(spec_path)
    with open(spec_path, encoding='utf-8') as f:
        spec = json.load(f)
    validate(spec)
    app_id = args.application_id or spec.get('applicationId')
    if not app_id:
        raise SystemExit('no applicationId (spec or --application-id)')
    if not args.key_file:
        raise SystemExit('pass --key-file or set PGS_SERVICE_ACCOUNT_KEY')
    locale = spec.get('defaultLocale', 'en-US')
    ids_path = args.ids_file or os.path.join(spec_dir, 'pgs_ids.json')
    state = {}
    if os.path.exists(ids_path):
        with open(ids_path, encoding='utf-8') as f:
            state = json.load(f)

    service, session = build_clients(args.key_file)
    if args.list:
        for label, res in (('achievements', service.achievementConfigurations()),
                           ('leaderboards', service.leaderboardConfigurations())):
            print(f'== {label}')
            for c in list_all(res, app_id):
                d = c.get('draft') or c.get('published') or {}
                print(f"  {c['id']}  {default_name(d, locale, True)}  "
                      f"pts={d.get('pointValue', '-')} icon={'yes' if d.get('iconUrl') else 'no'}")
        return

    common = dict(app_id=app_id, locale=locale, state=state, session=session,
                  spec_dir=spec_dir, dry_run=args.dry_run, icons=not args.no_icons)
    try:
        print('achievements:')
        sync_kind('achievements', spec.get('achievements', []), service.achievementConfigurations(),
                  'achievementId', achievement_body, 'ACHIEVEMENT_ICON', **common)
        print('leaderboards:')
        sync_kind('leaderboards', spec.get('leaderboards', []), service.leaderboardConfigurations(),
                  'leaderboardId', leaderboard_body, 'LEADERBOARD_ICON', **common)
    finally:
        # Persist every id obtained so far, even when a later call failed,
        # so the next run updates instead of inserting duplicates.
        if not args.dry_run:
            state['applicationId'] = app_id
            with open(ids_path, 'w', encoding='utf-8', newline='\n') as f:
                json.dump(state, f, indent=2, sort_keys=True)
                f.write('\n')
            print(f'wrote {ids_path}')
    if args.dart_out and not args.dry_run:
        write_dart(args.dart_out, app_id, spec, state)
    status = 0
    if MANUAL_ICONS:
        print(f'NOTE: {len(MANUAL_ICONS)} icon(s) could not be uploaded by API; upload them in '
              'Play Console (Play Games Services -> Achievements/Leaderboards -> entry -> Icon):')
        for key, rid, path in MANUAL_ICONS:
            print(f'  {key}  {rid}  {path}')
        status = 2
    if UNSUPPORTED_LOCALES:
        print('NOTE: these locales are not enabled on the Play Games project and were '
              'skipped: ' + ', '.join(sorted(UNSUPPORTED_LOCALES)) +
              '. Add them in Play Console and re-run this sync to upload the translations.')
        status = 2
    return status


if __name__ == '__main__':
    sys.exit(main())
