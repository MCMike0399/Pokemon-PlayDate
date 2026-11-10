#!/usr/bin/env python3
"""Install the regenerated coast packet on the checkpoint C manifest."""
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.activate_checkpoint_c import manifest as checkpoint_c
from tools.generate_source_map_cache import canonical

COAST = (
    'Route19', 'Route20', 'Route21',
    'SeafoamIslands1F', 'SeafoamIslandsB1F', 'SeafoamIslandsB2F',
    'SeafoamIslandsB3F', 'SeafoamIslandsB4F',
    'CinnabarIsland', 'CinnabarPokecenter', 'CinnabarMart', 'CinnabarGym',
    'CinnabarLab', 'CinnabarLabTradeRoom', 'CinnabarLabMetronomeRoom',
    'CinnabarLabFossilRoom',
    'PokemonMansion1F', 'PokemonMansion2F', 'PokemonMansion3F', 'PokemonMansionB1F',
)


def manifest(project=ROOT):
    installed = checkpoint_c(project)
    raw = (Path(project) / 'Source/data/zCoast/manifest-entries.json').read_bytes()
    packet = json.loads(raw)
    entries = packet['maps']
    if (packet.get('source_revision') != installed['source_revision']
            or len(installed['maps']) != 171 or set(entries) != set(COAST)
            or set(entries) & set(installed['maps'])):
        raise ValueError('coast packet is not 20 new maps on the 171-map manifest')
    for name, entry in entries.items():
        body = (Path(project) / 'Source' / entry['path']).read_bytes()
        if hashlib.sha256(body).hexdigest() != entry['source_sha256']:
            raise ValueError('coast map bytes differ from the manifest pin: ' + name)
        if entry['id'] != 'pokered:' + json.loads(body)['source_map_constant']:
            raise ValueError('coast map id differs from its decoded constant: ' + name)
    installed['maps'].update(entries)
    if len(installed['maps']) != 191:
        raise ValueError('coast install is not 191 maps')
    route19 = json.loads((Path(project) / 'Source/data/zCoast/Route19.json').read_bytes())
    fuchsia = json.loads((Path(project) / 'Source/data/midgameSouth/FuchsiaCity.json').read_bytes())
    south = [row for row in fuchsia['connections'] if row['direction'] == 'south']
    north = [row for row in route19['connections'] if row['direction'] == 'north']
    if (len(south) != 1 or south[0]['target_map'] != 'ROUTE_19'
            or len(north) != 1 or north[0]['target_map'] != 'FUCHSIA_CITY'):
        raise ValueError('Fuchsia south / Route 19 north connection is not the source pair')
    return installed


def write(path, project=ROOT):
    Path(path).write_bytes(canonical(manifest(project)))


if __name__ == '__main__':
    destination = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'Source/data/sourceMaps.json'
    write(destination)
    print('Installed 191 source maps: checkpoint C 171 plus 20 coast maps.')
