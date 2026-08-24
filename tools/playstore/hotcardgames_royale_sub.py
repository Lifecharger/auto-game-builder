"""Create + activate the royale_pass_monthly SUBSCRIPTION for Hot Card Games
and retire the legacy one-time royale_pass from sale (owners keep it).

Task #271: the eternal pass at one-time pricing was too cheap — same price,
monthly, via Play's monetization.subscriptions API.
"""
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

SA_KEY = "D:/keys/arcade-snake-488801-5ac9863bb0ab.json"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
PACKAGE = "com.lifecharger.hotcardgames"
PRODUCT_ID = "royale_pass_monthly"
BASE_PLAN_ID = "monthly"
USD = {"currencyCode": "USD", "units": "4", "nanos": 990000000}

LISTINGS = [
    {"languageCode": "en-US", "title": "Royale Pass (Monthly)",
     "benefits": ["No interstitial ads", "Exclusive Royale card back",
                   "Double daily streak bonuses"],
     "description": "No interstitial ads, the exclusive Royale card back and double daily streak bonuses while subscribed."},
    {"languageCode": "tr-TR", "title": "Royale Pass (Aylık)",
     "benefits": ["Geçiş reklamı yok", "Özel Royale kart arkası",
                   "Günlük seri ödülleri x2"],
     "description": "Abonelik süresince geçiş reklamı yok, özel Royale kart arkası ve günlük seri bonusları iki kat."},
]


def main() -> int:
    creds = service_account.Credentials.from_service_account_file(
        SA_KEY, scopes=SCOPES)
    svc = build("androidpublisher", "v3", credentials=creds,
                cache_discovery=False)

    conv = svc.monetization().convertRegionPrices(
        packageName=PACKAGE, body={"price": USD}).execute()
    regions_version = conv["regionVersion"]
    regional = [
        {"regionCode": rc, "price": p["price"],
         "newSubscriberAvailability": True}
        for rc, p in conv["convertedRegionPrices"].items()
    ]
    other = conv["convertedOtherRegionsPrice"]
    print(f"prices converted for {len(regional)} regions "
          f"(version {regions_version['version']})")

    body = {
        "packageName": PACKAGE,
        "productId": PRODUCT_ID,
        "listings": [
            {"languageCode": item["languageCode"], "title": item["title"],
             "benefits": item["benefits"], "description": item["description"]}
            for item in LISTINGS
        ],
        "basePlans": [{
            "basePlanId": BASE_PLAN_ID,
            "autoRenewingBasePlanType": {
                "billingPeriodDuration": "P1M",
                "gracePeriodDuration": "P30D",
                "resubscribeState": "RESUBSCRIBE_STATE_ACTIVE",
                "prorationMode":
                    "SUBSCRIPTION_PRORATION_MODE_CHARGE_ON_NEXT_BILLING_DATE",
                "legacyCompatible": True,
            },
            "regionalConfigs": regional,
            "otherRegionsConfig": {
                "usdPrice": other["usdPrice"],
                "eurPrice": other["eurPrice"],
                "newSubscriberAvailability": True,
            },
        }],
    }

    subs = svc.monetization().subscriptions()
    try:
        subs.patch(
            packageName=PACKAGE, productId=PRODUCT_ID, allowMissing=True,
            updateMask="listings,basePlans",
            body=body,
            **{"regionsVersion_version": regions_version["version"]},
        ).execute()
        print(f"[CREATE/UPDATE] {PRODUCT_ID} ($4.99/month)")
    except HttpError as e:
        print(f"[ERROR] patch: {e.resp.status} {e.content.decode()[:500]}")
        return 1

    try:
        subs.basePlans().activate(
            packageName=PACKAGE, productId=PRODUCT_ID,
            basePlanId=BASE_PLAN_ID, body={},
        ).execute()
        print(f"base plan '{BASE_PLAN_ID}' ACTIVE")
    except HttpError as e:
        print(f"[ERROR] activate: {e.resp.status} {e.content.decode()[:300]}")
        return 1

    # Retire the legacy one-time pass from sale (existing owners keep it).
    try:
        svc.monetization().onetimeproducts().purchaseOptions().batchUpdateStates(
            packageName=PACKAGE, productId="-",
            body={"requests": [{"deactivatePurchaseOptionRequest": {
                "packageName": PACKAGE, "productId": "royale_pass",
                "purchaseOptionId": "buy"}}]},
        ).execute()
        print("legacy royale_pass purchase option DEACTIVATED (retired from sale)")
    except HttpError as e:
        print(f"[WARN] deactivate legacy: {e.resp.status} "
              f"{e.content.decode()[:300]}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
