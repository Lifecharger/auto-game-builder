"""Complete the AdMob part of the Data safety declaration for the nine ad-supported apps, following Google's own
"Google Mobile Ads SDK - Play data disclosure": the SDK collects AND shares approximate location (from the IP),
app interactions, diagnostics and device ids, for advertising, analytics and fraud prevention. Input: the merged
CSVs that were already pushed (analytics types included). Purely additive, except that user control for the
ad-collected types becomes REQUIRED (single choice; a player cannot switch the ad SDK's collection off)."""
import csv, io, sys

APPS = ["hotjigsaw", "hotcharm", "hotslider", "hotidle", "projigsaw", "sentience", "arcadesnake", "beestriker", "deathpin"]
FOLDER = "C:/Users/caca_/Downloads/datasafety/merged/%s.csv"
U = "PSL_DATA_USAGE_RESPONSES:%s:%s"
PURPOSES = ["PSL_ADVERTISING", "PSL_ANALYTICS", "PSL_FRAUD_PREVENTION_SECURITY"]
TYPES = [("PSL_DATA_TYPES_LOCATION", "PSL_APPROX_LOCATION"), ("PSL_DATA_TYPES_APP_ACTIVITY", "PSL_USER_INTERACTION"),
         ("PSL_DATA_TYPES_APP_PERFORMANCE", "PSL_PERFORMANCE_DIAGNOSTICS"), ("PSL_DATA_TYPES_IDENTIFIERS", "PSL_DEVICE_ID")]

for slug in APPS:
    path = FOLDER % slug
    rows = list(csv.reader(io.open(path, encoding="utf-8", newline="")))
    index = {(r[0], r[1]): r for r in rows[1:]}
    changed = []

    def put(q, resp, value):
        row = index.get((q, resp))
        if row is None:
            sys.exit("row missing: %s | %s" % (q, resp))
        if row[2].strip() != value:
            changed.append((q.replace("PSL_DATA_USAGE_RESPONSES:", ""), resp, row[2].strip(), value))
            row[2] = value

    for group, t in TYPES:
        put(group, t, "true")
        put(U % (t, "PSL_DATA_USAGE_COLLECTION_AND_SHARING"), "PSL_DATA_USAGE_ONLY_COLLECTED", "true")
        put(U % (t, "PSL_DATA_USAGE_COLLECTION_AND_SHARING"), "PSL_DATA_USAGE_ONLY_SHARED", "true")
        put(U % (t, "PSL_DATA_USAGE_EPHEMERAL"), "", "false")
        put(U % (t, "DATA_USAGE_USER_CONTROL"), "PSL_DATA_USAGE_USER_CONTROL_OPTIONAL", "")
        put(U % (t, "DATA_USAGE_USER_CONTROL"), "PSL_DATA_USAGE_USER_CONTROL_REQUIRED", "true")
        for purpose in PURPOSES:
            put(U % (t, "DATA_USAGE_COLLECTION_PURPOSE"), purpose, "true")
            put(U % (t, "DATA_USAGE_SHARING_PURPOSE"), purpose, "true")
    with io.open(path, "w", encoding="utf-8", newline="") as f:
        csv.writer(f, lineterminator="\n").writerows(rows)
    print("== %s: %d answers changed" % (slug, len(changed)))
    if slug == APPS[0]:
        for c in changed:
            print("   %s | %s: '%s' -> '%s'" % c)
