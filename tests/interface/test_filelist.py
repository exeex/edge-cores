"""Workspace integration checks for root-relative -f and file-relative -F."""
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import prepare_e3_filelist as filelist


class FilelistTest(unittest.TestCase):
    def test_pinned_product_filelist(self):
        sources = filelist.expand(filelist.ENTRY)
        self.assertIn(str(filelist.PUBLIC_MODEL), sources)
        self.assertNotIn(str(filelist.SRAM_MODEL), sources)
        self.assertTrue(any(p.endswith("/edge_tensor_unit/edge_tensor_unit.v") for p in sources))
        self.assertTrue(any(p.endswith("/rtl/edge_dtcm_h4.v") for p in sources))
        self.assertFalse(any("/legacy/" in p for p in sources))

    def test_mixed_relative_modes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            (root / "lists").mkdir()
            (root / "rtl").mkdir()
            (root / "rtl/a.v").touch()
            (root / "top.fl").write_text("-F lists/product.fl\n")
            (root / "lists/product.fl").write_text("+incdir+../rtl\n../rtl/a.v\n-f ../root.fl\n")
            (root / "root.fl").write_text("rtl/a.v\n")
            with patch.multiple(filelist, E3=root, ALLOWED=(root,)):
                self.assertEqual(filelist.expand(root / "top.fl"), [
                    "+incdir+" + str(root / "rtl"), str(root / "rtl/a.v"),
                    str(root / "rtl/a.v"),
                ])

    def test_relative_cycle_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            (root / "loop.fl").write_text("-F loop.fl\n")
            with patch.multiple(filelist, E3=root, ALLOWED=(root,)):
                with self.assertRaisesRegex(ValueError, "cyclic filelist"):
                    filelist.expand(root / "loop.fl")


if __name__ == "__main__":
    unittest.main()
