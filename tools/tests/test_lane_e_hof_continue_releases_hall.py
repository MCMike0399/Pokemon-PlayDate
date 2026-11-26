#!/usr/bin/env python3
"""A Hall of Fame continue must not keep the ceremony resident.

Measured on lane E 232d4452 with MallocPoolSize 16645684 and no capture
image (recent interval 18000). Continue.end, the boot-trace heap:

    ordinary Pallet save b7703d85...   13409 KiB
    Hall save 8e72131f...              13565 KiB

The Hall continue still held the Hall of Fame runtime definition and the
decoded postgame story. That is 156 KiB over a Pallet continue, and the
same boot then died on the walk north (signal 11, heap about 13857) when a
capture image was also live. This test fails until Continue.end for the
Hall save is within 150 KiB of the Pallet continue and four real steps
east from Pallet (5, 6) still land on (9, 6).
"""

import hashlib
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = Path(__file__).resolve().parent / "fixtures"
HALL_SAVE = FIXTURES / "lane-h-hall-continue-8e72131f.json"
PALLET_SAVE = FIXTURES / "lane-h-pallet-continue.json"
HALL_SHA = "8e72131fa1b88f59d3192a82a2e2d3da856ccf3b725b6860ccc69dcbc95d1cc1"
POOL_BYTES = "16645684"
SDK = Path(os.environ.get("PLAYDATE_SDK_PATH", "/home/ubuntu/Developer/PlaydateSDK"))
DATA = SDK / "Disk/Data"
POOL_INI = Path.home() / ".config/Playdate Simulator/Playdate Simulator.ini"

CONTINUE = [
    "wait 260", "press a", "wait 30", "press a",
    {"op": "await", "path": "title.phase", "equals": "menu", "frames": 900},
    "wait 30", "press a", "wait 45", "press a",
    {"op": "await", "path": "zone", "equals": "kanto_pallet_town", "frames": 1500},
    {"op": "await", "path": "player.x", "equals": 5, "frames": 80},
    {"op": "await", "path": "player.y", "equals": 6, "frames": 80},
    {"op": "await", "path": "player.facing", "equals": "down", "frames": 80},
]


def continue_heap(trace_text):
    found = None
    for line in trace_text.splitlines():
        parts = line.split("\t")
        if len(parts) >= 6 and parts[1] == "Continue.end":
            found = float(parts[5])
    return found


def seed_save(data_root, before, save, proc):
    deadline = time.time() + 45
    while proc.poll() is None and time.time() < deadline:
        if data_root.is_dir():
            for path in data_root.glob("com.poc.pokemon.harness.*"):
                if path.name not in before and path.is_dir():
                    target = path / "adventure.a.json"
                    target.write_bytes(save.read_bytes())
                    return target
        time.sleep(0.02)
    return None


def run_continue(output, save, commands):
    output = Path(output)
    scenario = output / "scenario.json"
    output.mkdir(parents=True)
    scenario.write_text(json.dumps({"commands": commands}), encoding="utf-8")
    before = {path.name for path in DATA.glob("com.poc.pokemon.harness.*")} if DATA.is_dir() else set()
    cmd = [
        sys.executable, "tools/harness/run.py",
        "--scenario", str(scenario),
        "--output", str(output / "run"),
        "--timeout", "180",
        "--ready-timeout", "180",
        "--max-frames", "6000",
        "--recent-interval", "18000",
    ]
    env = os.environ.copy()
    env["PLAYDATE_SDK_PATH"] = str(SDK)
    proc = subprocess.Popen(cmd, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    seeded = seed_save(DATA, before, save, proc)
    out, _ = proc.communicate()
    return proc.returncode, out, seeded, output / "run"


class HallContinueReleaseTest(unittest.TestCase):
    def test_hall_continue_matches_pallet_and_walks_four(self):
        self.assertEqual(hashlib.sha256(HALL_SAVE.read_bytes()).hexdigest(), HALL_SHA)
        pool = POOL_INI.read_text(encoding="utf-8")
        self.assertIn("MallocPoolSize=" + POOL_BYTES, pool)
        self.assertTrue(SDK.is_dir(), "Playdate SDK is required")

        with tempfile.TemporaryDirectory(prefix="hof-continue-") as tmp:
            tmp = Path(tmp)
            pallet_code, pallet_out, pallet_seed, pallet_run = run_continue(
                tmp / "pallet", PALLET_SAVE, CONTINUE + ["snapshot"])
            self.assertEqual(pallet_code, 0, pallet_out)
            self.assertIsNotNone(pallet_seed, "Pallet save was not copied in before GameSaves")
            hall_commands = CONTINUE + ["encounters off", "move right 4", "snapshot"]
            hall_code, hall_out, hall_seed, hall_run = run_continue(
                tmp / "hall", HALL_SAVE, hall_commands)
            self.assertEqual(hall_code, 0, hall_out)
            self.assertIsNotNone(hall_seed, "Hall save was not copied in before GameSaves")

            pallet_heap = continue_heap((pallet_run / "runtime-data/boot-trace.tsv").read_text(encoding="utf-8"))
            hall_heap = continue_heap((hall_run / "runtime-data/boot-trace.tsv").read_text(encoding="utf-8"))
            self.assertIsNotNone(pallet_heap, "Pallet continue did not reach Continue.end")
            self.assertIsNotNone(hall_heap, "Hall continue did not reach Continue.end")
            self.assertLessEqual(
                hall_heap - pallet_heap, 150,
                f"Hall Continue.end {hall_heap:.1f} KiB is more than 150 KiB above "
                f"the Pallet continue {pallet_heap:.1f} KiB. "
                "Release the Hall definition and the postgame tables.",
            )

            results = []
            for path in sorted(hall_run.glob("*-result.json")):
                payload = json.loads(path.read_text(encoding="utf-8"))
                results.extend(payload.get("results") or [])
            moves = [item for item in results if item.get("op") == "move"]
            self.assertTrue(moves, "the four-step walk did not report a move")
            move = moves[-1]
            self.assertEqual(move.get("outcome"), "ok", move)
            player = move["snapshot"]["player"]
            self.assertEqual(move["snapshot"].get("zone"), "kanto_pallet_town")
            self.assertEqual(player.get("x"), 9)
            self.assertEqual(player.get("y"), 6)
            self.assertTrue(player.get("settled"), player)


if __name__ == "__main__":
    unittest.main()
