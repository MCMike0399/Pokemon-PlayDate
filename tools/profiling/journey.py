"""Bounded root-owned profiling journey; actual doors/connections/battle rules."""
import json,subprocess
from pathlib import Path
from tools.harness.journeys import Journey
from tools.harness.protocol import atomic_json,ProtocolError


def run(client,scenario,evidence):
    config=scenario['journey'];cycles=config.get('cycles',6)
    if type(cycles)is not int or not 6<=cycles<=12:raise ProtocolError('profile cycles must be6..12')
    journey=Journey(client,evidence,config);rss=[]
    def gc(label):
        journey.send({'op':'profile','args':['gc',label]})
        client._check_owner()
        metadata=json.loads((Path(evidence)/'run.json').read_text());pid=metadata['simulator_pid']
        result=subprocess.run(['ps','-o','rss=','-p',str(pid)],capture_output=True,text=True,timeout=5)
        rss.append({'label':label,'owned_pid':pid,'rss_kib':int(result.stdout.strip())if result.returncode==0 and result.stdout.strip().isdigit()else None,
                    'limitation':'Simulator process RSS is not device/native allocator capacity'})
    def arrive(key):
        journey.await_value('zone',key);journey.await_value('overworld','explore');journey.await_value('root','overworld')
    journey.send('gamestate');startup=journey.state['world_profile']
    journey.send({'op':'fixture','options':{'seed':42,'intro':'skip','zone':'kanto_route1','opening':False,
        'party_pokemon':[{'species':'charmander','level':50}],
        'quest_flags':{'EVENT_GOT_OAKS_PARCEL':True,'EVENT_OAK_GOT_PARCEL':True,'EVENT_GOT_POKEDEX':True}}},'encounters off')
    gc('initial-fixture')
    for cycle in range(1,cycles+1):
        journey.send({'op':'profile','args':['zone','kanto_route1']}) # labeled direct-view fixture, no session reset
        journey.send('warp 10 0','press up');arrive('kanto_viridian_city')
        journey.send('warp 29 20','press up');arrive('kanto_viridian_mart')
        journey.send('press down');arrive('kanto_viridian_city')
        journey.send('warp 23 26','press up');arrive('kanto_viridian_center')
        journey.send('press down');arrive('kanto_viridian_city')
        journey.send('battle magikarp 1');journey.battle(f'profile-{cycle:02d}',expected='win')
        arrive('kanto_viridian_city');gc(f'cycle-{cycle:02d}-retained')
    journey.send({'op':'profile','args':['report','final']},'shot profile-final')
    build=json.loads((Path(evidence)/'build.json').read_text())
    report={'ok':True,'build_id':build['build_id'],'source_sha256':build['source_sha256'],'source_asset_inventory':build['profile_inventory'],'cycles':cycles,'startup':startup,'world_profile':journey.state['world_profile'],'rss':rss,
        'fixtures':['completed-parcel/level50/no-encounter initial session','within-map warp positioning','direct Route1 rebuild at each cycle start'],
        'real_flows':['Route1-City connection','City-Mart-City doors','City-Center-City doors','wild battle commands/rules/victory return'],
        'limitations':['Lua heap excludes native image/SDK allocator heap','full GC is an explicit profiling intervention','observer rows and harness snapshots allocate memory','frame timing excludes harness before/afterFrame capture work','no guessed hardware budget']}
    atomic_json(Path(evidence)/'world-profile.json',report)
    return report
