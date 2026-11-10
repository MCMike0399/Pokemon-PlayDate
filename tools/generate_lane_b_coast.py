#!/usr/bin/env python3
"""Decode the lane-B coast from pinned pokered without rewriting installed maps.

Decoded maps live under Source/data/zCoast. This tool does not write
sourceMaps.json or the shared cell cache. Promotion installs the entries
and regenerates those with tools/generate_source_map_cache.py.
"""
import hashlib
import json
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.generate_kanto_maps import MapError, REVISION
import tools.generate_midgame_content as midgame
REFERENCE_DEFAULT = Path('/home/ubuntu/Developer/Pokemon-PlayDate-env/pokered')
COAST = (
    'Route19', 'Route20', 'Route21',
    'SeafoamIslands1F', 'SeafoamIslandsB1F', 'SeafoamIslandsB2F',
    'SeafoamIslandsB3F', 'SeafoamIslandsB4F',
    'CinnabarIsland', 'CinnabarPokecenter', 'CinnabarMart', 'CinnabarGym',
    'CinnabarLab', 'CinnabarLabTradeRoom', 'CinnabarLabMetronomeRoom',
    'CinnabarLabFossilRoom',
    'PokemonMansion1F', 'PokemonMansion2F', 'PokemonMansion3F', 'PokemonMansionB1F',
)
PACKAGE_FILES = (
    'dialogue.json', 'sprites.json', 'trainers.json', 'events.json',
    'scripts.json', 'reservations.json', 'manifest-entries.json', 'provenance.json',
)
KEEP_PREFIXES = tuple(name + '.json' for name in COAST) + PACKAGE_FILES


def sha(data):
    return hashlib.sha256(data).hexdigest()


def union_pins():
    pins = {}
    for packet in ('east', 'south', 'saffron'):
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
    midgame.package = lambda packet: 'zCoast' if packet == 'coast' else original_package(packet)
    midgame.PACKETS['coast'] = COAST
    midgame.proposal = lambda *args, **kwargs: {}
    try:
        pins = union_pins()
        for name in COAST:
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
        for relative in (
                'data/wild/maps/SeaRoutes.asm',
                'data/wild/maps/Route21.asm'):
            if (reference / relative).is_file():
                add_pin(pins, reference, relative)
        for _ in range(400):
            try:
                artifacts, consumed = midgame.build(reference, 'coast', pins=pins)
                return artifacts, consumed, pins
            except (MapError, ValueError, FileNotFoundError) as error:
                relative = unpinned(error)
                if relative is None:
                    raise
                add_pin(pins, reference, relative)
        raise ValueError('coast pin discovery did not settle')
    finally:
        midgame.package = original_package
        midgame.proposal = original_proposal
        midgame.PACKETS.pop('coast', None)


def write_maps(artifacts, destination=ROOT):
    package = destination / 'Source/data/zCoast'
    package.mkdir(parents=True, exist_ok=True)
    written = {}
    for name, raw in artifacts.items():
        if name.startswith('proposed-') or name not in KEEP_PREFIXES and not name.endswith('.json'):
            continue
        if name not in KEEP_PREFIXES:
            continue
        path = package / name
        path.write_bytes(raw)
        written[name] = sha(raw)
    entries = json.loads(artifacts['manifest-entries.json'])['maps']
    if set(entries) != set(COAST):
        raise ValueError('coast manifest inventory drift')
    installed = json.loads((ROOT / 'Source/data/sourceMaps.json').read_bytes())
    for name, entry in entries.items():
        current = installed['maps'].get(name)
        if current is None:
            continue
        for key, value in entry.items():
            if current.get(key) != value:
                raise ValueError('coast map collides with an installed map: ' + name + ':' + key)
    return {'schema': 1, 'source_revision': REVISION, 'maps': entries}


def write_pin(consumed, destination=ROOT):
    pin = {
        'schema': 1,
        'revision': REVISION,
        'maps': list(COAST),
        'files': {path: digest for path, digest in sorted(consumed.items())},
    }
    raw = (json.dumps(pin, indent=2, sort_keys=True) + '\n').encode()
    path = destination / 'tools/references/midgame-coast.json'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)
    return raw


def compare(staging):
    mismatches = []
    for path in sorted(staging.rglob('*')):
        if not path.is_file():
            continue
        relative = path.relative_to(staging)
        if relative.parts[:3] == ('Source', 'data', 'contentCache') or relative.as_posix() in {
                'Source/data/sourceMaps.json', 'tools/references/content-cache.json'}:
            mismatches.append('forbidden ' + relative.as_posix())
            continue
        live = ROOT / relative
        if not live.is_file():
            mismatches.append('missing ' + relative.as_posix())
        elif live.read_bytes() != path.read_bytes():
            mismatches.append('drift ' + relative.as_posix())
    if mismatches:
        raise SystemExit('coast check failed:\n' + '\n'.join(mismatches))


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    check = '--check' in argv
    if check:
        argv.remove('--check')
    if len(argv) > 1:
        raise SystemExit('usage: generate_lane_b_coast.py [--check] [pokered]')
    reference = Path(argv[0] if argv else REFERENCE_DEFAULT)
    artifacts, consumed, _pins = generate(reference)
    if check:
        with tempfile.TemporaryDirectory(prefix='lane-b-coast-check-') as temporary:
            staging = Path(temporary)
            manifest = write_maps(artifacts, staging)
            write_pin(consumed, staging)
            compare(staging)
        print(f'coast check ok, maps {len(manifest["maps"])}, consumed inputs {len(consumed)}')
        return
    manifest = write_maps(artifacts)
    write_pin(consumed)
    print(f'Coast maps {len(manifest["maps"])}, consumed inputs {len(consumed)}')


if __name__ == '__main__':
    main()
