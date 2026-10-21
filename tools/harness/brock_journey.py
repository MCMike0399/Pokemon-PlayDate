"""Bounded source-driven Brock journey; receives an already-owned Client.

No process launch, mailbox access, RNG simulation, Source writes or save copying.
Natural mode permits only the inherited first new-game seed fixture.
"""
import hashlib
import heapq
import json
import math
from pathlib import Path
from tools.harness.parcel_journey import ParcelJourney, Geometry, Step, sequence, load_geometry, project_connection, NAMES as PARCEL_NAMES, REVISION
from tools.harness.journeys import lookup, DIRECTIONS
from tools.harness.protocol import ProtocolError, atomic_json

MAPS={"Route2":"pokered:ROUTE_2","ViridianForestSouthGate":"pokered:VIRIDIAN_FOREST_SOUTH_GATE","ViridianForest":"pokered:VIRIDIAN_FOREST","ViridianForestNorthGate":"pokered:VIRIDIAN_FOREST_NORTH_GATE","PewterCity":"pokered:PEWTER_CITY","PewterGym":"pokered:PEWTER_GYM","PewterMart":"pokered:PEWTER_MART","PewterPokecenter":"pokered:PEWTER_POKECENTER"}
ALL_NAMES=dict(PARCEL_NAMES,**MAPS)
BROCK="pokered:PEWTER_GYM:objects:1"
JR="pokered:PEWTER_GYM:objects:2"
FOREST=[f"pokered:VIRIDIAN_FOREST:objects:{i}"for i in (2,3,4)]


def boolean_map(value,label):
    if value==[]:return {}
    if not isinstance(value,dict)or any(not isinstance(k,str)or type(v)is not bool for k,v in value.items()):raise ProtocolError('invalid boolean map: '+label)
    return value


def finite(value,label,minimum=0):
    if type(value)not in (int,float)or not math.isfinite(value)or value<minimum:raise ProtocolError('invalid move metadata: '+label)
    return value


def move_score(move):
    """Transparent heuristic only; never predicts random rolls or outcomes."""
    if not isinstance(move,dict)or not isinstance(move.get('key'),str)or type(move.get('index'))is not int:raise ProtocolError('actual legal move descriptor required')
    pp=finite(move.get('pp'),'pp')
    power=finite(move.get('power'),'power');accuracy=finite(move.get('accuracy'),'accuracy')
    if move.get('category')not in {'physical','special','status'}:raise ProtocolError('unknown move category')
    if pp<=0 or move['category']=='status'or power<=0:return 0
    effectiveness=finite(move.get('effectiveness'),'effectiveness');stab=finite(move.get('stab'),'stab')
    attack=finite(move.get('attack'),'attack',minimum=0.001);defense=finite(move.get('defense'),'defense',minimum=0.001)
    return power*effectiveness*stab*attack/defense*(1 if accuracy==0 else min(100,accuracy)/100)


def choose_battle_medicine(mon, inventory):
    """Use observed stock and health; no damage prediction or outcome override."""
    hp=finite(mon.get('hp'),'hp');maximum=finite(mon.get('maxHP'),'maxHP',minimum=1)
    quantities=inventory.get('quantities',{})
    potion=quantities.get('potion',0)>0
    if hp<=0:return None
    if potion and hp*3<=maximum:return 'potion'
    if mon.get('status')in {'poison','badPoison'}and quantities.get('antidote',0)>0:return 'antidote'
    if potion and hp*3<maximum*2:return 'potion'
    return None


def choose_move(moves):
    moves=sequence(moves,'battle.legal_moves');indices=set();ranked=[]
    for move in moves:
        if not isinstance(move,dict)or type(move.get('index'))is not int:raise ProtocolError('actual legal move descriptor required')
        if move['index'] in indices or not 1<=move['index']<=4:raise ProtocolError('duplicate/invalid legal move index')
        indices.add(move['index']);ranked.append((move_score(move),-move['index'],move))
    if not ranked:return None
    best=max(ranked,key=lambda x:x[:2])
    if best[0]<=0:raise ProtocolError('driver has no supported damaging legal move; refusing status mash')
    return best[2]


def learn_decision(pending,known):
    """Keep coverage: replace status first, otherwise weakest raw power×accuracy."""
    def strength(move):
        if not isinstance(move,dict)or not isinstance(move.get('key'),str):raise ProtocolError('learning move metadata required')
        if move.get('category')not in {'physical','special','status'}:raise ProtocolError('unknown learning move category')
        power=finite(move.get('power'),'learning power');accuracy=finite(move.get('accuracy'),'learning accuracy')
        return power*(1 if accuracy==0 else min(100,accuracy)/100)if move.get('category')in {'physical','special'}else 0
    incoming=strength(pending);known=sequence(known,'learning.known_moves')
    if not known or len(known)>4:raise ProtocolError('invalid current learning moves')
    slot=min(range(len(known)),key=lambda i:(strength(known[i]),i))
    return slot+1 if incoming>strength(known[slot])else None


