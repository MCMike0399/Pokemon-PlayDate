#!/usr/bin/env python3
"""Pokered level-up moves and the trainer special-move pass.

pret/pokered af519899. Level-1 moves come from each base-stats file.
evos_moves.asm supplies later levels. WriteMonMoves keeps the last four.
LoneMoves overwrites move slot 3 of one gym-leader party member.
TeamMoves overwrites move slot 3 of an Elite Four party's fifth member.
The champion rival is the same ReadTrainer branch. Output is generated.
"""

import argparse
import re
from pathlib import Path

REVISION = "af519899719f0754965776faac0e836a3b906e6d"
LEADERS = ("BROCK", "MISTY", "LT_SURGE", "ERIKA", "KOGA", "SABRINA", "BLAINE", "GIOVANNI")
SPECIES_SYMBOL = {
    "NIDORAN_F": "nidoranF",
    "NIDORAN_M": "nidoranM",
    "MR_MIME": "mr",
    "FARFETCHD": "farfetchd",
}
LABEL_SPECIES = {
    "NidoranF": "nidoranF",
    "NidoranM": "nidoranM",
    "MrMime": "mr",
    "Farfetchd": "farfetchd",
}
MOVE_ALIAS = {
    "PSYCHIC_M": "psychic",
    "HI_JUMP_KICK": "highJumpKick",
}


def read(reference, relative):
    return (Path(reference) / relative).read_text(encoding="utf-8")


def move_keys(moves_lua):
    keys = re.findall(r"^\s{4}([A-Za-z][A-Za-z0-9]*) = function\(\)", moves_lua, re.M)
    return {key.lower(): key for key in keys}


def move_ids(constants):
    names = re.findall(r"^\s*const\s+([A-Z0-9_]+)", constants, re.M)
    struggle = names.index("STRUGGLE")
    return {name: index for index, name in enumerate(names[: struggle + 1])}


def move_key(symbol, keys, ids):
    if symbol not in ids:
        raise ValueError("move is past Struggle or unknown: " + symbol)
    if symbol in MOVE_ALIAS:
        return MOVE_ALIAS[symbol]
    parts = symbol.lower().split("_")
    camel = parts[0] + "".join(part.capitalize() for part in parts[1:])
    found = keys.get(camel.lower())
    if not found:
        raise ValueError("no battle move for " + symbol)
    return found


def species_from_symbol(symbol):
    if symbol in SPECIES_SYMBOL:
        return SPECIES_SYMBOL[symbol]
    return symbol.lower()


def species_from_label(label):
    if label in LABEL_SPECIES:
        return LABEL_SPECIES[label]
    return label[:1].lower() + label[1:]


def level1_moves(reference, keys, ids):
    found = {}
    for path in sorted((Path(reference) / "data/pokemon/base_stats").glob("*.asm")):
        text = path.read_text(encoding="utf-8")
        row = re.search(
            r"db\s+([A-Z0-9_]+),\s+([A-Z0-9_]+),\s+([A-Z0-9_]+),\s+([A-Z0-9_]+)\s*; level 1 learnset",
            text)
        if not row:
            raise ValueError("missing level-1 learnset: " + path.name)
        species = {
            "nidoranf": "nidoranF",
            "nidoranm": "nidoranM",
            "mrmime": "mr",
        }.get(path.stem, path.stem)
        moves = []
        for symbol in row.groups():
            if symbol != "NO_MOVE":
                moves.append(move_key(symbol, keys, ids))
        if not moves:
            raise ValueError("empty level-1 learnset: " + species)
        found[species] = moves
    if len(found) != 151:
        raise ValueError("expected 151 level-1 learnsets, got %d" % len(found))
    return found


