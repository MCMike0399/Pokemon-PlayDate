#!/usr/bin/env python3
"""A live Cerulean must survive a run of one-frame harness commands.

Each finished command keeps a settled player and zone. Frames inside a
wait stay stubs once the heap is at least 13000 KiB. An empty table
encodes as an array, so a non-final move or wait would lose its player.
The landed record is the completion snapshot in Source/dev/harness.lua.
tools/notes/lane-e-harness-trace-handle.patch stays held and is not
reapplied: those hunks are already the parent of the snapshot, and a
second apply does not fit.
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
FOLLOWUP = ROOT / "tools/notes/lane-e-harness-completion-snapshot.patch"


def cerulean_fixture():
    return {
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
    }


def forty_waits():
    script = [cerulean_fixture(), "encounters off"]
    script.extend(["wait 1"] * 40)
    script.append({"op": "quiesce"})
    return script


def one_wait_then_quiesce():
    return [cerulean_fixture(), "encounters off", "wait 1", {"op": "quiesce"}]


def run_cerulean(root, output, script):
    sdk = sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))
    output = Path(output)
    if output.exists():
        shutil.rmtree(output)
    scenario_dir = Path(tempfile.mkdtemp(prefix="lane-k-harness-scenario-"))
    scenario = scenario_dir / "scenario.json"
    scenario.write_text(json.dumps({"commands": script}))
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
    if not result_path.is_file():
        found = sorted(output.glob("*result.json"))
        result_path = found[-1] if found else result_path
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
        self.assertIn("local lastCommand", text)
        self.assertNotIn("settledCommandSnapshot", text)
        follow = FOLLOWUP.read_text()
        self.assertIn("diff --git a/Source/dev/harness.lua", follow)
        self.assertIn("settledCommandSnapshot", follow)
        self.assertIn("elseif complete", follow)
        self.assertIn("-    local lastCommand", follow)
        self.assertNotIn("skip", follow.lower())
        self.assertNotIn("MallocPoolSize", follow)
        self.assertNotIn("MallocPoolSize", text)
        self.assertNotIn("xfail", text.lower())
        self.assertNotIn("skip", text.lower())
        source = (ROOT / "Source/dev/harness.lua").read_text()
        self.assertIn("local function settledCommandSnapshot", source)
        self.assertNotIn("local lastCommand", source)
        held = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, check=False, text=True, capture_output=True)
        self.assertNotEqual(held.returncode, 0, "held trace-handle patch must not reapply")

    def test_cerulean_command_snapshots_return(self):
        try:
            sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))
        except ProtocolError as error:
            raise RuntimeError(str(error)) from error
        output = Path(tempfile.mkdtemp(prefix="lane-k-harness-"))
        proc, outcome, result, heartbeat = run_cerulean(ROOT, output, forty_waits())
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

    def test_nonfinal_command_snapshot_has_a_player(self):
        try:
            sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))
        except ProtocolError as error:
            raise RuntimeError(str(error)) from error
        output = Path(tempfile.mkdtemp(prefix="lane-k-harness-player-"))
        proc, outcome, result, heartbeat = run_cerulean(
            ROOT, output, one_wait_then_quiesce())
        rows = result.get("results") or []
        waits = [row for row in rows if row.get("op") == "wait"]
        detail = json.dumps({
            "ok": outcome.get("ok"),
            "error": outcome.get("error"),
            "status": result.get("status"),
            "ops": [row.get("op") for row in rows],
            "wait_snapshot_type": type(waits[0].get("snapshot")).__name__ if waits else None,
            "heartbeat_tick": heartbeat.get("tick") or heartbeat.get("status"),
            "returncode": proc.returncode,
        }, sort_keys=True)
        self.assertTrue(outcome.get("ok"), detail)
        self.assertTrue(waits, detail)
        self.assertNotEqual(waits[0].get("command"), rows[-1].get("command"), detail)
        snapshot = waits[0].get("snapshot")
        self.assertIsInstance(snapshot, dict, detail)
        player = snapshot.get("player")
        self.assertIsInstance(player, dict, detail)
        self.assertIsInstance(player.get("x"), int, detail)
        self.assertIsInstance(player.get("y"), int, detail)
        self.assertTrue(player.get("settled"), detail)
        self.assertEqual(snapshot.get("zone"), "kanto_cerulean_city", detail)


if __name__ == "__main__":
    unittest.main()
