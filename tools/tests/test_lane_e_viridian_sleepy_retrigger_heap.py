#!/usr/bin/env python3
"""Retriggering the Viridian sleepy old man must not grow the Lua heap.

Measured on lane E 79fbcba560e34945a130d7e1788ab44be5aa8d77, full harness,
MallocPoolSize 16645684, recent interval 18000. Each retrigger is its own
request: move onto (19, 9), dismiss the private-property line, wait until
RED is back on (19, 10). collectgarbage("count") at the settled snapshot:

    cycle 1   13225.4 KiB
    cycle 2   13308.3 KiB
    cycle 3   13391.4 KiB
    cycle 4   13474.6 KiB

About 83 KiB stays behind after every request. A full collect before the
count keeps the same scene at 13216 KiB, so the bytes are not a live
retainer. GameBootstrap uses generational collection, and the frame loop
only calls collectgarbage("step", 1). finish() used to major-collect only
for the journey profile, after json.encodeToFile had kept the request graph
alive. The long retrigger loop on the earlier scratch reached 24749.7 KiB.

The same four requests after tools/notes/lane-e-viridian-sleepy-retrigger-heap.patch:

    cycle 1   13225.4 KiB
    cycle 2   13243.6 KiB
    cycle 3   13244.4 KiB
    cycle 4   13244.2 KiB

A snapshot after the fourth request, with that request's tables already
collected, is 13179.7 KiB. The four settled readings stay within 64 KiB of
the first. This fails on the unpatched tree.
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

from tools.harness.protocol import Client, OwnerLock, ProtocolError
from tools.harness.run import prepare

PROJECT = Path(os.environ["POKEMON_PROJECT"]) if os.environ.get("POKEMON_PROJECT") else ROOT
SDK = Path(os.environ.get("PLAYDATE_SDK_PATH", "/home/ubuntu/Developer/PlaydateSDK"))
POOL_INI = Path.home() / ".config/Playdate Simulator/Playdate Simulator.ini"
POOL_BYTES = "16645684"
CYCLES = 4
BOUND_KIB = 64

FIXTURE = [
    {
        "op": "fixture",
        "options": {
            "intro": "skip",
            "opening": False,
            "seed": 1,
            "zone": "kanto_viridian_city",
            "entry": {"x": 19, "y": 10, "facing": "up"},
            "player_pokemon": {"species": "squirtle", "level": 5},
        },
    },
    "encounters off",
    "snapshot",
]
CYCLE = [
    "move up",
    "dismiss",
    {"op": "await", "path": "root", "equals": "overworld", "frames": 240},
    {"op": "await", "path": "player.y", "equals": 10, "frames": 120},
    "snapshot",
]


def snapshot_heap(result, op):
    for entry in reversed(result.get("results") or []):
        if entry.get("op") == op and entry.get("snapshot"):
            return entry
    return None


class SleepyRetriggerHeapTest(unittest.TestCase):
    def test_retriggers_stay_near_the_first_heap(self):
        pool = POOL_INI.read_text(encoding="utf-8")
        self.assertIn("MallocPoolSize=" + POOL_BYTES, pool)
        self.assertTrue(SDK.is_dir(), "Playdate SDK is required")
        os.environ["PLAYDATE_SDK_PATH"] = str(SDK)
        os.environ.setdefault("DISPLAY", ":1")
        output = Path(tempfile.mkdtemp(prefix="sleepy-retrigger-"))
        self.addCleanup(shutil.rmtree, output, True)
        metadata = prepare(
            PROJECT, SDK, output, os.urandom(16).hex(), recent_interval=18000)
        data = Path(metadata["data_dir"])
        data.mkdir(parents=True, exist_ok=False)
        owner = OwnerLock(data / "owner.lock")
        owner.__enter__()
        log_handle = (output / "simulator.log").open("w")
        process = subprocess.Popen(
            [metadata["simulator"], metadata["bundle"]],
            stdout=log_handle, stderr=subprocess.STDOUT,
        )
        client = Client(
            data, metadata["build_id"], metadata["session_id"], output, owner=owner)
        heaps = []
        try:
            client.ready(240)

            def send(commands):
                try:
                    return client.send(commands, 120, 4000)
                except ProtocolError as exc:
                    result_path = output / f"{client.sequence:05d}-result.json"
                    if (output / "runtime-error.json").is_file() or not result_path.is_file():
                        raise
                    result = json.loads(result_path.read_text(encoding="utf-8"))
                    self.fail(f"{exc}; result {result.get('status')} {result.get('error')}")

            send(FIXTURE)
            for _ in range(CYCLES):
                result = send(CYCLE)
                move = snapshot_heap(result, "move")
                settled = snapshot_heap(result, "snapshot")
                self.assertIsNotNone(move, result.get("error"))
                self.assertIsNotNone(settled, result.get("error"))
                player = move["snapshot"]["player"]
                self.assertEqual(move["snapshot"].get("root"), "dialog")
                self.assertEqual(player.get("x"), 19)
                self.assertEqual(player.get("y"), 9)
                self.assertEqual(settled["snapshot"]["player"].get("y"), 10)
                heaps.append(settled["snapshot"]["performance"]["heap_kib"])
        finally:
            process.kill()
            process.wait(timeout=20)
            owner.__exit__(None, None, None)
            log_handle.close()
        self.assertEqual(len(heaps), CYCLES)
        self.assertLessEqual(
            heaps[-1] - heaps[0],
            BOUND_KIB,
            f"sleepy retriggers grew the heap from {heaps[0]:.1f} KiB to {heaps[-1]:.1f} KiB "
            f"({heaps}). Reclaim the harness request graph after each request.",
        )


if __name__ == "__main__":
    unittest.main()
