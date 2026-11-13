"""Battle-menu and clip decisions for the lane B simulator driver.

The move list is already open when a Hyper Potion becomes the plan, and a
failed ffmpeg encode used to raise out of the fight before the save.
"""


def leave_move_menu_for_item(in_move_select, plan):
    """B leaves FIGHT's move list so the bag command can use the item."""
    return bool(in_move_select) and isinstance(plan, tuple) and len(plan) > 0 and plan[0] == 'item'


def battle_continues_after_clip(returncode):
    """A gray-clip encode never cancels the battle or the save after it."""
    del returncode
    return True
