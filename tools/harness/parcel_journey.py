"""Real-input Blue parcel journey. Runtime ownership remains with run.py.

Dependencies and acceptance status are explicit; importing or planning this module
never launches the Simulator, writes Source, edits inventory, or claims passage.
"""
from dataclasses import dataclass
import hashlib
import heapq
import json
from pathlib import Path
import sys
if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.harness.journeys import Journey, DIRECTIONS, lookup
from tools.harness.protocol import ProtocolError, atomic_json

REVISION = "af519899719f0754965776faac0e836a3b906e6d"
NAMES = {"Route1": "pokered:ROUTE_1", "ViridianCity": "pokered:VIRIDIAN_CITY",
         "ViridianMart": "pokered:VIRIDIAN_MART", "ViridianPokecenter": "pokered:VIRIDIAN_POKECENTER"}
KEYS = {"pallet_town": "pallet_town", "oaks_lab": "oaks_lab", **{v: k for k, v in NAMES.items()}}
FLAGS = ("EVENT_GOT_OAKS_PARCEL", "EVENT_OAK_GOT_PARCEL", "EVENT_GOT_POKEDEX")
DEPENDENCIES = {
    "schema": 1, "status": "runtime integration required; no passage claimed",
    "snapshot": ["zone", "zone_id", "session.flags.quest", "session.inventory.slots",
                 "session.inventory.money", "session.party.members", "session.party.active", "session.checkpoint"],
    "ui": {"battle.menu": ["selected", "options", "columns"], "event": ["id", "phase", "waiting", "menu.selected"],
           "shop": ["phase", "selected", "item", "quantity", "result"],
           "pause": ["phase", "selected", "menu.options", "lastSave.ok"]},
    "shop_phases": ["mode", "browse", "quantity", "confirm", "result"],
    "heal_phases": ["dialog", "heal-confirm", "heal-animation"],
    "save": "B -> pause option SAVE -> phase save option YES -> saved dialog; lastSave.ok survives exit",
    "dispatcher": "journeys.run must dispatch parcel-natural to this module",
    "natural_constraints": "one initial new-game seed reset; no inventory/HP/position/encounter/outcome fixtures afterward",
}


def sequence(value, label):
    if value == {}:  # SDK's empty Lua table can encode as an empty object.
        return []
    if not isinstance(value, list):
        raise ProtocolError(f"parcel dependency requires array {label}")
    return value


@dataclass(frozen=True)
class Step:
    direction: str
    destination: tuple
    kind: str = "walk"


