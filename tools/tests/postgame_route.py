"""Headless post-Hall-of-Fame walk from Pallet to Mewtwo and Zapdos.

Collision, ledges, warps, and map connections follow SourceMaps. Surf follows
FieldTravel.surfSurface and the sea-connection exception in PewterWorld: a
surfing step may enter a water tile whose land collision is 1. Seafoam is left
out. Its currents and strength boulders are not in the collision grid, so a
path through those floors would not be a real walk. Rock Tunnel's collision
grid is the walkable maze, so the Power Plant route may use it.
"""
import json
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Source"
WATER_TILESETS = {"OVERWORLD", "FOREST", "DOJO", "GYM", "SHIP", "SHIP_PORT", "CAVERN", "FACILITY", "PLATEAU"}
WATER_PAIRS = {("FOREST", 20, 46), ("FOREST", 72, 46), ("CAVERN", 20, 5)}
FACING = {"up": "SPRITE_FACING_UP", "down": "SPRITE_FACING_DOWN",
          "left": "SPRITE_FACING_LEFT", "right": "SPRITE_FACING_RIGHT"}
CARDINAL = {"up": "north", "down": "south", "left": "west", "right": "east"}
DELTAS = {"up": (0, -1), "down": (0, 1), "left": (-1, 0), "right": (1, 0)}
# A finished save has already resolved these actors. The path treats them as gone.
HIDDEN = {
    "pokered:CERULEAN_CITY:objects:1",   # rival, defeated
    "pokered:CERULEAN_CITY:objects:2",   # rocket thief, TOGGLE_CERULEAN_ROCKET
    "pokered:CERULEAN_CITY:objects:10",  # cave guard, TOGGLE_CERULEAN_CAVE_GUY
    "pokered:CERULEAN_CITY:objects:11",  # house guard, hidden once the ticket is owned
    "pokered:MT_MOON_B2F:objects:6",     # dome fossil, one fossil already taken
    "pokered:MT_MOON_B2F:objects:7",     # helix fossil, the nerd takes the other
}
QUEST_FLAGS = (
    "TOGGLE_CERULEAN_CAVE_GUY",
    "TOGGLE_CERULEAN_ROCKET",
    "EVENT_GOT_SS_TICKET",
    "EVENT_GOT_DOME_FOSSIL",
)
DEFEATED_TRAINERS = ("pokered:CERULEAN_CITY:objects:1",)
MEWTWO = {("CeruleanCaveB1F", x, y) for x, y in ((27, 12), (27, 14), (26, 13), (28, 13))}
ZAPDOS = {("PowerPlant", x, y) for x, y in ((4, 8), (4, 10), (3, 9), (5, 9))}
SPAWN = ("PalletTown", 5, 6, "walk")


def _load():
    compact = json.loads((SOURCE / "data/sourceMapCache/compact.json").read_text())
    manifest = json.loads((SOURCE / "data/sourceMaps.json").read_text())["maps"]
    return compact, manifest


