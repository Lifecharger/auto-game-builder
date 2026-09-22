"""#385 normalizer: sema uyumu, atlama mantigi, indeks sekli, engel anlamlari.

Sunucu ice ALINMAZ (asset_normalizer `jigsaw_flow`'u cekiyor, o da comfy/GPU
tarafini): yalniz gereken tanimlar ast ile yuklenir - test_review_regressions
ile ayni yontem. Ag, GPU ve kova bu testlerde hic yoktur.
"""
from __future__ import annotations

import ast
import importlib.util
import json
import os
import threading
import unittest

from test_review_regressions import CORE, extract

NORM = CORE / "asset_normalizer.py"
DELIVERY = CORE / "delivery.py"


_LITERAL = (ast.Constant, ast.Tuple, ast.List, ast.Dict, ast.Set, ast.JoinedStr)


def load(path, names, env=None):
    """Modulun SABIT (duz deger) atamalarini + istenen fonksiyonlari yukler.

    Cagri iceren atamalar (urllib opener'i, kilitler, yol hesaplari) bilincli
    olarak atlanir - testin ag/GPU/dosya baglantisi yok. `_ROOT` depo kokunden
    verilir, cunku sema ve exif_writer yollari ondan turuyor.
    """
    env = dict(env or {})
    env.setdefault("os", os)
    env.setdefault("threading", threading)
    env.setdefault("json", json)
    env.setdefault("importlib", importlib)
    env.setdefault("_ROOT", str(path.parents[2]))
    body = ast.parse(path.read_text(encoding="utf-8-sig")).body
    sabitler = [n for n in body if isinstance(n, (ast.Assign, ast.AnnAssign))
                and n.value is not None and isinstance(n.value, _LITERAL)]
    module = ast.Module(body=sabitler, type_ignores=[])
    exec(compile(ast.fix_missing_locations(module), str(path), "exec"), env)
    return extract(path, names, env)


def _tam_etiket():
    """tagging_schema'nin TAM sema cevabi - her alan dolu ve gecerli."""
    spec = importlib.util.spec_from_file_location(
        "norm_schema_test", CORE.parents[1] / "tools/r2manager/tagging_schema.py")
    schema = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(schema)
    out = {}
    for alan, kural in schema._OLLAMA_TAG_SCHEMA["properties"].items():
        if "enum" in kural:
            out[alan] = kural["enum"][0]
        elif kural["type"] == "array":
            out[alan] = []
        elif kural["type"] == "integer":
            out[alan] = 1
        else:
            out[alan] = "deger"
    return out, schema


class SchemaValidation(unittest.TestCase):
    def setUp(self):
        self.env = load(NORM, {"validate_tags", "fields_from_tags", "conforms", "_pipe", "_schema"})

    def test_full_answer_passes_and_maps_onto_the_worker_field_names(self):
        data, _ = _tam_etiket()
        self.env["validate_tags"](data)                      # atmamali
        subject, title = self.env["fields_from_tags"](data)
        # Worker (serveFieldValues) BU kisa adlari okur - degisirse filtre bozulur.
        self.assertEqual(set(subject), {"rating", "safety", "voyeur", "skin", "adult", "racy",
                                        "violence", "camera", "view", "pose", "framing", "mood",
                                        "context"})
        self.assertEqual(set(title), {"coverage", "fit", "risk", "flags", "body", "clothing",
                                      "style", "setting", "focus"})
        ok, neden = self.env["conforms"]({"subject_fields": subject, "title_fields": title})
        self.assertTrue(ok, neden)

    def test_a_missing_field_is_an_error_not_a_default(self):
        data, _ = _tam_etiket()
        del data["rating"]
        with self.assertRaises(ValueError) as e:
            self.env["validate_tags"](data)
        self.assertIn("rating", str(e.exception))

    def test_bad_enum_and_out_of_range_score_are_refused(self):
        data, _ = _tam_etiket()
        data["safety_level"] = "pretty_safe"
        with self.assertRaises(ValueError):
            self.env["validate_tags"](data)
        data, _ = _tam_etiket()
        data["adult"] = 9
        with self.assertRaises(ValueError):
            self.env["validate_tags"](data)
        data, _ = _tam_etiket()
        data["body_parts"] = "cleavage"              # liste olmali
        with self.assertRaises(ValueError):
            self.env["validate_tags"](data)

    def test_conforms_names_the_reason_so_the_report_can_print_it(self):
        conforms = self.env["conforms"]
        self.assertEqual(conforms(None), (False, "metadata yok"))
        self.assertEqual(conforms({})[1], "subject/title alanlari yok")
        data, _ = _tam_etiket()
        subject, title = self.env["fields_from_tags"](data)
        eksik = dict(subject)
        del eksik["voyeur"]
        self.assertEqual(conforms({"subject_fields": eksik, "title_fields": title}),
                         (False, "subject eksik: voyeur"))
        bozuk = dict(subject, rating="grown-up")
        self.assertFalse(conforms({"subject_fields": bozuk, "title_fields": title})[0])
        # Bos LISTE gecerlidir (risk/flags cogu gorselde bos) - bos METIN degildir.
        self.assertTrue(conforms({"subject_fields": subject,
                                  "title_fields": dict(title, risk=[], flags=[])})[0])
        self.assertFalse(conforms({"subject_fields": dict(subject, mood=""),
                                   "title_fields": title})[0])

    def test_pipe_parser_matches_the_worker_exactly(self):
        # Worker'in parsePipeDelimitedFields'i ile ayni sonuc: sayisal alanlar
        # int, virgullu degerler liste, gerisi metin. Iki taraf ayrilirsa
        # filtre ile yazilan etiket ortusmez.
        out = self.env["_pipe"]("adult:3|rating:teen|risk:cleavage, thighs|mood:", ("adult",))
        self.assertEqual(out, {"adult": 3, "rating": "teen",
                               "risk": ["cleavage", "thighs"], "mood": ""})
        self.assertEqual(self.env["_pipe"](None), {})
        self.assertEqual(self.env["_pipe"]("gecersiz"), {})


