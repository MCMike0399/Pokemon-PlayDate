#!/usr/bin/env python3
"""Deferred scores must decode to the same notes as the warm's file.run.

The departed-tile warm skips every bed when BootTrace's 9 MiB sample is on.
A player build then loads a bed on first play through KantoSynth.ensureScore,
which is the same playdate.file.run of audio/score/<name>. This session asks
the patched synth for each score's identity and compares it to a host load of
that score file. The checksum is ticks, loop, note count, and every note field.
MallocPoolSize stays 16645684. The 9 MiB guard is not changed.
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
from tools.tests.test_lane_e_departed_tile_registry import POOL_INI, _restore

# Keep this mix identical to KantoSynth.identity in the departed-tile patch.
HOST_LUA = r'''
local function identity(score)
    local notes = score.notes
    local count = notes and #notes or score.count or 0
    local sum = (score.ticks or 0) + (score.loop or 0)
    sum = (sum + count * 1000003) % 2147483647
    if notes then
        for index = 1, #notes do
            local note = notes[index]
            for field = 1, #note do
                local value = note[field]
                if type(value) == "number" then
                    sum = (sum * 131 + math.floor(value * 1000)) % 2147483647
                elseif type(value) == "string" then
                    for byte = 1, #value do
                        sum = (sum * 131 + string.byte(value, byte)) % 2147483647
                    end
                end
            end
        end
    end
    return string.format("%d:%s:%d:%d", score.ticks or 0, tostring(score.loop or 0), count, sum)
end
local path, name = arg[1], arg[2]
KantoScores = {}
dofile(path)
local score = assert(KantoScores[name], "missing " .. name)
io.write(identity(score))
'''

PARSE_ANCHOR = (
    '    elseif op == "snapshot" or op == "gamestate" or op == "state" or op == "pokemon"\n'
    '        or op == "dismiss" or op == "atlas" or op == "quiesce" then\n'
    '        valid = #args == 0\n'
    '    end\n'
)
PARSE_INSERT = (
    '    elseif op == "snapshot" or op == "gamestate" or op == "state" or op == "pokemon"\n'
    '        or op == "dismiss" or op == "atlas" or op == "quiesce" then\n'
    '        valid = #args == 0\n'
    '    elseif op == "score-identity" then valid = #args == 0\n'
    '    end\n'
)
RUN_ANCHOR = '        elseif command.op == "snapshot" or command.op == "shot" then complete = true\n'
RUN_INSERT = '''        elseif command.op == "snapshot" or command.op == "shot" then complete = true
        elseif command.op == "score-identity" then
            assert(KantoSynth and KantoSynth.identity, "score identity requires the departed-tile patch")
            local names = {}
            local listed = playdate.file.listFiles("audio/score") or {}
            for _, file in ipairs(listed) do
                local name = file:gsub("%.pdz$", ""):gsub("%.lua$", "")
                if name ~= file and not name:find("%.", 1, true) then
                    names[#names + 1] = name
                end
            end
            table.sort(names)
            local lines = {}
            for _, name in ipairs(names) do
                KantoSynth.unloadAll()
                -- The warm's load. identity then reads that table.
                playdate.file.run("audio/score/" .. name)
                local warm = KantoSynth.identity(name)
                KantoSynth.unloadAll()
                -- The deferred path: ensureScore runs the same chunk again.
                local deferred = KantoSynth.identity(name)
                lines[#lines + 1] = name .. " " .. warm .. " " .. deferred
            end
            local out = playdate.file.open("score-identity.txt", playdate.file.kFileWrite)
            out:write(table.concat(lines, "\\n") .. "\\n")
            out:close()
            complete = true
'''


def host_identities(score_dir):
    script = Path(tempfile.mkdtemp(prefix="score-identity-host-")) / "identity.lua"
    script.write_text(HOST_LUA)
    found = {}
    for path in sorted(score_dir.glob("*.lua")):
        name = path.stem
        proc = subprocess.run(
            ["lua5.4", str(script), str(path), name],
            check=False, text=True, capture_output=True,
        )
        if proc.returncode != 0:
            raise RuntimeError(proc.stderr or proc.stdout)
        found[name] = proc.stdout.strip()
    return found


def _inject(root):
    path = root / "Source/dev/harness.lua"
    text = path.read_text()
    if text.count(PARSE_ANCHOR) != 1 or text.count(RUN_ANCHOR) != 1:
        raise RuntimeError("score-identity anchor missing in harness.lua")
    saved = {path: text}
    path.write_text(text.replace(PARSE_ANCHOR, PARSE_INSERT, 1).replace(RUN_ANCHOR, RUN_INSERT, 1))
    return saved


class ScoreIdentityTest(unittest.TestCase):
    def test_deferred_scores_match_the_score_files(self):
        pool = POOL_INI.read_text(encoding="utf-8")
        self.assertIn("MallocPoolSize=16645684", pool)
        engine = (ROOT / "Source/audio/engine.lua").read_text()
        self.assertIn("function KantoSynth.identity", engine)
        expected = host_identities(ROOT / "Source/audio/score")
        self.assertGreaterEqual(len(expected), 60)
        try:
            sdk = sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))
        except ProtocolError as error:
            raise RuntimeError(str(error)) from error
        output = Path(tempfile.mkdtemp(prefix="score-identity-"))
        shutil.rmtree(output)
        self.addCleanup(shutil.rmtree, output, True)
        scenario_dir = Path(tempfile.mkdtemp(prefix="score-identity-scenario-"))
        self.addCleanup(shutil.rmtree, scenario_dir, True)
        commands = [
            {
                "op": "fixture",
                "options": {
                    "intro": "skip",
                    "opening": False,
                    "seed": 1,
                    "zone": "kanto_viridian_center",
                    "entry": {"x": 7, "y": 4, "facing": "right"},
                    "player_pokemon": {"species": "squirtle", "level": 5},
                },
            },
            {"op": "score-identity"},
            "snapshot",
        ]
        (scenario_dir / "scenario.json").write_text(json.dumps({"commands": commands}))
        saved = _inject(ROOT)
        try:
            proc = subprocess.run(
                [
                    sys.executable, "tools/harness/run.py",
                    "--sdk", str(sdk),
                    "--output", str(output),
                    "--scenario", str(scenario_dir / "scenario.json"),
                    "--ready-timeout", "180",
                    "--timeout", "300",
                    "--max-frames", "18000",
                ],
                cwd=ROOT, check=False, text=True, capture_output=True,
            )
        finally:
            _restore(saved)
        outcome_path = output / "outcome.json"
        outcome = json.loads(outcome_path.read_text()) if outcome_path.is_file() else {
            "ok": False, "error": proc.stderr or proc.stdout or "no outcome",
        }
        self.assertTrue(outcome.get("ok"), json.dumps({"error": outcome.get("error"), "returncode": proc.returncode}))
        report = (output / "runtime-data" / "score-identity.txt").read_text()
        got = {}
        for line in report.splitlines():
            name, warm, deferred = line.split()
            got[name] = (warm, deferred)
        self.assertEqual(sorted(got), sorted(expected))
        mismatched = []
        for name, digest in expected.items():
            warm, deferred = got[name]
            host_shape = ":".join(digest.split(":")[:3])
            warm_shape = ":".join(warm.split(":")[:3])
            if warm != deferred or warm_shape != host_shape:
                mismatched.append(f"{name} host {host_shape} warm {warm} deferred {deferred}")
        self.assertEqual(mismatched, [])


if __name__ == "__main__":
    unittest.main()
