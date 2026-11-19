#!/usr/bin/env python3
"""The faint line waits until the HP drain and the slide finish."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BATTLE = ROOT / "Source/battle/battle.lua"
SCENE = ROOT / "Source/battle/battleScene.lua"
START_HP = 180
MAX_HP = 200


def faint_body(text):
    start = text.index("function Battle:_registerFaints")
    end = text.index("\nfunction Battle:_resolveFaintCheckpoint", start)
    return text[start:end]


def visual_event(text):
    start = text.index("function BattleScene:updateVisualEvent")
    end = text.index("\nfunction BattleScene:drawPresentedPokemon", start)
    return text[start:end]


def bar_after(start, maximum, frames):
    shown = float(start)
    step = max(1.0, maximum / 30.0)
    for _ in range(frames):
        delta = 0.0 - shown
        shown += max(-step, min(step, delta))
    return shown


def faint_line_hp(body, scene):
    said = body.index('self:say(pokemon.name .. " fainted!")')
    shown = body.index('self:present("faint"')
    if said < shown:
        return START_HP
    gate = scene.index("if self:isVitalsBlocking() then")
    count = scene.index("self.presentationFrame = self.presentationFrame + 1")
    if gate > count:
        return bar_after(START_HP, MAX_HP, 20)
    shown_hp = START_HP
    frames = 0
    while shown_hp != 0:
        shown_hp = bar_after(shown_hp, MAX_HP, 1)
        frames += 1
        if frames > 1000:
            break
    return shown_hp


class FaintOrderTests(unittest.TestCase):
    def test_a_fixed_slide_does_not_finish_a_large_drain(self):
        self.assertGreater(bar_after(START_HP, MAX_HP, 20), 0)

    def test_the_line_waits_until_the_bar_hits_zero(self):
        body = faint_body(BATTLE.read_text())
        scene = visual_event(SCENE.read_text())
        said = body.index('self:say(pokemon.name .. " fainted!")')
        shown = body.index('self:present("faint"')
        self.assertLess(shown, said)
        self.assertLess(body.index("isVitalsBlocking() is false"), said)
        self.assertLess(
            scene.index("if self:isVitalsBlocking() then"),
            scene.index("self.presentationFrame = self.presentationFrame + 1"),
        )
        self.assertEqual(faint_line_hp(body, scene), 0)


if __name__ == "__main__":
    unittest.main()