class ExifRoundTrip(unittest.TestCase):
    """Etiket -> EXIF -> indeks girdisi: yazan ve okuyan ayni semayi konusmali."""

    def test_written_exif_reads_back_as_a_conforming_index_entry(self):
        import tempfile
        from PIL import Image
        env = load(NORM, {"validate_tags", "fields_from_tags", "conforms", "_pipe",
                          "exif_entry", "write_exif", "_schema"})
        data, _ = _tam_etiket()
        data.update(tags="a,b,c", description="bir cumle", body_parts=["cleavage", "thighs"],
                    risk_factors=[], policy_flags=[], adult=3, racy=2, violence=1)
        with tempfile.TemporaryDirectory() as klasor:
            yol = os.path.join(klasor, "1.jpg")
            Image.new("RGB", (24, 32), "gray").save(yol, "JPEG")
            env["write_exif"](yol, data)
            girdi = env["exif_entry"](yol)
            self.assertIsNotNone(girdi)
            ok, neden = env["conforms"](girdi)
            self.assertTrue(ok, neden)
            self.assertEqual(girdi["subject_fields"]["adult"], 3)
            self.assertEqual(girdi["title_fields"]["body"], ["cleavage", "thighs"])
            # exif_writer bos listeyi "none" yazar; liste alanlari zorunlu enum
            # olmadigi icin bu gecerlidir ve filtreyi yanlis tetiklemez.
            self.assertEqual(girdi["title_fields"]["risk"], "none")
            self.assertEqual(girdi["tags"], "a,b,c")

    def test_an_untagged_jpg_has_no_entry_at_all(self):
        import tempfile
        from PIL import Image
        env = load(NORM, {"exif_entry", "_pipe"})
        with tempfile.TemporaryDirectory() as klasor:
            yol = os.path.join(klasor, "1.jpg")
            Image.new("RGB", (8, 8), "gray").save(yol, "JPEG")
            self.assertIsNone(env["exif_entry"](yol))


class BlockSemantics(unittest.TestCase):
    """Engel listesi: kurallardan SONRA, global + uygulama BIRLESIMI."""

    def setUp(self):
        self.env = load(DELIVERY, {"_block_lists"})

    def test_lists_are_trimmed_deduped_and_limited_to_the_known_names(self):
        out = self.env["_block_lists"]({"pictures": [" generic/1.jpg ", "generic/1.jpg", ""],
                                        "decks": ["gothic_vampire"], "junk": ["x"]})
        self.assertEqual(out["pictures"], ["generic/1.jpg"])
        self.assertEqual(out["decks"], ["gothic_vampire"])
        self.assertEqual(out["cards"], [])
        self.assertNotIn("junk", out)
        self.assertEqual(set(out), {"pictures", "collections", "cards", "decks", "hostLevels"})

    def test_a_non_dict_becomes_empty_lists_never_an_exception(self):
        out = self.env["_block_lists"](None)
        self.assertEqual(sorted(k for k, v in out.items() if v), [])


class PoolShape(unittest.TestCase):
    def test_every_pool_declares_its_bucket_and_index_mechanism(self):
        env = load(NORM, {"report"})
        for pool in env["POOLS"]:
            bilgi = env["POOL_INFO"][pool]
            self.assertTrue(bilgi["bucket"])
            self.assertTrue(bilgi["index"], "havuzun indeks mekanizmasi yazili olmali")

    def test_delivery_pools_and_block_lists_line_up(self):
        env = load(DELIVERY, {"_block_lists"})
        self.assertEqual(env["POOLS"], ("jigsaw", "cards", "events"))
        for pool, listeler in env["POOL_BLOCK_LISTS"].items():
            self.assertIn(pool, env["POOLS"])
            for ad in listeler:
                self.assertIn(ad, env["BLOCK_LISTS"])


if __name__ == "__main__":
    unittest.main()
