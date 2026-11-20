#!/usr/bin/env python3
"""Between-turn text is dismissed before the command menu is required.

Wrap prints "is hurt by the binding!" while the command menu stays closed.
select() then awaited battle.menu.active and the harness expired. A press
on that message opens the menu. The wait alone does not.
tools/notes/lane-e-battle-menu-text-dismiss.patch.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class BattleMenuTextDismissTests(unittest.TestCase):
    def test_select_dismisses_between_turn_text_before_the_menu(self):
        source = (ROOT / "tools/harness/parcel_journey.py").read_text(encoding="utf-8")
        window = source.split("def select(self, path, index, bound=24):", 1)[1]
        window = window.split("visited = set()", 1)[0]
        self.assertIn("between-turn text", window)
        self.assertIn('self.send("press a", "wait 6")', window)
        self.assertIn('self.await_value("battle.menu.active", True, frames=180)', window)
        self.assertNotIn('frames=120', window)


if __name__ == "__main__":
    unittest.main()
