"""Real-input walk onto Celadon Dept. Store 4F, buy LINK CABLE, evolve Kadabra.

The session is a skipped-intro fixture with no Hall of Fame flag and no cable
already in the bag. The only added item is the one bought from the 4F clerk.
"""
import json
from pathlib import Path

from tools.harness.journeys import Journey, lookup
from tools.harness.parcel_journey import Geometry
from tools.harness.protocol import ProtocolError, atomic_json

STAIRS = "kanto_celadon_mart_5f"
FLOOR = "kanto_celadon_mart_4f"
CLERK = (5, 7)
# The clerk stands behind the counter. The walkable cell north of it faces
# down across the counter tile, which is how a mart purchase reaches him.
APPROACHES = {(5, 5): "down"}
# Source wander is four cells of LEFT_RIGHT. Treat the whole span as occupied
# so a pacing youngster or super nerd cannot step into the route.
WANDER = {(x, 2) for x in range(1, 10)} | {(x, 5) for x in range(11, 20)}
CHAMPION = "session.flags.quest.TOGGLE_CERULEAN_CAVE_GUY"


def floor_model():
    path = Path(__file__).resolve().parents[2] / "Source/data/midgameEast/CeladonMart4F.json"
    data = json.loads(path.read_text())
    return Geometry("CeladonMart4F", data["collision"], events=data["events"])


class LinkCableJourney(Journey):
    def __init__(self, client, evidence, config):
        super().__init__(client, evidence, config)
        self.model = floor_model()

    def position(self):
        return self.state["player"]["x"], self.state["player"]["y"]

    def occupied(self):
        npcs = self.state.get("npcs") or []
        if isinstance(npcs, dict):
            npcs = []
        return {(npc["x"], npc["y"]) for npc in npcs} | WANDER

    def before_hall(self):
        if lookup(self.state, CHAMPION) is True:
            raise ProtocolError("LINK CABLE was used after the Hall of Fame flag")

    def select_menu(self, path, index):
        for _ in range(8):
            current = lookup(self.state, path)
            if current == index:
                return
            self.send("press down")
        raise ProtocolError(f"menu {path} never reached {index}")

    def enter_floor(self):
        self.reset(
            intro="skip", opening=False, seed=self.config.get("seed", 42),
            zone=STAIRS,
            entry={"x": 16, "y": 2, "facing": "up"},
            player_pokemon={"species": "kadabra", "level": 16},
            inventory={"money": 0, "slots": []},
        )
        self.require(
            zone=STAIRS, root="overworld",
            **{"player.x": 16, "player.y": 2, "player.facing": "up",
               "player.settled": True, "pokemon.species": "kadabra",
               "inventory.money": 0, "inventory.quantities.linkCable": 0})
        self.before_hall()
        self.send("press up", "wait 30")
        self.await_value("zone", FLOOR, frames=240)
        self.await_value("overworld", "explore", frames=120)
        self.await_value("player.settled", True, frames=60)
        self.require(zone=FLOOR, zone_id="pokered:CELADON_MART_4F")
        self.send("shot link-cable-floor")
        self.checkpoint("celadon-4f")

    def walk_to_clerk(self):
        goals = set(APPROACHES)
        for _ in range(40):
            if self.position() in goals:
                facing = APPROACHES[self.position()]
                self.face(facing)
                return
            try:
                route = self.model.path(self.position(), goals, self.occupied())
            except ProtocolError:
                self.send("wait 8")
                continue
            step = route[0]
            self.send("press " + step.direction, "wait 9")
            self.require(
                root="overworld", zone=FLOOR,
                **{"player.x": step.destination[0], "player.y": step.destination[1],
                   "player.settled": True})
        raise ProtocolError("could not reach the Celadon 4F clerk")

    def buy(self):
        self.before_hall()
        self.send("press a")
        self.await_value("root", "shop", frames=180)
        self.require(**{"shop.phase": "mode"})
        self.send("press a")
        self.require(**{"shop.phase": "browse"})
        seen = []
        for _ in range(8):
            item = lookup(self.state, "shop.item")
            if item == "linkCable":
                break
            if item in seen:
                raise ProtocolError("LINK CABLE is not on the Celadon 4F counter: " + ", ".join(seen))
            seen.append(item)
            self.send("press down")
        else:
            raise ProtocolError("LINK CABLE is not on the Celadon 4F counter: " + ", ".join(seen))
        self.send("shot link-cable-shelf")
        self.send("press a")
        self.require(**{"shop.phase": "quantity", "shop.quantity": 1, "shop.item": "linkCable"})
        self.send("press a")
        self.require(**{"shop.phase": "confirm"})
        self.send("press a")
        self.require(**{"shop.phase": "result"})
        self.require(**{"inventory.quantities.linkCable": 1, "inventory.money": 0})
        self.send("press a")
        self.require(**{"shop.phase": "browse"})
        self.send("press b")
        self.require(**{"shop.phase": "mode"})
        self.select_menu("shop.menu.selected", 3)
        self.send("press a")
        self.await_value("root", "overworld", frames=180)
        self.checkpoint("bought-link-cable")

    def evolve(self):
        self.before_hall()
        self.require(**{"pokemon.species": "kadabra", "inventory.quantities.linkCable": 1})
        self.send("press b")
        self.await_value("root", "pause", frames=180)
        options = lookup(self.state, "pause.menu.options") or []
        if "ITEM" not in options:
            raise ProtocolError("pause menu has no ITEM: " + repr(options))
        self.select_menu("pause.menu.selected", options.index("ITEM") + 1)
        self.send("press a")
        self.await_value("root", "bag", frames=180)
        self.require(**{"bag.phase": "list"})
        self.send("press a")
        self.require(**{"bag.phase": "actions"})
        self.send("press a")
        self.await_value("root", "party", frames=180)
        self.send("press a")
        self.await_value("root", "evolution", frames=180)
        self.require(**{"evolution.kind": "stone", "evolution.can_cancel": False, "pokemon.species": "kadabra"})
        self.await_value("evolution.dialog_ready", True, frames=180)
        # The finished line has to sit for 10 frames before a new A turns the page.
        self.send("wait 12", "shot link-cable-before", "press a")
        self.await_value("evolution.phase", "animate", frames=180)
        self.send("record link-cable-evolve 80")
        self.await_value("evolution.done", True, frames=240)
        self.require(**{"pokemon.species": "alakazam", "inventory.quantities.linkCable": 0, "inventory.money": 0})
        self.before_hall()
        self.await_value("evolution.dialog_ready", True, frames=180)
        self.send("wait 12", "shot link-cable-after", "press a")
        self.await_value("root", "bag", frames=180)
        self.checkpoint("alakazam")

    def play(self):
        self.enter_floor()
        self.walk_to_clerk()
        self.buy()
        self.evolve()


def run(client, scenario, evidence_dir):
    journey = None
    try:
        config = scenario.get("journey")
        if not isinstance(config, dict) or config.get("name") != "link-cable-celadon":
            raise ProtocolError("link-cable journey name required")
        journey = LinkCableJourney(client, evidence_dir, config)
        journey.play()
    except BaseException as error:
        summary = journey.summary if journey else {"schema": 1}
        summary.update(ok=False, error=str(error), last_snapshot=journey.state if journey else {})
        atomic_json(Path(evidence_dir) / "journey-summary.json", summary)
        raise
    journey.summary.update(ok=True, last_snapshot=journey.state)
    atomic_json(Path(evidence_dir) / "journey-summary.json", journey.summary)
    return journey.summary