def learnsets(reference, keys, ids, species):
    text = read(reference, "data/pokemon/evos_moves.asm")
    found = {name: [] for name in species}
    for label, body in re.findall(r"^([A-Za-z0-9]+)EvosMoves:\n(.*?)(?=^[A-Za-z0-9]+EvosMoves:|\Z)", text, re.M | re.S):
        name = species_from_label(label)
        if name not in found:
            continue
        section = body.split("; Learnset", 1)[1]
        rows = []
        for level, symbol in re.findall(r"^\s*db\s+(\d+),\s+([A-Z0-9_]+)", section, re.M):
            rows.append((int(level), move_key(symbol, keys, ids), ids[symbol]))
        found[name] = rows
    return found


def gym_leaders(reference):
    paired = {}
    objects = Path(reference) / "data/maps/objects"
    for path in sorted(objects.glob("*.asm")):
        text = path.read_text(encoding="utf-8")
        present = [leader for leader in LEADERS if re.search(r"\bOPP_%s\b" % leader, text)]
        script_path = Path(reference) / "scripts" / (path.stem + ".asm")
        if not script_path.exists():
            continue
        script = script_path.read_text(encoding="utf-8")
        number = re.search(r"ld a, \$([0-9A-Fa-f]+)\s*\n\tld \[wGymLeaderNo\], a", script)
        if not number:
            continue
        if len(present) != 1:
            raise ValueError("gym leader pair is not unique: " + path.name)
        paired[present[0]] = int(number.group(1), 16)
    if sorted(paired) != sorted(LEADERS):
        raise ValueError("gym leader numbers drifted: %r" % paired)
    return paired


def lone_moves(reference, keys, ids, leaders):
    text = read(reference, "data/trainers/special_moves.asm")
    block = text.split("LoneMoves:", 1)[1].split("TeamMoves:", 1)[0]
    rows = re.findall(r"^\s*db\s+(\d+),\s+([A-Z0-9_]+)", block, re.M)
    if len(rows) != len(LEADERS):
        raise ValueError("LoneMoves count drifted")
    by_number = {}
    for index, (skip, symbol) in enumerate(rows, start=1):
        by_number[index] = {"skip": int(skip), "move": move_key(symbol, keys, ids)}
    if sorted(by_number) != sorted(leaders.values()):
        raise ValueError("LoneMoves indexes do not match gym leader numbers")
    return by_number


def team_moves(reference, keys, ids):
    text = read(reference, "data/trainers/special_moves.asm")
    block = text.split("TeamMoves:", 1)[1]
    rows = re.findall(r"^\s*db\s+([A-Z0-9_]+),\s+([A-Z0-9_]+)", block, re.M)
    found = {}
    for trainer, symbol in rows:
        if trainer == "1":
            continue
        found["OPP_" + trainer] = move_key(symbol, keys, ids)
    expected = {"OPP_LORELEI", "OPP_BRUNO", "OPP_AGATHA", "OPP_LANCE"}
    if set(found) != expected:
        raise ValueError("TeamMoves drifted: %r" % found)
    return found


def champion(reference, keys, ids):
    text = read(reference, "engine/battle/read_trainer_party.asm")
    block = text.split("\n.ChampionRival", 1)[1].split("\n.FinishUp", 1)[0]
    lead = re.search(r"ld a, ([A-Z0-9_]+)\s*\n\tld \[wEnemyMon1Moves \+ 2\], a", block)
    starter3 = re.search(r"cp STARTER3\s*\n\tld b, ([A-Z0-9_]+)", block)
    starter1 = re.search(r"cp STARTER1\s*\n\tld b, ([A-Z0-9_]+)", block)
    starter2 = re.search(r"ld b, ([A-Z0-9_]+) ; must be squirtle", block)
    if not (lead and starter3 and starter1 and starter2):
        raise ValueError("champion rival special moves drifted")
    return {
        "lead": move_key(lead.group(1), keys, ids),
        "starter": {
            "bulbasaur": move_key(starter3.group(1), keys, ids),
            "charmander": move_key(starter1.group(1), keys, ids),
            "squirtle": move_key(starter2.group(1), keys, ids),
        },
    }