class _World:
    def __init__(self):
        compact, self.manifest = _load()
        self.tiles = compact["tiles"]
        self.maps = compact["maps"]
        self.doors = {name: set(ids) for name, ids in compact["door_tiles"].items()}
        self.by_const = {row["source_map_constant"]: name for name, row in self.maps.items()}
        self.raw_cache = {}
        self.obj_cache = {}
        self.warp_cache = {}

    def raw(self, name):
        if name not in self.raw_cache:
            self.raw_cache[name] = json.loads((SOURCE / self.manifest[name]["path"]).read_text())
        return self.raw_cache[name]

    def tile(self, name, x, y):
        row = self.maps[name]
        tid = int(row["tile_rows"][y][x * 2:x * 2 + 2], 16)
        return self.tiles[row["palette"][tid - 1]]

    def collision(self, name, x, y):
        row = self.maps[name]
        if not (0 <= x < row["width"] and 0 <= y < row["height"]):
            return 1
        if row["blocked"].get(str(y * row["width"] + x + 1)):
            return 1
        return self.tile(name, x, y)["collision"]

    def foot(self, name, x, y):
        return self.tile(name, x, y)["terrain"]["foot_tile"]

    def occupied(self, name):
        if name in self.obj_cache:
            return self.obj_cache[name]
        blocked = set()
        pad = self.manifest[name]["padding"]
        for obj in self.raw(name)["events"]["objects"]:
            if obj["id"] in HIDDEN or obj["kind"] == "item" or obj.get("movement") == "WALK":
                continue
            blocked.add((obj["x"] + pad, obj["y"]))
        self.obj_cache[name] = blocked
        return blocked

    def warps(self, name):
        if name in self.warp_cache:
            return self.warp_cache[name]
        row = self.maps[name]
        table = {}
        inert = row["non_triggering_warps"]
        for index, warp in enumerate(row["warps"], 1):
            if str(index) in inert or index in inert:
                continue
            table.setdefault((warp["x"], warp["y"]), []).append(warp)
        self.warp_cache[name] = table
        return table

    def is_door(self, name, x, y):
        constant = self.maps[name]["tileset"]["constant"]
        return self.foot(name, x, y) in self.doors.get(constant, ())

    def surf_surface(self, name, x, y):
        tileset = self.maps[name]["tileset"]["constant"]
        if tileset not in WATER_TILESETS:
            return False
        foot = self.foot(name, x, y)
        if tileset == "SHIP_PORT":
            return foot == 0x14
        return foot in (0x14, 0x32, 0x48)

    def pair_blocked(self, name, origin, target):
        tileset = self.maps[name]["tileset"]["constant"]
        return (tileset, origin, target) in WATER_PAIRS or (tileset, target, origin) in WATER_PAIRS

    def land(self, target, index):
        if not target:
            return None
        other = self.maps[target]
        arrival = other["warps"][index - 1]
        ax, ay = arrival["x"], arrival["y"]
        if other["blocked"].get(str(ay * other["width"] + ax + 1)):
            return None
        door = self.is_door(target, ax, ay)
        advance = 1 if door and ay + 1 < other["height"] and self.collision(target, ax, ay + 1) == 0 else 0
        x, y = ax, ay + advance
        if other["blocked"].get(str(y * other["width"] + x + 1)):
            return None
        arrived = self.tile(target, x, y)
        water = arrived["terrain"].get("water_candidate") and arrived["terrain"]["foot_tile"] == 0x14
        if not (arrived["collision"] == 0 or water):
            return None
        if (x, y) in self.occupied(target):
            return None
        return target, x, y, ("down" if door else None)

    def steps(self, name, x, y, mode):
        out = []
        row = self.maps[name]
        here = self.foot(name, x, y)
        for direction, (dx, dy) in DELTAS.items():
            nx, ny = x + dx, y + dy
            inside = 0 <= nx < row["width"] and 0 <= ny < row["height"]
            if inside and mode == "walk" and self.collision(name, x, y) == 0:
                ahead = self.foot(name, nx, ny)
                jumped = False
                for rule in self.raw(name).get("directional_rules", {}).get("ledges", []):
                    if (rule.get("facing") == FACING[direction]
                            and rule.get("standing_foot_tile") == here
                            and rule.get("target_foot_tile") == ahead):
                        lx, ly = x + 2 * dx, y + 2 * dy
                        if (0 <= lx < row["width"] and 0 <= ly < row["height"]
                                and self.collision(name, lx, ly) == 0
                                and (lx, ly) not in self.occupied(name)):
                            out.append((name, lx, ly, "walk", direction, "ledge"))
                        jumped = True
                        break
                if jumped:
                    continue
                pairs = self.raw(name).get("directional_rules", {}).get("forbidden_tile_pairs", [])
                if any((here == pair[0] and ahead == pair[1]) or (here == pair[1] and ahead == pair[0])
                       for pair in pairs):
                    continue
            if inside:
                hits = self.warps(name).get((nx, ny))
                can_enter = self.collision(name, nx, ny) == 0 or (
                    self.surf_surface(name, nx, ny) and not self.pair_blocked(name, here, self.foot(name, nx, ny)))
                if hits and can_enter and (nx, ny) not in self.occupied(name):
                    for warp in hits:
                        dest = warp["destination"]
                        if dest["kind"] == "last_outdoor_map":
                            target = self.maps[name]["last_outdoor"]
                            landed = self.land(target, dest["warp_index"]) if target else None
                        else:
                            landed = self.land(self.by_const.get(dest["map"]), dest["warp_index"])
                        if landed:
                            map_name, tx, ty, facing = landed
                            arrive = "surf" if self.collision(map_name, tx, ty) != 0 and self.surf_surface(map_name, tx, ty) else "walk"
                            out.append((map_name, tx, ty, arrive, facing or direction, "warp"))
                            break
                    continue
                if (nx, ny) in self.occupied(name):
                    continue
                target_foot = self.foot(name, nx, ny)
                if self.pair_blocked(name, here, target_foot):
                    continue
                if mode == "walk" and self.collision(name, nx, ny) == 0:
                    out.append((name, nx, ny, "walk", direction, "walk"))
                elif self.surf_surface(name, nx, ny):
                    out.append((name, nx, ny, "surf", direction, "surf"))
                elif mode == "surf" and self.collision(name, nx, ny) == 0 and target_foot != 0x14:
                    out.append((name, nx, ny, "walk", direction, "surf-land"))
                continue
            boundary = ((direction == "up" and y == 0) or (direction == "down" and y == row["height"] - 1)
                        or (direction == "left" and x == 0) or (direction == "right" and x == row["width"] - 1))
            if not boundary:
                continue
            if mode == "surf" and self.collision(name, x, y) != 0 and not self.surf_surface(name, x, y):
                continue
            if mode == "walk" and self.collision(name, x, y) != 0:
                continue
            for connection in row["connections"]:
                if connection["direction"] != CARDINAL[direction]:
                    continue
                blocked = f"{connection['direction']}:{connection['target_map']}"
                if any(item == blocked for item in row.get("blocked_connections", [])):
                    continue
                target = self.by_const.get(connection["target_map"])
                if not target:
                    continue
                other = self.maps[target]
                adjust = connection["entry_lateral_adjustment_cells"]
                vertical = direction in ("up", "down")
                tx = (x - row["padding"] + adjust + other["padding"]) if vertical else (
                    other["width"] - other["padding"] - 1 if direction == "left" else other["padding"])
                ty = (other["height"] - 1 if direction == "up" else 0) if vertical else y + adjust
                if not (other["padding"] <= tx < other["padding"] + other["source_width"] and 0 <= ty < other["height"]):
                    continue
                if (tx, ty) in self.occupied(target):
                    continue
                if self.collision(target, tx, ty) == 0:
                    arrive = "surf" if mode == "surf" and self.surf_surface(target, tx, ty) else "walk"
                    out.append((target, tx, ty, arrive, direction, "connection"))
                elif self.surf_surface(target, tx, ty) and not self.pair_blocked(target, here, self.foot(target, tx, ty)):
                    out.append((target, tx, ty, "surf", direction, "connection"))
        return out


