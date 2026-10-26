#!/usr/bin/env python3
"""Verify the existing immutable Gen5 oracle and bounded callback contracts.

This reads primary JavaScript; it does not execute JavaScript or emulate Lua.
"""
import argparse
import json
from pathlib import Path

from tools.check_contact_ability_sources import DEFAULT_CACHE, load
from tools.generate_ability_move_metadata import entries
from tools.generate_specimen_traits import load as load_traits, collect as collect_traits

ROOT = Path(__file__).resolve().parents[1]
REVISION = '9b136a8c8cdb860a8ab96fa063f906604e352547'
IDS = dict(technician=101, flashfire=18, clearbody=29, liquidooze=64,
           waterabsorb=11, swiftswim=33, levitate=26)


def policies(sources):
    base = entries(sources['ps_data_abilities.ts'])
    mods = {g: entries(sources[f'ps_data_mods_gen{g}_abilities.ts']) for g in (8, 7, 6, 5)}
    for name, number in IDS.items():
        assert f'num: {number},' in base[name], name
    # These callbacks inherit unchanged; later rating/flag edits are irrelevant.
    inherited = dict(technician='onBasePower(', flashfire='onTryHit(',
                     clearbody='onTryBoost(', waterabsorb='onTryHit(',
                     swiftswim='onModifySpe(')
    for name, callback in inherited.items():
        assert callback in base[name], name
        for generation in (8, 7, 6, 5):
            assert callback not in mods[generation].get(name, ''), (generation, name)
    tech = base['technician']
    assert 'this.modify(basePower, this.event.modifier)' in tech
    assert 'basePowerAfterMultiplier <= 60' in tech and 'chainModify(1.5)' in tech
    assert 'onBasePowerPriority: 19' in mods[7]['technician']
    for generation in (6, 5):
        assert 'onBasePowerPriority' not in mods[generation].get('technician', '')
    flash = base['flashfire']
    for text in ("target !== source && move.type === 'Fire'", "addVolatile('flashfire')",
                 'onEnd(pokemon)', "removeVolatile('flashfire')", 'noCopy: true',
                 'onModifyAtkPriority: 5', 'onModifySpAPriority: 5',
                 "attacker.hasAbility('flashfire')", 'chainModify(1.5)'):
        assert text in flash, text
    clear = base['clearbody']
    assert 'target === source' in clear and 'boost[i]! < 0' in clear
    assert '!(effect as ActiveMove).secondaries' in clear
    ooze = mods[6]['liquidooze']
    assert "['drain', 'leechseed']" in ooze
    assert 'onSourceTryHeal' in ooze and 'this.damage(damage, null, null, null, true)' in ooze
    assert 'onSourceTryHeal' not in mods[5].get('liquidooze', '')
    water = base['waterabsorb']
    assert "target !== source && move.type === 'Water'" in water
    assert 'target.baseMaxhp / 4' in water and 'return null' in water
    assert "'raindance'" in base['swiftswim'] and 'chainModify(2)' in base['swiftswim']
    # TryHeal still dispatches at full HP. Gen5 direct drain uses Math.round.
    battle = sources['ps_sim_battle.ts']
    start = battle.index('\n\theal(damage:')
    heal = battle[start:battle.index('\n\tchain(', start)]
    assert heal.index("runEvent('TryHeal'") < heal.index('target.hp >= target.maxhp')
    assert 'Math.round(targetDamage * effect.drain[0] / effect.drain[1])' in battle
    pokemon = sources['ps_sim_pokemon.ts']
    assert "hasAbility('levitate')" in pokemon and 'isGrounded(' in pokemon
    return dict(primary_revision=REVISION, primary_files=len(sources),
                abilities=IDS, sdk_executed=False, native_discrepancies=[])


def verify(cache=DEFAULT_CACHE):
    report = policies(load(cache))
    # Also check actual ordinary acquisition slots; no hidden ability override.
    traits = collect_traits(load_traits(ROOT / 'tools/references/traits'), ROOT)
    report['personal_species'] = len(traits)
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache', type=Path, default=DEFAULT_CACHE)
    args = parser.parse_args()
    print(json.dumps(verify(args.cache), indent=2))
