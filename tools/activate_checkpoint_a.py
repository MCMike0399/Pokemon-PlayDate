#!/usr/bin/env python3
"""Generate an unapplied 5.5a activation patch through the shared cache builder.

No shared writes, deletion, reset, Simulator or native acceptance at generation.
"""
import argparse
import copy
import difflib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.generate_source_map_cache import build as build_cache

BASE = '0406bf3'
ACCEPTED = '63267b0'
POLICY = ROOT / 'tools/integration/checkpoint-a/production-exclusions.json'


def git_bytes(revision, path):
    return subprocess.check_output(['git', '-C', str(ROOT), 'show', revision + ':' + path])


def map_names(project=ROOT):
    old = json.loads(git_bytes(ACCEPTED, 'Source/data/sourceMaps.json'))['maps']
    east = json.loads((Path(project) / 'Source/data/midgameEast/manifest-entries.json').read_bytes())['maps']
    if len(old) != 65 or len(east) != 43 or set(old) & set(east):
        raise ValueError('accepted and East inventories differ from the reviewed checkpoint')
    return set(old) | set(east)


def production_exclusions(project):
    """Only installed checkpoint A opts into the exclusion policy; B/C stays intact."""
    project = Path(project)
    manifest = json.loads((project / 'Source/data/sourceMaps.json').read_bytes())
    names = set(manifest['maps'])
    roots = ('data/viridianSlice/', 'data/pewterSlice/', 'data/sourceSlice/',
             'data/vermilionPreparation/', 'data/midgameEast/')
    east_count = sum(entry['path'].startswith('data/midgameEast/') for entry in manifest['maps'].values())
    if len(names) != 108 or east_count != 43 or not {'CeladonCity', 'RocketHideoutB4F'} <= names \
            or not all(entry['path'].startswith(roots) for entry in manifest['maps'].values()):
        return []
    policy = json.loads(POLICY.read_bytes())
    return policy['exclude']


def ignored_source_names(source_root, directory, names, exclusions):
    relative = Path(directory).relative_to(source_root).as_posix()
    relative = '' if relative == '.' else relative + '/'
    result = []
    for name in names:
        path = relative + name
        if path == 'dev' or any(path == prefix.rstrip('/') or path.startswith(prefix)
                                 for prefix in exclusions if prefix.endswith('/')) or path in exclusions:
            result.append(name)
        elif name in {'proposed-source-maps.json', 'proposed-compact.json', 'proposed-tile-grids.json'}:
            result.append(name)
    return result


def changed(path, transform):
    before = git_bytes(BASE, path).decode()
    after = transform(before)
    if before == after:
        raise ValueError('activation transform did not change ' + path)
    return before.encode(), after.encode()


