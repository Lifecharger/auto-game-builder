"""Upload the Lumina Live AAB and stage a draft release on the
closed testing track. Testers/countries/rollout finish in the Console UI.

Run: python "C:/Projects/Auto Game Builder/tools/playstore/luminalive_upload.py"
"""
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

SA_KEY = "D:/keys/arcade-snake-488801-5ac9863bb0ab.json"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
PACKAGE = "com.lifecharger.luminalive"
AAB = r"C:\Projects\Lumina Live\build\app\outputs\bundle\release\app-release.aab"


def main() -> int:
    creds = service_account.Credentials.from_service_account_file(SA_KEY, scopes=SCOPES)
    svc = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)
    edits = svc.edits()

    edit_id = edits.insert(packageName=PACKAGE, body={}).execute()["id"]
    print("edit:", edit_id)

    bundle = edits.bundles().upload(
        packageName=PACKAGE, editId=edit_id,
        media_body=MediaFileUpload(
            AAB, mimetype="application/octet-stream", resumable=True),
    ).execute()
    version_code = bundle["versionCode"]
    print("uploaded bundle versionCode:", version_code)

    tracks = edits.tracks().list(packageName=PACKAGE, editId=edit_id).execute()
    names = [t["track"] for t in tracks.get("tracks", [])]
    print("available tracks:", names)
    target = "beta" if "beta" in names else next(
        (n for n in names if "closed" in n.lower() or "kapal" in n.lower()), None)
    if target is None:
        target = "beta"  # closed testing default track id
    print("target track:", target)

    edits.tracks().update(
        packageName=PACKAGE, editId=edit_id, track=target,
        body={"track": target, "releases": [{
            "name": "1.0.0 closed test",
            "versionCodes": [str(version_code)],
            "status": "draft",
        }]},
    ).execute()
    edits.commit(packageName=PACKAGE, editId=edit_id).execute()
    print(f"COMMITTED: draft release v{version_code} on '{target}'")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
