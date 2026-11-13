#!/usr/bin/env python3
"""X Attack and X Speed are sold and then rejected in battle.

Celadon Mart 5F stocks them. Battle:useItem accepts only heal, full
restore, cure, revive, and PP. Items.planUse returns unsupported-item-use
for effect "unsupported" before any stage change, so a purchased X Speed
does not raise Speed and does not spend the turn. One stage is 3/2, which
is the Gen V X item. The patch is not applied on this branch. Guard Spec.
and Dire Hit are not a single stage and stay unsupported.
"""

import subprocess
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
    def test_live_source_rejects_x_speed(self):
        line = item_line(ITEMS.read_text(), 'xSpeed')
        self.assertIn('["effect"] = "unsupported"', line)
        self.assertNotIn('statStage', line)
        battle = BATTLE.read_text()
        self.assertIn(
            'local legal={heal=true,fullRestore=true,cure=true,revive=true,pp=true}',
            battle)
        self.assertNotIn('statStage=true', battle)
        domain = DOMAIN.read_text()
        self.assertIn('else return nil,"unsupported-item-use" end', domain)
        self.assertNotIn('battle-only', domain)

    @unittest.expectedFailure
    def test_unpatched_battle_accepts_an_x_speed_stage(self):
        line = item_line(ITEMS.read_text(), 'xSpeed')
        self.assertIn('["effect"] = "statStage"', line)
        self.assertIn('["stat"] = "spe"', line)
        self.assertIn('["stages"] = 1', line)
        self.assertIn('statStage=true', BATTLE.read_text())

    def test_patch_raises_one_stage_and_keeps_field_use_closed(self):
        check = subprocess.run(
            ['git', 'apply', '--check', str(PATCH)], cwd=ROOT,
            capture_output=True, text=True)
        self.assertEqual(check.returncode, 0, check.stderr)
        staged = Path('/tmp/lane-e-x-items-staged')
        if staged.exists():
            subprocess.check_call(['rm', '-rf', str(staged)])
        for relative in (
                'Source/data/items.lua',
                'Source/domain/items.lua',
                'Source/battle/battle.lua'):
            destination = staged / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes((ROOT / relative).read_bytes())
        applied = subprocess.run(
            ['patch', '-p1', '-d', str(staged), '-i', str(PATCH)],
            capture_output=True, text=True)
        self.assertEqual(applied.returncode, 0, applied.stdout + applied.stderr)
        patched_items = (staged / 'Source/data/items.lua').read_text()
        for item_id, stat in (
                ('xAccuracy', 'acc'), ('xAttack', 'atk'), ('xDefend', 'def'),
                ('xSpeed', 'spe'), ('xSpecial', 'spa')):
            line = item_line(patched_items, item_id)
            self.assertIn('["effect"] = "statStage"', line)
            self.assertIn(f'["stat"] = "{stat}"', line)
            self.assertIn('["stages"] = 1', line)
        patched_domain = (staged / 'Source/domain/items.lua').read_text()
        self.assertIn('elseif item.effect == "statStage" then return nil,"battle-only"', patched_domain)
        patched_battle = (staged / 'Source/battle/battle.lua').read_text()
        self.assertIn('statStage=true', patched_battle)
        self.assertIn('target.statStages[stat] = current + 1', patched_battle)
        self.assertIn('Inventory.consume(self.session:inventory(), id, 1)', patched_battle)
        self.assertNotIn('statStage', item_line(ITEMS.read_text(), 'xSpeed'))
        self.assertNotIn('statStage=true', BATTLE.read_text())


if __name__ == '__main__':
    unittest.main()
