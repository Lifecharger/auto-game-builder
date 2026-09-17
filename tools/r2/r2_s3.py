"""Minimal R2 S3 client (stdlib only): list, head, get, copy and delete.

A copy runs inside Cloudflare, so it costs no upload bandwidth here - use it whenever the same
bytes must exist under a second key or bucket. Listing and HEAD are cheap enough to drive a
browser UI; GET is deliberately the only call that spends the metered line, so callers check the
size first. Credentials are read at call time from the R2-scoped token file in the keys folder
(never stored in this repo); `set_credentials_file` lets a host (the AGB server) point at the
path from its own settings.
"""
from __future__ import annotations

import datetime
import hashlib
import hmac
import json
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

CREDENTIALS_FILE = "D:/keys/cloudflare_r2_s3_credentials.json"
_EMPTY_SHA = hashlib.sha256(b"").hexdigest()
_NS = "{http://s3.amazonaws.com/doc/2006-03-01/}"

# Keys may contain anything except the path separator; everything else is percent-encoded the
# way SigV4 expects (S3 signs the encoded path, so encoding and signing must use one table).
_KEY_SAFE = "/-_.~"


def set_credentials_file(path: str) -> None:
    """Point the client at another credentials file (absolute path)."""
    global CREDENTIALS_FILE
    if path and path.strip():
        CREDENTIALS_FILE = path.strip()


def credentials() -> dict:
    with open(CREDENTIALS_FILE, encoding="utf-8") as f:
        cred = json.load(f)
    for alan in ("endpoint", "access_key_id", "secret_access_key"):
        if not cred.get(alan):
            raise RuntimeError("R2 credentials file is missing '%s': %s" % (alan, CREDENTIALS_FILE))
    return cred


def _sign(key: bytes, msg: str) -> bytes:
    return hmac.new(key, msg.encode("utf-8"), hashlib.sha256).digest()


def signing_key(secret: str, day: str, region: str = "auto", service: str = "s3") -> bytes:
    """SigV4 derived key. R2 signs for region `auto`, service `s3`; the arguments
    exist so the known-answer test can drive the published AWS vectors."""
    return _sign(_sign(_sign(_sign(("AWS4" + secret).encode("utf-8"), day), region), service), "aws4_request")


def _canonical_query(query: dict | None) -> str:
    """Query string in signed order: keys sorted, both sides percent-encoded."""
    if not query:
        return ""
    parts = []
    for k in sorted(query):
        v = query[k]
        if v is None:
            continue
        parts.append("%s=%s" % (urllib.parse.quote(str(k), safe="-_.~"),
                                urllib.parse.quote(str(v), safe="-_.~")))
    return "&".join(parts)


def authorization(method: str, path: str, query: dict | None, headers: dict,
                  payload_sha: str, cred: dict, amz_date: str,
                  region: str = "auto", service: str = "s3") -> str:
    """The Authorization header value for one request (kept public for the signer test)."""
    day = amz_date[:8]
    lower = {k.lower(): str(v).strip() for k, v in headers.items()}
    signed = ";".join(sorted(lower))
    canonical = "\n".join([
        method, path, _canonical_query(query),
        "".join("%s:%s\n" % (k, lower[k]) for k in sorted(lower)),
        signed, payload_sha])
    scope = "%s/%s/%s/aws4_request" % (day, region, service)
    to_sign = "\n".join(["AWS4-HMAC-SHA256", amz_date, scope,
                         hashlib.sha256(canonical.encode("utf-8")).hexdigest()])
    signature = hmac.new(signing_key(cred["secret_access_key"], day, region, service),
                         to_sign.encode("utf-8"), hashlib.sha256).hexdigest()
    return ("AWS4-HMAC-SHA256 Credential=%s/%s, SignedHeaders=%s, Signature=%s"
            % (cred["access_key_id"], scope, signed, signature))


def _call(method: str, bucket: str, key: str = "", query: dict | None = None,
          headers: dict | None = None, body: bytes = b"", timeout: int = 120):
    """Signed request. Returns (response headers dict, body bytes). Raises on HTTP failure."""
    cred = credentials()
    host = urllib.parse.urlparse(cred["endpoint"]).netloc
    path = "/" + bucket + ("/" + urllib.parse.quote(key, safe=_KEY_SAFE) if key else "")
    now = datetime.datetime.now(datetime.timezone.utc)
    amz_date = now.strftime("%Y%m%dT%H%M%SZ")
    payload_sha = hashlib.sha256(body).hexdigest() if body else _EMPTY_SHA

    sign_me = {"host": host, "x-amz-content-sha256": payload_sha, "x-amz-date": amz_date}
    sign_me.update(headers or {})
    sign_me["authorization"] = authorization(method, path, query, sign_me, payload_sha, cred, amz_date)

    url = "https://%s%s" % (host, path)
    qs = _canonical_query(query)
    if qs:
        url += "?" + qs
    request = urllib.request.Request(url, method=method, headers=sign_me,
                                     data=body if body else (b"" if method in ("PUT", "POST") else None))
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return dict(response.headers), response.read()
    except urllib.error.HTTPError as e:
        detail = (e.read() or b"").decode("utf-8", "replace")[:300]
        raise RuntimeError("R2 %s %s failed: %s %s" % (method, path, e.code, detail)) from e


