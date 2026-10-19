"""Notices: notes for the owner from automations (2026-10-19) - temp database, no network.

Weekly report and Play review replies used to file closed tasks on the AGB app; they
now go to their own `notices` table (Notes tab). A note with a key is replaced by a
rerun with the same key and comes back unread.
"""
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from database.db_manager import DBManager  # noqa: E402


class NoticesTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.db = DBManager(str(Path(self.tmp.name) / "t.db"))

    def tearDown(self):
        self.db._get_conn().close()
        self.tmp.cleanup()

    def test_add_read_delete(self):
        a = self.db.upsert_notice("play_reviews", "Play yorumlari", "4 cevap")
        b = self.db.upsert_notice("weekly_report", "Weekly", "body")
        self.assertEqual(self.db.count_notices(unread_only=True), 2)
        self.db.set_notice_read(a, True)
        self.assertEqual([n["id"] for n in self.db.get_notices(unread_only=True)], [b])
        self.db.delete_notice(b)
        self.assertEqual(self.db.count_notices(), 1)

    def test_same_key_replaces_and_marks_unread(self):
        a = self.db.upsert_notice("weekly_report", "Weekly 10-19", "v1", note_key="weekly:2026-10-19")
        self.db.set_notice_read(a, True)
        b = self.db.upsert_notice("weekly_report", "Weekly 10-19", "v2", note_key="weekly:2026-10-19")
        self.assertEqual(a, b)
        n = self.db.get_notice(a)
        self.assertEqual((n["body"], n["is_read"]), ("v2", 0))
        self.assertEqual(self.db.count_notices(), 1)

    def test_no_key_never_merges(self):
        self.db.upsert_notice("x", "t", "1")
        self.db.upsert_notice("x", "t", "2")
        self.assertEqual(self.db.count_notices(), 2)


if __name__ == "__main__":
    unittest.main()
