"""Representative bounded traces; large artifacts are written only on explicit CLI requests."""
import hashlib
from pathlib import Path
import json

from .trace import Trace

FIRST = [
    ('audio1:Music_PkmnHealed', None, 0, 128),
    ('audio3:Music_Dungeon1', None, 0, 128),
    ('audio1:SFX_Collision_1', None, 0, 128),
    ('audio2:SFX_Cry01_2', None, 0, 128),
    ('audio1:Music_PalletTown', None, 0, 128),
    ('audio1:Music_Routes3', None, 0, 128),
    ('audio1:Music_Cities1', None, 0, 128),
    ('audio1:Music_Lavender', None, 0, 128),
    ('audio3:Music_PokemonTower', None, 0, 128),
    ('audio2:Music_WildBattle', None, 0, 128),
    ('audio2:Music_TrainerBattle', None, 0, 128),
    ('audio2:Music_GymLeaderBattle', None, 0, 128),
    ('audio2:Music_FinalBattle', None, 0, 128),
    ('audio1:Music_MeetRival', None, 0, 128),
    ('audio1:Music_MeetRival', 'Music_RivalAlternateStart', 0, 128),
    ('audio1:Music_MeetRival', 'Music_RivalAlternateTempo', 0, 128),
    ('audio1:Music_Cities1', 'Music_Cities1AlternateTempo', 0, 128),
    ('audio2:SFX_Cry00_2', None, 0, 128),
    ('audio2:SFX_Cry00_2', None, 255, 192),
    ('audio1:SFX_Cry00_1', None, 204, 1),
    ('audio3:SFX_Cry00_3', None, 237, 255),
    ('audio1:SFX_Pokeflute', None, 0, 128),
    ('audio2:SFX_Caught_Mon', 'Music_PokeFluteInBattle', 0, 128),
]


def run_fixtures(catalog, output, max_ticks=120000):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    summaries = []
    exercised = set()
    for index, (asset, variant, pitch, length) in enumerate(FIRST):
        trace = Trace(catalog, catalog.headers[asset]['family'])
        trace.load(asset, pitch, length)
        if variant: trace.variant(variant)
        result = trace.run(max_ticks)
        result['revision'] = catalog.source.revision
        result['consumed_sha256'] = dict(sorted(catalog.source.hashes.items()))
        result['asset'] = asset
        result['variant'] = variant
        exercised.update(result['executed_macros'])
        payload = json.dumps(result, sort_keys=True, indent=2)+'\n'
        filename = f'{index:02d}-{asset.replace(":", "-")}-{variant or "default"}-{pitch}-{length}.json'
        (output/filename).write_text(payload)
        summaries.append({'asset': asset, 'variant': variant, 'pitch': pitch, 'length': length,
                          'status': result['status'], 'ticks': result['ticks'],
                          'repeat': result['repeat'], 'events': len(result['events']),
                          'trace': filename, 'sha256': hashlib.sha256(payload.encode()).hexdigest()})
    trace = Trace(catalog, 2)
    result = trace.run(128, alarm=True)
    (output/'low-health.json').write_text(json.dumps(result, sort_keys=True, indent=2)+'\n')
    summaries.append({'asset': 'audio2:low-health', 'status': result['status'], 'repeat': result['repeat']})
    return {'fixtures': summaries, 'exercised_macros': sorted(exercised),
            'unexercised_macros': sorted(set(catalog.coverage)-exercised-{'dw', 'dn'}),
            'bounded': [r['asset'] for r in summaries if r['status'] == 'bound']}
