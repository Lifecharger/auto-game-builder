"""Create + activate Anime Dance Streamer one-time products on Google Play.

Same recipe as hotcardgames_iaps.py (monetization.onetimeproducts, USD anchor
converted per region, legacyCompatible for the Flutter in_app_purchase plugin,
then activated). Run AFTER the app entry exists in the Console and a build is
on any track.

Run: python "C:/Projects/Auto Game Builder/tools/playstore/animestreamer_iaps.py"
"""
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

SA_KEY = "D:/keys/arcade-snake-488801-5ac9863bb0ab.json"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
PACKAGE = "com.lifecharger.animestreamer"

PRODUCTS = [
    {"id": "outfit_bunny", "usd": "2.99",
     "en": ("Bunny Deluxe Outfit", "The classic satin bunny suit for Bella - ears, cuffs and all. Yours forever."),
     "tr": ("Bunny Deluxe Kıyafeti", "Bella için klasik saten bunny kostümü - kulaklar, manşetler, hepsi. Kalıcı.")},
    {"id": "outfit_wedding", "usd": "3.99",
     "en": ("White Promise Outfit", "An elegant wedding mini dress with veil and gloves. Yours forever."),
     "tr": ("Beyaz Söz Kıyafeti", "Duvak ve eldivenli zarif bir gelinlik. Kalıcı.")},
    {"id": "outfit_gala", "usd": "2.99",
     "en": ("Midnight Gala Outfit", "A deep purple evening gown with crystal sparkle. Yours forever."),
     "tr": ("Gece Yarısı Galası", "Kristal parıltılı mor bir gece elbisesi. Kalıcı.")},
    {"id": "outfit_catgirl", "usd": "2.99",
     "en": ("Neko Star Outfit", "Cat ears, tail and paw-print thigh highs. Yours forever."),
     "tr": ("Neko Star Kıyafeti", "Kedi kulakları, kuyruk ve pati desenli çoraplar. Kalıcı.")},
    {"id": "outfit_santa", "usd": "1.99",
     "en": ("Santa Baby Outfit", "A fur-trimmed santa dress with matching boots. Yours forever."),
     "tr": ("Santa Baby Kıyafeti", "Kürk detaylı noel elbisesi ve uyumlu çizmeler. Kalıcı.")},
    {"id": "timeskip_1h", "usd": "0.99",
     "en": ("1 Hour Time Skip", "Instantly collect one hour of viewer payouts."),
     "tr": ("1 Saatlik Zaman Atlaması", "Bir saatlik izleyici ödemesini anında topla.")},
    {"id": "timeskip_8h", "usd": "2.99",
     "en": ("8 Hour Time Skip", "Instantly collect eight hours of viewer payouts."),
     "tr": ("8 Saatlik Zaman Atlaması", "Sekiz saatlik izleyici ödemesini anında topla.")},
    {"id": "timeskip_24h", "usd": "5.99",
     "en": ("24 Hour Time Skip", "Instantly collect a full day of viewer payouts."),
     "tr": ("24 Saatlik Zaman Atlaması", "Tam bir günlük izleyici ödemesini anında topla.")},
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
