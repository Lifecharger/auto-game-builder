"""Kovalar (#381) regression tests - no network, no real bucket.

The S3 layer is replaced by a fake, so every destructive path (delete, takedown,
copy, header repair) is exercised without touching Cloudflare. The signer is
checked against the published AWS Signature Version 4 test vectors.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import types
import unittest

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / "core"
TOOLS = ROOT.parent / "tools"


def _load(name: str, path: Path):
    """Load one module by file path under a private package, like the server does."""
    pkg = name.split(".")[0]
    if pkg not in sys.modules:
        parent = types.ModuleType(pkg)
        parent.__path__ = []
        sys.modules[pkg] = parent
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


class FakeS3:
    """In-memory stand-in for tools/r2/r2_s3.py. Records every mutation."""

    def __init__(self, objects: dict | None = None):
        # {bucket: {key: {"size", "etag", "content_type", "cache_control", "body"}}}
        self.objects = objects or {}
        self.copies: list[tuple] = []
        self.deleted: list[tuple] = []
        self.credentials_file = ""

    def set_credentials_file(self, path):
        self.credentials_file = path

    def list_objects_v2(self, bucket, prefix="", delimiter="", token="", max_keys=1000, timeout=120):
        keys = sorted(self.objects.get(bucket, {}))
        objects, prefixes = [], []
        for k in keys:
            if not k.startswith(prefix):
                continue
            kalan = k[len(prefix):]
            if delimiter and delimiter in kalan:
                p = prefix + kalan.split(delimiter, 1)[0] + delimiter
                if p not in prefixes:
                    prefixes.append(p)
                continue
            o = self.objects[bucket][k]
            objects.append({"key": k, "size": o["size"], "etag": o.get("etag", ""),
                            "last_modified": o.get("last_modified", "")})
        return {"objects": objects[:max_keys], "prefixes": prefixes,
                "cursor": "", "truncated": len(objects) > max_keys}

    def list_all(self, bucket, prefix="", timeout=120):
        for k in sorted(self.objects.get(bucket, {})):
            if k.startswith(prefix):
                o = self.objects[bucket][k]
                yield {"key": k, "size": o["size"], "etag": o.get("etag", "")}

    def head_object(self, bucket, key, timeout=60):
        o = self.objects.get(bucket, {}).get(key)
        if o is None:
            raise RuntimeError("R2 HEAD /%s/%s failed: 404" % (bucket, key))
        return {"key": key, "size": o["size"], "etag": o.get("etag", "e"),
                "last_modified": o.get("last_modified", ""),
                "content_type": o.get("content_type", ""),
                "cache_control": o.get("cache_control", "")}

    def get_object(self, bucket, key, first=-1, last=-1, timeout=120):
        body = self.objects[bucket][key].get("body", b"")
        return body[first:last + 1] if first >= 0 else body

    def copy_object(self, src_bucket, src_key, dst_bucket, dst_key, timeout=120,
                    content_type="", cache_control=""):
        self.copies.append((src_bucket, src_key, dst_bucket, dst_key, content_type, cache_control))
        src = dict(self.objects[src_bucket][src_key])
        if content_type:
            src["content_type"] = content_type
        if cache_control:
            src["cache_control"] = cache_control
        self.objects.setdefault(dst_bucket, {})[dst_key] = src

    def delete_objects(self, bucket, keys, timeout=120):
        keys = [k for k in keys if k]
        self.deleted.append((bucket, list(keys)))
        for k in keys:
            self.objects.get(bucket, {}).pop(k, None)
        return {"deleted": list(keys), "errors": []}


class SignerTests(unittest.TestCase):
    """Published AWS SigV4 vectors - the signer is the one thing that cannot be
    checked by reading the code."""

    def setUp(self):
        self.s3 = _load("r2_signer_test.r2_s3", TOOLS / "r2" / "r2_s3.py")

    def test_signing_key_matches_aws_derivation_example(self):
        self.assertEqual(
            self.s3.signing_key("wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY",
                                "20120215", "us-east-1", "iam").hex(),
            "f4780e2d9f65fa895f9c67b32ce1baf0b0d8a43505a000a1a9e090d414db404d")

    def test_authorization_matches_get_vanilla_vector(self):
        cred = {"access_key_id": "AKIDEXAMPLE",
                "secret_access_key": "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY"}
        got = self.s3.authorization(
            "GET", "/", None,
            {"host": "example.amazonaws.com", "x-amz-date": "20150830T123600Z"},
            hashlib.sha256(b"").hexdigest(), cred, "20150830T123600Z",
            "us-east-1", "service")
        self.assertEqual(got, (
            "AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20150830/us-east-1/service/aws4_request, "
            "SignedHeaders=host;x-amz-date, "
            "Signature=5fa00fa31553b73ebf1942676e86291e8372ff2a2260956d9b8aae1d763fbf31"))

    def test_query_is_signed_in_sorted_encoded_order(self):
        self.assertEqual(
            self.s3._canonical_query({"prefix": "a b/c", "list-type": "2", "delimiter": "/"}),
            "delimiter=%2F&list-type=2&prefix=a%20b%2Fc")

    def test_delete_batch_refuses_more_than_one_thousand_keys(self):
        with self.assertRaises(ValueError):
            self.s3.delete_objects("promo", ["k%d" % i for i in range(1001)])


class RegistryTests(unittest.TestCase):
    def setUp(self):
        self.r2 = _load("r2_control_test.r2_control", CORE / "r2_control.py")

    def test_every_twin_points_at_a_registered_bucket(self):
        adlar = set(self.r2.bucket_names())
        for b in self.r2.registry()["buckets"]:
            twin = (b.get("twin") or {}).get("bucket")
            if twin:
                self.assertIn(twin, adlar, b["name"])

    def test_twin_mapping_both_directions(self):
        cases = [
            ("gallery-hot", "collections/Generic/images/5.jpg",
             "hotjigsaw", "collections/Generic/images/5.jpg"),
            ("promo", "cross-promo/manifest.json", "hotjigsaw", "promo/manifest.json"),
            ("characters", "freya/relationships/L3_scene_loop.webp",
             "hotcardgames", "relationships/freya/L3_scene_loop.webp"),
            ("cards", "dealers/nova_sheet.webp", "hotcardgames", "dealers/nova_sheet.webp"),
            ("cards", "manifest.json", "hotcardgames", "manifest.json"),
            ("idols", "bella/public/dance/x.ab12cd34.webp",
             "characters-v2", "bella/public/dance/x.ab12cd34.webp"),
            ("gallery-family", "collections/animals/videos/2.mp4",
             "kidfriendlybucket", "collections/animals/videos/2.mp4"),
        ]
        for bucket, key, twin, twin_key in cases:
            self.assertEqual(self.r2.twin_key(bucket, key), (twin, twin_key), key)
            # The legacy bucket maps back through the same rule, reversed.
            self.assertEqual(self.r2.twin_key(twin, twin_key), (bucket, key), twin_key)

    def test_unmapped_keys_are_not_invented(self):
        # shop_characters/ came from a bucket that is already deleted - no twin.
        self.assertEqual(self.r2.twin_key("cards", "shop_characters/noir/ava/ava.webp"), ("", ""))
        self.assertEqual(self.r2.twin_key("characters", "characters.json"), ("", ""))
        self.assertEqual(self.r2.twin_key("game-reports", "anything"), ("", ""))

    def test_one_legacy_bucket_can_feed_two_new_ones(self):
        self.assertEqual(self.r2.twin_buckets("hotjigsaw"), ["gallery-hot", "promo"])
        self.assertEqual(self.r2.twin_key("hotjigsaw", "promo/a_icon_v1.webp"),
                         ("promo", "cross-promo/a_icon_v1.webp"))
        self.assertEqual(self.r2.twin_key("hotjigsaw", "collections/x/images/1.jpg"),
                         ("gallery-hot", "collections/x/images/1.jpg"))

    def test_literal_prefix_limits_the_legacy_listing(self):
        self.assertEqual(self.r2._literal_prefix("promo/{rest...}"), "promo/")
        self.assertEqual(self.r2._literal_prefix("{girl}/relationships/{rest...}"), "")
        self.assertEqual(self.r2._literal_prefix("manifest.json"), "manifest.json")

    def test_unknown_bucket_is_refused(self):
        with self.assertRaises(ValueError):
            self.r2.bucket_info("hotjigsaw-scanner")

    def test_public_url_only_for_buckets_with_a_files_domain(self):
        self.assertEqual(self.r2.public_url("promo", "cross-promo/a b.webp"),
                         "https://promo.lifechargergames.com/cross-promo/a%20b.webp")
        self.assertEqual(self.r2.public_url("game-reports", "x"), "")


class HeaderStandardTests(unittest.TestCase):
    def setUp(self):
        self.r2 = _load("r2_control_test.r2_control", CORE / "r2_control.py")

    def test_assets_want_the_immutable_ninety_day_header(self):
        d = self.r2.header_check("gallery-hot", "collections/a/images/1.jpg",
                                 "public, max-age=7776000, immutable")
        self.assertEqual(d["kind"], "asset")
        self.assertTrue(d["ok"])

    def test_json_wants_the_revalidating_header(self):
        d = self.r2.header_check("cards", "manifest.json",
                                 "public, max-age=21600, stale-while-revalidate=86400")
        self.assertEqual(d["kind"], "json")
        self.assertTrue(d["ok"])

    def test_deviation_is_reported_with_the_expected_value(self):
        d = self.r2.header_check("gallery-hot", "collections/a/images/1.jpg", "public, max-age=60")
        self.assertFalse(d["ok"])
        self.assertEqual(d["expected"], "public, max-age=7776000, immutable")

    def test_relationships_are_intentionally_mutable_for_now(self):
        d = self.r2.header_check("characters", "freya/relationships/L1.webp", "public, max-age=60")
        self.assertEqual(d["kind"], "mutable")
        self.assertTrue(d["ok"])
        # The same file name under another bucket is an ordinary asset.
        self.assertFalse(self.r2.header_check("cards", "freya/relationships/L1.webp",
                                              "public, max-age=60")["ok"])

    def test_spacing_and_case_do_not_count_as_a_deviation(self):
        self.assertTrue(self.r2.header_check(
            "cards", "manifest.json",
            "Public,max-age=21600,  stale-while-revalidate=86400")["ok"])


class DeleteGuardTests(unittest.TestCase):
    def setUp(self):
        self.r2 = _load("r2_control_test.r2_control", CORE / "r2_control.py")
        self.fake = FakeS3({"promo": {"cross-promo/a.webp": {"size": 10}},
                            "hotjigsaw": {"promo/a.webp": {"size": 10}}})
        self.r2._s3_cache = self.fake
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.r2._DATA_DIR = self.tmp.name
        self.r2._AUDIT_FILE = str(Path(self.tmp.name, "r2_audit.log"))

    def test_confirm_must_be_the_bucket_name(self):
        with self.assertRaises(ValueError):
            self.r2.delete("promo", ["cross-promo/a.webp"], confirm="")
        with self.assertRaises(ValueError):
            self.r2.delete("promo", ["cross-promo/a.webp"], confirm="Promo")
        self.assertEqual(self.fake.deleted, [])

    def test_more_than_five_hundred_keys_is_refused(self):
        with self.assertRaises(ValueError):
            self.r2.delete("promo", ["k%d" % i for i in range(501)], confirm="promo")
        self.assertEqual(self.fake.deleted, [])

    def test_empty_selection_and_unknown_bucket_are_refused(self):
        with self.assertRaises(ValueError):
            self.r2.delete("promo", [], confirm="promo")
        with self.assertRaises(ValueError):
            self.r2.delete("nosuchbucket", ["a"], confirm="nosuchbucket")

    def test_plain_delete_leaves_the_legacy_twin_alone(self):
        out = self.r2.delete("promo", ["cross-promo/a.webp"], confirm="promo")
        self.assertEqual(out["deleted"], 1)
        self.assertEqual(self.fake.deleted, [("promo", ["cross-promo/a.webp"])])
        self.assertIn("promo/a.webp", self.fake.objects["hotjigsaw"])

    def test_takedown_clears_the_legacy_twin_too(self):
        out = self.r2.delete("promo", ["cross-promo/a.webp"], takedown=True, confirm="promo")
        self.assertEqual(self.fake.deleted,
                         [("promo", ["cross-promo/a.webp"]), ("hotjigsaw", ["promo/a.webp"])])
        self.assertEqual(out["twins"], [{"bucket": "hotjigsaw", "keys": ["promo/a.webp"],
                                         "deleted": 1, "errors": []}])
        self.assertEqual(self.fake.objects["hotjigsaw"], {})

    def test_takedown_reports_keys_it_cannot_map(self):
        self.fake.objects["cards"] = {"shop_characters/x.webp": {"size": 1}}
        out = self.r2.delete("cards", ["shop_characters/x.webp"], takedown=True, confirm="cards")
        self.assertEqual(out["unmapped"], ["shop_characters/x.webp"])
        self.assertEqual(out["twins"], [])

    def test_every_delete_lands_in_the_audit_log(self):
        self.r2.delete("promo", ["cross-promo/a.webp"], takedown=True,
                       confirm="promo", client="studyo")
        satirlar = [json.loads(s) for s in
                    Path(self.r2._AUDIT_FILE).read_text(encoding="utf-8").splitlines()]
        self.assertEqual([s["action"] for s in satirlar], ["takedown", "takedown-twin"])
        self.assertEqual(satirlar[0]["client"], "studyo")
        self.assertEqual(satirlar[1]["keys"], ["promo/a.webp"])

    def test_plan_shows_both_buckets_before_anything_is_deleted(self):
        plan = self.r2.takedown_plan("promo", ["cross-promo/a.webp", "cross-promo/b.webp"])
        self.assertEqual(plan["twins"],
                         [{"bucket": "hotjigsaw", "keys": ["promo/a.webp", "promo/b.webp"]}])
        self.assertEqual(plan["limit"], 500)
        self.assertEqual(self.fake.deleted, [])


class PreviewTests(unittest.TestCase):
    def setUp(self):
        self.r2 = _load("r2_control_test.r2_control", CORE / "r2_control.py")
        self.fake = FakeS3({"gallery-hot": {
            "collections/a/videos/1.mp4": {"size": 3_000_000, "content_type": "video/mp4"},
            "collections/a/videos_webp/1.webp": {"size": 2_900_000, "content_type": "image/webp"},
            "collections/a/images/1.jpg": {"size": 300_000, "content_type": "image/jpeg"},
            "collections/a/music/t.mp3": {"size": 800_000, "content_type": "audio/mpeg"},
        }})
        self.r2._s3_cache = self.fake

    def test_videos_are_never_downloaded(self):
        with self.assertRaises(self.r2.NoPreview) as e:
            self.r2.thumb("gallery-hot", "collections/a/videos/1.mp4")
        self.assertEqual(e.exception.reason, "video")
        self.assertEqual(e.exception.size, 3_000_000)

    def test_objects_over_two_megabytes_are_never_downloaded(self):
        with self.assertRaises(self.r2.NoPreview) as e:
            self.r2.thumb("gallery-hot", "collections/a/videos_webp/1.webp")
        self.assertEqual(e.exception.reason, "too_large")

    def test_audio_is_reported_as_not_an_image(self):
        with self.assertRaises(self.r2.NoPreview) as e:
            self.r2.thumb("gallery-hot", "collections/a/music/t.mp3")
        self.assertEqual(e.exception.reason, "not_image")

    def test_listing_marks_only_small_stills_as_previewable(self):
        rows = {o["name"]: o["preview"]
                for o in self.r2.list_prefix("gallery-hot", "collections/a/")["objects"]}
        self.assertEqual(rows, {})          # everything sits one level deeper
        rows = {o["name"]: o["preview"]
                for o in self.r2.list_prefix("gallery-hot", "collections/a/videos/")["objects"]}
        self.assertEqual(rows, {"1.mp4": False})
        rows = {o["name"]: o["preview"]
                for o in self.r2.list_prefix("gallery-hot", "collections/a/images/")["objects"]}
        self.assertEqual(rows, {"1.jpg": True})

    def test_browsing_shows_sub_folders(self):
        out = self.r2.list_prefix("gallery-hot", "collections/a/")
        self.assertEqual([f["name"] for f in out["folders"]],
                         ["images", "music", "videos", "videos_webp"])


class FixHeaderTests(unittest.TestCase):
    def setUp(self):
        self.r2 = _load("r2_control_test.r2_control", CORE / "r2_control.py")
        self.fake = FakeS3({"cards": {
            "manifest.json": {"size": 5, "content_type": "application/json",
                              "cache_control": "public, max-age=60"},
            "collections/a/a_ace_sheet.webp": {"size": 9, "content_type": "image/webp",
                                               "cache_control": "public, max-age=7776000, immutable"},
            "collections/a/a_two_sheet.webp": {"size": 9, "content_type": "image/webp",
                                               "cache_control": ""},
        }})
        self.r2._s3_cache = self.fake
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.r2._DATA_DIR = self.tmp.name
        self.r2._AUDIT_FILE = str(Path(self.tmp.name, "r2_audit.log"))

    def test_only_deviating_objects_are_rewritten_and_the_type_is_kept(self):
        op = self.r2.fix_headers("cards", "")
        self._wait(op)
        self.assertEqual(sorted(c[1] for c in self.fake.copies),
                         ["collections/a/a_two_sheet.webp", "manifest.json"])
        yazilan = {c[1]: (c[4], c[5]) for c in self.fake.copies}
        self.assertEqual(yazilan["manifest.json"],
                         ("application/json", "public, max-age=21600, stale-while-revalidate=86400"))
        self.assertEqual(yazilan["collections/a/a_two_sheet.webp"],
                         ("image/webp", "public, max-age=7776000, immutable"))

    def test_an_empty_prefix_tree_is_refused_before_an_op_starts(self):
        with self.assertRaises(ValueError):
            self.r2.fix_headers("cards", "nothing/here/")

    def _wait(self, op):
        for _ in range(200):
            o = self.r2.op_status(op)
            if o and o["status"] != "running":
                self.assertEqual(o["status"], "done", o.get("message"))
                return o
            import time
            time.sleep(0.01)
        self.fail("op did not finish")


class CopyTests(unittest.TestCase):
    def setUp(self):
        self.r2 = _load("r2_control_test.r2_control", CORE / "r2_control.py")
        self.fake = FakeS3({"gallery-hot": {"collections/a/images/1.jpg": {"size": 1},
                                            "collections/a/images/2.jpg": {"size": 2}},
                            "gallery-family": {}})
        self.r2._s3_cache = self.fake
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.r2._DATA_DIR = self.tmp.name
        self.r2._AUDIT_FILE = str(Path(self.tmp.name, "r2_audit.log"))

    def test_prefix_copy_keeps_the_relative_path(self):
        op = self.r2.copy("gallery-hot", "gallery-family",
                          src_prefix="collections/a", dst_prefix="collections/b")
        for _ in range(200):
            o = self.r2.op_status(op)
            if o and o["status"] != "running":
                break
            import time
            time.sleep(0.01)
        self.assertEqual(sorted(self.fake.objects["gallery-family"]),
                         ["collections/b/images/1.jpg", "collections/b/images/2.jpg"])

    def test_a_copy_needs_exactly_one_of_key_or_prefix(self):
        with self.assertRaises(ValueError):
            self.r2.copy("gallery-hot", "gallery-family",
                         src_key="collections/a/images/1.jpg", src_prefix="collections/a/")
        with self.assertRaises(ValueError):
            self.r2.copy("gallery-hot", "gallery-family")
        with self.assertRaises(ValueError):
            self.r2.copy("gallery-hot", "gallery-family", src_key="collections/a/images/1.jpg")

    def test_an_empty_source_tree_is_refused(self):
        with self.assertRaises(ValueError):
            self.r2.copy("gallery-hot", "gallery-family",
                         src_prefix="collections/zzz", dst_prefix="collections/b")


class LocalDiffTests(unittest.TestCase):
    """The local "Pushed" tree against the bucket, with a fake staging layout."""

    def setUp(self):
        self.r2 = _load("r2_control_test.r2_control", CORE / "r2_control.py")
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.pushed = Path(self.tmp.name, "Hot Jigsaw - Pushed", "Generic")
        self.pushed.mkdir(parents=True)
        for ad, boy in (("1.jpg", 10), ("1.mp4", 20), ("1.webp", 30),
                        ("1.json", 5), ("2.jpg", 40)):
            Path(self.pushed, ad).write_bytes(b"x" * boy)
        self.fake = FakeS3({"gallery-hot": {
            "collections/Generic/images/1.jpg": {"size": 10},
            "collections/Generic/videos/1.mp4": {"size": 20},
            "collections/Generic/videos_webp/1.webp": {"size": 99},
            "collections/Generic/thumbs/1-grayscale.jpg": {"size": 7},
        }})
        self.r2._s3_cache = self.fake
        sahte = types.ModuleType("r2_control_test.jigsaw_flow")
        sahte.paths = lambda rating: {"pushed": str(self.pushed.parent),
                                      "bucket": "gallery-hot"}
        sys.modules["r2_control_test.jigsaw_flow"] = sahte
        sys.modules["r2_control_test"].jigsaw_flow = sahte
        self.addCleanup(lambda: sys.modules.pop("r2_control_test.jigsaw_flow", None))

    def test_local_sidecars_never_count_as_missing_in_the_bucket(self):
        d = self.r2.diff("hot", "Generic")
        self.assertEqual(d["missing_in_bucket"], ["collections/Generic/images/2.jpg"])
        self.assertEqual(d["local_count"], 4, "the .json sidecar stays local")

    def test_generated_thumbs_are_reported_apart_from_real_gaps(self):
        d = self.r2.diff("hot", "Generic")
        self.assertEqual(d["missing_locally"], [])
        self.assertEqual(d["derived_in_bucket"], ["collections/Generic/thumbs/1-grayscale.jpg"])

    def test_a_size_mismatch_carries_both_sizes(self):
        d = self.r2.diff("hot", "Generic")
        self.assertEqual(d["size_mismatch"],
                         [{"key": "collections/Generic/videos_webp/1.webp",
                           "local": 30, "bucket": 99}])

    def test_an_unknown_collection_is_refused(self):
        with self.assertRaises(ValueError):
            self.r2.diff("hot", "NoSuchCollection")


class TwinDiffTests(unittest.TestCase):
    def setUp(self):
        self.r2 = _load("r2_control_test.r2_control", CORE / "r2_control.py")
        self.fake = FakeS3({
            "promo": {"cross-promo/a.webp": {"size": 10},
                      "cross-promo/b.webp": {"size": 20},
                      "house-ads/x.webp": {"size": 5}},
            "hotjigsaw": {"promo/a.webp": {"size": 10},
                          "promo/c.webp": {"size": 30},
                          "collections/x/images/1.jpg": {"size": 99}},
        })
        self.r2._s3_cache = self.fake

    def test_diff_reports_both_sides_and_ignores_the_rest_of_the_legacy_bucket(self):
        d = self.r2.twin_diff("promo")
        self.assertEqual(d["twin"], "hotjigsaw")
        self.assertEqual(d["missing_in_legacy"], ["cross-promo/b.webp"])
        self.assertEqual(d["only_in_legacy"], ["promo/c.webp"])
        self.assertEqual(d["unmapped"], ["house-ads/x.webp"])
        self.assertEqual(d["legacy_count"], 2)   # collections/ belongs to gallery-hot

    def test_size_mismatch_is_listed_with_both_keys(self):
        self.fake.objects["hotjigsaw"]["promo/a.webp"]["size"] = 11
        d = self.r2.twin_diff("promo")
        self.assertEqual(d["size_mismatch"], [{"key": "cross-promo/a.webp",
                                               "twin_key": "promo/a.webp",
                                               "new": 10, "legacy": 11}])

    def test_the_diff_is_taken_from_the_new_side(self):
        with self.assertRaises(ValueError):
            self.r2.twin_diff("hotjigsaw")
        with self.assertRaises(ValueError):
            self.r2.twin_diff("cbn")


if __name__ == "__main__":
    unittest.main()