class Geometry:
    """A small path surface shared by authored SDK exports and pinned source cells."""
    def __init__(self, name, collision, grass=None, feet=None, rules=(), pairs=(), events=None, doors=()):
        self.name = name
        self.height = len(collision)
        self.width = len(collision[0]) if self.height else 0
        if not self.width or any(len(row) != self.width or any(type(c) is not int or c not in (0, 1) for c in row) for row in collision):
            raise ProtocolError("invalid parcel collision dimensions/values")
        self.collision = collision
        self.grass = grass or [[False] * self.width for _ in collision]
        self.feet = feet or [[None] * self.width for _ in collision]
        self.rules, self.pairs = rules, pairs
        self.events = events or {"objects": [], "warps": [], "background_events": []}
        self.doors = list(doors)
        self.warps = {(e["x"], e["y"]) for e in self.events["warps"]} | {(d["x"], d["y"]) for d in doors}
        self.signs = {(e["x"], e["y"]) for e in self.events["background_events"]}
        for matrix in (self.grass, self.feet):
            if len(matrix) != self.height or any(len(row) != self.width for row in matrix):
                raise ProtocolError("invalid parcel terrain dimensions")

    def inside(self, point):
        return 0 <= point[0] < self.width and 0 <= point[1] < self.height

    def terrain_step(self, point, direction):
        dx, dy = DIRECTIONS[direction]
        x, y = point
        target = (x + dx, y + dy)
        if not self.inside(point) or not self.inside(target):
            return None
        a, b = self.feet[y][x], self.feet[target[1]][target[0]]
        for rule in self.rules:
            if (rule["facing"] == "SPRITE_FACING_" + direction.upper()
                    and rule["standing_foot_tile"] == a and rule["target_foot_tile"] == b):
                landing = (x + dx * 2, y + dy * 2)
                if self.inside(landing) and not self.collision[landing[1]][landing[0]]:
                    return Step(direction, landing, "ledge")
                return None
        if any((a == first and b == second) or (a == second and b == first) for first, second in self.pairs):
            return None
        return Step(direction, target) if not self.collision[target[1]][target[0]] else None

    def path(self, origin, goals, occupied=(), allow_warps=()):
        """Dijkstra favors real non-grass walking without disabling encounters."""
        goals, occupied, allowed = set(goals), set(occupied), set(allow_warps)
        if not self.inside(origin) or not goals or any(not self.inside(p) for p in goals):
            raise ProtocolError("parcel path endpoint outside source map")
        blocked = occupied | (self.warps - allowed) | self.signs
        blocked.discard(origin)
        queue, cost, previous = [(0, origin)], {origin: 0}, {}
        while queue:
            current_cost, point = heapq.heappop(queue)
            if current_cost != cost[point]:
                continue
            if point in goals:
                route = []
                while point != origin:
                    parent, step = previous[point]
                    route.append(step)
                    point = parent
                return list(reversed(route))
            for direction in ("up", "right", "down", "left"):
                step = self.terrain_step(point, direction)
                if step is None or step.destination in blocked:
                    continue
                x, y = step.destination
                candidate = current_cost + (2 if step.kind == "ledge" else 1) + 8 * int(self.grass[y][x])
                if candidate < cost.get(step.destination, float("inf")):
                    cost[step.destination] = candidate
                    previous[step.destination] = point, step
                    heapq.heappush(queue, (candidate, step.destination))
        raise ProtocolError(f"no source-valid parcel path in {self.name}: {origin} -> {sorted(goals)}")

    def approaches(self, target):
        if not self.inside(target):
            raise ProtocolError("interaction target outside source map")
        approaches = {}
        for facing, (dx, dy) in DIRECTIONS.items():
            for distance in (1, 2):
                point = (target[0] - dx * distance, target[1] - dy * distance)
                middle = (target[0] - dx, target[1] - dy)
                if not self.inside(point) or self.collision[point[1]][point[0]]:
                    continue
                if distance == 2 and (not self.inside(middle) or self.feet[middle[1]][middle[0]] not in getattr(self, "counter_feet", ())):
                    continue
                approaches[point] = facing
        return approaches

    @classmethod
    def imported(cls, data):
        if data.get("source_revision") != REVISION or data.get("id") not in NAMES.values():
            raise ProtocolError("parcel map is not the pinned Blue slice")
        width, height = data["dimensions"]["cells"]
        if len(data["collision"]) != height or any(len(row) != width for row in data["collision"]):
            raise ProtocolError("source parcel dimension mismatch")
        offset, padded_width = max(0, (13 - width) // 2), max(13, width)
        collision = [[1] * padded_width for _ in range(height)]
        grass = [[False] * padded_width for _ in range(height)]
        feet = [[None] * padded_width for _ in range(height)]
        for y in range(height):
            if len(data["tile_ids"][y]) != width:
                raise ProtocolError("source parcel tile row mismatch")
            for x in range(width):
                local_id = data["tile_ids"][y][x]
                if type(local_id) is not int or not 1 <= local_id <= len(data["grids"]):
                    raise ProtocolError("unknown source parcel tile ID")
                terrain = data["grids"][local_id - 1]["terrain"]
                if data["collision"][y][x] != int(not terrain["land_passable"]):
                    raise ProtocolError("source parcel collision disagreement")
                collision[y][x + offset] = data["collision"][y][x]
                grass[y][x + offset], feet[y][x + offset] = terrain["grass"], terrain["foot_tile"]
        events = {kind: [dict(event, x=event["x"] + offset) for event in entries] for kind, entries in data["events"].items()}
        for entries in events.values():
            if any(not (0 <= e["x"] < padded_width and 0 <= e["y"] < height) for e in entries):
                raise ProtocolError("source parcel event outside map")
        model = cls(data["id"], collision, grass, feet, data["directional_rules"]["ledges"],
                    data["directional_rules"]["forbidden_tile_pairs"], events)
        model.source_data = data
        model.counter_feet = tuple(data["tileset"]["counter_tiles"])
        return model


def load_geometry(evidence):
    """Consume the exact immutable Source copied for this identified bundle."""
    evidence = Path(evidence)
    manifest = json.loads((evidence / "source-manifest.json").read_text())
    authored = json.loads(Path(__file__).with_name("parcel_authored.json").read_text())
    source = evidence / "Source" / authored["source_file"]
    if hashlib.sha256(source.read_bytes()).hexdigest() != authored["source_sha256"]:
        raise ProtocolError("authored Pallet/lab Source changed; regenerate reviewed SDK collision reference")
    models = {}
    for key, entry in authored["maps"].items():
        rows = entry["collision_rows"]
        if (len(rows) != entry["height"] or any(len(row) != entry["width"] or set(row) - {".", "#"} for row in rows)
                or len(entry["grass_rows"]) != entry["height"]
                or any(len(row) != entry["width"] or set(row) - {".", "g"} for row in entry["grass_rows"])):
            raise ProtocolError("malformed reviewed authored collision/terrain reference")
        models[key] = Geometry(key, [[int(c == "#") for c in row] for row in rows],
                               [[c == "g" for c in row] for row in entry["grass_rows"]], doors=entry["doors"])
    for name, stable in NAMES.items():
        relative = "data/viridianSlice/" + name + ".json"
        path = evidence / "Source" / relative
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != manifest.get(relative):
            raise ProtocolError("parcel dependency missing/changed compiled map: " + relative)
        data = json.loads(path.read_text())
        if data.get("id") != stable or data.get("name") != name:
            raise ProtocolError("compiled parcel map filename/identity mismatch")
        models[stable] = Geometry.imported(data)
    return models


def project_connection(models, zone, point, direction):
    """Project only source headers, authored edge doors, or the reviewed Pallet seam."""
    model = models[zone]
    if not model.inside(point) or model.collision[point[1]][point[0]]:
        raise ProtocolError("connection origin is not passable source geometry")
    for door in model.doors:
        if (door["x"], door["y"]) == point and door.get("edge") == direction:
            return door["to"], (door["toX"], door["toY"])
    pin = json.loads((Path(__file__).resolve().parents[1] / "references/map-pilot.json").read_text())
    if pin.get("revision") != REVISION:
        raise ProtocolError("wrong Pallet seam reference revision")
    seam = pin["adapter_proposals"]["pallet_route1"]
    authored = [tuple(p) for p in seam["authored_pallet_north_cells"]]
    imported = [tuple(p) for p in seam["imported_route1_south_cells"]]
    if zone == "pallet_town" and direction == "up" and point in authored:
        return NAMES["Route1"], imported[authored.index(point)]
    if zone == NAMES["Route1"] and direction == "down" and point in imported:
        return "pallet_town", authored[imported.index(point)]
    cardinal = {"up": "north", "down": "south", "left": "west", "right": "east"}
    edge = {"up": point[1] == 0, "down": point[1] == model.height - 1,
            "left": point[0] == 0, "right": point[0] == model.width - 1}
    if not edge.get(direction):
        raise ProtocolError("connection input is not on source map edge")
    source = getattr(model, "source_data", {})
    header = next((c for c in source.get("connections", []) if c["direction"] == cardinal[direction]), None)
    if header is None or header["target_header"] not in NAMES:
        raise ProtocolError("source connection is outside the supported parcel slice")
    target_id = NAMES[header["target_header"]]
    target = models[target_id]
    adjustment = header["entry_lateral_adjustment_cells"]
    if direction in {"up", "down"}:
        destination = (point[0] + adjustment, target.height - 1 if direction == "up" else 0)
    else:
        destination = (target.width - 1 if direction == "left" else 0, point[1] + adjustment)
    if not target.inside(destination) or target.collision[destination[1]][destination[0]]:
        raise ProtocolError("source header connection arrives outside/passability mismatch")
    return target_id, destination


class ParcelJourney(Journey):
    def __init__(self, client, evidence, config):
        super().__init__(client, evidence, config)
        self.models = {}
        self.initializing = False
        self.initialized = False
        self.actions = 0
        self.event_recordings = set()
        self.summary.update(dependencies=DEPENDENCIES, navigation=[], events=[], wild_encounters=[], acceptance="pending",
                            driver_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                            authored_reference_sha256=hashlib.sha256(Path(__file__).with_name("parcel_authored.json").read_bytes()).hexdigest())
        for key, low, high in (("max_actions", 1, 20000), ("max_steps", 1, 5000), ("max_encounters", 1, 64)):
            if key in config and (type(config[key]) is not int or not low <= config[key] <= high):
                raise ProtocolError("invalid bounded parcel option: " + key)
        if config.get("rival_fixture") is not None:
            raise ProtocolError("natural parcel journey forbids forced rival outcomes")

    def send(self, *commands):
        self.actions += len(commands)
        if self.actions > self.config.get("max_actions", 6000):
            raise ProtocolError("parcel journey exceeded semantic action bound")
        for command in commands:
            op = command.split()[0] if isinstance(command, str) else command.get("op")
            if op == "fixture":
                if not self.initializing:
                    raise ProtocolError("parcel natural journey forbids later fixtures")
                if not self.config.get("supplementary") and set(command.get("options", {})) != {"seed"}:
                    raise ProtocolError("natural parcel initialization accepts only a seed")
            elif op not in {"press", "wait", "shot", "record", "snapshot", "await", "assert"}:
                raise ProtocolError("non-input parcel action forbidden: " + str(op))
        return super().send(*commands)

    def reset(self, **options):
        if not self.initializing or self.initialized:
            raise ProtocolError("parcel permits only one initial new-game reset")
        self.initialized = True
        return super().reset(**options)

    def dependencies(self):
        atomic_json(self.evidence / "parcel-dependencies.json", DEPENDENCIES)
        self.models = load_geometry(self.evidence)
        self.send("snapshot")
        required = ["zone_id", "session.flags.quest", "session.inventory", "session.party", "session.checkpoint"]
        for path in required:
            if lookup(self.state, path) is None:
                raise ProtocolError("parcel runtime dependency missing: " + path)
        for key in ("event", "shop", "pause", "bag"):
            if not isinstance(self.state.get(key), dict):
                raise ProtocolError("parcel runtime UI dependency missing: " + key)
        self.summary["map_sources"] = {key: {"width": model.width, "height": model.height} for key, model in self.models.items()}

    def quantity(self, item):
        slots = sequence(lookup(self.state, "session.inventory.slots"), "session.inventory.slots")
        return sum(slot["quantity"] for slot in slots if slot["id"] == item)

    def flag(self, name):
        flags = lookup(self.state, "session.flags.quest")
        if flags == []:  # SDK encodes an empty Lua mapping as an empty array.
            flags = {}
        if not isinstance(flags, dict) or any(not isinstance(key, str) or type(value) is not bool
                                               for key, value in flags.items()):
            raise ProtocolError("quest diagnostic requires a boolean flag map")
        return flags.get(name, False)

    def pause_option(self, name):
        if self.state.get("root") == "overworld":
            self.await_value("root", "pause", frames=8)
        options = sequence(lookup(self.state, "pause.menu.options"), "pause.menu.options")
        if any(not isinstance(option, str) for option in options) or options.count(name) != 1:
            raise ProtocolError("pause menu requires exactly one option: " + name)
        self.select("pause.selected", options.index(name) + 1)

    def inventory(self):
        return lookup(self.state, "session.inventory")

    def party(self):
        return sequence(lookup(self.state, "session.party.members"), "session.party.members")

    def model(self):
        key = self.state.get("zone_id")
        if key not in self.models:
            raise ProtocolError("parcel navigation reached unsupported zone: " + str(key))
        return self.models[key]

    def position(self):
        return self.state["player"]["x"], self.state["player"]["y"]

    def occupied(self):
        return {(npc["x"], npc["y"]) for npc in sequence(self.state.get("npcs", []), "npcs")}

    def select(self, path, index, bound=24):
        visited = set()
        for _ in range(bound):
            current = lookup(self.state, path)
            if current == index:
                return
            if type(current) is not int or current in visited:
                raise ProtocolError(f"cannot select menu index{index} via {path}: {current!r}")
            visited.add(current)
            columns = lookup(self.state, "battle.menu.columns") if path == "battle.menu.selected" else 1
            columns = 1 if columns is None else columns
            if type(columns) is not int or columns < 1 or columns > 4:
                raise ProtocolError("invalid menu column diagnostic")
            direction = "right" if (current - 1) % columns != (index - 1) % columns else "down"
            self.send("press " + direction)
        raise ProtocolError("parcel menu exceeded navigation bound")

    def flee(self):
        self.require(root="battle")
        self.await_value("battle.introPhase", "ready")
        if self.state["battle"].get("trainerName"):
            raise ProtocolError("unexpected trainer during parcel navigation")
        if len(self.summary["wild_encounters"]) >= self.config.get("max_encounters", 24):
            raise ProtocolError("parcel walk exceeded natural encounter bound")
        entry = {"entry": self.state, "strategy": "real RUN menu input"}
        self.summary["wild_encounters"].append(entry)
        for _ in range(240):
            if self.state.get("root") != "battle":
                entry["exit"] = self.state.get("last_battle_outcome")
                if lookup(self.state, "last_battle_outcome.blackout"):
                    raise ProtocolError("natural parcel walk interrupted by real blackout")
                return
            phase = lookup(self.state, "battle.phase")
            if phase == "ended":
                self.send("press a")
            elif phase == "script":
                self.send("wait 12", "press a") if lookup(self.state, "battle.waiting") else self.send("wait 2")
            elif phase == "command":
                if lookup(self.state, "battle.inMoveSelect"):
                    self.send("press b")
                active = lookup(self.state, "battle.menu.active")
                if type(active) is not bool:
                    raise ProtocolError("battle command menu requires an active diagnostic")
                if not active:
                    # introPhase becomes ready at the end of an update, before
                    # BattleScene's next ordinary input pass opens its menu.
                    self.send("wait 2")
                    self.await_value("battle.menu.active", True, frames=60)
                    continue
                options = lookup(self.state, "battle.menu.options")
                run_index = 2  # Compatibility with the original confirmed FIGHT/RUN menu.
                if options is not None:
                    options = sequence(options, "battle.menu.options")
                    indices = [i for i, value in enumerate(options, 1)
                               if value == "RUN" or isinstance(value, dict) and value.get("action") == "run"]
                    if len(indices) != 1:
                        raise ProtocolError("battle menu must expose exactly one real RUN action")
                    run_index = indices[0]
                self.select("battle.menu.selected", run_index)
                self.send("press a")
            else:
                raise ProtocolError("unexpected wild phase: " + str(phase))
        raise ProtocolError("wild RUN attempts exceeded bounded real inputs")

    def drain(self, stop_phase=None):
        for _ in range(900):
            root = self.state.get("root")
            if root == "overworld":
                if self.state.get("overworld") == "explore" and lookup(self.state, "player.settled") is True:
                    return
                self.send("wait 3")
            elif root == "dialog":
                self.dialog()
            elif root == "battle":
                self.flee()
            elif root == "event":
                event = self.state["event"]
                self.summary["events"].append({"id": event.get("id"), "phase": event.get("phase"), "waiting": event.get("waiting")})
                if event.get("phase") == "failed":
                    raise ProtocolError("source event failed: " + str(event.get("waiting")))
                if stop_phase is not None and event.get("phase") == stop_phase:
                    return
                if event.get("phase") == "heal-confirm":
                    raise ProtocolError("heal confirmation requires explicit driver decision")
                if event.get("phase") == "dialog":
                    self.send("press a")
                else:
                    phase = event.get("phase")
                    key = (event.get("id"), phase)
                    if phase in {"move", "oak-arrival", "oak-departure", "heal-animation"} and key not in self.event_recordings:
                        self.event_recordings.add(key)
                        name = f"parcel-event-{len(self.event_recordings):02d}-{phase}"
                        frames = 40 if phase.startswith("oak-") else 24 if phase == "move" else 15 * len(self.party()) + 56
                        self.summary.setdefault("event_records", []).append({"name": name, "frames": frames, "id": key[0], "phase": phase})
                        self.send(f"record {name} {frames}")
                    self.send("wait 3")
            elif root == "learning":
                phase = lookup(self.state, "learning.phase")
                if phase == "message":
                    if lookup(self.state, "learning.dialog_ready"):
                        self.send("press a")
                    else:
                        self.send("wait 3")
                elif phase == "ask":
                    self.send("press b")  # Explicit natural choice to retain current moves.
                elif phase == "stop":
                    self.select("learning.selected", 1)
                    self.send("press a")
                else:
                    raise ProtocolError("unexpected learning choice during parcel walk: " + str(phase))
            elif root in {"shop", "pause", "bag"}:
                return
            else:
                raise ProtocolError("unexpected parcel UI state: " + str(root))
        raise ProtocolError("parcel event/transition exceeded semantic bound")

    def step(self, step):
        self.require(root="overworld", overworld="explore", **{"player.settled": True})
        before_zone, before = self.state["zone_id"], self.position()
        self.send("press " + step.direction, "wait " + ("17" if step.kind == "ledge" else "9"))
        self.drain()
        self.summary["navigation"].append({"zone": before_zone, "from": before, "direction": step.direction,
                                           "kind": step.kind, "expected": step.destination,
                                           "actual_zone": self.state.get("zone_id"), "actual": self.position()})
        if self.state.get("zone_id") == before_zone and self.position() != step.destination:
            raise ProtocolError(f"source-valid {step.kind} failed: {before} -> {step.destination}, actual {self.position()}")

    def navigate(self, goals, transition=None):
        if isinstance(goals, tuple):
            goals = {goals}
        goals = set(goals)
        zone = self.state["zone_id"]
        for _ in range(self.config.get("max_steps", 1000)):
            if self.state["zone_id"] != zone:
                if self.state["zone_id"] != transition:
                    raise ProtocolError("unexpected parcel door transition")
                return
            if self.position() in goals:
                return
            route = self.model().path(self.position(), goals, self.occupied(), allow_warps=goals)
            self.step(route[0])  # Replan after each real step/NPC observation.
        raise ProtocolError("parcel source path exceeded step bound")

    def cross(self, direction, zone, destination):
        self.require(root="overworld", **{"player.settled": True})
        before = self.state["zone_id"]
        projected = project_connection(self.models, before, self.position(), direction)
        if projected != (zone, destination):
            raise ProtocolError("requested connection disagrees with pinned source/header transformation")
        self.send("press " + direction, "wait 12")
        self.drain()
        self.require(zone_id=zone, **{"player.x": destination[0], "player.y": destination[1]})
        self.summary["navigation"].append({"connection_from": before, "direction": direction,
                                           "connection_to": zone, "destination": destination})

    def interact(self, name=None, source_id=None, stop_phase=None):
        model, target = self.model(), None
        if source_id:
            source = next((e for e in model.events["objects"] if e["id"] == source_id), None)
            if source is None:
                raise ProtocolError("unknown pinned interaction ID: " + source_id)
            target = (source["x"], source["y"])
            for npc in sequence(self.state.get("npcs", []), "npcs"):
                if npc.get("source_event_id") == source_id or npc.get("name") == source.get("text_id"):
                    target = (npc["x"], npc["y"])
        else:
            npc = next((npc for npc in sequence(self.state.get("npcs", []), "npcs") if npc["name"] == name), None)
            if npc:
                target = (npc["x"], npc["y"])
        if target is None:
            raise ProtocolError("parcel interaction target missing: " + str(name or source_id))
        approaches = model.approaches(target)
        self.navigate(set(approaches))
        self.face(approaches[self.position()])
        self.send("press a", "wait 2")
        self.drain(stop_phase=stop_phase)

    def leave_lab(self):
        self.require(zone_id="oaks_lab")
        self.navigate((5, 9))
        self.cross("down", "pallet_town", (10, 11))

    def north_to_city(self):
        self.navigate((9, 0))
        self.cross("up", NAMES["Route1"], (10, 35))
        self.navigate((10, 0))
        self.cross("up", NAMES["ViridianCity"], (20, 35))

    def enter_mart(self):
        door = next(e for e in self.model().events["warps"] if e["destination"].get("map") == "VIRIDIAN_MART")
        self.navigate((door["x"], door["y"]), transition=NAMES["ViridianMart"])
        self.require(zone_id=NAMES["ViridianMart"])

    def leave_mart(self):
        self.navigate((5, 7))
        self.require(zone_id=NAMES["ViridianMart"])
        self.send("press down", "wait 15")
        self.drain()
        self.require(zone_id=NAMES["ViridianCity"], **{"player.x": 29, "player.y": 20})

    def return_to_oak(self):
        self.navigate((20, 35))
        self.cross("down", NAMES["Route1"], (10, 0))
        self.navigate((10, 35))
        self.cross("down", "pallet_town", (9, 0))
        self.navigate((10, 11), transition="oaks_lab")
        self.require(zone_id="oaks_lab")
        self.interact(name="OAK")
        if not self.flag("EVENT_OAK_GOT_PARCEL") or not self.flag("EVENT_GOT_POKEDEX") or self.quantity("oaksParcel") != 0:
            raise ProtocolError("Oak dialogue did not atomically consume parcel/unlock Pokédex")
        self.checkpoint("oak-pokedex-complete")

    def buy(self):
        before_money, before_balls = self.inventory()["money"], self.quantity("pokeBall")
        self.interact(source_id="pokered:VIRIDIAN_MART:objects:1")
        self.require(root="shop", **{"shop.phase": "mode"})
        self.select("shop.selected", 1)
        self.send("press a")
        self.require(**{"shop.phase": "browse"})
        item = lookup(self.state, "shop.item")
        if isinstance(item, dict):
            item = item.get("id")
        if item != "pokeBall":
            raise ProtocolError("source first Viridian stock item must be pokeBall")
        self.send("press a")
        self.require(**{"shop.phase": "quantity", "shop.quantity": 1})
        self.send("press a")
        self.require(**{"shop.phase": "confirm"})
        self.select("shop.selected", 1)
        self.send("press a")
        self.require(**{"shop.phase": "result"})
        if self.quantity("pokeBall") != before_balls + 1 or self.inventory()["money"] != before_money - 200:
            raise ProtocolError("real shop purchase did not debit source price200 and grant one ball")
        self.checkpoint("shop-purchase")
        self.send("press a", "press b", "press b")
        self.drain()
        self.require(root="overworld")

    def heal(self):
        door = next(e for e in self.model().events["warps"] if e["destination"].get("map") == "VIRIDIAN_POKECENTER")
        self.navigate((door["x"], door["y"]), transition=NAMES["ViridianPokecenter"])
        before_party = json.loads(json.dumps(self.party()))
        before_checkpoint = lookup(self.state, "session.checkpoint")
        self.interact(source_id="pokered:VIRIDIAN_POKECENTER:objects:1", stop_phase="heal-confirm")
        self.select("event.menu.selected", 2)
        self.send("press a")
        self.drain()
        if self.party() != before_party or lookup(self.state, "session.checkpoint") != before_checkpoint:
            raise ProtocolError("declining healing changed party/checkpoint")
        self.checkpoint("healing-declined")
        self.interact(source_id="pokered:VIRIDIAN_POKECENTER:objects:1", stop_phase="heal-confirm")
        self.select("event.menu.selected", 1)
        self.send("press a")
        self.drain()
        for member in self.party():
            maxima = member.get("maxPP")
            if not isinstance(maxima, dict) or not maxima:
                raise ProtocolError("heal proof requires authoritative party member maxPP diagnostics")
            if (member["hp"] != member["maxHP"] or member["status"] not in (None, "none")
                    or member["pp"] != maxima):
                raise ProtocolError("accepted healing did not restore full authoritative party")
        checkpoint = lookup(self.state, "session.checkpoint")
        if any(checkpoint.get(k) != v for k, v in {"zone_id": NAMES["ViridianCity"], "x": 23, "y": 26, "facing": "down"}.items()):
            raise ProtocolError("accepted healing checkpoint is not original outdoor Viridian23,26")
        self.checkpoint("healing-complete")

    def save(self):
        self.send("press b")
        self.require(root="pause", **{"pause.phase": "menu"})
        self.pause_option("SAVE")
        self.send("press a")
        self.require(**{"pause.phase": "save"})
        self.pause_option("YES")
        self.send("press a")
        self.require(root="dialog", **{"pause.lastSave.ok": True})
        self.dialog()
        self.require(root="overworld")
        self.checkpoint("parcel-game-saved")

    def natural(self):
        self.dependencies()
        self.initializing = True
        try:
            self.natural_intro()
        finally:
            self.initializing = False
        if any(self.flag(flag) for flag in FLAGS) or self.quantity("oaksParcel"):
            raise ProtocolError("new-game parcel flags/inventory were not empty")
        self.leave_lab()
        self.north_to_city()
        self.enter_mart()
        if not self.flag("EVENT_GOT_OAKS_PARCEL") or self.quantity("oaksParcel") != 1:
            raise ProtocolError("natural first Mart entry did not grant exactly one parcel")
        self.checkpoint("parcel-received")
        self.leave_mart()
        self.enter_mart()
        if self.quantity("oaksParcel") != 1:
            raise ProtocolError("reentering Mart duplicated/lost parcel")
        self.leave_mart()
        self.return_to_oak()
        self.leave_lab()
        self.north_to_city()
        self.assert_visibility(True)
        self.enter_mart()
        self.buy()
        self.leave_mart()
        self.heal()
        self.save()
        self.summary.update(acceptance="natural journey complete", natural=True, forbidden_shortcuts=False)

    def toss_single(self, item="antidote"):
        slots = sequence(self.inventory()["slots"], "inventory.slots")
        index = next((index for index, slot in enumerate(slots, 1) if slot["id"] == item and slot["quantity"] == 1), None)
        if index is None:
            raise ProtocolError("supplementary retry requires a single ordinary item to toss")
        self.send("press b")
        self.require(root="pause", **{"pause.phase": "menu"})
        self.pause_option("ITEM")
        self.send("press a")
        self.require(root="bag", **{"bag.phase": "list"})
        self.select("bag.selected", index)
        self.send("press a")
        self.require(**{"bag.phase": "actions"})
        self.select("bag.menu.selected", 2)
        self.send("press a")
        self.require(**{"bag.phase": "toss"})
        self.select("bag.menu.selected", 2)  # Existing actual menu is NO/YES.
        self.send("press a")
        self.require(**{"bag.phase": "message"})
        if len(sequence(self.inventory()["slots"], "inventory.slots")) != len(slots) - 1:
            raise ProtocolError("TOSS did not free the single ordinary-item slot")
        self.send("press a", "press b")
        self.drain()
        self.require(root="overworld")

    def full_bag(self):
        self.dependencies()
        options = self.config.get("fixture_options")
        if not self.config.get("supplementary") or not isinstance(options, dict):
            raise ProtocolError("full-bag scenario requires explicitly supplementary fixture_options")
        self.initializing = True
        try:
            self.reset(**options)
        finally:
            self.initializing = False
        self.drain()
        reward = self.config.get("reward")
        if reward == "potion":
            item, flag, event = "potion", "EVENT_GOT_POTION_SAMPLE", "pokered:ROUTE_1:objects:1"
            before = self.quantity(item)
            self.interact(source_id=event)
        elif reward == "parcel":
            if self.state.get("zone_id") == NAMES["ViridianCity"]:
                self.enter_mart()
            item, flag, event = "oaksParcel", "EVENT_GOT_OAKS_PARCEL", "pokered:VIRIDIAN_MART:objects:1"
            before = 0
            self.require(zone_id=NAMES["ViridianMart"], **{"player.x": 4, "player.y": 5})
        else:
            raise ProtocolError("supplementary reward must be potion or parcel")
        if self.flag(flag) or self.quantity(item) != before or len(sequence(self.inventory()["slots"], "inventory.slots")) != 20:
            raise ProtocolError("full-bag reward changed flag/item or did not start from20 full slots")
        self.checkpoint("supplementary-" + reward + "-bag-full")
        self.toss_single()
        self.interact(source_id=event)
        if not self.flag(flag) or self.quantity(item) != before + 1:
            raise ProtocolError("reward was not retryable after real TOSS freed capacity")
        self.interact(source_id=event)
        if self.quantity(item) != before + 1:
            raise ProtocolError("repeated reward interaction duplicated item")
        self.checkpoint("supplementary-" + reward + "-retry-complete")
        self.summary.update(acceptance="supplementary reward retry complete", natural=False)


    def assert_visibility(self, got_pokedex):
        identities = set()
        aliases = {"TEXT_VIRIDIANCITY_OLD_MAN_SLEEPY": "pokered:VIRIDIAN_CITY:objects:5",
                   "TEXT_VIRIDIANCITY_OLD_MAN": "pokered:VIRIDIAN_CITY:objects:7"}
        for npc in sequence(self.state.get("npcs", []), "npcs"):
            identities.add(npc.get("source_event_id") or npc.get("source_id") or aliases.get(npc.get("name")))
        if (("pokered:VIRIDIAN_CITY:objects:5" in identities) != (not got_pokedex)
                or ("pokered:VIRIDIAN_CITY:objects:7" in identities) != got_pokedex):
            raise ProtocolError("original sleepy/awake NPC visibility does not match Pokédex flag")

    def visibility_checkpoint(self):
        self.dependencies()
        options = self.config.get("fixture_options")
        if not self.config.get("supplementary") or not isinstance(options, dict):
            raise ProtocolError("visibility/checkpoint proof requires labeled supplementary fixture")
        self.initializing = True
        try:
            self.reset(**options)
        finally:
            self.initializing = False
        self.drain()
        got = self.flag("EVENT_GOT_POKEDEX")
        self.assert_visibility(got)
        if got:
            self.navigate((18, 9))  # The actual source floor is now physically free.
            self.require(**{"player.x": 18, "player.y": 9})
        self.checkpoint("supplementary-" + ("awake" if got else "sleepy") + "-source-npcs")
        self.heal()
        self.summary.update(acceptance="supplementary visibility/checkpoint complete", natural=False)


def run(client, scenario, evidence_dir):
    journey = None
    try:
        config = scenario.get("journey")
        if not isinstance(config, dict):
            raise ProtocolError("parcel journey must be an object")
        journey = ParcelJourney(client, evidence_dir, config)
        actions = {"parcel-natural": journey.natural, "parcel-full-bag-supplementary": journey.full_bag,
                   "parcel-visibility-checkpoint-supplementary": journey.visibility_checkpoint}
        action = actions.get(config.get("name"))
        if action is None:
            raise ProtocolError("unknown parcel journey")
        action()
    except BaseException as error:
        summary = journey.summary if journey else {"schema": 1, "acceptance": "pending", "dependencies": DEPENDENCIES}
        summary.update(ok=False, error=str(error), last_snapshot=journey.state if journey else {})
        atomic_json(Path(evidence_dir) / "journey-summary.json", summary)
        raise
    journey.summary.update(ok=True, last_snapshot=journey.state)
    return journey.summary


def offline_plan(evidence):
    models = load_geometry(evidence)
    # Door and connection end points are source landmarks. Each interior segment
    # is solved from the collision/ledge graph, not a pretyped movement shortcut.
    segments = [
        ("oaks_lab", (5, 9), (5, 9)),
        ("pallet_town", (10, 11), (9, 0)),
        (NAMES["Route1"], (10, 35), (10, 0)),
        (NAMES["ViridianCity"], (20, 35), (29, 19)),
        (NAMES["ViridianMart"], (4, 5), (5, 7)),
        (NAMES["ViridianCity"], (29, 20), (20, 35)),
        (NAMES["Route1"], (10, 0), (10, 35)),
        ("pallet_town", (9, 0), (10, 11)),
        ("oaks_lab", (5, 9), (5, 4)),
        (NAMES["ViridianCity"], (29, 20), (23, 25)),
        (NAMES["ViridianPokecenter"], (3, 6), (3, 3)),
    ]
    result = []
    for name, start, goal in segments:
        model = models[name]
        occupied = {(e["x"], e["y"]) for e in model.events["objects"]
                    if not (name == NAMES["ViridianCity"] and e["source_index"] == 7)}
        route = model.path(start, {goal}, occupied, {goal})
        result.append({"zone_id": name, "origin": start, "goal": goal,
                       "source_steps": [{"direction": s.direction, "destination": s.destination, "kind": s.kind} for s in route]})
    return {"schema": 1, "ok": False, "status": "offline action plan; not runtime acceptance", "dependencies": DEPENDENCIES,
            "source_revision": REVISION, "segments": result,
            "dynamic_occupancy": "runtime replans every step using actual NPC snapshots; offline authored NPC occupancy not asserted"}


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", action="store_true", required=True)
    parser.add_argument("--bundle-source", required=True, help="identified runner output containing staged Source and source-manifest.json")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    target = Path(args.output).resolve()
    if target.is_relative_to(Path(__file__).resolve().parents[2] / "Source"):
        raise ProtocolError("offline journey plans cannot overwrite Source")
    atomic_json(target, offline_plan(args.bundle_source))
    print(args.output)
