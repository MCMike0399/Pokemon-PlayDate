#!/usr/bin/env python3
"""Check/extract immutable Blue NPC trade data; never execute game code."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

REVISION = "af519899719f0754965776faac0e836a3b906e6d"
# table index, wanted, received, nickname, map, object index, dialog set
EXPECTED = [
    (0, "NIDORINO", "NIDORINA", "TERRY", "Route11Gate2F", 1, "CASUAL"),
    (1, "ABRA", "MR_MIME", "MARCEL", "Route2TradeHouse", 2, "CASUAL"),
    (3, "PONYTA", "SEEL", "SAILOR", "CinnabarLabFossilRoom", 2, "CASUAL"),
    (4, "SPEAROW", "FARFETCHD", "DUX", "VermilionTradeHouse", 1, "HAPPY"),
    (5, "SLOWBRO", "LICKITUNG", "MARC", "Route18Gate2F", 1, "CASUAL"),
    (6, "POLIWHIRL", "JYNX", "LOLA", "CeruleanTradeHouse", 2, "EVOLUTION"),
    (7, "RAICHU", "ELECTRODE", "DORIS", "CinnabarLabTradeRoom", 2, "EVOLUTION"),
    (8, "VENONAT", "TANGELA", "CRINKLES", "CinnabarLabTradeRoom", 3, "HAPPY"),
    (9, "NIDORAN_M", "NIDORAN_F", "SPOT", "UndergroundPathRoute5", 1, "HAPPY"),
]


def check(source):
    def read(path):
        return subprocess.check_output(
            ["git", "-C", str(source), "show", f"{REVISION}:{path}"])

    table = read("data/events/trades.asm").decode()
    rows = re.findall(
        r'^\s*npctrade\s+(\w+),\s+(\w+),\s+TRADE_DIALOGSET_(\w+),\s+"([^"]+)"',
        table, re.M)
    assert len(rows) == 10, "changed table size"
    assert rows[2] == ("BUTTERFREE", "BEEDRILL", "HAPPY", "CHIKUCHIKU")
    uses = subprocess.check_output(
        ["git", "-C", str(source), "grep", "-n", "TRADE_FOR_", REVISION, "--", "scripts"]
    ).decode()
    used_names = re.findall(r"TRADE_FOR_(\w+)", uses)
    assert sorted(used_names) == sorted(row[3] for row in EXPECTED), "changed script usage"
    inventory = []
    for index, wanted, received, nickname, map_name, object_index, dialog in EXPECTED:
        assert rows[index] == (wanted, received, dialog, nickname), nickname
        script = read(f"scripts/{map_name}.asm").decode()
        objects = read(f"data/maps/objects/{map_name}.asm").decode()
        # Direct literal table selection, including TERRY's xor-a index zero.
        assert f"TRADE_FOR_{nickname}" in script, nickname
        entries = re.findall(r'^\s*object_event\s+(.+)$', objects, re.M)
        entry = entries[object_index - 1]
        text_id = entry.split(",")[-1].strip()
        pointers = dict(re.findall(r'dw_const\s+(\w+),\s+(\w+)', script))
        pointer = next(k for k, v in pointers.items() if v == text_id)
        body = script.split(pointer + ":", 1)[1].split("\n\n", 1)[0]
        assert f"TRADE_FOR_{nickname}" in body, (nickname, pointer)
        constant = re.search(r'def_warps_to\s+(\w+)', objects).group(1)
        inventory.append(dict(index=index, source_id=f"pokered:{constant}:objects:{object_index}",
                              wanted=wanted, received=received, nickname=nickname,
                              dialogue=dialog, pointer=pointer))
    # One unused row, nine distinct original trade bits and source objects.
    assert len({v["index"] for v in inventory}) == 9
    assert len({v["source_id"] for v in inventory}) == 9
    paths = ["data/events/trades.asm", "engine/events/in_game_trades.asm",
             "engine/pokemon/add_mon.asm", "engine/pokemon/evos_moves.asm",
             "engine/events/evolve_trade.asm", "data/text/text_7.asm",
             "constants/script_constants.asm"]
    return dict(revision=REVISION, inventory=inventory,
                sha256={p: hashlib.sha256(read(p)).hexdigest() for p in paths})


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path,
                        help="local pret/pokered Git checkout containing the pinned revision")
    print(json.dumps(check(parser.parse_args().source), indent=2))