def runtime_changes():
    changes = {}
    def main(s):
        future_imports = ('game/towerStory', 'game/snorlaxStory', 'game/towerStoryController',
            'game/silphStory', 'game/silphStoryWorld', 'game/silphStoryController',
            'game/midgameGymStoryController', 'game/fieldTravelRequests', 'game/fieldTravelRuntime',
            'game/fieldTravelState', 'game/fieldGearRequests', 'game/fieldGearState', 'world/fieldGearArt',
            'domain/safariBattle')
        for module in future_imports:
            s = s.replace('import "' + module + '"\n', '')
        for package in ('South', 'Saffron'):
            block = ('CeruleanContent.registerPackage("midgame' + package + '", "data/midgame' + package
                     + '/", function(events, trainers)\n    return HideoutTowerContent.package("midgame' + package
                     + '", events, trainers)\nend)\n')
            if block not in s:
                raise ValueError('package registration drift: ' + package)
            s = s.replace(block, '')
        for name in ('fieldTravel', 'fieldGear'):
            cls = 'FieldTravelState' if name == 'fieldTravel' else 'FieldGearState'
            s = s.replace('machine:register("' + name + '", ' + cls + '(game))\n', '')
        return s
    changes['Source/main.lua'] = changed('Source/main.lua', main)

    def content(s):
        s = s.replace('if name == "midgameEast" or name == "midgameSouth" then',
            'if TowerStory and SourceMaps.nameForID("pokered:POKEMON_TOWER_1F")\n        and (name == "midgameEast" or name == "midgameSouth") then')
        s = s.replace('if name == "midgameSouth" then', 'if TowerStory and name == "midgameSouth" then')
        s = s.replace('if name == "midgameSaffron" then', 'if SilphStory and name == "midgameSaffron" then')
        start=s.index('    for _, extra in ipairs({RocketHideoutStory.actorMetadata')
        end=s.index('    return result\nend', start)
        s=s[:start]+'''    local values = {RocketHideoutStory.actorMetadata(id, game),
        MidgameGymStory.actorMetadata(id), CeladonServices.actorMetadata(id)}
    if TowerStory and SourceMaps.nameForID("pokered:POKEMON_TOWER_1F") then
        values[#values + 1] = TowerStory.actorMetadata(id, game)
        values[#values + 1] = SnorlaxStory.actorMetadata(id)
    elseif id == "pokered:MR_FUJIS_HOUSE:objects:5" then
        -- Fuji is not home before the parked Tower rescue.
        values[#values + 1] = {visibility={{group="quest", id="EVENT_RESCUED_MR_FUJI", equals=true}}}
    end
    if SilphStory and SourceMaps.nameForID("pokered:SILPH_CO_1F") then
        values[#values + 1] = SilphStory.actorMetadata(id, game)
    end
    for _, extra in ipairs(values) do
        for _, condition in ipairs(extra.visibility or {}) do
            result.visibility[#result.visibility + 1] = copy(condition)
        end
    end
'''+s[end:]
        s=s.replace('    TowerStory.install("midgameSouth", {reconcileActors = KantoScenes.reconcileActors})\n    SnorlaxStory.install("midgameSouth")', '''    if TowerStory and SourceMaps.nameForID("pokered:POKEMON_TOWER_1F") then
        TowerStory.install("midgameSouth", {reconcileActors=KantoScenes.reconcileActors})
        SnorlaxStory.install("midgameSouth")
    end''')
        s=s.replace('    SilphStory.install({reconcileActors = KantoScenes.reconcileActors})', '''    if SilphStory and SourceMaps.nameForID("pokered:SILPH_CO_1F") then
        SilphStory.install({reconcileActors=KantoScenes.reconcileActors})
    end''')
        return s
    changes['Source/game/hideoutTowerContent.lua']=changed('Source/game/hideoutTowerContent.lua',content)

    def controller(s):
        # Optional delegates are absent from the A production bundle.
        for module in ('TowerStoryController','MidgameGymStoryController','SilphStoryController'):
            for method in ('enter','draw','exit'):
                s=s.replace('    '+module+'.'+method+'(state)', '    if '+module+' then '+module+'.'+method+'(state) end')
            s=s.replace(module+'.advance(state)', '('+module+' and '+module+'.advance(state))')
            s=s.replace(module+'.handleButton(state, button)', '('+module+' and '+module+'.handleButton(state, button))')
        s=s.replace('or id == TowerStory.RIVAL or id == TowerStory.FUJI or id == TowerStory.HOUSE_FUJI or TowerStory.rocket(id)\n        or SnorlaxStory.definition(id)',
            'or TowerStory and (id == TowerStory.RIVAL or id == TowerStory.FUJI or id == TowerStory.HOUSE_FUJI or TowerStory.rocket(id))\n        or SnorlaxStory and SnorlaxStory.definition(id)')
        return s
    changes['Source/game/hideoutTowerController.lua']=changed('Source/game/hideoutTowerController.lua',controller)

    def gym(s):
        s=s.replace('    return copy(cached)\nend', '''    local installed = {}
    for id, descriptor in pairs(cached) do
        local mapID = id:match("^(pokered:[^:]+):")
        if SourceMaps.nameForID(mapID) then
            installed[id] = copy(descriptor)
        end
    end
    return installed
end''',1)
        s=s.replace('    SourceEvents.registerWorldHooks(MidgameGymStory.MASTER, {', '''    if not SourceMaps.nameForID("pokered:FIGHTING_DOJO") then
        return
    end
    SourceEvents.registerWorldHooks(MidgameGymStory.MASTER, {''')
        return s
    changes['Source/game/midgameGymStory.lua']=changed('Source/game/midgameGymStory.lua',gym)
    changes['Source/game/midgameStoryWarps.lua']=changed('Source/game/midgameStoryWarps.lua',lambda s:s.replace(
        '    register(SilphStoryWorld, "pokered:SILPH_CO_ELEVATOR")',
        '    if SilphStoryWorld and SourceMaps.nameForID("pokered:SILPH_CO_ELEVATOR") then\n        register(SilphStoryWorld, "pokered:SILPH_CO_ELEVATOR")\n    end'))
    changes['Source/game/partyState.lua']=changed('Source/game/partyState.lua',lambda s:s.replace(
        '    if FieldTravel then\n', '    if FieldTravel and self.game.machine:get("fieldTravel") then\n',1))
    changes['Source/game/fieldMoveState.lua']=changed('Source/game/fieldMoveState.lua',lambda s:s.replace(
        '        return FieldTravelState.open(game, party, mon, key)',
        '        if not FieldTravelState or not game.machine:get("fieldTravel") then\n            party.message = "That move can\'t be used here."\n            return false, "field-travel-state-not-installed"\n        end\n        return FieldTravelState.open(game, party, mon, key)',1))
    changes['Source/game/bagState.lua']=changed('Source/game/bagState.lua',lambda s:s.replace(
        '        return FieldGearState.open(', '        if not FieldGearState then return false, "field-gear-state-not-installed" end\n        return FieldGearState.open('))

    def catalog(s):
        s=s.replace('    asset("midgame-unidentified-ghost", 96, 96, "midgame-battle-art", true)',
            '    if SourceMaps.nameForID("pokered:POKEMON_TOWER_1F") then\n        asset("midgame-unidentified-ghost", 96, 96, "midgame-battle-art", true)\n    end')
        start=s.index('    result.field_gear_assets =');end=s.index('    table.sort(result.images',start)
        s=s[:start]+'    if FieldGearArt and SourceMaps.nameForID("pokered:FUCHSIA_CITY") then\n'+s[start:end]+'    end\n'+s[end:]
        line='    sink.asset("midgame-unidentified-ghost", assert(playdate.graphics.image.new("images/title/ghost")), "midgame-battle-art", true)'
        s=s.replace(line,'    if SourceMaps.nameForID("pokered:POKEMON_TOWER_1F") then\n'+line+'\n    end')
        start=s.index('    report.field_gear =');end=s.index('    return report',start)
        s=s[:start]+'    if FieldGearArt and SourceMaps.nameForID("pokered:FUCHSIA_CITY") then\n'+s[start:end]+'    end\n'+s[end:]
        s=s.replace('    FieldGearArt.prepare()', '    if FieldGearArt and SourceMaps.nameForID("pokered:FUCHSIA_CITY") then FieldGearArt.prepare() end')
        return s
    changes['Source/dev/midgameCatalogExporter.lua']=changed('Source/dev/midgameCatalogExporter.lua',catalog)

    def dev(s):
        for module,suite,callback,mapname in (
            ('strengthBoulderContracts','strength-boulder','StrengthBoulderContracts.run','WardensHouse'),
            ('fieldTravelContracts','field-travel','FieldTravelContracts.run','FuchsiaCity'),
            ('sourceEncounterContracts','source-encounters','SourceEncounterContracts.run','PokemonTower1F'),
            ('fieldGearContracts','field-gear','FieldGearContracts.run','FuchsiaCity')):
            block='import "dev/'+module+'"\nContracts.register("'+suite+'", '+callback+')'
            if block not in s:raise ValueError('SDK registration drift: '+module)
            s=s.replace(block,'if SourceMaps.nameForID("pokered:'+{'WardensHouse':'WARDENS_HOUSE','FuchsiaCity':'FUCHSIA_CITY','PokemonTower1F':'POKEMON_TOWER_1F'}[mapname]+'") then\n'+block+'\nend')
        return s
    changes['tools/harness/dev_imports.lua']=changed('tools/harness/dev_imports.lua',dev)

    def build(s):
        s=s.replace('from tools.harness.run import sdk_path, fingerprint',
            'from tools.harness.run import sdk_path, fingerprint\nfrom tools.activate_checkpoint_a import production_exclusions, ignored_source_names')
        s=s.replace("    shutil.copytree(project / 'Source', source,\n                    ignore=lambda directory, names: ['dev'] if Path(directory) == project / 'Source' else [])", "    original = project / 'Source'\n    excluded = production_exclusions(project)\n    shutil.copytree(original, source, ignore=lambda directory, names:\n                    ignored_source_names(original, directory, names, excluded))")
        return s
    changes['tools/build.py']=changed('tools/build.py',build)
    return changes


