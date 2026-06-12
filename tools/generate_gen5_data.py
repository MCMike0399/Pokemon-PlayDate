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
                       pokemon (base_experience)
  Pokémon Showdown   — pokedex.ts + mods/gen{8,7,6,5}/pokedex.ts applied in
                       order, yielding Gen V base stats and types

Run: python3 tools/generate_gen5_data.py
"""

import csv
import io
import os
import re
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, "tools", "gen5cache")
MOVES_LUA = os.path.join(ROOT, "Source", "battle", "moves.lua")
POKEMON_LUA = os.path.join(ROOT, "Source", "data", "pokemon.lua")

B2W2_VERSION_GROUP = 14

POKEAPI_CSV = "https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv/"
SHOWDOWN = "https://raw.githubusercontent.com/smogon/pokemon-showdown/master/data/"

CSV_FILES = ["moves", "move_changelog", "move_meta", "move_meta_stat_changes", "pokemon", "types"]
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


def generate_moves(data):
    with open(MOVES_LUA, encoding="utf-8") as f:
        current = f.read()
    keys = re.findall(r"^\s*(\w+) = Move[({]", current, re.MULTILINE)
    if not keys:
        sys.exit("no move keys found in moves.lua")

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

    out, missing = [], []
    for key in keys:
        row = moves_by_ident.get(MOVE_ALIASES.get(key) or camel_to_kebab(key))
        if not row:
            missing.append(key)
            continue
        move_id = row["id"]
        fields = resolve_b2w2(row, changelog.get(move_id, []))
        meta = meta_by_id.get(move_id)
        target_id = num(row["target_id"]) or 0
        category = class_names[num(row["damage_class_id"]) or 1]
        is_status = category == "status"

        effects = build_effects(key, meta, stat_changes_by_id.get(move_id, []),
                                target_id, is_status)

        display = camel_to_kebab(key).replace("-", " ").upper()
        parts = [
            f'name = "{display}"',
            f'type = "{type_names[str(fields["type_id"])]}"',
            f'category = "{category}"',
            f"power = {fields['power'] or 0}",
            f"accuracy = {fields['accuracy'] or 0}",
            f"pp = {PP_OVERRIDES.get(key, fields['pp'])}",
        ]
        if fields["priority"]:
            parts.append(f"priority = {fields['priority']}")
        if meta:
            drain = int(meta["drain"] or 0)
            if drain:
                parts.append(f"drain = {drain}")
            min_hits, max_hits = num(meta["min_hits"]), num(meta["max_hits"])
            if min_hits and max_hits and max_hits > 1:
                parts.append(f"minHits = {min_hits}, maxHits = {max_hits}")
        if effects:
            parts.append("effects = { " + ", ".join(effects) + " }")

        out.append(f"    {key} = Move{{ {', '.join(parts)} }},")

    header = '''-- Generated by tools/generate_gen5_data.py — do not edit move data by hand.
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
    self.priority = m.priority or 0
    self.drain = m.drain
    self.minHits = m.minHits
    self.maxHits = m.maxHits
    self.effects = m.effects
end

moveData = {
'''
    with open(MOVES_LUA, "w", encoding="utf-8") as f:
        f.write(header + "\n".join(out) + "\n}\n")

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


def generate_species(data):
    with open(POKEMON_LUA, encoding="utf-8") as f:
        src = f.read()

    dex = resolve_gen5_dex(data)
    base_exp = {r["identifier"]: int(r["base_experience"] or 0)
                for r in data["pokemon"] if r["is_default"] == "1"}

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
        exp = base_exp.get(SPECIES_CSV_ALIASES.get(key) or camel_to_kebab(key), 0)
        changed.append(key)
        return (f'{prefix}type = "{types[0]}", type2 = {type2},\n'
                f'        baseHP = {s["hp"]}, baseAtk = {s["atk"]}, baseDef = {s["def"]}, '
                f'baseSpA = {s["spa"]}, baseSpD = {s["spd"]}, baseSpe = {s["spe"]}, '
                f'baseExp = {exp},\n')

    out = block_re.sub(replace, src)
    with open(POKEMON_LUA, "w", encoding="utf-8") as f:
        f.write(out)

    print(f"pokemon.lua: {len(changed)} species updated")
    if missing:
        print(f"  NOT RESOLVED (left untouched!): {', '.join(missing)}")


def main():
    data = load_all()
    generate_moves(data)
    generate_species(data)


if __name__ == "__main__":
    main()