def _search(world, start, goals):
    queue = deque([start])
    previous = {start: None}
    found = None
    while queue:
        current = queue.popleft()
        if current[:3] in goals and current[3] == "walk":
            found = current
            break
        for nxt in world.steps(*current):
            if nxt[0].startswith("Seafoam"):
                continue
            state = nxt[:4]
            if state not in previous:
                previous[state] = (current, nxt)
                queue.append(state)
    if found is None:
        raise RuntimeError("no postgame path to " + str(sorted(goals)))
    steps = []
    state = found
    while previous[state] is not None:
        parent, step = previous[state]
        steps.append(step)
        state = parent
    steps.reverse()
    return found, steps


def _record(world, step):
    name, x, y, mode, facing, kind = step
    return {"map": name, "zone": world.manifest[name]["id"], "x": x, "y": y,
            "mode": mode, "facing": facing, "kind": kind}


def build_journey():
    """Return the Continue spawn plus the walk that reaches both statics."""
    world = _World()
    mewtwo_at, mewtwo_steps = _search(world, SPAWN, MEWTWO)
    zapdos_at, zapdos_steps = _search(world, mewtwo_at, ZAPDOS)
    steps = [_record(world, step) for step in mewtwo_steps + zapdos_steps]
    return {
        "spawn": {"map": "PalletTown", "zone": world.manifest["PalletTown"]["id"],
                  "x": 5, "y": 6, "facing": "down", "mode": "walk"},
        "mewtwo_index": len(mewtwo_steps) - 1,
        "zapdos_index": len(steps) - 1,
        "mewtwo_at": {"map": mewtwo_at[0], "x": mewtwo_at[1], "y": mewtwo_at[2]},
        "zapdos_at": {"map": zapdos_at[0], "x": zapdos_at[1], "y": zapdos_at[2]},
        "steps": steps,
        "quest_flags": list(QUEST_FLAGS),
        "defeated_trainers": list(DEFEATED_TRAINERS),
    }


def location_hash(steps):
    facing_code = {"up": 1, "down": 2, "left": 3, "right": 4}
    value = 0
    for step in steps:
        value = (value * 33 + step["x"] * 131 + step["y"] * 17
                 + facing_code[step["facing"]] + len(step["zone"])) % 10000019
    return value
