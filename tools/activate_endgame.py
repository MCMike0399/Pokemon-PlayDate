#!/usr/bin/env python3
"""Install the regenerated league packet on the coast manifest."""
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.activate_coast import manifest as coast
from tools.generate_source_map_cache import canonical

ENDGAME = (
    'ViridianGym', 'Route22Gate', 'Route23',
    'VictoryRoad1F', 'VictoryRoad2F', 'VictoryRoad3F',
    'IndigoPlateau', 'IndigoPlateauLobby',
    'LoreleisRoom', 'BrunosRoom', 'AgathasRoom', 'LancesRoom',
    'ChampionsRoom', 'HallOfFame',
)


def manifest(project=ROOT):
    installed = coast(project)
    raw = (Path(project) / 'Source/data/zEndgame/manifest-entries.json').read_bytes()
    packet = json.loads(raw)
    entries = packet['maps']
    if (packet.get('source_revision') != installed['source_revision']
            or len(installed['maps']) != 191 or set(entries) != set(ENDGAME)
            or set(entries) & set(installed['maps'])):
        raise ValueError('endgame packet is not 14 new maps on the 191-map manifest')
    for name, entry in entries.items():
        body = (Path(project) / 'Source' / entry['path']).read_bytes()
        if hashlib.sha256(body).hexdigest() != entry['source_sha256']:
            raise ValueError('endgame map bytes differ from the manifest pin: ' + name)
        if entry['id'] != 'pokered:' + json.loads(body)['source_map_constant']:
            raise ValueError('endgame map id differs from its decoded constant: ' + name)
    installed['maps'].update(entries)
    if len(installed['maps']) != 205:
        raise ValueError('endgame install is not 205 maps')
    city = json.loads((Path(project) / 'Source/data/viridianSlice/ViridianCity.json').read_bytes())
    gym_warp = [row for row in city['events']['warps']
                if row['destination'].get('map') == 'VIRIDIAN_GYM']
    route22 = json.loads((Path(project) / 'Source/data/sourceSlice/Route22.json').read_bytes())
    north = [row for row in route22['connections'] if row['direction'] == 'north']
    if len(gym_warp) != 1 or gym_warp[0]['x'] != 32 or gym_warp[0]['y'] != 7:
        raise ValueError('Viridian City gym door is not the source warp')
    if len(north) != 1 or north[0]['target_map'] != 'ROUTE_23':
        raise ValueError('Route 22 north is not Route 23')
    return installed


def write(path, project=ROOT):
    Path(path).write_bytes(canonical(manifest(project)))


if __name__ == '__main__':
    destination = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'Source/data/sourceMaps.json'
    write(destination)
    print('Installed 205 source maps: coast 191 plus 14 league maps.')