class SourceGeometry(Geometry):
    @classmethod
    def imported(cls,data,compact):
        if data.get('source_revision')!=REVISION or data.get('id')not in MAPS.values():raise ProtocolError('not pinned Pewter source geometry')
        width,height=data['dimensions']['cells'];runtime_width=max(13,width);pad=(runtime_width-width)//2
        if len(data['collision'])!=height or len(data['tile_ids'])!=height:raise ProtocolError('source dimensions mismatch')
        collision=[[1]*runtime_width for _ in range(height)];grass=[[False]*runtime_width for _ in range(height)];feet=[[None]*runtime_width for _ in range(height)]
        for y in range(height):
            if len(data['collision'][y])!=width or len(data['tile_ids'][y])!=width:raise ProtocolError('source row mismatch')
            for x,identity in enumerate(data['tile_ids'][y]):
                if type(identity)is not int or not 1<=identity<=len(data['grids']):raise ProtocolError('invalid source tile reference')
                terrain=data['grids'][identity-1]['terrain'];value=data['collision'][y][x]
                if type(value)is not int or value!=int(not terrain['land_passable']):raise ProtocolError('source collision disagreement')
                collision[y][x+pad]=1 if str(y*runtime_width+x+pad+1)in compact['blocked']else value
                grass[y][x+pad],feet[y][x+pad]=terrain['grass'],terrain['foot_tile']
        events={kind:[dict(e,x=e['x']+pad)for e in entries]for kind,entries in data['events'].items()}
        model=cls(data['id'],collision,grass,feet,data['directional_rules']['ledges'],data['directional_rules']['forbidden_tile_pairs'],events)
        model.source_data=data;model.padding=pad;model.counter_feet=tuple(data['tileset']['counter_tiles'])
        return model

    def path(self,origin,goals,occupied=(),allow_warps=()):
        goals=set(goals);occupied=set(occupied);blocked=occupied|(self.warps-set(allow_warps))|self.signs;blocked.discard(origin)
        if not self.inside(origin)or not goals or any(not self.inside(p)for p in goals):raise ProtocolError('source path endpoint outside map')
        queue=[(0,origin)];cost={origin:0};previous={}
        while queue:
            distance,point=heapq.heappop(queue)
            if distance!=cost[point]:continue
            if point in goals:
                route=[]
                while point!=origin:point,step=previous[point];route.append(step)
                return list(reversed(route))
            for direction,(dx,dy)in DIRECTIONS.items():
                step=self.terrain_step(point,direction)
                if not step or step.destination in blocked:continue
                if step.kind=='ledge'and(point[0]+dx,point[1]+dy)in occupied:continue
                x,y=step.destination;candidate=distance+(2 if step.kind=='ledge'else 1)+8*int(self.grass[y][x])
                if candidate<cost.get(step.destination,float('inf')):
                    cost[step.destination]=candidate;previous[step.destination]=(point,step);heapq.heappush(queue,(candidate,step.destination))
        raise ProtocolError(f'no source-valid Brock path in {self.name}: {origin}->{sorted(goals)}')


def load_models(build):
    build=Path(build);models=load_geometry(build);manifest=json.loads((build/'source-manifest.json').read_text())
    def read(relative):
        path=build/'Source'/relative
        if hashlib.sha256(path.read_bytes()).hexdigest()!=manifest.get(relative):raise ProtocolError('compiled source data hash mismatch: '+relative)
        return json.loads(path.read_text())
    compact=read('data/pewterSlice/compact.json');doors=read('data/pewterSlice/doors.json')
    if compact.get('source_revision')!=REVISION or doors.get('source_revision')!=REVISION:raise ProtocolError('wrong runtime source revision')
    for name,stable in MAPS.items():
        data=read('data/pewterSlice/'+name+'.json')
        if data['id']!=stable or compact['maps'][name]['source_sha256']!=hashlib.sha256((build/'Source/data/pewterSlice'/f'{name}.json').read_bytes()).hexdigest():raise ProtocolError('Pewter map identity mismatch')
        models[stable]=SourceGeometry.imported(data,compact['maps'][name])
    return models,doors['tilesets'],read('data/pewterSlice/trainers.json')['trainers']

