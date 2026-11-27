#!/usr/bin/env python3
"""Cave encounter contracts must finish inside the 16 MiB pool.

Two cases run out of memory on clean main. The terrain-only Mt. Moon fixture
calls SourceMaps.padded, which inflates the raw slice, then
Zone.fromMapDefinition deep-copies a terrain table per cell. Viridian Forest
then decodes its full source record while that zone is still live. Neither
allocation has a contiguous hole. The packed runtime path and reading the
Blue rate before the zone is built are the fix in
tools/notes/lane-e-cave-encounter-memory.patch.

Measured on this host with MallocPoolSize 16645684, same runner:

- 61a70ffe, unpatched: 6 passed, 2 failed, scored heap 13112.371 KiB
- 247d60a9, unpatched: 6 passed, 2 failed, scored heap 13113.326 KiB
- terrain fixture after SourceMaps.padded: 13827.54 KiB, then
  Zone.fromMapDefinition raises "not enough memory"
- Viridian Forest source decode beside the live zone: 13398.69 KiB, then
  the same error. Releasing the two-slot runtime cache first only drops the
  floor from 13302.12 KiB to 13001.10 KiB and both cases still fail.
- 247d60a9 with the patch: 8 passed, 0 failed, scored heap 13046.306 KiB.
  Peak 13525.742 KiB at map.ViridianForest.zone.end.

61a70ffe and 247d60a9 fail the same two cases, so the commits between them
did not introduce it. Set CAVE_ROOT to a tree where the patch is applied.
The default tree is this checkout, which stays unpatched until lane E lands it.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(os.environ.get("CAVE_ROOT", Path(__file__).resolve().parents[2]))
sys.path.insert(0, str(ROOT))

from tools.harness.run import ProtocolError, sdk_path
from tools.measure_boot_budget import LUA_PEAK_BUDGET_KIB

PATCH = Path(__file__).resolve().parents[2] / "tools/notes/lane-e-cave-encounter-memory.patch"


def run_cave(root, output):
    sdk = sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))
    output = Path(output)
    if output.exists():
        shutil.rmtree(output)
    proc = subprocess.run(
        [
            sys.executable, "tools/harness/run.py",
            "--sdk", str(sdk),
            "--output", str(output),
            "--recent-interval", "10000",
            "--max-frames", "18000",
            "--timeout", "180",
            "contracts cave-encounters",
        ],
        cwd=root,
        check=False,
        text=True,
        capture_output=True,
    )
    progress_path = output / "runtime-data" / "contract-progress.json"
    progress = json.loads(progress_path.read_text()) if progress_path.is_file() else {}
    outcome_path = output / "outcome.json"
    outcome = json.loads(outcome_path.read_text()) if outcome_path.is_file() else {
        "ok": False,
        "error": proc.stderr or proc.stdout or "no outcome",
    }
    return proc, outcome, progress


class CaveEncounterMemoryTest(unittest.TestCase):
    def test_patch_keeps_the_pool_and_the_unbound_fixture(self):
        text = PATCH.read_text()
        self.assertIn("diff --git a/Source/dev/caveEncounterContracts.lua", text)
        self.assertIn("diff --git a/Source/world/sourceMapProvider.lua", text)
        self.assertIn("terrainFixture", text)
        self.assertIn("collectgarbage(\"collect\")", text)
        self.assertNotIn("MallocPoolSize", text)
        self.assertNotIn("xfail", text.lower())
        self.assertNotIn("skip", text.lower())

    def test_cave_encounters_fit(self):
        try:
            sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))
        except ProtocolError as error:
            raise RuntimeError(str(error)) from error
        output = Path(os.environ.get(
            "CAVE_OUTPUT",
            tempfile.mkdtemp(prefix="lane-k-cave-"),
        ))
        proc, outcome, progress = run_cave(ROOT, output)
        detail = json.dumps({
            "root": str(ROOT),
            "ok": outcome.get("ok"),
            "error": outcome.get("error"),
            "passed": progress.get("passed"),
            "failed": progress.get("failed"),
            "heap_kib": progress.get("heap_kib"),
            "returncode": proc.returncode,
        }, sort_keys=True)
        self.assertTrue(outcome.get("ok"), detail)
        self.assertEqual(progress.get("passed"), 8, detail)
        self.assertEqual(progress.get("failed"), 0, detail)
        self.assertLessEqual(progress.get("heap_kib"), LUA_PEAK_BUDGET_KIB, detail)


if __name__ == "__main__":
    unittest.main()
