"""Bounded goal 5.3 input driver. Runtime/process ownership stays with run.py.

Uses the reviewed root API hooks and explicit read-only observations. Geometry and
the read-only owner export come from the identified staged build, never git HEAD.
Missing story/diagnostic integration is an error, not permission to skip a scene.
"""
import copy
import hashlib
import heapq
import json
import re
from pathlib import Path

from tools.harness.brock_journey import BrockJourney, FAMILIES, NaturalBlackout, SourceGeometry, boolean_map
from tools.harness.journeys import DIRECTIONS, lookup
from tools.harness.parcel_journey import load_geometry, sequence, REVISION
from tools.harness.protocol import ProtocolError, atomic_json


def sid(constant, index):
    return f"pokered:{constant}:objects:{index}"


MISTY = sid("CERULEAN_GYM", 1)
NERD = sid("MT_MOON_B2F", 1)
BRIDGE_RIVAL = sid("CERULEAN_CITY", 1)
NUGGET = sid("ROUTE_24", 1)
BILL = sid("BILLS_HOUSE", 1)
TICKET = sid("BILLS_HOUSE", 2)
PC = "pokered:BILLS_HOUSE:hidden_events:1"
FOSSILS = {
    "dome": (sid("MT_MOON_B2F", 6), "domeFossil", "EVENT_GOT_DOME_FOSSIL"),
    "helix": (sid("MT_MOON_B2F", 7), "helixFossil", "EVENT_GOT_HELIX_FOSSIL"),
}
REQUIRED_MAPS = {"Route3", "Route4", "MtMoon1F", "MtMoonB1F", "MtMoonB2F",
                 "MtMoonPokecenter", "CeruleanCity", "CeruleanGym", "CeruleanMart",
                 "CeruleanPokecenter", "BikeShop", "CeruleanTrashedHouse",
                 "Route24", "Route25", "BillsHouse"}
REQUIRED_EVENTS = {MISTY, NERD, BRIDGE_RIVAL, NUGGET, BILL, TICKET, PC,
                   *(row[0] for row in FOSSILS.values())}
NAMES = {"cerulean-natural", "cerulean-continue", "cerulean-supplementary"}
CASES = {"ticket-full-retry", "fossil-full-retry", "tm11-full-retry", "blackout"}
BOUNDS = {"seed": (-2147483648, 2147483647), "max_actions": (1, 20000),
          "max_steps": (1, 5000), "max_encounters": (1, 64), "training_level": (8, 20),
          "max_training_battles": (1, 256), "max_capture_attempts": (1, 24),
          "max_blackouts": (0, 2), "max_transitions": (1, 128)}
FULL_BAG = ("potion", "superPotion", "hyperPotion", "maxPotion", "fullRestore",
            "revive", "maxRevive", "antidote", "burnHeal", "iceHeal", "awakening",
            "parlyzHeal", "fullHeal", "ether", "maxEther", "elixir", "maxElixir",
            "pokeBall", "greatBall", "ultraBall")


def validate_config(config):
    allowed = set(BOUNDS) | {"name", "starter", "fossil", "evolution_policy", "case", "supplementary"}
    if not isinstance(config, dict) or set(config) - allowed or config.get("name") not in NAMES:
        raise ProtocolError("unknown or malformed Cerulean journey")
    for name, (low, high) in BOUNDS.items():
        if name in config and (type(config[name]) is not int or not low <= config[name] <= high):
            raise ProtocolError("invalid bounded Cerulean option: " + name)
    if config.get("starter", "squirtle") not in FAMILIES or config.get("fossil", "dome") not in FOSSILS:
        raise ProtocolError("Cerulean requires an original starter and a source fossil choice")
    if config.get("evolution_policy", "accept") not in {"accept", "cancel"}:
        raise ProtocolError("invalid evolution policy")
    supplementary = config["name"] == "cerulean-supplementary"
    if supplementary != (config.get("supplementary") is True):
        raise ProtocolError("supplementary fixtures must be explicitly classified")
    if supplementary and config.get("case") not in CASES or not supplementary and "case" in config:
        raise ProtocolError("invalid Cerulean supplementary case")


def validate_process_journey(config, index, previous):
    """Root restart validator delegates only these names here."""
    validate_config(config)
    if config["name"] == "cerulean-supplementary":
        raise ProtocolError("supplementary case is not a natural restart journey")
    if config["name"] == "cerulean-natural" and index != 0:
        raise ProtocolError("Cerulean New Game must be first process")
    if config["name"] == "cerulean-continue":
        if index == 0 or previous.get("name") not in {"cerulean-natural", "cerulean-continue"}:
            raise ProtocolError("Cerulean Continue requires a prior Cerulean receipt")
        for key in ("starter", "fossil"):
            if key in config and config[key] != previous.get(key, {"starter": "squirtle", "fossil": "dome"}[key]):
                raise ProtocolError("Continue configuration changes saved " + key)


# Canonical current SessionCodec envelope, not a selected quest-state DTO.
CODEC_FIELDS = {"version", "pokemonEncoding", "title", "intro", "questFlags", "trainerFlags",
                "pokedex", "location", "checkpoint", "world", "party", "storage", "inventory",
                "rng", "worldMotion", "itemStorage"}


