#!/usr/bin/env python3
"""Qualify isolated Haze/Clear Smog bytes against pinned local references.

Static provenance and generation checks only; never executes Lua or a runtime.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
if __package__ in (None, ""):
    sys.path.insert(0, str(ROOT))
from tools import move_producer_contract as contract
from tools.generate_ability_move_metadata import FILES, REV, entries
from tools.verify_moves.fetch_pokeapi import PinnedSources
from tools import generate_gen5_data as generator

BASE = "10cb9572f8db3979fd7d3b1ddf517277008b4eeb"
KEYS = {"haze", "clearSmog"}


def qualify(cache):
    sources = {}
    oracle = {}
    for name, checksum in FILES.items():
        raw = (cache / name.replace("/", "_")).read_bytes()
        assert contract.digest(raw) == checksum, "Showdown source checksum: " + name
        sources[name] = checksum
        oracle[name] = entries(raw.decode())
    base = oracle["data/moves.ts"]
    assert 'pokemon.clearBoosts();' in base["haze"]
    assert 'target.clearBoosts();' in base["clearsmog"]
    assert 'bypasssub: 1' in base["haze"]
    assert 'bypasssub' not in base["clearsmog"]
    # Neither reset producer has any Gen8 -> Gen5 override.
    for name, rows in oracle.items():
        if name != "data/moves.ts":
            assert "haze" not in rows and "clearsmog" not in rows
    assert 'return this.HIT_SUBSTITUTE;' in oracle["data/mods/gen5/moves.ts"]["substitute"]
    pins = json.loads((ROOT / "tools/references/early-abilities-sources.json").read_text())["files"]
    for name, path in {
        "ps_sim_battle-actions.ts": "tools/references/traits/ps_sim_battle-actions.ts",
        "ps_sim_pokemon.ts": "tools/references/pickup/ps_sim_pokemon.ts",
    }.items():
        raw = (ROOT / path).read_bytes()
        assert contract.digest(raw) == pins[name]["sha256"], "mechanics source checksum: " + path
        sources[path] = pins[name]["sha256"]
    inputs = PinnedSources()
    data = {"moves": inputs.load("moves_pre_sv.csv"),
            "move_changelog": inputs.load("move_changelog_pre_sv.csv")}
    for name in ("move_meta", "move_meta_stat_changes", "types"):
        data[name] = inputs.load(name + ".csv")
    current = (ROOT / "Source/battle/moves.lua").read_text()
    old = subprocess.check_output(["git", "show", BASE + ":Source/battle/moves.lua"], cwd=ROOT, text=True)
    before, after = contract.read_rows(old), contract.read_rows(current)
    assert len(before) == len(after) == 425 and set(before) == set(after)
    assert {key for key in before if before[key] != after[key]} == KEYS
    for key in before:
        a, b = contract.fields(before[key]), contract.fields(after[key])
        assert {k: v for k, v in a.items() if k not in contract.PAYLOAD} == {k: v for k, v in b.items() if k not in contract.PAYLOAD}
    assert contract.producer_epoch(old) == 15
    assert contract.producer_epoch(current) == 16
    meta = contract.producer_metadata()
    for key in KEYS:
        assert contract.compatible(key, before[key], after[key], meta[key], epoch=15)
        assert not contract.compatible(key, before[key], after[key], meta[key], epoch=16)
        assert not contract.compatible(key, after[key], before[key], meta[key], epoch=16)
    lowered = contract.legacy_rows(after, 16)
    inverse = contract.digest(json.dumps(lowered, sort_keys=True, separators=(",", ":")).encode())
    assert len(lowered) == 424
    assert inverse == "ad40fd9b5592a4ffeb88dcfc9243cc56034b2f4ea5b2da6bb3f2a8c129da45ea"
    with tempfile.TemporaryDirectory(prefix="stage-reset-generation-") as temporary:
        target = Path(temporary) / "moves.lua"
        generator.MOVES_INPUT = str(ROOT / "Source/battle/moves.lua")
        generator.MOVES_LUA = str(target)
        generator.EXTRA_MOVE_KEYS = []
        generator.generate_moves(data, preserve_existing=True)
        assert target.read_bytes() == current.encode(), "move regeneration drift"
    return {"ok": True, "dependency": BASE, "oracle_revision": REV,
            "source_sha256": sources, "pokeapi_cache": str(inputs.cache),
            "pokeapi_manifest_sha256": contract.digest((ROOT / "tools/verify_moves/sources.json").read_bytes()),
            "pokeapi_inputs": {name: {"revision": inputs.manifest["files"][name].get("revision", inputs.manifest["revision"]),
                                      "sha256": inputs.manifest["files"][name]["sha256"]}
                               for name in ("moves_pre_sv.csv", "move_changelog_pre_sv.csv", "move_meta.csv", "move_meta_stat_changes.csv", "types.csv")},
            "move_rows": 425, "unchanged_rows": 423, "changed_rows": sorted(KEYS),
            "all_scalar_fields_unchanged": True, "legacy_rows": 424,
            "legacy_inverse_sha256": inverse, "exact_regeneration": True,
            "native_execution": False, "substitute_supported": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--showdown-cache", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    result = qualify(args.showdown_cache)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    with args.report.open("x") as output:
        output.write(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    main()
