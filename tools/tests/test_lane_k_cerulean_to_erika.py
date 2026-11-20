#!/usr/bin/env python3
"""Cerulean (0, 18) reaches Erika on the installed grids.

pret/pokered af519899. The east road is a separate component until the
tree at (19, 28). Route 9, Celadon, and the gym trees are the same kind
of cut. The walk below is the line in lane-k-cerulean-to-erika.md.
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
DELTA = {"up": (0, -1), "down": (0, 1), "left": (-1, 0), "right": (1, 0)}
WORD = {"up": "north", "down": "south", "left": "west", "right": "east"}
FACING = {
    "UP": (0, -1), "DOWN": (0, 1), "LEFT": (-1, 0), "RIGHT": (1, 0),
    "SPRITE_FACING_UP": (0, -1), "SPRITE_FACING_DOWN": (0, 1),
    "SPRITE_FACING_LEFT": (-1, 0), "SPRITE_FACING_RIGHT": (1, 0),
}
MAP_FILES = {
    "CeruleanCity": "data/sourceSlice/CeruleanCity.json",
    "Route9": "data/midgameEast/Route9.json",
    "Route10": "data/midgameEast/Route10.json",
    "CeladonCity": "data/midgameEast/CeladonCity.json",
    "CeladonGym": "data/midgameEast/CeladonGym.json",
}
POKERED_MAPS = {
    "CeruleanCity": ("CERULEAN_CITY", "maps/CeruleanCity.blk", "overworld.bst", "Overworld_Coll"),
    "Route9": ("ROUTE_9", "maps/Route9.blk", "overworld.bst", "Overworld_Coll"),
    "Route10": ("ROUTE_10", "maps/Route10.blk", "overworld.bst", "Overworld_Coll"),
    "CeladonCity": ("CELADON_CITY", "maps/CeladonCity.blk", "overworld.bst", "Overworld_Coll"),
    "CeladonGym": ("CELADON_GYM", "maps/CeladonGym.blk", "gym.bst", "Gym_Coll"),
}
TREES = (
    ("CeruleanCity", (19, 28), 0x3D, 0x32, 0x6D),
    ("Route9", (5, 8), 0x3D, 0x35, 0x4C),
    ("CeladonCity", (35, 32), 0x3D, 0x32, 0x6D),
    ("CeladonGym", (2, 4), 0x50, 0x3C, 0x35),
    ("CeladonGym", (7, 5), 0x50, 0x3D, 0x36),
    ("CeladonGym", (5, 7), 0x50, 0x3F, 0x35),
)
FIGHTS = (
    "pokered:ROUTE_9:objects:1",
    "pokered:ROUTE_9:objects:9",
    "pokered:ROCK_TUNNEL_B1F:objects:6",
    "pokered:ROCK_TUNNEL_B1F:objects:1",
    "pokered:ROCK_TUNNEL_B1F:objects:2",
    "pokered:ROUTE_8:objects:9",
    "pokered:CELADON_GYM:objects:7",
)
START = ("CeruleanCity", 0, 18)

STEPS = [
    ('walk', 'down', 1, 'CeruleanCity', 0, 19),
    ('walk', 'right', 5, 'CeruleanCity', 5, 19),
    ('walk', 'down', 7, 'CeruleanCity', 5, 26),
    ('walk', 'right', 5, 'CeruleanCity', 10, 26),
    ('walk', 'down', 1, 'CeruleanCity', 10, 27),
    ('walk', 'right', 9, 'CeruleanCity', 19, 27),
    ('cut', 'down', 19, 28, 'CeruleanCity', 19, 27),
    ('walk', 'down', 2, 'CeruleanCity', 19, 29),
    ('walk', 'right', 17, 'CeruleanCity', 36, 29),
    ('walk', 'up', 12, 'CeruleanCity', 36, 17),
    ('walk', 'right', 3, 'CeruleanCity', 39, 17),
    ('conn', 'right', 'Route9', 0, 9),
    ('walk', 'up', 1, 'Route9', 0, 8),
    ('walk', 'right', 4, 'Route9', 4, 8),
    ('cut', 'right', 5, 8, 'Route9', 4, 8),
    ('walk', 'right', 1, 'Route9', 5, 8),
    ('walk', 'down', 1, 'Route9', 5, 9),
    ('walk', 'right', 5, 'Route9', 10, 9),
    ('fight', 'down', 'Route9', 10, 10, 'pokered:ROUTE_9:objects:1'),
    ('ledge', 'down', 'Route9', 10, 12),
    ('walk', 'right', 10, 'Route9', 20, 12),
    ('walk', 'up', 1, 'Route9', 20, 11),
    ('walk', 'right', 8, 'Route9', 28, 11),
    ('walk', 'down', 1, 'Route9', 28, 12),
    ('walk', 'right', 13, 'Route9', 41, 12),
    ('walk', 'up', 3, 'Route9', 41, 9),
    ('fight', 'up', 'Route9', 41, 8, 'pokered:ROUTE_9:objects:9'),
    ('walk', 'up', 1, 'Route9', 41, 7),
    ('walk', 'left', 2, 'Route9', 39, 7),
    ('walk', 'up', 3, 'Route9', 39, 4),
    ('walk', 'right', 5, 'Route9', 44, 4),
    ('walk', 'up', 1, 'Route9', 44, 3),
    ('walk', 'right', 6, 'Route9', 50, 3),
    ('walk', 'down', 1, 'Route9', 50, 4),
    ('ledge', 'down', 'Route9', 50, 6),
    ('walk', 'down', 1, 'Route9', 50, 7),
    ('walk', 'right', 1, 'Route9', 51, 7),
    ('walk', 'down', 1, 'Route9', 51, 8),
    ('walk', 'right', 8, 'Route9', 59, 8),
    ('conn', 'right', 'Route10', 0, 8),
    ('walk', 'down', 1, 'Route10', 0, 9),
    ('walk', 'right', 2, 'Route10', 2, 9),
    ('walk', 'down', 1, 'Route10', 2, 10),
    ('ledge', 'down', 'Route10', 2, 12),
    ('walk', 'down', 1, 'Route10', 2, 13),
    ('walk', 'right', 8, 'Route10', 10, 13),
    ('walk', 'down', 2, 'Route10', 10, 15),
    ('walk', 'right', 4, 'Route10', 14, 15),
    ('walk', 'down', 5, 'Route10', 14, 20),
    ('walk', 'left', 3, 'Route10', 11, 20),
    ('warp', 'RockTunnelPokecenter', 3, 7),
    ('walk', 'up', 4, 'RockTunnelPokecenter', 3, 3),
    ('walk', 'down', 3, 'RockTunnelPokecenter', 3, 6),
    ('warp', 'Route10', 11, 20),
    ('walk', 'left', 1, 'Route10', 10, 20),
    ('walk', 'down', 5, 'Route10', 10, 25),
    ('walk', 'left', 1, 'Route10', 9, 25),
    ('walk', 'down', 1, 'Route10', 9, 26),
    ('walk', 'left', 6, 'Route10', 3, 26),
    ('walk', 'up', 8, 'Route10', 3, 18),
    ('walk', 'right', 5, 'Route10', 8, 18),
    ('warp', 'RockTunnel1F', 15, 3),
    ('walk', 'down', 4, 'RockTunnel1F', 15, 7),
    ('walk', 'right', 16, 'RockTunnel1F', 31, 7),
    ('walk', 'down', 1, 'RockTunnel1F', 31, 8),
    ('walk', 'right', 3, 'RockTunnel1F', 34, 8),
    ('walk', 'up', 5, 'RockTunnel1F', 34, 3),
    ('walk', 'right', 2, 'RockTunnel1F', 36, 3),
    ('warp', 'RockTunnelB1F', 33, 25),
    ('walk', 'left', 5, 'RockTunnelB1F', 28, 25),
    ('walk', 'down', 5, 'RockTunnelB1F', 28, 30),
    ('walk', 'left', 1, 'RockTunnelB1F', 27, 30),
    ('walk', 'down', 4, 'RockTunnelB1F', 27, 34),
    ('walk', 'left', 2, 'RockTunnelB1F', 25, 34),
    ('walk', 'up', 1, 'RockTunnelB1F', 25, 33),
    ('walk', 'left', 8, 'RockTunnelB1F', 17, 33),
    ('walk', 'up', 4, 'RockTunnelB1F', 17, 29),
    ('fight', 'up', 'RockTunnelB1F', 17, 28, 'pokered:ROCK_TUNNEL_B1F:objects:6'),
    ('walk', 'up', 4, 'RockTunnelB1F', 17, 24),
    ('walk', 'right', 3, 'RockTunnelB1F', 20, 24),
    ('walk', 'up', 2, 'RockTunnelB1F', 20, 22),
    ('walk', 'left', 3, 'RockTunnelB1F', 17, 22),
    ('walk', 'up', 1, 'RockTunnelB1F', 17, 21),
    ('walk', 'left', 3, 'RockTunnelB1F', 14, 21),
    ('walk', 'up', 3, 'RockTunnelB1F', 14, 18),
    ('walk', 'left', 1, 'RockTunnelB1F', 13, 18),
    ('walk', 'up', 1, 'RockTunnelB1F', 13, 17),
    ('walk', 'left', 1, 'RockTunnelB1F', 12, 17),
    ('fight', 'left', 'RockTunnelB1F', 11, 17, 'pokered:ROCK_TUNNEL_B1F:objects:1'),
    ('walk', 'left', 3, 'RockTunnelB1F', 8, 17),
    ('walk', 'up', 1, 'RockTunnelB1F', 8, 16),
    ('walk', 'left', 1, 'RockTunnelB1F', 7, 16),
    ('walk', 'up', 3, 'RockTunnelB1F', 7, 13),
    ('fight', 'left', 'RockTunnelB1F', 6, 13, 'pokered:ROCK_TUNNEL_B1F:objects:2'),
    ('walk', 'left', 2, 'RockTunnelB1F', 4, 13),
    ('walk', 'up', 9, 'RockTunnelB1F', 4, 4),
    ('walk', 'left', 1, 'RockTunnelB1F', 3, 4),
    ('warp', 'RockTunnel1F', 37, 17),
    ('walk', 'left', 5, 'RockTunnel1F', 32, 17),
    ('walk', 'down', 6, 'RockTunnel1F', 32, 23),
    ('walk', 'right', 5, 'RockTunnel1F', 37, 23),
    ('walk', 'down', 2, 'RockTunnel1F', 37, 25),
    ('walk', 'left', 5, 'RockTunnel1F', 32, 25),
    ('walk', 'down', 3, 'RockTunnel1F', 32, 28),
    ('walk', 'left', 6, 'RockTunnel1F', 26, 28),
    ('walk', 'up', 1, 'RockTunnel1F', 26, 27),
    ('walk', 'left', 3, 'RockTunnel1F', 23, 27),
    ('walk', 'down', 2, 'RockTunnel1F', 23, 29),
    ('walk', 'left', 2, 'RockTunnel1F', 21, 29),
    ('walk', 'up', 2, 'RockTunnel1F', 21, 27),
    ('walk', 'left', 6, 'RockTunnel1F', 15, 27),
    ('walk', 'down', 5, 'RockTunnel1F', 15, 32),
    ('warp', 'Route10', 8, 54),
    ('walk', 'right', 2, 'Route10', 10, 54),
    ('walk', 'down', 1, 'Route10', 10, 55),
    ('walk', 'right', 4, 'Route10', 14, 55),
    ('walk', 'down', 1, 'Route10', 14, 56),
    ('ledge', 'down', 'Route10', 14, 58),
    ('walk', 'down', 2, 'Route10', 14, 60),
    ('ledge', 'down', 'Route10', 14, 62),
    ('walk', 'down', 1, 'Route10', 14, 63),
    ('walk', 'right', 1, 'Route10', 15, 63),
    ('walk', 'down', 2, 'Route10', 15, 65),
    ('walk', 'left', 5, 'Route10', 10, 65),
    ('walk', 'down', 1, 'Route10', 10, 66),
    ('ledge', 'down', 'Route10', 10, 68),
    ('walk', 'left', 1, 'Route10', 9, 68),
    ('walk', 'down', 3, 'Route10', 9, 71),
    ('conn', 'down', 'LavenderTown', 9, 0),
    ('walk', 'left', 3, 'LavenderTown', 6, 0),
    ('walk', 'down', 6, 'LavenderTown', 6, 6),
    ('walk', 'left', 3, 'LavenderTown', 3, 6),
    ('warp', 'LavenderPokecenter', 3, 7),
    ('walk', 'up', 4, 'LavenderPokecenter', 3, 3),
    ('walk', 'down', 3, 'LavenderPokecenter', 3, 6),
    ('warp', 'LavenderTown', 3, 6),
    ('walk', 'left', 3, 'LavenderTown', 0, 6),
    ('walk', 'down', 2, 'LavenderTown', 0, 8),
    ('conn', 'left', 'Route8', 59, 8),
    ('walk', 'left', 7, 'Route8', 52, 8),
    ('walk', 'down', 5, 'Route8', 52, 13),
    ('walk', 'left', 5, 'Route8', 47, 13),
    ('fight', 'up', 'Route8', 47, 12, 'pokered:ROUTE_8:objects:9'),
    ('walk', 'left', 5, 'Route8', 42, 12),
    ('walk', 'up', 3, 'Route8', 42, 9),
    ('walk', 'left', 1, 'Route8', 41, 9),
    ('walk', 'up', 2, 'Route8', 41, 7),
    ('walk', 'left', 1, 'Route8', 40, 7),
    ('walk', 'up', 1, 'Route8', 40, 6),
    ('walk', 'left', 11, 'Route8', 29, 6),
    ('walk', 'down', 1, 'Route8', 29, 7),
    ('walk', 'left', 6, 'Route8', 23, 7),
    ('walk', 'down', 3, 'Route8', 23, 10),
    ('walk', 'left', 1, 'Route8', 22, 10),
    ('walk', 'down', 2, 'Route8', 22, 12),
    ('walk', 'left', 8, 'Route8', 14, 12),
    ('walk', 'up', 8, 'Route8', 14, 4),
    ('walk', 'left', 1, 'Route8', 13, 4),
    ('warp', 'UndergroundPathRoute8', 5, 7),
    ('walk', 'up', 2, 'UndergroundPathRoute8', 5, 5),
    ('walk', 'right', 1, 'UndergroundPathRoute8', 6, 5),
    ('warp', 'UndergroundPathWestEast', 47, 2),
    ('walk', 'left', 45, 'UndergroundPathWestEast', 2, 2),
    ('walk', 'down', 2, 'UndergroundPathWestEast', 2, 4),
    ('warp', 'UndergroundPathRoute7', 6, 4),
    ('walk', 'down', 2, 'UndergroundPathRoute7', 6, 6),
    ('warp', 'Route7', 5, 14),
    ('walk', 'right', 3, 'Route7', 8, 14),
    ('walk', 'up', 5, 'Route7', 8, 9),
    ('walk', 'left', 4, 'Route7', 4, 9),
    ('walk', 'up', 3, 'Route7', 4, 6),
    ('walk', 'left', 2, 'Route7', 2, 6),
    ('walk', 'up', 3, 'Route7', 2, 3),
    ('walk', 'left', 2, 'Route7', 0, 3),
    ('conn', 'left', 'CeladonCity', 49, 11),
    ('walk', 'left', 8, 'CeladonCity', 41, 11),
    ('walk', 'up', 1, 'CeladonCity', 41, 10),
    ('warp', 'CeladonPokecenter', 3, 7),
    ('walk', 'up', 4, 'CeladonPokecenter', 3, 3),
    ('walk', 'down', 3, 'CeladonPokecenter', 3, 6),
    ('warp', 'CeladonCity', 41, 10),
    ('walk', 'left', 5, 'CeladonCity', 36, 10),
    ('walk', 'down', 12, 'CeladonCity', 36, 22),
    ('walk', 'left', 10, 'CeladonCity', 26, 22),
    ('walk', 'down', 1, 'CeladonCity', 26, 23),
    ('walk', 'left', 1, 'CeladonCity', 25, 23),
    ('walk', 'down', 8, 'CeladonCity', 25, 31),
    ('walk', 'right', 10, 'CeladonCity', 35, 31),
    ('cut', 'down', 35, 32, 'CeladonCity', 35, 31),
    ('walk', 'down', 3, 'CeladonCity', 35, 34),
    ('walk', 'left', 30, 'CeladonCity', 5, 34),
    ('walk', 'up', 5, 'CeladonCity', 5, 29),
    ('walk', 'right', 7, 'CeladonCity', 12, 29),
    ('walk', 'up', 1, 'CeladonCity', 12, 28),
    ('warp', 'CeladonGym', 5, 17),
    ('walk', 'left', 3, 'CeladonGym', 2, 17),
    ('walk', 'up', 7, 'CeladonGym', 2, 10),
    ('walk', 'left', 1, 'CeladonGym', 1, 10),
    ('walk', 'up', 6, 'CeladonGym', 1, 4),
    ('walk', 'right', 1, 'CeladonGym', 2, 4),
    ('cut', 'right', 3, 4, 'CeladonGym', 2, 4),
    ('walk', 'right', 1, 'CeladonGym', 3, 4),
    ('fight', 'right', 'CeladonGym', 4, 4, 'pokered:CELADON_GYM:objects:7'),
    ('walk', 'right', 1, 'CeladonGym', 5, 4)
]


def reference():
    raw = os.environ.get("POKERED_REFERENCE_DIR")
    if not raw:
        raise RuntimeError("POKERED_REFERENCE_DIR is required")
    path = Path(raw)
    if not path.is_dir():
        raise RuntimeError("POKERED_REFERENCE_DIR is not a directory")
    return path


def load_compact():
    return json.loads((ROOT / "Source/data/sourceMapCache/compact.json").read_text(encoding="utf-8"))


class Board:
    def __init__(self, compact, name):
        meta = compact["maps"][name]
        tiles = compact["tiles"]
        self.name = name
        self.w = meta["width"]
        self.h = meta["height"]
        self.pad = meta["padding"]
        self.source_width = meta["source_width"]
        self.meta = meta
        self.foot = [[0] * self.w for _ in range(self.h)]
        self.solid = [[False] * self.w for _ in range(self.h)]
        blocked = {int(key) for key in meta["blocked"]}
        for y, row in enumerate(meta["tile_rows"]):
            for x in range(self.w):
                tid = int(row[x * 2:x * 2 + 2], 16)
                cell = tiles[meta["palette"][tid - 1]]
                self.foot[y][x] = cell["terrain"]["foot_tile"]
                self.solid[y][x] = cell["collision"] != 0 or (y * self.w + x + 1) in blocked
        src = json.loads((ROOT / "Source" / MAP_FILES.get(name, "")).read_text(encoding="utf-8")) if name in MAP_FILES else None
        self.ledges = []
        if src and src.get("directional_rules"):
            for rule in src["directional_rules"]["ledges"]:
                self.ledges.append((FACING[rule["facing"]], rule["standing_foot_tile"], rule["target_foot_tile"]))
        else:
            path = {
                "RockTunnelPokecenter": "data/midgameEast/RockTunnelPokecenter.json",
                "RockTunnel1F": "data/midgameEast/RockTunnel1F.json",
                "RockTunnelB1F": "data/midgameEast/RockTunnelB1F.json",
                "LavenderTown": "data/midgameEast/LavenderTown.json",
                "LavenderPokecenter": "data/midgameEast/LavenderPokecenter.json",
                "Route8": "data/midgameEast/Route8.json",
                "UndergroundPathRoute8": "data/midgameEast/UndergroundPathRoute8.json",
                "UndergroundPathWestEast": "data/midgameEast/UndergroundPathWestEast.json",
                "UndergroundPathRoute7": "data/midgameEast/UndergroundPathRoute7.json",
                "Route7": "data/midgameEast/Route7.json",
                "CeladonPokecenter": "data/midgameEast/CeladonPokecenter.json",
            }[name]
            src = json.loads((ROOT / "Source" / path).read_text(encoding="utf-8"))
            for rule in src.get("directional_rules", {}).get("ledges", []):
                self.ledges.append((FACING[rule["facing"]], rule["standing_foot_tile"], rule["target_foot_tile"]))
        self.npcs = {(obj["x"] + self.pad, obj["y"]) for obj in src["events"]["objects"]}
        self.warps = {(warp["x"], warp["y"]): warp for warp in meta["warps"]}
        self.cuts = set()
        index = json.loads((ROOT / "Source/data/fieldMoveIndex.json").read_text(encoding="utf-8"))
        record = index["maps"].get(meta["id"])
        self.targets = []
        if record:
            sites = json.loads((ROOT / "Source" / record["path"]).read_text(encoding="utf-8"))["record"]["sites"]
            for site in sites:
                for target in site["targets"]:
                    self.targets.append((target["x"] + self.pad, target["y"], site["block"], site["replacement"]))

    def is_solid(self, x, y):
        if (x, y) in self.cuts:
            return False
        return self.solid[y][x]

    def foot_at(self, x, y):
        if (x, y) in self.cuts:
            return 0x2C if self.meta["tileset"]["constant"] != "GYM" else 0x2B
        return self.foot[y][x]

    def landing(self, x, y, dx, dy):
        stand = self.foot_at(x, y)
        nx, ny = x + dx, y + dy
        if not (0 <= nx < self.w and 0 <= ny < self.h):
            return None
        front = self.foot_at(nx, ny)
        for (ldx, ldy), need_s, need_f in self.ledges:
            if (ldx, ldy) == (dx, dy) and stand == need_s and front == need_f:
                lx, ly = x + 2 * dx, y + 2 * dy
                if 0 <= lx < self.w and 0 <= ly < self.h and not self.is_solid(lx, ly):
                    return lx, ly
        return None


def trainers_for(compact):
    found = {name: [] for name in compact["maps"]}
    cache = ROOT / "Source/data/contentCache"
    for package in cache.glob("package-*-trainers-trainers.json"):
        for ident, digest in json.loads(package.read_text(encoding="utf-8"))["records"].items():
            rec = json.loads((cache / "chunks-v2" / digest[:2] / f"{digest}.json").read_text(encoding="utf-8"))
            const = rec["map_id"].split(":", 1)[1]
            name = next(n for n, meta in compact["maps"].items() if meta["source_map_constant"] == const)
            found[name].append(rec)
    return found


def sees(board, trainer, x, y, defeated):
    if trainer["talk_only"] or trainer["sight_range_cells"] <= 0 or trainer["id"] in defeated:
        return False
    dx, dy = x - (trainer["x"] + board.pad), y - trainer["y"]
    vx, vy = FACING[trainer["facing_source"]]
    dist = abs(dx) + abs(dy)
    if dist < 1 or dist > trainer["sight_range_cells"] or (dx, dy) != (vx * dist, vy * dist):
        return False
    for step in range(1, dist):
        cx = trainer["x"] + board.pad + vx * step
        cy = trainer["y"] + vy * step
        if board.is_solid(cx, cy) or (cx, cy) in board.npcs:
            return False
        px = trainer["x"] + board.pad + vx * (step - 1)
        py = trainer["y"] + vy * (step - 1)
        if board.landing(px, py, vx, vy):
            return False
    return True


def watchers(board, roster, x, y, defeated):
    return [rec for rec in roster if sees(board, rec, x, y, defeated)]


def arrival(boards, target, warp_index, doors):
    board = boards[target]
    warp = board.meta["warps"][warp_index - 1]
    x, y = warp["x"], warp["y"]
    door = board.foot[y][x] in doors.get(board.meta["tileset"]["constant"], ())
    advance = 0
    if door and y + 1 < board.h and not board.is_solid(x, y + 1):
        advance = 1
    return x, y + advance


def connection(boards, name, x, y, direction):
    meta = boards[name].meta
    vertical = direction in ("up", "down")
    boundary = (
        (direction == "up" and y == 0) or (direction == "down" and y == meta["height"] - 1)
        or (direction == "left" and x == 0) or (direction == "right" and x == meta["width"] - 1)
    )
    if not boundary:
        return None
    word = WORD[direction]
    for conn in meta["connections"]:
        if conn["direction"] != word:
            continue
        if f"{word}:{conn['target_map']}" in meta["blocked_connections"]:
            return None
        target = next(n for n, m in boards.items() if m.meta["source_map_constant"] == conn["target_map"])
        other = boards[target].meta
        adj = conn["entry_lateral_adjustment_cells"]
        if vertical:
            tx = x - meta["padding"] + adj + other["padding"]
            ty = other["height"] - 1 if direction == "up" else 0
        else:
            tx = other["width"] - other["padding"] - 1 if direction == "left" else other["padding"]
            ty = y + adj
        if not (other["padding"] <= tx < other["padding"] + other["source_width"] and 0 <= ty < other["height"]):
            return None
        return target, tx, ty
    return None


class CeruleanToErikaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ref = reference()
        revision = subprocess.check_output(
            ["git", "-C", str(cls.ref), "rev-parse", "HEAD"], text=True).strip()
        if revision != REVISION:
            raise AssertionError(revision)
        cls.compact = load_compact()
        names = {START[0]}
        for step in STEPS:
            kind = step[0]
            if kind == "walk":
                names.add(step[3])
            elif kind in ("fight", "ledge", "conn"):
                names.add(step[2])
            elif kind == "cut":
                names.add(step[4])
            elif kind == "warp":
                names.add(step[1])
            else:
                raise AssertionError(kind)
        cls.boards = {name: Board(cls.compact, name) for name in names}
        cls.roster = trainers_for(cls.compact)
        cls.doors = {key: set(value) for key, value in cls.compact["door_tiles"].items()}
        cls.constants = (cls.ref / "constants/map_constants.asm").read_text(encoding="utf-8")
        cls.collision_text = (cls.ref / "data/tilesets/collision_tile_ids.asm").read_text(encoding="utf-8")
        cls.swaps = (cls.ref / "data/tilesets/cut_tree_blocks.asm").read_text(encoding="utf-8")

    def test_notes_name_the_cut_and_the_erika_cell(self):
        text = (ROOT / "docs/validation/lane-k-cerulean-to-erika.md").read_text(encoding="utf-8")
        for needle in ("(0, 18)", "(19, 28)", "(5, 8)", "(35, 32)", "(3, 4)", "(8, 5)", "(6, 7)", "(5, 4)"):
            self.assertIn(needle, text)

    def test_pokered_trees_and_feet_match_the_installed_maps(self):
        pairs = [(int(a, 16), int(b, 16)) for a, b in __import__("re").findall(
            r"db\s+\$([0-9A-Fa-f]+),\s+\$([0-9A-Fa-f]+)", self.swaps)]
        self.assertIn((0x32, 0x6D), pairs)
        self.assertIn((0x35, 0x4C), pairs)
        self.assertIn((0x3C, 0x35), pairs)
        self.assertIn((0x3D, 0x36), pairs)
        self.assertIn((0x3F, 0x35), pairs)
        gym_allowed = route4.coll_set(self.collision_text, "Gym_Coll")
        self.assertIn(0x2B, gym_allowed)
        self.assertNotIn(0x50, gym_allowed)
        overworld_allowed = route4.coll_set(self.collision_text, "Overworld_Coll")
        self.assertIn(0x2C, overworld_allowed)
        self.assertNotIn(0x3D, overworld_allowed)
        for name, (const, blk, bst, label) in POKERED_MAPS.items():
            width, height = route4.map_blocks(self.constants, const)
            feet = route4.feet_from_blocks(
                (self.ref / blk).read_bytes(), (self.ref / "gfx/blocksets" / bst).read_bytes(), width, height)
            allowed = route4.coll_set(self.collision_text, label)
            installed = json.loads((ROOT / "Source" / MAP_FILES[name]).read_text(encoding="utf-8"))
            self.assertEqual(installed["source_revision"], REVISION)
            mismatches = []
            for y, row in enumerate(feet):
                for x, foot in enumerate(row):
                    grid = installed["grids"][installed["tile_ids"][y][x] - 1]
                    committed = grid["source_tile_ids"][2]
                    collision = installed["collision"][y][x]
                    if committed != foot or collision != (0 if foot in allowed else 1):
                        mismatches.append((x, y, foot, committed, collision))
            self.assertEqual(mismatches, [])
        blocks = {}
        for name, (const, blk, _bst, _label) in POKERED_MAPS.items():
            width, _height = route4.map_blocks(self.constants, const)
            blocks[name] = ((self.ref / blk).read_bytes(), width)
        for name, (x, y), foot, block, replacement in TREES:
            data, width = blocks[name]
            self.assertEqual(data[(y // 2) * width + (x // 2)], block)
            self.assertIn((block, replacement), pairs)
            installed = json.loads((ROOT / "Source" / MAP_FILES[name]).read_text(encoding="utf-8"))
            grid = installed["grids"][installed["tile_ids"][y][x] - 1]
            self.assertEqual(grid["source_tile_ids"][2], foot)

    def test_cerulean_east_road_opens_only_after_the_cut(self):
        board = self.boards["CeruleanCity"]
        self.assertIn((19, 28, 50, 109), [(x, y, b, r) for x, y, b, r in board.targets])

        def reach(opened):
            board.cuts = {(19, 28)} if opened else set()
            seen = {(0, 18)}
            pile = [(0, 18)]
            while pile:
                x, y = pile.pop()
                for dx, dy in DELTA.values():
                    jump = board.landing(x, y, dx, dy)
                    if jump:
                        nxt = [jump]
                    else:
                        nx, ny = x + dx, y + dy
                        nxt = [(nx, ny)] if 0 <= nx < board.w and 0 <= ny < board.h and not board.is_solid(nx, ny) else []
                    for cell in nxt:
                        if cell not in seen:
                            seen.add(cell)
                            pile.append(cell)
            board.cuts = set()
            return seen

        closed = reach(False)
        opened = reach(True)
        self.assertNotIn((39, 17), closed)
        self.assertNotIn((39, 16), closed)
        self.assertIn((39, 17), opened)
        self.assertIn((19, 28), opened)

    def test_walk_reaches_erika_on_seven_sight_cells(self):
        boards = self.boards
        pos = START
        defeated = set()
        fought = []
        opened = {name: set() for name in boards}
        for step in STEPS:
            name, x, y = pos
            board = boards[name]
            board.cuts = opened[name]
            kind = step[0]
            if kind in ("walk", "fight"):
                direction = step[1]
                count = 1 if kind == "fight" else step[2]
                dx, dy = DELTA[direction]
                for _ in range(count):
                    self.assertIsNone(board.landing(x, y, dx, dy), (pos, direction))
                    nx, ny = x + dx, y + dy
                    self.assertTrue(0 <= nx < board.w and 0 <= ny < board.h, (pos, direction))
                    self.assertFalse(board.is_solid(nx, ny), (name, nx, ny))
                    self.assertNotIn((nx, ny), board.npcs, (name, nx, ny))
                    self.assertNotIn((nx, ny), board.warps, (name, nx, ny))
                    seen = watchers(board, self.roster[name], nx, ny, defeated)
                    if kind == "fight" :
                        self.assertEqual([rec["id"] for rec in seen], [step[5]], (nx, ny))
                        defeated.add(step[5])
                        fought.append(step[5])
                    else:
                        self.assertEqual(seen, [], (name, nx, ny, [rec["id"] for rec in seen]))
                    x, y = nx, ny
                expect = (step[2], step[3], step[4]) if kind == "fight" else (step[3], step[4], step[5])
                self.assertEqual((name, x, y), expect)
                pos = (name, x, y)
            elif kind == "ledge":
                dx, dy = DELTA[step[1]]
                landing = board.landing(x, y, dx, dy)
                self.assertEqual(landing, (step[3], step[4]))
                seen = watchers(board, self.roster[name], landing[0], landing[1], defeated)
                self.assertEqual(seen, [])
                pos = (name, landing[0], landing[1])
            elif kind == "cut":
                tx, ty = step[2], step[3]
                dx, dy = DELTA[step[1]]
                self.assertEqual((x + dx, y + dy), (tx, ty))
                self.assertIn((tx, ty), {(a, b) for a, b, _block, _repl in board.targets})
                self.assertTrue(board.solid[ty][tx])
                opened[name].add((tx, ty))
                self.assertEqual((step[4], step[5], step[6]), pos)
            elif kind == "conn":
                linked = connection(boards, name, x, y, step[1])
                self.assertEqual(linked, (step[2], step[3], step[4]))
                dest = boards[linked[0]]
                dest.cuts = opened[linked[0]]
                self.assertFalse(dest.is_solid(linked[1], linked[2]))
                pos = linked
            elif kind == "warp":
                options = []
                for dx, dy in DELTA.values():
                    nx, ny = x + dx, y + dy
                    warp = board.warps.get((nx, ny))
                    if not warp:
                        continue
                    dest_meta = warp["destination"]
                    if dest_meta["kind"] == "last_outdoor_map":
                        target = board.meta["last_outdoor"]
                    else:
                        target = next(n for n, b in boards.items()
                                      if b.meta["source_map_constant"] == dest_meta["map"])
                    landed = arrival(boards, target, dest_meta["warp_index"], self.doors)
                    options.append((target, landed[0], landed[1]))
                self.assertIn((step[1], step[2], step[3]), options, options)
                pos = (step[1], step[2], step[3])
            else:
                self.fail(kind)
        self.assertEqual(tuple(fought), FIGHTS)
        self.assertEqual(pos, ("CeladonGym", 5, 4))
        gym = boards["CeladonGym"]
        erika = next(rec for rec in self.roster["CeladonGym"] if rec["talk_only"])
        self.assertEqual((erika["x"] + gym.pad, erika["y"]), (5, 3))
        self.assertEqual(watchers(gym, self.roster["CeladonGym"], 5, 4, defeated), [])
        self.assertEqual(opened["CeladonGym"], {(3, 4)})
        self.assertTrue(gym.solid[5][8])
        self.assertTrue(gym.solid[7][6])
        for center in ("RockTunnelPokecenter", "LavenderPokecenter", "CeladonPokecenter"):
            self.assertIn(("walk", "up", 4, center, 3, 3), STEPS)


if __name__ == "__main__":
    unittest.main()
