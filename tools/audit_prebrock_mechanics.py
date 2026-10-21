#!/usr/bin/env python3
"""Read-only source-hashed Pallet→Brock exposure inventory; never claims runtime acceptance."""
import argparse,collections,dataclasses,hashlib,json,re,sys
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--project',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--primary',type=Path,required=True,help='pinned pokered checkout');p.add_argument('--showdown',type=Path,required=True,help='pinned resolved-move source cache');a=p.parse_args()
root=a.project.resolve();sys.path.insert(0,str(root))
from tools.verify_moves.parse_lua import LuaParser,read_moves,read_table,Expression,Reader,tokens
pokemon=LuaParser(root/'Source/data/pokemon.lua').parse();moves=read_moves(root/'Source/battle/moves.lua');items=read_table(root/'Source/data/items.lua','ItemData');evo=read_table(root/'Source/data/evolutionData.lua','EvolutionData')['rules']
# Item generator uses bracketed literal keys; parse only that declarative shape.
for item,fields in items['definitions'].items():
 if isinstance(fields,list):
  row={}
  for field in fields:
   assert isinstance(field,Expression)
   match=re.fullmatch(r'\[ ("(?:[^"\\]|\\.)*") \] = (.+)',field.text)
   assert match,(item,field)
   key=json.loads(match[1]);assert key not in row
   value=Reader(tokens(match[2])).value();assert not isinstance(value,Expression)
   row[key]=value
  items['definitions'][item]=row
starters=['bulbasaur','charmander','squirtle'];wild=['caterpie','metapod','weedle','kakuna','pidgey','rattata','pikachu'];enemy=['sandshrew','diglett','geodude','onix']
level_edges=lambda s:[r['to']for r in evo[s] if r['trigger']=='level']
def closure(seeds,all_methods=False):
 out=set(seeds);todo=list(seeds)
 while todo:
  for row in evo[todo.pop()]:
   if (all_methods or row['trigger']=='level') and row['to']not in out:out.add(row['to']);todo.append(row['to'])
 return out
natural=closure(starters+wild);technical=closure(starters+wild+enemy,True)
assert len(natural)==21 and len(technical)==30
campaigns={s:sorted(closure([s]+wild),key=lambda k:pokemon[k]['dex'])for s in starters}
assert all(len(x)==15 for x in campaigns.values())
wild_files=('Source/data/viridianSlice/Route1.json','Source/data/pewterSlice/Route2.json','Source/data/pewterSlice/ViridianForest.json')
minimum={s:5 for s in starters}
for rel in wild_files:
 for row in json.loads((root/rel).read_text())['encounters']['grass']['slots']:
  minimum[row['species']]=min(minimum.get(row['species'],100),row['level'])
for _ in range(5):
 for species,level in list(minimum.items()):
  for rule in evo[species]:
   if rule['trigger']=='level':minimum[rule['to']]=min(minimum.get(rule['to'],100),max(level+1,rule['minimum']))
# Earliest source capture can already have evolved below evolution threshold (Metapod/Kakuna).
parents={}
for parent,rules in evo.items():
 for rule in rules:parents[rule['to']]=parent
