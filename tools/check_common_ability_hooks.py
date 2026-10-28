#!/usr/bin/env python3
"""Focused offline primary-source checks. No Lua runtime or mechanics-test credit."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.generate_ability_move_metadata import FILES, entries

ROOT = Path(__file__).resolve().parents[1]
DEFAULT = Path.home() / 'Developer/Pokemon-PlayDate-env/preparation'


def checked(path, digest):
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != digest:
        raise ValueError(f'pinned source checksum: {path}')
    return raw.decode()


def check(abilities, moves):
    manifest = json.loads((ROOT / 'tools/references/early-abilities-sources.json').read_text())['files']
    names = ['ps_data_abilities.ts'] + [f'ps_data_mods_gen{gen}_abilities.ts' for gen in (8, 7, 6, 5)]
    names += ['ps_sim_battle.ts', 'ps_sim_battle-actions.ts']
    sources = {name: checked(abilities / name, manifest[name]['sha256']) for name in names}
    base = entries(sources['ps_data_abilities.ts'])
    assertions = 0

    def require(condition, label):
        nonlocal assertions
        if not condition:
            raise ValueError(label)
        assertions += 1

    # Literal callbacks checked through the pinned inheritance chain. In
    # particular, do not accidentally use Gen9 Inner Focus or self-sound policy.
    for key, token in {
        'intimidate': "this.boost({ atk: -1 }",
        'forewarn': 'if (!bp && move.category !== \'Status\') bp = 80;',
        'vitalspirit': "status.id !== 'slp'",
        'waterveil': "status.id !== 'brn'",
        'noguard': 'onAnyAccuracy(',
        'shellarmor': 'onCriticalHit: false',
        'skilllink': 'move.multihit = move.multihit[1]',
        'sniper': 'return this.chainModify(1.5)',
    }.items():
        require(token in base[key], f'primary callback changed: {key}')
        for gen in (8, 7, 6, 5):
            body = entries(sources[f'ps_data_mods_gen{gen}_abilities.ts']).get(key, '')
            require(not re.search(r'^\t\ton\w+', body, re.M), f'unreviewed callback override: gen{gen}/{key}')
    gen7 = entries(sources['ps_data_mods_gen7_abilities.ts'])
    gen5 = entries(sources['ps_data_mods_gen5_abilities.ts'])
    require('onTryBoost: undefined' in gen7['innerfocus'], 'Gen5 Inner Focus must allow Intimidate')
    require("if (move.flags['sound'])" in gen7['soundproof']
            and 'target !== source' not in gen7['soundproof'], 'Gen5 Soundproof TryHit policy')
    require('onAllyTryHitSide: undefined' in gen5['soundproof'], 'Gen5 side callback disabled')
    for key in ('vitalspirit', 'waterveil'):
        require("(effect as Move)?.status" in base[key], f'{key} direct-status announcement policy')
    actions = sources['ps_sim_battle-actions.ts']
    require(actions.index("this.battle.randomChance(1, critMult[critRatio])")
            < actions.index("this.battle.runEvent('CriticalHit', target"), 'critical trial precedes immunity')
    require(actions.index("this.battle.gen === 5 && !baseDamage")
            < actions.index("this.battle.runEvent('ModifyDamage'"), 'Sniper follows Gen5 minimum damage')

    # Resolve sound flags through EVERY Gen5 move override, then intersect with
    # the actual production registry. This catches tempting Sonic Boom inference.
    flags = {}
    primary = {}
    for filename, digest in FILES.items():
        text = checked(moves / filename.replace('/', '_'), digest)
        for key, body in entries(text).items():
            if filename == 'data/moves.ts':
                primary[key] = body
            field = re.search(r'^\t\tflags: \{([^}]*)\}', body, re.M)
            if field:
                flags[key] = bool(re.search(r'\bsound:\s*1\b', field[1]))
    registry = re.findall(r'^    (\w+) = Move', (ROOT / 'Source/battle/moves.lua').read_text(), re.M)
    expected = {key for key in registry if flags.get(key.lower(), False)}
    effect_text = (ROOT / 'Source/battle/effects.lua').read_text()
    sound_table = re.search(r'local soundMoves = \{(.*?)\n\}', effect_text, re.S)[1]
    actual = set(re.findall(r'(\w+)=true', sound_table))
    require(actual == expected, f'actual Gen5 sound registry differs: {actual ^ expected}')
    require('supersonic' in actual and 'sonicBoom' not in actual, 'Soundproof concrete regional boundary')

    # These are the regional fixed/variable classes encountered by Forewarn.
    # The generated metadata uses0; the primary algorithm ranks each at80.
    for key in ('lowKick', 'flail', 'sonicBoom', 'dragonRage', 'nightShade', 'seismicToss', 'psywave'):
        require(re.search(r'^\t\tbasePower: 0,', primary[key.lower()], re.M) is not None,
                f'Forewarn declared-power class changed: {key}')
    return {'ok': True, 'primary_files': len(names) + len(FILES),
            'checks': assertions, 'sound_moves': sorted(actual), 'runtime_executed': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--abilities', type=Path, default=DEFAULT / 'common-abilities-oracle')
    parser.add_argument('--moves', type=Path, default=DEFAULT / 'move-failure-phazing/showdown')
    args = parser.parse_args()
    print(json.dumps(check(args.abilities, args.moves), indent=2))


if __name__ == '__main__':
    main()
