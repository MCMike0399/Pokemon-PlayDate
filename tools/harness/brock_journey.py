"""Bounded source-driven Brock journey; receives an already-owned Client.

No process launch, mailbox access, RNG simulation, Source writes or save copying.
Natural mode permits only the inherited first new-game seed fixture.
"""
import hashlib
import copy
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
FAMILIES={'squirtle':{'squirtle','wartortle','blastoise'},'bulbasaur':{'bulbasaur','ivysaur','venusaur'},'charmander':{'charmander','charmeleon','charizard'}}
FIXED_DAMAGE={'dragonRage':40,'sonicBoom':20}
SOURCE_SHOP_STOCK={
    'pokered:VIRIDIAN_MART:objects:1':('pokeBall','antidote','parlyzHeal','burnHeal'),
    'pokered:PEWTER_MART:objects:1':('pokeBall','potion','escapeRope','antidote','burnHeal','awakening','parlyzHeal'),
}

def require_shop_stock(clerk,item):
    if clerk not in SOURCE_SHOP_STOCK or item not in SOURCE_SHOP_STOCK[clerk]:
        raise ProtocolError('planned purchase absent from pinned Blue source stock: '+str(clerk)+':'+str(item))

class NaturalBlackout(ProtocolError):
    """A genuine terminal loss; only an explicit bounded recovery may resume."""



def training_lane(model,origin,occupied):
    candidates=[]
    for y in range(model.height):
        for x in range(model.width):
            point=(x,y)
            if not model.grass[y][x]or model.collision[y][x]or point in occupied:continue
            for direction,(dx,dy)in DIRECTIONS.items():
                other=(x+dx,y+dy)
                if not model.inside(other)or not model.grass[other[1]][other[0]]or other in occupied:continue
                forward=model.terrain_step(point,direction);back=model.terrain_step(other,{'up':'down','down':'up','left':'right','right':'left'}[direction])
                if not forward or not back or forward.destination!=other or back.destination!=point or forward.kind=='ledge'or back.kind=='ledge':continue
                try:route=model.path(origin,{point},occupied)
                except ProtocolError:continue
                candidates.append((len(route),point,other))
    if not candidates:raise ProtocolError('no reachable reciprocal source grass lane')
    _,a,b=min(candidates);return a,b


def boolean_map(value,label):
    if value==[]:return {}
    if not isinstance(value,dict)or any(not isinstance(k,str)or type(v)is not bool for k,v in value.items()):raise ProtocolError('invalid boolean map: '+label)
    return value


def finite(value,label,minimum=0):
    if type(value)not in (int,float)or not math.isfinite(value)or value<minimum:raise ProtocolError('invalid move metadata: '+label)
    return value


def move_score(move,level=None):
    """Transparent heuristic only; never predicts random rolls or outcomes."""
    if not isinstance(move,dict)or not isinstance(move.get('key'),str)or type(move.get('index'))is not int:raise ProtocolError('actual legal move descriptor required')
    pp=finite(move.get('pp'),'pp')
    power=finite(move.get('power'),'power');accuracy=finite(move.get('accuracy'),'accuracy')
    if move.get('power_rule'):
        power=finite(move.get('effective_power'),'effective_power')
    if move.get('category')not in {'physical','special','status'}:raise ProtocolError('unknown move category')
    if pp<=0 or move['category']=='status':return 0
    if move.get('ohko')or move['key']in {'hornDrill','fissure','guillotine','sheerCold'}:return 0 # Dedicated OHKO path is not this damage heuristic.
    effectiveness=finite(move.get('effectiveness'),'effectiveness');stab=finite(move.get('stab'),'stab')
    if effectiveness==0:return 0
    accuracy=finite(move.get('effective_accuracy',accuracy),'effective_accuracy')
    if not 0<=accuracy<=100:raise ProtocolError('invalid effective accuracy')
    if move.get('damage_rule')=='endeavor':return finite(move.get('fixed_damage'),'fixed_damage')*accuracy/100
    if move['key'] in FIXED_DAMAGE:
        if 'effective_accuracy'not in move:raise ProtocolError('fixed damage requires actual effective_accuracy')
        return FIXED_DAMAGE[move['key']]*accuracy/100
    if power<=0:return 0
    attack=finite(move.get('attack'),'attack',minimum=0.001);defense=finite(move.get('defense'),'defense',minimum=0.001)
    base=power*attack/defense if level is None else ((2*finite(level,'level',minimum=1)/5+2)*power*attack/defense/50+2)
    return base*effectiveness*stab*(1 if move.get('accuracy')==0 else accuracy/100)


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