def validate_boundary_payload(payload):
    if not isinstance(payload, dict) or set(payload) != CODEC_FIELDS:
        raise ProtocolError("incomplete canonical Save/Continue payload")
    if type(payload["version"]) is not int or payload["version"] < 1 or payload["pokemonEncoding"] != "decimal-counters-v1":
        raise ProtocolError("invalid canonical Save/Continue encoding")
    owners = CODEC_FIELDS - {"version", "pokemonEncoding", "questFlags", "trainerFlags"}
    if any(not isinstance(payload[field], dict) for field in owners):
        raise ProtocolError("invalid canonical Save/Continue owner record")
    for field in ("questFlags", "trainerFlags"):
        value = payload[field]
        # The SDK encodes an empty Lua table as []; preserve the wire payload
        # exactly and accept only that empty-map representation.
        if value == []:
            continue
        if not isinstance(value, dict) or any(type(flag) is not bool for flag in value.values()):
            raise ProtocolError("invalid canonical Save/Continue flag record")


def validate_receipt_state(state):
    fields = {"starter", "fossil", "zone_id", "player", "flags", "inventory", "party", "checkpoint", "codec"}
    if not isinstance(state, dict) or set(state) != fields:
        raise ProtocolError("malformed Cerulean saved receipt state")
    if state["starter"] not in FAMILIES or state["fossil"] not in FOSSILS or not isinstance(state["zone_id"], str):
        raise ProtocolError("invalid Cerulean saved identity")
    for name in ("player", "flags", "inventory", "party", "checkpoint", "codec"):
        if not isinstance(state[name], dict):
            raise ProtocolError("invalid Cerulean saved " + name)
    for name in ("x", "y"):
        if type(state["player"].get(name)) is not int or state["player"][name] < 0:
            raise ProtocolError("invalid saved player coordinate")
    if state["player"].get("facing") not in DIRECTIONS or not state["codec"]:
        raise ProtocolError("missing saved facing/codec payload")
    validate_boundary_payload(state["codec"])
    for group in state["flags"].values():
        boolean_map(group, "saved flags")


class StagedSource:
    def __init__(self, build):
        self.build = Path(build)
        self.manifest = json.loads((self.build / "source-manifest.json").read_text())

    def read(self, relative):
        path = Path(relative)
        if path.is_absolute() or ".." in path.parts:
            raise ProtocolError("unsafe staged source dependency")
        target = self.build / "Source" / path
        if not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest() != self.manifest.get(relative):
            raise ProtocolError("missing/changed staged source dependency: " + relative)
        value = json.loads(target.read_text())
        if value.get("schema") != 1 or value.get("source_revision") != REVISION:
            raise ProtocolError("unverified staged source record: " + relative)
        return value


def source_models(source):
    """Decode the shared importer's compiled cache; reuse its path/ledge solver."""
    manifest = source.read("data/sourceMaps.json")
    compact = source.read("data/sourceMapCache/compact.json")
    digest = source.manifest["data/sourceMaps.json"]
    if compact["manifest_sha256"] != digest or set(compact["maps"]) != set(manifest["maps"]):
        raise ProtocolError("runtime map cache differs from active source manifest")
    models = load_geometry(source.build)
    for name, entry in manifest["maps"].items():
        raw = source.read(entry["path"])
        desc = compact["maps"][name]
        for field in ("id", "key", "width", "height", "padding", "source_sha256"):
            if desc[field] != entry[field]:
                raise ProtocolError("source descriptor disagreement: " + name + ":" + field)
        if source.manifest[entry["path"]] != entry["source_sha256"] or raw["id"] != entry["id"]:
            raise ProtocolError("source map identity disagreement: " + name)
        if len(desc["tile_rows"]) != entry["height"] or any(len(row) != entry["width"] * 2 for row in desc["tile_rows"]):
            raise ProtocolError("malformed source cache tile dimensions")
        if any(not 1 <= int(row[x:x + 2], 16) <= len(desc["palette"])
               for row in desc["tile_rows"] for x in range(0, len(row), 2)):
            raise ProtocolError("malformed source cache palette index")
        tiles = [[compact["tiles"][desc["palette"][int(row[x:x + 2], 16) - 1]]
                  for x in range(0, len(row), 2)] for row in desc["tile_rows"]]
        collision = [[1 if str(y * entry["width"] + x + 1) in desc["blocked"] else tile["collision"]
                      for x, tile in enumerate(row)] for y, row in enumerate(tiles)]
        events = {kind: [dict(e, x=e["x"] + entry["padding"]) for e in values]
                  for kind, values in raw["events"].items()}
        model = SourceGeometry(entry["id"], collision,
                               [[t["terrain"]["grass"] for t in row] for row in tiles],
                               [[t["terrain"]["foot_tile"] for t in row] for row in tiles],
                               raw["directional_rules"]["ledges"], raw["directional_rules"]["forbidden_tile_pairs"], events)
        if (model.width, model.height) != (entry["width"], entry["height"]):
            raise ProtocolError("source cache dimensions disagree")
        model.source_data, model.descriptor = raw, desc
        model.padding, model.counter_feet = entry["padding"], tuple(raw["tileset"]["counter_tiles"])
        models[entry["id"]] = model
    return models, manifest, compact["door_tiles"]


