"""Create + activate Anime Dance Streamer VIP products (vip_month P1M $1.49, vip_year P1Y $14.99, one-time vip $19.99) by cloning Hot Idle's VIP ladder. Run once; re-runs are idempotent. Ran 2026-09-14: all three ACTIVE."""
import json, sys
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
SA="D:/keys/arcade-snake-488801-5ac9863bb0ab.json"
SRC="com.lifecharger.hotidle"; DST="com.lifecharger.animestreamer"
REGIONS_VERSION="2025/03"
creds=service_account.Credentials.from_service_account_file(SA,scopes=["https://www.googleapis.com/auth/androidpublisher"])
svc=build("androidpublisher","v3",credentials=creds,cache_discovery=False)
mon=svc.monetization()

LISTINGS={
 "vip_month":[("en-US","Monthly VIP","No ads and +4 hours of offline earnings. Renews monthly."),
              ("tr-TR","Aylık VIP","Reklamsız ve +4 saat çevrimdışı kazanç. Aylık yenilenir."),
              ("de-DE","Monats-VIP","Keine Werbung und +4 Stunden Offline-Einnahmen. Verlängert sich monatlich."),
              ("es-ES","VIP mensual","Sin anuncios y +4 horas de ganancias sin conexión. Se renueva cada mes.")],
 "vip_year":[("en-US","Yearly VIP","No ads and +4 hours of offline earnings. Renews yearly."),
             ("tr-TR","Yıllık VIP","Reklamsız ve +4 saat çevrimdışı kazanç. Yıllık yenilenir."),
             ("de-DE","Jahres-VIP","Keine Werbung und +4 Stunden Offline-Einnahmen. Verlängert sich jährlich."),
             ("es-ES","VIP anual","Sin anuncios y +4 horas de ganancias sin conexión. Se renueva cada año.")],
 "vip":[("en-US","Lifetime VIP","No ads and +4 hours of offline earnings, forever. One-time purchase."),
        ("tr-TR","Ömür Boyu VIP","Sonsuza kadar reklamsız ve +4 saat çevrimdışı kazanç. Tek seferlik."),
        ("de-DE","Lebenslanges VIP","Keine Werbung und +4 Stunden Offline-Einnahmen, für immer. Einmalkauf."),
        ("es-ES","VIP de por vida","Sin anuncios y +4 horas de ganancias sin conexión, para siempre. Pago único.")],
}
def listings(pid): return [{"languageCode":l,"title":t,"description":d} for l,t,d in LISTINGS[pid]]

# ---- subscriptions
src_subs={s["productId"]:s for s in (mon.subscriptions().list(packageName=SRC).execute() or {}).get("subscriptions",[])}
dst_subs={s["productId"]:s for s in (mon.subscriptions().list(packageName=DST).execute() or {}).get("subscriptions",[])}
for pid in ["vip_month","vip_year"]:
    src=src_subs[pid]
    bp=src["basePlans"][0]
    body={"packageName":DST,"productId":pid,
          "basePlans":[{"basePlanId":bp["basePlanId"],
                        "autoRenewingBasePlanType":bp["autoRenewingBasePlanType"],
                        "offerTags":bp.get("offerTags",[]),
                        "regionalConfigs":bp["regionalConfigs"],
                        "otherRegionsConfig":bp["otherRegionsConfig"]}],
          "listings":listings(pid),
          "taxAndComplianceSettings":src.get("taxAndComplianceSettings",{})}
    if pid in dst_subs:
        print(pid,"already exists on",DST,"- state",[b.get("state") for b in dst_subs[pid].get("basePlans",[])])
    else:
        try:
            r=mon.subscriptions().create(packageName=DST,productId=pid,body=body,**{"regionsVersion_version":REGIONS_VERSION}).execute()
            print("CREATED sub",pid,[b.get("state") for b in r.get("basePlans",[])])
        except HttpError as e:
            print("ERROR create",pid,e.resp.status,e.content.decode()[:600]); continue
    try:
        r=mon.subscriptions().basePlans().activate(packageName=DST,productId=pid,basePlanId=bp["basePlanId"],body={"packageName":DST,"productId":pid,"basePlanId":bp["basePlanId"]}).execute()
        print("ACTIVATED",pid,bp["basePlanId"],[b.get("state") for b in r.get("basePlans",[])])
    except HttpError as e:
        print("activate",pid,e.resp.status,e.content.decode()[:400])

# ---- one-time lifetime vip: fresh $19.99 conversion (same recipe as animestreamer_iaps.py)
otp=mon.onetimeproducts()
existing={p.get("productId") for p in (otp.list(packageName=DST).execute() or {}).get("oneTimeProducts",[])}
conv=mon.convertRegionPrices(packageName=DST,body={"price":{"currencyCode":"USD","units":"19","nanos":990000000}}).execute()
rv=conv["regionVersion"]; other=conv["convertedOtherRegionsPrice"]
regional=[{"regionCode":rc,"price":p["price"],"availability":"AVAILABLE"} for rc,p in conv["convertedRegionPrices"].items()]
body={"packageName":DST,"productId":"vip","regionsVersion":rv,"listings":listings("vip"),
      "purchaseOptions":[{"purchaseOptionId":"buy","buyOption":{"legacyCompatible":True},
                          "newRegionsConfig":{"availability":"AVAILABLE","usdPrice":other["usdPrice"],"eurPrice":other["eurPrice"]},
                          "regionalPricingAndAvailabilityConfigs":regional}]}
try:
    otp.patch(packageName=DST,productId="vip",allowMissing=True,updateMask="listings,purchaseOptions,offerTags,restrictedPaymentCountries",body=body,**{"regionsVersion_version":rv["version"]}).execute()
    print("UPDATE" if "vip" in existing else "CREATE","vip $19.99",len(regional),"regions; TR:",[r["price"] for r in regional if r["regionCode"]=="TR"])
    res=otp.purchaseOptions().batchUpdateStates(packageName=DST,productId="-",body={"requests":[{"activatePurchaseOptionRequest":{"packageName":DST,"productId":"vip","purchaseOptionId":"buy"}}]}).execute()
    print("vip state:",[o.get("state") for p in res.get("oneTimeProducts",[]) for o in p.get("purchaseOptions",[])])
except HttpError as e:
    print("ERROR vip",e.resp.status,e.content.decode()[:600])

# ---- verify
subs=(mon.subscriptions().list(packageName=DST).execute() or {}).get("subscriptions",[])
for s in subs:
    for b in s["basePlans"]:
        tr=[r["price"] for r in b["regionalConfigs"] if r["regionCode"]=="TR"]
        print("VERIFY",s["productId"],b["basePlanId"],b.get("state"),b["otherRegionsConfig"]["usdPrice"],"TR",tr)
