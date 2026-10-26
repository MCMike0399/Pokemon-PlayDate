#!/usr/bin/env python3
"""Generate only bespoke Blue story data; no runtime execution or shared manifests."""
import argparse
import hashlib
import json
import re
from pathlib import Path
from tools.generate_viridian_slice import text_recipes

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / 'tools/references/cerulean-story'
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
CONTENT = 'ceruleanStory'
BILL = 'pokered:BILLS_HOUSE:objects:'
MOON = 'pokered:MT_MOON_B2F:objects:'
MISTY = 'pokered:CERULEAN_GYM:objects:1'
PC = 'pokered:BILLS_HOUSE:hidden_events:1'


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def verified(reference):
    pin = json.loads((REFERENCE / 'manifest.json').read_text())
    assert pin['revision'] == REVISION
    result = {}
    for path, digest in pin['files'].items():
        raw = (reference / path).read_bytes()
        if hashlib.sha256(raw).hexdigest() != digest:
            raise ValueError('unverified pinned story source: ' + path)
        result[path] = raw.decode()
    return result


def build(reference=REFERENCE):
    sources = verified(Path(reference))
    events = {}

    def add(identity, **descriptor):
        events[identity] = dict(content=CONTENT, **descriptor)

    def scene(identity, script, source, positions=None, **extra):
        add(identity, kind='bespoke', scene_script=script, source=source,
            **({'script_positions': positions} if positions else {}), **extra)

    # Identity and coordinates come from the decoded object order, never labels
    # normalized into a new event namespace.
    scene(BILL+'1', 'bill-intro', 'scripts/BillsHouse.asm:BillsHouseBillPokemonText',
          [{'x':x,'y':y} for x,y in [(6,5),(6,4),(6,3),(6,2),(7,5),(7,4),(7,3)]],
          script_collision_positions=[{'x':6,'y':2}])
    scene(PC, 'bill-pc', 'engine/events/hidden_events/bills_house_pc.asm:BillsHousePC')
    scene(BILL+'2', 'bill-ticket', 'scripts/BillsHouse.asm:BillsHouseBillSSTicketText',
          [{'x':x,'y':y} for x,y in [(1,2),(1,3),(2,3),(3,3),(4,3),(4,4)]], item='ssTicket', script_collision_positions=[{'x':1,'y':2}])
    add(BILL+'3', kind='program', steps=[{'op':'dialog','labels':['_BillsHouseBillCheckOutMyRarePokemonText']}])
    for index, item, flag, label in [(6,'domeFossil','EVENT_GOT_DOME_FOSSIL','_MtMoonB2FDomeFossilYouWantText'),
                                      (7,'helixFossil','EVENT_GOT_HELIX_FOSSIL','_MtMoonB2FHelixFossilYouWantText')]:
        scene(MOON+str(index), 'fossil', 'scripts/MtMoonB2F.asm:MtMoonB2F'+('Dome' if index==6 else 'Helix')+'FossilText',
              item=item, flag=flag, prompt=label)
    scene(MOON+'1', 'super-nerd', 'scripts/MtMoonB2F.asm:MtMoonB2FSuperNerdText',
          [{'x':x,'y':y} for x,y in [(12,8),(13,8),(13,7),(12,7)]],
          victory={'guard_flags':['EVENT_BEAT_MT_MOON_EXIT_SUPER_NERD'],
                   'flags':{'EVENT_BEAT_MT_MOON_EXIT_SUPER_NERD':True}})
    add(MISTY, kind='trainer', before=['_CeruleanGymMistyPreBattleText'],
        won=['_CeruleanGymMistyReceivedCascadeBadgeText'], after=['_CeruleanGymMistyTM11ExplanationText'],
        source='scripts/CeruleanGym.asm:CeruleanGymReceiveTM11',
        reward={'item':'tm11','flag':'EVENT_GOT_TM11','before':['_CeruleanGymMistyCascadeBadgeInfoText'],
                'success':['_CeruleanGymMistyReceivedTM11Text'], 'full':['_CeruleanGymMistyTM11NoRoomText'],
                'full_status':'bag-full'},
        victory={'guard_flags':['BADGE_CASCADE','EVENT_BEAT_MISTY'],
                 'flags':{'BADGE_CASCADE':True,'EVENT_BEAT_MISTY':True},
                 'trainers':{'pokered:CERULEAN_GYM:objects:2':True,'pokered:CERULEAN_GYM:objects:3':True}})

    movement = {}
    script = sources['scripts/BillsHouse.asm']
    for key, label in [('bill_enter','.PokemonWalkToMachineMovement'),('bill_around','.PokemonWalkAroundPlayerMovement'),('bill_exit','.BillExitMachineMovement')]:
        block = script.split(label+':',1)[1].split('db -1',1)[0]
        movement[key] = [d.lower() for d in re.findall(r'db NPC_MOVEMENT_(UP|DOWN|LEFT|RIGHT)',block)]
    # Fall-through is significant: MoveRight consists of RIGHT followed by UP.
    moon = sources['scripts/MtMoonB2F.asm']
    for key,label in [('nerd_dome','MtMoon3FSuperNerdMoveRightMovementData'),('nerd_helix','MtMoon3FSuperNerdMoveUpMovementData')]:
        movement[key] = [d.lower() for d in re.findall(r'db NPC_MOVEMENT_(UP|DOWN|LEFT|RIGHT)',moon.split(label+':',1)[1].split('db -1',1)[0])]

    texts = {}
    for path, source in sources.items():
        if path.startswith(('text/','data/text/')):
            for label, recipe in text_recipes(source).items():
                if (label.startswith(('_BillsHouse','_SSTicket','_MtMoonB2FSuperNerd','_MtMoonB2fSuperNerd','_CeruleanGymMisty'))
                    or label in {'_MtMoonB2FDomeFossilYouWantText','_MtMoonB2FHelixFossilYouWantText',
                                 '_MtMoonB2FReceivedFossilText','_MtMoonB2FYouHaveNoRoomText','_MoneyForWinningText'}):
                    assert label not in texts
                    texts[label] = {'source':path,'recipe':recipe}
    # PC strings live in shared text banks.
    assert '_BillsHouseInitiatedText' in texts and '_BillsHouseMonitorText' in texts
    trainers = {}
    parties = sources['data/trainers/parties.asm']
    for identity, section, roster, name, sprite, flag, base, x, y in [
        (MOON+'1','SuperNerdData',2,'SUPER NERD','SPRITE_SUPER_NERD','EVENT_BEAT_MT_MOON_EXIT_SUPER_NERD',25,12,8),
        (MISTY,'MistyData',1,'MISTY','SPRITE_BRUNETTE_GIRL','EVENT_BEAT_MISTY',99,4,2)]:
        block = parties.split(section+':',1)[1].split('\n\n',1)[0]
        rows = re.findall(r'^\s*db (.+)',block,re.M)
        tokens = [v.strip() for v in rows[roster-1].split(',')][:-1]
        if tokens[0] == '$FF':
            party = [{'species':tokens[i+1].lower(),'level':int(tokens[i])} for i in range(1,len(tokens),2)]
        else:
            party = [{'species':s.lower(),'level':int(tokens[0])} for s in tokens[1:]]
        money_row = re.search(r'pic_money '+('Misty' if identity==MISTY else 'SuperNerd')+r'Pic,\s+(\d+)',sources['data/trainers/pic_pointers_money.asm'])
        assert money_row and int(money_row[1]) // 100 == base
        trainers[identity] = dict(id=identity,map_id=':'.join(identity.split(':')[:2]),name=name,
            sprite_source=sprite,source_flag=flag,party=party,payout=base*party[-1]['level'],
            sight_range_cells=0,talk_only=True,x=x,y=y)
    # hidden_event arguments are (x,y); its macro emits y then x for the
    # dispatcher. The dispatcher compares the tile in front of the player.
    hidden = sources['data/events/hidden_events.asm']
    pc_rows = hidden.split('hidden_events_for BILLS_HOUSE',1)[1].split('db -1',1)[0]
    match = re.search(r'hidden_event\s+(\d+),\s*(\d+), BillsHousePC, SPRITE_FACING_UP',pc_rows)
    assert match, 'pinned Bill PC target/facing missing'
    pc_x, pc_y = int(match[1]), int(match[2])
    dispatcher = sources['engine/overworld/hidden_events.asm']
    assert 'call CheckIfCoordsInFrontOfPlayerMatch' in dispatcher
    assert '.facingUp\n\tld a, [wYCoord]\n\tdec a' in dispatcher
    pc = {'x':pc_x,'y':pc_y,'facing':'up','id':PC,'coordinate_role':'target'}
    pc_player = {'x':pc_x,'y':pc_y+1,'facing':'up','id':PC}
    payload = dict(schema=1,source_revision=REVISION)
    return {'events.json':encoded(dict(payload,events=events)),
            'dialogue.json':encoded(dict(payload,texts=texts)),
            'scenes.json':encoded(dict(payload,movement=movement,pc=pc,pc_player=pc_player,
                fossil_trigger={'x':13,'y':8,'id':MOON+'1'},
                no_encounters_after_nerd={'x_min':11,'x_max':14,'y_min':5,'y_max':8})),
            'trainers.json':encoded(dict(payload,trainers=trainers))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path, default=REFERENCE)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    artifacts = build(args.reference)
    target = args.output or ROOT/'Source/data/ceruleanStory'
    if args.check:
        for name, raw in artifacts.items():
            assert (target/name).read_bytes() == raw, 'story output differs: '+name
    else:
        assert args.output, 'explicit output directory required'
        target.mkdir(parents=True, exist_ok=True)
        for name, raw in artifacts.items():
            (target/name).write_bytes(raw)

if __name__ == '__main__':
    main()