def parties(reference):
    text = read(reference, "data/trainers/parties.asm")
    found = {}
    for label, body in re.findall(r"^([A-Za-z0-9]+Data):\n(.*?)(?=^[A-Za-z0-9]+Data:|\Z)", text, re.M | re.S):
        roster = []
        for raw in body.splitlines():
            line = raw.split(";", 1)[0].strip()
            if not line.startswith("db"):
                continue
            parts = [part.strip() for part in line[2:].split(",")]
            parts = [part for part in parts if part and part != "0"]
            if not parts:
                continue
            if parts[0] == "$FF":
                team = []
                for cursor in range(1, len(parts), 2):
                    team.append({"level": int(parts[cursor]), "species": species_from_symbol(parts[cursor + 1])})
                roster.append(team)
            else:
                level = int(parts[0])
                roster.append([{"level": level, "species": species_from_symbol(name)} for name in parts[1:]])
        found[label[:-4] if label.endswith("Data") else label] = roster
    return found


def load(reference, moves_lua):
    reference = Path(reference)
    keys = move_keys(Path(moves_lua).read_text(encoding="utf-8"))
    ids = move_ids(read(reference, "constants/move_constants.asm"))
    level1 = level1_moves(reference, keys, ids)
    learned = learnsets(reference, keys, ids, level1)
    leaders = gym_leaders(reference)
    return {
        "revision": REVISION,
        "level1": level1,
        "learn": learned,
        "gymLeaderNo": {"OPP_" + name: number for name, number in leaders.items()},
        "lone": lone_moves(reference, keys, ids, leaders),
        "team": team_moves(reference, keys, ids),
        "champion": champion(reference, keys, ids),
        "parties": parties(reference),
    }


def moves_at_level(data, species, level):
    moves = list(data["level1"][species])
    for learned_level, key, _move_id in data["learn"][species]:
        if learned_level > level:
            break
        if key in moves:
            continue
        if len(moves) == 4:
            del moves[0]
        moves.append(key)
    return moves


def write_slot(moves, slot, key):
    slots = list(moves) + [None, None, None, None]
    slots[slot - 1] = key
    return [item for item in slots[:4] if item]


def trainer_moves(data, species, level, class_name=None, index=None, starter=None):
    moves = moves_at_level(data, species, level)
    if not class_name or index is None:
        return moves
    gym = data["gymLeaderNo"].get(class_name)
    if gym:
        lone = data["lone"].get(gym)
        if lone and index == lone["skip"] + 1:
            return write_slot(moves, 3, lone["move"])
        return moves
    team = data["team"].get(class_name)
    if team and index == 5:
        return write_slot(moves, 3, team)
    if class_name == "OPP_RIVAL3":
        if index == 1:
            return write_slot(moves, 3, data["champion"]["lead"])
        if index == 6:
            move = data["champion"]["starter"].get(starter)
            if move:
                return write_slot(moves, 3, move)
    return moves


def entries_between(data, species, minimum, maximum):
    return [
        {"move": key, "level": level, "id": move_id}
        for level, key, move_id in data["learn"][species]
        if minimum <= level <= maximum
    ]


def lua_string(value):
    return '"' + value + '"'


