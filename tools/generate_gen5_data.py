#!/usr/bin/env python3
"""Regenerate Gen V (Black 2 / White 2) battle data.

Produces:
  Source/battle/moves.lua      — full move data: B2W2 power/accuracy/pp/type/
                                 priority/damage class + effects composed from
                                 the battle DSL (ailments, stat changes, flinch,
                                 healing) + drain/recoil/multi-hit fields
  Source/data/pokemon.lua      — species blocks updated in place: Gen V types,
                                 base stats split into SpA/SpD, Speed renamed
                                 baseSpe, plus baseExp for the XP formula
                                 (name/dex/movesets preserved)

Sources (cached in tools/gen5cache/):
  PokeAPI CSV dumps  — moves, move_changelog (resolves values as of version
                       group 14 = B2W2), move_meta, move_meta_stat_changes,
  Pinned B2W2 personal table — Gen V base experience yields, independently
                       cross-checked by generate_growth_data.py
  Pokémon Showdown   — pokedex.ts + mods/gen{8,7,6,5}/pokedex.ts applied in
                       order, yielding Gen V base stats and types

Run moves-only into an explicit staging root:
  python3 tools/generate_gen5_data.py --input-root . --output-root /tmp/stage \
      --moves-only --pinned-cache /path/to/pinned/csvs --extra-move charm
Full species generation still uses mutable historical Showdown fetch paths;
that uninvoked mode requires a separate provenance migration.
"""

import argparse
import csv
import io
import json
import os
import re
import sys
import urllib.request
from pathlib import Path

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, "tools", "gen5cache")
MOVES_LUA = os.path.join(ROOT, "Source", "battle", "moves.lua")
POKEMON_LUA = os.path.join(ROOT, "Source", "data", "pokemon.lua")

MOVES_INPUT = MOVES_LUA
POKEMON_INPUT = POKEMON_LUA
EXTRA_MOVE_KEYS = []

B2W2_VERSION_GROUP = 14

POKEAPI_CSV = "https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv/"
SHOWDOWN = "https://raw.githubusercontent.com/smogon/pokemon-showdown/master/data/"

CSV_FILES = ["moves", "move_changelog", "move_meta", "move_meta_stat_changes", "types"]
SHOWDOWN_FILES = ["pokedex.ts", "mods/gen8/pokedex.ts", "mods/gen7/pokedex.ts",
                  "mods/gen6/pokedex.ts", "mods/gen5/pokedex.ts"]

STAT_KEYS = {2: "atk", 3: "def", 4: "spa", 5: "spd", 6: "spe", 7: "acc", 8: "eva"}
AILMENTS = {1: "paralyze", 2: "sleep", 3: "freeze", 4: "burn", 5: "poison", 6: "confuse"}
TARGET_USER = 7  # PokeAPI move target id for "user"

# Moves whose negative stat changes hit the USER, not the target
SELF_LOWER = {"superpower", "overheat", "leafStorm", "dracoMeteor", "closeCombat",
              "hammerArm", "psychoBoost", "vCreate", "shellSmash", "curse"}
# Moves whose positive stat changes raise the TARGET
TARGET_RAISE = {"swagger", "flatter"}

# PokeAPI identifiers that don't follow plain camelCase->kebab conversion
MOVE_ALIASES = {"conversion2": "conversion-2"}
SPECIES_ALIASES = {"mr": "mrmime"}
SPECIES_CSV_ALIASES = {"mr": "mr-mime"}

# PokeAPI's move_changelog misses the Gen IX PP nerf to 10-PP healing moves;
# these are the Gen V values
PP_OVERRIDES = {"recover": 10, "roost": 10, "softBoiled": 10,
                "milkDrink": 10, "slackOff": 10, "rest": 10}

# Classic fixed-damage / OHKO moves the formula can't express — DSL effects
FIXED_DAMAGE = {
    "psywave": "PsywaveDamage()",
    "sonicBoom": 'DirectDamage(DEFENDER, 20)',
    "dragonRage": 'DirectDamage(DEFENDER, 40)',
    "seismicToss": 'DirectDamage(DEFENDER, LevelOf(ATTACKER))',
    "nightShade": 'DirectDamage(DEFENDER, LevelOf(ATTACKER))',
    "superFang": 'DirectDamage(DEFENDER, Product(CurrentHPOf(DEFENDER), 0.5))',
    "guillotine": 'DirectDamage(DEFENDER, CurrentHPOf(DEFENDER))',
    "hornDrill": 'DirectDamage(DEFENDER, CurrentHPOf(DEFENDER))',
    "fissure": 'DirectDamage(DEFENDER, CurrentHPOf(DEFENDER))',
    "sheerCold": 'DirectDamage(DEFENDER, CurrentHPOf(DEFENDER))',
}


