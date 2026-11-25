"""Mirrors a game's Play Games achievements + leaderboards into Game Center (App Store Connect API).

usage: asc_gamecenter.py <bundle id> <achievements.json> [--apply]
Idempotent: matches by vendorIdentifier "<prefix>.<key>" / "<prefix>.lb.<key>", creates only what is
missing (entries, localizations, images). Without --apply it only prints the plan.
Writes <achievements.json dir>/gamecenter_ids.json {"achievements": {key: vendorId}, "leaderboards": {...}}.
Key material: ~/keys/apple_api_key_info.json (never printed).
"""
import hashlib
import json
import os
import sys
import time

import jwt
import requests

info = json.load(open(os.path.expanduser('~/keys/apple_api_key_info.json')))
key_file = os.path.expanduser(info.get('key_file') or '')
if not os.path.isfile(key_file):
    key_file = os.path.expanduser(f"~/keys/AuthKey_{info['key_id']}.p8")
PK = open(key_file).read()
BASE = 'https://api.appstoreconnect.apple.com/v1/'
# Play locale -> App Store Connect locale.
LOCALE = {'en-US': 'en-US', 'tr-TR': 'tr', 'de-DE': 'de-DE', 'es-ES': 'es-ES', 'fr-FR': 'fr-FR', 'ja-JP': 'ja',
          'pt-BR': 'pt-BR', 'pt-PT': 'pt-PT'}


def tok():
    now = int(time.time())
    return jwt.encode({'iss': info['issuer_id'], 'exp': now + 1200, 'aud': 'appstoreconnect-v1'}, PK,
                      algorithm='ES256', headers={'kid': info['key_id'], 'typ': 'JWT'})


def call(method, path, **kw):
    url = path if path.startswith('http') else BASE + path
    for attempt in range(4):
        r = requests.request(method, url, headers={'Authorization': f'Bearer {tok()}'}, timeout=60, **kw)
        if r.status_code == 429 or r.status_code >= 500:
            time.sleep(3 + attempt * 5)
            continue
        break
    if r.status_code >= 400:
        raise RuntimeError(f'{method} {path} -> HTTP {r.status_code} {r.text[:1500]}')
    return r.json() if r.text else {}


def all_pages(path, params=None):
    out = []
    d = call('GET', path, params=params or {'limit': 200})
    out += d.get('data', [])
    while d.get('links', {}).get('next'):
        d = call('GET', d['links']['next'])
        out += d.get('data', [])
    return out


def rel(t, i):
    return {'data': {'type': t, 'id': i}}


def upload_image(kind, loc_rel_name, loc_id, path):
    data = open(path, 'rb').read()
    res = call('POST', f'{kind}', json={'data': {
        'type': kind, 'attributes': {'fileSize': len(data), 'fileName': os.path.basename(path)},
        'relationships': {loc_rel_name: rel(loc_rel_name + 's', loc_id)}}})['data']
    for op in res['attributes']['uploadOperations']:
        chunk = data[op['offset']:op['offset'] + op['length']]
        h = {x['name']: x['value'] for x in op.get('requestHeaders', [])}
        r = requests.request(op['method'], op['url'], headers=h, data=chunk, timeout=120)
        r.raise_for_status()
    call('PATCH', f"{kind}/{res['id']}", json={'data': {
        'type': kind, 'id': res['id'],
        'attributes': {'uploaded': True}}})


