#!/usr/bin/env python3
"""Generate small source policy/text; immutable ASM stays in external checkout."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.generate_vermilion_preparation import text_recipes

REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
INPUTS = (
    'scripts/SafariZoneGate.asm', 'scripts/SafariZoneSecretHouse.asm', 'scripts/WardensHouse.asm',
    'engine/events/hidden_events/safari_game.asm', 'engine/battle/safari_zone.asm',
    'engine/battle/core.asm', 'engine/items/item_effects.asm', 'home/overworld.asm',
    'data/maps/objects/SafariZoneGate.asm', 'data/maps/objects/SafariZoneCenter.asm',
    'data/maps/objects/SafariZoneWest.asm', 'text/SafariZoneGate.asm', 'text/WardensHouse.asm',
    'home/money.asm', 'engine/math/bcd.asm',
)


def generate(reference):
    if subprocess.check_output(['git', '-C', str(reference), 'rev-parse', 'HEAD'], text=True).strip() != REVISION:
        raise ValueError('wrong pokered revision')
    sources = {}
    for name in INPUTS:
        raw = (reference / name).read_bytes()
        if raw != subprocess.check_output(['git', '-C', str(reference), 'show', f'{REVISION}:{name}']):
            raise ValueError(f'modified pinned source: {name}')
        sources[name] = raw
    gate = sources['scripts/SafariZoneGate.asm'].decode()
    balls = int(re.search(r'ld a, (\d+)\s*\n\s*ld \[wNumSafariBalls\]', gate).group(1))
    steps = int(re.search(r'ld a, HIGH\((\d+)\)', gate).group(1))
    # Verify the BCD charge independently of the human-readable payment text.
    if 'ld a, $05\n\tld [wPriceTemp + 1], a' not in gate or 'ld [wPriceTemp + 2], a' not in gate:
        raise ValueError('Safari fee sequence changed')
    texts = {}
    for name in ('text/SafariZoneGate.asm', 'text/WardensHouse.asm'):
        texts.update(text_recipes(sources[name].decode()))
    policy = {'schema': 1, 'source_revision': REVISION, 'fee': 500, 'balls': balls, 'steps': steps,
              'battle_maps': [f'pokered:SAFARI_ZONE_{name}' for name in ('CENTER', 'EAST', 'NORTH', 'WEST')],
              'gate': 'pokered:SAFARI_ZONE_GATE', 'gate_worker': 'pokered:SAFARI_ZONE_GATE:objects:1',
              'info_worker': 'pokered:SAFARI_ZONE_GATE:objects:2',
              'warden': 'pokered:WARDENS_HOUSE:objects:1',
              'existing_surf_gift': 'pokered:SAFARI_ZONE_SECRET_HOUSE:objects:1',
              'existing_teeth_pickup': 'pokered:SAFARI_ZONE_WEST:objects:4',
              'texts': texts}
    pins = {'schema': 1, 'source_revision': REVISION,
            'inputs': {name: hashlib.sha256(raw).hexdigest() for name, raw in sources.items()}}
    money = sources['home/money.asm'].decode().split('HasEnoughCoins::')[1]
    coin_bytes = int(re.search(r'ld c, (\d+)', money).group(1))
    coin_limit = 10 ** (coin_bytes * 2) - 1
    return {'Source/data/safariServices.json': policy, 'tools/references/safari-services.json': pins,
            'Source/data/coinWallet.json': {'schema': 1, 'source_revision': REVISION, 'limit': coin_limit}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', required=True, type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    for name, value in generate(args.reference).items():
        text = json.dumps(value, ensure_ascii=False, separators=(',', ':')) + '\n'
        path = ROOT / name
        if args.check:
            if path.read_text() != text:
                raise SystemExit(f'stale Safari source output: {name}')
        else:
            path.write_text(text)
    print('Safari source policy and small pins verified.')


if __name__ == '__main__':
    main()
