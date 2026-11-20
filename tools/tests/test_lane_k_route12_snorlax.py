#!/usr/bin/env python3
"""Route 11 cannot reach Lavender while Route 12's Snorlax is asleep.

pret/pokered af519899. The east connection adds 54, so Route 11's open east
edge lands on Route 12 at (0, 62), the same row as Snorlax (10, 62). The
Route 12 gate is north of that row. VermilionGym.asm does not roll the first
trash lock; VermilionCity.asm does, on map load.
"""

import json
import os
import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import test_lane_k_route4_exit as route4

ROOT = Path(__file__).resolve().parents[2]
REVISION = route4.REVISION
SNORLAX = (10, 62)
GATE_SOUTH = (10, 21)
GATE_NORTH = ((10, 15), (11, 15))


def reference():
    raw = os.environ.get("POKERED_REFERENCE_DIR")
    if not raw:
        raise RuntimeError("POKERED_REFERENCE_DIR is required")
    path = Path(raw)
    if not path.is_dir():
        raise RuntimeError("POKERED_REFERENCE_DIR is not a directory")
    return path


def installed(path):
    return json.loads(path.read_text(encoding="utf-8"))


def feet_match(document, pokered, allowed):
    mismatches = []
    for y, row in enumerate(pokered):
        for x, foot in enumerate(row):
            grid = document["grids"][document["tile_ids"][y][x] - 1]
            committed = grid["source_tile_ids"][2]
            collision = document["collision"][y][x]
            if committed != foot or collision != (0 if foot in allowed else 1):
                mismatches.append((x, y, foot, committed, collision))
    return mismatches


def without(graph, blocked):
    return [edge for edge in graph
            if (edge[0], edge[1]) not in blocked and (edge[2], edge[3]) not in blocked]


def with_gate(graph):
    extra = list(graph)
    for landing in GATE_NORTH:
        extra.append((GATE_SOUTH[0], GATE_SOUTH[1], landing[0], landing[1]))
    return extra


