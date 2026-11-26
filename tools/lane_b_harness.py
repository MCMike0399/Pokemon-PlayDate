"""Battle-menu and clip decisions for the lane B simulator driver.

The move list is already open when a Hyper Potion becomes the plan, and a
failed ffmpeg encode used to raise out of the fight before the save.

A harness `record` command holds its request open until every named frame
is stored, and the runtime accepts no other request until then. Recording
the whole clip on the first step leaves the player standing with no
buttons. Each live command is recorded only for the frames it consumes,
and the saved frames are ordered by chunk, then frame.
"""
import re
from pathlib import Path


def leave_move_menu_for_item(in_move_select, plan):
    """B leaves FIGHT's move list so the bag command can use the item."""
    return bool(in_move_select) and isinstance(plan, tuple) and len(plan) > 0 and plan[0] == 'item'


def battle_continues_after_clip(returncode):
    """A gray-clip encode never cancels the battle or the save after it."""
    del returncode
    return True


def command_span(commands):
    """Frames a harness request spends running these commands."""
    span = 0
    for command in commands:
        parts = str(command).split()
        if len(parts) >= 2 and parts[0] == 'wait' and parts[1].isdigit():
            span += int(parts[1])
        else:
            span += 1
    return span


def attach_record(commands, name, chunk, clip_left):
    """Prefix one live command with a record that ends when that input ends.

    The record count is the record command's own frame plus the frames the
    rest of the request consumes, and never more than the frames still owed
    to the clip. It is never the whole remaining clip, so the request cannot
    sit open after the buttons stop.
    """
    commands = [str(command) for command in commands]
    if clip_left <= 0:
        return commands, 0, clip_left
    take = min(command_span(commands) + 1, clip_left)
    recorded = [f'record {name}-{int(chunk):04d} {take}', *commands]
    if int(recorded[0].split()[-1]) > command_span(recorded):
        raise ValueError('record outlives the commands in its request')
    return recorded, take, clip_left - take


def clip_frames(folder, name):
    """Display frames in chunk order, ignoring lexicographic leftovers."""
    pattern = re.compile(rf'^{re.escape(name)}-(\d+)-(\d+)-display\.png$')
    found = []
    for path in Path(folder).glob(f'{name}-*-display.png'):
        match = pattern.match(path.name)
        if match:
            found.append((int(match.group(1)), int(match.group(2)), path))
    found.sort()
    return [path for _, _, path in found]
