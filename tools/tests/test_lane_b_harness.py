#!/usr/bin/env python3
"""The Route 22 fight stays alive when a potion or a clip encode fails.

A clip records each live command for the frames that command consumes.
A 900-frame record around one step holds the harness request open and the
picture freezes. Saved frames stay in capture order, including the old
tail a later recording did not overwrite.
"""

import os
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from tools.lane_b_harness import (
    attach_record, battle_continues_after_clip, clip_frames, coherent_clip_frames,
    command_span, leave_move_menu_for_item, walk_allowed,
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
            names = (
                'victory-road-01-display.png',
                'victory-road-100-display.png',
                'victory-road-0002-01-display.png',
                'victory-road-0001-02-display.png',
                'victory-road-0001-10-display.png',
                'victory-road-0001-01-display.png',
            )
            for name in names:
                (folder / name).write_bytes(b'x')
            # One recording: capture time follows the chunk, not the write order above.
            for stamp, name in enumerate((
                'victory-road-0001-01-display.png',
                'victory-road-0001-02-display.png',
                'victory-road-0001-10-display.png',
                'victory-road-0002-01-display.png',
            ), start=1):
                os.utime(folder / name, (stamp, stamp))
            got = [path.name for path in clip_frames(folder, 'victory-road')]
        self.assertEqual(got, [
            'victory-road-0001-01-display.png',
            'victory-road-0001-02-display.png',
            'victory-road-0001-10-display.png',
            'victory-road-0002-01-display.png',
        ])

    def test_an_overwritten_chunk_plays_its_old_tail_before_the_new_frames(self):
        """A second record replaces frames 1 and 2. Frame 3 is the earlier tail."""
        with TemporaryDirectory() as tmp:
            folder = Path(tmp)
            names = {
                'elite-lorelei-0001-01-display.png': 2000,
                'elite-lorelei-0001-02-display.png': 2001,
                'elite-lorelei-0001-03-display.png': 1000,
                'elite-lorelei-0002-01-display.png': 1500,
            }
            for name, stamp in names.items():
                (folder / name).write_bytes(name.encode())
                os.utime(folder / name, (stamp, stamp))
            got = [path.name for path in clip_frames(folder, 'elite-lorelei')]
        self.assertEqual(got, [
            'elite-lorelei-0001-03-display.png',
            'elite-lorelei-0002-01-display.png',
            'elite-lorelei-0001-01-display.png',
            'elite-lorelei-0001-02-display.png',
        ])

    def test_a_recycled_chunk_plays_after_the_frames_it_did_not_replace(self):
        """A second pass reuses chunk 0001. The leftover higher chunk is older."""
        with TemporaryDirectory() as tmp:
            folder = Path(tmp)
            earlier = folder / 'elite-lorelei-0002-01-display.png'
            later_win = folder / 'elite-lorelei-0001-01-display.png'
            later_prize = folder / 'elite-lorelei-0001-02-display.png'
            earlier.write_bytes(b'confuse-ray')
            later_win.write_bytes(b'defeated')
            later_prize.write_bytes(b'prize')
            os.utime(earlier, (1000, 1000))
            os.utime(later_win, (2000, 2000))
            os.utime(later_prize, (2001, 2001))
            got = [path.name for path in clip_frames(folder, 'elite-lorelei')]
        self.assertEqual(got, [
            'elite-lorelei-0002-01-display.png',
            'elite-lorelei-0001-01-display.png',
            'elite-lorelei-0001-02-display.png',
        ])

    def test_stale_battle_bytes_do_not_return_after_the_map(self):
        battle = b'B' * 400
        torn = b'T' * 500
        got_away = b'G' * 300
        machop = b'M' * 180
        first_map = b'W' * 6000
        later_map = b'X' * 6100
        with TemporaryDirectory() as tmp:
            folder = Path(tmp)
            pictures = {
                'victory-road-0044-01-display.png': battle,
                'victory-road-0044-02-display.png': battle,
                'victory-road-0044-03-display.png': first_map,
                'victory-road-0045-01-display.png': battle,
                'victory-road-0045-02-display.png': torn,
                'victory-road-0045-03-display.png': later_map,
            'victory-road-0048-01-display.png': torn,
            'victory-road-0048-02-display.png': later_map,
            'victory-road-0048-03-display.png': b'I' * 500,
                'victory-road-0049-01-display.png': got_away,
                'victory-road-0049-02-display.png': machop,
                'victory-road-0050-01-display.png': got_away,
                'victory-road-0050-02-display.png': got_away,
                'victory-road-0051-01-display.png': got_away,
                'victory-road-0051-02-display.png': b'Z' * 6200,
            }
            for name, payload in pictures.items():
                (folder / name).write_bytes(payload)
            got = [path.name for path in coherent_clip_frames(folder, 'victory-road')]
        self.assertEqual(got, [
            'victory-road-0044-01-display.png',
            'victory-road-0044-02-display.png',
            'victory-road-0044-03-display.png',
            'victory-road-0045-03-display.png',
            'victory-road-0048-02-display.png',
            'victory-road-0048-03-display.png',
            'victory-road-0049-01-display.png',
            'victory-road-0049-02-display.png',
            'victory-road-0051-02-display.png',
        ])

    def test_a_real_battle_exit_keeps_its_last_battle_frames(self):
        battle = b'B' * 400
        ending = b'E' * 450
        field = b'W' * 6000
        with TemporaryDirectory() as tmp:
            folder = Path(tmp)
            for name, payload in {
                'victory-road-0028-01-display.png': battle,
                'victory-road-0029-01-display.png': ending,
                'victory-road-0029-02-display.png': field,
            }.items():
                (folder / name).write_bytes(payload)
            got = [path.name for path in coherent_clip_frames(folder, 'victory-road')]
        self.assertEqual(got, [
            'victory-road-0028-01-display.png',
            'victory-road-0029-01-display.png',
            'victory-road-0029-02-display.png',
        ])

    def test_walk_inputs_wait_until_the_battle_is_over(self):
        self.assertFalse(walk_allowed({'root': 'battle', 'battle': {
            'phase': 'script', 'outcome': 'ongoing'}}))
        self.assertFalse(walk_allowed({'root': 'overworld', 'battle': {
            'phase': 'command', 'outcome': 'ongoing', 'present': True}}))
        self.assertTrue(walk_allowed({'root': 'overworld', 'battle': {'present': False}}))
        self.assertTrue(walk_allowed({'root': 'overworld', 'battle': {
            'phase': 'ended', 'outcome': 'ran'}}))
        self.assertFalse(walk_allowed(None))


if __name__ == '__main__':
    unittest.main()
