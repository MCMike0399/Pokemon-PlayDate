#!/usr/bin/env python3
"""Thirty Pallet-Center round trips must not keep growing the Lua heap.

Each completed harness command kept its result table until finish().
That table survived releaseDepartingWorld and two full collections, so
every return to the Viridian Center added 2.125 KiB. Return 5 through
return 30 is 25 of those steps, about 53 KiB, until
tools/notes/lane-e-revisit-leak.patch spills the results and drops
departed zone profiles. The bound is 8 KiB and is not loosened.
zoneProfiles is reported at each release and stays at most 2.
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

# The switchzone helpers live here so this test does not import the
# departed-tile registry note. That note is not on this tree.
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

PHASE = "map.ViridianPokecenter.definition.begin"
RETURN_FROM = 5
RETURN_TO = 30
GROWTH_KIB = 8
PROFILE_CAP = 2


def commands():
    steps = [COMMANDS[0], "encounters off", "snapshot"]
    for _ in range(RETURN_TO):
        steps.append("switchzone kanto_pallet_town")
        steps.append("switchzone kanto_viridian_center")
    steps.extend(["record center-return 8", "snapshot"])
    return steps


class RevisitLeakTest(unittest.TestCase):
    def test_thirty_pallet_center_trips_grow_under_eight_kib(self):
        pool = POOL_INI.read_text(encoding="utf-8")
        self.assertIn("MallocPoolSize=16645684", pool)
        try:
            sdk = sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))
        except ProtocolError as error:
            raise RuntimeError(str(error)) from error
        output = Path(tempfile.mkdtemp(prefix="revisit-leak-"))
        shutil.rmtree(output)
        self.addCleanup(shutil.rmtree, output, True)
        scenario_dir = Path(tempfile.mkdtemp(prefix="revisit-leak-scenario-"))
        self.addCleanup(shutil.rmtree, scenario_dir, True)
        (scenario_dir / "scenario.json").write_text(json.dumps({"commands": commands()}))
        saved = _inject(ROOT)
        try:
            proc = subprocess.run(
                [
                    sys.executable, "tools/harness/run.py",
                    "--sdk", str(sdk),
                    "--output", str(output),
                    "--scenario", str(scenario_dir / "scenario.json"),
                    "--ready-timeout", "180",
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
        profiles = [
            int(row["phase"].rsplit(" ", 1)[1])
            for row in rows
            if row["phase"].startswith("registry.profiles ")
        ]
        detail = json.dumps({
            "ok": outcome.get("ok"),
            "error": outcome.get("error"),
            "begins": [round(value, 3) for value in begins],
            "profiles_max": max(profiles) if profiles else None,
            "returncode": proc.returncode,
        })
        self.assertTrue(outcome.get("ok"), detail)
        self.assertGreaterEqual(len(begins), RETURN_TO + 1, detail)
        growth = begins[RETURN_TO] - begins[RETURN_FROM]
        self.assertLessEqual(
            growth, GROWTH_KIB,
            f"Center definition grew {growth:.3f} KiB from return {RETURN_FROM} "
            f"({begins[RETURN_FROM]:.3f}) to return {RETURN_TO} "
            f"({begins[RETURN_TO]:.3f}) ({detail})",
        )
        self.assertGreaterEqual(len(profiles), 2, detail)
        self.assertLessEqual(max(profiles), PROFILE_CAP, detail)


if __name__ == "__main__":
    unittest.main()
