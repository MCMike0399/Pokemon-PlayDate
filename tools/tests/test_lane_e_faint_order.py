#!/usr/bin/env python3
"""Faint text is on screen while the HP bar and sprite are still up.

20261119T144452Z-route22-rival.mp4 at about 8s shows "DROWZEE fainted!"
with the bar at 60/69 and the sprite standing. Sandshrew is the same
near 15s, still on its feet at 5/41. The 144824Z retake shows the
Poliwag line at 12/28 with the sprite still on the platform. pokered
drains the bar to 0, slides the picture down, then prints the line.

Battle:_registerFaints says the line and only then presents the slide.
say() parks the script on the message immediately, and updateVitals
keeps stepping the bar underneath it. The patch is not applied.
"""

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BATTLE = ROOT / 'Source/battle/battle.lua'
PATCH = ROOT / 'tools/notes/lane-e-faint-order.patch'


def faint_body(text):
    start = text.index('function Battle:_registerFaints')
    end = text.index('\nfunction Battle:_resolveFaintCheckpoint', start)
    return text[start:end]


class FaintOrderTests(unittest.TestCase):
    def test_live_source_prints_the_line_before_the_slide(self):
        body = faint_body(BATTLE.read_text())
        said = body.index('self:say(pokemon.name .. " fainted!")')
        shown = body.index('self:present("faint"')
        self.assertLess(said, shown)

    @unittest.expectedFailure
    def test_unpatched_battle_slides_before_the_faint_line(self):
        body = faint_body(BATTLE.read_text())
        said = body.index('self:say(pokemon.name .. " fainted!")')
        shown = body.index('self:present("faint"')
        self.assertLess(shown, said)

    def test_patch_prints_the_line_after_the_slide(self):
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
        said = body.index('self:say(pokemon.name .. " fainted!")')
        shown = body.index('self:present("faint"')
        self.assertLess(shown, said)
        self.assertLess(body.index('SlideDownFaintedMonPic'), said)
        self.assertLess(faint_body(BATTLE.read_text()).index('self:say(pokemon.name .. " fainted!")'),
                        faint_body(BATTLE.read_text()).index('self:present("faint"'))


if __name__ == '__main__':
    unittest.main()
