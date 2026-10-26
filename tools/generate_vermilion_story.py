#!/usr/bin/env python3
"""Project only bespoke Blue scenes; verify every pinned byte before decoding."""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / 'tools/references/vermilion-story'
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
CONTENT = 'vermilionStory'
RIVAL = 'pokered:SS_ANNE_2F:objects:2'
CAPTAIN = 'pokered:SS_ANNE_CAPTAINS_ROOM:objects:1'
GUARD = 'pokered:VERMILION_CITY:objects:3'
SURGE = 'pokered:VERMILION_GYM:objects:1'
DOCK = 'pokered:VERMILION_DOCK:hidden_events:1'


def encoded(value):
    return (json.dumps(value, sort_keys=True, indent=2, ensure_ascii=False)+'\n').encode()


def verified(reference=REFERENCE):
    pin = json.loads((REFERENCE/'manifest.json').read_text())
    assert pin['revision'] == REVISION
    result = {}
    for path, digest in pin['files'].items():
        raw = (Path(reference)/path).read_bytes()
        if hashlib.sha256(raw).hexdigest() != digest:
            raise ValueError('unverified pinned Vermilion source: '+path)
        result[path] = raw if path.endswith('.bst') else raw.decode('utf-8')
    return result


def global_block(source, label):
    """ASM global labels end a block; local labels remain in their parent."""
    match = re.search(r'^'+re.escape(label)+r'::?[ \t]*(?:;[^\n]*)?$', source, re.M)
    if not match:
        raise ValueError('missing global label: '+label)
    tail = source[match.end():]
    end = re.search(r'^[A-Za-z_][\w]*::?(?:\s|$)', tail, re.M)
    return tail[:end.start()] if end else tail


def recipes(source):
    result = {}
    # Stop even at non-text global labels. Never leak a subsequent routine into
    # a text recipe, and never mistake a local label for a global boundary.
    labels = list(re.finditer(r'^([A-Za-z_][\w]*)::?[ \t]*(?:;[^\n]*)?$', source, re.M))
    for i, match in enumerate(labels):
        if not match[1].startswith('_'):
            continue
        start = match.end()
        block = source[start:labels[i+1].start() if i+1<len(labels) else len(source)]
        operations = []
        for offset, line in enumerate(block.splitlines()):
            clean = line.strip()
            if not clean or clean.startswith(';'):
                continue
            number = source[:start].count('\n')+offset+1
            text = re.fullmatch(r'(text|line|cont|para|next)\s+"(.*)"', clean)
            if text:
                operations.append(dict(op=text[1],text=text[2],source_line=number))
            elif clean.startswith('text_ram '):
                operations.append(dict(op='text_ram',symbol=clean.split()[1],source_line=number))
            else:
                operations.append(dict(op='control',source=clean.split(';',1)[0].strip(),source_line=number))
        result[match[1]] = operations
    return result


def movement(block, label):
    tail = block.split(label+':',1)[1].split('db -1',1)[0]
    return [d.lower() for d in re.findall(r'db NPC_MOVEMENT_(UP|DOWN|LEFT|RIGHT)',tail)]


def party(source, label, index):
    rows = re.findall(r'^\s*db ([^;\n]+)', global_block(source,label), re.M)
    values = [v.strip() for v in rows[index-1].split(',')]
    assert values.pop() == '0' and values.pop(0) == '$FF'
    return [dict(level=int(values[i]),species=values[i+1].lower()) for i in range(0,len(values),2)]


