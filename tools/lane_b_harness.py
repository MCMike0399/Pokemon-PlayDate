"""Battle-menu and clip decisions for the lane B simulator driver.

The move list is already open when a Hyper Potion becomes the plan, and a
failed ffmpeg encode used to raise out of the fight before the save.

A harness `record` command holds its request open until every named frame
is stored, and the runtime accepts no other request until then. Recording
the whole clip on the first step leaves the player standing with no
buttons. Each live command is recorded only for the frames it consumes,
and the saved frames stay in capture order. A later recording of the
same name overwrites the low frame numbers of a chunk and leaves the
old tail on disk. That tail is an earlier segment, not the end of the
new chunk.
"""
import re
import subprocess
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

    One ``record`` writes a chunk as frames 1..N, in that order. The next
    recording of the same name starts again at frame 1 and overwrites only
    as many files as it captures. The previous recording's higher frame
    numbers stay on disk with their old write times, so a sort of every
    file by time plays the tail of an old chunk in the middle of the new
    one. A drop in write time as the frame number increases is that leftover
    tail. It is its own earlier segment. Inside a segment the frame number
    is the order, and the segments play by the time they were captured.
    """
    pattern = re.compile(rf'^{re.escape(name)}-(\d+)-(\d+)-display\.png$')
    by_chunk = {}
    for path in Path(folder).glob(f'{name}-*-display.png'):
        match = pattern.match(path.name)
        if path.name.endswith('-display.png') and match:
            by_chunk.setdefault(int(match.group(1)), []).append(
                (int(match.group(2)), path.stat().st_mtime_ns, path))
    segments = []
    for chunk, items in by_chunk.items():
        items.sort()
        current = [items[0]]
        for frame, mtime, path in items[1:]:
            if mtime < current[-1][1]:
                segments.append((chunk, current))
                current = []
            current.append((frame, mtime, path))
        segments.append((chunk, current))
    segments.sort(key=lambda item: (item[1][0][1], item[0], item[1][0][0]))
    return [path for _, segment in segments for _, _, path in segment]


def encode_clip(frames, target):
    """Write every frame, in the given order, as a 30fps gray game screen.

    The concat demuxer presents these PNGs at 25fps and drops the ones that
    miss a tick, so a continuous recording has to be an image sequence at
    the capture rate.
    """
    frames = [Path(frame) for frame in frames]
    target = Path(target)
    if not frames:
        raise ValueError('encode_clip requires frames')
    sequence = target.parent / f'.{target.stem}-frames'
    if sequence.exists():
        for child in sequence.iterdir():
            child.unlink()
    else:
        sequence.mkdir(parents=True)
    for index, frame in enumerate(frames, start=1):
        link = sequence / f'f{index:05d}.png'
        if link.exists() or link.is_symlink():
            link.unlink()
        link.symlink_to(frame)
    command = [
        'ffmpeg', '-y', '-framerate', '30', '-i', str(sequence / 'f%05d.png'),
        '-vf', "lutrgb=r='gte(val\\,128)*255':g='gte(val\\,128)*255':b='gte(val\\,128)*255',format=gray",
        '-c:v', 'libx264', '-crf', '0', '-pix_fmt', 'gray', str(target),
    ]
    done = subprocess.run(command, capture_output=True, text=True)
    for child in sequence.iterdir():
        child.unlink()
    sequence.rmdir()
    if done.returncode != 0 or not target.exists():
        raise RuntimeError((done.stderr or 'ffmpeg failed')[-400:])
    return target


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
