import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import types
import unittest
import urllib.request

from test_review_regressions import CORE, extract


class CardMetadataTests(unittest.TestCase):
    def test_cached_tags_do_not_run_vision(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder, "still.png")
            path.write_bytes(b"image")
            cached = {"source_sha256": hashlib.sha256(b"image").hexdigest(), "subject_fields": {"rating": "teen"}}
            env = {"Path": Path, "hashlib": hashlib}
            extract(CORE / "card_metadata.py", {"tag_still"}, env)
            self.assertIs(env["tag_still"](str(path), cached, "op"), cached)

    def test_vision_uses_lane_and_writes_manifest_fields_without_changing_source(self):
        from PIL import Image
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder, "still.png")
            Image.new("RGB", (32, 48), "gray").save(path)
            before = path.read_bytes()
            spec = importlib.util.spec_from_file_location("schema_test", CORE.parents[1] / "tools/r2manager/tagging_schema.py")
            schema = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(schema)
            data = {}
            for key, rule in schema._OLLAMA_TAG_SCHEMA['properties'].items():
                data[key] = rule['enum'][0] if 'enum' in rule else [] if rule['type'] == 'array' else 1 if rule['type'] == 'integer' else 'value'
            events = []
            @contextlib.contextmanager
            def hold(*args, **kwargs):
                events.append('acquired')
                yield
                events.append('released')
            def request(req, timeout):
                self.assertEqual(events, ['acquired'])
                self.assertEqual(json.loads(req.data)['model'], 'gemma3:12b')
                return io.BytesIO(json.dumps({'message': {'content': json.dumps(data)}}).encode())
            env = {'Path': Path, 'hashlib': hashlib, 'importlib': importlib, 'json': json,
                   '__file__': str(CORE / 'card_metadata.py'),
                   'urllib': types.SimpleNamespace(request=types.SimpleNamespace(Request=urllib.request.Request, urlopen=request)),
                   'gpu_lane': types.SimpleNamespace(hold=hold),
                   'jigsaw_flow': types.SimpleNamespace(_ollama_cfg=lambda: ('http://local', 'gemma3:12b'), ollama_unload=lambda: events.append('unloaded'))}
            extract(CORE / 'card_metadata.py', {'tag_still'}, env)
            result = env['tag_still'](str(path), None, 'op')
            self.assertEqual(result['subject_fields']['safety'], 'safe')
            self.assertEqual(result['title_fields']['flags'], [])
            self.assertEqual(path.read_bytes(), before)
            self.assertEqual(events, ['acquired', 'unloaded', 'released'])
