#!/usr/bin/env python3
"""Project compact Blue Celadon service data; verify external pinned Git blobs."""
import argparse
import hashlib
import importlib.util
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
OUT = ROOT / 'Source/data/celadonServices'
spec = importlib.util.spec_from_file_location('source_recipe_helpers', ROOT / 'tools/generate_vermilion_story.py')
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
FILES = [
    'scripts/CeladonMartRoof.asm', 'scripts/CeladonMansionRoofHouse.asm', 'scripts/CeladonMartElevator.asm',
    'scripts/GameCorner.asm', 'scripts/GameCornerPrizeRoom.asm',
    'data/items/vending_prices.asm', 'data/events/prizes.asm', 'data/events/prize_mon_levels.asm',
    'data/events/slot_machine_wheels.asm', 'data/events/hidden_events.asm',
    'engine/events/vending_machine.asm', 'engine/events/prize_menu.asm', 'engine/events/hidden_items.asm',
    'engine/slots/slot_machine.asm', 'engine/slots/game_corner_slots.asm', 'engine/slots/game_corner_slots2.asm',
    'engine/math/bcd.asm', 'home/money.asm', 'constants/script_constants.asm', 'constants/ram_constants.asm',
] + [f'data/maps/objects/{name}.asm' for name in ('CeladonMartRoof', 'CeladonMansionRoofHouse',
    'CeladonMartElevator', 'GameCorner', 'GameCornerPrizeRoom')]
FILES += [f'data/maps/objects/CeladonMart{n}F.asm' for n in range(1, 6)]
FILES += [f'text/{name}.asm' for name in ('CeladonMartRoof', 'CeladonMansionRoofHouse', 'GameCorner', 'GameCornerPrizeRoom')]
FILES += [f'data/text/text_{n}.asm' for n in range(1, 7)]


def encode(value):
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + '\n').encode()


def blue(source):
    result, active = [], [True]
    for line in source.splitlines():
        match = re.match(r'IF DEF\(_(RED|BLUE)\)', line)
        if match:
            active.append(active[-1] and match[1] == 'BLUE')
        elif line.strip() == 'ENDC':
            active.pop()
        elif active[-1]:
            result.append(line)
    assert len(active) == 1
    return '\n'.join(result)


