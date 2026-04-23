"""Create Bee Striker IAPs as drafts on Google Play Console.

Uses the new monetization.onetimeproducts API (legacy inappproducts is gone).
Each product is created with a placeholder USD price — required by the API
(min $0.05) — and left in DRAFT state (we never call batchUpdateStates), so
nothing is visible to users. Edit real prices in Play Console.

Run: python "C:/Projects/Auto Game Builder/tools/playstore/beestriker_iaps.py"
"""
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

SA_KEY = "D:/keys/arcade-snake-488801-35f27b42dfb3.json"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
PACKAGE = "com.lifecharger.beestriker"
REGIONS_VERSION = "2022/02"

# Placeholder prices — user will reprice in Play Console.
PRODUCTS = [
    {"id": "honey_small",  "title": "Small Honey Pack",  "desc": "500 honey coins",                  "usd": "0.99"},
    {"id": "honey_medium", "title": "Medium Honey Pack", "desc": "1500 honey coins",                 "usd": "2.99"},
    {"id": "honey_large",  "title": "Large Honey Pack",  "desc": "5000 honey coins",                 "usd": "9.99"},
    {"id": "remove_ads",   "title": "Remove Ads",        "desc": "Removes all ads from the game",    "usd": "2.99"},
]


def money_usd(amount: str) -> dict:
    units, _, frac = amount.partition(".")
    nanos = int((frac + "000000000")[:9]) if frac else 0
    return {"currencyCode": "USD", "units": units, "nanos": nanos}


def money_eur(amount: str) -> dict:
    units, _, frac = amount.partition(".")
    nanos = int((frac + "000000000")[:9]) if frac else 0
    return {"currencyCode": "EUR", "units": units, "nanos": nanos}


def build_body(prod: dict) -> dict:
    price_usd = money_usd(prod["usd"])
    price_eur = money_eur(prod["usd"])  # same numeric placeholder
    return {
        "packageName": PACKAGE,
        "productId": prod["id"],
        "listings": [
            {
                "languageCode": "en-US",
                "title": prod["title"],
                "description": prod["desc"],
            }
        ],
        "purchaseOptions": [
            {
                "purchaseOptionId": "default",
                "buyOption": {"legacyCompatible": True},
                "regionalPricingAndAvailabilityConfigs": [
                    {"regionCode": "US", "price": price_usd, "availability": "AVAILABLE"},
                ],
                "newRegionsConfig": {
                    "usdPrice": price_usd,
                    "eurPrice": price_eur,
                    "availability": "AVAILABLE",
                },
            }
        ],
    }


def main() -> int:
    creds = service_account.Credentials.from_service_account_file(SA_KEY, scopes=SCOPES)
    svc = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)
    otp = svc.monetization().onetimeproducts()

    existing = otp.list(packageName=PACKAGE).execute().get("oneTimeProducts", [])
    existing_ids = {p.get("productId") for p in existing}
    print(f"Existing product IDs: {sorted(existing_ids) or '(none)'}")

    exit_code = 0
    for prod in PRODUCTS:
        pid = prod["id"]
        body = build_body(prod)
        try:
            otp.patch(
                packageName=PACKAGE,
                productId=pid,
                allowMissing=True,
                updateMask="listings,purchaseOptions",
                body=body,
                **{"regionsVersion_version": REGIONS_VERSION},
            ).execute()
            action = "UPDATE" if pid in existing_ids else "CREATE"
            print(f"[{action}] {pid} — ${prod['usd']} USD placeholder")
        except HttpError as e:
            print(f"[ERROR] {pid}: {e.resp.status} {e.content.decode()[:300]}")
            exit_code = 1
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
