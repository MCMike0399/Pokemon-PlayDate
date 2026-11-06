#!/usr/bin/env python3
"""Project the checksum-pinned Blue Copycat service; never activate it."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.generate_cerulean_content import text_recipes

REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
PINS = ROOT / 'tools/references/copycat.json'
OUTPUT = ROOT / 'Source/data/copycatService'


def build(reference):
    reference = Path(reference)
    pins = json.loads(PINS.read_bytes())
    if pins['schema'] != 1 or pins['source_revision'] != REVISION:
        raise ValueError('unverified Copycat pins')
    sources = {}
    for name, digest in pins['files'].items():
        raw = (reference / name).read_bytes()
        original = subprocess.check_output(['git', '-C', str(reference), 'show', REVISION + ':' + name])
        if raw != original or hashlib.sha256(raw).hexdigest() != digest:
            raise ValueError('modified Copycat source: ' + name)
        if name.endswith('.asm'):
            sources[name] = raw.decode()
    assert 'CopycatsHouse2F_Blocks:\nRedsHouse2F_Blocks: INCBIN \"maps/RedsHouse2F.blk\"' in sources['maps.asm']
    script = sources['scripts/CopycatsHouse2F.asm']
    service = script.split('CopycatsHouse2FCopycatText:', 1)[1].split('.DoYouLikePokemonText:', 1)[0]
    sequence = ['CheckEvent EVENT_GOT_TM31', 'ld hl, .DoYouLikePokemonText',
                'ld b, POKE_DOLL', 'call IsItemInBag', 'ld hl, .TM31PreReceiveText',
                'lb bc, TM_MIMIC, 1', 'call GiveItem', 'jr nc, .bag_full',
                'ld hl, .ReceivedTM31Text', 'farcall RemoveItemByID', 'SetEvent EVENT_GOT_TM31']
    offsets = [service.index(value) for value in sequence]
    assert offsets == sorted(offsets) and 'YesNoChoice' not in service
    pc = script.split('CopycatsHouse2FPCText:', 1)[1]
    assert 'cp SPRITE_FACING_UP' in pc and pc.index('jr nz, .notUp') < pc.index('ld hl, .MySecretsText')
    objects = sources['data/maps/objects/CopycatsHouse2F.asm']
    assert 'object_event  4,  3, SPRITE_BRUNETTE_GIRL, WALK, ANY_DIR, TEXT_COPYCATSHOUSE2F_COPYCAT' in objects
    assert 'bg_event  0,  1, TEXT_COPYCATSHOUSE2F_PC' in objects
    assert 'call AddItemToInventory\n\tret nc' in sources['home/give.asm']
    prefix = '_CopycatsHouse2FCopycat'
    labels = dict(before=prefix + 'DoYouLikePokemonText', offer=prefix + 'TM31PreReceiveText',
                  received=prefix + 'ReceivedTM31Text', explanation=prefix + 'TM31Explanation1Text',
                  completed=prefix + 'TM31Explanation2Text', full=prefix + 'TM31NoRoomText',
                  pc_up='_CopycatsHouse2FPCMySecretsText', pc_other='_CopycatsHouse2FPCCantSeeText')
    recipes = text_recipes(sources['text/CopycatsHouse2F.asm'])
    texts = {label: dict(recipe=recipes[label], source='text/CopycatsHouse2F.asm')
             for label in labels.values()}
    value = dict(schema=1, source_revision=REVISION, source_files=pins['files'],
                 flag='EVENT_GOT_TM31', payment='pokeDoll', reward='tm31', labels=labels,
                 copycat='pokered:COPYCATS_HOUSE_2F:objects:1',
                 pc='pokered:COPYCATS_HOUSE_2F:background_events:2', texts=texts,
                 audio_gap='sound_get_item_1', transaction_order=['add-reward', 'take-payment', 'set-flag'])
    return {'service.json': (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + '\n').encode()}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=OUTPUT)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    files = build(args.reference)
    if args.check:
        actual = {p.name: p.read_bytes() for p in args.output.iterdir() if p.is_file()}
        if actual != files:
            raise ValueError('Copycat projection differs')
    else:
        args.output.mkdir(parents=True, exist_ok=False)
        for name, raw in files.items():
            (args.output / name).write_bytes(raw)
    print('Verified pinned Copycat projection; no activation or runtime.')
