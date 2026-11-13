#!/usr/bin/env python3
"""Saffron Gym's last teleporter is on the bottom row, so it never fires.

Session d42e783ef3cb4fba9aa067f6e02ed785 beat Sabrina. BADGE_MARSH and
TM46 were set in memory. The exit script then stepped east onto
SAFFRON_GYM warps:32 at (19, 17). That pad's destination is warps:20 at
(11, 15), the same room. The player stayed at (19, 17). The center save
after the badge never ran.

SourceBindings marks every interior warp on the last row as an edge door.
An edge door waits for a down press into the wall. pret/pokered
af519899719f0754965776faac0e836a3b906e6d fires a same-room warp on the
step that lands. The two outdoor exit mats stay edge doors. This test
fails until tools/notes/lane-e-saffron-gym-pad.patch is applied.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BINDINGS = ROOT / "Source/world/sourceBindings.lua"
PATCH = ROOT / "tools/notes/lane-e-saffron-gym-pad.patch"


def warp_loop(source):
    return source.split("for _, event in ipairs(d.events.warps) do", 1)[1].split(
        "for _, event in ipairs(d.events.background_events) do", 1)[0]


class SaffronGymPadTest(unittest.TestCase):
    def test_patch_keeps_same_room_pads_as_step_doors(self):
        patch = PATCH.read_text(encoding="utf-8")
        added = "\n".join(line[1:] for line in patch.splitlines() if line.startswith("+") and not line.startswith("+++"))
        self.assertIn(
            'local same_room = event.destination.kind == "map" and event.destination.map == d.source_map_constant',
            added)
        self.assertIn("and not same_room and \"down\" or nil", added)

    def test_bottom_row_same_room_warp_is_not_an_edge_door(self):
        body = warp_loop(BINDINGS.read_text(encoding="utf-8"))
        self.assertIn("not same_room", body, "Apply tools/notes/lane-e-saffron-gym-pad.patch")
        self.assertIn('event.destination.map == d.source_map_constant', body)
        self.assertNotIn(
            'edge = (viridian or interior) and event.y == height - 1 and "down" or nil',
            body)


if __name__ == "__main__":
    unittest.main()
