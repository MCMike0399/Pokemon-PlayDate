#!/usr/bin/env python3
"""Drawn type names are pokered display names, and drawText sees no raw markup.

The Hall card currently prints the constant PSYCHIC_TYPE. Playdate drawText
treats _ as italic, so the card shows PSYCHIC plus an italic TYPE. pokered
data/types/names.asm (af519899) uses plain PSYCHIC. These checks fail on the
live tree and pass once tools/notes/lane-e-type-display-names.patch is applied.
A single-type mon still has no TYPE2/ row.
"""

import json
import os
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VISUAL = ROOT / "Source/data/endgame/visual.json"
STORY = ROOT / "Source/game/endgameStory.lua"
DRAWN = ROOT / "Source/game/drawnText.lua"
BATTLE = ROOT / "Source/battle/battleScene.lua"
FONT = ROOT / "Source/game/gbFont.lua"

PROBE = r"""
json = { decodeFile = function() return visual end }
local handle = io.open(drawn_path, "r")
if handle then
    handle:close()
    dofile(drawn_path)
end
dofile(story_path)
local function emit(kind, text)
    io.write(kind, "\t", (text or ""):gsub("\n", "\\n"), "\n")
end
local species = {}
for name in pairs(EndgameStory.visual().types) do
    species[#species + 1] = name
end
table.sort(species)
for _, name in ipairs(species) do
    local rows = EndgameStory.hallRows({
        kind = "pokemon", name = "MON", level = 5,
        types = EndgameStory.monTypes(name),
    })
    local texts = {}
    for _, row in ipairs(rows) do
        texts[#texts + 1] = row.text
    end
    emit("HALL", name .. "\t" .. table.concat(texts, "\t"))
end
if DrawnText and DrawnText.install and DrawnText.typeName then
    local seen
    local gfx = {}
    function gfx.drawText(text)
        seen = text
    end
    function gfx.drawTextInRect(text)
        gfx.drawText(text)
    end
    function gfx.drawTextAligned(text)
        gfx.drawText(text)
    end
    function gfx.getTextSize(text)
        return #text, 8
    end
    DrawnText.install(gfx)
    local function through(kind, text, draw)
        seen = nil
        draw(text)
        emit(kind, seen)
    end
    through("DRAW", "NICK_NAME*STAR", gfx.drawText)
    through("RECT", "NICK_NAME*STAR", gfx.drawTextInRect)
    through("ALIGN", "NICK_NAME*STAR", gfx.drawTextAligned)
    through("DRAW", "*Lv 5*", gfx.drawText)
    emit("NAME", DrawnText.typeName("PSYCHIC_TYPE"))
    emit("NAME", DrawnText.typeName("psychic"))
    emit("NAME", DrawnText.typeName("FIRE"))
    emit("NAME", DrawnText.typeName("dark"))
    emit("NAME", DrawnText.typeName("steel"))
end
"""


def lua_binary():
    override = os.environ.get("LUA")
    if override:
        return override
    for name in ("lua", "lua5.4"):
        found = shutil.which(name)
        if found:
            return found
    raise AssertionError("Lua 5.4 is required")


def unescaped_markup(text):
    index = 0
    while index < len(text):
        mark = text[index]
        if mark in "_*":
            if index + 1 < len(text) and text[index + 1] == mark:
                index += 2
            else:
                return mark
        else:
            index += 1
    return None


def lua_quote(value):
    return json.dumps(value, ensure_ascii=False)


def load_cards():
    visual = json.loads(VISUAL.read_text(encoding="utf-8"))
    script = (
        "visual = " + lua_quote_table(visual) + "\n"
        + "drawn_path = " + lua_quote(str(DRAWN)) + "\n"
        + "story_path = " + lua_quote(str(STORY)) + "\n"
        + PROBE
    )
    completed = subprocess.run(
        [lua_binary(), "-e", script],
        cwd=ROOT, check=False, capture_output=True, text=True)
    if completed.returncode != 0:
        raise AssertionError(completed.stderr or completed.stdout)
    cards = {}
    drawn = []
    names = []
    for line in completed.stdout.splitlines():
        kind, _, rest = line.partition("\t")
        if kind == "HALL":
            species, _, texts = rest.partition("\t")
            cards[species] = texts.split("\t") if texts else []
        elif kind in ("DRAW", "RECT", "ALIGN"):
            drawn.append(rest)
        elif kind == "NAME":
            names.append(rest)
    return cards, drawn, names


def lua_quote_table(value):
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int) and not isinstance(value, bool):
        return str(value)
    if isinstance(value, str):
        return lua_quote(value)
    if isinstance(value, list):
        return "{" + ",".join(lua_quote_table(item) for item in value) + "}"
    if isinstance(value, dict):
        parts = []
        for key, item in value.items():
            parts.append("[" + lua_quote(str(key)) + "]=" + lua_quote_table(item))
        return "{" + ",".join(parts) + "}"
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    raise TypeError(type(value))


def type_row(texts, label):
    index = texts.index(label)
    return texts[index + 1]


class TypeDisplayNameTests(unittest.TestCase):
    def test_hall_card_prints_the_psychic_display_name(self):
        cards, _, names = load_cards()
        mewtwo = cards["mewtwo"]
        self.assertIn("TYPE1/", mewtwo)
        self.assertNotIn("TYPE2/", mewtwo)
        self.assertEqual(type_row(mewtwo, "TYPE1/"), "PSYCHIC")
        charmander = cards["charmander"]
        self.assertNotIn("TYPE2/", charmander)
        self.assertEqual(type_row(charmander, "TYPE1/"), "FIRE")
        exeggutor = cards["exeggutor"]
        self.assertIn("TYPE2/", exeggutor)
        self.assertEqual(type_row(exeggutor, "TYPE1/"), "GRASS")
        self.assertEqual(type_row(exeggutor, "TYPE2/"), "PSYCHIC")
        self.assertEqual(names, ["PSYCHIC", "PSYCHIC", "FIRE", "DARK", "STEEL"])

    def test_drawn_strings_have_no_unescaped_markup(self):
        cards, drawn, _ = load_cards()
        presented = []
        for texts in cards.values():
            presented.extend(texts)
        presented.extend(drawn)
        if not drawn:
            presented.append("NICK_NAME*STAR")
        bad = [text for text in presented if unescaped_markup(text)]
        self.assertEqual(bad, [])
        battle = BATTLE.read_text(encoding="utf-8")
        font = FONT.read_text(encoding="utf-8")
        story = STORY.read_text(encoding="utf-8")
        module = DRAWN.read_text(encoding="utf-8")
        self.assertIn('import "game/drawnText"', story)
        self.assertIn("DrawnText.typeName(move.type)", battle)
        self.assertIn("DrawnText.install(gfx)", font)
        self.assertIn("graphics.drawTextInRect", module)
        self.assertIn("graphics.drawTextAligned", module)
        self.assertIn('DrawnText.install(playdate.graphics)', module)
        self.assertEqual(drawn[0], "NICK__NAME**STAR")
        self.assertEqual(drawn[1], "NICK__NAME**STAR")
        self.assertEqual(drawn[2], "NICK__NAME**STAR")
        self.assertEqual(drawn[3], "**Lv 5**")


if __name__ == "__main__":
    unittest.main()