def build(reference):
    assert subprocess.check_output(['git','-C',str(reference),'rev-parse','HEAD'], text=True).strip() == REVISION
    source, pins = {}, {}
    for name in FILES:
        raw = (reference / name).read_bytes()
        assert raw == subprocess.check_output(['git','-C',str(reference),'show',f'{REVISION}:{name}']), name
        source[name] = raw.decode()
        pins[name] = hashlib.sha256(raw).hexdigest()
    drinks = [dict(symbol=s, item={'FRESH_WATER':'freshWater','SODA_POP':'sodaPop','LEMONADE':'lemonade'}[s], price=int(p))
              for s,p in re.findall(r'vend_item\s+(\w+),\s*(\d+)', source['data/items/vending_prices.asm'])]
    assert [d['price'] for d in drinks] == [200,300,350]
    for drink, tm, name in zip(drinks, ['13','48','49'], ['FreshWater','SodaPop','Lemonade']):
        drink.update(tm='tm'+tm, flag='EVENT_GOT_TM'+tm, source_name=name)
    prize_source = blue(source['data/events/prizes.asm'])
    levels = {species.lower():int(level) for species,level in re.findall(r'db (\w+),\s*(\d+)', blue(source['data/events/prize_mon_levels.asm']))}
    prizes = []
    for entries, prices in [('PrizeMenuMon1Entries','PrizeMenuMon1Cost'),('PrizeMenuMon2Entries','PrizeMenuMon2Cost'),('PrizeMenuTMsEntries','PrizeMenuTMsCost')]:
        symbols = re.findall(r'^\s*db (\w+)\s*$', helper.global_block(prize_source, entries), re.M)
        costs = [int(x) for x in re.findall(r'bcd2 (\d+)', helper.global_block(prize_source, prices))]
        assert len(symbols) == len(costs) == 3
        rows = []
        for symbol, cost in zip(symbols, costs):
            if symbol.startswith('TM_'):
                rows.append(dict(item={'TM_DRAGON_RAGE':'tm23','TM_HYPER_BEAM':'tm15','TM_SUBSTITUTE':'tm50'}[symbol], price=cost, symbol=symbol))
            else:
                rows.append(dict(species=symbol.lower(), level=levels[symbol.lower()], price=cost, symbol=symbol))
        prizes.append(rows)
    elevator = []
    for warp, floor in re.findall(r'db (\d+), CELADON_MART_(\d)F', source['scripts/CeladonMartElevator.asm']):
        warps = re.findall(r'warp_event\s+(\d+),\s*(\d+),\s*(\w+),\s*(\d+)', source[f'data/maps/objects/CeladonMart{floor}F.asm'])
        x,y,target,_ = warps[int(warp)]
        assert target == 'CELADON_MART_ELEVATOR'
        elevator.append(dict(floor=int(floor), map_id=f'pokered:CELADON_MART_{floor}F', source_warp_byte=int(warp), x=int(x), y=int(y)))
    assert len(elevator) == 5
    hidden = source['data/events/hidden_events.asm'].split('hidden_events_for GAME_CORNER\n',1)[1].split('db -1',1)[0]
    machines, hidden_coins = [], []
    for index,(x,y,function,arg) in enumerate(re.findall(r'hidden_event\s+(\d+),\s*(\d+),\s*(\w+),\s*([^;\n]+)', hidden),1):
        row = dict(id=f'pokered:GAME_CORNER:hidden_events:{index}', x=int(x),y=int(y),index=index)
        if function == 'StartSlotMachine':
            row['condition'] = arg.strip()
            machines.append(row)
        else:
            assert function == 'HiddenCoins'
            row['coins'] = int(re.search(r'COIN \+ (\d+)', arg)[1])
            row['flag'] = 'CELADON_SERVICES_V1_HIDDEN_COINS_'+str(index)
            row['shadowed_by_slot'] = any(m['x']==row['x'] and m['y']==row['y'] for m in machines)
            hidden_coins.append(row)
    assert len(machines)==36 and len(hidden_coins)==12 and hidden_coins[-1]['shadowed_by_slot']
    wheels = []
    for i in range(1,4):
        wheels.append(re.findall(r'dw (SLOTS\w+)', helper.global_block(source['data/events/slot_machine_wheels.asm'], f'SlotMachineWheel{i}')))
    assert all(len(w)==18 for w in wheels)
    labels = set()
    for path, text in source.items():
        if path.startswith(('scripts/','engine/events/','engine/slots/')):
            labels.update(re.findall(r'text_far\s+(_\w+)', text))
    labels.update(['_GotMonText','_SentToBoxText','_BoxIsFullText','_FoundHiddenItemText'])
    # Runtime recipes only: no full source assembly dump or unrelated corpus.
    texts = {}
    for path,text in source.items():
        if path.startswith(('text/','data/text/')):
            for label,recipe in helper.recipes(text).items():
                if label in labels:
                    texts[label] = dict(recipe=recipe,source=path)
    wanted = ['_VendingMachineText1','_VendingMachineText4','_VendingMachineText5','_VendingMachineText6','_VendingMachineText7',
              '_GameCornerClerk1DoYouNeedSomeGameCoinsText','_GotMonText','_SentToBoxText','_BoxIsFullText']
    assert all(label in texts for label in wanted), [label for label in wanted if label not in texts]
    data = dict(drinks=drinks, prizes=prizes, elevator=elevator, machines=machines, hidden_coins=hidden_coins,
                wheels=wheels, vending_minimum_money=200, coin_sale=dict(price=1000,coins=50,full_threshold=9990),
                eevee=dict(id='pokered:CELADON_MANSION_ROOF_HOUSE:objects:2', species='eevee',level=25,
                           flag='CELADON_SERVICES_V1_EEVEE_TAKEN'))
    header = dict(schema=1,source_revision=REVISION)
    return {'policy.json':encode(dict(header,policy=data)), 'dialogue.json':encode(dict(header,texts=texts)),
            'provenance.json':encode(dict(header,files=pins))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference',type=Path,required=True)
    parser.add_argument('--check',action='store_true')
    args = parser.parse_args()
    for name,value in build(args.reference).items():
        path = OUT/name
        if args.check:
            if not path.exists() or path.read_bytes()!=value:
                raise SystemExit('stale generated service data: '+str(path))
        else:
            path.write_bytes(value)


if __name__=='__main__':
    main()
