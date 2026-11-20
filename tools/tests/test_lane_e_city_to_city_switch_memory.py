#!/usr/bin/env python3
"""A live city must switch into the next city inside the boot heap budget.

switchZone used to decode the destination while the previous city's view,
actors, definition and tile-grid cache were still in the 16 MiB pool. A
fresh fixture fits. A live Viridian world does not: the Simulator raises
pd_readcompressed inflate failed, out of memory. This drives that path.
The product fix is tools/notes/lane-e-switchzone-release-before-build.patch.
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
from tools.measure_boot_budget import LUA_PEAK_BUDGET_KIB

PATCH = ROOT / "tools/notes/lane-e-switchzone-release-before-build.patch"
DESTINATIONS = (
    ("kanto_cerulean_city", "map.CeruleanCity.zone.end"),
    ("kanto_celadon_city", "map.CeladonCity.zone.end"),
    ("kanto_saffron_city", "map.SaffronCity.zone.end"),
    ("kanto_lavender_town", "map.LavenderTown.zone.end"),
    ("kanto_fuchsia_city", "map.FuchsiaCity.zone.end"),
)
CAVE_PHASE = "map.CeruleanCave1F.zone.end"
VIRIDIAN = {
    "op": "fixture",
    "options": {
        "intro": "skip",
        "opening": False,
        "seed": 1,
        "zone": "kanto_viridian_city",
        "entry": {"x": 20, "y": 35, "facing": "up"},
    },
}
HARNESS_ANCHOR = (
    '    elseif op == "warp" then valid = integer(args[1], 0, 10000) '
    'and integer(args[2], 0, 10000) and #args == 2\n'
)
HARNESS_INSERT = (
    HARNESS_ANCHOR
    + '    elseif op == "switchzone" then valid = #args == 1 '
    'and WorldDeltas.describeZone(args[1]) ~= nil\n'
)
AUTOPILOT_ANCHOR = """        results[#results + 1] = "pokemon none"
        end
        return true
    end
"""
AUTOPILOT_INSERT = """        results[#results + 1] = "pokemon none"
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


def parse_trace(text):
    rows = []
    for line in text.splitlines():
        parts = line.split("\t")
        if not parts or not parts[0].isdigit() or len(parts) < 7:
            continue
        rows.append({
            "phase": parts[1],
            "heap_kib": float(parts[5]),
            "peak_kib": float(parts[6]),
        })
    return rows


def zone_end_peaks(rows, phases):
    found = {}
    for row in rows:
        if row["phase"] in phases:
            found[row["phase"]] = row
    return found


def _restore(saved):
    for path, text in saved.items():
        path.write_text(text)


def _inject_switch_command(root):
    """Stage a dev-only switchzone command. Product Source is restored after the run."""
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


def run_commands(root, output, commands, inject=False):
    sdk = sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))
    output = Path(output)
    if output.exists():
        shutil.rmtree(output)
    scenario_dir = Path(tempfile.mkdtemp(prefix="lane-k-switch-scenario-"))
    scenario = scenario_dir / "scenario.json"
    scenario.write_text(json.dumps({"commands": commands}))
    saved = _inject_switch_command(root) if inject else {}
    try:
        proc = subprocess.run(
            [
                sys.executable, "tools/harness/run.py",
                "--sdk", str(sdk),
                "--output", str(output),
                "--scenario", str(scenario),
                "--ready-timeout", "120",
                "--timeout", "180",
                "--max-frames", "18000",
            ],
            cwd=root,
            check=False,
            text=True,
            capture_output=True,
        )
    finally:
        _restore(saved)
        shutil.rmtree(scenario_dir, ignore_errors=True)
    outcome_path = output / "outcome.json"
    outcome = json.loads(outcome_path.read_text()) if outcome_path.is_file() else {
        "ok": False, "error": proc.stderr or proc.stdout or "no outcome",
    }
    trace_path = output / "runtime-data" / "boot-trace.tsv"
    rows = parse_trace(trace_path.read_text()) if trace_path.is_file() else []
    return proc, outcome, rows


def city_commands():
    commands = [VIRIDIAN]
    for key, _phase in DESTINATIONS:
        commands.append(f"switchzone {key}")
    commands.append("snapshot")
    return commands


