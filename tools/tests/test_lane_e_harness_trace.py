#!/usr/bin/env python3
"""A live Cerulean must survive a run of one-frame harness commands.

Each finished command keeps the diagnostics snapshot. On Cerulean those
snapshots are about 30 KiB, so a string of wait 1 commands climbs from the
city's resting heap through 13927 KiB and the runtime raises not enough
memory. The product is idle on the overworld. The fix is
tools/notes/lane-e-harness-trace-handle.patch: one trace handle, and no full
snapshot once the heap is at least 13000 KiB except the first and last
frames. This test fails on Source that does not contain that fix.
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

PATCH = ROOT / "tools/notes/lane-e-harness-trace-handle.patch"


def commands():
    script = [
        {
            "op": "fixture",
            "options": {
                "intro": "skip",
                "opening": False,
                "seed": 11,
                "zone": "kanto_cerulean_city",
                "entry": {"x": 19, "y": 18, "facing": "down"},
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
        "encounters off",
    ]
    script.extend(["wait 1"] * 40)
    script.append({"op": "quiesce"})
    return script


def run_cerulean(root, output):
    sdk = sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))
    output = Path(output)
    if output.exists():
        shutil.rmtree(output)
    scenario_dir = Path(tempfile.mkdtemp(prefix="lane-k-harness-scenario-"))
    scenario = scenario_dir / "scenario.json"
    scenario.write_text(json.dumps({"commands": commands()}))
    try:
        proc = subprocess.run(
            [
                sys.executable, "tools/harness/run.py",
                "--sdk", str(sdk),
                "--output", str(output),
                "--scenario", str(scenario),
                "--ready-timeout", "90",
                "--timeout", "45",
                "--max-frames", "4000",
                "--recent-interval", "10000",
            ],
            cwd=root,
            check=False,
            text=True,
            capture_output=True,
        )
    finally:
        shutil.rmtree(scenario_dir, ignore_errors=True)
    outcome_path = output / "outcome.json"
    outcome = json.loads(outcome_path.read_text()) if outcome_path.is_file() else {
        "ok": False, "error": proc.stderr or proc.stdout or "no outcome",
    }
    result_path = output / "runtime-data" / "result.json"
    result = json.loads(result_path.read_text()) if result_path.is_file() else {}
    heartbeat_path = output / "runtime-data" / "heartbeat.json"
    heartbeat = json.loads(heartbeat_path.read_text()) if heartbeat_path.is_file() else {}
    return proc, outcome, result, heartbeat


class HarnessTraceTest(unittest.TestCase):
    def test_patch_is_a_diff_and_does_not_raise_the_pool(self):
        text = PATCH.read_text()
        self.assertIn("diff --git a/Source/dev/harness.lua", text)
        self.assertIn("local traceFile", text)
        self.assertIn("heapNow < 13000", text)
        self.assertNotIn("MallocPoolSize", text)
        self.assertNotIn("xfail", text.lower())
        self.assertNotIn("skip", text.lower())

    def test_cerulean_command_snapshots_return(self):
        try:
            sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))
        except ProtocolError as error:
            raise RuntimeError(str(error)) from error
        output = Path(os.environ.get(
            "LANE_K_HARNESS_OUTPUT",
            tempfile.mkdtemp(prefix="lane-k-harness-"),
        ))
        proc, outcome, result, heartbeat = run_cerulean(ROOT, output)
        snapshot = result.get("snapshot") or {}
        detail = json.dumps({
            "ok": outcome.get("ok"),
            "error": outcome.get("error"),
            "status": result.get("status"),
            "zone": snapshot.get("zone") if isinstance(snapshot, dict) else None,
            "heartbeat_tick": heartbeat.get("tick") or heartbeat.get("status"),
            "returncode": proc.returncode,
        }, sort_keys=True)
        self.assertTrue(outcome.get("ok"), detail)
        self.assertEqual(result.get("status"), "ok", detail)
        self.assertEqual(snapshot.get("zone"), "kanto_cerulean_city", detail)


if __name__ == "__main__":
    unittest.main()
