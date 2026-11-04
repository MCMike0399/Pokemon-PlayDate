#!/usr/bin/env python3
"""Compact Silph source scenes, door blocks, elevator entries and object toggles."""
import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.generate_kanto_maps import Reference, decode_map

REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
OUTPUT = ROOT / 'Source/data/silphStory'


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def global_block(source, label):
    tail = source.split(label + ':', 1)[1]
    end = re.search(r'^\w+::?', tail, re.M)
    return tail[:end.start()] if end else tail


def path(source, label):
    block = source.split(label + ':', 1)[1].split('db -1', 1)[0]
    return [d.lower() for d in re.findall(r'db NPC_MOVEMENT_(UP|DOWN|LEFT|RIGHT)', block)]


def build(reference):
    head = subprocess.check_output(['git', '-C', str(reference), 'rev-parse', 'HEAD'], text=True).strip()
    if head != REVISION:
        raise ValueError('exact pinned pokered reference required')
    sources, pins = {}, {}
    names = [f'SilphCo{floor}F' for floor in range(1, 12)] + ['SilphCoElevator']
    files = [f'{kind}/{name}.asm' for kind in ('scripts', 'data/maps/objects') for name in names]
    files += [f'data/maps/headers/{name}.asm' for name in names]
    files += ['gfx/blocksets/interior.bst', 'gfx/blocksets/facility.bst', 'engine/events/card_key.asm', 'engine/events/elevator.asm',
              'home/map_objects.asm', 'data/maps/toggleable_objects.asm', 'constants/toggle_constants.asm',
              'data/maps/objects/SaffronCity.asm', 'home/overworld.asm',
              'engine/overworld/player_state.asm', 'data/tilesets/door_tile_ids.asm',
              'data/tilesets/warp_tile_ids.asm', 'scripts/PokemonTower7F.asm']
    for name in files:
        raw = (reference / name).read_bytes()
        if raw != subprocess.check_output(['git', '-C', str(reference), 'show', f'{REVISION}:{name}']):
            raise ValueError('modified source: ' + name)
        sources[name] = raw if name.endswith('.bst') else raw.decode()
        pins[name] = hashlib.sha256(raw).hexdigest()
    doors = {}
    def keys(block, tileset):
        raw = sources[f'gfx/blocksets/{tileset.lower()}.bst']
        result = []
        for q in range(4):
            ids = [raw[block * 16 + (q // 2 * 2 + y) * 4 + q % 2 * 2 + x] for y in range(2) for x in range(2)]
            result.append(f'pokered:{tileset}:cell:' + '-'.join(f'{v:02x}' for v in ids))
        return result
    for floor in range(2, 12):
        name = f'SilphCo{floor}F'
        tileset = re.search(r'map_header\s+\w+,\s*\w+,\s*(\w+)',
                            sources[f'data/maps/headers/{name}.asm'])[1]
        source = sources[f'scripts/{name}.asm']
        label = re.search(r'^(SilphCo\d+F_?GateCallbackScript):', source, re.M)[1]
        callback = global_block(source, label)
        entries = re.findall(r'ld a, \$([0-9a-f]+).*?lb bc,\s*(\d+),\s*(\d+)', callback, re.S)
        flags = list(dict.fromkeys(re.findall(r'EVENT_SILPH_CO_\d+_UNLOCKED_DOOR\d*', callback)))
        assert len(entries) == len(flags) and 1 <= len(flags) <= 4
        records = []
        for index, ((block, y, x), flag) in enumerate(zip(entries, flags), 1):
            # Callback .GateCoordinates repeats block X,Y in dbmapcoord syntax.
            assert re.search(r'dbmapcoord\s+' + x + r',\s*' + y, source)
            closed, opened = int(block, 16), 3 if floor == 11 else 14
            records.append(dict(id=f'pokered:SILPH_CO_{floor}F:hidden_events:{1000 + index}',
                                flag=flag, map=name, x=int(x), y=int(y),
                                closed_block=closed, open_block=opened, closed_keys=keys(closed, tileset), open_keys=keys(opened, tileset)))
        doors[f'pokered:SILPH_CO_{floor}F'] = records
    elevator = []
    source = sources['scripts/SilphCoElevator.asm']
    for warp, floor in re.findall(r'db (\d+), SILPH_CO_(\d+)F', source):
        objects = sources[f'data/maps/objects/SilphCo{floor}F.asm']
        warps = re.findall(r'warp_event\s+(\d+),\s*(\d+),\s*(\w+),\s*(\d+)', objects)
        target = warps[int(warp)]
        assert target[2] == 'SILPH_CO_ELEVATOR'
        elevator.append(dict(floor=int(floor), map_id=f'pokered:SILPH_CO_{floor}F',
                             source_warp_byte=int(warp), destination=dict(x=int(target[0]), y=int(target[1]))))
    assert len(elevator) == 11
    rival = sources['scripts/SilphCo7F.asm']
    approaches = path(rival, '.RivalMovementUp')
    assert approaches == ['up'] * 4
    variants = []
    positions = set()
    # CheckCoords increments before matching: CoordIndex is ONE-based, despite
    # misleading script comments. First (3,2) gets four UP; second gets three.
    for y, approach, departure in [(2, approaches, path(rival, '.RivalExitRightMovement')),
                                    (3, approaches[1:], path(rival, '.RivalWalkAroundPlayerMovement'))]:
        x, ay = 3, 7
        positions.add((x, ay))
        for step in approach + departure:
            dx, dy = dict(up=(0,-1), down=(0,1), left=(-1,0), right=(1,0))[step]
            x, ay = x + dx, ay + dy
            positions.add((x, ay))
        assert (x, ay) == (5, 3)
        variants.append(dict(trigger=dict(x=3,y=y), approach=approach, departure=departure,
                             battle_pose=dict(x=3,y=y+1)))
    gio = sources['scripts/SilphCo11F.asm']
    assert path(gio, '.GiovanniMovement') == ['down'] * 3
    # Resolve the toggle constant -> object identity through matching source
    # table order. Never infer that object index equals the toggle suffix.
    toggle_ids = {}
    constants = sources['constants/toggle_constants.asm']
    states = sources['data/maps/toggleable_objects.asm']
    for map_constant in ['SAFFRON_CITY'] + [f'SILPH_CO_{i}F' for i in range(1,12)]:
        cm = re.search(r'toggle_consts_for ' + map_constant + r'\s*\n(.*?)(?=\n\s*toggle_consts_for|\Z)', constants, re.S)
        sm = re.search(r'toggleable_objects_for ' + map_constant + r'\s*\n(.*?)(?=\n\s*toggleable_objects_for|\Z)', states, re.S)
        if not cm:
            continue
        cs = re.findall(r'\bconst (TOGGLE_\w+)', cm[1])
        ss = re.findall(r'toggle_object_state (\w+),', sm[1])
        assert len(cs) == len(ss)
        name = 'SaffronCity' if map_constant == 'SAFFRON_CITY' else 'SilphCo' + map_constant.split('_')[-1]
        object_names = re.findall(r'const_export (\w+)', sources[f'data/maps/objects/{name}.asm'])
        for toggle, obj in zip(cs, ss):
            toggle_ids[toggle] = f'pokered:{map_constant}:objects:{object_names.index(obj)+1}'
    toggles = {}
    for mode, label in [('show', '.ShowToggleableObjectIDs'), ('hide', '.HideToggleableObjectIDs')]:
        block = gio.split(label + ':',1)[1].split('db -1',1)[0]
        toggles[mode] = [toggle_ids[t] for t in re.findall(r'db (TOGGLE_\w+)', block)]
    # Saffron has one earlier transition: rescuing Mr. Fuji hides the Rocket at
    # the Silph door (E) and reveals the sleeping Rocket (F). Silph completion
    # hides both. Read the exact predef pair, then require both ids in that later
    # hide list; object identity still comes from the pinned source toggle table.
    rescue = global_block(sources['scripts/PokemonTower7F.asm'], 'PokemonTower7FMrFujiText')
    assert re.search(r'SetEvent EVENT_RESCUED_MR_FUJI\b', rescue)
    for constant, predef in [('TOGGLE_SAFFRON_CITY_E', 'HideObject'),
                             ('TOGGLE_SAFFRON_CITY_F', 'ShowObject')]:
        assert re.search(r'ld a, ' + constant + r'\s*\n\s*ld \[wToggleableObjectIndex\], a\s*\n\s*predef ' + predef, rescue), constant
    fuji_rescue = dict(flag='EVENT_RESCUED_MR_FUJI', source='scripts/PokemonTower7F.asm',
                       hides=[toggle_ids['TOGGLE_SAFFRON_CITY_E']],
                       shows=[toggle_ids['TOGGLE_SAFFRON_CITY_F']])
    assert set(fuji_rescue['hides'] + fuji_rescue['shows']) <= set(toggles['hide'])
    scenes = dict(doors=doors, elevator=elevator, toggles=toggles, fuji_rescue=fuji_rescue,
                  rival=dict(id='pokered:SILPH_CO_7F:objects:9', origin=dict(x=3,y=7), variants=variants,
                             script_positions=[dict(x=x,y=y) for x,y in sorted(positions)],
                             rival_party_indices=dict(charmander=7,squirtle=8,bulbasaur=9)),
                  giovanni=dict(id='pokered:SILPH_CO_11F:objects:3', origin=dict(x=6,y=9),
                                approach=['down']*3, battle_pose=dict(x=6,y=12),
                                triggers=[dict(x=6,y=13,player_facing='up',actor_facing='down'),
                                          dict(x=7,y=12,player_facing='left',actor_facing='right')]))
    # Use the existing pinned map decoder for callback-only cells absent from
    # base layouts. Do not regenerate/reindex any installed decoded map.
    map_pins = json.loads((ROOT / 'tools/references/midgame-saffron.json').read_bytes())['files']
    ref = Reference(reference, map_pins)
    missing = {'pokered:FACILITY:cell:24-25-24-25', 'pokered:INTERIOR:cell:5d-5d-5e-5e'}
    tiles = []
    for name, block in [('SilphCo3F', 0x5f), ('SilphCo11F', 0x20)]:
        definition = decode_map(ref, name, extra_blocks=(block,))
        tiles.extend(grid for grid in definition['grids'] if grid['stable_id'] in missing)
    assert {grid['stable_id'] for grid in tiles} == missing and len(tiles) == 2
    # The unused LAST_MAP declaration is interior floor, not a trigger. The
    # source checks a standing door/warp tile, then (for INTERIOR) a map edge.
    # Retain the source event; shared owners must not turn it into a wall/door.
    raw11 = decode_map(ref, 'SilphCo11F')
    warp = raw11['events']['warps'][2]
    grid = raw11['grids'][raw11['tile_ids'][5][5] - 1]
    assert (warp['x'], warp['y'], grid['terrain']['foot_tile']) == (5, 5, 0x1f)
    assert not grid['terrain']['warp_tile'] and grid['terrain']['land_passable']
    assert 'dbw INTERIOR,' not in sources['data/tilesets/door_tile_ids.asm']
    assert 'cp SILPH_CO_11F' not in global_block(sources['home/overworld.asm'], 'ExtraWarpCheck')
    scenes['inert_warps'] = [dict(id=warp['id'], map='SilphCo11F', x=5, y=5,
        key=grid['stable_id'], foot_tile=0x1f,
        reason='INTERIOR has no door tiles; $1f is not a warp tile; (5,5) is not a map edge')]
    pins.update(ref.consumed)
    return {'tiles.json': encoded(dict(schema=1, source_revision=REVISION, grids=tiles)),
            'scenes.json': encoded(dict(schema=1,source_revision=REVISION,scenes=scenes)),
            'provenance.json': encoded(dict(schema=1,source_revision=REVISION,files=pins))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference',type=Path,required=True)
    parser.add_argument('--check',action='store_true')
    args = parser.parse_args()
    for name, raw in build(args.reference).items():
        target = OUTPUT/name
        if args.check:
            if not target.exists() or target.read_bytes() != raw:
                raise SystemExit('stale source scene: '+str(target))
        else:
            target.write_bytes(raw)


if __name__ == '__main__':
    main()
