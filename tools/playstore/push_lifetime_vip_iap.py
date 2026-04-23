"""Create `vip_lifetime` one-time products on four apps as drafts.

Uses the new Monetization API (`androidpublisher.monetization.onetimeproducts`).
The old `inappproducts.insert` endpoint returns 403 with "Please migrate to
the new publishing API."

Each product is upserted via PATCH with allowMissing=true. Purchase options
on freshly-created products enter DRAFT state — user reviews pricing in
Play Console and uses "Activate" to go live.

The API requires a price in at least one regional config. We set a
placeholder $0.99 USD — clearly not a real price; user replaces it before
activating.

Run: python "C:/Projects/Auto Game Builder/tools/playstore/push_lifetime_vip_iap.py"
"""
from __future__ import annotations

import sys
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

SA_KEY = "D:/keys/arcade-snake-488801-35f27b42dfb3.json"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]

APPS = [
    ("Hot Jigsaw", "com.lifecharger.hotjigsaw"),
    ("Hot Slider", "com.lifecharger.hotslider"),
    ("Hot Charm",  "com.lifecharger.hotcharm"),
    ("Pro Jigsaw", "com.lifecharger.projigsaw"),
]

PRODUCT_ID = "vip_lifetime"
PURCHASE_OPTION_ID = "buy"

# Current published regions-config version. If this ever rejects with a
# version error, re-fetch via https://support.google.com/googleplay/android-developer/answer/10532353
REGIONS_VERSION = "2022/02"

LISTING_TITLE = "Lifetime VIP"
LISTING_DESC = (
    "Unlock VIP forever with a one-time payment. No forced ads, plus "
    "the VIP daily claim. No subscription, never expires."
)

# Placeholder price — user replaces before activating in Play Console.
PLACEHOLDER_PRICE = {"currencyCode": "USD", "units": "0", "nanos": 990000000}


def build_body(package: str) -> dict:
    return {
        "packageName": package,
        "productId":   PRODUCT_ID,
        "listings": [
            {
                "languageCode": "en-US",
                "title":        LISTING_TITLE,
                "description":  LISTING_DESC,
            },
        ],
        "purchaseOptions": [
            {
                "purchaseOptionId": PURCHASE_OPTION_ID,
                "buyOption": {
                    "legacyCompatible": True,
                },
                "regionalPricingAndAvailabilityConfigs": [
                    {
                        "regionCode":   "US",
                        "availability": "AVAILABLE",
                        "price":        PLACEHOLDER_PRICE,
                    },
                ],
            },
        ],
    }


def upsert_product(service, package: str) -> str:
    body = build_body(package)
    result = service.monetization().onetimeproducts().patch(
        packageName=package,
        productId=PRODUCT_ID,
        allowMissing=True,
        updateMask="listings,purchaseOptions",
        regionsVersion_version=REGIONS_VERSION,
        body=body,
    ).execute()
    po = (result.get("purchaseOptions") or [{}])[0]
    return f"upserted productId={result.get('productId')} purchaseOption.state={po.get('state')}"


def main() -> int:
    creds = service_account.Credentials.from_service_account_file(SA_KEY, scopes=SCOPES)
    service = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)

    exit_code = 0
    for name, package in APPS:
        print(f"=== {name} ({package}) ===")
        try:
            msg = upsert_product(service, package)
            print(f"  OK: {msg}")
        except HttpError as e:
            print(f"  FAILED: HTTP {e.resp.status}: {e.error_details if hasattr(e, 'error_details') else e}")
            exit_code = 1
        except Exception as e:
            print(f"  FAILED: {e}")
            exit_code = 1
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
