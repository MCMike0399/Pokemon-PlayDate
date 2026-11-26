#!/usr/bin/env python3
"""Party-menu Fly must land the destination inside the boot heap budget.

Fly used to decode the destination while the origin city, its view, and its
event chunks were still in the 16 MiB pool. From a live Viridian the
Simulator never publishes Fuchsia. This drives that path through the real
party menu. The product fix is
tools/notes/lane-e-fly-release-before-build.patch. The test fails on Source
that does not contain that fix.
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

PATCH = ROOT / "tools/notes/lane-e-fly-release-before-build.patch"
ORIGIN = "kanto_viridian_city"
DEST_ID = "pokered:FUCHSIA_CITY"
DEST_ZONE = "kanto_fuchsia_city"
DEST_PHASE = "map.FuchsiaCity.zone.end"
ARRIVAL = (19, 28)
HARNESS_ANCHOR = (
    '    elseif op == "warp" then valid = integer(args[1], 0, 10000) '
    'and integer(args[2], 0, 10000) and #args == 2\n'
)
HARNESS_INSERT = HARNESS_ANCHOR + (
    '    elseif op == "visitfly" then valid = #args == 1 '
    'and type(args[1]) == "string" and args[1]:match("^pokered:[A-Z0-9_]+$") ~= nil\n'
)
AUTOPILOT_ANCHOR = '''            results[#results + 1] = "pokemon none"
        end
        return true
    end
'''
AUTOPILOT_INSERT = '''            results[#results + 1] = "pokemon none"
        end
        return true

    elseif name == "visitfly" then
        local id = cmd[2]
        local travel = FieldTravel.enter(game.session:fieldTravelData(), id, "walking")
        local accepted, reason = game.session:captureTraversal({
            location = game.session:location(),
            world = WorldDeltas.export(),
            actors = game.npcManager.motion:snapshot(),
            fieldTravel = travel,
        })
        assert(accepted, reason)
        results[#results + 1] = "visitfly " .. id
        return true
    end
'''


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


def _restore(saved):
    for path, text in saved.items():
        path.write_text(text)


def _inject_visitfly(root):
    edits = (
        (root / "Source/dev/harness.lua", HARNESS_ANCHOR, HARNESS_INSERT),
        (root / "Source/dev/autopilot.lua", AUTOPILOT_ANCHOR, AUTOPILOT_INSERT),
    )
    saved = {}
    try:
        for path, old, new in edits:
            text = path.read_text()
            if text.count(old) != 1:
                raise RuntimeError(f"visitfly anchor missing in {path}")
            saved[path] = text
            path.write_text(text.replace(old, new, 1))
    except Exception:
        _restore(saved)
        raise
    return saved


def fly_commands():
    ox, oy = 23, 26
    commands = [
        {
            "op": "fixture",
            "options": {
                "intro": "skip",
                "opening": False,
                "seed": 11,
                "zone": ORIGIN,
                "entry": {"x": ox, "y": oy, "facing": "down"},
                "quest_flags": {"BADGE_THUNDER": True},
                "player_pokemon": {
                    "species": "blastoise",
                    "level": 65,
                    "nature_id": 0,
                    "ability_slot": "first",
                    "held_item": "none",
                    "moves": ["fly"],
                },
            },
        },
        "wait 4",
        "encounters off",
        f"visitfly {DEST_ID}",
        "wait 1",
        f"warp {ox} {oy}",
        "wait 1",
        "press b",
        "wait 2",
        "press a",
        "wait 1",
        "press a",
        "wait 1",
        "press a",
        "wait 1",
        "press down",
        "wait 1",
        "press a",
        "wait 1",
        "press down",
        "wait 1",
        "press a",
        "wait 1",
        "press a",
        "wait 30",
        {"op": "await", "path": "zone", "equals": DEST_ZONE, "frames": 40},
    ]
    return commands


def run_fly(root, output):
    sdk = sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))
    output = Path(output)
    if output.exists():
        shutil.rmtree(output)
    scenario_dir = Path(tempfile.mkdtemp(prefix="lane-k-fly-scenario-"))
    scenario = scenario_dir / "scenario.json"
    scenario.write_text(json.dumps({"commands": fly_commands()}))
    saved = _inject_visitfly(root)
    try:
        proc = subprocess.run(
            [
                sys.executable, "tools/harness/run.py",
                "--sdk", str(sdk),
                "--output", str(output),
                "--scenario", str(scenario),
                "--ready-timeout", "120",
                "--timeout", "140",
                "--max-frames", "4000",
                "--recent-interval", "10000",
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
    result_path = output / "runtime-data" / "result.json"
    result = json.loads(result_path.read_text()) if result_path.is_file() else {}
    return proc, outcome, rows, result


class FlyMemoryTest(unittest.TestCase):
    def test_patch_is_a_diff_and_does_not_raise_the_pool(self):
        text = PATCH.read_text()
        self.assertIn("diff --git a/Source/game/fieldTravelRuntime.lua", text)
        self.assertIn("diff --git a/Source/world/overworld.lua", text)
        self.assertIn("releaseFlyOrigin", text)
        self.assertIn("function SourceEvents.releaseRecentContent()", text)
        self.assertIn("function TileRegistry:releaseRenderedImages()", text)
        self.assertIn("consumeMissedBed", text)
        self.assertIn("table.create", text)
        self.assertNotIn("MallocPoolSize", text)
        self.assertNotIn("DOOR_FADE_FRAMES", text)
        self.assertNotIn("xfail", text.lower())
        self.assertNotIn("skip", text.lower())

    def test_viridian_fly_to_fuchsia_stays_under_budget(self):
        try:
            sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))
        except ProtocolError as error:
            raise RuntimeError(str(error)) from error
        output = Path(os.environ.get(
            "LANE_K_FLY_OUTPUT",
            tempfile.mkdtemp(prefix="lane-k-fly-"),
        ))
        proc, outcome, rows, result = run_fly(ROOT, output)
        phase = next((row for row in rows if row["phase"] == DEST_PHASE), None)
        snapshot = result.get("snapshot") or {}
        player = snapshot.get("player") or {}
        detail = json.dumps({
            "ok": outcome.get("ok"),
            "error": outcome.get("error"),
            "zone": snapshot.get("zone"),
            "zone_id": snapshot.get("zone_id"),
            "x": player.get("x"),
            "y": player.get("y"),
            "heap_kib": (snapshot.get("performance") or {}).get("heap_kib"),
            "peak_kib": None if phase is None else phase["peak_kib"],
            "returncode": proc.returncode,
        }, sort_keys=True)
        self.assertTrue(outcome.get("ok"), detail)
        self.assertIsNotNone(phase, detail)
        self.assertLessEqual(phase["peak_kib"], LUA_PEAK_BUDGET_KIB, detail)
        self.assertEqual(snapshot.get("zone"), DEST_ZONE, detail)
        self.assertEqual(snapshot.get("zone_id"), DEST_ID, detail)
        self.assertEqual((player.get("x"), player.get("y")), ARRIVAL, detail)


if __name__ == "__main__":
    unittest.main()
