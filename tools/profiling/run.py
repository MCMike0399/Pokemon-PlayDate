#!/usr/bin/env python3
"""Isolated current-source profiling build; --execute is root Simulator owner only."""
import argparse,difflib,hashlib,importlib.util,json,shutil,subprocess,sys,tempfile
from pathlib import Path
from types import SimpleNamespace
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--project',default=str(Path(__file__).resolve().parents[2]));parser.add_argument('--output',required=True);parser.add_argument('--sdk');parser.add_argument('--cycles',type=int,choices=range(6,13),default=6);parser.add_argument('--execute',action='store_true');args=parser.parse_args()
project=Path(args.project).resolve();stage=Path(__file__).resolve().parent;sys.path.insert(0,str(project))
from tools.harness import run as harness,journeys
from tools.harness.protocol import atomic_json
original_prepare,original_journey=harness.prepare,journeys.run

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
from tools.profiling.anchors import replace

def prepare(project,sdk,output,session):
    metadata=original_prepare(project,sdk,output,session);changes=[]
    shutil.copyfile(stage/'worldProfile.lua',output/'Source/dev/worldProfile.lua')
    def edit(name,fn):
        p=output/'Source'/name;before=p.read_text();after=fn(before);p.write_text(after)
        changes.extend(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='a/Source/'+name,tofile='b/Source/'+name))
    def main(text):
        text=replace(text,'import "lib/oop"','import "dev/worldProfile"\nWorldProfile.sample("startup-imports:begin")\nimport "lib/oop"')
        text=replace(text,'game = GameContext({sessionLocationPolicy=KantoWorld.locationPolicy()})','WorldProfile.sample("startup-imports:end")\nlocal contextProfile=WorldProfile.begin("context")\ngame = GameContext({sessionLocationPolicy=KantoWorld.locationPolicy()})\nWorldProfile.finish(contextProfile)')
        text=replace(text,'KantoWorld.install(game)','local installProfile=WorldProfile.begin("four-map-install")\nKantoWorld.install(game)\nWorldProfile.finish(installProfile)\nWorldProfile.collect("four-map-install-profile")')
        text=replace(text,'game.saves:start()','local savesProfile=WorldProfile.begin("GameSaves-start")\ngame.saves:start()\nWorldProfile.finish(savesProfile)')
        text=replace(text,'    Harness.beforeFrame(game)\n','    Harness.beforeFrame(game)\n    local profileTick=playdate.getCurrentTimeMilliseconds()\n    local profilePhase=machine:getCurrent() or "none"\n')
        text=replace(text,'    local top = machine:getCurrent()','    WorldProfile.frame(playdate.getCurrentTimeMilliseconds()-profileTick,profilePhase)\n    local top = machine:getCurrent()')
        return text
    edit('main.lua',main)
    edit('game/overworldState.lua',lambda text:replace(replace(text,'function OverworldState:enter(opts)\n','function OverworldState:enter(opts)\n    local profile=WorldProfile.begin("view:"..currentZone.stableID)\n'),'    if KantoWorld then KantoWorld.onEnter(game,opts) end','    if KantoWorld then KantoWorld.onEnter(game,opts) end\n    WorldProfile.finish(profile)'))
    edit('game/battleState.lua',lambda text:replace(replace(replace(replace(text,'function BattleState:enter(playerPokemon, enemyPokemon, npc, enemyParty)\n','function BattleState:enter(playerPokemon, enemyPokemon, npc, enemyParty)\n    local profile=WorldProfile.begin("battle-entry")\n'),'    assert(self.game.session:markSeen(enemyPokemon.species))','    assert(self.game.session:markSeen(enemyPokemon.species))\n    WorldProfile.finish(profile)'),'function BattleState:exit()\n','function BattleState:exit()\n    local profile=WorldProfile.begin("battle-exit")\n'),'    self.npc = nil\nend\n\nfunction BattleState:update()','    self.npc = nil\n    WorldProfile.finish(profile)\nend\n\nfunction BattleState:update()'))
    edit('dev/diagnostics.lua',lambda text:replace(text,'        display = HarnessCapture.display(),','        world_profile = WorldProfile.snapshot(),\n        display = HarnessCapture.display(),'))
    def protocol(text):
        text=replace(text,'    if op == "assert" or op == "await" then','    if op == "profile" then\n        valid=#args==2 and (args[1]=="sample" or args[1]=="gc" or args[1]=="report" or args[1]=="zone") and type(args[2])=="string" and #args[2]<=60\n    elseif op == "assert" or op == "await" then')
        text=replace(text,'        if command.op == "assert" or command.op == "await" then','''        if command.op == "profile" then
            local action,label=command.args[1],command.args[2]
            if action=="gc" then WorldProfile.collect(label)
            elseif action=="sample" then WorldProfile.sample(label)
            elseif action=="report" then WorldProfile.publish()
            else
                assert(game.machine:is("overworld") and not game.player.isMoving,"profile transition fixture needs settled overworld")
                assert(label=="kanto_route1" or label=="kanto_viridian_city" or label=="kanto_viridian_mart" or label=="kanto_viridian_center","profile zone outside four-map slice")
                WorldProfile.sample("direct-zone-fixture:"..label)
                switchZone(label);game.machine:change("overworld",{respawn=true})
            end
            complete=true
        elseif command.op == "assert" or command.op == "await" then''')
        return text
    edit('dev/harness.lua',protocol)
    (output/'profile-instrumentation.patch').write_text(''.join(changes))
    metadata['profile_inventory']={'source_files':len(list((output/'Source').rglob('*.lua'))),'source_lua_bytes':sum(p.stat().st_size for p in (output/'Source').rglob('*.lua')),
        'png_files':len(list((output/'Source').rglob('*.png'))),'png_bytes':sum(p.stat().st_size for p in (output/'Source').rglob('*.png')),
        'json_files':len(list((output/'Source').rglob('*.json'))),'json_bytes':sum(p.stat().st_size for p in (output/'Source').rglob('*.json'))}
    pdx=output/'Source/pdxinfo';generated=pdx.read_text();pdx.write_text(metadata['original_pdxinfo'])
    metadata['source_sha256']=harness.fingerprint(output);metadata['build_id']=metadata['revision']+':'+metadata['source_sha256']
    atomic_json(output/'source-manifest.json',{str(p.relative_to(output/'Source')):sha(p)for p in sorted((output/'Source').rglob('*'))if p.is_file() and p.name!='harness_build.lua'})
    pdx.write_text(generated)
    values=[]
    for key in ('protocol','session_id','build_id','output_dir','bundle_id','sdk_version','enabled','data_dir'):
        value=metadata[key];values.append('    '+key+' = '+('true'if value is True else json.dumps(value,ensure_ascii=False))+',')
    (output/'Source/dev/harness_build.lua').write_text('HarnessBuild = {\n'+'\n'.join(values)+'\n}\n')
    metadata['compiled_source_sha256']=harness.fingerprint(output,exclude_generated=False)
    metadata['profiling']={'cycles':args.cycles,'explicit_full_gc':True,'native_heap_available':False,'observer':'private-source Lua heap/sprite/tile/timing instrumentation'}
    with (output/'profile-build.log').open('w')as log:subprocess.run([str(sdk/'bin/pdc'),str(output/'Source'),metadata['bundle']],stdout=log,stderr=subprocess.STDOUT,check=True)
    atomic_json(output/'build.json',metadata);return metadata

spec=importlib.util.spec_from_file_location('world_profile_job',stage/'journey.py');job=importlib.util.module_from_spec(spec);spec.loader.exec_module(job)
harness.prepare=prepare
journeys.run=lambda client,scenario,evidence:job.run(client,scenario,evidence) if scenario.get('journey',{}).get('name')=='world-profile'else original_journey(client,scenario,evidence)
harness.PROJECT=project
try:
    with tempfile.TemporaryDirectory(prefix='pokemon-profile-scenario-') as temporary:
        scenario=Path(temporary)/'scenario.json'
        atomic_json(scenario,{'journey':{'name':'world-profile','cycles':args.cycles},'outputs':['profile-final.png']})
        result=harness.run(SimpleNamespace(sdk=args.sdk,output=args.output,scenario=str(scenario),commands=[],build_only=not args.execute,timeout=60,ready_timeout=20,max_frames=1800))
finally:
    harness.prepare=original_prepare
    journeys.run=original_journey
raise SystemExit(result)
