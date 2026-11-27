#!/usr/bin/env python3
"""Fifty new maps must leave the Center heap level, under the pool.

The four-map bound is tools/tests/test_lane_e_departed_tile_registry.py.
This walk visits fifty maps that have not been seen yet and reads
map.ViridianPokecenter.definition.begin after every five. On the
unpatched tree the Center is still climbing at map 50 (map 20 through
map 50 spans about 444 KiB) and a straight line crosses the pool near
map 158. The patch in tools/notes/lane-e-departed-tile-registry.patch
keeps that tail inside 96 KiB, and every sample under 15000 KiB.
16255.6 KiB is the pool. MallocPoolSize stays 16645684.
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
from tools.tests.test_lane_e_departed_tile_registry import (
    COMMANDS,
    POOL_INI,
    _inject,
    _restore,
    parse_trace,
)

PHASE = "map.ViridianPokecenter.definition.begin"
TAIL_FROM = 4
TAIL_KIB = 96
CEILING_KIB = 15000
MAPS = [
    "kanto_pallet_town", "kanto_viridian_city", "kanto_viridian_mart", "kanto_viridian_gym", "kanto_route1",
    "kanto_route2", "kanto_viridian_forest", "kanto_pewter_city", "kanto_pewter_mart", "kanto_pewter_gym",
    "kanto_route_3", "kanto_mt_moon_1f", "kanto_mt_moon_b1f", "kanto_mt_moon_b2f", "kanto_mt_moon_pokecenter",
    "kanto_route_4", "kanto_cerulean_city", "kanto_cerulean_mart", "kanto_cerulean_gym", "kanto_route_24",
    "kanto_route_25", "kanto_route_5", "kanto_route_6", "kanto_vermilion_city", "kanto_vermilion_mart",
    "kanto_vermilion_gym", "kanto_route_11", "kanto_digletts_cave", "kanto_route_9", "kanto_rock_tunnel_1f",
    "kanto_lavender_town", "kanto_lavender_mart", "kanto_pokemon_tower_1f", "kanto_route_8", "kanto_route_7",
    "kanto_celadon_city", "kanto_celadon_mart_1f", "kanto_saffron_city", "kanto_saffron_mart", "kanto_saffron_gym",
    "kanto_fuchsia_city", "kanto_fuchsia_mart", "kanto_route_12", "kanto_route_16", "kanto_cinnabar_island",
    "kanto_cinnabar_gym", "kanto_seafoam_islands_1f", "kanto_victory_road_1f", "kanto_power_plant",
    "kanto_safari_zone_center",
]


def commands():
    steps = [COMMANDS[0], "encounters off", "snapshot"]
    for index, key in enumerate(MAPS, start=1):
        steps.append("switchzone " + key)
        if index % 5 == 0:
            steps.append("switchzone kanto_viridian_center")
    steps.extend(["record center-return 8", "snapshot"])
    return steps


class DepartedTilePlateauTest(unittest.TestCase):
    def test_center_heap_levels_off_across_fifty_maps(self):
        pool = POOL_INI.read_text(encoding="utf-8")
        self.assertIn("MallocPoolSize=16645684", pool)
        self.assertEqual(len(MAPS), 50)
        try:
            sdk = sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))
        except ProtocolError as error:
            raise RuntimeError(str(error)) from error
        output = Path(tempfile.mkdtemp(prefix="departed-plateau-"))
        shutil.rmtree(output)
        self.addCleanup(shutil.rmtree, output, True)
        scenario_dir = Path(tempfile.mkdtemp(prefix="departed-plateau-scenario-"))
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
                    "--timeout", "420",
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
        detail = json.dumps({
            "ok": outcome.get("ok"),
            "error": outcome.get("error"),
            "begins": [round(value, 1) for value in begins],
            "returncode": proc.returncode,
        })
        self.assertTrue(outcome.get("ok"), detail)
        self.assertGreaterEqual(len(begins), 11, detail)
        samples = begins[:11]
        self.assertLessEqual(max(samples), CEILING_KIB, detail)
        tail = samples[TAIL_FROM:]
        span = max(tail) - min(tail)
        self.assertLessEqual(
            span, TAIL_KIB,
            f"Center heap from map 20 through map 50 spanned {span:.1f} KiB ({detail})",
        )


if __name__ == "__main__":
    unittest.main()
