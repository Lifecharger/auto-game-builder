import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from character.sam_frames import alpha_from


class CharacterEdgeRefinementTests(unittest.TestCase):
    def test_strict_removes_floor_outside_matte_without_erasing_center(self):
        mask = np.zeros((48, 48), dtype=bool)
        mask[10:38, 10:38] = True
        matte = np.zeros((48, 48), dtype=np.float32)
        matte[12:36, 12:36] = 255
        soft = alpha_from(mask, matte, True)
        strict = alpha_from(mask, matte, True, edge_mode="strict")
        self.assertGreater(soft[11, 24], 0)
        self.assertEqual(strict[11, 24], 0)
        self.assertEqual(strict[24, 24], soft[24, 24])

    def test_strict_requires_refinement_data(self):
        mask = np.ones((16, 16), dtype=bool)
        with self.assertRaisesRegex(RuntimeError, "requires an ISNet matte"):
            alpha_from(mask, None, True, edge_mode="strict")
        with self.assertRaises(ValueError):
            alpha_from(mask, None, False, edge_mode="unknown")


if __name__ == "__main__":
    unittest.main()