def fetch(url, path):
    if os.path.exists(path):
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": "PokemonPoC/1.0"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        data = resp.read()
    with open(path, "wb") as f:
        f.write(data)
    print(f"fetched {url}")


def load_all():
    data = {}
    for name in CSV_FILES:
        path = os.path.join(CACHE, name + ".csv")
        fetch(POKEAPI_CSV + name + ".csv", path)
        with open(path, encoding="utf-8") as f:
            data[name] = list(csv.DictReader(f))
    for rel in SHOWDOWN_FILES:
        path = os.path.join(CACHE, rel.replace("/", "_"))
        fetch(SHOWDOWN + rel, path)
        with open(path, encoding="utf-8") as f:
            data[rel] = f.read()
    return data


def camel_to_kebab(key):
    return re.sub(r"([A-Z])", lambda m: "-" + m.group(1).lower(), key)


def num(value):
    return int(value) if value not in ("", None) else None


# ----------------------------------------------------------------------
# Moves
# ----------------------------------------------------------------------

def resolve_b2w2(move_row, changelog_rows):
    """Apply move_changelog: an entry 'changed_in vg X' holds the values that
    applied BEFORE X. The B2W2 value of a field is from the entry with the
    smallest X > 14; fields with no such entry keep their current value."""
    fields = {
        "type_id": num(move_row["type_id"]),
        "power": num(move_row["power"]),
        "pp": num(move_row["pp"]),
        "accuracy": num(move_row["accuracy"]),
        "priority": num(move_row["priority"]),
        "effect_chance": num(move_row["effect_chance"]),
        "target_id": num(move_row["target_id"]),
    }
    entries = [r for r in changelog_rows
               if int(r["changed_in_version_group_id"]) > B2W2_VERSION_GROUP]
    entries.sort(key=lambda r: int(r["changed_in_version_group_id"]))
    for field in fields:
        for entry in entries:
            if entry.get(field) not in ("", None):
                fields[field] = num(entry[field])
                break
    return fields


