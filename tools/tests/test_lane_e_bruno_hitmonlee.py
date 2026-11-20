#!/usr/bin/env python3
"""Bruno's Hitmonlee must use its pokered moves, not Wide Guard.

pret/pokered af519899 gives Bruno one special-level team. Hitmonlee is the
third member at level 55. WriteMonMoves starts from DOUBLE KICK and MEDITATE
and keeps the last four level-up moves: JUMP KICK, FOCUS ENERGY, HI JUMP
KICK, and MEGA KICK. Wide Guard is not in data/moves/moves.asm, and no Gen 1
learnset or TM teaches it. The B2W2 learnset was still handing that slot
WIDE GUARD, a gap that prints "But it failed!" and deals no damage.
"""

import os
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REFERENCE = Path(os.environ["POKERED_REFERENCE_DIR"])
KEYS = {
    "DOUBLE_KICK": "doubleKick",
    "MEDITATE": "meditate",
    "ROLLING_KICK": "rollingKick",
    "JUMP_KICK": "jumpKick",
    "FOCUS_ENERGY": "focusEnergy",
    "HI_JUMP_KICK": "highJumpKick",
    "MEGA_KICK": "megaKick",
}
NAMES = {
    "jumpKick": "JUMP KICK",
    "focusEnergy": "FOCUS ENERGY",
    "highJumpKick": "HIGH JUMP KICK",
    "megaKick": "MEGA KICK",
}


def pokered_moves(level):
    base = Path(REFERENCE, "data/pokemon/base_stats/hitmonlee.asm").read_text(encoding="utf-8")
    learned = re.search(r"db\s+([A-Z_]+),\s+([A-Z_]+),\s+NO_MOVE", base)
    moves = [KEYS[learned.group(1)], KEYS[learned.group(2)]]
    body = Path(REFERENCE, "data/pokemon/evos_moves.asm").read_text(encoding="utf-8")
    block = body.split("HitmonleeEvosMoves:", 1)[1].split("HitmonchanEvosMoves:", 1)[0]
    for level_text, move in re.findall(r"db\s+(\d+),\s+([A-Z_]+)", block):
        if int(level_text) > level:
            break
        key = KEYS[move]
        if key in moves:
            continue
        if len(moves) == 4:
            moves.pop(0)
        moves.append(key)
    return moves


def party_moves():
    text = (ROOT / "Source/data/redPartyMoves.lua").read_text(encoding="utf-8")
    row = text.split('["pokered:BRUNOS_ROOM:objects:1"]', 1)[1]
    listed = re.search(r'hitmonlee = \{"([^"]+)", "([^"]+)", "([^"]+)", "([^"]+)"\}', row)
    return list(listed.groups())


class BrunoHitmonleeTests(unittest.TestCase):
    def test_level_55_uses_the_pokered_moves_and_their_effects(self):
        expected = pokered_moves(55)
        self.assertEqual(expected, ["jumpKick", "focusEnergy", "highJumpKick", "megaKick"])
        names = Path(REFERENCE, "data/moves/names.asm").read_text(encoding="utf-8")
        self.assertIn('li "HI JUMP KICK"', names)
        self.assertIn('li "JUMP KICK"', names)
        self.assertIn('li "FOCUS ENERGY"', names)
        self.assertIn('li "MEGA KICK"', names)
        self.assertEqual(party_moves(), expected)
        events = (ROOT / "Source/game/trainerEvents.lua").read_text(encoding="utf-8")
        self.assertIn("RedPartyMoves[value.definition.id]", events)
        self.assertIn("created:usePartyMoves(scripted)", events)
        moves = (ROOT / "Source/battle/moves.lua").read_text(encoding="utf-8")
        support = (ROOT / "Source/battle/moveSupport.lua").read_text(encoding="utf-8")
        for key, name in NAMES.items():
            body = moves.split(f"{key} = function()", 1)[1].split("end,", 1)[0]
            self.assertIn(f'name = "{name}"', body)
            self.assertNotIn(f"MoveSupport.gaps.{key}", support)
        self.assertIn('MoveSupport.handlers.jumpKick = "standard-damage"', support)
        self.assertIn('MoveSupport.handlers.highJumpKick = "standard-damage"', support)
        self.assertIn('MoveSupport.handlers.megaKick = "standard-damage"', support)
        self.assertIn('MoveSupport.handlers.focusEnergy = "engine-dsl"', support)
        self.assertIn('MoveSupport.gaps.wideGuard = "sideCondition, onTry, onHitSide, stallingMove"', support)
        self.assertNotIn("wideGuard", party_moves())
        pokemon = (ROOT / "Source/data/pokemon.lua").read_text(encoding="utf-8")
        chooser = pokemon.split("function Pokemon.initialMovesFor", 1)[1].split("\nfunction ", 1)[0]
        learning = pokemon.split("function Pokemon:gainXP", 1)[1].split("\nfunction ", 1)[0]
        self.assertIn('entry.move ~= "wideGuard"', chooser)
        self.assertIn('entry.move ~= "wideGuard"', learning)
        # The B2W2 FIFO at 55, before the skip and the party row, is the clip:
        # slot 1 is Wide Guard (Gen V 469). That row must not be what launches.
        raw = []
        for part in re.search(r'learnset = "([^"]+)"', pokemon.split("hitmonlee = {", 1)[1]).group(1).split(";"):
            move, level, _form, _gid = part.split("|")
            if int(level) > 55 or int(level) < 1:
                continue
            if move in raw:
                continue
            if len(raw) == 4:
                raw.pop(0)
            raw.append(move)
        self.assertEqual(raw, ["wideGuard", "blazeKick", "endure", "megaKick"])
        self.assertNotEqual(party_moves(), raw)
        self.assertNotIn("wideGuard", party_moves())


if __name__ == "__main__":
    unittest.main()
