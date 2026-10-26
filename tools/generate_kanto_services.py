"""Project three pinned Blue services into native planner data; never run Lua."""
import argparse
import hashlib
import json
import re
from pathlib import Path

from tools.generate_viridian_slice import text_recipes

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / 'tools/references/kanto-services'
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
CONTENT = 'kantoServices'
IDS = {'museum': 'pokered:MUSEUM_1F:objects:1',
       'magikarp': 'pokered:MT_MOON_POKECENTER:objects:4',
       'bicycle': 'pokered:BIKE_SHOP:objects:1'}


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def verified(reference):
    pin = json.loads((reference / 'manifest.json').read_text())
    assert pin['revision'] == REVISION
    sources = {}
    for path, digest in pin['files'].items():
        raw = (reference / path).read_bytes()
        if hashlib.sha256(raw).hexdigest() != digest:
            raise ValueError('unverified service source: ' + path)
        sources[path] = raw.decode()
    return sources


def build(reference=REFERENCE):
    sources = verified(Path(reference))
    museum = sources['scripts/Museum1F.asm']
    moon = sources['scripts/MtMoonPokecenter.asm']
    bike = sources['scripts/BikeShop.asm']
    # Fail rather than silently applying this projection to a different script.
    assert 'ResetEvent EVENT_BOUGHT_MUSEUM_TICKET' in sources['scripts/PewterCity.asm']
    assert 'SetEvent EVENT_BOUGHT_MUSEUM_TICKET' in museum
    assert re.search(r'cp 4\s+ret nz.*?cp 9.*?cp 10', museum, re.S)
    assert museum.count('ld a, $50') == 2
    assert 'lb bc, MAGIKARP, 5' in moon and moon.count('ld a, $5') == 2
    assert moon.index('call GivePokemon') < moon.index('predef SubBCDPredef') < moon.index('SetEvent EVENT_BOUGHT_MAGIKARP')
    assert bike.index('call GiveItem') < bike.index('farcall RemoveItemByID') < bike.index('SetEvent EVENT_GOT_BICYCLE')
    assert 'db "¥1000000@"' in bike
    give = sources['engine/events/give_pokemon.asm']
    assert 'cp PARTY_LENGTH' in give and 'cp MONS_PER_BOX' in give and 'SendNewMonToBox' in give
    for name, index, text_id in [('Museum1F', 1, 'TEXT_MUSEUM1F_SCIENTIST1'),
                                 ('MtMoonPokecenter', 4, 'TEXT_MTMOONPOKECENTER_MAGIKARP_SALESMAN'),
                                 ('BikeShop', 1, 'TEXT_BIKESHOP_CLERK')]:
        rows = re.findall(r'^\s*object_event (.+)$', sources['data/maps/objects/' + name + '.asm'], re.M)
        assert text_id in rows[index - 1]
    texts = {}
    for path, source in sources.items():
        if path.startswith(('text/', 'data/text/')):
            for label, recipe in text_recipes(source).items():
                if label.startswith(('_Museum1FScientist1', '_MtMoonPokecenterMagikarpSalesman', '_BikeShop')) or label in {'_GotMonText', '_SentToBoxText', '_BoxIsFullText'}:
                    texts[label] = dict(source=path, recipe=recipe)
    events = {identity: dict(kind='bespoke', content=CONTENT, service=key)
              for key, identity in IDS.items()}
    policy = dict(museum=dict(price=50, flag='EVENT_BOUGHT_MUSEUM_TICKET',
                            reset_map='pokered:PEWTER_CITY', trigger_y=4, trigger_x=[9, 10]),
                  magikarp=dict(price=500, species='magikarp', level=5, flag='EVENT_BOUGHT_MAGIKARP'),
                  bicycle=dict(offer_price=1000000, voucher='bikeVoucher', item='bicycle', flag='EVENT_GOT_BICYCLE'))
    header = dict(schema=1, source_revision=REVISION)
    return {'events.json': encoded(dict(header, events=events)),
            'dialogue.json': encoded(dict(header, texts=texts)),
            'policy.json': encoded(dict(header, **policy))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path, default=REFERENCE)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    artifacts = build(args.reference)
    target = args.output or ROOT / 'Source/data/kantoServices'
    if args.check:
        for name, raw in artifacts.items():
            assert (target / name).read_bytes() == raw, 'service output differs: ' + name
    else:
        assert args.output, 'explicit output directory required'
        target.mkdir(parents=True, exist_ok=True)
        for name, raw in artifacts.items():
            (target / name).write_bytes(raw)


if __name__ == '__main__':
    main()
