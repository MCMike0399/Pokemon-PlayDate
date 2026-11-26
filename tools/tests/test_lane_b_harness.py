#!/usr/bin/env python3
"""The Route 22 fight stays alive when a potion or a clip encode fails.

A clip records each live command for the frames that command consumes.
A 900-frame record around one step holds the harness request open and the
picture freezes. Saved frames are ordered by chunk, then frame.
"""

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from tools.lane_b_harness import (
    attach_record, battle_continues_after_clip, clip_frames, command_span,
    leave_move_menu_for_item,
)


class LaneBHarnessTest(unittest.TestCase):
    def test_item_plan_backs_out_of_the_move_list(self):
        plan = ('item', 'hyperPotion', 1)
        self.assertTrue(leave_move_menu_for_item(True, plan))
        self.assertFalse(leave_move_menu_for_item(False, plan))
        self.assertFalse(leave_move_menu_for_item(True, ('attack',)))

    def test_failed_clip_encode_does_not_abort_the_battle(self):
        self.assertTrue(battle_continues_after_clip(0))
        self.assertTrue(battle_continues_after_clip(243))
        self.assertTrue(battle_continues_after_clip(1))

    def test_one_step_is_not_held_open_for_the_rest_of_the_clip(self):
        self.assertEqual(command_span(['wait 8', 'press a', 'wait 6']), 15)
        commands, take, left = attach_record(
            ['press down', 'wait 18'], 'victory-road', 1, 900)
        self.assertEqual(commands, ['record victory-road-0001 20', 'press down', 'wait 18'])
        self.assertEqual(take, 20)
        self.assertEqual(left, 880)
        self.assertEqual(int(commands[0].split()[-1]), command_span(commands))
        nxt, take2, left2 = attach_record(['press up', 'wait 18'], 'victory-road', 2, left)
        self.assertEqual(nxt[0], 'record victory-road-0002 20')
        self.assertEqual(take2, 20)
        self.assertEqual(left2, 860)
        tail, taken, done = attach_record(['press a', 'wait 12'], 'elite-lorelei', 7, 4)
        self.assertEqual(tail[0], 'record elite-lorelei-0007 4')
        self.assertEqual(taken, 4)
        self.assertEqual(done, 0)
        self.assertLess(int(tail[0].split()[-1]), command_span(tail))

    def test_clip_frames_follow_chunk_order_not_lexicographic_names(self):
        with TemporaryDirectory() as tmp:
            folder = Path(tmp)
            for name in (
                'victory-road-01-display.png',
                'victory-road-100-display.png',
                'victory-road-0002-01-display.png',
                'victory-road-0001-02-display.png',
                'victory-road-0001-10-display.png',
                'victory-road-0001-01-display.png',
            ):
                (folder / name).write_bytes(b'x')
            got = [path.name for path in clip_frames(folder, 'victory-road')]
        self.assertEqual(got, [
            'victory-road-0001-01-display.png',
            'victory-road-0001-02-display.png',
            'victory-road-0001-10-display.png',
            'victory-road-0002-01-display.png',
        ])


if __name__ == '__main__':
    unittest.main()
