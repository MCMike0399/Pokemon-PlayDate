#!/usr/bin/env python3
"""Decode the league maps from pinned pokered without rewriting installed maps.

Decoded maps live under Source/data/zEndgame. This tool does not write
sourceMaps.json. Promotion installs the entries and regenerates the shared
cache with tools/activate_endgame.py.
"""
import hashlib
import json
import re
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.generate_kanto_maps import MapError, REVISION, Reference, map_constants
from tools.generate_cerulean_content import canonical, digest
import tools.generate_midgame_content as midgame

REFERENCE_DEFAULT = Path('/home/ubuntu/Developer/Pokemon-PlayDate-env/pokered')
ENDGAME = (
    'ViridianGym', 'Route22Gate', 'Route23',
    'VictoryRoad1F', 'VictoryRoad2F', 'VictoryRoad3F',
    'IndigoPlateau', 'IndigoPlateauLobby',
    'LoreleisRoom', 'BrunosRoom', 'AgathasRoom', 'LancesRoom',
    'ChampionsRoom', 'HallOfFame',
)
PACKAGE_FILES = (
    'dialogue.json', 'sprites.json', 'trainers.json', 'events.json',
    'scripts.json', 'reservations.json', 'manifest-entries.json', 'provenance.json',
)
KEEP_PREFIXES = tuple(name + '.json' for name in ENDGAME) + PACKAGE_FILES


def sha(data):
    return hashlib.sha256(data).hexdigest()


def union_pins():
    pins = {}
    for packet in ('east', 'south', 'saffron', 'coast'):
        data = json.loads((ROOT / 'tools/references' / f'midgame-{packet}.json').read_bytes())
        if data['revision'] != REVISION:
            raise ValueError('midgame pin revision drift: ' + packet)
        for path, digest in data['files'].items():
            if pins.get(path, digest) != digest:
                raise ValueError('conflicting midgame pin: ' + path)
            pins[path] = digest
    return pins


def add_pin(pins, reference, relative):
    if relative in pins:
        return
    raw = (reference / relative).read_bytes()
    pins[relative] = sha(raw)


def unpinned(error):
    text = str(error)
    marker = 'unpinned consumed source: '
    if marker not in text:
        return None
    return text.split(marker, 1)[1].strip()


def generate(reference):
    original_package = midgame.package
    original_proposal = midgame.proposal
    midgame.package = lambda packet: 'zEndgame' if packet == 'endgame' else original_package(packet)
    midgame.PACKETS['endgame'] = ENDGAME
    midgame.proposal = lambda *args, **kwargs: {}
    try:
        pins = union_pins()
        for name in ENDGAME:
            for relative in (
                    f'data/maps/headers/{name}.asm',
                    f'data/maps/objects/{name}.asm',
                    f'scripts/{name}.asm',
                    f'maps/{name}.blk',
                    f'text/{name}.asm',
                    f'text/{name}_2.asm',
                    f'data/wild/maps/{name}.asm'):
                if (reference / relative).is_file():
                    add_pin(pins, reference, relative)
        for _ in range(400):
            try:
                artifacts, consumed = midgame.build(
                    reference, 'endgame', pins=pins,
                    ingress_map={'IndigoPlateauLobby': 'IndigoPlateau'})
                resolve_route22_gate(artifacts, reference)
                return artifacts, consumed, pins
            except (MapError, ValueError, FileNotFoundError) as error:
                relative = unpinned(error)
                if relative is None:
                    raise
                add_pin(pins, reference, relative)
        raise ValueError('endgame pin discovery did not settle')
    finally:
        midgame.package = original_package
        midgame.proposal = original_proposal
        midgame.PACKETS.pop('endgame', None)


