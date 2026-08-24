"""Create + activate Hot Card Games one-time products on Google Play Console.

monetization.onetimeproducts API (legacy inappproducts is closed). Prices are
converted for every region from a USD anchor via pricing:convertRegionPrices,
then each purchase option is ACTIVATED so license testers can buy them on the
alpha track. buyOption.legacyCompatible=true is mandatory for the Flutter
in_app_purchase plugin to see the SKU.

Run: python "C:/Projects/Auto Game Builder/tools/playstore/hotcardgames_iaps.py"
"""
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

SA_KEY = "D:/keys/arcade-snake-488801-5ac9863bb0ab.json"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
PACKAGE = "com.lifecharger.hotcardgames"

PRODUCTS = [
    {"id": "royale_pass", "usd": "4.99",
     "en": ("Royale Pass", "No interstitial ads, the exclusive Royale card back and double daily streak bonuses. Forever."),
     "tr": ("Royale Pass", "Geçiş reklamı yok, özel Royale kart arkası ve günlük seri bonusları iki kat. Kalıcı.")},
    {"id": "coins_small", "usd": "0.99",
     "en": ("1,000 Coins", "A pocketful of coins for the daily shop and the chip exchange."),
     "tr": ("1.000 Coin", "Günlük mağaza ve fiş bozdurma için bir avuç coin.")},
    {"id": "coins_medium", "usd": "4.99",
     "en": ("5,500 Coins", "Enough for a rare card or a new dealer."),
     "tr": ("5.500 Coin", "Nadir bir kart ya da yeni bir krupiye için yeterli.")},
    {"id": "coins_large", "usd": "9.99",
     "en": ("12,000 Coins", "A legendary joker is within reach."),
     "tr": ("12.000 Coin", "Efsanevi bir joker artık ulaşılabilir.")},
    {"id": "coins_mega", "usd": "19.99",
     "en": ("30,000 Coins", "Best value. Fill the deck with the art you want."),
     "tr": ("30.000 Coin", "En iyi değer. Desteyi istediğin sanatla doldur.")},
]


def money(amount: str, cur: str = "USD") -> dict:
    units, _, frac = amount.partition(".")
    return {"currencyCode": cur, "units": units, "nanos": int((frac + "000000000")[:9]) if frac else 0}


def main() -> int:
    creds = service_account.Credentials.from_service_account_file(SA_KEY, scopes=SCOPES)
    svc = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)
    otp = svc.monetization().onetimeproducts()
    try:
        existing = {p.get("productId") for p in (otp.list(packageName=PACKAGE).execute() or {}).get("oneTimeProducts", [])}
    except HttpError as e:
        existing = set(); print("list:", e.resp.status)
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
                                     "usdPrice": other["usdPrice"], "eurPrice": other["eurPrice"]},
                "regionalPricingAndAvailabilityConfigs": regional,
            }],
        }
        try:
            otp.patch(packageName=PACKAGE, productId=pid, allowMissing=True,
                      updateMask="listings,purchaseOptions,offerTags,restrictedPaymentCountries",
                      body=body, **{"regionsVersion_version": regions_version["version"]}).execute()
            print(f"[{'UPDATE' if pid in existing else 'CREATE'}] {pid} ${prod['usd']} ({len(regional)} regions)")
        except HttpError as e:
            print(f"[ERROR] {pid}: {e.resp.status} {e.content.decode()[:400]}"); rc = 1; continue
        try:
            res = otp.purchaseOptions().batchUpdateStates(
                packageName=PACKAGE, productId="-",
                body={"requests": [{"activatePurchaseOptionRequest": {
                    "packageName": PACKAGE, "productId": pid, "purchaseOptionId": "buy"}}]}).execute()
            states = [po.get("state") for p in res.get("oneTimeProducts", []) for po in p.get("purchaseOptions", [])]
            print(f"         activated -> {states}")
        except HttpError as e:
            print(f"[ERROR activate] {pid}: {e.resp.status} {e.content.decode()[:300]}"); rc = 1
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
