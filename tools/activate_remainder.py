#!/usr/bin/env python3
"""Install the regenerated remainder packet on the 205-map manifest."""
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.activate_endgame import manifest as endgame
from tools.generate_source_map_cache import canonical

REMAINDER = (
    'PalletTown', 'RedsHouse1F', 'RedsHouse2F', 'BluesHouse', 'OaksLab',
    'ViridianSchoolHouse', 'ViridianNicknameHouse',
    'PewterNidoranHouse', 'PewterSpeechHouse',
    'CeruleanTradeHouse', 'CeruleanBadgeHouse',
    'PowerPlant',
    'CeruleanCave1F', 'CeruleanCave2F', 'CeruleanCaveB1F',
    'TradeCenter', 'Colosseum',
)


def manifest(project=ROOT):
    installed = endgame(project)
    raw = (Path(project) / 'Source/data/zRemainder/manifest-entries.json').read_bytes()
    packet = json.loads(raw)
    entries = packet['maps']
    if (packet.get('source_revision') != installed['source_revision']
            or len(installed['maps']) != 205 or set(entries) != set(REMAINDER)
            or set(entries) & set(installed['maps'])):
        raise ValueError('remainder packet is not 17 new maps on the 205-map manifest')
    for name, entry in entries.items():
        body = (Path(project) / 'Source' / entry['path']).read_bytes()
        if hashlib.sha256(body).hexdigest() != entry['source_sha256']:
            raise ValueError('remainder map bytes differ from the manifest pin: ' + name)
        if entry['id'] != 'pokered:' + json.loads(body)['source_map_constant']:
            raise ValueError('remainder map id differs from its decoded constant: ' + name)
    installed['maps'].update(entries)
    if len(installed['maps']) != 222:
        raise ValueError('remainder install is not 222 maps')
    plant = json.loads((Path(project) / 'Source/data/zRemainder/PowerPlant.json').read_bytes())
    cave = json.loads((Path(project) / 'Source/data/zRemainder/CeruleanCaveB1F.json').read_bytes())
    zapdos = [row for row in plant['events']['objects'] if row['extra'][:1] == ['ZAPDOS']]
    mewtwo = [row for row in cave['events']['objects'] if row['extra'][:1] == ['MEWTWO']]
    if len(zapdos) != 1 or (zapdos[0]['x'], zapdos[0]['y'], zapdos[0]['extra'][1]) != (4, 9, '50'):
        raise ValueError('Power Plant Zapdos is not the source object')
    if len(mewtwo) != 1 or (mewtwo[0]['x'], mewtwo[0]['y'], mewtwo[0]['extra'][1]) != (27, 13, '70'):
        raise ValueError('Cerulean Cave Mewtwo is not the source object')
    return installed


def write(path, project=ROOT):
    Path(path).write_bytes(canonical(manifest(project)))


if __name__ == '__main__':
    destination = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'Source/data/sourceMaps.json'
    write(destination)
    print('Installed 222 source maps: endgame 205 plus 17 remainder maps.')