# Explicit mechanics review, not an inference that a nonempty effect is complete.
gaps={
 'assurance':('partial','Double power when target already damaged this turn is absent.'),
 'bugBite':('partial','Consume target berry and apply its effect is absent; berry acquisition is not currently enabled.'),
 'captivate':('wrong','Opposite-sex/sexless eligibility and ability immunity absent; currently unconditional SpA-2. Sex persistence is still a separate pending foundation.'),
 'dig':('partial','Two-turn charge, underground immunity, interruption and doubled opposing Earthquake/Magnitude damage absent.'),
 'earthquake':('conditional-gap','Double damage against underground target absent; Dig is not produced by current fixed authored teams.'),
 'electroBall':('missing','Speed-ratio power calculation absent: power0 with no effects.'),
 'endeavor':('missing','HP difference damage and target-HP failure rule absent: power0 with no effects.'),
 'explosion':('partial','User self-faint and ordering absent; standard damage alone is insufficient.'),
 'feint':('partial','Protect/Detect break and related guards absent; ordinary GenV hit is present.'),
 'flareBlitz':('conditional-gap','Recoil/burn present; self-thaw and relevant Fire thaw semantics absent. Freeze is not produced by currently obtainable preBrock species.'),
 'furyCutter':('partial','Consecutive-use power and interruption reset absent.'),
 'growth':('conditional-gap','Ordinary Atk+1/SpA+1 present; Sun +2 absent. No current preBrock ordinary Sun producer is available.'),
 'gust':('conditional-gap','Double damage to Fly/Bounce target absent; those producers unavailable before Brock.'),
 'gyroBall':('missing','Speed-ratio variable power absent: power0 with no effects.'),
 'heavySlam':('missing','Relative-weight variable power absent: power0 with no effects.'),
 'hurricane':('partial','Confusion/damage present; Rain always-hit, Sun50 and semi-invulnerable target interaction absent. Rain Dance is naturally reachable by grinding Squirtle.'),
 'lightScreen':('missing','Side special-damage reduction/duration absent.'),
 'magnitude':('missing','Magnitude distribution, power and underground-target interaction absent: power0 with no effects.'),
 'mirrorMove':('missing','Copy last eligible opponent move and failure policy absent.'),
 'petalDance':('partial','Multi-turn forced lock and ending confusion absent.'),
 'protect':('missing','Protection, consecutive success distribution and interruption guards absent.'),
 'pursuit':('partial','Withdraw interception/doubled damage absent; current authored single/multi opponents do not voluntarily switch.'),
 'ragePowder':('missing','Singles failure must be explicit; no redirect producer exists and generic empty status success is incorrect.'),
 'rainDance':('missing','Rain weather owner/producer,5-turn duration and dependent damage/accuracy/heal rules absent.'),
 'roost':('partial','Half heal present; temporary Flying removal/restoration absent. Real Brock Rock Throw gives reachable type interaction.'),
 'safeguard':('missing','Side status protection/duration absent.'),
 'selfDestruct':('partial','User self-faint and ordering absent; standard damage alone is insufficient.'),
 'skullBash':('partial','First-turn charge/Def+1, second-turn attack and interruption rules absent.'),
 'smackDown':('partial','Grounding and airborne cancellation absent; standard damage alone is insufficient.'),
 'solarBeam':('partial','Charge/skip-in-Sun lifecycle absent; currently attacks immediately. Sand half power present, Rain half power pending Rain owner.'),
 'steamroller':('conditional-review','Damage/flinch present; exact GenV Minimize-target exception must be qualified before implementation. No current preBrock Minimize producer.'),
 'suckerPunch':('partial','Fails unless target selected an eligible damaging action not yet executed; currently unconditional priority damage (e.g. incorrectly hits Harden).'),
 'sweetScent':('wrong','Current Eva-2 is later-gen; pinned Showdown gen5 override requires Eva-1.'),
 'tailwind':('missing','Side doubled Speed/four-turn duration absent.'),
 'thunder':('partial','Damage/paralysis present; Rain always-hit/Sun50/Fly interaction absent. Rain is naturally producible in Squirtle campaign grind-tail.'),
 'twister':('conditional-gap','Damage/flinch present; Fly/Bounce doubled damage absent, producers unavailable preBrock.'),
 'whirlwind':('missing','Trainer reserve forced switch / wild battle escape eligibility and failure rules absent. Future replacement must use authoritative entry discovery.'),
 'worrySeed':('missing','Temporary Insomnia ability override, eligibility, sleep cure, suppression/withdraw lifecycle absent.'),
 'focusEnergy':('candidate','Frozen candidate implements nonstacking+2 critical stage and lifecycle; root SDK/native proof pending.'),
 'razorLeaf':('candidate','Frozen generated critStage1 family +shared critical stage query; root proof pending.'),
 'slash':('candidate','Frozen generated critStage1 family +shared critical stage query; root proof pending.'),
 'airSlash':('path-present','Ordinary damage +30% flinch path; not an exhaustive per-move SDK acceptance claim.'),
 'nightSlash':('candidate','Frozen generated critStage1 family; root proof pending.'),
 'shadowClaw':('candidate','Frozen generated critStage1 family; root proof pending.'),
 'stoneEdge':('candidate','Frozen generated critStage1 family; root proof pending.'),
}
# Exactly the current 135 move keys are retained. Primary body locations are linked independently.
primary_ps=a.showdown;ps_files=[primary_ps/'data_moves.ts']+[primary_ps/f'data_mods_gen{g}_moves.ts'for g in (8,7,6,5)]
def primary_locations(key):
 out=[]
 for f in ps_files:
  txt=f.read_text();needle='\t'+key.lower()+': {'
  pos=txt.find(needle)
  if pos>=0:out.append({'file':str(f),'line':txt[:pos].count('\n')+1})
 return out

