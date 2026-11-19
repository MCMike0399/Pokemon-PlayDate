"""A scored contract report survives the title-score inflate.

Cerulean unloads audio/score/title so the maps can build. The next frame
used to file.run that score into a fragmented pool, and the runtime error
replaced the finished report with an empty result. The reply now leaves a
missing score unloaded, and if a compressed read still fails, the finished
contracts are published instead of runtime-error.json.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HARNESS = ROOT / "Source/dev/harness.lua"


class CeruleanReplyTests(unittest.TestCase):
    def test_a_missing_score_is_not_reloaded_for_the_reply(self):
        text = HARNESS.read_text()
        guard = text.split("local function keepMissingScores()", 1)[1].split(
            "function Harness.beforeFrame", 1)[0]
        self.assertIn('path:sub(1, 12) == "audio/score/"', guard)
        self.assertIn("KantoScores[path:sub(13)]", guard)
        self.assertIn("KantoScores[name]", guard)
        before = text.split("function Harness.beforeFrame", 1)[1].split(
            "function Harness.afterFrame", 1)[0]
        self.assertLess(before.index("finished.contracts"), before.index("keepMissingScores()"))
        self.assertLess(before.index("keepMissingScores()"), before.index('publish("result.json"'))

    def test_a_scored_report_is_published_before_a_runtime_error(self):
        text = HARNESS.read_text()
        error = text.split("if runtimeError then", 1)[1].split("Autopilot.afterFrame()", 1)[0]
        contracts = error.index("command.contracts")
        result = error.index('publish("result.json"')
        runtime = error.index('publish("runtime-error.json"')
        self.assertLess(contracts, result)
        self.assertLess(result, runtime)
        self.assertIn("results = entries", error)

    def test_a_failed_contract_report_is_published_before_the_failure_capture(self):
        text = HARNESS.read_text()
        reply = text.split("if failure and command.contracts then", 1)[1].split(
            "entries[#entries + 1]", 1)[0]
        self.assertLess(reply.index('publish("result.json"'), reply.index("return"))
        self.assertNotIn("HarnessCapture.write", reply)


if __name__ == "__main__":
    unittest.main()
