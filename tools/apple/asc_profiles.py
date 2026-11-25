"""List (or delete one) App Store provisioning profiles of a bundle id. usage: asc_profiles.py <bundle> [delete <profile id>]"""
import sys
sys.argv = [sys.argv[0], 'noop'] + sys.argv[1:]
exec(open(__file__.replace('asc_profiles.py', 'asc_caps.py')).read().split("cmd = sys.argv[1]")[0])
args = sys.argv[2:]
b = bundle(args[0])
profs = call('GET', f"bundleIds/{b['id']}/profiles", params={'limit': 50})['data']
for p in profs:
    a = p['attributes']
    print(p['id'], a['name'], a['profileType'], a['profileState'], a.get('expirationDate', '')[:10], a.get('uuid'))
if len(args) == 3 and args[1] == 'delete':
    call('DELETE', f'profiles/{args[2]}')
    print('deleted', args[2])
