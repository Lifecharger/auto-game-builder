"""Lists / enables bundle-id capabilities via the App Store Connect API.

usage: asc_caps.py list <bundle id>...
       asc_caps.py enable <CAPABILITY_TYPE> <bundle id>...
Key material is read from ~/keys/apple_api_key_info.json and never printed.
"""
import json
import os
import sys
import time

import jwt
import requests

info = json.load(open(os.path.expanduser('~/keys/apple_api_key_info.json')))
key_file = os.path.expanduser(info['key_file']) if info.get('key_file') else os.path.expanduser(
    f"~/keys/AuthKey_{info['key_id']}.p8")
if not os.path.isfile(key_file):
    key_file = os.path.expanduser(f"~/keys/AuthKey_{info['key_id']}.p8")
PK = open(key_file).read()
BASE = 'https://api.appstoreconnect.apple.com/v1/'


def tok():
    now = int(time.time())
    return jwt.encode({'iss': info['issuer_id'], 'exp': now + 1200, 'aud': 'appstoreconnect-v1'}, PK,
                      algorithm='ES256', headers={'kid': info['key_id'], 'typ': 'JWT'})


def call(method, path, **kw):
    r = requests.request(method, BASE + path, headers={'Authorization': f'Bearer {tok()}'}, timeout=60, **kw)
    if r.status_code >= 400:
        print('HTTP', r.status_code, r.text[:800])
        r.raise_for_status()
    return r.json() if r.text else {}


def bundle(ident):
    d = call('GET', 'bundleIds', params={'filter[identifier]': ident, 'limit': 5})['data']
    d = [x for x in d if x['attributes']['identifier'] == ident]
    if not d:
        raise SystemExit(f'no bundle id {ident}')
    return d[0]


def caps(bid):
    return [c['attributes']['capabilityType'] for c in call('GET', f'bundleIds/{bid}/bundleIdCapabilities')['data']]


cmd = sys.argv[1]
if cmd == 'list':
    for ident in sys.argv[2:]:
        b = bundle(ident)
        print(ident, b['id'], sorted(caps(b['id'])))
elif cmd == 'enable':
    cap = sys.argv[2]
    for ident in sys.argv[3:]:
        b = bundle(ident)
        have = caps(b['id'])
        if cap in have:
            print(ident, 'already has', cap)
            continue
        attrs = {'capabilityType': cap}
        if cap == "APPLE_ID_AUTH":
            attrs['settings'] = [{'key': 'APPLE_ID_AUTH_APP_CONSENT',
                                  'options': [{'key': 'PRIMARY_APP_CONSENT'}]}]
        call('POST', 'bundleIdCapabilities', json={'data': {
            'type': 'bundleIdCapabilities', 'attributes': attrs,
            'relationships': {'bundleId': {'data': {'type': 'bundleIds', 'id': b['id']}}}}})
        print(ident, 'enabled', cap, '->', sorted(caps(b['id'])))
