#!/usr/bin/env python3
"""Faint text is on screen while the HP bar and sprite are still up.

20261119T145127Z shows "DROWZEE fainted!" with the confirm arrow at
46/69 and again at 26/69, sprite standing. 145428Z shows the same line
at 53/69, and "POLIWAG fainted!" at 20/28. 153952Z shows
"SANDSHREW fainted!" at 32/41 and 6/41, and "POLIWAG fainted!" at
24/28. Those lines are fully printed, not a typewriter frame.

A neutral KO says the fainted line in the same step the HP becomes 0.
The bar then steps by maxHP/30 under the text. Twenty slide frames do
not cover it: 180 of 200 is still about 47 after twenty steps of
200/30. The line has to wait until the displayed HP is 0.

Bellsprout looked finished in 153952Z because "It's super effective!"
stayed up for the whole 58-point drain, so the faint line was the next
page. That hold is not a gate.

Battle:_registerFaints says the line and only then presents the slide.
The patch presents first. It is not applied.
"""

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BATTLE = ROOT / 'Source/battle/battle.lua'
SCENE = ROOT / 'Source/battle/battleScene.lua'
PATCH = ROOT / 'tools/notes/lane-e-faint-order.patch'

# A large fraction of a high max HP. Twenty frames of maxHP/30 leave this
# bar well above 0, which is the Drowzee 60/69 case scaled up.
START_HP = 180
MAX_HP = 200


def faint_body(text):
    start = text.index('function Battle:_registerFaints')
    end = text.index('\nfunction Battle:_resolveFaintCheckpoint', start)
    return text[start:end]


def visual_event(text):
    start = text.index('function BattleScene:updateVisualEvent')
    end = text.index('\nfunction BattleScene:drawPresentedPokemon', start)
    return text[start:end]


def bar_after(start, maximum, frames):
    """The same step BattleScene:updateVitals uses."""
    shown = float(start)
    step = max(1.0, maximum / 30.0)
    for _ in range(frames):
        delta = 0.0 - shown
        shown += max(-step, min(step, delta))
    return shown


def faint_line_hp(body, scene):
    """HP still on the bar when the fainted line first becomes the message.

    say() before present() shows the line on the first drain frame.
    present() first holds on isVitalsBlocking() for the whole tween, then
    runs the 20-frame slide, and only then reaches say().
    """
    said = body.index('self:say(pokemon.name .. " fainted!")')
    shown = body.index('self:present("faint"')
    if said < shown:
        return START_HP
    gate = scene.index('if self:isVitalsBlocking() then')
    count = scene.index('self.presentationFrame = self.presentationFrame + 1')
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

    def test_live_source_prints_the_line_before_the_slide(self):
        body = faint_body(BATTLE.read_text())
        said = body.index('self:say(pokemon.name .. " fainted!")')
        shown = body.index('self:present("faint"')
        self.assertLess(said, shown)

    @unittest.expectedFailure
    def test_unpatched_battle_waits_for_a_large_drain(self):
        body = faint_body(BATTLE.read_text())
        scene = visual_event(SCENE.read_text())
        self.assertEqual(faint_line_hp(body, scene), 0)

    def test_patch_prints_the_line_after_the_bar_hits_zero(self):
        check = subprocess.run(
            ['git', 'apply', '--check', str(PATCH)], cwd=ROOT,
            capture_output=True, text=True)
        self.assertEqual(check.returncode, 0, check.stderr)
        copy = Path('/tmp/lane-e-faint-order-tree')
        if copy.exists():
            subprocess.check_call(['rm', '-rf', str(copy)])
        dest = copy / 'Source/battle/battle.lua'
        dest.parent.mkdir(parents=True)
        dest.write_bytes(BATTLE.read_bytes())
        applied = subprocess.run(
            ['patch', '-p1', '-d', str(copy), '-i', str(PATCH)],
            capture_output=True, text=True)
        self.assertEqual(applied.returncode, 0, applied.stdout + applied.stderr)
        body = faint_body(dest.read_text())
        scene = visual_event(SCENE.read_text())
        said = body.index('self:say(pokemon.name .. " fainted!")')
        shown = body.index('self:present("faint"')
        self.assertLess(shown, said)
        self.assertLess(body.index('isVitalsBlocking() is false'), said)
        self.assertLess(scene.index('if self:isVitalsBlocking() then'),
                        scene.index('self.presentationFrame = self.presentationFrame + 1'))
        self.assertEqual(faint_line_hp(body, scene), 0)
        self.assertGreater(bar_after(START_HP, MAX_HP, 20), 0)
        self.assertLess(
            faint_body(BATTLE.read_text()).index('self:say(pokemon.name .. " fainted!")'),
            faint_body(BATTLE.read_text()).index('self:present("faint"'))


if __name__ == '__main__':
    unittest.main()