def list_objects_v2(bucket: str, prefix: str = "", delimiter: str = "",
                    token: str = "", max_keys: int = 1000, timeout: int = 120) -> dict:
    """One page of ListObjectsV2.

    Returns {"objects": [{key,size,last_modified,etag}], "prefixes": [str],
             "cursor": str, "truncated": bool}. `delimiter="/"` gives folder-style browsing:
    `prefixes` are the sub-folders, `objects` only the keys directly inside `prefix`.
    """
    query = {"list-type": "2", "max-keys": str(max(1, min(1000, max_keys)))}
    if prefix:
        query["prefix"] = prefix
    if delimiter:
        query["delimiter"] = delimiter
    if token:
        query["continuation-token"] = token
    _h, body = _call("GET", bucket, query=query, timeout=timeout)
    root = ET.fromstring(body)
    objects = []
    for c in root.findall(_NS + "Contents"):
        objects.append({"key": c.findtext(_NS + "Key") or "",
                        "size": int(c.findtext(_NS + "Size") or 0),
                        "last_modified": c.findtext(_NS + "LastModified") or "",
                        "etag": (c.findtext(_NS + "ETag") or "").strip('"')})
    prefixes = [p.findtext(_NS + "Prefix") or ""
                for p in root.findall(_NS + "CommonPrefixes")]
    return {"objects": objects, "prefixes": prefixes,
            "cursor": root.findtext(_NS + "NextContinuationToken") or "",
            "truncated": (root.findtext(_NS + "IsTruncated") or "").lower() == "true"}


def list_all(bucket: str, prefix: str = "", timeout: int = 120):
    """Every object under a prefix, page by page (generator - no full list in memory)."""
    token = ""
    while True:
        page = list_objects_v2(bucket, prefix=prefix, token=token, timeout=timeout)
        for o in page["objects"]:
            yield o
        if not page["truncated"] or not page["cursor"]:
            return
        token = page["cursor"]


def head_object(bucket: str, key: str, timeout: int = 60) -> dict:
    """Object headers: {size, etag, last_modified, content_type, cache_control}."""
    h, _b = _call("HEAD", bucket, key, timeout=timeout)
    return {"key": key,
            "size": int(h.get("Content-Length") or 0),
            "etag": (h.get("ETag") or "").strip('"'),
            "last_modified": h.get("Last-Modified") or "",
            "content_type": h.get("Content-Type") or "",
            "cache_control": h.get("Cache-Control") or ""}


def get_object(bucket: str, key: str, first: int = -1, last: int = -1, timeout: int = 120) -> bytes:
    """Object bytes. Give `first`/`last` for a ranged GET (both inclusive, 0-based)."""
    headers = {}
    if first >= 0:
        headers["range"] = "bytes=%d-%s" % (first, last if last >= 0 else "")
    _h, body = _call("GET", bucket, key, headers=headers, timeout=timeout)
    return body


def copy_object(src_bucket: str, src_key: str, dst_bucket: str, dst_key: str, timeout: int = 120,
                content_type: str = "", cache_control: str = "") -> None:
    """Copy one object server-side. Raises on failure.

    Without `content_type`/`cache_control` the source metadata travels with the bytes. Give
    either one to rewrite the headers in place (MetadataDirective REPLACE) - that is how a
    stale Cache-Control is repaired without moving a byte over this line.
    """
    headers = {"x-amz-copy-source": "/" + src_bucket + "/" + urllib.parse.quote(src_key, safe=_KEY_SAFE)}
    if content_type or cache_control:
        headers["x-amz-metadata-directive"] = "REPLACE"
        if content_type:
            headers["content-type"] = content_type
        if cache_control:
            headers["cache-control"] = cache_control
    _h, body = _call("PUT", dst_bucket, dst_key, headers=headers, timeout=timeout)
    text = body.decode("utf-8", "replace")
    if "<Error>" in text:  # S3 can answer 200 with an error document for copies
        raise RuntimeError("R2 copy %s/%s -> %s/%s failed: %s"
                           % (src_bucket, src_key, dst_bucket, dst_key, text[:300]))


def delete_object(bucket: str, key: str, timeout: int = 60) -> None:
    """Delete one object. Deleting a key that is not there is not an error (S3 semantics)."""
    _call("DELETE", bucket, key, timeout=timeout)


def delete_objects(bucket: str, keys: list, timeout: int = 120) -> dict:
    """Batch delete (max 1000 keys per call). Returns {"deleted": [key], "errors": [{key,message}]}."""
    keys = [k for k in keys if k]
    if not keys:
        return {"deleted": [], "errors": []}
    if len(keys) > 1000:
        raise ValueError("delete_objects takes at most 1000 keys per call (%d given)" % len(keys))
    parts = ["<Delete><Quiet>false</Quiet>"]
    for k in keys:
        parts.append("<Object><Key>%s</Key></Object>" % _xml_escape(k))
    parts.append("</Delete>")
    body = "".join(parts).encode("utf-8")
    headers = {"content-md5": _md5_b64(body), "content-type": "application/xml"}
    _h, out = _call("POST", bucket, query={"delete": ""}, headers=headers, body=body, timeout=timeout)
    root = ET.fromstring(out)
    deleted = [d.findtext(_NS + "Key") or "" for d in root.findall(_NS + "Deleted")]
    errors = [{"key": e.findtext(_NS + "Key") or "",
               "message": "%s %s" % (e.findtext(_NS + "Code") or "", e.findtext(_NS + "Message") or "")}
              for e in root.findall(_NS + "Error")]
    return {"deleted": deleted, "errors": errors}


def _xml_escape(text: str) -> str:
    return (text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace('"', "&quot;").replace("'", "&apos;"))


def _md5_b64(body: bytes) -> str:
    import base64
    return base64.b64encode(hashlib.md5(body).digest()).decode("ascii")
