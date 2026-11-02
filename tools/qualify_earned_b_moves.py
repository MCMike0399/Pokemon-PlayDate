#!/usr/bin/env python3
"""Static five-move qualification against exact B and pinned local primary sources.

No network fetch, Lua execution, Simulator, locks or runtime acceptance.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
if __package__ in (None, ''):
    sys.path.insert(0, str(ROOT))
from tools import move_producer_contract as c
from tools import generate_gen5_data as generator
from tools.generate_ability_move_metadata import FILES, REV, entries
from tools.verify_moves.fetch_pokeapi import PinnedSources

BASE = '00ce443a32f183599ab073d5944905fdd8c19c0e'
KEYS = {'rest', 'snore', 'yawn', 'foresight', 'revenge'}
INVERSE = 'ad40fd9b5592a4ffeb88dcfc9243cc56034b2f4ea5b2da6bb3f2a8c129da45ea'


def qualify(showdown_cache, condition_cache):
    sources = {}
    oracle = {}
    for name, checksum in FILES.items():
        raw = (showdown_cache / name.replace('/', '_')).read_bytes()
        assert c.digest(raw) == checksum, 'source checksum: ' + name
        sources[name] = checksum
        oracle[name] = entries(raw.decode())
    base = oracle['data/moves.ts']
    assert "source.status === 'slp'" in base['rest']
    assert 'source.hp === source.maxhp' in base['rest']
    assert "hasAbility('insomnia')" in base['rest'] and "hasAbility('vitalspirit')" in base['rest']
    assert "target.setStatus('slp', source, move)" in base['rest']
    assert 'target.statusState.time = 3' in base['rest']
    assert 'target.statusState.startTime = 3' in base['rest']
    assert 'this.heal(target.maxhp)' in base['rest']
    assert 'pp: 10' in oracle['data/mods/gen8/moves.ts']['rest']
    assert 'sleepUsable: true' in base['snore'] and "source.status === 'slp'" in base['snore']
    assert 'chance: 30' in base['snore'] and "volatileStatus: 'flinch'" in base['snore']
    snore5 = oracle['data/mods/gen5/moves.ts']['snore']
    assert 'basePower: 40' in snore5 and 'bypasssub' not in snore5
    assert 'duration: 2' in base['yawn'] and 'onResidualOrder: 23' in base['yawn']
    assert "target.trySetStatus('slp', this.effectState.source)" in base['yawn']
    assert "effect.id === 'yawn'" in base['safeguard']
    assert "status.id === 'yawn'" in base['safeguard']
    assert "volatileStatus: 'foresight'" in base['foresight'] and "volatileStatus: 'foresight'" in base['odorsleuth']
    assert "['Normal', 'Fighting']" in base['foresight'] and 'boosts.evasion > 0' in base['foresight']
    assert 'p.source === target && p.damage > 0 && p.thisTurn' in base['revenge']
    assert 'priority: -4' in base['revenge'] and 'move.basePower * 2' in base['revenge']
    allowed_overrides = {'rest': {'data/mods/gen8/moves.ts'},
                         'snore': {'data/mods/gen5/moves.ts'},
                         'foresight': {'data/mods/gen7/moves.ts'},
                         'yawn': set(), 'revenge': {'data/mods/gen8/moves.ts'}}
    for key, allowed in allowed_overrides.items():
        self_overrides = {name for name, rows in oracle.items() if name != 'data/moves.ts' and key in rows}
        assert self_overrides == allowed, 'unreviewed inherited override: ' + key
    pins = json.loads((ROOT / 'tools/references/contact-abilities-sources.json').read_text())['files']
    mechanics = {}
    paths = {'ps_data_conditions.ts': condition_cache / 'ps_data_conditions.ts',
             'ps_data_mods_gen5_conditions.ts': condition_cache / 'ps_data_mods_gen5_conditions.ts',
             'ps_data_mods_gen6_conditions.ts': condition_cache / 'ps_data_mods_gen6_conditions.ts',
             'ps_sim_battle.ts': condition_cache / 'ps_sim_battle.ts',
             'ps_sim_battle-actions.ts': ROOT / 'tools/references/traits/ps_sim_battle-actions.ts',
             'ps_sim_pokemon.ts': ROOT / 'tools/references/pickup/ps_sim_pokemon.ts'}
    for name, path in paths.items():
        raw = path.read_bytes()
        assert c.digest(raw) == pins[name]['sha256'], 'mechanics checksum: ' + name
        sources[name] = pins[name]['sha256']
        mechanics[name] = raw.decode()
    sleep = entries(mechanics['ps_data_conditions.ts'])['slp']
    assert 'this.random(2, 5)' in sleep and 'pokemon.statusState.time--' in sleep
    assert 'if (move.sleepUsable)' in sleep
    assert 'this.effectState.time = this.effectState.startTime' in entries(mechanics['ps_data_mods_gen5_conditions.ts'])['slp']
    assert 'target.gotAttacked(move,' in mechanics['ps_sim_battle-actions.ts']
    assert 'thisTurn: true' in mechanics['ps_sim_pokemon.ts']
    assert 'attack.thisTurn = false' in mechanics['ps_sim_battle.ts']
    current = (ROOT / 'Source/battle/moves.lua').read_text()
    prior = subprocess.check_output(['git', 'show', BASE + ':Source/battle/moves.lua'], cwd=ROOT, text=True)
    before, after = c.read_rows(prior), c.read_rows(current)
    assert len(before) == len(after) == 425 and set(before) == set(after)
    assert {key for key in before if before[key] != after[key]} == KEYS
    for key in before:
        old, new = c.fields(before[key]), c.fields(after[key])
        old = {k: v for k, v in old.items() if k not in c.PAYLOAD}
        new = {k: v for k, v in new.items() if k not in c.PAYLOAD}
        if key == 'snore':
            assert new.pop('attemptRule') == 'snore'
        if key == 'revenge':
            assert new.pop('powerRule') == 'revenge'
        assert c.same(old, new), 'changed original scalar: ' + key
    assert c.producer_epoch(prior) == 16 and c.producer_epoch(current) == 17
    semantics = c.producer_metadata()
    for key in KEYS:
        assert c.compatible(key, before[key], after[key], semantics[key], epoch=16)
        assert not c.compatible(key, before[key], after[key], semantics[key], epoch=17)
        assert not c.compatible(key, after[key], before[key], semantics[key], epoch=17)
    lowered = c.legacy_rows(after, 17)
    assert lowered == c.legacy_rows(before, 16) and len(lowered) == 424
    inverse = c.digest(json.dumps(lowered, sort_keys=True, separators=(',', ':')).encode())
    assert inverse == INVERSE
    history = c.load_contract()
    old_history = json.loads(subprocess.check_output(
        ['git', 'show', BASE + ':tools/references/move-producer-migrations.json'], cwd=ROOT, text=True))
    for key, value in old_history.items():
        if key not in ('policy', 'transitions'):
            assert c.same(history[key], value), 'changed producer history: ' + key
    earlier = {key: [entry for entry in rows if entry['version'] < 17]
               for key, rows in history['transitions'].items()}
    earlier = {key: rows for key, rows in earlier.items() if rows}
    assert c.same(earlier, old_history['transitions']), 'changed earlier transition history'
    assert history['policy'].startswith(old_history['policy'])
    inventory = json.loads((ROOT / 'tools/references/move-support.json').read_text())
    old_inventory = json.loads(subprocess.check_output(['git', 'show', BASE + ':tools/references/move-support.json'], cwd=ROOT, text=True))
    assert {key for key in inventory['moves'] if inventory['moves'][key] != old_inventory['moves'][key]} == KEYS
    preserved = {}
    for relative in ('Source/data/fieldMoveBattleData.lua', 'Source/domain/sessionCodec.lua'):
        raw = (ROOT / relative).read_bytes()
        old_raw = subprocess.check_output(['git', 'show', BASE + ':' + relative], cwd=ROOT)
        assert raw == old_raw, 'changed HM/schema owner: ' + relative
        preserved[relative] = c.digest(raw)
    hm = (ROOT / 'Source/data/fieldMoveBattleData.lua').read_text()
    for key in ('cut', 'fly', 'surf', 'strength', 'flash'):
        assert 'MoveSupport.handlers.' + key + ' =' in hm
    inputs = PinnedSources()
    data = {'moves': inputs.load('moves_pre_sv.csv'), 'move_changelog': inputs.load('move_changelog_pre_sv.csv')}
    for name in ('move_meta', 'move_meta_stat_changes', 'types'):
        data[name] = inputs.load(name + '.csv')
    with tempfile.TemporaryDirectory(prefix='earned-b-generation-') as directory:
        target = Path(directory) / 'moves.lua'
        with patch.object(generator, 'MOVES_INPUT', str(ROOT / 'Source/battle/moves.lua')), patch.object(generator, 'MOVES_LUA', str(target)), patch.object(generator, 'EXTRA_MOVE_KEYS', []):
            generator.generate_moves(data, preserve_existing=True)
        assert target.read_bytes() == current.encode(), 'regeneration drift'
    return dict(ok=True, prerequisite=BASE, oracle_revision=REV, source_sha256=sources,
                pokeapi_manifest_sha256=c.digest((ROOT / 'tools/verify_moves/sources.json').read_bytes()),
                pokeapi_inputs={name: {'revision': inputs.manifest['files'][name].get('revision', inputs.manifest['revision']),
                                     'sha256': inputs.manifest['files'][name]['sha256']}
                               for name in ('moves_pre_sv.csv', 'move_changelog_pre_sv.csv', 'move_meta.csv', 'move_meta_stat_changes.csv', 'types.csv')},
                move_rows=425, unchanged_rows=420, changed_rows=sorted(KEYS), epoch=17,
                original_scalar_fields_unchanged=True, original424_inverse_sha256=inverse,
                exact_regeneration=True, prior_transition_history_unchanged=True,
                preserved_hm_schema_sha256=preserved, native_execution=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--showdown-cache', required=True, type=Path)
    parser.add_argument('--condition-cache', required=True, type=Path)
    parser.add_argument('--report', required=True, type=Path)
    args = parser.parse_args()
    result = qualify(args.showdown_cache, args.condition_cache)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    with args.report.open('x') as output:
        output.write(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__':
    main()
