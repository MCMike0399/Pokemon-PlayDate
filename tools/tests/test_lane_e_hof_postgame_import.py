#!/usr/bin/env python3
"""PostgameStory has to be a literal import or a Hall continue stays in the Hall.

origin/main lateKantoStory.lua binds import to a local and calls it only when
that local is a function. pdc treats that string as a bundle request and does
not run the chunk, so PostgameStory.boot never wraps GameContext.installSession.
A Hall save then continues at its saved cell. This fails on that source and
passes once tools/notes/lane-e-hof-postgame-import.patch is applied.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LATE = ROOT / "Source/game/lateKantoStory.lua"
REQUIRED = (
    'import "game/postgameStory"',
    'import "game/fossilRevival"',
)


def import_statements(text):
    return [line.strip() for line in text.splitlines() if line.startswith("import ")]


class PostgameImportTest(unittest.TestCase):
    def test_postgame_and_fossil_chunks_are_literal_imports(self):
        text = LATE.read_text(encoding="utf-8")
        lines = import_statements(text)
        for statement in REQUIRED:
            self.assertIn(
                statement,
                lines,
                "a variable call does not run the chunk, so the Simulator "
                "never builds PostgameStory and a Hall continue stays in the Hall. "
                f"missing {statement}",
            )
        self.assertNotIn("local importer = import", text)
        self.assertNotIn('importer "game/postgameStory"', text)
        self.assertNotIn('importer "game/fossilRevival"', text)


if __name__ == "__main__":
    unittest.main()