def build(reference=REFERENCE):
    s = verified(reference)
    header = dict(schema=1,source_revision=REVISION)
    rival = s['scripts/SSAnne2F.asm']
    default = global_block(rival,'SSAnne2FDefaultScript')
    after = global_block(rival,'SSAnne2FRivalAfterBattleScript')
    points = [dict(x=int(x),y=int(y)) for x,y in re.findall(r'dbmapcoord\s+(\d+),\s*(\d+)',default)]
    assert points == [dict(x=36,y=8),dict(x=37,y=8)]
    variants = []
    for i, p in enumerate(points):
        approach = movement(default,'.RivalDownThreeMovement' if i==0 else '.RivalDownFourMovement')
        departure = movement(after,'.RivalWalkAroundPlayerMovement' if i==0 else '.RivalDownFourMovement')
        variants.append(dict(trigger=p,origin=dict(x=36,y=4),approach=approach,departure=departure,
                             end=dict(x=36,y=7 if i==0 else 8),facing='down' if i==0 else 'right'))
    positions = set()
    for v in variants:
        x,y = v['origin'].values()
        positions.add((x,y))
        for d in v['approach']+v['departure']:
            dx,dy = dict(down=(0,1),up=(0,-1),left=(-1,0),right=(1,0))[d]
            x,y=x+dx,y+dy; positions.add((x,y))
    table = global_block(s['engine/events/hidden_events/vermilion_gym_trash.asm'],'GymTrashCans')
    rows = [[int(n) for n in row.split(',')] for row in re.findall(r'^\s*db ([\d, ]+)',table,re.M)]
    assert len(rows)==15 and all(len(r)==5 for r in rows)
    hidden = s['data/events/hidden_events.asm'].split('hidden_events_for VERMILION_GYM',1)[1].split('db -1',1)[0]
    all_hidden = re.findall(r'hidden_event\s+(\d+),\s*(\d+),\s*(\w+),\s*(\w+)',hidden)
    cans = [dict(x=int(x),y=int(y),index=int(arg),id=f'pokered:VERMILION_GYM:hidden_events:{i}')
            for i,(x,y,fn,arg) in enumerate(all_hidden,1) if fn=='GymTrashScript']
    assert [c['index'] for c in cans]==list(range(15))
    events = {GUARD:dict(kind='bespoke',scene_script='boarding',item='ssTicket'),
              CAPTAIN:dict(kind='bespoke',scene_script='captain',item='hm01'),
              DOCK:dict(kind='bespoke',scene_script='departure'),
              RIVAL:dict(kind='bespoke',scene_script='rival',lost=['_SSAnne2FRivalVictoryText'],
                         script_positions=[dict(x=x,y=y) for x,y in sorted(positions) if (x,y)!=(36,4)],
                         victory=dict(guard_flags=['EVENT_BEAT_SS_ANNE_RIVAL','VERMILION_SCENE_V1_RIVAL_SHOWN'],flags={'EVENT_BEAT_SS_ANNE_RIVAL':True,'VERMILION_SCENE_V1_RIVAL_SHOWN':False})),
              SURGE:dict(kind='trainer',before=['_VermilionGymLTSurgePreBattleText'],
                         won=['_VermilionGymLTSurgeReceivedThunderBadgeText'],after=['_VermilionGymLTSurgePostBattleAdviceText'],
                         lost=['_VermilionGymLTSurgeReceivedThunderBadgeText'],
                         reward=dict(item='tm24',flag='EVENT_GOT_TM24',before=['_VermilionGymLTSurgeThunderBadgeInfoText'],
                                     success=['_VermilionGymLTSurgeReceivedTM24Text','_TM24ExplanationText'],
                                     full=['_VermilionGymLTSurgeTM24NoRoomText'],full_status='bag-full'),
                         victory=dict(guard_flags=['BADGE_THUNDER','EVENT_BEAT_LT_SURGE'],
                                      flags={'BADGE_THUNDER':True,'EVENT_BEAT_LT_SURGE':True},
                                      trainers={f'pokered:VERMILION_GYM:objects:{i}':True for i in [2,3,4]}))}
    for can in cans:
        events[can['id']]=dict(kind='bespoke',scene_script='trash',trash_index=can['index'])
    for d in events.values(): d['content']=CONTENT
    classes=s['data/trainers/parties.asm']; money=s['data/trainers/pic_pointers_money.asm']
    def trainer(identity,label,name,sprite,base):
        amount=int(re.search(r'pic_money '+label+r'Pic,\s+(\d+)',money)[1])//100
        assert amount==base
        team=party(classes,label+'Data',1)
        return dict(id=identity,map_id=':'.join(identity.split(':')[:2]),name=name,sprite_source=sprite,
                    sight_range_cells=0,talk_only=True,party=team,payout=base*team[-1]['level'])
    trainers={SURGE:trainer(SURGE,'LtSurge','LT.SURGE','SPRITE_ROCKER',99),
              RIVAL:trainer(RIVAL,'Rival2','BLUE','SPRITE_BLUE',65)}
    variants_by_starter={starter:dict(party=party(classes,'Rival2Data',i),payout=1300)
                         for starter,i in [('charmander',1),('squirtle',2),('bulbasaur',3)]}
    trainers[RIVAL]['rival_parties']=variants_by_starter
    trainers[RIVAL]['party']=variants_by_starter['charmander']['party']
    trainers[RIVAL]['source_flag']='EVENT_BEAT_SS_ANNE_RIVAL'
    trainers[SURGE]['source_flag']='EVENT_BEAT_LT_SURGE'
    texts={}
    for path, source in s.items():
        if not path.startswith(('text/','data/text/')): continue
        for label,recipe in recipes(source).items():
            if (label.startswith(('_SSAnne2FRival','_SSAnneCaptainsRoomCaptain','_SSAnneCaptainsRoomRub',
                                  '_VermilionCitySailor1','_VermilionGymLTSurge','_VermilionGymTrash'))
                or label in {'_TM24ExplanationText','_MoneyForWinningText'}):
                assert label not in texts
                texts[label]=dict(source=path,recipe=recipe)
    scenes=dict(rival=dict(id=RIVAL,variants=variants),trash=dict(cans=cans,table=rows,count=15,
                    selector='pinned-blue-mask-swap-underflow-zero',first_mask=14),
                boarding=dict(x=18,y=30,facing='down',id=GUARD),
                departure=dict(from_zone='pokered:SS_ANNE_1F',from_x=26,from_y=0,to_zone='pokered:VERMILION_DOCK',
                               to_x=14,to_y=2,id=DOCK),
                gym_door=dict(block_x=2,block_y=2,closed_block=36,open_block=5),
                dock=dict(erased_block=13,block_y=2,block_x=[5,6,7,8]))
    assert 'warp_event 26,  0, VERMILION_DOCK, 2' in s['data/maps/objects/SSAnne1F.asm']
    terrain = {}
    for effect, map_name, tileset, block, targets in [
        ('gym-close','VermilionGym','GYM',36,[(2,2)]),
        ('gym-open','VermilionGym','GYM',5,[(2,2)]),
        ('ship-departed','VermilionDock','SHIP_PORT',13,[(x,2) for x in [5,6,7,8]])]:
        raw = s['gfx/blocksets/'+('gym' if tileset=='GYM' else 'ship_port')+'.bst']
        keys=[]
        for q in range(4):
            qx,qy=q%2,q//2
            ids=[raw[block*16+(2*qy+y)*4+2*qx+x] for y in range(2) for x in range(2)]
            keys.append('pokered:'+tileset+':cell:'+'-'.join(f'{n:02x}' for n in ids))
        terrain[effect]=dict(map=map_name,block=block,keys=keys,targets=[dict(x=x,y=y) for x,y in targets])
    return {name:encoded(dict(header,**{key:value})) for name,key,value in [
        ('events.json','events',events),('trainers.json','trainers',trainers),
        ('dialogue.json','texts',texts),('scenes.json','scenes',scenes),('terrain.json','effects',terrain)]}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference',type=Path,default=REFERENCE)
    parser.add_argument('--output',type=Path)
    parser.add_argument('--check',action='store_true')
    a=parser.parse_args(); artifacts=build(a.reference)
    if a.check:
        for name,raw in artifacts.items(): assert (ROOT/'Source/data/vermilionStory'/name).read_bytes()==raw,name
    else:
        assert a.output,'explicit output directory required'
        a.output.mkdir(parents=True,exist_ok=True)
        for name,raw in artifacts.items(): (a.output/name).write_bytes(raw)

if __name__=='__main__': main()