def build_effects(key, meta, stat_changes, target_id, is_status):
    # Pinned Gen V mechanic overrides; modern move_meta includes later changes.
    concrete={
        "whirlwind": ["ForceSwitchEffect(DEFENDER)"],
        "roar": ["ForceSwitchEffect(DEFENDER)"],
        "sandstorm": ["SandstormEffect()"],
        "rainDance": ['WeatherEffect("raindance")'],
        "focusEnergy": ["FocusEnergyEffect()"],
        "protect": ["ProtectEffect()"],
        "roost": ["RoostEffect()"],
        "poisonFang": ['When(Chance(30), ApplyStatus(DEFENDER, "badPoison"))'],
        "lightScreen": ['SideConditionEffect("lightScreen")'],
        "safeguard": ['SideConditionEffect("safeguard")'],
        "tailwind": ['SideConditionEffect("tailwind")'],
        "worrySeed": ["WorrySeedEffect()"],
        "triAttack": ['When(Chance(20), RandomMajorStatusEffect(DEFENDER, {"burn", "paralyze", "freeze"}))'],
        "synthesis": ["WeatherHealEffect()"],"moonlight": ["WeatherHealEffect()"],"morningSun": ["WeatherHealEffect()"],
        "mudSport": ["MudSportEffect()"], "curse": ["CurseEffect()"],
        "rage": ["RageEffect()"], "rapidSpin": ["RapidSpinEffect()"],
        "stringShot": ['ModifyStat(DEFENDER, "spe", -1)'],
        "defenseCurl": ['ModifyStat(ATTACKER, "def", 1)',"DefenseCurlEffect()"],
        "leechSeed": ["LeechSeedEffect()"],
        "spikes": ['EntryHazardEffect("spikes")'],
        "toxicSpikes": ['EntryHazardEffect("toxicSpikes")'],
        "stealthRock": ['EntryHazardEffect("stealthRock")'],
        "toxic": ['ApplyStatus(DEFENDER, "badPoison")'],
    }
    if key in concrete:return concrete[key]
    if key in {"bind","wrap","clamp","fireSpin","whirlpool","sandTomb","magmaStorm"}:return ["PartialTrapEffect()"]
    if key == "sweetScent":
        return ['ModifyStat(DEFENDER, "eva", -1)']
    effects = []

    if key in FIXED_DAMAGE:
        effects.append(FIXED_DAMAGE[key])

    ailment = AILMENTS.get(int(meta["meta_ailment_id"] or 0)) if meta else None
    if ailment:
        chance = int(meta["ailment_chance"] or 0)
        target = "ATTACKER" if target_id == TARGET_USER else "DEFENDER"
        apply_str = f'ApplyStatus({target}, "{ailment}")'
        effects.append(f"When(Chance({chance}), {apply_str})" if chance > 0 else apply_str)

    flinch = int(meta["flinch_chance"] or 0) if meta else 0
    if flinch > 0:
        effects.append(f'When(Chance({flinch}), ApplyStatus(DEFENDER, "flinch"))')

    stat_chance = int(meta["stat_chance"] or 0) if meta else 0
    changes = []
    for sc in stat_changes:
        stat = STAT_KEYS.get(int(sc["stat_id"]))
        if not stat:
            continue
        change = int(sc["change"])
        if key in SELF_LOWER:
            target = "ATTACKER"
        elif key in TARGET_RAISE:
            target = "DEFENDER"
        elif target_id == TARGET_USER:
            target = "ATTACKER"
        else:
            target = "ATTACKER" if change > 0 else "DEFENDER"
        changes.append(f'ModifyStat({target}, "{stat}", {change})')
    if changes:
        if stat_chance > 0:
            inner = changes[0] if len(changes) == 1 else "EffectSeq{ " + ", ".join(changes) + " }"
            effects.append(f"When(Chance({stat_chance}), {inner})")
        else:
            effects.extend(changes)

    healing = int(meta["healing"] or 0) if meta else 0
    if healing > 0:
        effects.append(f"Heal(ATTACKER, Product(MaxHPOf(ATTACKER), {healing / 100}))")

    return effects


def lazy_move_registry(header, rows):
    """Change construction timing only; canonical rows stay verifier-readable."""
    text = "\n".join(rows)
    names = {"Move"} | set(re.findall(r"\b([A-Z]\w*)\(", text))
    names.update(name for name in ("ATTACKER", "DEFENDER") if name in text)
    aliases = "\n".join(f"local {name} <const> = {name}" for name in sorted(names))
    header = header.replace('Class("Move")', 'import "data/moveRegistry"\n\nClass("Move")', 1)
    header = header.replace("moveData = {\n", aliases + "\n\nmoveData = {\n", 1)
    wrapped = []
    for row in rows:
        match = re.fullmatch(r"    (\w+) = (Move.+),", row)
        if not match:
            raise ValueError("unsupported generated move row")
        wrapped.extend([f"    {match[1]} = function()", f"        return {match[2]}", "    end,"])
    return header + "\n".join(wrapped) + "\n}\nmoveData = MoveRegistry.new(moveData)\n"