def prim(v):
 if isinstance(v,Expression):return v.text
 if isinstance(v,dict):return {k:prim(x)for k,x in v.items()}
 if isinstance(v,list):return [prim(x)for x in v]
 return v
rows=[];species_rows=[]
for species in sorted(technical,key=lambda k:pokemon[k]['dex']):
 data=pokemon[species];access='player-level-evolution-or-catch'if species in natural else 'stone-unavailable'if species=='raichu'else 'trainer-only-technical-family'
 entries=data['learnset'];assert all(0<=x['level']<=100 for x in entries)
 for i,entry in enumerate(entries):
  key=entry['move'];assert key in moves
  status,why=gaps.get(key,('path-present','Current declarative scalar/effect plus shared damage/stat/status path present. No bespoke missing producer identified in this bounded source audit; independent per-move behavioral acceptance still required.'))
  rows.append({'species':species,'dex':data['dex'],'access':access,'campaigns':[s for s,c in campaigns.items()if species in c],
   'level':entry['level'],'order':entry['order'],'sourceMoveId':entry['id'],'event_index':i+1,'move':key,
   'normal_route_priority':species in natural and entry['level']<=16,'level_0_100_retained':True,'event_acquisition':('direct-initial-or-level-up' if species in starters+wild else 'evolution-or-level-up' if species in natural and entry['level']>=minimum[species] else 'earlier-than-evolution:inheritance-or-relearner-review' if species in natural else 'technical-only'),'status':status,'remaining_semantics':why})
 species_rows.append({'species':species,'dex':data['dex'],'access':access,'direct':species in starters+wild+enemy,'campaigns':[s for s,c in campaigns.items()if species in c],
   'evolution_edges':evo[species],'learnset_event_count':len(entries),'levels_reviewed':[0,100],
   'level0':'No legal level0 Pokemon; level0 source events, if any, are retained without instantiating a level0 specimen.',
   'earliest_obtainable_level':minimum.get(species),'max_learnset_level':max(x['level']for x in entries)})
keys=sorted({r['move']for r in rows});assert len(keys)==135
move_rows=[]
for key in keys:
 status,why=gaps.get(key,('path-present','Shared production path present; no identified bespoke gap. Not exhaustive behavior acceptance.'))
 move_rows.append({'move':key,'current_definition':prim(moves[key]),'primary_bodies':primary_locations(key),'status':status,'remaining_semantics':why,
  'player_natural':any(r['move']==key and r['species']in natural and r['event_acquisition']!='earlier-than-evolution:inheritance-or-relearner-review' for r in rows),
  'normal_route_priority':any(r['move']==key and r['normal_route_priority']for r in rows),
  'learn_events':[{'species':r['species'],'level':r['level'],'access':r['access']}for r in rows if r['move']==key]})
# Fixed opponent initial selections use chronological backwards distinct rule, no level-tail upgrade.
def initial(species,level):
 eligible=[x['move']for x in pokemon[species]['learnset']if x['level']<=level];seen=set();selected=[]
 for key in reversed(eligible):
  if key not in seen:seen.add(key);selected.append(key)
  if len(selected)==4:break
 return list(reversed(selected))
