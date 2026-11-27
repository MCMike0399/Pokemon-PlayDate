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
    """Display frames in capture order.

    Chunk numbers are only the order inside one recording. A later recording
    of the same name starts again at chunk 1 and leaves the previous
    recording's higher chunks on disk. Those older files sort after the new
    prefix when the key is the chunk number, so the win plays first and the
    earlier turns follow it. The write time is the capture order: an
    overwritten chunk is newer than the tail it did not replace.
    """
    pattern = re.compile(rf'^{re.escape(name)}-(\d+)-(\d+)-display\.png$')
    found = []
    for path in Path(folder).glob(f'{name}-*-display.png'):
        match = pattern.match(path.name)
        if path.name.endswith('-display.png') and match:
            found.append((path.stat().st_mtime_ns, int(match.group(1)), int(match.group(2)), path))
    found.sort()
    return [path for _, _, _, path in found]


def _chunk_groups(frames):
    groups = []
    current = None
    last = None
    for path in frames:
        match = re.search(r'-(\d+)-(\d+)-display\.png$', path.name)
        chunk = int(match.group(1)) if match else 0
        if chunk != last:
            current = []
            groups.append(current)
            last = chunk
        current.append(path)
    return groups


def _scene_class(path):
    """Map tiles are the large frames. Battle text and torn battle buffers are smaller."""
    return 'map' if path.stat().st_size >= 6000 else 'battle'


def coherent_clip_frames(folder, name):
    """Drop a chunk's leading frames when they revive a scene that chunk already left.

    Each recorded command screenshots the working image. After a battle the
    next command's first frames can still hold the previous battle, including
    a byte-for-byte copy of a frame the previous command had already moved
    past, and then the real map. A frame that repeats one of those abandoned
    images, or a leading battle run on a command that starts and ends on the
    map, is not a second live scene.
    """
    groups = _chunk_groups(clip_frames(folder, name))
    superseded = set()
    last_class = None
    kept = []
    for group in groups:
        digest = [path.read_bytes() for path in group]
        classes = [_scene_class(path) for path in group]
        start = 0
        while start < len(group) and digest[start] in superseded:
            start += 1
        # A command that was already on the map can still open with a torn
        # battle buffer and only reach the map partway through. Drop that
        # prefix. A battle that is still underway stays, because the previous
        # command ended on the battle and these frames match it.
        if last_class is not None and last_class in classes[start:]:
            while start < len(group) and classes[start] != last_class:
                start += 1
        chosen = group[start:]
        kept.extend(chosen)
        final = digest[-1]
        for picture in digest:
            if picture != final:
                superseded.add(picture)
        if chosen:
            last_class = _scene_class(chosen[-1])
    return kept


def walk_allowed(state):
    """A direction while a battle is still ongoing steps the player and can roll an encounter."""
    if not isinstance(state, dict) or state.get('root') != 'overworld':
        return False
    battle = state.get('battle') or {}
    if battle.get('present') is False or not battle.get('phase'):
        return True
    return battle.get('phase') == 'ended' or battle.get('outcome') not in (None, 'ongoing')
