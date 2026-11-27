#!/usr/bin/env python3
"""The party list must not call import() after the pdz has loaded.

Playdate allows import() only while a pdx is loading. PartyState:drawPartyList
calls import "game/gbFont" on every paint. Opening the party menu from the
pause reorder after seq1869 (Victory Road, build e899cdde) raises
game/partyState.lua:374: import() called outside of pdz loading.
loadStatusScreen and PauseState:drawTrainer call the same import at runtime.
pauseState.lua already imports game/gbFont at file scope, which loads
TitleIdle before the update loop. The runtime calls have to go, and
partyState.lua has to import at file scope so the list still has the font
when it is loaded on its own.

Source/game/partyState.lua and Source/game/pauseState.lua are shared, so the
fix is tools/notes/lane-e-party-import.patch. This test fails until that
patch is in the shared files.
"""

import json
import os
import shutil
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tools.harness.run import sdk_path
PARTY = ROOT / "Source/game/partyState.lua"
PAUSE = ROOT / "Source/game/pauseState.lua"
PATCH = ROOT / "tools/notes/lane-e-party-import.patch"


def body(source, name, nxt):
    return source.split(f"function {name}", 1)[1].split(f"function {nxt}", 1)[0]


class PartyImportTests(unittest.TestCase):
    def test_party_list_does_not_import_after_load(self):
        party = PARTY.read_text(encoding="utf-8")
        pause = PAUSE.read_text(encoding="utf-8")
        self.assertTrue(PATCH.is_file(), "missing tools/notes/lane-e-party-import.patch")
        # File scope, before any function. A call indented inside draw is too late.
        head = party.split("function PartyState:", 1)[0]
        self.assertIn(
            'import "game/gbFont"',
            head,
            "Apply tools/notes/lane-e-party-import.patch",
        )
        for name, nxt, source in (
            ("PartyState:drawPartyList", "PartyState:draw", party),
            ("PartyState:loadStatusScreen", "PartyState:drawStatus", party),
            ("PauseState:drawTrainer", "PauseState:releaseTrainerScreen", pause),
        ):
            self.assertNotIn(
                'import "game/gbFont"',
                body(source, name, nxt),
                f"{name} calls import() after the pdx has loaded. "
                "Apply tools/notes/lane-e-party-import.patch",
            )

    def test_no_other_import_runs_after_load(self):
        # main.lua's imports are the pdx boot itself. namingState.lua imports
        # gbFont while that file is loading, inside `if Class then`, before
        # NamingState exists. Every other indented import is a call after load.
        allowed = {"Source/main.lua", "Source/game/namingState.lua"}
        late = []
        for path in sorted((ROOT / "Source").rglob("*.lua")):
            rel = path.relative_to(ROOT).as_posix()
            if rel in allowed:
                continue
            for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                stripped = line.lstrip()
                if line[:1].isspace() and stripped.startswith("import ") and not stripped.startswith("import ("):
                    late.append("%s:%d: %s" % (rel, number, stripped))
        self.assertEqual(late, [])
        naming = (ROOT / "Source/game/namingState.lua").read_text(encoding="utf-8")
        load, _, functions = naming.partition("function NamingState")
        self.assertIn('import "game/gbFont"', load)
        self.assertNotIn('import "game/gbFont"', functions)

    def test_boot_opens_party_status_and_trainer_card(self):
        output = Path(os.environ.get("PARTY_IMPORT_OUTPUT", "/tmp/party-import-boot"))
        if output.exists():
            shutil.rmtree(output)
        scenario = output.parent / "party-import-boot.json"
        scenario.write_text(json.dumps({
            "commands": [
                {"op": "fixture", "options": {
                    "intro": "skip", "opening": False, "seed": 1,
                    "zone": "reds_house_2f",
                    "player_pokemon": {"species": "squirtle", "level": 5},
                }},
                {"op": "await", "path": "player.settled", "equals": True, "frames": 120},
                "press b",
                "wait 4",
                {"op": "await", "path": "root", "equals": "pause", "frames": 30},
                "press a",
                "wait 4",
                {"op": "await", "path": "root", "equals": "party", "frames": 30},
                {"op": "await", "path": "party_ui.phase", "equals": "list", "frames": 30},
                "press a",
                "wait 2",
                "press a",
                "wait 4",
                {"op": "await", "path": "party_info.page", "equals": "stats", "frames": 30},
                "press b",
                "wait 2",
                "press b",
                "wait 4",
                {"op": "await", "path": "root", "equals": "overworld", "frames": 30},
                "press b",
                "wait 4",
                {"op": "await", "path": "pause.phase", "equals": "menu", "frames": 30},
                {"op": "await", "path": "pause.selected", "equals": 1, "frames": 15},
                "press down",
                "press down",
                {"op": "await", "path": "pause.selected", "equals": 3, "frames": 15},
                "press a",
                "wait 4",
                {"op": "await", "path": "pause.phase", "equals": "trainer", "frames": 30},
            ],
        }))
        proc = subprocess.run(
            [
                sys.executable, "tools/harness/run.py",
                "--sdk", str(sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))),
                "--scenario", str(scenario),
                "--output", str(output),
                "--timeout", "180",
                "--ready-timeout", "90",
            ],
            cwd=ROOT,
            check=False,
            text=True,
            capture_output=True,
            env={**os.environ, "DISPLAY": os.environ.get("DISPLAY", ":1")},
        )
        outcome = output / "outcome.json"
        detail = (proc.stderr or "") + (proc.stdout or "")
        if outcome.is_file():
            detail += outcome.read_text(encoding="utf-8")
        result = output / "runtime-data" / "result.json"
        if result.is_file():
            detail += result.read_text(encoding="utf-8")[:1500]
        self.assertTrue(outcome.is_file() and '"ok": true' in outcome.read_text(encoding="utf-8"), detail[-2000:])
        self.assertNotIn("import() called outside", detail)


if __name__ == "__main__":
    unittest.main()
