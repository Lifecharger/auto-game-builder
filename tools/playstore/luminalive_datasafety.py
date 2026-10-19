"""Push the Lumina Live Data Safety form via the Play Developer API.

POST applications/{pkg}/dataSafety with the filled CSV (ads + IAP profile:
no accounts, Device/other IDs collected + shared for advertising). 204 = saved.

Run: python tools/playstore/luminalive_datasafety.py
"""
import google.auth.transport.requests
from google.oauth2 import service_account
import requests

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import local_settings  # noqa: E402

SA_KEY = local_settings.get("play_publish_service_account")
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
PACKAGE = "com.lifecharger.luminalive"
CSV = str(local_settings.path("projects_dir", "Lumina Live", "store", "data_safety_luminalive.csv"))


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