def validate_export(export, source):
    """Validate a root-produced read-only owner projection, never parse Lua."""
    fields = {"schema", "source_revision", "sources", "events", "trainers", "rivals", "shops",
              "session_codec", "bill_pc_player"}
    if (not isinstance(export, dict) or set(export) != fields
            or export.get("schema") != 1 or export.get("source_revision") != REVISION):
        raise ProtocolError("malformed Cerulean owner projection")
    if any(not isinstance(export[key], dict) for key in ("sources", "trainers", "rivals", "shops")):
        raise ProtocolError("malformed Cerulean owner collections")
    events = export["events"]
    stable = re.compile(r"pokered:[A-Z0-9_]+:(?:(?:objects|background_events|hidden_events|hidden):[1-9][0-9]*|script:[a-z-]+)$")
    if (not isinstance(events, list)
            or any(not isinstance(value, str) or not stable.fullmatch(value) for value in events)
            or len(events) != len(set(events))):
        raise ProtocolError("invalid or duplicate registered event ID")
    for stable_id, definition in export["trainers"].items():
        if (not isinstance(definition, dict) or not stable.fullmatch(stable_id)
                or definition.get("id") != stable_id or not definition.get("party")
                or type(definition.get("payout")) is not int):
            raise ProtocolError("invalid projected trainer definition")
    if (set(export["rivals"]) != {BRIDGE_RIVAL, sid("ROUTE_22", 1)}
            or any(set(variants) != set(FAMILIES) for variants in export["rivals"].values())):
        raise ProtocolError("missing six registered rival counter teams")
    for relative, digest in export["sources"].items():
        path_parts = Path(relative)
        if path_parts.is_absolute() or ".." in path_parts.parts or relative == "data/ceruleanJourney.json":
            raise ProtocolError("unsafe or recursive owner source dependency")
        if source.manifest.get(relative) != digest:
            raise ProtocolError("Cerulean owner projection has stale source: " + relative)
        path = source.build / "original-main.lua" if relative == "main.lua" else source.build / "Source" / relative
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise ProtocolError("Cerulean owner projection source bytes changed")
    for required in ("data/sourceMaps.json", "domain/sessionCodec.lua", "data/items.lua",
                     "data/sourceSlice/trainers.json", "data/ceruleanStory/events.json"):
        if required not in export["sources"]:
            raise ProtocolError("owner projection omits source: " + required)
    missing = REQUIRED_EVENTS - set(export["events"])
    for trainer in (MISTY, NERD, NUGGET):
        if trainer not in export["trainers"]:
            missing.add(trainer)
    variants = export["rivals"].get(BRIDGE_RIVAL, {})
    if set(variants) != set(FAMILIES):
        missing.add(BRIDGE_RIVAL + ":all-starter-teams")
    if missing:
        raise ProtocolError("missing root story integration: " + ", ".join(sorted(missing)))
    if type(export["session_codec"]) is not int or export["session_codec"] < 1:
        raise ProtocolError("missing root SessionCodec version")
    return export


def connection_projection(models, model, point, direction):
    cardinal = {"up": "north", "down": "south", "left": "west", "right": "east"}
    headers = [h for h in model.source_data["connections"] if h["direction"] == cardinal[direction]]
    if len(headers) != 1 or cardinal[direction] in model.descriptor["blocked_connections"]:
        raise ProtocolError("missing/blocked source header connection")
    header = headers[0]
    target = next((m for m in models.values() if getattr(m, "source_data", {}).get("name") == header["target_header"]), None)
    if target is None:
        raise ProtocolError("source connection target is not staged")
    x, y = point
    if direction in {"up", "down"}:
        edge = 0 if direction == "up" else model.height - 1
        dest = (x - model.padding + header["entry_lateral_adjustment_cells"] + target.padding,
                target.height - 1 if direction == "up" else 0)
        on_edge = y == edge
    else:
        edge = 0 if direction == "left" else model.width - 1
        dest = (target.width - 1 if direction == "left" else 0,
                y + header["entry_lateral_adjustment_cells"])
        on_edge = x == edge
    if not on_edge or not target.inside(dest) or target.collision[dest[1]][dest[0]]:
        raise ProtocolError("source connection has no passable edge arrival")
    return target.name, dest


