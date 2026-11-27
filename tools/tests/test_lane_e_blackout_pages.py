#!/usr/bin/env python3
"""_PlayerBlackedOutText2 is two pages, and "out!" shares the second.

pret/pokered af519899 data/text/text_2.asm:

    text "<PLAYER> is out of"
    line "useable #MON!"
    para "<PLAYER> blacked"
    line "out!"

Dialog.paginate (home/text.asm PrintText, fidelity ledger dialog row) puts
a paragraph on a new page and a line on the second row of that page. The
defeat string joins the paragraphs with a blank line. That empty row fills
the box, so "RED blacked" is one page and "out!" is the next page alone.
"""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REFERENCE = ROOT / "tools/references/vermilion-story/data/text/text_2.asm"


def lua_unescape(text):
    out = []
    index = 0
    while index < len(text):
        if text[index] == "\\" and index + 1 < len(text):
            code = text[index + 1]
            out.append({"n": "\n", "f": "\f", "\\": "\\"}.get(code, "\\" + code))
            index += 2
        else:
            out.append(text[index])
            index += 1
    return "".join(out)


def paginate(text):
    """The two-row rule in Source/ui/dialog.lua Dialog.paginate."""
    pages = []

    def emit(rows):
        if rows:
            pages.append("\n".join(rows))

    paragraphs = text.split("\f")
    if text.endswith("\f"):
        paragraphs = paragraphs[:-1]
    for paragraph in paragraphs:
        rows = []

        def push(row):
            nonlocal rows
            if len(rows) == 2:
                emit(rows)
                rows = []
            rows.append(row)

        for hard in paragraph.split("\n"):
            push(hard)
        emit(rows)
    return pages or [""]


class BlackoutPageTests(unittest.TestCase):
    def test_blackout_paragraphs_match_player_blacked_out_text(self):
        source = REFERENCE.read_text()
        block = source.split("_PlayerBlackedOutText2::", 1)[1].split("_LinkBattleLostText::", 1)[0]
        self.assertIn('text "<PLAYER> is out of"', block)
        self.assertIn('line "useable #MON!"', block)
        self.assertLess(block.index("para"), block.index('line "out!"'))
        self.assertIn('para "<PLAYER> blacked"', block)
        self.assertIn('line "out!"', block)

        battle = (ROOT / "Source/battle/battle.lua").read_text()
        branch = battle.split("if not playerTeamAlive then", 1)[1].split('return "defeat"', 1)[0]
        match = re.search(
            r'self\.message = playerName \.\. "((?:\\.|[^"\\])*)"\s*'
            r'\.\.\s*playerName \.\. "((?:\\.|[^"\\])*)"',
            branch,
        )
        self.assertIsNotNone(match, branch)
        text = "RED" + lua_unescape(match.group(1)) + "RED" + lua_unescape(match.group(2))
        self.assertEqual(
            paginate(text),
            [
                "RED is out of\nuseable POKéMON!",
                "RED blacked\nout!",
            ],
        )


if __name__ == "__main__":
    unittest.main()