def generate_moves(data, preserve_existing=False):
    with open(MOVES_INPUT, encoding="utf-8") as f:
        current = f.read()
    from tools import move_producer_contract as move_contract
    keys = list(move_contract.read_rows(current))
    if not keys:
        sys.exit("no move keys found in moves.lua")

    original_keys=set(keys)
    for key in EXTRA_MOVE_KEYS:
        if key not in keys:
            keys.append(key)

    moves_by_ident = {r["identifier"]: r for r in data["moves"]}
    changelog = {}
    for r in data["move_changelog"]:
        changelog.setdefault(r["move_id"], []).append(r)
    meta_by_id = {r["move_id"]: r for r in data["move_meta"]}
    stat_changes_by_id = {}
    for r in data["move_meta_stat_changes"]:
        stat_changes_by_id.setdefault(r["move_id"], []).append(r)
    type_names = {r["id"]: r["identifier"] for r in data["types"]}
    class_names = {1: "status", 2: "physical", 3: "special"}

    # Shared declarative contract validates the immutable derived metadata; the
    # independent primary qualifier replays its pinned Showdown sources.
    from tools import move_producer_contract as move_contract
    ability_metadata=move_contract.producer_metadata()
    out, missing = [], []
    for key in keys:
        row = moves_by_ident.get(MOVE_ALIASES.get(key) or camel_to_kebab(key))
        if not row:
            missing.append(key)
            continue
        if int(row["generation_id"]) > 5:
            raise ValueError("move introduced after Gen V: " + key)
        move_id = row["id"]
        fields = resolve_b2w2(row, changelog.get(move_id, []))
        if fields["target_id"] not in range(1, 15):
            raise ValueError("invalid Gen V target metadata: " + key)
        meta = meta_by_id.get(move_id)
        target_id = num(row["target_id"]) or 0
        category = class_names[num(row["damage_class_id"]) or 1]
        is_status = category == "status"

        effects = build_effects(key, meta, stat_changes_by_id.get(move_id, []),
                                target_id, is_status)

        # GenV source critical metadata:6 is an always-crit marker, never a
        # stage. The independent qualifier compares all424 against PS Gen5.
        crit_rate=int(meta.get("crit_rate")or 0)if meta else 0
        if crit_rate==6:
            if key!="stormThrow":raise ValueError("undeclared forced-crit producer: "+key)
            crit_stage=0
        elif 0<=crit_rate<=4:crit_stage=crit_rate
        else:raise ValueError("invalid GenV critical stage: "+key)
        semantics=ability_metadata[key]
        secondaries=[]
        if semantics['secondary']:
            primary=[]
            for effect in effects:
                # Eligibility is from the pinned resolved Gen5 secondary field,
                # never power/category or chance alone. Target comes from the DSL.
                if ('ApplyStatus(' in effect or 'ModifyStat(' in effect or 'RandomMajorStatusEffect(' in effect) and 'DEFENDER' in effect:
                    secondaries.append('SecondaryEffect(DEFENDER, '+effect+')')
                elif ('ApplyStatus(' in effect or 'ModifyStat(' in effect or 'RandomMajorStatusEffect(' in effect) and 'ATTACKER' in effect:
                    secondaries.append('SecondaryEffect(ATTACKER, '+effect+')')
                else:primary.append(effect)
            effects=primary
        if semantics['ohko']:effects=[]
        display = camel_to_kebab(key).replace("-", " ").upper()
        parts = [
            f'name = "{display}"',
            f'type = "{type_names[str(fields["type_id"])]}"',
            f'category = "{category}"',
            f"power = {fields['power'] or 0}",
            f"accuracy = {fields['accuracy'] or 0}",
            f"pp = {PP_OVERRIDES.get(key, fields['pp'])}",
            f"targetId = {fields['target_id']}",
        ]
        parts.extend(["contact = " + str(semantics['contact']).lower(),
                      "hasSecondary = " + str(semantics['secondary']).lower(),
                      "ohko = " + str(semantics['ohko']).lower()])
        for field,value in move_contract.protection_metadata()[key].items():
            parts.append(field + " = " + json.dumps(value))
        if semantics["typeImmunity"]: parts.append("typeImmunity = true")
        if key == "solarBeam": parts.append("sandWeakened = true")
        if key == "rollout": parts.append("rollout = true")
        if key == "curse": parts.append("curse = true")
        if key == "struggle":
            parts.extend(["typeless = true", "noPP = true", "struggleRecoil = true"])
        if key == "stormThrow":
            parts.append("willCrit = true")
        if crit_stage:parts.append(f"critStage = {crit_stage}")
        for field,value in move_contract.RULES.get(key,{}).items():
            parts.append(field + " = " + json.dumps(value))
        if fields["priority"]:
            parts.append(f"priority = {fields['priority']}")
        if meta:
            drain = int(meta["drain"] or 0)
            if drain and key != "struggle":
                parts.append(f"drain = {drain}")
            min_hits, max_hits = num(meta["min_hits"]), num(meta["max_hits"])
            if min_hits and max_hits and max_hits > 1:
                parts.append(f"minHits = {min_hits}, maxHits = {max_hits}")
        if secondaries:
            parts.append("secondaries = { " + ", ".join(secondaries) + " }")
        if effects:
            parts.append("effects = { " + ", ".join(effects) + " }")

        out.append(f"    {key} = Move{{ {', '.join(parts)} }},")

    header = '''-- move-producer-contract: 13
-- Generated by tools/generate_gen5_data.py — do not edit move data by hand.
-- Gen V (Black 2 / White 2) move data: power/accuracy/pp/type/priority
-- resolved through PokeAPI's move_changelog as of version group 14 (B2W2);
-- damage classes are the per-move Gen IV+ physical/special split; effects
-- are composed from the battle DSL (battle/dsl.lua, imported before this
-- file). drain is % of damage dealt (negative = recoil); minHits/maxHits
-- mark multi-hit moves (Gen V 2-5 distribution lives in the engine).

Class("Move")
function Move:init(m)
    self.name = m.name
    self.type = m.type
    self.category = m.category
    self.power = m.power
    self.accuracy = m.accuracy   -- 0 = never misses
    self.pp = m.pp
    self.maxPP = m.pp
    self.targetId = m.targetId or 10
    self.priority = m.priority or 0
    self.rollout = m.rollout or false
    self.curse = m.curse or false
    self.willCrit = m.willCrit or false
    self.critStage = m.critStage or 0
    self.powerRule = m.powerRule
    self.damageRule = m.damageRule
    self.attemptRule = m.attemptRule
    self.chargeRule = m.chargeRule
    self.lockRule = m.lockRule
    self.weatherAccuracy = m.weatherAccuracy or false
    self.protectable = m.protectable or false
    self.breaksProtect = m.breaksProtect or false
    self.typeless = m.typeless or false
    self.noPP = m.noPP or false
    self.struggleRecoil = m.struggleRecoil or false
    self.drain = m.drain
    self.minHits = m.minHits
    self.maxHits = m.maxHits
    self.typeImmunity = m.typeImmunity or false
    self.sandWeakened = m.sandWeakened or false
    self.contact = m.contact or false
    self.hasSecondary = m.hasSecondary or false
    self.ohko = m.ohko or false
    self.secondaries = m.secondaries
    self.effects = m.effects
end

moveData = {
'''
    if missing:
        raise ValueError("move IDs missing from source: " + ", ".join(missing))
    if preserve_existing:
        old_rows=move_contract.read_rows(current)
        if set(old_rows)!=original_keys:raise ValueError("unsupported existing declarative move layout")
        new_rows = dict(re.findall(r"^    (\w+) = (Move[^\n]+)$", "\n".join(out), re.MULTILINE))
        contract=move_contract.load_contract()
        epoch=move_contract.producer_epoch(current)
        changed=[key for key,value in old_rows.items()
                 if not move_contract.compatible(key,value,new_rows.get(key),ability_metadata[key],contract,epoch)]
        if changed:
            raise ValueError("refusing unexpected changes to existing move rows: " + ", ".join(changed))
    os.makedirs(os.path.dirname(MOVES_LUA), exist_ok=True)
    with open(MOVES_LUA, "w", encoding="utf-8") as f:
        f.write(lazy_move_registry(header, out))

    print(f"moves.lua: {len(out)}/{len(keys)} moves written")
    if missing:
        print(f"  NOT FOUND in PokeAPI (kept out!): {', '.join(missing)}")


