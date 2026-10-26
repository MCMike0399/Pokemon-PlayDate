#!/usr/bin/env python3
"""Verify primary oracle bytes and the callback policies used by batch B."""
import argparse
import hashlib
import json
from pathlib import Path
import urllib.request

from tools.generate_ability_move_metadata import entries

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'tools/references/contact-abilities-sources.json'
DEFAULT_CACHE = Path.home() / 'Developer/Pokemon-PlayDate-env/preparation/common-abilities-oracle'


def load(cache=DEFAULT_CACHE, fetch=False):
    manifest = json.loads(MANIFEST.read_text())
    result = {}
    for name, record in manifest['files'].items():
        path = cache / name
        if not path.exists() and fetch:
            raw = urllib.request.urlopen(record['url'], timeout=30).read()
            if hashlib.sha256(raw).hexdigest() != record['sha256']:
                raise ValueError('source checksum: '+name)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
        raw = path.read_bytes()
        if hashlib.sha256(raw).hexdigest() != record['sha256']:
            raise ValueError('source checksum: '+name)
        result[name] = raw.decode()
    return result


def policies(sources):
    base = entries(sources['ps_data_abilities.ts'])
    # These callbacks inherit unchanged from base through the Gen V mod chain.
    inherited = ['effectspore','cutecharm','synchronize','stench','angerpoint','naturalcure']
    for generation in [8,7,6,5]:
        overrides = entries(sources[f'ps_data_mods_gen{generation}_abilities.ts'])
        for name in inherited:
            if name in overrides:
                assert 'on' not in overrides[name].replace('inherit', ''), (generation,name)
    assert 'r < 11' in base['effectspore'] and 'r < 21' in base['effectspore'] and 'r < 30' in base['effectspore']
    assert "randomChance(3, 10)" in base['cutecharm']
    assert "effect?.id === 'toxicspikes'" in base['synchronize']
    assert "status.id === 'slp' || status.id === 'frz'" in base['synchronize']
    assert "chance: 10" in base['stench'] and "secondary.volatileStatus === 'flinch'" in base['stench']
    assert "if (!target.hp) return" in base['angerpoint'] and 'atk: 12' in base['angerpoint']
    assert 'onSwitchOut(pokemon)' in base['naturalcure'] and 'pokemon.clearStatus()' in base['naturalcure']
    magic = entries(sources['ps_data_mods_gen6_abilities.ts'])['magicguard']
    assert "effect.effectType !== 'Move'" in magic
    confusion = entries(sources['ps_data_mods_gen6_conditions.ts'])['confusion']
    assert "effectType: 'Move'" in confusion and 'randomChance(1, 2)' in confusion
    actions = sources['ps_sim_battle-actions.ts']
    assert "directDamage(recoilDamage, pokemon, pokemon, { id: 'strugglerecoil' }" in actions
    assert "this.battle.damage(recoilDamage, pokemon, pokemon, effect)" in actions
    attract = entries(sources['ps_data_moves.ts'])['attract']
    assert 'onBeforeMovePriority: 2' in attract and 'randomChance(1, 2)' in attract
    assert '!this.effectState.source.isActive' in attract and 'noCopy: true' in attract
    # Gen5 Grass damageTaken replaces the modern powder immunity map.
    grass = entries(sources['ps_data_mods_gen5_typechart.ts'])['grass']
    assert 'powder' not in grass
    return dict(files=len(sources), abilities=7, primary_revision='9b136a8c8cdb860a8ab96fa063f906604e352547',
                sdk_executed=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache', type=Path, default=DEFAULT_CACHE)
    parser.add_argument('--fetch', action='store_true')
    args = parser.parse_args()
    print(json.dumps(policies(load(args.cache, args.fetch)), indent=2))