trainers=json.loads((root/'Source/data/pewterSlice/trainers.json').read_text())['trainers']
for trainer in trainers:
 for mon in trainer['party']:mon['initial_moves']=initial(mon['species'],mon['level'])
# Imported wild slots are preserved; both versions are visible in source JSON.
encounters=[]
for rel in ('Source/data/viridianSlice/Route1.json','Source/data/pewterSlice/Route2.json','Source/data/pewterSlice/ViridianForest.json'):
 data=json.loads((root/rel).read_text());encounters.append({'source':rel,'encounters':data.get('encounters')})
item_rows=[]
acquisitions={'pokeBall':['ViridianMart','PewterMart','Forestobjects7'],'potion':['RedPC','Route1gift','PewterMart','Forestobjects6','Foresthidden1'],
 'antidote':['ViridianMart','PewterMart','Forestobjects5','Foresthidden2'],'parlyzHeal':['ViridianMart','PewterMart'],'burnHeal':['ViridianMart','PewterMart'],
 'awakening':['PewterMart'],'escapeRope':['PewterMart'],'townMap':['Daisyafterparcel'],'oaksParcel':['ViridianMartsourcehandoff'],'tm34':['Brockreward']}
for key,sources in acquisitions.items():
 d=items['definitions'][key];item_rows.append({'id':key,'definition':d,'acquisitions':sources,'status':'gap'if d['effect']=='unsupported'and key not in ('oaksParcel','pokeBall')else 'path-present',
  'remaining':{'tm34':'Bide battle producer + originalBlue TM compatibility/teaching/learning provenance/UI absent; must not substitute GenV TM34 SludgeWave.',
   'escapeRope':'Field escape implementation absent; source permits FOREST tileset, so real Forest use is reachable.',
   'townMap':'Bag use explicitly refuses unsupported; readable source-backed field map remains absent.'}.get(key,'Authoritative medicine/capture/quest transaction paths exist; scenario acceptance is distinct.')})
item_rows.extend([{'id':k,'acquisitions':['Route2eastobjects'],'status':'unavailable-before-Cut','remaining':'Source pickup exists but east area requires later access; not an obtainable preBrock stone/vitamin.'}for k in ('moonStone','hpUp')])
item_rows.append({'id':'lightBall','nativeGenVId':236,'acquisitions':['approved-in-principle B2W2 ordinary wild Pikachu5% policy, not enabled'],
 'status':'gap','remaining':'Need canonical GenV definition, precise acquisition transaction + Pikachu attack/spattack effect and held transfer/use/save witnesses. Existing Blue mart/gifts unchanged.'})
ability_names={5:'Sturdy',8:'Sand Veil',9:'Static',14:'Compound Eyes',19:'Shield Dust',50:'Run Away',51:'Keen Eye',61:'Shed Skin',62:'Guts',65:'Overgrow',66:'Blaze',67:'Torrent',68:'Swarm',69:'Rock Head',71:'Arena Trap',77:'Tangled Feet'}
slot_rows={int(dex):(int(first),int(second),int(hidden))for dex,first,second,hidden in re.findall(r'\[(\d+)\] = \{first=(\d+),second=(\d+),hidden=(\d+)\}',(root/'Source/data/specimenData.lua').read_text())}
abilities=[]
for key in species_rows:
 first,second,hidden=slot_rows[key['dex']];key['normal_ability_ids']=[first,second];key['hidden_ability_id_unavailable']=hidden
for ability_id in sorted({v for k in species_rows for v in k['normal_ability_ids']}):
 assert ability_id in ability_names
 abilities.append({'id':ability_id,'name':ability_names[ability_id],'species':[k['species']for k in species_rows if ability_id in k['normal_ability_ids']],
 'status':'existing scoped BattleEffects hooks; first16 source/SDK qualification handled by root, not full111 ability completion',
 'remaining':'Compound Eyes overworld held-distribution effect waits for enabled native wild-held generation.'if ability_id==14 else 'No new missing naturally exposed branch identified in this bounded inventory; exact lifecycle/native regression remains acceptance work.'})
