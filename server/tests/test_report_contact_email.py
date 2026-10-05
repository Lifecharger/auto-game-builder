"""Optional reply address on in-game reports (2026-10-05) - no network, no database.

The report form of every app may carry `contact_email` inside the report's `meta`;
`_report_dict` lifts it to a top-level field for the clients. The two helpers are
pure, so they are loaded straight from server.py's source (importing the whole API
module would start the server's services).
"""
from __future__ import annotations

import ast
import json
from pathlib import Path
import unittest

SERVER_PY = Path(__file__).resolve().parents[1] / "api" / "server.py"


def _load_functions(*names: str) -> dict:
    tree = ast.parse(SERVER_PY.read_text(encoding="utf-8"))
    picked = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name in names]
    assert {n.name for n in picked} == set(names), "helper missing from server.py"
    ns: dict = {"json": json}
    exec(compile(ast.Module(body=picked, type_ignores=[]), str(SERVER_PY), "exec"), ns)
    return ns


NS = _load_functions("_parse_meta", "_report_contact_email")
contact = NS["_report_contact_email"]


class ReportContactEmailTest(unittest.TestCase):
    def test_reads_the_address_from_meta(self):
        self.assertEqual(contact({"contact_email": "me@example.com"}), "me@example.com")
        self.assertEqual(contact(json.dumps({"contact_email": " me@example.com "})), "me@example.com")

    def test_anonymous_reports_have_no_address(self):
        for meta in (None, "", "{}", {}, {"model": "X"}, "not json", {"contact_email": ""}, {"contact_email": 7}):
            self.assertEqual(contact(meta), "", repr(meta))

    def test_refuses_values_that_are_not_one_address(self):
        for bad in ("no at sign", "a@b@c.com", "a b@c.com", "x" * 255 + "@b.com", "two@a.com, three@b.com"):
            self.assertEqual(contact({"contact_email": bad}), "", bad)


if __name__ == "__main__":
    unittest.main()