def choose_move(moves,level=None):
    moves=sequence(moves,'battle.legal_moves');indices=set();ranked=[]
    for move in moves:
        if not isinstance(move,dict)or type(move.get('index'))is not int:raise ProtocolError('actual legal move descriptor required')
        if move['index'] in indices or not 1<=move['index']<=4:raise ProtocolError('duplicate/invalid legal move index')
        indices.add(move['index']);ranked.append((move_score(move,level),-move['index'],move))
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
        if move.get('category')=='status':return 0
        return FIXED_DAMAGE.get(move['key'],power)*(1 if accuracy==0 else min(100,accuracy)/100)
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
        if config.get('starter','squirtle')not in FAMILIES:raise ProtocolError('Brock driver requires an original Kanto starter')
        for key,low,high in [('training_level',8,20),('max_training_battles',1,256),('max_capture_attempts',1,24),('max_blackouts',0,2)]:
            if key in config and (type(config[key])is not int or not low<=config[key]<=high):raise ProtocolError('invalid bounded Brock option: '+key)
        if config.get('evolution_policy','accept')not in {'accept','cancel'}:raise ProtocolError('invalid evolution policy')
        super().__init__(client,evidence,config)
        self.starter=config.get('starter','squirtle')
        self.build_evidence=Path(build_evidence or evidence);self.frames_dir=Path(capture_dir)if capture_dir else self.evidence/"frames";self.doors={};self.source_trainers={};self.learning_slot=None;self.allow_blackout=False;self.observed_moves={}
        self.training_mode=None;self.capture_pending=False;self.switch_back=False;self.switch_reset_attempts=set();self.blackouts=0;self.training_target=None
        self.summary.update(acceptance='pending',battles=[],learning=[],recoveries=[],natural=True,captures=[],party_changes=[],evolutions=[],training=[],blackouts=[])
        self.summary['preparation_policy']={
            'training_level':config.get('training_level',16),
            'purpose':'deliberately trained evolution witness' if config.get('training_level',16)>=16 else 'bounded campaign-path preparation',
            'normal_pacing_or_balance_certified':False,
        }

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
                    'required':['battle.legal_moves[*].effective_accuracy','battle.player.stat_stages.acc','battle.legal_moves','learning.move_info','learning.known_moves','last_battle_outcome.payout','last_battle_outcome.money_delta','event.trainer']}
        atomic_json(self.evidence/'brock-dependencies.json',dependency);self.summary['brock_dependencies']=dependency

    def defeated(self,id):return boolean_map(lookup(self.state,'session.flags.trainers'),'trainers').get(id,False)

    def learning(self):
        def capture():
            entries=self.summary.setdefault('learning_captures',[])
            phase=lookup(self.state,'learning.phase')
            label='brock-learning-'+str(len(entries)+1).zfill(3)+'-'+phase
            self.checkpoint(label)
            entries.append({'name':label,'learning':copy.deepcopy(self.state['learning'])})
        for _ in range(160):
            if self.state.get('root')!='learning':return
            phase=lookup(self.state,'learning.phase')
            for info in sequence(lookup(self.state,'learning.known_moves')or [],'learning.known_moves'):self.observed_moves[info['key']]=info
            if phase=='message':
                if lookup(self.state,'learning.dialog_ready'):
                    capture();self.send('press a')
                else:self.send('wait 3')
            elif phase=='ask':
                pending=lookup(self.state,'learning.move_info');known=lookup(self.state,'learning.known_moves')
                self.learning_slot=learn_decision(pending,known)
                self.summary['learning'].append({'move':pending,'replace_slot':self.learning_slot,'battle_enemy':lookup(self.state,'battle.enemy.species')})
                self.select('learning.selected',1 if self.learning_slot else 2);capture();self.send('press a')
            elif phase=='replace':
                if self.learning_slot is None:raise ProtocolError('replacement appeared without explicit learning decision')
                self.select('learning.selected',self.learning_slot);capture();self.send('press a')
            elif phase in {'confirm','stop'}:
                self.select('learning.selected',1);capture();self.send('press a')
            elif phase=='idle':self.send('wait 2')
            else:raise ProtocolError('unknown explicit learning phase: '+str(phase))
        raise ProtocolError('learning exceeded bounded semantic inputs')

    def evolution(self):
        # Each actual overlay visit owns evidence and its terminal result.
        # Announce/result wait for native dialogue readiness; no fake outcome.
        info=self.state.get('evolution')
        if not isinstance(info,dict)or not isinstance(info.get('from'),str)or not isinstance(info.get('species'),str)or not info['from']or not info['species']or info['from']==info['species']:
            raise ProtocolError('actual evolution source/target metadata required')
        info=dict(info);policy=self.config.get('evolution_policy','accept')
        entry={'policy':policy,'before':copy.deepcopy(self.party()),'initial':dict(info),'result':None,'animation':None}
        self.summary['evolutions'].append(entry);prefix='brock-evolution-'+str(len(self.summary['evolutions'])).zfill(3)
        def finish():
            after=copy.deepcopy(self.party());entry['after']=after
            expected='cancelled'if policy=='cancel'else'complete'
            if entry['result']!=expected or not entry.get('result_capture'):
                raise ProtocolError('evolution exited without captured actual '+expected+' result')
            if not entry.get('announce_capture'):raise ProtocolError('native evolution announce evidence missing')
            if policy=='accept'and(not entry['animation']or not entry['animation']['complete']):raise ProtocolError('native96-frame evolution recording missing')
            if policy=='cancel'and not entry.get('cancel_sent'):raise ProtocolError('actual evolution cancel input missing')
            before_species=[mon['species']for mon in entry['before']];after_species=[mon['species']for mon in after]
            if len(before_species)!=len(after_species):raise ProtocolError('evolution changed party size')
            changed=[i for i,(a,b)in enumerate(zip(before_species,after_species))if a!=b]
            if expected=='cancelled':
                if changed:raise ProtocolError('cancelled evolution changed actual species')
            elif len(changed)!=1 or before_species[changed[0]]!=info['from']or after_species[changed[0]]!=info['species']:
                raise ProtocolError('completed evolution differs from actual source/target species')
        for _ in range(180):
            if self.state.get('root')!='evolution':finish();return
            native=self.state['evolution'];phase=native.get('phase');result=native.get('result')
            # Party progression can immediately enter the next member's overlay
            # without changing the root name. Its announce is a new visit.
            if phase=='announce'and entry['result']is not None:finish();return
            if result in {'complete','cancelled','failed'}:
                if entry['result']not in (None,result):raise ProtocolError('native evolution terminal result changed')
                entry['result']=result;entry['observed_result_snapshot']=dict(native)
            elif result!='none':raise ProtocolError('unknown native evolution result: '+str(result))
            if phase=='announce':
                if native.get('dialog_ready'):
                    if not entry.get('announce_capture'):
                        entry['announce_capture']=prefix+'-announce';self.checkpoint(entry['announce_capture'])
                    self.send('press a')
                else:self.send('wait 3')
            elif phase=='animate':
                if policy=='cancel':
                    if not native.get('can_cancel'):raise ProtocolError('requested native evolution is not cancellable')
                    if entry.get('cancel_sent'):raise ProtocolError('actual B input did not cancel evolution')
                    entry['cancel_capture']=prefix+'-cancel-before';self.checkpoint(entry['cancel_capture'])
                    if self.state.get('root')!='evolution'or lookup(self.state,'evolution.phase')!='animate'or not lookup(self.state,'evolution.can_cancel'):
                        raise ProtocolError('native cancel window ended before B input')
                    entry['cancel_sent']=True;self.send('press b')
                elif entry['animation']is None:
                    frame=native.get('frame')
                    if type(frame)is not int or not 0<=frame<=23:raise ProtocolError('evolution entered too late for96 actual animation frames')
                    label=prefix+'-animate';entry['animation']={'name':label,'frames':96,'started':dict(native),'complete':False}
                    self.send('record '+label+' 96');entry['animation']['complete']=True
                else:self.send('wait 6')
            elif phase=='result':
                if entry['result']is None:raise ProtocolError('native result phase lacks terminal result')
                if native.get('dialog_ready'):
                    if not entry.get('result_capture'):
                        entry['result_capture']=prefix+'-'+entry['result'];self.checkpoint(entry['result_capture'])
                    if entry['result']=='failed':raise ProtocolError('actual evolution failed: '+str(native.get('failure')))
                    self.send('press a')
                else:self.send('wait 3')
            elif phase=='closed':finish();return
            else:raise ProtocolError('unknown native evolution phase: '+str(phase))
        raise ProtocolError('evolution UI exceeded bounded inputs')

    def battle(self,name,strategy='attack',expected=None):
        self.require(root='battle');self.await_value('battle.introPhase','ready')
        self.capture_escape=False
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
            elif phase=='forcedSwitch':
                # The rules enter this phase before the controller opens Party
                # on its next update. Wait for that owner; never pick an outcome.
                self.send('wait 2')
            elif phase=='command':
                if not battle.get('inMoveSelect'):
                    if not lookup(self.state,'battle.menu.active'):
                        self.send('wait 2');continue
                    options=sequence(lookup(self.state,'battle.menu.options'),'battle.menu.options')
                    if self.battle_preparation_action(battle,options):continue
                    medicine=choose_battle_medicine(battle['player'],self.inventory())
                    if medicine:
                        self.battle_medicine(medicine,options)
                        continue
                    fight=[i for i,v in enumerate(options,1)if v=='FIGHT'or isinstance(v,dict)and v.get('action')=='fight']
                    if len(fight)!=1:raise ProtocolError('battle requires exactly one real FIGHT action')
                    self.select('battle.menu.selected',fight[0]);self.send('press a')
                else:
                    legal=sequence(lookup(self.state,'battle.legal_moves'),'battle.legal_moves')
                    if any('effective_accuracy'not in move and not move.get('ohko')for move in legal):raise ProtocolError('actual effective_accuracy diagnostic required')
                    if self.training_mode=='capture'and self.capture_pending:
                        damaging=[move for move in legal if move_score(move,battle['player']['level'])>0]
                        selected=min(damaging,key=lambda move:(move_score(move,battle['player']['level']),move['index']))if damaging else None
                    else:selected=choose_move(legal,battle['player']['level'])
                    if selected is None:raise ProtocolError('empty legal menu must use production Struggle via FIGHT')
                    self.select_grid('battle.moveMenu.selected',selected['index'],lookup(self.state,'battle.moveMenu.columns'))
                    choices.append({'enemy':battle['enemy']['species'],'move':selected,'heuristic':move_score(selected,battle['player']['level'])})
                    self.send('press a')
            else:raise ProtocolError('unknown battle phase: '+str(phase))
        else:raise ProtocolError('battle exceeded1200 observed semantic inputs')
        if terminal is None:
            if self.capture_escape and lookup(self.state,'last_battle_outcome.kind')=='run':
                self.summary['battles'].append({'name':name,'trainer':trainer,'trainer_id':trainer_id,'money_before':before_money,
                    'terminal':{'kind':'run','evidence':'actual RUN input returned from battle'},'outcome':lookup(self.state,'last_battle_outcome'),'choices':choices})
                return False,False
            raise ProtocolError('battle exited without observed terminal phase')
        outcome=lookup(self.state,'last_battle_outcome')
        if not isinstance(outcome,dict)or outcome.get('kind')!=terminal['kind']:raise ProtocolError('missing matching terminal outcome diagnostic')
        self.summary['battles'].append({'name':name,'trainer':trainer,'trainer_id':trainer_id,'money_before':before_money,'terminal':terminal,'outcome':outcome,'choices':choices})
        if trainer and outcome.get('won'):
            if type(outcome.get('payout'))is not int or expected_payout is None or outcome['payout']!=expected_payout:raise ProtocolError('trainer payout differs from actual pinned source trainer')
            if self.inventory()['money']-before_money!=outcome.get('money_delta'):raise ProtocolError('trainer money delta diagnostic mismatch')
        if outcome.get('blackout')and name!='rival':
            if not(self.allow_blackout and expected=='loss'):raise NaturalBlackout('genuine blackout; explicit recovery required')
        if expected=='win'and not outcome.get('won')or expected=='loss'and outcome.get('won'):raise ProtocolError('unexpected actual battle result')
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

    def advance_event(self,stop_phase=None):
        return False

    def drain(self,stop_phase=None):
        for _ in range(1200):
            if self.advance_event(stop_phase):continue
            root=self.state.get('root')
            if root=='battle':
                if lookup(self.state,'battle.trainerName'):self.battle('source-trainer-'+str(len(self.summary['battles'])),expected='win')
                elif self.training_mode:
                    self.training_battle()
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

    def warp(self,target_id,event_id=None):
        candidates=[]
        for event in self.model().events['warps']:
            if event_id is not None and event['id']!=event_id:continue
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
        interior=self.state['zone_id']not in {PARCEL_NAMES['Route1'],PARCEL_NAMES['ViridianCity'],MAPS['Route2'],MAPS['ViridianForest'],MAPS['PewterCity']}
        for event,projection in candidates:
            point=(event['x'],event['y'])
            try:route=model.path(self.position(),{point},self.occupied(),allow_warps={point})
            except ProtocolError as error:
                if str(error).startswith('no source-valid '):continue
                raise
            reentry=None
            if not route and not (interior and event['y']==model.height-1):
                # Arrival suppression intentionally requires a new real step.
                # Plan a reversible, ordinary step off this exact warp; another
                # reachable warp may still be cheaper and is considered below.
                exits=[]
                for direction,(dx,dy) in DIRECTIONS.items():
                    step=model.terrain_step(point,direction)
                    if step is None or step.kind!='walk' or step.destination in (model.warps|model.signs|self.occupied()):continue
                    back=next((model.terrain_step(step.destination,d)for d,(bx,by)in DIRECTIONS.items()if (bx,by)==(-dx,-dy)),None)
                    if back is not None and back.kind=='walk' and back.destination==point:exits.append((step,back))
                if not exits:continue
                first,back=min(exits,key=lambda pair:int(model.grass[pair[0].destination[1]][pair[0].destination[0]]))
                reentry=first.destination;route=[first,back] # Cost includes both real steps.
            cost=sum((2 if step.kind=='ledge'else 1)+8*int(model.grass[step.destination[1]][step.destination[0]])for step in route)
            reachable.append((cost,event,projection,reentry))
        if not reachable:raise ProtocolError('no reachable source warp to '+target_id)
        _,event,projection,reentry=min(reachable,key=lambda entry:entry[0])
        if reentry is not None:self.navigate(reentry)
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

    def require_shop_stock(self,clerk,item):
        require_shop_stock(clerk,item)

    def buy_item(self,clerk,item,count,unit_price):
        self.require_shop_stock(clerk,item)
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

    def occupied(self):
        cells=super().occupied()
        for npc in sequence(self.state.get('npcs',[]),'npcs'):
            motion=npc.get('motion')
            if isinstance(motion,dict)and motion.get('phase')=='moving':
                for prefix in ['origin','target']:
                    x,y=motion.get(prefix+'_x'),motion.get(prefix+'_y')
                    if type(x)is not int or type(y)is not int:raise ProtocolError('native moving NPC reservation coordinates required')
                    cells.add((x,y))
        return cells

    def starter_index(self):
        family=FAMILIES[self.starter]
        matches=[i for i,mon in enumerate(self.party(),1)if mon['species']in family]
        if len(matches)!=1:raise ProtocolError('actual owned starter family must be unique')
        return matches[0]

    def battle_switch(self,index,options,reason):
        previous=lookup(self.state,'session.party.active');before=self.party()[previous-1]
        positions=[i for i,value in enumerate(options,1)if value=='POKEMON'or isinstance(value,dict)and value.get('action')=='party']
        if len(positions)!=1:raise ProtocolError('battle requires exactly one real POKEMON action')
        self.select('battle.menu.selected',positions[0]);self.send('press a');self.require(root='party')
        self.select('party_ui.selected',index);self.send('press a')
        if self.state.get('root')=='party':
            message=lookup(self.state,'party_ui.message')
            if not isinstance(message,str)or 'trapped'not in message.lower():raise ProtocolError('real battle switch rejected: '+str(message))
            self.send('press b');self.summary['party_changes'].append({'kind':'switch-blocked','reason':reason,'message':message})
            return False
        self.require(root='battle',**{'session.party.active':index})
        self.summary['party_changes'].append({'kind':'battle-switch','reason':reason,'from':before['species'],'to':self.party()[index-1]['species'],'party':self.party()})
        return True

    def battle_preparation_action(self,battle,options):
        if battle.get('trainerName')is None and self.training_mode=='capture'and self.capture_pending:
            if choose_battle_medicine(battle['player'],self.inventory()):return False
            if self.quantity('pokeBall')<=0:
                self.flee();self.capture_escape=True;return True
            damaging=[move_score(move,battle['player']['level'])for move in sequence(battle.get('legal_moves',[]),'capture legal moves')if move_score(move,battle['player']['level'])>0]
            # Avoid deliberately knocking out a fragile target; this risk heuristic
            # changes only the real input choice, never the capture result.
            risky=bool(damaging)and min(damaging)>=battle['enemy']['hp']
            if battle['enemy']['hp']*2<=battle['enemy']['maxHP']or risky:
                if len(self.summary['captures'])>=self.config.get('max_capture_attempts',24):raise ProtocolError('real capture attempt bound exhausted')
                before=self.quantity('pokeBall');count=len(self.party())
                positions=[i for i,value in enumerate(options,1)if value=='BAG'or isinstance(value,dict)and value.get('action')=='bag']
                if len(positions)!=1:raise ProtocolError('capture requires one real BAG action')
                self.select('battle.menu.selected',positions[0]);self.send('press a');self.require(root='bag')
                index=next((i for i,row in enumerate(sequence(self.inventory()['slots'],'inventory.slots'),1)if row['id']=='pokeBall'),None)
                if index is None:raise ProtocolError('actual capture ball disappeared')
                self.select('bag.selected',index);self.send('press a');self.require(root='battle')
                if self.quantity('pokeBall')!=before-1:raise ProtocolError('real ball did not consume exactly one')
                result=lookup(self.state,'battle.capture_result')
                if not isinstance(result,dict)or type(result.get('caught'))is not bool:raise ProtocolError('actual capture result required')
                self.summary['captures'].append({'enemy':battle['enemy'],'result':result,'before_quantity':before,'after_quantity':before-1,'party_before':count,'party_after':len(self.party())})
                if result['caught']:
                    if len(self.party())!=count+1:raise ProtocolError('caught reserve did not enter actual party')
                    self.capture_pending=False
                self.send('record brock-capture-'+str(len(self.summary['captures']))+' 48')
                return True
        active=lookup(self.state,'session.party.active');primary=self.starter_index()
        # A fainted reserve can force the real starter back before our voluntary return.
        if self.switch_back and active==primary:self.switch_back=False
        if self.switch_back and active!=primary:
            if self.party()[primary-1]['hp']<=0:
                self.switch_back=False;return False
            if self.battle_switch(primary,options,'preparation-switch'):
                self.switch_back=False;return True
            # A real trapping refusal must allow an attack, rather than reopen
            # the same rejected party menu forever.
            return False
        stages=battle['player'].get('stat_stages')
        if not isinstance(stages,dict)or type(stages.get('acc'))is not int:raise ProtocolError('actual stat_stages required for stage-reset strategy')
        key=(battle['enemy']['species'],battle['enemy']['level'],active)
        if stages['acc']<0 and key not in self.switch_reset_attempts:
            reserve=next((i for i,mon in enumerate(self.party(),1)if i!=active and mon['hp']>0),None)
            if reserve:
                self.switch_reset_attempts.add(key)
                if self.battle_switch(reserve,options,'reset-accuracy-stages'):
                    self.switch_back=True;return True
                return False
        return False

    def field_swap(self,index,target=1):
        if index==target:return
        old=[mon['species']for mon in self.party()]
        self.send('press b');self.pause_option('POKEMON');self.send('press a');self.require(root='party')
        self.select('party_ui.selected',index);self.send('press a');self.require(**{'party_ui.phase':'actions'})
        options=sequence(lookup(self.state,'party_ui.menu.options'),'party action options')
        if options.count('SWITCH')!=1:raise ProtocolError('field party must expose one SWITCH')
        self.select('party_ui.menu.selected',options.index('SWITCH')+1);self.send('press a');self.require(**{'party_ui.phase':'swap'})
        self.select('party_ui.selected',target);self.send('press a');self.require(**{'party_ui.phase':'list'})
        expected=list(old);expected[index-1],expected[target-1]=expected[target-1],expected[index-1]
        if [mon['species']for mon in self.party()]!=expected:raise ProtocolError('actual field party swap differs')
        self.send('press b');self.require(root='overworld')
        self.summary['party_changes'].append({'kind':'field-swap','from':index,'to':target,'party':self.party()})

    def training_battle(self):
        used=len(self.summary['training']);limit=self.config.get('max_training_battles',256)
        if used>=limit:raise ProtocolError('bounded real training battle budget exhausted: '+str(used)+'/'+str(limit))
        entry={'number':used+1,'limit':limit,'goal':self.training_mode,'entry':self.state,'party_before':self.party()}
        self.summary['training'].append(entry);self.switch_reset_attempts=set()
        name='preparation-'+str(used+1);before=len(self.summary['battles'])
        entry.update(completed=False,interrupted=True,outcome=None,error=None)
        try:self.battle(name,expected=None)
        except BaseException as error:
            entry['error']=str(error);raise
        finally:
            records=self.summary['battles'][before:]
            matched=records[0]if len(records)==1 and records[0].get('name')==name else None
            entry.update(completed=matched is not None,interrupted=matched is None,
                         outcome=matched['outcome']if matched else None,party_after=self.party())
        if not self.capture_pending and entry['goal']=='capture'and entry['outcome'].get('kind')!='caught':raise ProtocolError('capture party change lacks actual caught terminal outcome')

    def recover_blackout(self):
        if self.blackouts>=self.config.get('max_blackouts',1):raise ProtocolError('bounded natural blackout recovery exhausted')
        last=self.summary['battles'][-1];outcome=last['outcome'];checkpoint=lookup(self.state,'session.checkpoint')
        if not outcome.get('blackout')or outcome.get('won'):raise ProtocolError('recovery requires actual terminal blackout')
        if self.state['zone_id']!=checkpoint['zone_id']or self.position()!=(checkpoint['x'],checkpoint['y']):raise ProtocolError('blackout did not restore actual saved checkpoint')
        expected=last['money_before']//2
        if self.inventory()['money']!=expected or outcome.get('money_delta')!=expected-last['money_before']:raise ProtocolError('blackout source half-money penalty mismatch')
        if last['trainer_id']in self.source_trainers and self.defeated(last['trainer_id']):raise ProtocolError('defeated-player trainer was marked completed')
        for mon in self.party():
            if mon['hp']!=mon['maxHP']or mon['status']not in {'none',None}or mon['pp']!=mon['maxPP']:raise ProtocolError('blackout restoration incomplete')
        self.blackouts+=1;self.summary['blackouts'].append({'kind':'actual-defeat-not-victory','outcome':outcome,'checkpoint':checkpoint,'party':self.party(),'money':self.inventory()['money']})
        self.checkpoint('natural-blackout-'+str(self.blackouts))

    def reach_training_zone(self,zone):
        current=self.state['zone_id']
        if current==zone:return
        if current==PARCEL_NAMES['ViridianCity']:
            self.navigate((18,0));self.cross('up',MAPS['Route2'],(8,71))
        elif current==MAPS['PewterCity']:
            self.navigate((18,35));self.cross('down',MAPS['Route2'],(8,0))
        elif current==MAPS['PewterGym']:
            self.warp(MAPS['PewterCity']);self.reach_training_zone(zone);return
        if zone==MAPS['ViridianForest']:
            gate=MAPS['ViridianForestNorthGate']if self.position()[1]<36 else MAPS['ViridianForestSouthGate']
            self.warp(gate);self.warp(zone)
        elif self.state['zone_id']!=zone:raise ProtocolError('unsupported real training recovery path')

    def training_center(self,replenish=False):
        zone=self.state['zone_id'];self.training_mode=None
        if zone==MAPS['ViridianForest']:self.warp(MAPS['ViridianForestSouthGate']);self.warp(MAPS['Route2'])
        if self.state['zone_id']==MAPS['Route2']:
            self.navigate((8,71));self.cross('down',PARCEL_NAMES['ViridianCity'],(18,0))
        if self.state['zone_id']!=PARCEL_NAMES['ViridianCity']:raise ProtocolError('training Center route left reviewed slice')
        self.center(PARCEL_NAMES['ViridianCity'])
        primary=self.starter_index()
        if self.party()[primary-1]['hp']>0 and lookup(self.state,'session.party.active')!=primary:
            # Healing restores HP, not the authoritative active owner. Request
            # a real POKEMON command in the next battle; never write active.
            self.switch_back=True
        if replenish:
            count=min(6,self.inventory()['money']//200)
            if count<1:raise ProtocolError('actual shop funds cannot replenish capture balls')
            self.warp(PARCEL_NAMES['ViridianMart']);self.buy_item('pokered:VIRIDIAN_MART:objects:1','pokeBall',count,200);self.warp(PARCEL_NAMES['ViridianCity'])
        self.reach_training_zone(zone)

    def train_to(self,level,capture=False):
        zone=self.state['zone_id']
        if zone not in {MAPS['Route2'],MAPS['ViridianForest']}:raise ProtocolError('training requires reviewed source grass map')
        self.training_target=level;self.capture_pending=capture and len(self.party())<2
        lane=None;visits=0
        while True:
            primary=self.party()[self.starter_index()-1]
            if primary['level']>=level and not self.capture_pending and not self.switch_back:break
            if len(self.summary['training'])>=self.config.get('max_training_battles',256):raise ProtocolError('real training budget exhausted before target')
            if self.state['zone_id']!=zone:self.reach_training_zone(zone);lane=None
            if self.capture_pending and self.quantity('pokeBall')==0:
                self.training_center(replenish=True);lane=None
            active=lookup(self.state,'pokemon')
            known_damage=[key for key in active['moves']if key in self.observed_moves and (self.observed_moves[key].get('power',0)>0 or key in FIXED_DAMAGE)]
            low_pp=bool(known_damage)and sum(active['pp'][key]for key in known_damage)<3
            if active['hp']*4<active['maxHP']*3 or active['status']not in {'none',None}or low_pp:
                self.training_center();lane=None
            self.training_mode='capture'if self.capture_pending else'train'
            if lane is None:lane=training_lane(self.model(),self.position(),self.occupied())
            goal=lane[1]if self.position()==lane[0]else lane[0]
            try:self.navigate(goal)
            except NaturalBlackout:self.recover_blackout();self.reach_training_zone(zone);lane=None;continue
            visits+=1
            if visits>self.config.get('max_steps',5000):raise ProtocolError('grass traversal bound exhausted')
            if len(self.party())>=2 and not self.switch_back and not any(row.get('reason')=='preparation-switch'for row in self.summary['party_changes']):
                self.training_mode=None;self.training_center();self.field_swap(next(i for i,mon in enumerate(self.party(),1)if i!=self.starter_index()));self.switch_back=True;lane=None
            elif any(row.get('reason')=='preparation-switch'for row in self.summary['party_changes'])and self.starter_index()!=1:
                self.training_mode=None;self.field_swap(self.starter_index());lane=None
        self.training_mode=None
        if level>=16 and self.config.get('evolution_policy','accept')=='accept'and self.party()[self.starter_index()-1]['species']==self.starter:raise ProtocolError('actual accepted starter evolution not observed at preparation target')
        self.summary['preparation']={'starter':self.starter,'level_target':level,'party':self.party(),'training_battles':len(self.summary['training']),'training_limit':self.config.get('max_training_battles',256)}
        self.checkpoint('prepared-level-'+str(level))

    def return_to_pewter(self):
        if self.state['zone_id']==MAPS['ViridianForest']:
            self.warp(MAPS['ViridianForestNorthGate']);self.warp(MAPS['Route2'])
        if self.state['zone_id']==MAPS['Route2']:
            self.navigate((8,0));self.cross('up',MAPS['PewterCity'],(18,35))
        if self.state['zone_id']!=MAPS['PewterCity']:raise ProtocolError('unsupported real return to Pewter')
        self.center(MAPS['PewterCity'])

    def defeat_source(self,id):
        target=id.split(':objects:')[0]
        for attempt in range(self.config.get('max_blackouts',1)+1):
            try:
                self.interact(source_id=id)
                if not self.defeated(id):raise ProtocolError('actual source trainer victory missing: '+id)
                return
            except NaturalBlackout:
                self.recover_blackout()
                if target==MAPS['ViridianForest']:
                    self.reach_training_zone(target);self.train_to(max(10,self.party()[self.starter_index()-1]['level']))
                elif target==MAPS['PewterGym']:
                    # Reprepare through real south connection/gates; no teleport,
                    # HP adjustment, fake party or predicted XP is used.
                    self.reach_training_zone(MAPS['ViridianForest']);self.train_to(min(20,self.config.get('training_level',16)+2))
                    self.return_to_pewter();self.warp(target)
                else:raise ProtocolError('no reviewed natural trainer blackout recovery route')
        raise ProtocolError('source trainer recovery attempt bound exhausted')

    def north_to_city(self):
        self.navigate((9,0));self.cross('up',PARCEL_NAMES['Route1'],(10,35))
        if not self.flag('EVENT_GOT_POTION_SAMPLE'):
            before=self.quantity('potion')
            self.interact(source_id='pokered:ROUTE_1:objects:1')
            if not self.flag('EVENT_GOT_POTION_SAMPLE')or self.quantity('potion')!=before+1:
                raise ProtocolError('actual source Route1 sample not received exactly once')
            self.summary['recoveries'].append({'kind':'source-gift','source_event_id':'pokered:ROUTE_1:objects:1','item':'potion','quantity':1})
            self.interact(source_id='pokered:ROUTE_1:objects:1')
            if self.quantity('potion')!=before+1:raise ProtocolError('repeated source sample duplicated medicine')
            self.checkpoint('route1-original-potion-sample')
        self.navigate((10,0));self.cross('up',PARCEL_NAMES['ViridianCity'],(20,35))

    def natural(self):
        super().natural() # Initial seed reset only, exact passed parcel sequence.
        self.summary['acceptance']='parcel complete; Brock progression pending'
        self.warp(PARCEL_NAMES['ViridianCity']);self.warp(PARCEL_NAMES['ViridianMart'])
        self.buy_item('pokered:VIRIDIAN_MART:objects:1','antidote',3,100)
        self.buy_item('pokered:VIRIDIAN_MART:objects:1','pokeBall',5,200)
        self.warp(PARCEL_NAMES['ViridianCity'])
        self.navigate((18,0));self.cross('up',MAPS['Route2'],(8,71))
        self.train_to(8,capture=True)
        self.warp(MAPS['ViridianForestSouthGate']);self.warp(MAPS['ViridianForest'])
        # Source visible Potion: a real interaction rather than a bag fixture.
        self.interact(source_id='pokered:VIRIDIAN_FOREST:objects:6')
        for id in FOREST:
            self.field_recover()
            if not self.defeated(id):self.defeat_source(id)
            if not self.defeated(id):raise ProtocolError('source Forest trainer was not actually defeated: '+id)
            self.repeat_trainer(id);self.checkpoint('forest-defeated-'+id.rsplit(':',1)[1])
        self.train_to(self.config.get('training_level',16))
        self.return_to_pewter()
        count=max(0,min(3-self.quantity('potion'),self.inventory()['money']//300))
        if count:
            self.warp(MAPS['PewterMart']);self.buy_item('pokered:PEWTER_MART:objects:1','potion',count,300);self.warp(MAPS['PewterCity'])
        self.warp(MAPS['PewterGym']);self.defeat_source(JR)
        if not self.defeated(JR):raise ProtocolError('source Jr trainer victory missing')
        self.repeat_trainer(JR);self.warp(MAPS['PewterCity']);self.center(MAPS['PewterCity']);self.warp(MAPS['PewterGym']);self.defeat_source(BROCK)
        if not self.defeated(BROCK)or not self.flag('BADGE_BOULDER')or not self.flag('EVENT_GOT_TM34')or self.quantity('tm34')!=1:raise ProtocolError('Brock reward transaction incomplete')
        self.repeat_trainer(BROCK);self.checkpoint('brock-badge-tm34')
        if not any(row['result'].get('caught')for row in self.summary['captures']):raise ProtocolError('natural acceptance requires actual capture')
        if not any(row.get('reason')=='preparation-switch'and row['kind']=='battle-switch'for row in self.summary['party_changes']):raise ProtocolError('natural acceptance requires actual party change')
        primary=self.party()[self.starter_index()-1]
        if self.config.get('training_level',16)>=16 and self.config.get('evolution_policy','accept')=='accept'and (primary['level']<16 or primary['species']==self.starter):raise ProtocolError('prepared starter evolution missing')
        self.save();self.write_receipt();self.summary.update(acceptance='Brock path completed and saved; restart acceptance pending',natural=True,forbidden_shortcuts=False)

    def save(self):
        self.send('press b');self.require(root='pause',**{'pause.phase':'menu'})
        self.pause_option('SAVE');self.send('press a');self.require(**{'pause.phase':'save'})
        self.pause_option('YES');self.send('press a');self.require(root='dialog',**{'pause.lastSave.ok':True})
        self.await_value('dialog.ready',True,frames=300)
        self.capture_presentation('brock-save-dialog'if self.defeated(BROCK)else 'parcel-save-dialog','saved-dialog')
        self.dialog();self.require(root='overworld')
        if self.defeated(BROCK):self.capture_presentation('brock-game-saved','world')
        else:self.checkpoint('parcel-game-saved')

    def capture_presentation(self,label,kind):
        from tools.harness.brock_capture import qualify,identify
        path=self.frames_dir/(label+'.png')
        if path.exists():raise ProtocolError('Brock capture label already exists in this process: '+label)
        self.checkpoint(label)
        proof=qualify(self.build_evidence,path,self.state,kind)
        proof.update(identify(self.client,self.state,label));proof['path']=path.name
        self.summary.setdefault('presentation_evidence',[]).append(proof)
        atomic_json(self.evidence/'journey-progress.json',self.summary)

    def receipt_state(self):
        return {'starter':self.starter,'zone_id':self.state['zone_id'],'player':{k:self.state['player'][k]for k in ['x','y','facing']},
                'flags':{k:boolean_map(v,k)for k,v in lookup(self.state,'session.flags').items()},
                'inventory':self.inventory(),'party':lookup(self.state,'session.party'),'checkpoint':lookup(self.state,'session.checkpoint')}

    def write_receipt(self):
        packet={'schema':1,'kind':'brock-saved','build_id':self.client.identity['build_id'],'session_id':self.client.identity['session_id'],'state':self.receipt_state()}
        path=self.evidence/'journey-receipt.json';atomic_json(path,packet)
        self.summary['receipt']={'path':'journey-receipt.json','sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

    def continue_saved(self,prior):
        if not isinstance(prior,dict)or prior.get('schema')!=1 or prior.get('kind')!='brock-saved'or prior.get('build_id')!=self.client.identity['build_id']or prior.get('session_id')!=self.client.identity['session_id']:raise ProtocolError('missing or wrong-build Brock continuation receipt')
        self.starter=prior['state'].get('starter')
        if self.starter not in FAMILIES:raise ProtocolError('saved starter identity missing')
        self.dependencies();self.require(root='title',**{'title.phase':'menu'})
        options=sequence(lookup(self.state,'title.menu.options'),'title.menu.options')
        if options.count('CONTINUE')!=1:raise ProtocolError('title must expose exactly one real CONTINUE')
        self.select('title.selected',options.index('CONTINUE')+1)
        self.capture_presentation('brock-title-continue-selected','title')
        self.send('press a');self.drain()
        if self.receipt_state()!=prior['state']:raise ProtocolError('Continue differs from prior immutable journey receipt')
        if not all(self.defeated(id)for id in FOREST+[JR,BROCK]):raise ProtocolError('Continue lost source trainer defeat flags')
        self.repeat_trainer(BROCK);self.capture_presentation('brock-continued-no-repeat','world');self.write_receipt();self.summary.update(acceptance='Brock saved state continued across actual owned process restart',natural=True)



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
        journey.summary.update(ok=False,intro_outcome=journey.summary.get('outcome'),journey_outcome='failed',error=str(error),last_snapshot=journey.state);atomic_json(Path(evidence)/'journey-summary.json',journey.summary);raise
    journey.summary.update(ok=True,intro_outcome=journey.summary.get('outcome'),journey_outcome='complete',last_snapshot=journey.state);atomic_json(Path(evidence)/'journey-summary.json',journey.summary);return journey.summary