class BrockJourney(ParcelJourney):
    def __init__(self,client,evidence,config,build_evidence=None,capture_dir=None):
        if config.get('starter','squirtle')!='squirtle':raise ProtocolError('bounded Brock driver requires Squirtle')
        super().__init__(client,evidence,config)
        self.build_evidence=Path(build_evidence or evidence);self.frames_dir=Path(capture_dir)if capture_dir else self.evidence/"frames";self.doors={};self.source_trainers={};self.learning_slot=None;self.allow_blackout=False;self.observed_moves={}
        self.summary.update(acceptance='pending',battles=[],learning=[],recoveries=[],natural=True)

    def dependencies(self):
        # Artifact output and immutable compiled Source may be in different
        # process directories. Never read gameplay state from the save files.
        self.models,self.doors,trainers=load_models(self.build_evidence)
        self.source_trainers={d['id']:d for d in trainers}
        self.send('snapshot')
        for path in ['session.flags.quest','session.flags.trainers','session.inventory','session.party','session.checkpoint']:
            if lookup(self.state,path)is None:raise ProtocolError('Brock runtime dependency missing: '+path)
        self.summary['build_evidence']=str(self.build_evidence)
        dependency={'source_revision':REVISION,'status':'native journey acceptance pending','build_id':self.client.identity['build_id'],
                    'map_dimensions':{key:[model.width,model.height]for key,model in self.models.items()},
                    'required':['battle.legal_moves','learning.move_info','learning.known_moves','last_battle_outcome.payout','last_battle_outcome.money_delta','event.trainer']}
        atomic_json(self.evidence/'brock-dependencies.json',dependency);self.summary['brock_dependencies']=dependency

    def defeated(self,id):return boolean_map(lookup(self.state,'session.flags.trainers'),'trainers').get(id,False)

    def learning(self):
        for _ in range(160):
            if self.state.get('root')!='learning':return
            phase=lookup(self.state,'learning.phase')
            for info in sequence(lookup(self.state,'learning.known_moves')or [],'learning.known_moves'):self.observed_moves[info['key']]=info
            if phase=='message':
                self.send('press a')if lookup(self.state,'learning.dialog_ready')else self.send('wait 3')
            elif phase=='ask':
                pending=lookup(self.state,'learning.move_info');known=lookup(self.state,'learning.known_moves')
                self.learning_slot=learn_decision(pending,known)
                self.summary['learning'].append({'move':pending,'replace_slot':self.learning_slot,'battle_enemy':lookup(self.state,'battle.enemy.species')})
                self.select('learning.selected',1 if self.learning_slot else 2);self.send('press a')
            elif phase=='replace':
                if self.learning_slot is None:raise ProtocolError('replacement appeared without explicit learning decision')
                self.select('learning.selected',self.learning_slot);self.send('press a')
            elif phase in {'confirm','stop'}:
                self.select('learning.selected',1);self.send('press a')
            elif phase=='idle':self.send('wait 2')
            else:raise ProtocolError('unknown explicit learning phase: '+str(phase))
        raise ProtocolError('learning exceeded bounded semantic inputs')

    def evolution(self):
        # Current native overlay accepts cancellation only while animating.
        # Announce/result are real dialogs and must be acknowledged with A.
        for _ in range(180):
            if self.state.get('root')!='evolution':return
            phase=lookup(self.state,'evolution.phase')
            if lookup(self.state,'evolution.result')=='failed':raise ProtocolError('actual evolution failed')
            if phase in {'announce','result'}:
                self.send('press a')if lookup(self.state,'evolution.dialog_ready')else self.send('wait 3')
            elif phase=='animate':
                self.send('press b')if lookup(self.state,'evolution.can_cancel')else self.send('wait 3')
            elif phase=='closed':self.send('wait 2')
            else:raise ProtocolError('unknown native evolution phase: '+str(phase))
        raise ProtocolError('evolution UI exceeded bounded inputs')

    def battle(self,name,strategy='attack',expected=None):
        self.require(root='battle');self.await_value('battle.introPhase','ready')
        before_money=self.inventory()['money'];trainer=lookup(self.state,'battle.trainerName');terminal=None;choices=[]
        trainer_id=lookup(self.state,'event.id');source=self.source_trainers.get(trainer_id)
        expected_payout=source['payout'] if source else 175 if trainer=='BLUE'and lookup(self.state,'story.stage')=='rival_fight'else None
        self.checkpoint(name+'-intro')
        for _ in range(1200):
            root=self.state.get('root')
            if root=='learning':self.learning();continue
            if root=='evolution':self.evolution();continue
            if root=='party':
                members=self.party();active=lookup(self.state,'session.party.active')
                index=next((i for i,m in enumerate(members,1)if i!=active and m['hp']>0),None)
                if index is None:raise ProtocolError('forced switch has no conscious reserve')
                self.select('party_ui.selected',index);self.send('press a');continue
            if root!='battle':break
            battle=self.state['battle'];phase=battle['phase']
            for info in sequence(battle.get('legal_moves',[]),'battle.legal_moves'):self.observed_moves[info['key']]=info
            if phase=='ended':
                terminal={'kind':battle['outcome'],'player':battle['player'],'enemy':battle['enemy']};self.checkpoint(name+'-terminal');self.send('press a')
            elif phase=='script':self.send('wait 12','press a')if battle.get('waiting')else self.send('wait 2')
            elif phase=='command':
                if not battle.get('inMoveSelect'):
                    if not lookup(self.state,'battle.menu.active'):
                        self.send('wait 2');continue
                    options=sequence(lookup(self.state,'battle.menu.options'),'battle.menu.options')
                    medicine=choose_battle_medicine(battle['player'],self.inventory())
                    if medicine:
                        self.battle_medicine(medicine,options)
                        continue
                    fight=[i for i,v in enumerate(options,1)if v=='FIGHT'or isinstance(v,dict)and v.get('action')=='fight']
                    if len(fight)!=1:raise ProtocolError('battle requires exactly one real FIGHT action')
                    self.select('battle.menu.selected',fight[0]);self.send('press a')
                else:
                    selected=choose_move(lookup(self.state,'battle.legal_moves'))
                    if selected is None:raise ProtocolError('empty legal menu must use production Struggle via FIGHT')
                    self.select_grid('battle.moveMenu.selected',selected['index'],lookup(self.state,'battle.moveMenu.columns'))
                    choices.append({'enemy':battle['enemy']['species'],'move':selected,'heuristic':move_score(selected)})
                    self.send('press a')
            else:raise ProtocolError('unknown battle phase: '+str(phase))
        else:raise ProtocolError('battle exceeded1200 observed semantic inputs')
        if terminal is None:raise ProtocolError('battle exited without observed terminal phase')
        outcome=lookup(self.state,'last_battle_outcome')
        if not isinstance(outcome,dict)or outcome.get('kind')!=terminal['kind']:raise ProtocolError('missing matching terminal outcome diagnostic')
        if expected=='win'and not outcome.get('won')or expected=='loss'and outcome.get('won'):raise ProtocolError('unexpected actual battle result')
        if trainer and outcome.get('won'):
            if type(outcome.get('payout'))is not int or expected_payout is None or outcome['payout']!=expected_payout:raise ProtocolError('trainer payout differs from actual pinned source trainer')
            if self.inventory()['money']-before_money!=outcome.get('money_delta'):raise ProtocolError('trainer money delta diagnostic mismatch')
        self.summary['battles'].append({'name':name,'trainer':trainer,'terminal':terminal,'outcome':outcome,'choices':choices})
        if outcome.get('blackout')and name!='rival'and not self.allow_blackout:raise ProtocolError('real blackout: acceptance stopped at checkpoint; evidence retained')
        if name=='rival'and self.state.get('root')=='dialog':self.dialog()
        return bool(outcome.get('won')),terminal['player']['hp']<=0

    def battle_medicine(self,item,options):
        before=self.quantity(item)
        bag=[i for i,value in enumerate(options,1)if value=='BAG'or isinstance(value,dict)and value.get('action')=='bag']
        if len(bag)!=1:raise ProtocolError('battle requires exactly one real BAG action')
        self.select('battle.menu.selected',bag[0]);self.send('press a');self.require(root='bag')
        slots=sequence(self.inventory()['slots'],'inventory.slots')
        index=next((i for i,row in enumerate(slots,1)if row['id']==item),None)
        if index is None:raise ProtocolError('observed battle medicine no longer in actual bag')
        self.select('bag.selected',index);self.send('press a');self.require(root='party')
        self.select('party_ui.selected',lookup(self.state,'session.party.active'));self.send('press a')
        self.require(root='battle',**{'inventory.quantities.'+item:before-1})
        self.summary['recoveries'].append({'kind':'battle-medicine','item':item,'party':self.party()})
        self.checkpoint('brock-battle-medicine-'+str(len(self.summary['recoveries'])))

    def select_grid(self,path,index,columns):
        if type(columns)is not int or not 1<=columns<=4:raise ProtocolError('move menu requires real column count')
        visited=set()
        for _ in range(12):
            current=lookup(self.state,path)
            if current==index:return
            if type(current)is not int or current in visited:raise ProtocolError('move menu navigation cycled')
            visited.add(current);self.send('press '+('right'if(current-1)%columns!=(index-1)%columns else 'down'))
        raise ProtocolError('move menu bound exceeded')

    def drain(self,stop_phase=None):
        for _ in range(1200):
            root=self.state.get('root')
            if root=='battle':
                if lookup(self.state,'battle.trainerName'):self.battle('source-trainer-'+str(len(self.summary['battles'])),expected='win')
                else:self.flee()
            elif root=='learning':self.learning()
            elif root=='evolution':self.evolution()
            elif root=='event'and lookup(self.state,'event.phase')in {'trainer-notice','trainer-approach'}:
                phase=lookup(self.state,'event.phase');key=(lookup(self.state,'event.id'),phase)
                if key not in self.event_recordings:
                    self.event_recordings.add(key);self.summary.setdefault('trainer_motion',[]).append(self.state['event'])
                    self.send('record brock-trainer-motion-'+str(len(self.event_recordings))+' 70');continue
                self.send('wait 1')
            else:
                # Base drain handles actual parcel/healing/dialog/menu semantics;
                # intercept root battle/learning by taking one bounded UI step.
                if root=='dialog':self.dialog()
                elif root=='overworld':
                    if self.state.get('overworld')=='explore'and lookup(self.state,'player.settled'):return
                    self.send('wait 3')
                elif root=='event':
                    phase=lookup(self.state,'event.phase')
                    if phase=='failed':raise ProtocolError('source event failed: '+str(lookup(self.state,'event.waiting')))
                    if phase==stop_phase:return
                    if phase=='heal-confirm':raise ProtocolError('healing requires explicit decision')
                    key=(lookup(self.state,'event.id'),phase)
                    if phase in {'move','oak-arrival','oak-departure','heal-animation'}and key not in self.event_recordings:
                        self.event_recordings.add(key);frames=40 if phase.startswith('oak-')else 24 if phase=='move'else 15*len(self.party())+56
                        self.send('record brock-event-'+str(len(self.event_recordings))+' '+str(frames));continue
                    self.send('wait 3')
                elif root in {'shop','pause','bag'}:return
                else:raise ProtocolError('unexpected Brock journey root: '+str(root))
        raise ProtocolError('event drain bound exceeded')

    def project(self,direction):
        model=self.model();point=self.position();source=getattr(model,'source_data',{})
        cardinal={'up':'north','down':'south','left':'west','right':'east'}
        header=next((c for c in source.get('connections',[])if c['direction']==cardinal[direction]),None)
        if header and header['target_header']in ALL_NAMES:
            target_id=ALL_NAMES[header['target_header']];target=self.models[target_id]
            if direction not in {'up','down'}:raise ProtocolError('bounded slice has no implemented horizontal connection')
            if point[1]!=(0 if direction=='up'else model.height-1):raise ProtocolError('connection requires real edge cell')
            target_point=(point[0]+header['entry_lateral_adjustment_cells'],target.height-1 if direction=='up'else 0)
            if not target.inside(target_point)or target.collision[target_point[1]][target_point[0]]:raise ProtocolError('source connection target blocked')
            return target_id,target_point
        return project_connection(self.models,self.state['zone_id'],point,direction)

    def cross(self,direction,zone,destination):
        if self.project(direction)!=(zone,destination):raise ProtocolError('requested crossing differs from source header')
        self.send('press '+direction,'wait 12');self.drain();self.require(zone_id=zone,**{'player.x':destination[0],'player.y':destination[1]})

    def warp_projection(self,event):
        destination=event['destination'];constant=destination.get('map')
        if destination['kind']=='last_outdoor_map':
            constant='ROUTE_2'if self.state['zone_id']in {MAPS['ViridianForestSouthGate'],MAPS['ViridianForestNorthGate']}else 'PEWTER_CITY'if self.state['zone_id'].startswith('pokered:PEWTER_')else 'VIRIDIAN_CITY'
        target=next((m for m in self.models.values()if getattr(m,'source_data',{}).get('source_map_constant')==constant),None)
        if target is None:raise ProtocolError('unsupported source warp: '+str(constant))
        arrival=target.events['warps'][destination['warp_index']-1];x,y=arrival['x'],arrival['y']
        if target.feet[y][x]in self.doors.get(target.source_data['tileset']['constant'],[]):y+=1
        if not target.inside((x,y))or target.collision[y][x]:raise ProtocolError('source warp arrival blocked')
        return target.name,(x,y)

    def warp(self,target_id):
        candidates=[]
        for event in self.model().events['warps']:
            try:projection=self.warp_projection(event)
            except ProtocolError:continue
            if projection[0]==target_id and not self.model().collision[event['y']][event['x']]:candidates.append((event,projection))
        if not candidates:raise ProtocolError('no supported source warp to '+target_id)
        # Adjacent warp cells can have different reachable approaches. A sign
        # below one Forest exit makes its Manhattan-nearest cell reachable only
        # through the other warp, which would already change maps. Choose an
        # actual source-valid route with all other warp cells still blocked.
        reachable=[]
        model=self.model()
        for event,projection in candidates:
            point=(event['x'],event['y'])
            try:route=model.path(self.position(),{point},self.occupied(),allow_warps={point})
            except ProtocolError as error:
                if str(error).startswith('no source-valid '):continue
                raise
            cost=sum((2 if step.kind=='ledge'else 1)+8*int(model.grass[step.destination[1]][step.destination[0]])for step in route)
            reachable.append((cost,event,projection))
        if not reachable:raise ProtocolError('no reachable source warp to '+target_id)
        _,event,projection=min(reachable,key=lambda entry:entry[0])
        interior=self.state['zone_id']not in {PARCEL_NAMES['Route1'],PARCEL_NAMES['ViridianCity'],MAPS['Route2'],MAPS['ViridianForest'],MAPS['PewterCity']}
        self.navigate((event['x'],event['y']),transition=target_id)
        if self.state['zone_id']!=target_id:
            if not interior or event['y']!=self.model().height-1:raise ProtocolError('step warp failed to activate')
            self.send('press down','wait 15');self.drain()
        self.require(zone_id=target_id,**{'player.x':projection[1][0],'player.y':projection[1][1]})

    def center(self,city):
        center=MAPS['PewterPokecenter']if city==MAPS['PewterCity']else PARCEL_NAMES['ViridianPokecenter']
        if self.state['zone_id']==city:self.warp(center)
        self.interact(source_id=center+':objects:1',stop_phase='heal-confirm')
        self.select('event.menu.selected',1);self.send('press a');self.drain()
        for member in self.party():
            if member['hp']!=member['maxHP']or member['status']not in {'none',None}or member['pp']!=member['maxPP']:raise ProtocolError('real Center healing failed')
        self.summary['recoveries'].append({'kind':'Center','zone':center,'checkpoint':lookup(self.state,'session.checkpoint')})
        self.warp(city)

    def buy_item(self,clerk,item,count,unit_price):
        before=self.inventory()['money'];quantity=self.quantity(item)
        if before<unit_price*count:raise ProtocolError('observed money cannot fund requested source shop recovery')
        self.interact(source_id=clerk);self.require(root='shop',**{'shop.phase':'mode'})
        self.select('shop.menu.selected',1);self.send('press a');visited=set()
        for _ in range(20):
            current=lookup(self.state,'shop.item')
            if current==item:break
            if current in visited:raise ProtocolError('required item absent from actual source stock')
            visited.add(current);self.send('press down')
        else:raise ProtocolError('shop browse bound exceeded')
        self.send('press a');self.require(**{'shop.phase':'quantity'})
        for _ in range(count-1):self.send('press up')
        self.require(**{'shop.quantity':count});self.send('press a');self.require(**{'shop.phase':'confirm'})
        self.select('shop.menu.selected',1);self.send('press a');self.require(**{'shop.phase':'result'})
        if self.quantity(item)!=quantity+count or self.inventory()['money']!=before-unit_price*count:raise ProtocolError('shop purchase not reflected atomically')
        self.send('press a','press b','press b');self.drain()

    def medicine(self,item):
        quantity=self.quantity(item)
        if quantity<=0:raise ProtocolError('required field medicine absent')
        self.send('press b');self.pause_option('ITEM');self.send('press a')
        index=next(i for i,s in enumerate(sequence(self.inventory()['slots'],'inventory.slots'),1)if s['id']==item)
        self.select('bag.selected',index);self.send('press a');self.require(**{'bag.phase':'actions'})
        self.select('bag.menu.selected',1);self.send('press a');self.require(root='party')
        self.select('party_ui.selected',lookup(self.state,'session.party.active'));self.send('press a');self.require(root='bag',**{'bag.phase':'message'})
        if self.quantity(item)!=quantity-1:raise ProtocolError('field medicine did not consume exactly one real item')
        self.send('press a','press b');self.drain();self.require(root='overworld')
        self.summary['recoveries'].append({'kind':'field-medicine','item':item,'party':self.party()})

    def field_recover(self):
        mon=lookup(self.state,'pokemon')
        if mon['status']in {'poison','badPoison'}and self.quantity('antidote'):self.medicine('antidote');mon=lookup(self.state,'pokemon')
        if mon['hp']*3<mon['maxHP']*2 and self.quantity('potion'):self.medicine('potion');mon=lookup(self.state,'pokemon')
        damage_pp=sum(mon['pp'].get(key,0)for key,info in self.observed_moves.items()if info.get('category')in {'physical','special'}and info.get('power',0)>0)
        if mon['hp']*3<mon['maxHP']*2 or mon['status']not in {'none',None}or damage_pp<8:
            original=self.state['zone_id'];point=self.position()
            if original==MAPS['ViridianForest']:
                self.warp(MAPS['ViridianForestSouthGate']);self.warp(MAPS['Route2']);self.navigate((8,71));self.cross('down',PARCEL_NAMES['ViridianCity'],(18,0))
                self.center(PARCEL_NAMES['ViridianCity']);self.navigate((18,0));self.cross('up',MAPS['Route2'],(8,71));self.warp(MAPS['ViridianForestSouthGate']);self.warp(original)
            elif original==MAPS['PewterGym']:
                self.warp(MAPS['PewterCity']);self.center(MAPS['PewterCity']);self.warp(original)
            else:raise ProtocolError('no reviewed real-input Center recovery from current map')
            self.navigate(point)

    def interaction_target(self,name=None,source_id=None):
        if source_id:
            source=next((e for e in self.model().events['objects']if e['id']==source_id),None)
            if source is None:raise ProtocolError('unknown pinned interaction ID: '+source_id)
            npc=next((n for n in sequence(self.state.get('npcs',[]),'npcs')if n.get('source_event_id')==source_id),None)
        else:
            npc=next((n for n in sequence(self.state.get('npcs',[]),'npcs')if n.get('name')==name),None)
        if npc is None:raise ProtocolError('current interaction actor missing: '+str(source_id or name))
        return npc['x'],npc['y']

    def interact(self,name=None,source_id=None,stop_phase=None):
        # A sight approach, battle return or wandering step can relocate the
        # actor while we navigate. Every real step replans the target as well
        # as the path; never face an obsolete empty cell.
        trainer=source_id in self.source_trainers
        previously_defeated=trainer and self.defeated(source_id)
        zone=self.state['zone_id']
        for _ in range(self.config.get('max_steps',5000)):
            self.require(root='overworld',overworld='explore',**{'player.settled':True})
            if self.state['zone_id']!=zone:raise ProtocolError('interaction left its source map')
            if trainer and not previously_defeated and self.defeated(source_id):return
            target=self.interaction_target(name,source_id);approaches=self.model().approaches(target)
            point=self.position()
            if point not in approaches:
                route=self.model().path(point,set(approaches),self.occupied())
                self.step(route[0]);continue
            direction=approaches[point]
            if lookup(self.state,'player.facing')!=direction:
                terrain=self.model().terrain_step(point,direction)
                self.send('press '+direction,'wait 9');self.drain()
                if self.state['zone_id']!=zone:raise ProtocolError('interaction facing crossed an unexpected map boundary')
                actual=self.position()
                if actual!=point and (terrain is None or actual!=terrain.destination):
                    raise ProtocolError('interaction follow step differs from source terrain')
                continue
            self.send('press a')
            dispatched=self.state.get('root')!='overworld'
            self.drain(stop_phase=stop_phase)
            if dispatched:return
        raise ProtocolError('moving interaction target exceeded source navigation bound')

    def repeat_trainer(self,id):
        before=self.inventory()['money'];battles=len(self.summary['battles']);self.interact(source_id=id)
        if len(self.summary['battles'])!=battles or self.inventory()['money']!=before or not self.defeated(id):raise ProtocolError('defeated trainer repeated battle/payout or lost flag')

    def natural(self):
        super().natural() # Initial seed reset only, exact passed parcel sequence.
        self.summary['acceptance']='parcel complete; Brock progression pending'
        self.warp(PARCEL_NAMES['ViridianCity']);self.warp(PARCEL_NAMES['ViridianMart'])
        self.buy_item('pokered:VIRIDIAN_MART:objects:1','antidote',3,100)
        self.warp(PARCEL_NAMES['ViridianCity'])
        self.navigate((18,0));self.cross('up',MAPS['Route2'],(8,71))
        self.warp(MAPS['ViridianForestSouthGate']);self.warp(MAPS['ViridianForest'])
        # Source visible Potion: a real interaction rather than a bag fixture.
        self.interact(source_id='pokered:VIRIDIAN_FOREST:objects:6')
        for id in FOREST:
            self.field_recover()
            if not self.defeated(id):self.interact(source_id=id)
            if not self.defeated(id):raise ProtocolError('source Forest trainer was not actually defeated: '+id)
            self.repeat_trainer(id);self.checkpoint('forest-defeated-'+id.rsplit(':',1)[1])
        self.warp(MAPS['ViridianForestNorthGate']);self.warp(MAPS['Route2'])
        self.navigate((8,0));self.cross('up',MAPS['PewterCity'],(18,35));self.center(MAPS['PewterCity'])
        self.warp(MAPS['PewterMart']);self.buy_item('pokered:PEWTER_MART:objects:1','potion',3,300);self.warp(MAPS['PewterCity'])
        self.warp(MAPS['PewterGym']);self.interact(source_id=JR)
        if not self.defeated(JR):raise ProtocolError('source Jr trainer victory missing')
        self.repeat_trainer(JR);self.field_recover();self.interact(source_id=BROCK)
        if not self.defeated(BROCK)or not self.flag('BADGE_BOULDER')or not self.flag('EVENT_GOT_TM34')or self.quantity('tm34')!=1:raise ProtocolError('Brock reward transaction incomplete')
        self.repeat_trainer(BROCK);self.checkpoint('brock-badge-tm34')
        self.save();self.write_receipt();self.summary.update(acceptance='Brock path completed and saved; restart acceptance pending',natural=True,forbidden_shortcuts=False)

    def save(self):
        self.send('press b');self.require(root='pause',**{'pause.phase':'menu'})
        self.pause_option('SAVE');self.send('press a');self.require(**{'pause.phase':'save'})
        self.pause_option('YES');self.send('press a');self.require(root='dialog',**{'pause.lastSave.ok':True})
        self.dialog();self.require(root='overworld');self.checkpoint('brock-game-saved'if self.defeated(BROCK)else 'parcel-game-saved')

    def receipt_state(self):
        return {'zone_id':self.state['zone_id'],'player':{k:self.state['player'][k]for k in ['x','y','facing']},
                'flags':{k:boolean_map(v,k)for k,v in lookup(self.state,'session.flags').items()},
                'inventory':self.inventory(),'party':lookup(self.state,'session.party'),'checkpoint':lookup(self.state,'session.checkpoint')}

    def write_receipt(self):
        packet={'schema':1,'kind':'brock-saved','build_id':self.client.identity['build_id'],'session_id':self.client.identity['session_id'],'state':self.receipt_state()}
        path=self.evidence/'journey-receipt.json';atomic_json(path,packet)
        self.summary['receipt']={'path':'journey-receipt.json','sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

    def continue_saved(self,prior):
        if not isinstance(prior,dict)or prior.get('schema')!=1 or prior.get('kind')!='brock-saved'or prior.get('build_id')!=self.client.identity['build_id']or prior.get('session_id')!=self.client.identity['session_id']:raise ProtocolError('missing or wrong-build Brock continuation receipt')
        self.dependencies();self.require(root='title',**{'title.phase':'menu'})
        options=sequence(lookup(self.state,'title.menu.options'),'title.menu.options')
        if options.count('CONTINUE')!=1:raise ProtocolError('title must expose exactly one real CONTINUE')
        self.select('title.selected',options.index('CONTINUE')+1);self.send('press a');self.drain()
        if self.receipt_state()!=prior['state']:raise ProtocolError('Continue differs from prior immutable journey receipt')
        if not all(self.defeated(id)for id in FOREST+[JR,BROCK]):raise ProtocolError('Continue lost source trainer defeat flags')
        self.repeat_trainer(BROCK);self.checkpoint('brock-continued-no-repeat');self.write_receipt();self.summary.update(acceptance='Brock saved state continued across actual owned process restart',natural=True)



    def supplementary(self):
        self.dependencies();case=self.config.get('case');id=self.config.get('trainer_id',BROCK)
        definition=self.source_trainers.get(id)
        if not definition:raise ProtocolError('supplementary source trainer ID required')
        model=self.models[definition['map_id']];event=next(e for e in model.events['objects']if e['id']==id)
        occupied={(e['x'],e['y'])for e in model.events['objects']}
        entry=next(((event['x']+dx,event['y']+dy)for dx,dy in [(0,1),(1,0),(0,-1),(-1,0)]if model.inside((event['x']+dx,event['y']+dy))and not model.collision[event['y']+dy][event['x']+dx]and(event['x']+dx,event['y']+dy)not in occupied),None)
        if entry is None:raise ProtocolError('no source-valid supplementary trainer approach')
        key={'pokered:VIRIDIAN_FOREST':'kanto_viridian_forest','pokered:PEWTER_GYM':'kanto_pewter_gym'}[definition['map_id']]
        options={'intro':'skip','opening':False,'zone':key,'entry':{'x':entry[0],'y':entry[1],'facing':'up'},'player_pokemon':{'species':'squirtle','level':30}}
        if case=='tm-full-retry':
            ids=['potion','superPotion','hyperPotion','maxPotion','fullRestore','revive','maxRevive','antidote','burnHeal','iceHeal','awakening','parlyzHeal','fullHeal','ether','maxEther','elixir','maxElixir','pokeBall','greatBall','ultraBall']
            options['inventory']={'money':3000,'slots':[{'id':item,'quantity':1}for item in ids]}
        elif case=='blackout':options['player_pokemon']={'species':'squirtle','level':1,'hp':1};self.allow_blackout=True
        elif case=='failed-sight':options['zone']='kanto_viridian_forest';options['entry']={'x':25,'y':33,'facing':'up'}
        elif case!='trainer':raise ProtocolError('unknown supplementary source case')
        self.initializing=True
        try:self.reset(**options)
        finally:self.initializing=False
        self.summary.update(natural=False,supplementary=True)
        if case=='failed-sight':
            before=json.loads(json.dumps(self.state['rng']));money=self.inventory()['money'];self.send('wait 60');self.require(root='overworld',**{'event.trainer.phase':'idle'})
            if self.state['rng']!=before or self.inventory()['money']!=money or self.defeated(FOREST[0]):raise ProtocolError('failed sight changed rules/flags/money')
        elif case=='blackout':
            self.face('up');self.send('press a');self.dialog();self.battle('source-blackout',expected='loss');self.drain()
            if self.defeated(BROCK)or self.flag('BADGE_BOULDER')or self.inventory()['money']!=1500:raise ProtocolError('trainer loss changed defeat/reward flags or wrong half-money')
            checkpoint=lookup(self.state,'session.checkpoint');self.require(zone_id=checkpoint['zone_id'],**{'player.x':checkpoint['x'],'player.y':checkpoint['y']})
        else:
            self.interact(source_id=id)
            if not self.defeated(id):raise ProtocolError('actual source trainer victory missing')
            if case=='tm-full-retry':
                if not self.flag('BADGE_BOULDER')or self.flag('EVENT_GOT_TM34')or self.quantity('tm34'):raise ProtocolError('full bag consumed TM eligibility or lost badge')
                money=self.inventory()['money'];battles=len(self.summary['battles']);self.toss_single();self.interact(source_id=BROCK)
                if self.quantity('tm34')!=1 or not self.flag('EVENT_GOT_TM34')or self.inventory()['money']!=money or len(self.summary['battles'])!=battles:raise ProtocolError('TM retry duplicated battle/payout or failed receipt')
            self.repeat_trainer(id)
        self.checkpoint('supplementary-'+case);self.summary['acceptance']='supplementary source case complete; not natural campaign acceptance'

def run(client,scenario,evidence,build_evidence=None,prior_receipt=None,capture_dir=None):
    config=scenario['journey'];journey=BrockJourney(client,evidence,config,build_evidence,capture_dir)
    try:
        if config.get('name')=='brock-natural':journey.natural()
        elif config.get('name')=='brock-continue':journey.continue_saved(prior_receipt)
        elif config.get('name')=='brock-source-supplementary':journey.supplementary()
        else:raise ProtocolError('unsupported bounded Brock journey name')
    except BaseException as error:
        journey.summary.update(ok=False,error=str(error),last_snapshot=journey.state);atomic_json(Path(evidence)/'journey-summary.json',journey.summary);raise
    journey.summary.update(ok=True,last_snapshot=journey.state);atomic_json(Path(evidence)/'journey-summary.json',journey.summary);return journey.summary
