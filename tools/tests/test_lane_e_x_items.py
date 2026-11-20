#!/usr/bin/env python3
"""X Attack, X Defend, X Speed, X Special, and X Accuracy raise one stage.

Celadon Mart 5F stocks them. One stage is the Gen V X item. Field use
returns battle-only, so the bag cannot spend them on the map. Guard Spec.
and Dire Hit are not a single stage and stay unsupported.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / 'tools/notes/lane-e-x-items.patch'
ITEMS = ROOT / 'Source/data/items.lua'
BATTLE = ROOT / 'Source/battle/battle.lua'
DOMAIN = ROOT / 'Source/domain/items.lua'


def item_line(text, item_id):
    return next(line for line in text.splitlines() if f'["id"] = "{item_id}"' in line)


class XItemTests(unittest.TestCase):
    def test_live_x_items_raise_one_stage_in_battle_only(self):
        items = ITEMS.read_text()
        for item_id, stat in (
                ('xAccuracy', 'acc'), ('xAttack', 'atk'), ('xDefend', 'def'),
                ('xSpeed', 'spe'), ('xSpecial', 'spa')):
            line = item_line(items, item_id)
            self.assertIn('["effect"] = "statStage"', line)
            self.assertIn(f'["stat"] = "{stat}"', line)
            self.assertIn('["stages"] = 1', line)
        for item_id in ('guardSpec', 'direHit'):
            line = item_line(items, item_id)
            self.assertIn('["effect"] = "unsupported"', line)
        battle = BATTLE.read_text()
        self.assertIn('statStage=true', battle)
        self.assertIn('target.statStages[stat] = current + 1', battle)
        self.assertIn('Inventory.consume(self.session:inventory(), id, 1)', battle)
        domain = DOMAIN.read_text()
        self.assertIn('elseif item.effect == "statStage" then return nil,"battle-only"', domain)

    def test_notes_patch_is_the_handoff(self):
        text = PATCH.read_text()
        self.assertIn('["stat"] = "spe"', text)
        self.assertIn('statStage=true', text)
        self.assertIn('battle-only', text)
        self.assertNotIn('MallocPoolSize', text)
        self.assertNotIn('guardSpec', text)


if __name__ == '__main__':
    unittest.main()
