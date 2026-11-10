#!/usr/bin/env python3
"""Decode the maps still absent from the 205-map manifest.

Diglett's Cave, Rock Tunnel and Route 2 are already installed. Unused
zero-size constants have no layout. Three COPY ids share another map's
header, and UndergroundPathRoute7Copy's header constant collides with
UndergroundPathRoute7. Those stay listed, not duplicated.
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
REMAINDER = (
    'PalletTown', 'RedsHouse1F', 'RedsHouse2F', 'BluesHouse', 'OaksLab',
    'ViridianSchoolHouse', 'ViridianNicknameHouse',
    'PewterNidoranHouse', 'PewterSpeechHouse',
    'CeruleanTradeHouse', 'CeruleanBadgeHouse',
    'PowerPlant',
    'CeruleanCave1F', 'CeruleanCave2F', 'CeruleanCaveB1F',
    'TradeCenter', 'Colosseum',
)
PACKAGE_FILES = (
    'dialogue.json', 'sprites.json', 'trainers.json', 'events.json',
    'scripts.json', 'reservations.json', 'manifest-entries.json', 'provenance.json',
)
KEEP_PREFIXES = tuple(name + '.json' for name in REMAINDER) + PACKAGE_FILES
# Header pointers in map_header_pointers.asm reuse an installed map.
HEADER_ALIASES = {
    'CERULEAN_TRASHED_HOUSE_COPY': 'CeruleanTrashedHouse',
    'UNDERGROUND_PATH_ROUTE_6_COPY': 'UndergroundPathRoute6',
    'CINNABAR_MART_COPY': 'CinnabarMart',
}
# Its header declares UNDERGROUND_PATH_ROUTE_7, the installed map's id.
DUPLICATE_HEADER = {
    'UNDERGROUND_PATH_ROUTE_7_COPY': 'UndergroundPathRoute7',
}
PRESENT = (
    'DiglettsCave', 'DiglettsCaveRoute2', 'DiglettsCaveRoute11',
    'RockTunnelPokecenter', 'RockTunnel1F', 'RockTunnelB1F',
    'Route2', 'Route2Gate', 'Route2TradeHouse',
    'ViridianForestNorthGate', 'ViridianForestSouthGate', 'ViridianForest',
)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def union_pins():
    pins = {}
    for packet in ('east', 'south', 'saffron', 'coast', 'endgame'):
        data = json.loads((ROOT / 'tools/references' / f'midgame-{packet}.json').read_bytes())
        if data['revision'] != REVISION:
            raise ValueError('midgame pin revision drift: ' + packet)
        for path, digest_value in data['files'].items():
            if pins.get(path, digest_value) != digest_value:
                raise ValueError('conflicting midgame pin: ' + path)
            pins[path] = digest_value
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


def classify(reference):
    constants = map_constants(Reference(reference))
    installed = json.loads((ROOT / 'Source/data/sourceMaps.json').read_bytes())['maps']
    present = {entry['id'].split(':', 1)[1] for entry in installed.values()}
    packet_ids = {constants_name(name, reference) for name in REMAINDER}
    # The inventory records the gap before this packet. A later check still
    # sees the same gap after the maps have been installed.
    base_present = present - packet_ids
    if len(base_present) != 205:
        raise ValueError('remainder packet is not the gap on the 205-map manifest')
    missing = [name for name in constants if name not in base_present]
    unused = [name for name in missing if constants[name]['width'] == 0 and constants[name]['height'] == 0]
    aliases = {name: HEADER_ALIASES[name] for name in missing if name in HEADER_ALIASES}
    duplicates = {name: DUPLICATE_HEADER[name] for name in missing if name in DUPLICATE_HEADER}
    accounted = set(unused) | set(aliases) | set(duplicates)
    playable = [name for name in missing if name not in accounted]
    expected = {constants_name(name, reference) for name in REMAINDER}
    if set(playable) != expected:
        raise ValueError('playable gap changed: ' + repr(sorted(set(playable) ^ expected)))
    for name in PRESENT:
        if name not in installed:
            raise ValueError('expected installed map is missing: ' + name)
    return {
        'schema': 1,
        'source_revision': REVISION,
        'constant_count': len(constants),
        'installed_before': len(base_present),
        'missing_constants': missing,
        'unused_zero_size': unused,
        'header_aliases': aliases,
        'duplicate_headers': duplicates,
        'already_present': list(PRESENT),
        'installed_by_this_packet': list(REMAINDER),
    }


def constants_name(header, reference=REFERENCE_DEFAULT):
    text = (Path(reference) / f'data/maps/headers/{header}.asm').read_text()
    match = re.search(r'map_header\s+\w+,\s+([A-Z0-9_]+),', text)
    if not match:
        raise ValueError('header constant missing: ' + header)
    return match[1]


def generate(reference):
    original_package = midgame.package
    original_proposal = midgame.proposal
    midgame.package = lambda packet: 'zRemainder' if packet == 'remainder' else original_package(packet)
    midgame.PACKETS['remainder'] = REMAINDER
    midgame.proposal = lambda *args, **kwargs: {}
    try:
        pins = union_pins()
        for name in REMAINDER:
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
                artifacts, consumed = midgame.build(reference, 'remainder', pins=pins)
                return artifacts, consumed, pins
            except (MapError, ValueError, FileNotFoundError) as error:
                relative = unpinned(error)
                if relative is None:
                    raise
                add_pin(pins, reference, relative)
        raise ValueError('remainder pin discovery did not settle')
    finally:
        midgame.package = original_package
        midgame.proposal = original_proposal
        midgame.PACKETS.pop('remainder', None)


def write_maps(artifacts, destination=ROOT):
    package = destination / 'Source/data/zRemainder'
    package.mkdir(parents=True, exist_ok=True)
    for name, raw in artifacts.items():
        if name not in KEEP_PREFIXES:
            continue
        (package / name).write_bytes(raw)
    entries = json.loads(artifacts['manifest-entries.json'])['maps']
    if set(entries) != set(REMAINDER):
        raise ValueError('remainder manifest inventory drift')
    installed = json.loads((ROOT / 'Source/data/sourceMaps.json').read_bytes())
    for name, entry in entries.items():
        current = installed['maps'].get(name)
        if current is None:
            continue
        for key, value in entry.items():
            if current.get(key) != value:
                raise ValueError('remainder map collides with an installed map: ' + name + ':' + key)
    return {'schema': 1, 'source_revision': REVISION, 'maps': entries}


def write_pin(consumed, destination=ROOT):
    pin = {
        'schema': 1,
        'revision': REVISION,
        'maps': list(REMAINDER),
        'files': {path: value for path, value in sorted(consumed.items())},
    }
    raw = (json.dumps(pin, indent=2, sort_keys=True) + '\n').encode()
    path = destination / 'tools/references/midgame-remainder.json'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)
    return raw


def write_inventory(reference, destination=ROOT):
    raw = canonical(classify(reference))
    path = destination / 'Source/data/zRemainder/inventory.json'
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
        raise SystemExit('remainder check failed:\n' + '\n'.join(mismatches))


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    check = '--check' in argv
    if check:
        argv.remove('--check')
    if len(argv) > 1:
        raise SystemExit('usage: generate_remainder_maps.py [--check] [pokered]')
    reference = Path(argv[0] if argv else REFERENCE_DEFAULT)
    inventory = classify(reference)
    artifacts, consumed, _pins = generate(reference)
    if check:
        with tempfile.TemporaryDirectory(prefix='remainder-maps-check-') as temporary:
            staging = Path(temporary)
            manifest = write_maps(artifacts, staging)
            write_pin(consumed, staging)
            write_inventory(reference, staging)
            compare(staging)
        print(f'remainder check ok, maps {len(manifest["maps"])}, consumed inputs {len(consumed)}')
        return
    manifest = write_maps(artifacts)
    write_pin(consumed)
    write_inventory(reference)
    print(f'Remainder maps {len(manifest["maps"])}, missing constants {len(inventory["missing_constants"])}, '
          f'consumed inputs {len(consumed)}')


if __name__ == '__main__':
    main()