# ----------------------------------------------------------------------
# Species
# ----------------------------------------------------------------------

def parse_showdown_entries(ts_text):
    entries = {}
    for m in re.finditer(r"\n\t(\w+): \{(.*?)\n\t\},", ts_text, re.DOTALL):
        ident, body = m.group(1), m.group(2)
        entry = {}
        tm = re.search(r'types: ?\[([^\]]*)\]', body)
        if tm:
            entry["types"] = [t.strip().strip('"').lower() for t in tm.group(1).split(",")]
        sm = re.search(r"baseStats: ?\{([^}]*)\}", body)
        if sm:
            stats = {}
            for part in sm.group(1).split(","):
                k, v = part.split(":")
                stats[k.strip()] = int(v.strip())
            entry["baseStats"] = stats
        if entry:
            entries[ident] = entry
    return entries


def resolve_gen5_dex(data):
    resolved = parse_showdown_entries(data["pokedex.ts"])
    for rel in ["mods/gen8/pokedex.ts", "mods/gen7/pokedex.ts",
                "mods/gen6/pokedex.ts", "mods/gen5/pokedex.ts"]:
        for ident, entry in parse_showdown_entries(data[rel]).items():
            resolved.setdefault(ident, {}).update(entry)
    return resolved


def load_gen5_yields(cache, fetch=False):
    """Use the authoritative growth projection, never modern PokeAPI yields."""
    sys.path.insert(0, ROOT)
    from tools.generate_growth_data import load_sources, collect
    _, species = collect(load_sources(cache, fetch))
    return {dex: values[1] for dex, values in species.items()}


