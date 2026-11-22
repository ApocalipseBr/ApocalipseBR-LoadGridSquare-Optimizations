import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from scripts.build_workshop import promote


class WorkshopPackageTests(unittest.TestCase):
    def test_rebuild_keeps_the_published_workshop_id(self):
        for configured, expected in (("", "id=123\n"), ("id=456\n", "id=456\n")):
            with self.subTest(configured=configured), TemporaryDirectory() as scratch:
                root = Path(scratch)
                previous = root / "output"
                previous.mkdir()
                (previous / "workshop.txt").write_text("version=1\nid=123\ndescription=previous\n", encoding="utf-8")
                replacement = root / "staged"
                replacement.mkdir()
                (replacement / "workshop.txt").write_text(
                    f"version=1\n{configured}description=current\n", encoding="utf-8",
                )

                promote(replacement, previous)

                metadata = (previous / "workshop.txt").read_text(encoding="utf-8")
                self.assertEqual(metadata, f"version=1\n{expected}description=current\n")