assert len(abilities)==16
# Explicit pins include both audited runtime tree and independent reference bodies.
paths=['Source/data/pokemon.lua','Source/data/evolutionData.lua','Source/data/specimenData.lua','Source/battle/battle.lua','Source/battle/dsl.lua','Source/battle/conditions.lua','Source/battle/effects.lua','Source/battle/moves.lua','Source/data/items.lua','Source/domain/items.lua','Source/domain/inventory.lua','Source/domain/specimen.lua','Source/domain/pokemonCodec.lua','Source/game/bagState.lua','Source/game/pewterEvents.lua','Source/game/context.lua','Source/game/trainerEvents.lua','Source/data/maps.lua','Source/data/pewterSlice/trainers.json','Source/data/viridianSlice/Route1.json','Source/data/pewterSlice/Route2.json','Source/data/pewterSlice/ViridianForest.json']
pins={rel:hashlib.sha256((root/rel).read_bytes()).hexdigest()for rel in paths}
references=ps_files+[a.primary/'data/wild/maps/Route22.asm',a.primary/'data/trainers/parties.asm',a.primary/'engine/items/item_effects.asm',a.primary/'data/tilesets/escape_rope_tilesets.asm',a.primary/'data/maps/objects/Route2.asm']
refpins={str(f):hashlib.sha256(f.read_bytes()).hexdigest()for f in references}
report={'schema':1,'status':'source-review inventory; not campaign or exhaustive move acceptance','baseline_revision':'1c40818cce099f8c4463ba5073b95cc1fafb4502',
 'source_sha256':pins,'reference_sha256':refpins,'scopes':{'technical_direct':14,'technical_evolution_closure':30,'natural_player_union':21,'each_starter_campaign':15,'normal_priority_level_marker':16,'marker_is_not_cap_or_waiver':True,'all_level_events_inclusive':[0,100]},
 'campaigns':campaigns,'abilities':abilities,'species':species_rows,'learn_events':rows,'moves':move_rows,'move_status_counts':dict(collections.Counter(x['status']for x in move_rows)),
 'trainers_fixed_authored_levels':trainers,'other_opponents':[{'source':'Originalintro','level':5,'species':'typeadvantagedcounterstarter'},{'source':'Authoredoutdoorrematch','level':7,'species':'typeadvantagedcounterstarter','not_originalRoute22':True}],
 'wild_sources':encounters,'items':item_rows,'shops':{k:items['marts'][k]for k in ('viridianMartClerkText','pewterMartClerkText')},
 'route22_world_gap':{'status':'original Blue content disconnected; remains required','wild_species':['rattata','nidoranF','spearow','nidoranM'],'blue_levels':[2,5],
 'first_rival_source_party':{'pidgey':9,'counterstarter':8},'required_followup':'Connect actual source map, optional source rival, exact wild data and reachable evolution/sex/normal ability/move closure; not waived by current14direct inventory.'},
 'cross_cutting_remaining':['IV/EV individuality/generation/progression still fixed0 baseline; user full-fidelity requirement remains.','Persistent sex/provenance pending; Captivate and Route22 Rivalry/PoisonPoint dependencies require actual implementation.','Wild held-item generation disabled; currentPikachu LightBall5% acquisition/effects not implemented.','All111 original151 normal+hidden union abilities remain required for full game; current16normal scope does not claim111.','TownMap/escapeRope/TM34Bide availability/use must close as real field/battle flows.','Physical duplicate99 stacks source-confirmed; selected physical stack vs aggregate bag operations/menus requires separate fidelity audit, no Inventory change in this packet.','Capture/evolution/learning/party/storage/save each require native settled/restart/lifecycle acceptance and multi-starter natural campaign witnesses; contract counts do not imply campaign completion.']}
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'species':len(species_rows),'learn_events':len(rows),'unique_moves':len(keys),'statuses':report['move_status_counts'],'sha256':hashlib.sha256(a.output.read_bytes()).hexdigest()}))
