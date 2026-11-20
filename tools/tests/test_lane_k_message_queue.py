"""Lorelei/Bruno clips: the battle queue moves on the confirm press.

pret/pokered af519899 home/print_text.asm PrintLetterDelay reveals the
line, then home/joypad.asm WaitForTextScrollButtonPress consumes one new
A for that page. BattleScene:handleInput calls battle:handleInput on the
same A that finishes the dialog, and syncMessage installs the next say
before draw. The finished line does not stay up.
"""

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/lane_k_message_queue_host.lua"


class MessageQueueTests(unittest.TestCase):
    def test_confirm_does_not_install_the_next_say(self):
        completed = subprocess.run(
            ["lua5.4", str(HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("queue-held", completed.stdout)


if __name__ == "__main__":
    unittest.main()
