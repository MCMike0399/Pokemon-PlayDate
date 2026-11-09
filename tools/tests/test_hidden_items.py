"""Pinned hidden-item rows, the Itemfinder window, and the existing coin table."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

from tools.generate_hidden_items import build

ROOT = Path(__file__).resolve().parents[2]
POKERED = Path('/home/ubuntu/Developer/Pokemon-PlayDate-env/pokered')


def lua_binary():
    for name in ('lua', 'lua5.4'):
        found = shutil.which(name)
        if found:
            return found
    built = Path('/tmp/lua-5.4.7/src/lua')
    if built.is_file():
        return str(built)
    raise AssertionError('Lua 5.4 is required')


class HiddenItemTests(unittest.TestCase):
    def test_generated_table_matches_the_pinned_sources(self):
        fresh = build(POKERED)
        saved = json.loads((ROOT / 'Source/data/hiddenItems.json').read_text())
        self.assertEqual(saved, fresh)
        self.assertEqual(len(fresh['items']), 54)
        self.assertEqual(fresh['items'][0]['item'], 'potion')
        self.assertEqual(fresh['items'][1]['item'], 'antidote')
        self.assertTrue(fresh['items'][23]['inaccessible'] or any(
            row['inaccessible'] for row in fresh['items']))

    def test_celadon_already_owns_the_twelve_coin_rows(self):
        policy = json.loads((ROOT / 'Source/data/celadonServices/policy.json').read_text())
        coins = policy['policy']['hidden_coins']
        source = build(POKERED)['coins']
        self.assertEqual(len(coins), 12)
        self.assertEqual([(row['x'], row['y']) for row in coins],
                         [(row['x'], row['y']) for row in source])
        typo = next(row for row in coins if row['coins'] == 40)
        self.assertEqual(typo['credited_coins'], 20)
        self.assertTrue(coins[-1]['shadowed_by_slot'])

    def test_itemfinder_window_matches_the_source_comparisons(self):
        path = str(ROOT / 'Source/game/hiddenItems.lua')
        probe = f'''
function import() end
dofile({json.dumps(path)})
local function check(actual, expected)
    if actual ~= expected then error(tostring(actual)) end
end
check(HiddenItems.near(10, 10, 15, 14), true)
check(HiddenItems.near(10, 10, 16, 14), false)
check(HiddenItems.near(10, 10, 15, 15), false)
check(HiddenItems.near(2, 2, 1, 1), true)
check(HiddenItems.near(2, 2, 0, 1), false)
print("hidden-item-window ok")
'''
        completed = subprocess.run(
            [lua_binary(), '-e', probe],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn('hidden-item-window ok', completed.stdout)


if __name__ == '__main__':
    unittest.main()
