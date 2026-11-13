#!/usr/bin/env python3
"""The Route 22 fight stays alive when a potion or a clip encode fails."""

import unittest

from tools.lane_b_harness import battle_continues_after_clip, leave_move_menu_for_item


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


if __name__ == '__main__':
    unittest.main()
