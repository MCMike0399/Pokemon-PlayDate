#!/usr/bin/env python3
"""The field-travel Fly contract must load Pewter after Cerulean has been released.

On 79fbcba5 the contract ensured Pewter while Cerulean was still live, and the
scene died at fieldTravelContracts.lua:91 with not enough memory. The retained
runtime definitions from the Surf and Safari scenes were still in the pool as
well. switchZone already releases a departing city. This contract owns a
private context, so the release belongs in the contract. The patch is
tools/notes/lane-e-fly-contract-release.patch. This test fails on Source that
does not contain that fix.
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

PATCH = ROOT / "tools/notes/lane-e-fly-contract-release.patch"
FLY = "Fly uses durable visited cities without granting route destinations"


def run_contracts(root, output):
    sdk = sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))
    output = Path(output)
    if output.exists():
        shutil.rmtree(output)
    proc = subprocess.run(
        [
            sys.executable, "tools/harness/run.py",
            "--sdk", str(sdk),
            "--output", str(output),
            "--timeout", "120",
            "--ready-timeout", "90",
            "--max-frames", "8000",
            "--recent-interval", "10000",
            "contracts field-travel",
        ],
        cwd=root,
        check=False,
        text=True,
        capture_output=True,
    )
    outcome_path = output / "outcome.json"
    outcome = json.loads(outcome_path.read_text()) if outcome_path.is_file() else {
        "ok": False, "error": proc.stderr or proc.stdout or "no outcome",
    }
    progress_path = output / "runtime-data" / "contract-progress.json"
    progress = json.loads(progress_path.read_text()) if progress_path.is_file() else {}
    fly = None
    for path in output.rglob("*result.json"):
        try:
            data = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError):
            continue
        for result in data.get("results") or []:
            for test in ((result.get("contracts") or {}).get("tests") or []):
                if FLY in (test.get("name") or ""):
                    fly = test
    return proc, outcome, progress, fly


class FlyContractTest(unittest.TestCase):
    def test_patch_is_a_diff_and_does_not_raise_the_pool(self):
        text = PATCH.read_text()
        self.assertIn("diff --git a/Source/dev/fieldTravelContracts.lua", text)
        self.assertIn("function releaseRetainedCityResidue()", text)
        self.assertIn("function releaseDepartedCity(g)", text)
        self.assertIn("releaseDepartedCity(g)", text)
        self.assertNotIn("MallocPoolSize", text)
        self.assertNotIn("xfail", text.lower())
        self.assertNotIn("skip", text.lower())

    def test_fly_visited_cities_stays_under_the_pool(self):
        try:
            sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))
        except ProtocolError as error:
            raise RuntimeError(str(error)) from error
        output = Path(os.environ.get(
            "LANE_K_CONTRACT_OUTPUT",
            tempfile.mkdtemp(prefix="lane-k-fly-contract-"),
        ))
        proc, outcome, progress, fly = run_contracts(ROOT, output)
        detail = json.dumps({
            "ok": outcome.get("ok"),
            "error": outcome.get("error"),
            "progress": progress,
            "fly": fly,
            "returncode": proc.returncode,
        }, sort_keys=True)
        self.assertTrue(outcome.get("ok"), detail)
        self.assertEqual(progress.get("suite"), "field-travel", detail)
        self.assertTrue(progress.get("ok"), detail)
        self.assertEqual(progress.get("failed"), 0, detail)
        self.assertGreaterEqual(progress.get("passed") or 0, 3, detail)
        self.assertIsNotNone(fly, detail)
        self.assertTrue(fly.get("ok"), detail)


if __name__ == "__main__":
    unittest.main()