class CeruleanJourney(BrockJourney):
    def __init__(self, client, evidence, config, build_evidence=None, capture_dir=None):
        validate_config(config)
        super().__init__(client, evidence, config, build_evidence, capture_dir)
        self.stage = "brock"
        self.summary.update(driver_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                            milestone="5.3", source_receipts=[], rewards=[], transitions=[])

    def dependencies(self):
        if not hasattr(BrockJourney, "advance_event") or not hasattr(BrockJourney, "require_shop_stock"):
            raise ProtocolError("missing root host API integration: apply cerulean/root-registration.patch")
        super().dependencies()
        source = StagedSource(self.build_evidence)
        self.models, self.map_manifest, self.doors = source_models(source)
        missing = REQUIRED_MAPS - set(self.map_manifest["maps"])
        if missing:
            raise ProtocolError("missing root map integration: " + ", ".join(sorted(missing)))
        self.export = validate_export(source.read("data/ceruleanJourney.json"), source)
        self.source_trainers.update(self.export["trainers"])
        self.source_trainers[BRIDGE_RIVAL] = self.export["rivals"][BRIDGE_RIVAL][self.starter]
        self.scenes = source.read("data/ceruleanStory/scenes.json")
        observed = self.observe("owners")
        if observed != {"kind": "owners", "valid": True, "version": self.export["session_codec"]}:
            raise ProtocolError("actual registered owners did not qualify")
        self.summary["cerulean_dependencies"] = {"build_id": self.client.identity["build_id"],
            "source_revision": REVISION, "owner_export_sha256": source.manifest["data/ceruleanJourney.json"],
            "status": "host contracts only; native and visual acceptance pending"}
        atomic_json(self.evidence / "cerulean-dependencies.json", self.summary["cerulean_dependencies"])

    def observe(self, kind):
        # Read-only request, charged to the same finite semantic action budget.
        # Keep the large payload out of self.state and 30 FPS frame snapshots.
        self.actions += 1
        if self.actions > self.config.get("max_actions", 6000):
            raise ProtocolError("Cerulean observation action bound exceeded")
        result = self.client.send([{"op": "observe", "args": [kind]}], timeout=60, max_frames=1800)
        self.state = result["snapshot"]
        rows = result.get("results")
        if not isinstance(rows, list) or len(rows) != 1 or rows[0].get("op") != "observe" or rows[0].get("status") != "ok":
            raise ProtocolError("missing explicit read-only observation result")
        value = rows[0].get("observation")
        if not isinstance(value, dict) or value.get("kind") != kind:
            raise ProtocolError("wrong read-only observation kind")
        return value

    def codec_guard(self, boundary=None):
        codec = self.observe(boundary or "validate")
        if codec.get("version") != self.export["session_codec"]:
            raise ProtocolError("missing root read-only SessionCodec diagnostic/version")
        if codec.get("valid") is not True or codec.get("roundtrip_equal") is not True:
            raise ProtocolError("actual SessionCodec validation/roundtrip guard failed")
        if boundary:
            if not isinstance(codec.get("payload"), dict) or not codec["payload"]:
                raise ProtocolError("missing complete Save/Continue boundary payload")
            validate_boundary_payload(codec["payload"])
            if codec["payload"]["version"] != self.export["session_codec"]:
                raise ProtocolError("boundary payload codec version differs")
            return copy.deepcopy(codec["payload"])
        if "payload" in codec:
            raise ProtocolError("fresh validation must not masquerade as a boundary receipt")
        return None

    def save(self):
        super().save()
        self.boundary_payload = self.codec_guard("saved")


    def advance_event(self, stop_phase=None):
        # Called by the small root Brock drain hook. Everything else stays with
        # the reviewed bounded battle/dialog/learning/evolution implementation.
        if self.state.get("root") != "event" or lookup(self.state, "event.phase") != "story-choice":
            return False
        event_id = lookup(self.state, "event.id")
        if event_id not in {BILL, NUGGET, *(row[0] for row in FOSSILS.values())}:
            raise ProtocolError("unplanned stable story choice: " + str(event_id))
        if sequence(lookup(self.state, "event.menu.options"), "event.menu.options") != ["YES", "NO"]:
            raise ProtocolError("source scene requires actual YES/NO menu")
        self.select("event.menu.selected", 1 if event_id != NUGGET else 2)
        self.send("press a")
        return True

    def project(self, direction):
        if not hasattr(self.model(), "descriptor"):
            return super().project(direction)
        # The reviewed authored Pallet seam is deliberately outside the source
        # manifest. Keep Parcel/Brock's adapter as its sole geometry owner.
        if self.state["zone_id"] == "pokered:ROUTE_1" and direction == "down":
            return super().project(direction)
        return connection_projection(self.models, self.model(), self.position(), direction)

    def warp_projection(self, event):
        return self.project_warp(self.model(), event)

    def project_warp(self, model, event):
        if not hasattr(model, "descriptor"):
            return super().warp_projection(event)
        destination = event["destination"]
        constant = destination.get("map")
        if destination["kind"] == "last_outdoor_map":
            name = model.descriptor["last_outdoor"]
            constant = self.models[self.map_manifest["maps"][name]["id"]].source_data["source_map_constant"]
        target = next((m for m in self.models.values() if getattr(m, "source_data", {}).get("source_map_constant") == constant), None)
        if target is None:
            raise ProtocolError("unsupported staged warp target: " + str(constant))
        index = destination["warp_index"]
        arrival = next((e for e in target.events["warps"] if e["source_index"] == index), None)
        if arrival is None:
            raise ProtocolError("staged destination warp index absent")
        x, y = arrival["x"], arrival["y"]
        if target.feet[y][x] in self.doors.get(target.source_data["tileset"]["constant"], []):
            y += 1
        if not target.inside((x, y)) or target.collision[y][x]:
            raise ProtocolError("staged warp arrival blocked")
        return target.name, (x, y)

    def portals(self, model):
        for event in model.events["warps"]:
            point = (event["x"], event["y"])
            if not model.collision[point[1]][point[0]]:
                yield point, "warp", event
        if hasattr(model, "descriptor"):
            for direction, (dx, dy) in DIRECTIONS.items():
                edge = ([(x, 0 if dy < 0 else model.height - 1) for x in range(model.width)] if dy
                        else [(0 if dx < 0 else model.width - 1, y) for y in range(model.height)])
                for point in edge:
                    if model.collision[point[1]][point[0]]:
                        continue
                    try:
                        target = connection_projection(self.models, model, point, direction)
                    except ProtocolError:
                        continue
                    yield point, "connection", (direction, target)

    def route_portal(self, target_id, goal=None):
        """Find a bounded route across floor components, not just map names.

        A B1F arrival cannot select an unrelated ladder in a disconnected B1F
        corridor. The node retains exact arrival cells and warp source indices.
        """
        start = (self.state["zone_id"], self.position())
        queue, best, serial = [(0, 0, start, [])], {start: 0}, 0
        while queue and len(best) <= 2048:
            cost, _, node, itinerary = heapq.heappop(queue)
            if cost != best[node]:
                continue
            zone, origin = node
            model = self.models[zone]
            occupied = self.occupied() if node == start else {(e["x"], e["y"]) for e in model.events["objects"]
                if e["id"] not in {row[0] for row in FOSSILS.values()} or not any(self.flag(row[2]) for row in FOSSILS.values())}
            if zone == target_id:
                try:
                    if goal is not None:
                        model.path(origin, goal, occupied)
                    return itinerary[0] if itinerary else None
                except ProtocolError:
                    pass
            for point, kind, detail in self.portals(model):
                try:
                    path = model.path(origin, {point}, occupied, {point})
                    if kind == "warp":
                        destination = self.project_warp(model, detail)
                    else:
                        destination = detail[1]
                except ProtocolError:
                    continue
                candidate = cost + len(path) + 2
                if candidate < best.get(destination, float("inf")):
                    best[destination] = candidate
                    serial += 1
                    heapq.heappush(queue, (candidate, serial, destination, itinerary + [(point, kind, detail, destination)]))
        raise ProtocolError("no bounded staged source route to " + str((target_id, goal)))

    def travel(self, target_id, goal=None):
        if isinstance(goal, tuple):
            goal = {goal}
        for _ in range(self.config.get("max_transitions", 64)):
            try:
                portal = self.route_portal(target_id, goal)
                if portal is None:
                    if goal is not None:
                        self.navigate(goal)
                    return
                point, kind, detail, destination = portal
                origin = self.state["zone_id"]
                if kind == "warp":
                    self.warp(destination[0], event_id=detail["id"])
                else:
                    self.navigate(point)
                    self.cross(detail[0], *destination)
                self.summary["transitions"].append({"from": origin, "kind": kind,
                    "source": detail["id"] if kind == "warp" else detail[0], "to": destination})
            except NaturalBlackout:
                if self.config["name"] != "cerulean-natural" or getattr(self, "blackout_probe", False):
                    raise
                self.recover_path_blackout("travel to " + target_id)
                # Replan every portal from the game's actual checkpoint pose.
        raise ProtocolError("Cerulean physical transition budget exhausted")

    def recover_path_blackout(self, context):
        try:
            self.recover_blackout()
            self.codec_guard()
        except ProtocolError as error:
            raise ProtocolError("Cerulean " + context + ": " + str(error)) from error

    def zone(self, name):
        return self.map_manifest["maps"][name]["id"]

    def battle(self, name, strategy="attack", expected=None):
        trainer_id = lookup(self.state, "event.id")
        if self.stage == "cerulean" and lookup(self.state, "battle.trainerName"):
            definition = self.source_trainers.get(trainer_id)
            observed = lookup(self.state, "event.trainer.definition")
            if not definition or observed != {"id": trainer_id, "party": definition["party"], "payout": definition["payout"]}:
                raise ProtocolError("missing/mismatched root read-only actual trainer team diagnostic: " + str(trainer_id))
        if getattr(self, "blackout_probe", False):
            expected = "loss"
        try:
            result = super().battle(name, strategy, expected)
        except NaturalBlackout:
            # Brock records the terminal outcome before raising. Retain that
            # source loss receipt too, rather than recording only later wins.
            self.record_source_outcome(trainer_id)
            raise
        self.record_source_outcome(trainer_id)
        if getattr(self, "blackout_probe", False) and lookup(self.state, "last_battle_outcome.blackout"):
            raise NaturalBlackout("supplementary actual trainer loss reached checkpoint")
        return result

    def record_source_outcome(self, trainer_id):
        if self.stage == "cerulean" and trainer_id in self.source_trainers:
            outcome = lookup(self.state, "last_battle_outcome")
            if outcome.get("trainer_id") != trainer_id:
                raise ProtocolError("actual trainer outcome lacks stable trainer receipt ID")
            self.summary["source_receipts"].append(copy.deepcopy(outcome))

    def flee(self):
        if self.stage != "cerulean":
            return super().flee()
        before_money = self.inventory()["money"]
        try:
            return super().flee()
        except ProtocolError as error:
            # Parcel's RUN driver already records the real encounter and final
            # packet, but reports a blackout as a plain ProtocolError.
            if (str(error) != "natural parcel walk interrupted by real blackout"
                    or not lookup(self.state, "last_battle_outcome.blackout")):
                raise
            outcome = copy.deepcopy(lookup(self.state, "last_battle_outcome"))
            self.summary["battles"].append({"name": "cerulean-travel-run", "trainer_id": None,
                "money_before": before_money, "outcome": outcome})
            raise NaturalBlackout("actual blackout during Cerulean RUN inputs") from error

    def fight(self, trainer_id):
        zone = self.source_trainers[trainer_id]["map_id"]
        event = next(e for e in self.models[zone].events["objects"] if e["id"] == trainer_id)
        for _ in range(self.config.get("max_blackouts", 1) + 1):
            try:
                self.travel(zone, set(self.models[zone].approaches((event["x"], event["y"]))))
                if not self.defeated(trainer_id):
                    self.interact(source_id=trainer_id)
                if not self.defeated(trainer_id) or not any(
                        r.get("trainer_id") == trainer_id and r.get("won") for r in self.summary["source_receipts"]):
                    raise ProtocolError("required actual trainer victory receipt missing: " + trainer_id)
                return
            except NaturalBlackout:
                if self.config["name"] != "cerulean-natural" or getattr(self, "blackout_probe", False):
                    raise
                self.recover_path_blackout("fight " + trainer_id)
        raise ProtocolError("Cerulean trainer retry budget exhausted: " + trainer_id)

    def heal_here(self, name):
        center = self.zone(name)
        self.travel(center)
        self.interact(source_id=center + ":objects:1", stop_phase="heal-confirm")
        self.select("event.menu.selected", 1)
        self.send("press a")
        self.drain()
        for mon in self.party():
            if mon["hp"] != mon["maxHP"] or mon["status"] not in {None, "none"} or mon["pp"] != mon["maxPP"]:
                raise ProtocolError("actual Center restoration incomplete")
        self.summary["recoveries"].append({"kind": "Center", "zone": center,
            "checkpoint": copy.deepcopy(lookup(self.state, "session.checkpoint"))})

    def reward(self, event_id, item, flag):
        before = self.quantity(item)
        self.interact(source_id=event_id)
        if not self.flag(flag) or self.quantity(item) != before + 1:
            raise ProtocolError("source reward transaction missing: " + event_id)
        self.summary["rewards"].append({"id": event_id, "item": item, "flag": flag, "quantity": self.quantity(item)})

    def require_shop_stock(self, clerk, item):
        if self.stage != "cerulean":
            return super().require_shop_stock(clerk, item)
        shop = self.export["shops"].get(clerk)
        if not shop or item not in shop["stock"] or type(shop["prices"].get(item)) is not int or shop["prices"][item] <= 0:
            raise ProtocolError("purchase missing from actual owner stock/price export")

    def stock_up(self, name):
        zone = self.zone(name)
        clerk = zone + ":objects:1"
        # Reserve a few poison cures before spending the remaining money on
        # Potions. Both are used by Brock's existing real battle Bag policy.
        for item, target in (("antidote", 3), ("potion", 15)):
            self.require_shop_stock(clerk, item)
            price = self.export["shops"][clerk]["prices"][item]
            count = min(max(0, target - self.quantity(item)), self.inventory()["money"] // price)
            if count:
                self.travel(zone)
                # Travel can earn a payout or incur a real blackout penalty.
                count = min(max(0, target - self.quantity(item)), self.inventory()["money"] // price)
                if count:
                    self.buy_item(clerk, item, count, price)

    def capture_presentation(self, label, kind):
        if self.stage == "cerulean":
            label = "cerulean-" + label
        return super().capture_presentation(label, kind)

    def fossil_exclusion(self):
        chosen = FOSSILS[self.config.get("fossil", "dome")]
        other = FOSSILS["helix" if self.config.get("fossil", "dome") == "dome" else "dome"]
        if not self.flag(chosen[2]) or self.quantity(chosen[1]) != 1 or self.flag(other[2]) or self.quantity(other[1]):
            raise ProtocolError("mutually exclusive fossil flags/inventory violated")
        if self.state["zone_id"] == self.zone("MtMoonB2F"):
            actors = {n.get("source_event_id") for n in sequence(self.state.get("npcs", []), "npcs")}
            if {chosen[0], other[0]} & actors:
                raise ProtocolError("fossil choice left a second collectible actor")

    def bill_scene(self):
        self.travel(self.zone("BillsHouse"))
        self.interact(source_id=BILL)
        if not self.flag("EVENT_BILL_SAID_USE_CELL_SEPARATOR"):
            raise ProtocolError("Bill setup integration missing")
        # The pinned hidden-event coordinates identify the PC event, not an
        # automatically walkable player pose. Root must export the production
        # dispatcher's resolved interaction pose after fixing that integration.
        pc = self.export.get("bill_pc_player")
        if not isinstance(pc, dict) or pc.get("id") != PC or pc.get("facing") not in DIRECTIONS or any(
                type(pc.get(key)) is not int for key in ("x", "y")):
            raise ProtocolError("missing root source-valid Bill PC player-pose export")
        point = (pc["x"] + self.model().padding, pc["y"])
        if not self.model().inside(point) or self.model().collision[point[1]][point[0]]:
            raise ProtocolError("missing root Bill PC integration: declared player cell is blocked in staged geometry")
        self.navigate(point)
        self.face(pc["facing"])
        self.send("press a")
        if lookup(self.state, "event.id") != PC:
            raise ProtocolError("Bill PC hidden stable-ID dispatch missing")
        self.drain()
        for flag in ("EVENT_USED_CELL_SEPARATOR_ON_BILL", "EVENT_MET_BILL", "EVENT_MET_BILL_2"):
            if not self.flag(flag):
                raise ProtocolError("Bill cell separator did not commit: " + flag)
        self.checkpoint("cerulean-bill-restored")

    def natural(self):
        super().natural()  # Retains full capture/party/medicine/evolution evidence.
        self.stage = "cerulean"
        self.summary["acceptance"] = "Brock saved; Cerulean pending"
        self.stock_up("PewterMart")
        self.travel(self.zone("Route3"))
        trainers = sorted((d for d in self.source_trainers.values() if d["map_id"] == self.zone("Route3")),
                          key=lambda d: d["source_object_index"])
        for trainer in trainers:
            self.fight(trainer["id"])
        self.heal_here("MtMoonPokecenter")
        self.travel(self.zone("MtMoon1F"))
        self.reward(sid("MT_MOON_1F", 9), "moonStone", "PICKUP:" + sid("MT_MOON_1F", 9))
        self.fight(sid("MT_MOON_B2F", 2))
        trigger = self.scenes["fossil_trigger"]
        self.travel(self.zone("MtMoonB2F"), (trigger["x"] + self.models[self.zone("MtMoonB2F")].padding, trigger["y"]))
        # Natural source positional trigger must produce the Nerd's own receipt.
        if not self.defeated(NERD) or not any(r.get("trainer_id") == NERD and r.get("won") for r in self.summary["source_receipts"]):
            raise ProtocolError("required Super Nerd positional battle integration missing")
        self.reward(*FOSSILS[self.config.get("fossil", "dome")])
        self.fossil_exclusion()
        self.checkpoint("cerulean-fossil-choice")
        self.travel(self.zone("CeruleanCity"))
        self.heal_here("CeruleanPokecenter")
        self.stock_up("CeruleanMart")
        self.fight(MISTY)
        if not all(self.flag(f) for f in ("BADGE_CASCADE", "EVENT_BEAT_MISTY", "EVENT_GOT_TM11")) or self.quantity("tm11") != 1:
            raise ProtocolError("Misty source badge/TM11 transaction incomplete")
        self.repeat_trainer(MISTY)
        self.checkpoint("cerulean-misty-badge-tm11")
        self.heal_here("CeruleanPokecenter")
        self.fight(BRIDGE_RIVAL)
        self.heal_here("CeruleanPokecenter")
        self.stock_up("CeruleanMart")
        for index in (6, 5, 4, 3, 2, 1):
            self.fight(sid("ROUTE_24", index))
        if not self.flag("EVENT_GOT_NUGGET") or self.quantity("nugget") != 1:
            raise ProtocolError("missing root Nugget Bridge gift/battle integration")
        self.checkpoint("cerulean-nugget-bridge")
        self.heal_here("CeruleanPokecenter")
        self.stock_up("CeruleanMart")
        self.travel(self.zone("Route25"))
        self.bill_scene()
        self.reward(TICKET, "ssTicket", "EVENT_GOT_SS_TICKET")
        self.interact(source_id=TICKET)
        if self.quantity("ssTicket") != 1:
            raise ProtocolError("repeated Ticket gift duplicated item")
        self.checkpoint("cerulean-ticket")
        # Revisit through real house exit; confirm the other fossil remains
        # excluded by persisted flags after scene/zone reconciliation.
        self.travel(self.zone("Route25"))
        if not self.flag("EVENT_LEFT_BILLS_HOUSE_AFTER_HELPING"):
            raise ProtocolError("Bill house departure hook missing")
        self.fossil_exclusion()
        self.save()
        self.write_receipt()
        self.summary.update(acceptance="Cerulean natural path saved; owned restart pending", natural=True,
                            forbidden_shortcuts=False)

    def receipt_state(self):
        payload = getattr(self, "boundary_payload", None)
        if not isinstance(payload, dict) or not payload:
            raise ProtocolError("receipt requires an explicitly observed actual Save/Continue")
        state = super().receipt_state()
        state.update(fossil=self.config.get("fossil", "dome"), codec=copy.deepcopy(payload))
        return state

    def write_receipt(self):
        # Brock invokes this once too; only final complete Cerulean receipts
        # are eligible for the next process.
        if self.stage != "cerulean":
            return
        packet = {"schema": 1, "kind": "cerulean-saved", **{k: self.client.identity[k] for k in ("build_id", "session_id")},
                  "state": self.receipt_state()}
        validate_receipt_state(packet["state"])
        path = self.evidence / "journey-receipt.json"
        atomic_json(path, packet)
        self.summary["receipt"] = {"path": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}

    def continue_saved(self, prior):
        if not isinstance(prior, dict) or prior.get("schema") != 1 or prior.get("kind") != "cerulean-saved" or any(
                prior.get(k) != self.client.identity[k] for k in ("build_id", "session_id")):
            raise ProtocolError("missing/wrong-build Cerulean continuation receipt")
        validate_receipt_state(prior.get("state"))
        self.starter = prior["state"].get("starter")
        if self.starter not in FAMILIES or prior["state"].get("fossil") not in FOSSILS:
            raise ProtocolError("invalid saved starter/fossil identity")
        self.config = dict(self.config, starter=self.starter, fossil=prior["state"]["fossil"])
        self.dependencies()
        self.stage = "cerulean"
        self.require(root="title", **{"title.phase": "menu"})
        options = sequence(lookup(self.state, "title.menu.options"), "title.menu.options")
        if options.count("CONTINUE") != 1:
            raise ProtocolError("title requires exactly one real CONTINUE")
        self.select("title.selected", options.index("CONTINUE") + 1)
        self.checkpoint("cerulean-title-continue")
        self.send("press a")
        self.drain()
        self.boundary_payload = self.codec_guard("loaded")
        if self.receipt_state() != prior["state"]:
            raise ProtocolError("Continue differs from immutable Cerulean receipt/SessionCodec payload")
        self.fossil_exclusion()
        if not self.flag("EVENT_GOT_SS_TICKET") or self.quantity("ssTicket") != 1 or not self.defeated(MISTY):
            raise ProtocolError("Continue lost goal 5.3 progress")
        self.checkpoint("cerulean-continued")
        self.write_receipt()
        self.summary.update(acceptance="Cerulean state continued across actual owned process restart", natural=True)

    def supplementary(self):
        self.dependencies()
        self.stage = "cerulean"
        case = self.config["case"]
        event_id = {"ticket-full-retry": TICKET, "fossil-full-retry": FOSSILS[self.config.get("fossil", "dome")][0],
                    "tm11-full-retry": MISTY, "blackout": MISTY}[case]
        setup_id = NERD if case == "fossil-full-retry" else BILL if case == "ticket-full-retry" else MISTY
        zone_id = setup_id.split(":objects:")[0]
        model = self.models[zone_id]
        event = next(e for e in model.events["objects"] if e["id"] == setup_id)
        occupied = {(e["x"], e["y"]) for e in model.events["objects"]}
        approaches = model.approaches((event["x"], event["y"]))
        entry = next((point for point in sorted(approaches) if point not in occupied), None)
        if entry is None:
            raise ProtocolError("no passable source supplementary approach")
        options = dict(zone=model.descriptor["key"], entry={"x": entry[0], "y": entry[1], "facing": approaches[entry]},
                       intro="skip", opening=False,
                       player_pokemon={"species": self.starter, "level": 1 if case == "blackout" else 40},
                       inventory={"money": 3000, "slots": [] if case == "blackout" else [{"id": item, "quantity": 1} for item in FULL_BAG]})
        if case in {"tm11-full-retry", "blackout"}:
            # Misty's only approach lies in the junior trainer's sight line.
            # Start at the normal safe spawn, then handle any real approach
            # and battle while navigating; no defeat is supplied by a fixture.
            options["entry"] = copy.deepcopy(self.map_manifest["maps"]["CeruleanGym"]["spawn"])
        if case == "blackout":
            options["player_pokemon"]["hp"] = 1
        self.initializing = True
        try:
            self.reset(**options)
        finally:
            self.initializing = False
        self.summary.update(natural=False, supplementary=True)
        if case == "blackout":
            self.allow_blackout = True
            self.heal_here("CeruleanPokecenter")
            checkpoint = copy.deepcopy(lookup(self.state, "session.checkpoint"))
            self.blackout_probe = True
            try:
                self.travel(self.zone("CeruleanGym"))
                self.interact(source_id=MISTY)
            except NaturalBlackout:
                pass
            else:
                raise ProtocolError("blackout probe completed without an actual terminal loss")
            self.blackout_probe = False
            self.recover_blackout()
            if lookup(self.state, "session.checkpoint") != checkpoint or any(self.flag(f) for f in ("BADGE_CASCADE", "EVENT_BEAT_MISTY", "EVENT_GOT_TM11")):
                raise ProtocolError("blackout changed healing checkpoint or awarded Misty progress")
            self.codec_guard()
            self.checkpoint("cerulean-supplementary-blackout")
            self.summary["acceptance"] = "supplementary actual blackout/checkpoint; not natural acceptance"
            return
        if case == "ticket-full-retry":
            self.bill_scene()
        elif case == "fossil-full-retry":
            self.fight(NERD)
        item, flag = {"ticket-full-retry": ("ssTicket", "EVENT_GOT_SS_TICKET"),
                      "fossil-full-retry": FOSSILS[self.config.get("fossil", "dome")][1:],
                      "tm11-full-retry": ("tm11", "EVENT_GOT_TM11")}[case]
        self.interact(source_id=event_id)
        if self.flag(flag) or self.quantity(item):
            raise ProtocolError("full bag consumed reward eligibility")
        if case == "tm11-full-retry" and (not self.defeated(MISTY) or not self.flag("BADGE_CASCADE")):
            raise ProtocolError("full bag lost confirmed Misty victory/badge")
        before = (self.inventory()["money"], len(self.summary["battles"]))
        self.toss_single()
        self.reward(event_id, item, flag)
        if before != (self.inventory()["money"], len(self.summary["battles"])):
            raise ProtocolError("reward retry repeated trainer payout/battle")
        if case == "fossil-full-retry":
            self.fossil_exclusion()
        elif case == "ticket-full-retry":
            self.interact(source_id=TICKET)
            if self.quantity(item) != 1:
                raise ProtocolError("Ticket retry duplicated gift")
        else:
            self.repeat_trainer(MISTY)
        self.codec_guard()
        self.checkpoint("cerulean-supplementary-" + case)
        self.summary["acceptance"] = "supplementary reward retry; not natural campaign acceptance"


def run(client, scenario, evidence, build_evidence=None, prior_receipt=None, capture_dir=None):
    journey = None
    try:
        config = scenario["journey"]
        journey = CeruleanJourney(client, evidence, config, build_evidence, capture_dir)
        if config["name"] == "cerulean-natural":
            journey.natural()
        elif config["name"] == "cerulean-continue":
            journey.continue_saved(prior_receipt)
        else:
            journey.supplementary()
    except BaseException as error:
        summary = journey.summary if journey else {"schema": 1, "acceptance": "pending"}
        summary.update(ok=False, error=str(error), journey_outcome="failed", last_snapshot=journey.state if journey else {})
        atomic_json(Path(evidence) / "journey-summary.json", summary)
        raise
    journey.summary.update(ok=True, journey_outcome="complete", last_snapshot=journey.state)
    atomic_json(Path(evidence) / "journey-summary.json", journey.summary)
    return journey.summary
