"""LINK CABLE is a new item id. Pokered ids and the other species stay put."""
import os
import re
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/link_cable_host.lua"
CABLE = {
    "kadabra": "alakazam",
    "machoke": "machamp",
    "graveler": "golem",
    "haunter": "gengar",
}


def lua_binary():
    override = os.environ.get("LUA")
    if override:
        return override
    for name in ("lua", "lua5.4"):
        found = shutil.which(name)
        if found:
            return found
    built = Path("/tmp/lua-5.4.7/src/lua")
    if built.is_file() and os.access(built, os.X_OK):
        return str(built)
    raise AssertionError("Lua 5.4 is required")


def pokered_ids(text):
    value = 0
    ids = {}
    in_macro = False
    for raw in text.splitlines():
        line = raw.split(";", 1)[0]
        if re.match(r"\s*MACRO\b", line):
            in_macro = True
            continue
        if re.match(r"\s*ENDM\b", line):
            in_macro = False
            continue
        if in_macro:
            continue
        jump = re.search(r"\bconst_next\s+\$([0-9A-Fa-f]+)", line)
        if jump:
            value = int(jump.group(1), 16)
            continue
        const = re.search(r"\bconst\s+([A-Z0-9_]+)", line)
        if const:
            ids[const.group(1)] = value
            value += 1
            continue
        hm = re.search(r"\badd_hm\s+([A-Z0-9_]+)", line)
        if hm:
            ids["HM_" + hm.group(1)] = value
            value += 1
            continue
        tm = re.search(r"\badd_tm\s+([A-Z0-9_]+)", line)
        if tm:
            ids["TM_" + tm.group(1)] = value
            value += 1
    return ids


class LinkCableTests(unittest.TestCase):
    def test_item_ids_match_pokered_and_the_cable_is_the_next_id(self):
        root = os.environ.get("POKERED_REFERENCE_DIR")
        self.assertTrue(root, "POKERED_REFERENCE_DIR is required")
        ids = pokered_ids((Path(root) / "constants/item_constants.asm").read_text())
        self.assertEqual(ids["TM_SUBSTITUTE"], 0xFA)
        self.assertNotIn(251, ids.values())
        rows = re.findall(
            r'\["symbol"\] = "([A-Z0-9_]+)", \["numericId"\] = (\d+)',
            (ROOT / "Source/data/items.lua").read_text())
        seen = {}
        for symbol, number in rows:
            number = int(number)
            self.assertNotIn(symbol, seen)
            seen[symbol] = number
        self.assertEqual(seen["LINK_CABLE"], 251)
        for symbol, number in seen.items():
            if symbol == "LINK_CABLE":
                continue
            self.assertEqual(ids[symbol], number, symbol)
        self.assertNotIn("linkCable", (ROOT / "Source/data/items.lua").read_text().split("marts = {", 1)[1])

    def test_only_the_four_trade_species_gain_the_stone_edge(self):
        text = (ROOT / "Source/data/evolutionData.lua").read_text()
        for species, target in CABLE.items():
            self.assertIn(
                species + ' = {{to = "' + target + '", targetDex = '
                + {"alakazam": "65", "machamp": "68", "golem": "76", "gengar": "94"}[target]
                + ', method = 8, trigger = "stone", item = "linkCable"}, {to = "'
                + target + '", targetDex = '
                + {"alakazam": "65", "machamp": "68", "golem": "76", "gengar": "94"}[target]
                + ', method = 5, trigger = "trade"}}',
                text)
        self.assertEqual(text.count('item = "linkCable"'), 4)
        self.assertEqual(text.count('trigger = "trade"'), 4)

    def test_bag_use_evolves_kadabra(self):
        completed = subprocess.run(
            [lua_binary(), str(HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn("link-cable-host ok", completed.stdout)


if __name__ == "__main__":
    unittest.main()