def generate_species(data, gen5_yields):
    with open(POKEMON_INPUT, encoding="utf-8") as f:
        src = f.read()

    dex = resolve_gen5_dex(data)

    block_re = re.compile(
        r'(^    (\w+) = \{\n'
        r'        name = "([^"]+)", dex = (\d+), )type = [^\n]*\n'
        r'        base[^\n]*\n',
        re.MULTILINE)

    changed, missing = [], []

    def replace(m):
        prefix, key, _name, _dexnum = m.group(1), m.group(2), m.group(3), m.group(4)
        ident = SPECIES_ALIASES.get(key) or key.lower()
        entry = dex.get(ident)
        if not entry or "baseStats" not in entry or "types" not in entry:
            missing.append(key)
            return m.group(0)
        s = entry["baseStats"]
        types = entry["types"]
        type2 = f'"{types[1]}"' if len(types) > 1 else "nil"
        exp = gen5_yields[int(_dexnum)]
        changed.append(key)
        return (f'{prefix}type = "{types[0]}", type2 = {type2},\n'
                f'        baseHP = {s["hp"]}, baseAtk = {s["atk"]}, baseDef = {s["def"]}, '
                f'baseSpA = {s["spa"]}, baseSpD = {s["spd"]}, baseSpe = {s["spe"]}, '
                f'baseExp = {exp},\n')

    out = block_re.sub(replace, src)
    os.makedirs(os.path.dirname(POKEMON_LUA), exist_ok=True)
    with open(POKEMON_LUA, "w", encoding="utf-8") as f:
        f.write(out)

    print(f"pokemon.lua: {len(changed)} species updated")
    if missing:
        print(f"  NOT RESOLVED (left untouched!): {', '.join(missing)}")


def main():
    global MOVES_INPUT, MOVES_LUA, POKEMON_INPUT, POKEMON_LUA, EXTRA_MOVE_KEYS
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-root", type=Path, default=Path(ROOT), help="project root containing input Source")
    parser.add_argument("--output-root", type=Path, required=True, help="explicit project root receiving generated Source")
    parser.add_argument("--moves-only", action="store_true", help="skip species/Showdown, pin CSV inputs and preserve every existing move row")
    parser.add_argument("--pinned-cache", type=Path)
    parser.add_argument("--fetch", action="store_true", help="download missing immutable inputs")
    parser.add_argument("--growth-cache", type=Path, default=Path(ROOT) / "tools/growthcache", help="pinned growth-source cache for full species yields")
    parser.add_argument("--extra-move", action="append", default=[])
    args = parser.parse_args()
    MOVES_INPUT = str(args.input_root / "Source/battle/moves.lua")
    POKEMON_INPUT = str(args.input_root / "Source/data/pokemon.lua")
    MOVES_LUA = str(args.output_root / "Source/battle/moves.lua")
    POKEMON_LUA = str(args.output_root / "Source/data/pokemon.lua")
    EXTRA_MOVE_KEYS = args.extra_move
    if args.moves_only:
        sys.path.insert(0, ROOT)
        from tools.verify_moves.fetch_pokeapi import PinnedSources
        source = PinnedSources(args.pinned_cache, args.fetch)
        data = {"moves": source.load("moves_pre_sv.csv"),
                "move_changelog": source.load("move_changelog_pre_sv.csv")}
        for name in ("move_meta", "move_meta_stat_changes", "types"):
            data[name] = source.load(name + ".csv")
        generate_moves(data, preserve_existing=True)
    else:
        if args.pinned_cache:
            parser.error("--pinned-cache requires --moves-only; species Showdown sources are not yet pinned")
        gen5_yields = load_gen5_yields(args.growth_cache, args.fetch)
        data = load_all()
        generate_moves(data)
        generate_species(data, gen5_yields)


if __name__ == "__main__":
    main()