def cave_commands():
    # H session 181de250: a fresh Cerulean switch, then real steps onto
    # pokered:CERULEAN_CITY:warps:7 at (4, 11). The guard stands on (4, 12)
    # until TOGGLE_CERULEAN_CAVE_GUY.
    return [
        {
            "op": "fixture",
            "options": {
                "intro": "skip",
                "opening": False,
                "seed": 11,
                "zone": "kanto_cerulean_city",
                "entry": {"x": 4, "y": 13, "facing": "up"},
                "quest_flags": {
                    "BADGE_SOUL": True,
                    "EVENT_BEAT_CERULEAN_RIVAL": True,
                    "EVENT_GOT_SS_TICKET": True,
                    "TOGGLE_CERULEAN_CAVE_GUY": True,
                    "TOGGLE_CERULEAN_ROCKET": True,
                },
                "player_pokemon": {
                    "species": "blastoise",
                    "level": 65,
                    "nature_id": 0,
                    "ability_slot": "first",
                    "held_item": "none",
                    "moves": ["surf", "hydroPump", "skullBash", "rainDance"],
                },
            },
        },
        "wait 20",
        "encounters off",
        "encounters off",
        "move up",
        "move up",
        "move up",
        {"op": "await", "path": "zone", "equals": "kanto_cerulean_cave_1f", "frames": 300},
    ]


class CityToCitySwitchMemoryTest(unittest.TestCase):
    def test_patch_is_a_diff_and_does_not_raise_the_pool(self):
        text = PATCH.read_text()
        self.assertIn("diff --git a/Source/world/zone.lua", text)
        self.assertIn("diff --git a/Source/world/overworld.lua", text)
        self.assertIn("releaseDepartingWorld", text)
        self.assertIn("function setupOverworld()", text)
        self.assertNotIn("MallocPoolSize", text)
        self.assertNotIn("DOOR_FADE_FRAMES", text)
        self.assertNotIn("xfail", text.lower())
        self.assertNotIn("skip", text.lower())

    def test_live_viridian_switch_stays_under_budget(self):
        try:
            sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))
        except ProtocolError as error:
            raise RuntimeError(str(error)) from error
        output = Path(os.environ.get(
            "LANE_K_SWITCH_OUTPUT",
            tempfile.mkdtemp(prefix="lane-k-switch-"),
        ))
        proc, outcome, rows = run_commands(ROOT, output, city_commands(), inject=True)
        peaks = zone_end_peaks(rows, {phase for _key, phase in DESTINATIONS})
        missing = [phase for _key, phase in DESTINATIONS if phase not in peaks]
        detail = json.dumps({
            "ok": outcome.get("ok"),
            "error": outcome.get("error"),
            "peaks": {phase: row["peak_kib"] for phase, row in peaks.items()},
            "heaps": {phase: row["heap_kib"] for phase, row in peaks.items()},
            "missing": missing,
            "returncode": proc.returncode,
        }, sort_keys=True)
        self.assertTrue(outcome.get("ok"), detail)
        self.assertEqual(missing, [], detail)
        for _key, phase in DESTINATIONS:
            self.assertLessEqual(peaks[phase]["peak_kib"], LUA_PEAK_BUDGET_KIB, detail)

    def test_cerulean_cave_warp_stays_under_budget(self):
        try:
            sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))
        except ProtocolError as error:
            raise RuntimeError(str(error)) from error
        output = Path(os.environ.get(
            "LANE_K_CAVE_OUTPUT",
            tempfile.mkdtemp(prefix="lane-k-cave-"),
        ))
        proc, outcome, rows = run_commands(ROOT, output, cave_commands())
        peaks = zone_end_peaks(rows, {CAVE_PHASE})
        detail = json.dumps({
            "ok": outcome.get("ok"),
            "error": outcome.get("error"),
            "peaks": {phase: row["peak_kib"] for phase, row in peaks.items()},
            "heaps": {phase: row["heap_kib"] for phase, row in peaks.items()},
            "returncode": proc.returncode,
        }, sort_keys=True)
        self.assertTrue(outcome.get("ok"), detail)
        self.assertIn(CAVE_PHASE, peaks, detail)
        self.assertLessEqual(peaks[CAVE_PHASE]["peak_kib"], LUA_PEAK_BUDGET_KIB, detail)


if __name__ == "__main__":
    unittest.main()