class Route12SnorlaxTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        ref = reference()
        revision = subprocess.check_output(
            ["git", "-C", str(ref), "rev-parse", "HEAD"], text=True).strip()
        if revision != REVISION:
            raise AssertionError(revision)
        cls.ref = ref
        constants = (ref / "constants/map_constants.asm").read_text(encoding="utf-8")
        blockset = (ref / "gfx/blocksets/overworld.bst").read_bytes()
        cls.allowed = route4.coll_set(
            (ref / "data/tilesets/collision_tile_ids.asm").read_text(encoding="utf-8"),
            "Overworld_Coll")
        cls.rules = route4.ledge_rules(
            (ref / "data/tilesets/ledge_tiles.asm").read_text(encoding="utf-8"))
        cls.route11 = route4.feet_from_blocks(
            (ref / "maps/Route11.blk").read_bytes(), blockset,
            *route4.map_blocks(constants, "ROUTE_11"))
        cls.route12 = route4.feet_from_blocks(
            (ref / "maps/Route12.blk").read_bytes(), blockset,
            *route4.map_blocks(constants, "ROUTE_12"))

    def test_route11_stops_west_of_snorlax(self):
        route11 = installed(ROOT / "Source/data/vermilionPreparation/Route11.json")
        route12 = installed(ROOT / "Source/data/midgameSouth/Route12.json")
        compact = installed(ROOT / "Source/data/sourceMapCache/compact.json")
        self.assertEqual(feet_match(route11, self.route11, self.allowed), [])
        self.assertEqual(feet_match(route12, self.route12, self.allowed), [])
        self.assertEqual(route12["directional_rules"]["forbidden_tile_pairs"], [])
        self.assertEqual(
            [(rule["facing"], rule["standing_foot_tile"], rule["target_foot_tile"], rule["input"])
             for rule in route12["directional_rules"]["ledges"]],
            self.rules)
        east = compact["maps"]["Route11"]["connections"]
        self.assertEqual(
            [row for row in east if row["direction"] == "east"],
            [{
                "direction": "east",
                "entry_lateral_adjustment_cells": 54,
                "interpretation": "source macro entry adjustment; runtime traversal unresolved",
                "offset_blocks": -27,
                "target_header": "Route12",
                "target_map": "ROUTE_12",
            }])
        self.assertEqual(compact["maps"]["Route11"]["blocked_connections"], [])
        self.assertEqual(compact["maps"]["Route12"]["blocked_connections"], [])
        self.assertEqual(compact["maps"]["Route12"]["padding"], 0)
        formula = (ROOT / "Source/world/sourceMaps.lua").read_text(encoding="utf-8")
        self.assertIn("or y + adjustment", formula)
        width = len(self.route11[0])
        arrivals = [y for y in range(len(self.route11)) if self.route11[y][width - 1] in self.allowed]
        self.assertEqual(arrivals, [8, 9])
        self.assertIn(self.route12[62][0], self.allowed)
        self.assertNotIn(self.route12[63][0], self.allowed)
        self.assertEqual(route12["collision"][62][0], 0)
        self.assertEqual(route12["collision"][63][0], 1)

        pokered = route4.edges(self.route12, self.allowed, self.rules)
        committed_feet = [
            [route12["grids"][route12["tile_ids"][y][x] - 1]["source_tile_ids"][2]
             for x in range(len(self.route12[0]))]
            for y in range(len(self.route12))]
        committed = route4.edges(committed_feet, self.allowed, self.rules)
        self.assertEqual(pokered, committed)
        asleep = route4.reachable((0, 62), with_gate(without(pokered, {SNORLAX})))
        ours = route4.reachable((0, 62), with_gate(without(committed, {SNORLAX})))
        self.assertEqual(asleep, ours)
        self.assertNotIn(GATE_SOUTH, asleep)
        self.assertFalse(any(y == 0 for _x, y in asleep))
        self.assertTrue(all(61 <= y <= 63 for _x, y in asleep))
        awake = route4.reachable((0, 62), with_gate(pokered))
        self.assertIn(GATE_SOUTH, awake)
        self.assertTrue(any(y == 0 for _x, y in awake))

        objects = (self.ref / "data/maps/objects/Route12.asm").read_text(encoding="utf-8")
        self.assertEqual(route4.warps(objects), [
            (10, 15, "ROUTE_12_GATE_1F", 1),
            (11, 15, "ROUTE_12_GATE_1F", 2),
            (10, 21, "ROUTE_12_GATE_1F", 3),
            (11, 77, "ROUTE_12_SUPER_ROD_HOUSE", 1),
        ])
        self.assertIn("object_event 10, 62, SPRITE_SNORLAX, STAY, DOWN, TEXT_ROUTE12_SNORLAX", objects)
        self.assertEqual(
            [(warp["x"], warp["y"], warp["destination"]["map"], warp["destination"]["warp_index"])
             for warp in route12["events"]["warps"]],
            [(10, 15, "ROUTE_12_GATE_1F", 1), (11, 15, "ROUTE_12_GATE_1F", 2),
             (10, 21, "ROUTE_12_GATE_1F", 3), (11, 77, "ROUTE_12_SUPER_ROD_HOUSE", 1)])
        snorlax = route12["events"]["objects"][0]
        self.assertEqual((snorlax["sprite"], snorlax["x"], snorlax["y"], snorlax["movement"]),
                         ("SPRITE_SNORLAX", 10, 62, "STAY"))
        scenes = installed(ROOT / "Source/data/towerStory/scenes.json")["scenes"]["snorlax"][0]
        self.assertEqual((scenes["id"], scenes["x"], scenes["y"], scenes["defeated_flag"]),
                         ("pokered:ROUTE_12:objects:1", 10, 62, "EVENT_BEAT_ROUTE12_SNORLAX"))
        story = (ROOT / "Source/game/snorlaxStory.lua").read_text(encoding="utf-8")
        self.assertIn('id = definition.defeated_flag, equals = false', story)
        player = (ROOT / "Source/world/player.lua").read_text(encoding="utf-8")
        body = player.split("function Player:tryMove", 1)[1].split("\nfunction ", 1)[0]
        occupant = body.split("local occupant = self.npcManager:getNPCAt", 1)[1]
        self.assertIn("occupied-next-cell", occupant.split("startMove", 1)[0])
        self.assertIn("return", occupant.split("occupied-next-cell", 1)[1].split("self.boulderAttempt = nil", 1)[0])

    def test_gates_do_not_skip_snorlax(self):
        expected = {
            "Route12Gate1F": [
                (4, 0, "LAST_MAP", 1), (5, 0, "LAST_MAP", 2),
                (4, 7, "LAST_MAP", 3), (5, 7, "LAST_MAP", 3),
                (8, 6, "ROUTE_12_GATE_2F", 1),
            ],
            "Route12Gate2F": [(7, 7, "ROUTE_12_GATE_1F", 5)],
            "Route11Gate1F": [
                (0, 4, "LAST_MAP", 1), (0, 5, "LAST_MAP", 2),
                (7, 4, "LAST_MAP", 3), (7, 5, "LAST_MAP", 4),
                (6, 8, "ROUTE_11_GATE_2F", 1),
            ],
            "Route11Gate2F": [(7, 7, "ROUTE_11_GATE_1F", 5)],
        }
        installed_paths = {
            "Route12Gate1F": ROOT / "Source/data/midgameSouth/Route12Gate1F.json",
            "Route12Gate2F": ROOT / "Source/data/midgameSouth/Route12Gate2F.json",
            "Route11Gate1F": ROOT / "Source/data/vermilionPreparation/Route11Gate1F.json",
            "Route11Gate2F": ROOT / "Source/data/vermilionPreparation/Route11Gate2F.json",
        }
        for name, warps in expected.items():
            source = route4.warps(
                (self.ref / f"data/maps/objects/{name}.asm").read_text(encoding="utf-8"))
            document = installed(installed_paths[name])
            got = []
            for warp in document["events"]["warps"]:
                destination = warp["destination"]
                map_name = "LAST_MAP" if destination["kind"] == "last_outdoor_map" else destination["map"]
                got.append((warp["x"], warp["y"], map_name, destination["warp_index"]))
            self.assertEqual(source, warps, name)
            self.assertEqual(got, warps, name)
            self.assertFalse(any(dest in {"LAVENDER_TOWN", "ROCK_TUNNEL_1F", "ROCK_TUNNEL_B1F"}
                                 for _x, _y, dest, _index in warps))

    def test_first_lock_rolls_on_vermilion_city_not_the_gym(self):
        gym = (self.ref / "scripts/VermilionGym.asm").read_text(encoding="utf-8")
        city = (self.ref / "scripts/VermilionCity.asm").read_text(encoding="utf-8")
        self.assertNotIn("Random", gym)
        self.assertNotIn("wFirstLockTrashCanIndex", gym)
        self.assertIn("call nz, .LoadNames", gym)
        self.assertIn(".setFirstLockTrashCanIndex", city)
        self.assertIn("call Random", city)
        self.assertIn("ldh a, [hRandomSub]", city)
        self.assertIn("and $e", city)
        self.assertIn("ld [wFirstLockTrashCanIndex], a", city)
        hooks = (ROOT / "Source/game/vermilionStoryHooks.lua").read_text(encoding="utf-8")
        self.assertIn("currentZone.stableID == CITY and options and options.fromDoor", hooks)
        self.assertNotIn("currentZone.stableID == GYM and options", hooks)


if __name__ == "__main__":
    unittest.main()
