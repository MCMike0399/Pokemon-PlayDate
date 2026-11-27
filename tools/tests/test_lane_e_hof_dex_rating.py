#!/usr/bin/env python3
"""Hall of Fame dex rating text, table, and 120-frame delays.

pokered hall_of_fame.asm prints DexSeenOwnedText, then DexRatingText, then
wDexRatingText, and HoFPrintTextAndDelay waits 120 frames after each.
DisplayDexRating's hall branch copies DexRatingsTable. The live tree draws
that paragraph as one drawText under the label, and the block is tall
enough that the rating text never appears. This fails on the live tree and
passes once K's tools/notes/lane-k-premerge-hof-dex-rating.patch is applied.
That patch is on cursor/lane-k-qa at 8600ea0b. It keeps these lines and
draws each one with EndgameStory.drawPokeredText. The patch under
tools/notes/lane-e-hof-dex-rating.patch is superseded: E no longer calls
gfx.drawText for the hall page, so that diff does not apply.
"""

import os
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STORY = ROOT / "Source/game/endgameStory.lua"

# text/pokedex_ratings.asm with '#' rendered as POKé, the same substitution
# the rest of the port uses. Thresholds are DexRatingsTable: owned < N.
BANDS = [
    (0, 9, "You still have\nlots to do.\nLook for POKéMON\nin grassy areas!"),
    (10, 19, "You're on the\nright track! \nGet a FLASH HM\nfrom my AIDE!"),
    (20, 29, "You still need\nmore POKéMON!\nTry to catch\nother species!"),
    (30, 39, "Good, you're\ntrying hard!\nGet an ITEMFINDER\nfrom my AIDE!"),
    (40, 49, "Looking good!\nGo find my AIDE\nwhen you get 50!"),
    (50, 59, "You finally got at\nleast 50 species!\nBe sure to get\nEXP.ALL from my\nAIDE!"),
    (60, 69, "Ho! This is geting\neven better!"),
    (70, 79, "Very good!\nGo fish for some\nmarine POKéMON!"),
    (80, 89, "Wonderful!\nDo you like to\ncollect things?"),
    (90, 99, "I'm impressed!\nIt must have been\ndifficult to do!"),
    (100, 109, "You finally got at\nleast 100 species!\nI can't believe\nhow good you are!"),
    (110, 119, "You even have the\nevolved forms of\nPOKéMON! Super!"),
    (120, 129, "Excellent! Trade\nwith friends to\nget some more!"),
    (130, 139, "Outstanding!\nYou've become a\nreal pro at this!"),
    (140, 149, "I have nothing\nleft to say!\nYou're the\nauthority now!"),
    (150, 151, "Your POKéDEX is\nentirely complete!\nCongratulations!"),
]


def lua_binary():
    override = os.environ.get("LUA")
    if override:
        return override
    for name in ("lua", "lua5.4"):
        found = shutil.which(name)
        if found:
            return found
    raise AssertionError("Lua 5.4 is required")


def lua_quote(value):
    return '"' + (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
    ) + '"'


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


PROBE = r"""
dofile(story_path)
local rows = EndgameStory.playerHallRows({name = "RED"})
if rows[1].text ~= "RED" or rows[1].row ~= 3 then
    error("RED label moved off the approved name-box row")
end
local pages = EndgameStory.playerHallPages({seen = 8, owned = 2, name = "RED"})
if #pages ~= 3 then error("player card pages") end
local labels = {"seen-owned", "rating-label", "rating-text"}
for index, page in ipairs(pages) do
    if page.delay ~= 120 then
        error(labels[index] .. " delay is " .. tostring(page.delay) .. ", HoFPrintTextAndDelay is 120")
    end
end
if not pages[1].text:find("Seen:8", 1, true) or not pages[1].text:find("Owned:2", 1, true) then
    error("DexSeenOwnedText got " .. pages[1].text)
end
if pages[2].text ~= "POKéDEX Rating:" then
    error("DexRatingText got " .. pages[2].text)
end
if pages[3].text ~= EndgameStory.dexRating(2) then
    error("wDexRatingText is not the owned-count paragraph")
end
if pages[3].text ~= bands[1][3] then
    error("2 owned printed " .. pages[3].text)
end
for index, band in ipairs(bands) do
    for owned = band[1], band[2] do
        local got = EndgameStory.dexRating(owned)
        if got ~= band[3] then
            error("owned " .. owned .. " got " .. got)
        end
    end
end
if type(EndgameStory.hallPageLines) ~= "function" then
    local text = pages[3].text
    local count = 1
    for _ in text:gmatch("\n") do count = count + 1 end
    local bottom = 160 + count * 20
    error("wDexRatingText for 2 owned is one " .. count
        .. "-line drawText ending at y=" .. bottom
        .. "; the hall clip is 240, so the paragraph does not print")
end
local _, anchorY = EndgameStory.hallPixel(8, 13 * 8)
for _, band in ipairs(bands) do
    local placed = EndgameStory.hallPageLines(band[3])
    if placed[1].y ~= anchorY then
        error("rating lines moved off the label anchor")
    end
    for _, line in ipairs(placed) do
        if line.bottom >= 240 or line.y < 0 then
            error("rating line falls outside the hall clip: " .. line.text)
        end
        if line.text:find("_", 1, true) or line.text:find("*", 1, true) then
            error("rating line still carries drawText markup: " .. line.text)
        end
    end
end
print("hof-dex-rating ok")
"""


class HallDexRatingTests(unittest.TestCase):
    def test_rating_table_order_delays_and_visible_lines(self):
        band_literal = "{" + ",".join(
            "{" + str(lo) + "," + str(hi) + "," + lua_quote(text) + "}"
            for lo, hi, text in BANDS
        ) + "}"
        script = "bands = " + band_literal + "\nstory_path = " + lua_quote(str(STORY)) + "\n" + PROBE
        completed = subprocess.run(
            [lua_binary(), "-e", script],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn("hof-dex-rating ok", completed.stdout)
        draw = STORY.read_text(encoding="utf-8")
        photo = draw[draw.index("function EndgameStory.drawPhoto"):draw.index("function EndgameStory.drawOverlay")]
        self.assertIn("EndgameStory.hallPageLines(page.text)", photo)
        self.assertNotIn("gfx.drawText(page.text", photo)
        advance = draw[draw.index('kind == "player" and photo.clock > 120'):]
        self.assertIn("photo.clock > 120", advance[:80])
        self.assertIn("page >= 3", advance[:240])
        for _, _, text in BANDS:
            for line in text.split("\n"):
                self.assertIsNone(unescaped_markup(line), line)


if __name__ == "__main__":
    unittest.main()
