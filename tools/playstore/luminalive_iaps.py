"""Create + activate Lumina Live one-time products on Google Play.

Same recipe as hotcardgames_iaps.py (monetization.onetimeproducts, USD anchor
converted per region, legacyCompatible for the Flutter in_app_purchase plugin,
then activated). Run AFTER the app entry exists in the Console and a build is
on any track.

Run: python "C:/Projects/Auto Game Builder/tools/playstore/luminalive_iaps.py"
"""
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

SA_KEY = "D:/keys/arcade-snake-488801-5ac9863bb0ab.json"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
PACKAGE = "com.lifecharger.luminalive"

PRODUCTS = [
    {"id": "producer_pass", "usd": "4.99",
     "en": ("Producer Pass", "No sponsor interruptions between runs. Yours forever."),
     "tr": ("Yapımcı Kartı", "Turlar arasında sponsor kesintisi yok. Kalıcı.")},
    {"id": "timeskip_1h", "usd": "0.99",
     "en": ("1 Hour Time Skip", "Instantly bank one hour of idle hearts."),
     "tr": ("1 Saatlik Zaman Atlaması", "Bir saatlik boşta kalp kazancını anında al.")},
    {"id": "timeskip_8h", "usd": "2.99",
     "en": ("8 Hour Time Skip", "Instantly bank eight hours of idle hearts."),
     "tr": ("8 Saatlik Zaman Atlaması", "Sekiz saatlik boşta kalp kazancını anında al.")},
    {"id": "timeskip_24h", "usd": "5.99",
     "en": ("24 Hour Time Skip", "Instantly bank a full day of idle hearts."),
     "tr": ("24 Saatlik Zaman Atlaması", "Tam bir günlük boşta kalp kazancını anında al.")},
]


def money(amount: str, cur: str = "USD") -> dict:
    units, _, frac = amount.partition(".")
    return {"currencyCode": cur, "units": units,
            "nanos": int((frac + "000000000")[:9]) if frac else 0}


def main() -> int:
    creds = service_account.Credentials.from_service_account_file(SA_KEY, scopes=SCOPES)
    svc = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)
    otp = svc.monetization().onetimeproducts()
    try:
        existing = {p.get("productId") for p in (otp.list(
            packageName=PACKAGE).execute() or {}).get("oneTimeProducts", [])}
    except HttpError as e:
        existing = set()
        print("list:", e.resp.status)
    print("existing:", sorted(existing) or "(none)")

    rc = 0
    for prod in PRODUCTS:
        pid = prod["id"]
        conv = svc.monetization().convertRegionPrices(
            packageName=PACKAGE, body={"price": money(prod["usd"])}).execute()
        regions_version = conv["regionVersion"]
        other = conv["convertedOtherRegionsPrice"]
        regional = [
            {"regionCode": rc_, "price": p["price"], "availability": "AVAILABLE"}
            for rc_, p in conv["convertedRegionPrices"].items()
        ]
        body = {
            "packageName": PACKAGE,
            "productId": pid,
            "regionsVersion": regions_version,
            "listings": [
                {"languageCode": "en-US", "title": prod["en"][0], "description": prod["en"][1]},
                {"languageCode": "tr-TR", "title": prod["tr"][0], "description": prod["tr"][1]},
            ],
            "purchaseOptions": [{
                "purchaseOptionId": "buy",
                "buyOption": {"legacyCompatible": True},
                "newRegionsConfig": {"availability": "AVAILABLE",
                                     "usdPrice": other["usdPrice"],
                                     "eurPrice": other["eurPrice"]},
                "regionalPricingAndAvailabilityConfigs": regional,
            }],
        }
        try:
            otp.patch(
                packageName=PACKAGE, productId=pid, allowMissing=True,
                updateMask="listings,purchaseOptions,offerTags,restrictedPaymentCountries",
                body=body,
                **{"regionsVersion_version": regions_version["version"]},
            ).execute()
            print(f"[{'UPDATE' if pid in existing else 'CREATE'}] {pid} ${prod['usd']} ({len(regional)} regions)")
        except HttpError as e:
            print(f"[ERROR] {pid}: {e.resp.status} {e.content.decode()[:400]}")
            rc = 1
            continue

        try:
            res = otp.purchaseOptions().batchUpdateStates(
                packageName=PACKAGE, productId="-",
                body={"requests": [{"activatePurchaseOptionRequest": {
                    "packageName": PACKAGE, "productId": pid,
                    "purchaseOptionId": "buy"}}]},
            ).execute()
            states = [po.get("state") for p in res.get("oneTimeProducts", [])
                      for po in p.get("purchaseOptions", [])]
            print(f"         activated -> {states}")
        except HttpError as e:
            print(f"[ERROR activate] {pid}: {e.resp.status} {e.content.decode()[:300]}")
            rc = 1
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