def render(data):
    lines = [
        "-- Generated by tools/generate_pokered_learnsets.py",
        "-- pret/pokered " + data["revision"] + ". Do not hand-edit.",
        "PokeredLearnsets = {",
        "    revision = " + lua_string(data["revision"]) + ",",
        "    level1 = {",
    ]
    for species in sorted(data["level1"]):
        moves = ", ".join(lua_string(key) for key in data["level1"][species])
        lines.append("        " + species + " = {" + moves + "},")
    lines.append("    },")
    lines.append("    learn = {")
    for species in sorted(data["learn"]):
        rows = ", ".join(
            "{%d,%s,%d}" % (level, lua_string(key), move_id)
            for level, key, move_id in data["learn"][species]
        )
        lines.append("        " + species + " = {" + rows + "},")
    lines.append("    },")
    lines.append("    gymLeaderNo = {")
    for class_name in sorted(data["gymLeaderNo"]):
        lines.append("        %s = %d," % (class_name, data["gymLeaderNo"][class_name]))
    lines.append("    },")
    lines.append("    lone = {")
    for number in sorted(data["lone"]):
        row = data["lone"][number]
        lines.append("        [%d] = {skip = %d, move = %s}," % (number, row["skip"], lua_string(row["move"])))
    lines.append("    },")
    lines.append("    team = {")
    for class_name in sorted(data["team"]):
        lines.append("        %s = %s," % (class_name, lua_string(data["team"][class_name])))
    lines.append("    },")
    lines.append("    champion = {")
    lines.append("        lead = " + lua_string(data["champion"]["lead"]) + ",")
    lines.append("        starter = {")
    for species in ("bulbasaur", "charmander", "squirtle"):
        lines.append("            %s = %s," % (species, lua_string(data["champion"]["starter"][species])))
    lines += [
        "        },",
        "    },",
        "}",
        "",
        "function PokeredLearnsets.movesAtLevel(species, level)",
        "    local base = PokeredLearnsets.level1[species]",
        "    assert(base, \"missing pokered level-1 moves: \" .. tostring(species))",
        "    local moves = {}",
        "    for _, key in ipairs(base) do moves[#moves + 1] = key end",
        "    for _, entry in ipairs(PokeredLearnsets.learn[species] or {}) do",
        "        if entry[1] > level then break end",
        "        local known = false",
        "        for _, have in ipairs(moves) do",
        "            if have == entry[2] then known = true end",
        "        end",
        "        if not known then",
        "            if #moves == 4 then table.remove(moves, 1) end",
        "            moves[#moves + 1] = entry[2]",
        "        end",
        "    end",
        "    assert(#moves > 0, \"pokered moveset is empty: \" .. tostring(species))",
        "    return moves",
        "end",
        "",
        "function PokeredLearnsets.entriesBetween(species, minimum, maximum)",
        "    assert(PokeredLearnsets.level1[species], \"missing pokered level-1 moves: \" .. tostring(species))",
        "    local entries = {}",
        "    for _, entry in ipairs(PokeredLearnsets.learn[species] or {}) do",
        "        if entry[1] >= minimum and entry[1] <= maximum then",
        "            entries[#entries + 1] = {move = entry[2], level = entry[1], order = nil, id = entry[3]}",
        "        end",
        "    end",
        "    return entries",
        "end",
        "",
        "local function writeThird(moves, key)",
        "    local slots = {moves[1], moves[2], moves[3], moves[4]}",
        "    slots[3] = key",
        "    local compact = {}",
        "    for index = 1, 4 do",
        "        if slots[index] then compact[#compact + 1] = slots[index] end",
        "    end",
        "    return compact",
        "end",
        "",
        "function PokeredLearnsets.trainerMoves(species, level, class, index, starter)",
        "    local moves = PokeredLearnsets.movesAtLevel(species, level)",
        "    if type(class) ~= \"string\" or type(index) ~= \"number\" then return moves end",
        "    local gym = PokeredLearnsets.gymLeaderNo[class]",
        "    if gym then",
        "        local lone = PokeredLearnsets.lone[gym]",
        "        if lone and index == lone.skip + 1 then return writeThird(moves, lone.move) end",
        "        return moves",
        "    end",
        "    local team = PokeredLearnsets.team[class]",
        "    if team and index == 5 then return writeThird(moves, team) end",
        "    if class == \"OPP_RIVAL3\" then",
        "        if index == 1 then return writeThird(moves, PokeredLearnsets.champion.lead) end",
        "        local starterMove = index == 6 and PokeredLearnsets.champion.starter[starter] or nil",
        "        if starterMove then return writeThird(moves, starterMove) end",
        "    end",
        "    return moves",
        "end",
        "",
    ]
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--moves", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    generated = render(load(args.reference, args.moves))
    if args.check:
        current = args.output.read_text(encoding="utf-8")
        if current != generated:
            raise SystemExit("generated pokered learnsets drifted")
        return 0
    project = Path(__file__).resolve().parents[1]
    if args.output.resolve().is_relative_to(project / "Source"):
        raise SystemExit("write the candidate outside Source; the lane-e patch carries it")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(generated, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
