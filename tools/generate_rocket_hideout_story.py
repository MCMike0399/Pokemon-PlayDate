#!/usr/bin/env python3
"""Decode pinned Blue story inputs outside Git; emit only compact scene data."""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
OUTPUT = ROOT / 'Source/data/rocketHideoutStory'
FILES = [f'scripts/RocketHideoutB{n}F.asm' for n in range(1, 5)] + [
    'scripts/RocketHideoutElevator.asm', 'scripts/GameCorner.asm',
    'engine/overworld/spinners.asm', 'home/map_objects.asm', 'engine/events/elevator.asm',
    'gfx/blocksets/facility.bst', 'gfx/blocksets/lobby.bst',
] + [f'data/maps/objects/{name}.asm' for name in (
    'RocketHideoutB1F', 'RocketHideoutB2F', 'RocketHideoutB3F',
    'RocketHideoutB4F', 'RocketHideoutElevator', 'GameCorner')]


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def read(reference):
    head = subprocess.check_output(['git', '-C', str(reference), 'rev-parse', 'HEAD'], text=True).strip()
    if head != REVISION:
        raise ValueError('reference must be exact pinned pokered revision')
    result, pins = {}, {}
    for name in FILES:
        raw = (reference / name).read_bytes()
        canonical = subprocess.check_output(['git', '-C', str(reference), 'show', f'{REVISION}:{name}'])
        if raw != canonical:
            raise ValueError('modified reference input: ' + name)
        pins[name] = hashlib.sha256(raw).hexdigest()
        result[name] = raw if name.endswith('.bst') else raw.decode()
    return result, pins


def build(reference):
    sources, pins = read(reference)
    routes = {}
    for floor, count in ((2, 43), (3, 16)):
        source = sources[f'scripts/RocketHideoutB{floor}F.asm']
        rows = re.findall(r'map_coord_movement\s+(\d+),\s*(\d+),\s*(\w+)', source)
        assert len(rows) == count
        decoded = []
        for index, (x, y, label) in enumerate(rows, 1):
            block = source.split(label + ':', 1)[1].split('db -1', 1)[0]
            pairs = re.findall(r'db PAD_(UP|DOWN|LEFT|RIGHT),\s*(\d+)', block)
            path = []
            for direction, length in reversed(pairs):
                path.extend([direction.lower()] * int(length))
            assert 0 < len(path) <= 64
            decoded.append(dict(id=f'pokered:ROCKET_HIDEOUT_B{floor}F:hidden_events:{index}',
                                x=int(x), y=int(y), path=path, source_label=label))
        routes[f'pokered:ROCKET_HIDEOUT_B{floor}F'] = decoded
    # These are source 1-based warp numbers, NOT object list indices.
    floors = []
    elevator = sources['scripts/RocketHideoutElevator.asm']
    warps = re.findall(r'db (\d+), ROCKET_HIDEOUT_B(\d)F', elevator)
    assert warps == [('4', '1'), ('4', '2'), ('2', '4')]
    for warp, floor in warps:
        objects = sources[f'data/maps/objects/RocketHideoutB{floor}F.asm']
        entries = re.findall(r'warp_event\s+(\d+),\s*(\d+),\s*(\w+),\s*(\d+)', objects)
        # Elevator menu copies the zero-based warp byte into both cabin exits.
        candidates = [(i, int(x), int(y)) for i, (x, y, target, _) in enumerate(entries, 1)
                      if target == 'ROCKET_HIDEOUT_ELEVATOR']
        assert len(candidates) == 2
        floors.append(dict(floor='B' + floor + 'F', map_id='pokered:ROCKET_HIDEOUT_B' + floor + 'F',
                           source_warp_byte=int(warp), destination=dict(x=int(entries[int(warp)][0]), y=int(entries[int(warp)][1])), exits=[dict(warp=i, x=x, y=y) for i, x, y in candidates]))
    terrain = {}
    for name, map_name, tileset, blockset, x, y, block in (
        ('entrance-closed', 'GameCorner', 'LOBBY', 'lobby', 8, 2, 0x2a),
        ('entrance-open', 'GameCorner', 'LOBBY', 'lobby', 8, 2, 0x43),
        ('b1-closed', 'RocketHideoutB1F', 'FACILITY', 'facility', 12, 8, 0x54),
        ('b1-open', 'RocketHideoutB1F', 'FACILITY', 'facility', 12, 8, 0x0e),
        ('b4-closed', 'RocketHideoutB4F', 'FACILITY', 'facility', 12, 5, 0x2d),
        ('b4-open', 'RocketHideoutB4F', 'FACILITY', 'facility', 12, 5, 0x0e),
    ):
        raw = sources[f'gfx/blocksets/{blockset}.bst']
        keys = []
        for quadrant in range(4):
            qx, qy = quadrant % 2, quadrant // 2
            ids = [raw[block * 16 + (qy * 2 + dy) * 4 + qx * 2 + dx]
                   for dy in range(2) for dx in range(2)]
            keys.append('pokered:' + tileset + ':cell:' + '-'.join(f'{v:02x}' for v in ids))
        terrain[name] = dict(map=map_name, block=block, x=x, y=y, keys=keys)
    corner = sources['scripts/GameCorner.asm']
    guard_paths = {}
    positions = set()
    for name, label in [('direct', 'GameCornerMovement_Rocket_WalkDirect'), ('around', 'GameCornerMovement_Rocket_WalkAroundPlayer')]:
        block = corner.split(label + ':', 1)[1].split('db -1', 1)[0]
        path = [d.lower() for d in re.findall(r'db NPC_MOVEMENT_(UP|DOWN|LEFT|RIGHT)', block)]
        guard_paths[name] = path
        x, y = 9, 5
        positions.add((x, y))
        for direction in path:
            dx, dy = dict(up=(0,-1), down=(0,1), left=(-1,0), right=(1,0))[direction]
            x, y = x + dx, y + dy
            positions.add((x,y))
    scenes = dict(spinners=routes, elevator=floors, terrain=terrain,
                  guard=dict(paths=guard_paths, script_positions=[dict(x=x,y=y) for x,y in sorted(positions)]))
    return {'scenes.json': encoded(dict(schema=1, source_revision=REVISION, scenes=scenes)),
            'provenance.json': encoded(dict(schema=1, source_revision=REVISION, files=pins))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    for name, value in build(args.reference).items():
        path = OUTPUT / name
        if args.check:
            if not path.exists() or path.read_bytes() != value:
                raise SystemExit('stale generated scene: ' + str(path))
        else:
            path.write_bytes(value)


if __name__ == '__main__':
    main()
