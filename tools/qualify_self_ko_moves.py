#!/usr/bin/env python3
"""Bounded host proof against private B and checksum-verified local Gen V sources."""
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

BASE = 'f6e10a97'
KEYS = {'selfDestruct', 'explosion'}


def qualify(preparation):
    pins = {}
    for name, checksum in FILES.items():
        raw = (preparation / 'move-failure-phazing/showdown' / name.replace('/', '_')).read_bytes()
        assert c.digest(raw) == checksum, name
        pins[name] = checksum
        rows = entries(raw.decode())
        if name == 'data/moves.ts':
            for key, power in (('selfdestruct', 200), ('explosion', 250)):
                assert 'selfdestruct: "always"' in rows[key]
                assert 'basePower: ' + str(power) in rows[key]
                assert 'target: "allAdjacent"' in rows[key]
        else:
            assert not {'selfdestruct', 'explosion'} & set(rows), name
    manifest = json.loads((ROOT / 'tools/references/contact-abilities-sources.json').read_text())
    assert manifest['revision'] == REV
    mechanics = {}
    names = ['ps_data_abilities.ts'] + ['ps_data_mods_gen' + str(gen) + '_abilities.ts' for gen in (8, 7, 6, 5)]
    names += ['ps_sim_battle.ts', 'ps_sim_battle-actions.ts', 'ps_sim_pokemon.ts']
    for name in names:
        path = preparation / 'common-abilities-oracle' / name
        if name == 'ps_sim_battle-actions.ts':
            path = ROOT / 'tools/references/traits' / name
        elif name == 'ps_sim_pokemon.ts':
            path = ROOT / 'tools/references/pickup' / name
        raw = path.read_bytes()
        assert c.digest(raw) == manifest['files'][name]['sha256'], name
        pins[name] = c.digest(raw)
        mechanics[name] = raw.decode()
    abilities = entries(mechanics['ps_data_abilities.ts'])
    assert 'onAnyTryMove' in abilities['damp'] and 'return false' in abilities['damp']
    assert 'breakable: 1' in abilities['damp']
    for key in ('moldbreaker', 'teravolt', 'turboblaze'):
        assert 'move.ignoreAbility = true' in abilities[key]
    for name in names[1:5]:
        overrides = entries(mechanics[name])
        for key in ('damp', 'moldbreaker', 'teravolt', 'turboblaze'):
            if key in overrides:
                assert not any(token in overrides[key] for token in ('onAny', 'onModifyMove', 'flags:'))
                assert 'inherit: true' in overrides[key]
    actions = mechanics['ps_sim_battle-actions.ts']
    assert actions.index("this.battle.runEvent('TryMove'") < actions.index("move.selfdestruct === 'always'")
    assert actions.index("move.selfdestruct === 'always'") < actions.index('this.trySpreadMoveHit(targets, pokemon, move)')
    assert "this.battle.gen <= 4 && ['explosion', 'selfdestruct']" in actions
    pokemon = mechanics['ps_sim_pokemon.ts']
    faint = pokemon[pokemon.index('\tfaint(source:'):pokemon.index('\tdamage(d:')]
    assert 'this.hp = 0' in faint and 'this.battle.faintQueue.push' in faint
    battle = mechanics['ps_sim_battle.ts']
    assert 'this.faintQueue.shift()' in battle
    assert 'this.win(faintData && this.gen > 4 ? faintData.target.side : null)' in battle
    assert '(this.activePokemon !== target || this.gen < 8)' in battle
    before_text = subprocess.check_output(['git', 'show', BASE + ':Source/battle/moves.lua'], cwd=ROOT, text=True)
    current = (ROOT / 'Source/battle/moves.lua').read_text()
    before, after = c.read_rows(before_text), c.read_rows(current)
    assert len(before) == len(after) == 425
    assert {key for key in before if before[key] != after[key]} == KEYS
    assert c.producer_epoch(before_text) == 17 and c.producer_epoch(current) == 18
    for key in KEYS:
        assert c.drop_fields(after[key], ('selfDestruct',)) == before[key]
        assert c.compatible(key, before[key], after[key], c.producer_metadata()[key], epoch=17)
        assert not c.compatible(key, before[key], after[key], c.producer_metadata()[key], epoch=18)
        assert not c.compatible(key, after[key], before[key], c.producer_metadata()[key], epoch=18)
    legacy = c.legacy_rows(after, 18)
    assert legacy == c.legacy_rows(before, 17)
    inverse = c.digest(json.dumps(legacy, sort_keys=True, separators=(',', ':')).encode())
    assert inverse == c.load_contract()['legacy_rows_sha256']
    preserved = {}
    for name in ('tools/references/move-producer-migrations.json', 'Source/domain/sessionCodec.lua',
                 'Source/data/fieldMoveBattleData.lua', 'Source/dev/contracts.lua', 'tools/harness/dev_imports.lua'):
        raw = (ROOT / name).read_bytes()
        original = subprocess.check_output(['git', 'show', BASE + ':' + name], cwd=ROOT)
        if name == 'tools/harness/dev_imports.lua':
            anchor = b'Contracts.register("earned-b-moves", EarnedBMoveContracts.run)\n'
            registration = b'import "dev/selfKOMoveContracts"\nContracts.register("self-ko-moves", SelfKOMoveContracts.run)\n'
            assert original.count(anchor) == 1
            assert raw in (original, original.replace(anchor, anchor + registration, 1)), name
        else:
            assert raw == original, name
        preserved[name] = c.digest(raw)
    old_support = json.loads(subprocess.check_output(['git', 'show', BASE + ':tools/references/move-support.json'], cwd=ROOT))
    support = json.loads((ROOT / 'tools/references/move-support.json').read_text())
    assert {k for k in support['moves'] if support['moves'][k] != old_support['moves'][k]} == KEYS
    assert support['moves']['substitute'] == old_support['moves']['substitute']
    inputs = PinnedSources()
    data = {}
    for name, file in [('moves', 'moves_pre_sv.csv'), ('move_changelog', 'move_changelog_pre_sv.csv'),
                       ('move_meta', 'move_meta.csv'), ('move_meta_stat_changes', 'move_meta_stat_changes.csv'), ('types', 'types.csv')]:
        data[name] = inputs.load(file)
    with tempfile.TemporaryDirectory(prefix='self-ko-generation-') as temporary:
        target = Path(temporary) / 'moves.lua'
        with patch.object(generator, 'MOVES_INPUT', str(ROOT / 'Source/battle/moves.lua')), patch.object(generator, 'MOVES_LUA', str(target)), patch.object(generator, 'EXTRA_MOVE_KEYS', []):
            generator.generate_moves(data, True)
        assert target.read_text() == current
    return dict(ok=True, base=subprocess.check_output(['git', 'rev-parse', BASE], cwd=ROOT, text=True).strip(),
                oracle_revision=REV, oracle_sha256=pins, changed_rows=sorted(KEYS), unchanged_rows=423,
                epoch=18, original424_inverse_sha256=inverse, preserved_sha256=preserved,
                exact_regeneration=True, native_execution=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preparation', required=True, type=Path)
    parser.add_argument('--report', required=True, type=Path)
    args = parser.parse_args()
    result = qualify(args.preparation)
    args.report.write_text(json.dumps(result, indent=2) + '\n')