def resolve_route22_gate(artifacts, reference):
    """The gate script selects the outdoor map from the player's y, then LAST_MAP uses it."""
    script = (Path(reference) / 'scripts/Route22Gate.asm').read_text()
    if not re.search(r'ld a, \[wYCoord\]\s+cp 4\s+ld a, ROUTE_23\s+jr c, \.set_last_map\s+ld a, ROUTE_22', script):
        raise ValueError('Route 22 gate last-map split changed')
    ids = map_constants(Reference(reference))
    data = json.loads(artifacts['Route22Gate.json'])
    changed = 0
    for warp in data['events']['warps']:
        destination = warp['destination']
        if destination.get('kind') != 'last_outdoor_map':
            continue
        target = 'ROUTE_23' if warp['y'] < 4 else 'ROUTE_22'
        warp['destination'] = {'kind': 'map', 'map': target, 'map_id': ids[target]['id'],
                               'warp_index': destination['warp_index'], 'resolved': False}
        changed += 1
    if changed != 4:
        raise ValueError('Route 22 gate outdoor warp count changed')
    raw = canonical(data)
    artifacts['Route22Gate.json'] = raw
    entries = json.loads(artifacts['manifest-entries.json'])
    entries['maps']['Route22Gate']['source_sha256'] = digest(raw)
    artifacts['manifest-entries.json'] = canonical(entries)
    contexts = json.loads(artifacts['contexts.json'])
    contexts['maps']['Route22Gate']['warps'] = data['events']['warps']
    artifacts['contexts.json'] = canonical(contexts)


def write_maps(artifacts, destination=ROOT):
    package = destination / 'Source/data/zEndgame'
    package.mkdir(parents=True, exist_ok=True)
    for name, raw in artifacts.items():
        if name not in KEEP_PREFIXES:
            continue
        (package / name).write_bytes(raw)
    entries = json.loads(artifacts['manifest-entries.json'])['maps']
    if set(entries) != set(ENDGAME):
        raise ValueError('endgame manifest inventory drift')
    installed = json.loads((ROOT / 'Source/data/sourceMaps.json').read_bytes())
    for name, entry in entries.items():
        current = installed['maps'].get(name)
        if current is None:
            continue
        for key, value in entry.items():
            if current.get(key) != value:
                raise ValueError('endgame map collides with an installed map: ' + name + ':' + key)
    return {'schema': 1, 'source_revision': REVISION, 'maps': entries}


def write_pin(consumed, destination=ROOT):
    pin = {
        'schema': 1,
        'revision': REVISION,
        'maps': list(ENDGAME),
        'files': {path: digest for path, digest in sorted(consumed.items())},
    }
    raw = (json.dumps(pin, indent=2, sort_keys=True) + '\n').encode()
    path = destination / 'tools/references/midgame-endgame.json'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)
    return raw


def compare(staging):
    mismatches = []
    for path in sorted(staging.rglob('*')):
        if not path.is_file():
            continue
        relative = path.relative_to(staging)
        live = ROOT / relative
        if not live.is_file():
            mismatches.append('missing ' + relative.as_posix())
        elif live.read_bytes() != path.read_bytes():
            mismatches.append('drift ' + relative.as_posix())
    if mismatches:
        raise SystemExit('endgame check failed:\n' + '\n'.join(mismatches))


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    check = '--check' in argv
    if check:
        argv.remove('--check')
    if len(argv) > 1:
        raise SystemExit('usage: generate_endgame_maps.py [--check] [pokered]')
    reference = Path(argv[0] if argv else REFERENCE_DEFAULT)
    artifacts, consumed, _pins = generate(reference)
    if check:
        with tempfile.TemporaryDirectory(prefix='endgame-maps-check-') as temporary:
            staging = Path(temporary)
            manifest = write_maps(artifacts, staging)
            write_pin(consumed, staging)
            compare(staging)
        print(f'endgame check ok, maps {len(manifest["maps"])}, consumed inputs {len(consumed)}')
        return
    manifest = write_maps(artifacts)
    write_pin(consumed)
    print(f'Endgame maps {len(manifest["maps"])}, consumed inputs {len(consumed)}')


if __name__ == '__main__':
    main()
