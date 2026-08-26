"""Push the Lumina Live Data Safety form via the Play Developer API.

POST applications/{pkg}/dataSafety with the filled CSV (ads + IAP profile:
no accounts, Device/other IDs collected + shared for advertising). 204 = saved.

Run: python "C:/Projects/Auto Game Builder/tools/playstore/luminalive_datasafety.py"
"""
import google.auth.transport.requests
from google.oauth2 import service_account
import requests

SA_KEY = "D:/keys/arcade-snake-488801-5ac9863bb0ab.json"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
PACKAGE = "com.lifecharger.luminalive"
CSV = r"C:\Users\caca_\Desktop\store_assets\data_safety_luminalive.csv"


def main() -> int:
    creds = service_account.Credentials.from_service_account_file(SA_KEY, scopes=SCOPES)
    creds.refresh(google.auth.transport.requests.Request())
    with open(CSV, "rb") as f:
        csv = f.read().decode("utf-8")
    r = requests.post(
        f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE}/dataSafety",
        headers={"Authorization": f"Bearer {creds.token}", "Content-Type": "application/json"},
        json={"safetyLabels": csv}, timeout=60)
    print(r.status_code, r.text[:500])
    return 0 if r.status_code in (200, 204) else 1


if __name__ == "__main__":
    raise SystemExit(main())