def main():
    bundle, cfg_path = sys.argv[1], sys.argv[2]
    apply = '--apply' in sys.argv
    prefix = sys.argv[sys.argv.index('--prefix') + 1] if '--prefix' in sys.argv else bundle.split('.')[-1]
    cfg = json.load(open(cfg_path))
    base_dir = os.path.dirname(os.path.abspath(cfg_path))

    app = call('GET', 'apps', params={'filter[bundleId]': bundle})['data']
    app = [a for a in app if a['attributes']['bundleId'] == bundle][0]
    print('app', app['id'], app['attributes']['name'])

    detail = call('GET', f"apps/{app['id']}/gameCenterDetail").get('data')
    if not detail:
        print('PLAN create gameCenterDetail')
        if not apply:
            return
        detail = call('POST', 'gameCenterDetails', json={'data': {
            'type': 'gameCenterDetails', 'relationships': {'app': rel('apps', app['id'])}}})['data']
    gid = detail['id']
    print('gameCenterDetail', gid)

    have_ach = {a['attributes']['vendorIdentifier']: a for a in
                all_pages(f'gameCenterDetails/{gid}/gameCenterAchievements')}
    have_lb = {a['attributes']['vendorIdentifier']: a for a in
               all_pages(f'gameCenterDetails/{gid}/gameCenterLeaderboards')}
    ids = {'achievements': {}, 'leaderboards': {}}

    for a in sorted(cfg['achievements'], key=lambda x: x.get('sortRank', 0)):
        vid = f"{prefix}.{a['key']}"
        ids['achievements'][a['key']] = vid
        ent = have_ach.get(vid)
        if not ent:
            print('PLAN achievement', vid, a['points'])
            if not apply:
                continue
            ent = call('POST', 'gameCenterAchievements', json={'data': {
                'type': 'gameCenterAchievements',
                'attributes': {'referenceName': a['name']['en-US'][:64], 'vendorIdentifier': vid,
                               'points': int(a['points']), 'showBeforeEarned': True, 'repeatable': False},
                'relationships': {'gameCenterDetail': rel('gameCenterDetails', gid)}}})['data']
        locs = {l['attributes']['locale']: l for l in all_pages(f"gameCenterAchievements/{ent['id']}/localizations")}
        for play_loc, asc_loc in LOCALE.items():
            if play_loc not in a['name']:
                continue
            loc = locs.get(asc_loc)
            if not loc:
                print('PLAN   loc', vid, asc_loc)
                if not apply:
                    continue
                desc = a['description'][play_loc]
                loc = call('POST', 'gameCenterAchievementLocalizations', json={'data': {
                    'type': 'gameCenterAchievementLocalizations',
                    'attributes': {'locale': asc_loc, 'name': a['name'][play_loc][:30],
                                   'beforeEarnedDescription': desc[:200], 'afterEarnedDescription': desc[:200]},
                    'relationships': {'gameCenterAchievement': rel('gameCenterAchievements', ent['id'])}}})['data']
            img = call('GET', f"gameCenterAchievementLocalizations/{loc['id']}/gameCenterAchievementImage").get('data')
            state = ((img or {}).get('attributes', {}).get('assetDeliveryState') or {}).get('state')
            if img and state in ('FAILED', 'AWAITING_UPLOAD') and apply:
                call('DELETE', f"gameCenterAchievementImages/{img['id']}")
                img = None
            if not img:
                print('PLAN   image', vid, asc_loc)
                if apply:
                    upload_image('gameCenterAchievementImages', 'gameCenterAchievementLocalization', loc['id'],
                                 os.path.join(base_dir, a['icon']))

    for lb in sorted(cfg['leaderboards'], key=lambda x: x.get('sortRank', 0)):
        vid = f"{prefix}.lb.{lb['key']}"
        ids['leaderboards'][lb['key']] = vid
        ent = have_lb.get(vid)
        if not ent:
            print('PLAN leaderboard', vid)
            if not apply:
                continue
            ent = call('POST', 'gameCenterLeaderboards', json={'data': {
                'type': 'gameCenterLeaderboards',
                'attributes': {'referenceName': lb['name']['en-US'][:64], 'vendorIdentifier': vid,
                               'defaultFormatter': 'INTEGER', 'submissionType': 'BEST_SCORE',
                               'scoreSortType': 'DESC' if lb.get('scoreOrder') != 'SMALLER_IS_BETTER' else 'ASC'},
                'relationships': {'gameCenterDetail': rel('gameCenterDetails', gid)}}})['data']
        locs = {l['attributes']['locale']: l for l in all_pages(f"gameCenterLeaderboards/{ent['id']}/localizations")}
        for play_loc, asc_loc in LOCALE.items():
            if play_loc not in lb['name']:
                continue
            loc = locs.get(asc_loc)
            if not loc:
                print('PLAN   loc', vid, asc_loc)
                if not apply:
                    continue
                loc = call('POST', 'gameCenterLeaderboardLocalizations', json={'data': {
                    'type': 'gameCenterLeaderboardLocalizations',
                    'attributes': {'locale': asc_loc, 'name': lb['name'][play_loc][:30]},
                    'relationships': {'gameCenterLeaderboard': rel('gameCenterLeaderboards', ent['id'])}}})['data']
            if lb.get('icon'):
                img = call('GET', f"gameCenterLeaderboardLocalizations/{loc['id']}/gameCenterLeaderboardImage").get('data')
                if not img:
                    print('PLAN   image', vid, asc_loc)
                    if apply:
                        try:
                            upload_image('gameCenterLeaderboardImages', 'gameCenterLeaderboardLocalization',
                                         loc['id'], os.path.join(base_dir, lb['icon']))
                        except Exception as e:  # leaderboard art is optional on Game Center
                            print('     leaderboard image refused:', str(e)[:300])

    if apply:
        out = os.path.join(base_dir, 'gamecenter_ids.json')
        json.dump(ids, open(out, 'w'), indent=2)
        print('wrote', out)


main()
