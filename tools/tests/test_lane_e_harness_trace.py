#!/usr/bin/env python3
"""A live Cerulean must survive a run of one-frame harness commands.

Each finished command keeps a real diagnostics snapshot. Frames inside a
wait do not: once the heap is at least 13000 KiB those frames used to be
the allocation that never returned. An empty completion snapshot encodes
as an array, so a non-final move or wait loses its player. The fix is
tools/notes/lane-e-harness-trace-handle.patch. Both runs apply that patch
to a private worktree. Source on this branch stays unchanged.
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
    @classmethod
    def setUpClass(cls):
        cls.tree = Path(tempfile.mkdtemp(prefix="lane-k-harness-tree-"))
        cls.tree.rmdir()
        added = subprocess.run(
            ["git", "worktree", "add", "--detach", str(cls.tree), "HEAD"],
            cwd=ROOT, check=False, text=True, capture_output=True)
        if added.returncode != 0:
            raise RuntimeError(added.stderr or added.stdout)
        applied = subprocess.run(
            ["git", "apply", str(PATCH)],
            cwd=cls.tree, check=False, text=True, capture_output=True)
        if applied.returncode != 0:
            subprocess.run(["git", "worktree", "remove", "--force", str(cls.tree)], cwd=ROOT)
            raise RuntimeError(applied.stderr or applied.stdout)

    @classmethod
    def tearDownClass(cls):
        tree = getattr(cls, "tree", None)
        if tree and tree.exists():
            subprocess.run(
                ["git", "worktree", "remove", "--force", str(tree)],
                cwd=ROOT, check=False)

    def test_patch_is_a_diff_and_does_not_raise_the_pool(self):
        text = PATCH.read_text()
        self.assertIn("diff --git a/Source/dev/harness.lua", text)
        self.assertIn("local traceFile", text)
        self.assertIn("heapNow < 13000", text)
        self.assertIn("elseif complete", text)
        self.assertIn("settledCommandSnapshot", text)
        self.assertNotIn("lastCommand", text)
        follow = FOLLOWUP.read_text()
        self.assertIn("diff --git a/Source/dev/harness.lua", follow)
        self.assertIn("settledCommandSnapshot", follow)
        self.assertIn("-    local lastCommand", follow)
        self.assertNotIn("skip", follow.lower())
        self.assertNotIn("MallocPoolSize", text)
        self.assertNotIn("xfail", text.lower())
        self.assertNotIn("skip", text.lower())

    def test_cerulean_command_snapshots_return(self):
        try:
            sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))
        except ProtocolError as error:
            raise RuntimeError(str(error)) from error
        output = Path(tempfile.mkdtemp(prefix="lane-k-harness-"))
        proc, outcome, result, heartbeat = run_cerulean(self.tree, output, forty_waits())
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
            self.tree, output, one_wait_then_quiesce())
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


def assert_nonfinal_wait_has_player(test, root):
    try:
        sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))
    except ProtocolError as error:
        raise RuntimeError(str(error)) from error
    output = Path(tempfile.mkdtemp(prefix="lane-k-harness-checkout-"))
    proc, outcome, result, heartbeat = run_cerulean(root, output, one_wait_then_quiesce())
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
    test.assertTrue(outcome.get("ok"), detail)
    test.assertTrue(waits, detail)
    test.assertNotEqual(waits[0].get("command"), rows[-1].get("command"), detail)
    snapshot = waits[0].get("snapshot")
    test.assertIsInstance(snapshot, dict, detail)
    player = snapshot.get("player")
    test.assertIsInstance(player, dict, detail)
    test.assertIsInstance(player.get("x"), int, detail)
    test.assertIsInstance(player.get("y"), int, detail)
    test.assertTrue(player.get("settled"), detail)
    test.assertEqual(snapshot.get("zone"), "kanto_cerulean_city", detail)


class CheckoutHarnessSnapshotTest(unittest.TestCase):
    def test_checkout_nonfinal_command_keeps_a_player(self):
        """The tree under test must publish a player for a non-final command.

        Main snapshots every frame, so this passes there. 85512254 landed the
        earlier trace patch, which stores [] for that command, and this fails
        until tools/notes/lane-e-harness-completion-snapshot.patch is applied.
        """
        assert_nonfinal_wait_has_player(self, ROOT)


if __name__ == "__main__":
    unittest.main()
