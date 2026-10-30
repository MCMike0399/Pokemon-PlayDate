"""Project pinned Blue gate programs into one declarative guard package."""
import argparse
import hashlib
import json
import re
from pathlib import Path
from tools.materialize_pokered_packages import reference_root
from tools.generate_cerulean_content import text_recipes

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = reference_root('saffron-guards')
OUTPUT = ROOT / 'Source/data/saffronGuards'
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
FLAG = 'pokered:wStatusFlags1:BIT_GAVE_SAFFRON_GUARDS_DRINK'


def build(reference=REFERENCE):
    pin = json.loads((reference / 'manifest.json').read_text())
    assert pin['revision'] == REVISION
    active_maps = set(json.loads((ROOT / 'Source/data/sourceMaps.json').read_text())['maps'])
    sources = {}
    for path, digest in pin['files'].items():
        raw = (reference / path).read_bytes()
        assert hashlib.sha256(raw).hexdigest() == digest, 'unverified guard source: ' + path
        sources[path] = raw.decode('utf-8')
    assert 'const BIT_GAVE_SAFFRON_GUARDS_DRINK' in sources['constants/ram_constants.asm']
    central = sources['engine/events/saffron_guards.asm']
    assert central.index('call IsItemInBag') < central.index('farjp RemoveItemByID')
    symbols = re.findall(r'^\s*db (\w+)$', sources['data/items/guard_drink_items.asm'], re.M)
    assert symbols == ['FRESH_WATER', 'SODA_POP', 'LEMONADE']
    drinks = ['freshWater', 'sodaPop', 'lemonade']
    guards = {}
    for number, push in [(5, 'up'), (6, 'down'), (7, 'left'), (8, 'right')]:
        script = sources[f'scripts/Route{number}Gate.asm']
        assert 'bit BIT_GAVE_SAFFRON_GUARDS_DRINK, a' in script
        assert script.index('call ArePlayerCoordsInArray') < script.index('farcall RemoveGuardDrink')
        assert f'ld a, PAD_{push.upper()}' in script
        direction = re.search(r'ld a, PLAYER_DIR_(\w+)', script)[1].lower()
        points = [dict(x=int(x), y=int(y)) for x, y in re.findall(r'dbmapcoord\s+(\d+),\s+(\d+)', script)]
        obj = sources[f'data/maps/objects/Route{number}Gate.asm']
        actor = re.findall(r'object_event\s+(\d+),\s+(\d+), SPRITE_GUARD, STAY, (\w+), (\w+)', obj)
        assert len(actor) == 1
        x, y, facing, text = actor[0]
        assert text == f'TEXT_ROUTE{number}GATE_GUARD'
        guards[f'pokered:ROUTE_{number}_GATE:objects:1'] = dict(
            map=f'Route{number}Gate', active=f'Route{number}Gate' in active_maps,
            actor=dict(x=int(x), y=int(y), facing=facing.lower()),
            trigger=points, entry_facing=direction, entry_push=push, talk_push='up')
    shared = sources['scripts/Route5Gate.asm']
    talk = shared[shared.index('SaffronGateGuardText:'):shared.index('SaffronGateGuardGeeImThirstyText:')]
    assert 'call Route5GateMovePlayerUpScript' in talk
    assert 'YesNoChoice' not in ''.join(sources.values())
    texts = {label: dict(recipe=recipe, source='text/SaffronGates.asm')
             for label, recipe in text_recipes(sources['text/SaffronGates.asm']).items()}
    assert len(texts) == 4
    value = dict(schema=1, source_revision=REVISION, flag=FLAG, drinks=drinks,
                 guards=guards, texts=texts,
                 thirsty=['_SaffronGateGuardGeeImThirstyText'],
                 accepted=['_SaffronGateGuardImParchedText', '_SaffronGateGuardYouCanGoOnThroughText'],
                 completed=['_SaffronGateGuardThanksForTheDrinkText'],
                 audio_gap='sound_get_key_item')
    return {'guards.json': (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False)+'\n').encode()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    target = args.output or OUTPUT
    for name, raw in build().items():
        if args.check:
            assert (target / name).read_bytes() == raw, 'stale guard data'
        else:
            assert args.output, 'explicit output directory required'
            target.mkdir(parents=True, exist_ok=True)
            (target / name).write_bytes(raw)


if __name__ == '__main__':
    main()
