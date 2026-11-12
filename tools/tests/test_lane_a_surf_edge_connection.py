#!/usr/bin/env python3
"""Lane A: a surfing water edge is not a blocked origin.

KantoWorld.connection returns blocked-origin for every collision ~= 0 cell
before it asks for a source connection. Route 19 (0, 40) facing left is
foot $14 on both banks. A surfing step there is the Route 20 door at
(99, 4). A walking step on that cell stays blocked.

The fix is tools/notes/lane-a-surf-edge.patch. It does not belong in this
branch: kantoWorld.lua is shared. CoastStoryWorld still answers the door
for the earned save until this patch lands in the shared function. This
test fails until that call sits above the blocked-origin return.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'Source/game/kantoWorld.lua'


def connection_body(source):
    start = source.index('function KantoWorld.connection')
    rest = source[start:]
    return rest[:rest.index('\nfunction ')]


class SurfEdgeConnectionTest(unittest.TestCase):
    def test_surfing_water_edge_is_checked_before_blocked_origin(self):
        body = connection_body(SOURCE.read_text())
        blocked = body.index('return nil,"blocked-origin"')
        head = body[:blocked]
        self.assertTrue(
            'surfingWaterDoor' in head,
            'A surfing foot-$14 edge is rejected as blocked-origin. '
            'Apply tools/notes/lane-a-surf-edge.patch ahead of that return.',
        )


if __name__ == '__main__':
    unittest.main()
