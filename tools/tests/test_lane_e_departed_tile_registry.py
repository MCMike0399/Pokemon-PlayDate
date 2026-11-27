#!/usr/bin/env python3
"""A walk out and back must leave the Lua heap near where it started.

switchZone from the Viridian Center through Mt. Moon 1F, Route 4 and
Cerulean, then back, collects before the Center is decoded again. The
return visit's definition.begin is still about 514 KiB above the first
visit. A second lap of the same maps adds about 5 KiB, so the residue is
paid once per map and kept. Rebuilding the Center succeeds. The bound is
96 KiB. This fails on the current tree. The measurement and the release
that was not enough are in tools/notes/lane-e-departed-tile-registry.md.
MallocPoolSize stays 16645684.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tools.harness.run import ProtocolError, sdk_path

PHASE = "map.ViridianPokecenter.definition.begin"
BOUND_KIB = 96
POOL_INI = Path.home() / ".config/Playdate Simulator/Playdate Simulator.ini"
HARNESS_ANCHOR = (
    '    elseif op == "warp" then valid = integer(args[1], 0, 10000) '
    'and integer(args[2], 0, 10000) and #args == 2\n'
)
HARNESS_INSERT = (
    HARNESS_ANCHOR
    + '    elseif op == "switchzone" then valid = #args == 1 '
    'and WorldDeltas.describeZone(args[1]) ~= nil\n'
)
AUTOPILOT_ANCHOR = """            results[#results + 1] = "pokemon none"
        end
        return true
    end
"""
AUTOPILOT_INSERT = """            results[#results + 1] = "pokemon none"
        end
        return true

    elseif name == "switchzone" then
        player = nil
        local key = cmd[2]
        assert(game.machine:is("overworld"), "switchzone requires overworld")
        assert(WorldDeltas.describeZone(key), "unknown zone")
        switchZone(key)
        game.machine:change("overworld", { respawn = true })
        player = game.player
        results[#results + 1] = "switchzone " .. tostring(currentZone and currentZone.stableID)
        return true
    end
"""
COMMANDS = [
    {
        "op": "fixture",
        "options": {
            "intro": "skip",
            "opening": False,
            "seed": 1,
            "zone": "kanto_viridian_center",
            "entry": {"x": 7, "y": 4, "facing": "right"},
            "player_pokemon": {"species": "squirtle", "level": 5},
        },
    },
    "encounters off",
    "snapshot",
    "switchzone kanto_mt_moon_1f",
    "switchzone kanto_route_4",
    "switchzone kanto_cerulean_city",
    "switchzone kanto_viridian_center",
    "record center-return 8",
    "snapshot",
]


def parse_trace(text):
    rows = []
    for line in text.splitlines():
        parts = line.split("\t")
        if not parts or not parts[0].isdigit() or len(parts) < 7:
            continue
        rows.append({"phase": parts[1], "heap_kib": float(parts[5])})
    return rows


def _restore(saved):
    for path, text in saved.items():
        path.write_text(text)


def _inject(root):
    edits = (
        (root / "Source/dev/harness.lua", HARNESS_ANCHOR, HARNESS_INSERT),
        (root / "Source/dev/autopilot.lua", AUTOPILOT_ANCHOR, AUTOPILOT_INSERT),
    )
    saved = {}
    try:
        for path, old, new in edits:
            text = path.read_text()
            if text.count(old) != 1:
                raise RuntimeError(f"switchzone anchor missing in {path}")
            saved[path] = text
            path.write_text(text.replace(old, new, 1))
    except Exception:
        _restore(saved)
        raise
    return saved


class DepartedTileRegistryTest(unittest.TestCase):
    def test_return_to_the_center_keeps_the_heap_near_the_first_visit(self):
        pool = POOL_INI.read_text(encoding="utf-8")
        self.assertIn("MallocPoolSize=16645684", pool)
        try:
            sdk = sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))
        except ProtocolError as error:
            raise RuntimeError(str(error)) from error
        output = Path(tempfile.mkdtemp(prefix="departed-tiles-"))
        shutil.rmtree(output)
        self.addCleanup(shutil.rmtree, output, True)
        scenario_dir = Path(tempfile.mkdtemp(prefix="departed-tiles-scenario-"))
        self.addCleanup(shutil.rmtree, scenario_dir, True)
        (scenario_dir / "scenario.json").write_text(json.dumps({"commands": COMMANDS}))
        saved = _inject(ROOT)
        try:
            proc = subprocess.run(
                [
                    sys.executable, "tools/harness/run.py",
                    "--sdk", str(sdk),
                    "--output", str(output),
                    "--scenario", str(scenario_dir / "scenario.json"),
                    "--ready-timeout", "120",
                    "--timeout", "300",
                    "--max-frames", "18000",
                ],
                cwd=ROOT,
                check=False,
                text=True,
                capture_output=True,
            )
        finally:
            _restore(saved)
        outcome_path = output / "outcome.json"
        outcome = json.loads(outcome_path.read_text()) if outcome_path.is_file() else {
            "ok": False, "error": proc.stderr or proc.stdout or "no outcome",
        }
        trace_path = output / "runtime-data" / "boot-trace.tsv"
        rows = parse_trace(trace_path.read_text()) if trace_path.is_file() else []
        begins = [row["heap_kib"] for row in rows if row["phase"] == PHASE]
        releases = [
            f"{row['phase']}={row['heap_kib']}"
            for row in rows
            if row["phase"].endswith("definition.begin") or row["phase"].startswith("probe.")
        ]
        detail = json.dumps({
            "ok": outcome.get("ok"),
            "error": outcome.get("error"),
            "begins": begins,
            "releases": releases,
            "returncode": proc.returncode,
        })
        self.assertTrue(outcome.get("ok"), detail)
        self.assertGreaterEqual(len(begins), 2, detail)
        growth = begins[-1] - begins[0]
        self.assertLessEqual(
            growth, BOUND_KIB,
            f"Viridian Center definition grew from {begins[0]:.1f} KiB to {begins[-1]:.1f} KiB "
            f"after Mt. Moon, Route 4 and Cerulean ({detail})",
        )


if __name__ == "__main__":
    unittest.main()