def activation(project=ROOT):
    project = Path(project)
    selected = map_names(project)
    active = json.loads((project / 'Source/data/sourceMaps.json').read_bytes())
    if not selected <= set(active['maps']):
        raise ValueError('shared manifest is missing accepted or East entries')
    scoped = copy.deepcopy(active)
    scoped['maps'] = {name: entry for name, entry in active['maps'].items() if name in selected}
    raw = (json.dumps(scoped, sort_keys=True, separators=(',', ':')) + '\n').encode()
    with tempfile.TemporaryDirectory(prefix='checkpoint-a-cache-') as temporary:
        manifest = Path(temporary) / 'sourceMaps.json'
        manifest.write_bytes(raw)
        cache = build_cache(manifest, project / 'Source')
    changes = runtime_changes()
    changes['Source/data/sourceMaps.json'] = ((project / 'Source/data/sourceMaps.json').read_bytes(), raw)
    for name, data in cache.items():
        path = 'Source/data/sourceMapCache/' + name
        changes[path] = ((project / path).read_bytes(), data)
    return changes


def patch_bytes(changes):
    parts = []
    for name, (before, after) in changes.items():
        parts.extend(difflib.unified_diff(before.decode().splitlines(True), after.decode().splitlines(True),
            fromfile='a/' + name, tofile='b/' + name))
    return ''.join(parts).encode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True, help='fresh unapplied patch outside production Source')
    parser.add_argument('--runtime-only', action='store_true')
    args = parser.parse_args()
    if args.output.resolve().is_relative_to(ROOT / 'Source'):
        parser.error('patch output must remain outside production Source')
    changes = runtime_changes() if args.runtime_only else activation()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('xb') as output:
        output.write(patch_bytes(changes))
    print('Prepared an unapplied 5.5a patch: 108 installed candidate maps. Main remains 65 until acceptance.')

if __name__ == '__main__':
    main()
