"""Charmander golden path on the Simulator.

New Game is the title menu. After that, walking, battles, shops and
Save use the existing button journey. This file does not send a fixture,
a teleport, the debug menu, or an HP edit.
"""
import argparse
import hashlib
import json
import os
import shutil
import signal
import subprocess
import sys
import time
import unittest
import uuid
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
if str(REPO) not in sys.path:
    sys.path.insert(0, str(REPO))

from tools.harness.brock_journey import BROCK, FOREST, JR, MAPS, BrockJourney
from tools.harness.journeys import lookup
from tools.harness.parcel_journey import NAMES as PARCEL_NAMES
from tools.harness.parcel_journey import sequence
from tools.harness.protocol import ProtocolError

# Leave several thousand button presses so the pause Save finishes
# before ParcelJourney's hard cap of 20000.
# The Simulator's RSS reaches the VM limit in about forty minutes.
# Pause sooner so a new session continues the earned save before that stall.
ACTION_PAUSE = 8000

FORBIDDEN_OPS = {"fixture", "warp", "debug", "intro", "seed", "battle", "encounters", "face"}
# Oddish, Bellsprout, and Pikachu resist Misty's water attacks.
WATER_COUNTERS = {"oddish", "bellsprout", "pikachu"}
LCD_OFFSET = (18, 45)
LCD_SIZE = (400, 240)
EXPECTED_WINDOW = (486, 700)
# The Simulator window paints the 1-bit LCD as these two colors. A threshold
# puts them back to 0 and 255 before the encode, so the file is the framebuffer.
LCD_WINDOW_WHITE = (214, 211, 203)
LCD_WINDOW_BLACK = (49, 46, 40)
# gte() returns 0 or 1. The backslash keeps the comma inside the ffmpeg expression.
LCD_CLIP_FILTER = (
    "lutrgb=r='gte(val\\,128)*255':g='gte(val\\,128)*255':b='gte(val\\,128)*255',format=gray"
)


def lcd_clip_output_args(path):
    """Full-range lossless gray. No 4:2:0 subsample and no TV-range shift."""
    return [
        "-an", "-vf", LCD_CLIP_FILTER,
        "-c:v", "libx264", "-crf", "0", "-preset", "veryfast",
        "-pix_fmt", "gray", "-color_range", "pc",
        str(path),
    ]


def lcd_clip_command(display, origin_x, origin_y, seconds, path):
    """Grab the LCD 1:1. The size matches the panel, so the scaler never runs."""
    return [
        "ffmpeg", "-y", "-loglevel", "error",
        "-f", "x11grab", "-draw_mouse", "0",
        "-video_size", f"{LCD_SIZE[0]}x{LCD_SIZE[1]}",
        "-framerate", "30",
        "-i", f"{display}.0+{origin_x},{origin_y}",
        "-t", str(seconds),
        *lcd_clip_output_args(path),
    ]


def command_op(command):
    if isinstance(command, str):
        return command.split()[0]
    if isinstance(command, dict):
        return command.get("op")
    raise ProtocolError("charmander command is not a string or object")


def real_input(commands):
    """Every command is a button, a wait, or a read of the live screen."""
    ops = []
    for command in commands:
        op = command_op(command)
        if op in FORBIDDEN_OPS:
            raise ProtocolError("charmander path refuses " + op)
        ops.append(op)
    return ops


def ball_press(commands, state):
    """A on a lab ball is an overworld gesture. It completes on the release frame."""
    if commands != ("press a",):
        return commands
    if state.get("root") != "overworld" or state.get("zone") != "oaks_lab":
        return commands
    if lookup(state, "story.stage") != "choose" or lookup(state, "pokemon.present") is not False:
        return commands
    return ("press a", "wait 2")


def pause_press(commands, state):
    """Let a previous A gesture finish before B asks for the pause menu."""
    if commands != ("press b",) or state.get("root") != "overworld":
        return commands
    return ("wait 4", "press b", "wait 2")


class ActionPause(ProtocolError):
    """The live save was written. A new session can continue it."""


def needs_action_pause(actions, state, stopping):
    state = state or {}
    # A wild iris is still the overworld root. Saving there abandons the battle.
    phase = state.get("overworld")
    exploring = phase in (None, "explore")
    return (not stopping) and actions >= ACTION_PAUSE and state.get("root") == "overworld" and exploring


def key_fight(name, trainer_id):
    """Game-screen clips for the rival and each badge fight."""
    label = str(name or "")
    trainer = str(trainer_id or "")
    if label == "rival":
        return "rival"
    if trainer == "pokered:PEWTER_GYM:objects:2":
        return "pewter-jr"
    if trainer == "pokered:PEWTER_GYM:objects:1" or label.startswith("brock"):
        return "badge-boulder"
    if trainer == "pokered:CERULEAN_GYM:objects:1" or label.startswith("misty"):
        return "badge-cascade"
    if trainer == "pokered:VERMILION_GYM:objects:1" or label.startswith("surge"):
        return "badge-thunder"
    return None


class CharmanderRun(BrockJourney):
    """Title NEW GAME, then the inherited real-button Brock route."""

    def reset(self, **options):
        if self.initialized:
            raise ProtocolError("charmander path refuses a second start")
        if options:
            raise ProtocolError("charmander path refuses fixture options")
        self.initialized = True
        if self.state.get("root") != "title":
            raise ProtocolError("new game must start on the title menu")
        self._choose_new_game()
        self.require(
            root="dialog", zone="reds_house_2f",
            **{"story.stage": "pre_oak", "pokemon.present": False,
               "player.x": 5, "player.y": 3})

    def _choose_new_game(self):
        self.send({"op": "await", "path": "title.phase", "equals": "menu", "frames": 1200})
        options = sequence(lookup(self.state, "title.menu.options"), "title options")
        if "CONTINUE" in options or "NEW GAME" not in options:
            raise ProtocolError("fresh title must offer NEW GAME and no CONTINUE")
        self.select("title.menu.selected", options.index("NEW GAME") + 1)
        self.send("press a")
        self.send({"op": "await", "path": "title.phase", "equals": "confirm-new", "frames": 60})
        confirm = sequence(lookup(self.state, "title.menu.options"), "confirm options")
        if confirm != ["NO", "YES"]:
            raise ProtocolError("new game confirmation is not NO/YES")
        self.select("title.menu.selected", 2)
        self.send("press a")
        self.send({"op": "await", "path": "root", "equals": "dialog", "frames": 180})
        self.send({"op": "await", "path": "zone", "equals": "reds_house_2f", "frames": 180})

    def send(self, *commands):
        if needs_action_pause(self.actions, self.state, getattr(self, "_stopping", False)):
            self._save_for_next_session()
            raise ActionPause("charmander saved so the next session can continue")
        commands = pause_press(ball_press(commands, self.state), self.state)
        real_input(commands)
        return super().send(*commands)

    def _save_for_next_session(self):
        """Finish a queued grass battle, then pause Save from the overworld."""
        self._stopping = True
        super().send("wait 12")
        if self.state.get("root") != "overworld":
            self._stopping = False
            self.drain()
            self._stopping = True
        if self.state.get("root") != "overworld":
            raise ProtocolError("action pause could not return to the overworld")
        self.save()
        closer = getattr(self, "close_recordings", None)
        if closer:
            closer()

    def training_battle(self):
        super().training_battle()
        count = len(self.summary.get("training") or [])
        if count % 10 == 0 and self.state.get("root") == "overworld" and not getattr(self, "_stopping", False):
            self._finish_wild_iris()
            if self.state.get("root") == "overworld" and self.state.get("overworld") in (None, "explore"):
                self.save()

    def step(self, step):
        self._finish_wild_iris()
        return super().step(step)

    def interact(self, name=None, source_id=None, stop_phase=None):
        self._finish_wild_iris()
        return super().interact(name, source_id, stop_phase)

    def _finish_wild_iris(self):
        """A grass step opens the battle iris before the next step may require explore."""
        if getattr(self, "_finishing_iris", False):
            return
        self._finishing_iris = True
        try:
            for _ in range(8):
                if self.state.get("root") != "overworld" or self.state.get("overworld") != "irisOut":
                    return
                self.send("wait 15")
                if self.state.get("root") == "battle" or self.state.get("overworld") == "irisOut":
                    super().drain()
            if self.state.get("overworld") == "irisOut":
                raise ProtocolError("wild iris never opened the battle")
        finally:
            self._finishing_iris = False

    def continue_earned(self):
        """Title CONTINUE, then the Brock steps the save has not finished."""
        self.dependencies()
        self.send({"op": "await", "path": "title.phase", "equals": "menu", "frames": 1200})
        options = sequence(lookup(self.state, "title.menu.options"), "title options")
        if options.count("CONTINUE") != 1:
            raise ProtocolError("earned save did not offer CONTINUE")
        self.select("title.menu.selected", options.index("CONTINUE") + 1)
        self.send("press a", "wait 8")
        for _ in range(40):
            if self.state.get("root") in {"overworld", "dialog", "event"}:
                break
            self.send("wait 8")
        else:
            raise ProtocolError("continue did not leave the title")
        self.drain()
        if not self.flag("EVENT_GOT_POKEDEX"):
            raise ProtocolError("continued save has not received the Pokedex")
        self.initialized = True
        self.brock_after_parcel()

    def _starter_level(self):
        return self.party()[self.starter_index() - 1]["level"]

    def _to_training_grass(self):
        zone = self.state.get("zone_id")
        if zone in {MAPS["Route2"], MAPS["ViridianForest"]}:
            return
        if zone == PARCEL_NAMES["ViridianPokecenter"]:
            self.warp(PARCEL_NAMES["ViridianCity"])
        elif zone == MAPS["PewterPokecenter"]:
            self.warp(MAPS["PewterCity"])
        self.reach_training_zone(MAPS["Route2"])

    def brock_after_parcel(self):
        """Finish Boulder Badge from whatever the earned save already did."""
        if self.defeated(BROCK) and self.flag("BADGE_BOULDER"):
            self.after_boulder()
            return
        if not all(self.defeated(trainer) for trainer in FOREST):
            if len(self.party()) < 2 and self.quantity("pokeBall") < 5:
                if self.state.get("zone_id") == PARCEL_NAMES["ViridianPokecenter"]:
                    self.warp(PARCEL_NAMES["ViridianCity"])
                self.warp(PARCEL_NAMES["ViridianMart"])
                self.buy_item("pokered:VIRIDIAN_MART:objects:1", "antidote", 3, 100)
                self.buy_item("pokered:VIRIDIAN_MART:objects:1", "pokeBall", 5, 200)
                self.warp(PARCEL_NAMES["ViridianCity"])
            self._to_training_grass()
            if self._starter_level() < 8 or len(self.party()) < 2:
                self.train_to(8, capture=len(self.party()) < 2)
            if self.state.get("zone_id") != MAPS["ViridianForest"]:
                self.warp(MAPS["ViridianForestSouthGate"])
                self.warp(MAPS["ViridianForest"])
            self.interact(source_id="pokered:VIRIDIAN_FOREST:objects:6")
            for trainer in FOREST:
                self.field_recover()
                if not self.defeated(trainer):
                    self.defeat_source(trainer)
                if not self.defeated(trainer):
                    raise ProtocolError("source Forest trainer was not actually defeated: " + trainer)
                self.repeat_trainer(trainer)
                self.checkpoint("forest-defeated-" + trainer.rsplit(":", 1)[1])
        primary = self.party()[self.starter_index() - 1]
        target = self.config.get("training_level", 16)
        if primary["level"] < target or primary["species"] == self.starter:
            self._to_training_grass()
            if self.state.get("zone_id") != MAPS["ViridianForest"]:
                self.reach_training_zone(MAPS["ViridianForest"])
            self.train_to(target)
        if not self.defeated(BROCK):
            self.return_to_pewter()
            count = max(0, min(3 - self.quantity("potion"), self.inventory()["money"] // 300))
            if count:
                self.warp(MAPS["PewterMart"])
                self.buy_item("pokered:PEWTER_MART:objects:1", "potion", count, 300)
                self.warp(MAPS["PewterCity"])
            self.warp(MAPS["PewterGym"])
            self.defeat_source(JR)
            if not self.defeated(JR):
                raise ProtocolError("source Jr trainer victory missing")
            self.repeat_trainer(JR)
            self.warp(MAPS["PewterCity"])
            self.center(MAPS["PewterCity"])
            self.warp(MAPS["PewterGym"])
            self.defeat_source(BROCK)
        if not self.defeated(BROCK) or not self.flag("BADGE_BOULDER") or self.quantity("tm34") != 1:
            raise ProtocolError("Brock reward transaction incomplete")
        self.repeat_trainer(BROCK)
        self.checkpoint("brock-badge-tm34")
        self.save()
        self.summary.update(acceptance="Brock path completed and saved", natural=True, forbidden_shortcuts=False)
        self.after_boulder()

    def _bind_kanto_route(self):
        """Use the source-map walker. Movement stays button presses and doors."""
        if getattr(self, "_kanto_route", False):
            return
        import tools.harness.cerulean_journey as cerulean
        source = cerulean.StagedSource(self.build_evidence)
        self.models, self.map_manifest, self.doors = cerulean.source_models(source)
        self.export = cerulean.validate_export(source.read("dev/ceruleanJourney.json"), source)
        self.source_trainers.update(self.export["trainers"])
        self.source_trainers[cerulean.BRIDGE_RIVAL] = self.export["rivals"][cerulean.BRIDGE_RIVAL][self.starter]
        self.scenes = source.read("data/ceruleanStory/scenes.json")
        self.stage = "cerulean"
        self.config["name"] = "cerulean-natural"
        self.config.setdefault("fossil", "dome")
        self.summary.setdefault("source_receipts", [])
        self.summary.setdefault("transitions", [])
        self.summary.setdefault("rewards", [])
        for name in (
            "project", "warp_projection", "project_warp", "portals", "route_portal",
            "travel", "fight", "heal_here", "stock_up", "reward", "zone",
            "fossil_exclusion", "recover_path_blackout", "codec_guard",
            "observe", "require_shop_stock", "advance_event",
        ):
            setattr(self, name, getattr(cerulean.CeruleanJourney, name).__get__(self, type(self)))
        # Route 24/25 have a second edge cell that is passable but cut off
        # from the road. The stock walker bounces through that pocket.
        self.travel = self._travel_past_dead_edges
        self._kanto_route = True

    def after_boulder(self):
        """Walk the earned Boulder save toward Misty and the Cerulean story."""
        if not self.defeated(BROCK) or not self.flag("BADGE_BOULDER") or self.quantity("tm34") != 1:
            raise ProtocolError("Boulder reward is not in this save")
        if self.state.get("zone_id") == MAPS["PewterGym"]:
            self.warp(MAPS["PewterCity"])
        self._bind_kanto_route()
        import tools.harness.cerulean_journey as cerulean
        if self.flag("BADGE_CASCADE") and self.defeated(cerulean.MISTY):
            self._after_cascade()
            return
        # A save in Cerulean, on Nugget Bridge, or on Route 25 already
        # walked Route 3 and Mt. Moon. Do not walk back to Pewter.
        zone_id = self.state.get("zone_id") or ""
        if any(token in zone_id for token in ("CERULEAN", "ROUTE_24", "ROUTE_25", "BILLS_HOUSE")) and (
            self.flag("EVENT_GOT_DOME_FOSSIL") or self.flag("EVENT_GOT_HELIX_FOSSIL")
        ):
            self._misty_badge(cerulean)
            return
        self.heal_here("PewterPokecenter")
        self.stock_up("PewterMart")
        self.save()
        route3 = self.zone("Route3")
        trainers = sorted(
            (d for d in self.source_trainers.values()
             if isinstance(d, dict) and d.get("map_id") == route3),
            key=lambda d: d.get("source_object_index", 0))
        for trainer in trainers:
            if not self.defeated(trainer["id"]):
                self.fight(trainer["id"])
                self.heal_here("PewterPokecenter")
        self.stock_up("PewterMart")
        self.save()
        self.heal_here("MtMoonPokecenter")
        self.save()
        stone = cerulean.sid("MT_MOON_1F", 9)
        if not self.flag("PICKUP:" + stone):
            self.travel(self.zone("MtMoon1F"))
            self.reward(stone, "moonStone", "PICKUP:" + stone)
        rocket = cerulean.sid("MT_MOON_B2F", 2)
        if not self.defeated(rocket):
            self.heal_here("MtMoonPokecenter")
            self.save()
            self.fight(rocket)
            self.heal_here("MtMoonPokecenter")
            self.save()
        if not self.defeated(cerulean.NERD):
            self.save()
            trigger = self.scenes["fossil_trigger"]
            self.travel(self.zone("MtMoonB2F"), (trigger["x"] + self.models[self.zone("MtMoonB2F")].padding, trigger["y"]))
        self.reward(*cerulean.FOSSILS[self.config.get("fossil", "dome")])
        self.fossil_exclusion()
        self.checkpoint("cerulean-fossil-choice")
        self.travel(self.zone("CeruleanCity"))
        self._misty_badge(cerulean)

    def _after_cascade(self):
        """Nugget Bridge and Bill. Save before each row of trainers."""
        import tools.harness.cerulean_journey as cerulean
        zone_id = self.state.get("zone_id") or ""
        if self.flag("EVENT_GOT_SS_TICKET") and any(
                token in zone_id for token in ("VERMILION", "SS_ANNE", "ROUTE_5", "ROUTE_6", "UNDERGROUND")):
            self._pin_route_trainers()
            if "VERMILION_POKECENTER" in zone_id or "SS_ANNE" in zone_id:
                self._toward_surge()
            else:
                self._toward_vermilion()
            return
        if not self.defeated(cerulean.BRIDGE_RIVAL):
            self.save()
            self.fight(cerulean.BRIDGE_RIVAL)
            self.heal_here("CeruleanPokecenter")
        self.stock_up("CeruleanMart")
        self.save()
        for index in (6, 5, 4, 3, 2, 1):
            trainer = cerulean.sid("ROUTE_24", index)
            if not self.defeated(trainer):
                self.fight(trainer)
        # The Nugget can already have been sold at the mart. The flag is the receipt.
        if not self.flag("EVENT_GOT_NUGGET"):
            raise ProtocolError("Nugget Bridge gift was not received")
        self.checkpoint("cerulean-nugget-bridge")
        self.heal_here("CeruleanPokecenter")
        self.save()
        if not self.flag("EVENT_GOT_SS_TICKET"):
            self.travel(self.zone("Route25"))
            self.bill_scene()
            self.reward(cerulean.TICKET, "ssTicket", "EVENT_GOT_SS_TICKET")
            self.interact(source_id=cerulean.TICKET)
            if self.quantity("ssTicket") != 1:
                raise ProtocolError("S.S. Ticket was not received once")
            self.checkpoint("cerulean-ticket")
        self.heal_here("CeruleanPokecenter")
        self.save()
        self._toward_vermilion()
        self.summary.update(acceptance="Reached Vermilion", natural=True, forbidden_shortcuts=False)

    def bill_scene(self):
        """Talk to Bill, then use the PC. Overworld A fires on the release frame."""
        import tools.harness.cerulean_journey as cerulean
        from tools.harness.journeys import DIRECTIONS
        self.travel(self.zone("BillsHouse"))
        self.interact(source_id=cerulean.BILL)
        if not self.flag("EVENT_BILL_SAID_USE_CELL_SEPARATOR"):
            raise ProtocolError("Bill setup integration missing")
        pc = self.export.get("bill_pc_player")
        if not isinstance(pc, dict) or pc.get("id") != cerulean.PC or pc.get("facing") not in DIRECTIONS or any(
                type(pc.get(key)) is not int for key in ("x", "y")):
            raise ProtocolError("missing root source-valid Bill PC player-pose export")
        point = (pc["x"] + self.model().padding, pc["y"])
        if not self.model().inside(point) or self.model().collision[point[1]][point[0]]:
            raise ProtocolError("missing root Bill PC integration: declared player cell is blocked in staged geometry")
        self.navigate(point)
        self.face(pc["facing"])
        self.send("press a", "wait 12")
        if lookup(self.state, "event.id") != cerulean.PC and self.state.get("root") == "overworld":
            self.send("press a", "wait 12")
        if lookup(self.state, "event.id") != cerulean.PC:
            raise ProtocolError("Bill PC hidden stable-ID dispatch missing")
        self.drain()
        for flag in ("EVENT_USED_CELL_SEPARATOR_ON_BILL", "EVENT_MET_BILL", "EVENT_MET_BILL_2"):
            if not self.flag(flag):
                raise ProtocolError("Bill cell separator did not commit: " + flag)
        self.checkpoint("cerulean-bill-restored")

    def _pin_route_trainers(self):
        """Sighted Route 6 trainers are not in the Cerulean export.

        Their payout pins live with the Vermilion source table. A win still
        has to match that pin. This does not invent a payout.
        """
        path = REPO / "Source" / "dev" / "vermilionJourney.json"
        trainers = json.loads(path.read_text())["trainers"]
        starter = getattr(self, "starter", None) or "charmander"
        for trainer_id, record in trainers.items():
            if trainer_id in self.source_trainers or not isinstance(record, dict):
                continue
            chosen = record
            parties = record.get("rival_parties")
            selected = parties.get(starter) if isinstance(parties, dict) else None
            if isinstance(selected, dict) and type(selected.get("payout")) is int and isinstance(selected.get("party"), list):
                chosen = dict(record, party=selected["party"], payout=selected["payout"])
            if type(chosen.get("payout")) is int:
                self.source_trainers[trainer_id] = chosen

    def step(self, step):
        """Wait when a pacing NPC steps onto the cell the path just chose."""
        zone, origin = self.state.get("zone_id"), self.position()
        try:
            return super().step(step)
        except ProtocolError as error:
            block = lookup(self.state, "player.lastTraversalBlock")
            if (getattr(step, "kind", None) != "walk"
                    or not str(error).startswith("source-valid walk failed:")
                    or self.state.get("zone_id") != zone or self.position() != origin
                    or block != {"kind": "npc", "id": "occupied-next-cell"}):
                raise
            key = (zone, origin, getattr(step, "destination", None))
            previous, count = getattr(self, "_npc_step_retry", (None, 0))
            count = count + 1 if previous == key else 1
            if count > 8:
                raise
            self._npc_step_retry = (key, count)
            self.send("wait 8")
            return None

    def _toward_vermilion(self):
        """Walk south to Vermilion. Wild fights are fled. Surge is the next gym."""
        self.training_mode = None
        self._pin_route_trainers()
        if "VERMILION" not in (self.state.get("zone_id") or ""):
            self.travel(self.zone("VermilionCity"))
        self.heal_here("VermilionPokecenter")
        self.save()
        self._toward_surge()

    def _seal_cut_tree(self):
        """The staged grid leaves the tree open. A center visit grows it back.

        Mark the Cut target solid so the walk stops beside it instead of
        stepping onto the tile the game rejects.
        """
        site = self.vermilion["cut_sites"][0]
        model = self.models[self.zone("VermilionCity")]
        for target in site["targets"]:
            x, y = target["x"] + model.padding, target["y"]
            model.collision[y][x] = 1

    def _vermilion_tools(self):
        """Bind the ship and gym button methods. Do not run the 5.4 campaign."""
        import tools.harness.vermilion_journey as vermilion
        if getattr(self, "_vermilion_bound", False):
            return vermilion
        self.vermilion = json.loads((REPO / "Source" / "dev" / "vermilionJourney.json").read_text())
        self.field_definitions = json.loads((REPO / "Source" / "data" / "fieldMoves.json").read_text())
        self.cut_cells = []
        self.cut_witnesses = 0
        self.vermilion_active = True
        for name in (
            "teach_cut", "field_cut", "puzzle", "inspect_can",
            "apply_world_observation", "leave_gym",
        ):
            setattr(self, name, getattr(vermilion.VermilionJourney, name).__get__(self, type(self)))
        self._vermilion_bound = True
        return vermilion

    def _toward_surge(self):
        """Board the S.S. Anne, teach Cut, and fight Lt. Surge."""
        import tools.harness.cerulean_journey as cerulean
        vermilion = self._vermilion_tools()
        if not self.flag("EVENT_GOT_HM01"):
            if "SS_ANNE" not in (self.state.get("zone_id") or ""):
                self.travel(self.zone("VermilionDock"))
                self.travel(self.zone("SSAnne1F"))
            if not self.defeated(vermilion.RIVAL):
                self.navigate((3, 7))
                self.navigate((3, 6))
                self.warp(self.zone("SSAnne2F"), event_id="pokered:SS_ANNE_1F:warps:9")
                trigger = self.vermilion["scenes"]["rival"]["variants"][0]["trigger"]
                pad = self.models[self.zone("SSAnne2F")].padding
                self.travel(self.zone("SSAnne2F"), (trigger["x"] + pad, trigger["y"]))
            if not self.defeated(vermilion.RIVAL):
                raise ProtocolError("S.S. Anne rival was not defeated")
            self.travel(self.zone("SSAnneCaptainsRoom"))
            self.reward(vermilion.CAPTAIN, "hm01", "EVENT_GOT_HM01")
            if self.quantity("hm01") != 1:
                raise ProtocolError("HM01 was not received once")
            self.save()
        self.teach_cut()
        if not self.flag("EVENT_SS_ANNE_LEFT"):
            self.travel(self.zone("SSAnne1F"))
            self.navigate((25, 7))
            self.navigate((26, 1))
            self.step(self.model().terrain_step(self.position(), "up"))
            self.send("wait 2")
            self.drain()
            if self.state["zone_id"] == self.zone("VermilionDock"):
                self.navigate((14, 1))
                self.step(self.model().terrain_step(self.position(), "up"))
                self.send("wait 2")
                self.drain()
            if self.state["zone_id"] != self.zone("VermilionCity") or not self.flag("EVENT_SS_ANNE_LEFT"):
                raise ProtocolError("the S.S. Anne did not leave")
            self.save()
        if not self.flag("BADGE_THUNDER"):
            cutter = next(i for i, mon in enumerate(self.party(), 1) if "cut" in mon["moves"])
            for trainer_index in (4, 3, 2):
                trainer_id = cerulean.sid("VERMILION_GYM", trainer_index)
                if self.defeated(trainer_id):
                    continue
                # Leaving the gym must not plan a step onto the tree. A center
                # reload grows it back, so Cut again on the way in.
                self._seal_cut_tree()
                self.heal_here("VermilionPokecenter")
                self.save()
                self._seal_cut_tree()
                self.field_cut(cutter)
                self.fight(trainer_id)
            self._seal_cut_tree()
            self.heal_here("VermilionPokecenter")
            self.save()
            self._seal_cut_tree()
            self.field_cut(cutter)
            self.travel(self.zone("VermilionGym"))
            self.puzzle()
            self.fight(vermilion.SURGE)
            if not all(self.flag(flag) for flag in ("BADGE_THUNDER", "EVENT_BEAT_LT_SURGE", "EVENT_GOT_TM24")) or self.quantity("tm24") != 1:
                raise ProtocolError("Lt. Surge win, badge, or TM24 is missing")
            self.heal_here("VermilionPokecenter")
            self.save()
        self.summary.update(acceptance="Thunder Badge earned", natural=True, forbidden_shortcuts=False)

    def _have_counter(self, minimum):
        return any(
            mon["species"] in WATER_COUNTERS and mon["level"] >= minimum and mon["hp"] > 0
            for mon in self.party()
        )

    def _grass_target_level(self):
        """High teens. A Misty loss raises this so the same lead is not sent back in."""
        return getattr(self, "_grass_level_target", 18)

    def _starter_level(self):
        return self.party()[self.starter_index() - 1]["level"]

    def _species_level(self, species):
        levels = [mon["level"] for mon in self.party() if mon["species"] == species and mon["hp"] > 0]
        return max(levels) if levels else 0

    def _misty_ready(self):
        """Bellsprout or Oddish leads. Charmeleon's level does not open the gym."""
        return self._have_counter(self._grass_target_level()) and self._species_level("pidgey") >= 14

    def _buy_balls(self):
        if self.quantity("pokeBall") >= 4:
            return
        clerk = self.zone("CeruleanMart") + ":objects:1"
        price = self.export["shops"][clerk]["prices"]["pokeBall"]
        count = min(4 - self.quantity("pokeBall"), self.inventory()["money"] // price)
        if count:
            self.travel(self.zone("CeruleanMart"))
            self.buy_item(clerk, "pokeBall", count, price)

    def _lead_counter(self, minimum):
        best = None
        for index, mon in enumerate(self.party(), 1):
            if mon["species"] in WATER_COUNTERS and mon["level"] >= minimum and mon["hp"] > 0:
                if best is None or mon["level"] > best[1]:
                    best = (index, mon["level"])
        if best and best[0] != 1:
            self.field_swap(best[0], 1)

    def _lead_starter(self):
        index = self.starter_index()
        if index != 1:
            self.field_swap(index, 1)

    def _lead_species(self, species):
        best = None
        for index, mon in enumerate(self.party(), 1):
            if mon["species"] == species and mon["hp"] > 0:
                if best is None or mon["level"] > best[1]:
                    best = (index, mon["level"])
        if best and best[0] != 1:
            self.field_swap(best[0], 1)

    def _arrange_lead(self, prefer):
        """The Grass counter keeps the experience until Misty. Pidgey is raised after that."""
        if prefer == "counter" and self._have_counter(1):
            self._lead_counter(1)
        elif prefer == "bench":
            self._lead_species("pidgey")
        else:
            self._lead_starter()

    def _lead_for_misty(self):
        if not self._have_counter(self._grass_target_level()):
            raise ProtocolError("Misty refused: no Grass lead in the high teens")
        self._lead_counter(self._grass_target_level())

    def _needs_heal(self):
        lead = self.party()[0]
        return lead["hp"] * 2 < lead["maxHP"] or lead["status"] not in {None, "none"}

    def _stock_potions(self):
        """Buy Potions toward 20 after the mart's usual restock."""
        target = 20
        have = self.quantity("potion")
        if have >= target:
            return
        clerk = self.zone("CeruleanMart") + ":objects:1"
        price = self.export["shops"][clerk]["prices"]["potion"]
        reserve = 0 if self._have_counter(1) or self.quantity("pokeBall") >= 4 else 400
        count = min(target - have, max(0, (self.inventory()["money"] - reserve) // price))
        if count:
            self.travel(self.zone("CeruleanMart"))
            self.buy_item(clerk, "potion", count, price)

    def _object_tiles(self, model):
        return {(event["x"], event["y"]) for event in model.events.get("objects", [])}

    def _arrival_reaches(self, zone_id, dest, target_id, goal, origin_id):
        """False for a pocket whose only exit is back to the map we just left."""
        model = self.models[zone_id]
        dest = tuple(dest)
        if not model.inside(dest) or model.collision[dest[1]][dest[0]]:
            return False
        blocked = self._object_tiles(model)
        if zone_id == target_id and goal:
            try:
                model.path(dest, set(goal), blocked)
                return True
            except ProtocolError:
                return False
        for point, kind, detail in self.portals(model):
            if kind == "connection":
                next_zone = detail[1][0]
            elif kind == "warp":
                try:
                    next_zone = self.project_warp(model, detail)[0]
                except ProtocolError:
                    continue
            else:
                continue
            if next_zone == origin_id:
                continue
            try:
                model.path(dest, {point}, blocked, allow_warps={point})
                return True
            except ProtocolError:
                continue
            except TypeError:
                try:
                    model.path(dest, {point}, blocked)
                    return True
                except ProtocolError:
                    continue
        return False

    def _cross_open_portal(self, target_id, goal, banned):
        """Walk to a different door. A zero-step door is the one we just reversed."""
        origin_id = self.state["zone_id"]
        model = self.model()
        options = []
        for point, kind, detail in self.portals(model):
            if kind != "connection":
                continue
            direction, destination = detail
            zone, dest = destination[0], tuple(destination[1])
            if (zone, dest) in banned:
                continue
            if not self._arrival_reaches(zone, dest, target_id, goal, origin_id):
                continue
            try:
                route = model.path(self.position(), {point}, self.occupied(), allow_warps={point})
            except ProtocolError:
                continue
            except TypeError:
                try:
                    route = model.path(self.position(), {point}, self.occupied())
                except ProtocolError:
                    continue
            options.append((len(route), point, direction, zone, dest))
        if not options:
            return False
        options.sort()
        _length, point, direction, zone, dest = options[0]
        origin = self.state["zone_id"]
        if self.position() != point:
            self.navigate(point)
        self.cross(direction, zone, dest)
        self.summary["transitions"].append({
            "from": origin, "kind": "connection", "source": direction, "to": [zone, list(dest)],
        })
        return True

    def _travel_past_dead_edges(self, target_id, goal=None):
        """Same real door walks, skipping an edge cell that cannot reach the road."""
        from tools.harness.brock_journey import NaturalBlackout
        if isinstance(goal, tuple):
            goal = {goal}
        banned = set()
        last_cross = None
        for _ in range(self.config.get("max_transitions", 64)):
            try:
                portal = self.route_portal(target_id, goal)
                if portal is None:
                    if goal is not None:
                        self.navigate(goal)
                    return
                point, kind, detail, destination = portal
                if kind == "connection":
                    zone, dest = destination[0], tuple(destination[1])
                    origin_id = self.state["zone_id"]
                    origin_cell = self.position()
                    reverse = (
                        last_cross is not None
                        and last_cross[2] == origin_id
                        and last_cross[3] == origin_cell
                        and last_cross[0] == zone
                        and tuple(last_cross[1]) == dest
                    )
                    if reverse or (zone, dest) in banned or not self._arrival_reaches(zone, dest, target_id, goal, origin_id):
                        banned.add((zone, dest))
                        if last_cross is not None:
                            banned.add((last_cross[2], last_cross[3]))
                        if self.state.get("zone_id") == target_id and goal is not None:
                            self.navigate(goal)
                            return
                        if self._cross_open_portal(target_id, goal, banned):
                            last_cross = None
                            continue
                        raise ProtocolError("no open route past a dead map edge to " + str(target_id))
                    last_cross = (origin_id, tuple(point), zone, dest)
                origin = self.state["zone_id"]
                if kind == "warp":
                    self.warp(destination[0], event_id=detail["id"])
                else:
                    self.navigate(point)
                    self.cross(detail[0], *destination)
                self.summary["transitions"].append({
                    "from": origin, "kind": kind,
                    "source": detail["id"] if kind == "warp" else detail[0],
                    "to": destination,
                })
            except NaturalBlackout:
                if self.config.get("name") not in {"cerulean-natural", "vermilion-natural"}:
                    raise
                self.recover_path_blackout("travel to " + str(target_id))
        raise ProtocolError("Cerulean physical transition budget exhausted")

    def _fight_route_trainers(self, constant, indices):
        """Nugget Bridge, the rest of Route 24, and Route 25. Save after each win."""
        import tools.harness.cerulean_journey as cerulean
        pending = []
        for index in indices:
            trainer = cerulean.sid(constant, index)
            if trainer not in self.source_trainers or self.defeated(trainer):
                continue
            zone = self.source_trainers[trainer]["map_id"]
            event = next(row for row in self.models[zone].events["objects"] if row["id"] == trainer)
            pending.append((event["x"], event["y"], trainer))
        # Meet the southern Route 24 trainers first, and the western Route 25 trainers first.
        if constant == "ROUTE_25":
            pending.sort(key=lambda row: (row[0], row[1]))
        else:
            pending.sort(key=lambda row: (-row[1], row[0]))
        fought = False
        for _x, _y, trainer in pending:
            self._arrange_lead("starter")
            if self._needs_heal():
                self.heal_here("CeruleanPokecenter")
            self.save()
            self.fight(trainer)
            fought = True
            if self.state.get("root") == "overworld":
                self.save()
        if fought:
            self.heal_here("CeruleanPokecenter")
            self._stock_potions()
            self.save()

    def _grind(self, route_name, limit, prefer):
        """Walk one route's grass and fight what appears. Catch a water counter."""
        from tools.harness.brock_journey import NaturalBlackout, training_lane
        route = self.zone(route_name)
        if self._needs_heal():
            self.heal_here("CeruleanPokecenter")
            self.save()
        self.training_mode = "train"
        self.capture_pending = False
        start = len(self.summary["training"])
        lane = None
        try:
            try:
                self.travel(route)
            except NaturalBlackout:
                self.recover_path_blackout(route_name + " training")
                return len(self.summary["training"]) - start
            except ProtocolError:
                return len(self.summary["training"]) - start
            for _ in range(limit * 4):
                if prefer == "starter" and self._misty_ready():
                    break
                if prefer == "counter" and self._have_counter(self._grass_target_level()):
                    break
                if prefer == "bench" and self._species_level("pidgey") >= 14:
                    break
                if len(self.summary["training"]) - start >= limit:
                    break
                if len(self.summary["training"]) >= self.config.get("max_training_battles", 256):
                    break
                active = lookup(self.state, "pokemon")
                # Pidgey is frail. Heal before a wild hit can black out the session.
                bench_hurt = prefer == "bench" and active.get("hp", 0) < active.get("maxHP", 1)
                if bench_hurt or active.get("hp", 0) * 2 < active.get("maxHP", 1) or active.get("status") not in {None, "none"}:
                    self.training_mode = None
                    self.heal_here("CeruleanPokecenter")
                    self.save()
                    self.training_mode = "train"
                    self.travel(route)
                    lane = None
                if self.state.get("zone_id") != route:
                    self.travel(route)
                    lane = None
                self._arrange_lead(prefer)
                try:
                    if lane is None:
                        lane = training_lane(self.model(), self.position(), self.occupied())
                    goal = lane[1] if self.position() == lane[0] else lane[0]
                    self.navigate(goal)
                except NaturalBlackout:
                    self.recover_path_blackout(route_name + " training")
                    self.training_mode = "train"
                    self.travel(route)
                    lane = None
                except ProtocolError:
                    break
                fought = len(self.summary["training"]) - start
                if fought and fought % 5 == 0 and self.state.get("root") == "overworld":
                    self.save()
        finally:
            self.training_mode = None
            self.capture_pending = False
        return len(self.summary["training"]) - start

    def _sell_nugget(self, clerk):
        """Sell the Bridge Nugget at the open counter. The shop's own total is the price."""
        if self.quantity("nugget") < 1:
            return 0
        quantity, money = self.quantity("nugget"), self.inventory()["money"]
        self.interact(source_id=clerk)
        self.require(root="shop", **{"shop.phase": "mode"})
        self.select("shop.menu.selected", 2)
        self.send("press a")
        index = next(i for i, slot in enumerate(self.inventory()["slots"], 1) if slot["id"] == "nugget")
        self.select("shop.selected", index)
        self.require(**{"shop.item": "nugget"})
        self.send("press a")
        self.require(**{"shop.phase": "quantity", "shop.quantity": 1})
        self.send("press a")
        self.require(**{"shop.phase": "confirm"})
        self.select("shop.menu.selected", 1)
        self.send("press a")
        self.require(**{"shop.phase": "result", "shop.result.ok": True})
        total = lookup(self.state, "shop.result.total")
        if type(total) is not int or total <= 0 or self.quantity("nugget") != quantity - 1 or self.inventory()["money"] != money + total:
            raise ProtocolError("actual Nugget sale did not commit exact item/money changes")
        self.send("press a", "press b", "press b")
        self.drain()
        return total

    def _buy_misty_items(self):
        """Buy what this mart sells. Cerulean has Parlyz Heals and no Super Potions."""
        clerk = self.zone("CeruleanMart") + ":objects:1"
        shop = self.export["shops"][clerk]
        wants_parlyz = "parlyzHeal" in shop["stock"] and self.quantity("parlyzHeal") < 5
        wants_super = "superPotion" in shop["stock"] and self.quantity("superPotion") < 5
        wants_potions = self.quantity("potion") < 20
        if self.quantity("nugget") and self.inventory()["money"] < 1000 and (wants_parlyz or wants_potions or wants_super):
            self.travel(self.zone("CeruleanMart"))
            self._sell_nugget(clerk)
        if wants_super:
            price = shop["prices"]["superPotion"]
            count = min(5 - self.quantity("superPotion"), self.inventory()["money"] // price)
            if count:
                self.travel(self.zone("CeruleanMart"))
                self.buy_item(clerk, "superPotion", count, price)
        if wants_parlyz:
            price = shop["prices"]["parlyzHeal"]
            count = min(5 - self.quantity("parlyzHeal"), self.inventory()["money"] // price)
            if count:
                self.travel(self.zone("CeruleanMart"))
                self.buy_item(clerk, "parlyzHeal", count, price)
        self._stock_potions()

    def _prepare_for_misty(self):
        """Level the Grass counter to the high teens and raise Pidgey. Do not enter the gym here."""
        self.heal_here("CeruleanPokecenter")
        self.stock_up("CeruleanMart")
        self._buy_balls()
        self._buy_misty_items()
        self.save()
        stalled = 0
        while not self._have_counter(self._grass_target_level()):
            level = self._species_level("bellsprout") or self._species_level("oddish")
            gained = self._grind("Route24", 10, "counter")
            gained += self._grind("Route25", 10, "counter")
            self.heal_here("CeruleanPokecenter")
            self._buy_misty_items()
            self.save()
            if (self._species_level("bellsprout") or self._species_level("oddish")) == level and gained == 0:
                stalled += 1
            else:
                stalled = 0
            if stalled >= 2 or len(self.summary["training"]) >= self.config.get("max_training_battles", 256):
                raise ProtocolError("training stalled before the Grass counter reached the high teens")
        stalled = 0
        while self._species_level("pidgey") < 14:
            level = self._species_level("pidgey")
            gained = self._grind("Route24", 8, "bench")
            gained += self._grind("Route25", 8, "bench")
            self.heal_here("CeruleanPokecenter")
            self.save()
            if self._species_level("pidgey") == level and gained == 0:
                stalled += 1
            else:
                stalled = 0
            if stalled >= 2 or len(self.summary["training"]) >= self.config.get("max_training_battles", 256):
                raise ProtocolError("training stalled before Pidgey was raised")
        self._buy_misty_items()
        self.heal_here("CeruleanPokecenter")
        self.save()

    def _misty_badge(self, cerulean):
        """Pause-save in the overworld, then fight Misty. A loss trains the Grass lead further."""
        previous = self.config.get("max_blackouts", 2)
        try:
            for attempt in range(4):
                self.config["max_blackouts"] = previous
                self._prepare_for_misty()
                if not self._misty_ready():
                    raise ProtocolError("Misty refused: the Grass lead is not ready")
                self._lead_for_misty()
                self.heal_here("CeruleanPokecenter")
                self.save()
                self.blackouts = 0
                self.config["max_blackouts"] = 0
                try:
                    if not self.defeated(cerulean.MISTY):
                        self.fight(cerulean.MISTY)
                    break
                except ProtocolError as error:
                    if "blackout" not in str(error) or attempt == 3:
                        raise
                    levels = [mon["level"] for mon in self.party() if mon["species"] in WATER_COUNTERS]
                    self._grass_level_target = (max(levels) if levels else self._grass_target_level()) + 2
            else:
                raise ProtocolError("Misty training retries exhausted")
        finally:
            self.config["max_blackouts"] = previous
        if not all(self.flag(flag) for flag in ("BADGE_CASCADE", "EVENT_BEAT_MISTY", "EVENT_GOT_TM11")) or self.quantity("tm11") != 1:
            raise ProtocolError("Misty badge or TM11 was not received")
        self.checkpoint("cascade-badge-tm11")
        self.heal_here("CeruleanPokecenter")
        self.save()
        self._after_cascade()

    def _throw_ball(self, battle, options):
        """Throw one real Poké Ball. Used so a counter is not knocked out first."""
        if self.quantity("pokeBall") <= 0:
            return False
        if len(self.summary["captures"]) >= self.config.get("max_capture_attempts", 24):
            return False
        before = self.quantity("pokeBall")
        count = len(self.party())
        positions = [i for i, value in enumerate(options, 1)
                     if value == "BAG" or isinstance(value, dict) and value.get("action") == "bag"]
        if len(positions) != 1:
            raise ProtocolError("capture requires one real BAG action")
        self.select("battle.menu.selected", positions[0])
        self.send("press a")
        self.require(root="bag")
        index = next((i for i, row in enumerate(sequence(self.inventory()["slots"], "inventory.slots"), 1)
                      if row["id"] == "pokeBall"), None)
        if index is None:
            raise ProtocolError("actual capture ball disappeared")
        self.select("bag.selected", index)
        self.send("press a")
        self.require(root="battle")
        if self.quantity("pokeBall") != before - 1:
            raise ProtocolError("real ball did not consume exactly one")
        result = lookup(self.state, "battle.capture_result")
        if not isinstance(result, dict) or type(result.get("caught")) is not bool:
            raise ProtocolError("actual capture result required")
        self.summary["captures"].append({
            "enemy": battle["enemy"], "result": result, "before_quantity": before,
            "after_quantity": before - 1, "party_before": count, "party_after": len(self.party()),
        })
        if result["caught"]:
            if len(self.party()) != count + 1:
                raise ProtocolError("caught reserve did not enter actual party")
            self.capture_pending = False
        return True

    def battle_preparation_action(self, battle, options):
        from tools.harness.brock_journey import choose_battle_medicine
        species = (battle.get("enemy") or {}).get("species")
        want = (
            self.training_mode in {"train", "capture"}
            and battle.get("trainerName") is None
            and species in WATER_COUNTERS
            and not self._have_counter(1)
            and self.quantity("pokeBall") > 0
            and len(self.party()) < 6
        )
        player = battle.get("player") or {}
        if player.get("status") in {"paralysis", "paralyze"} and self.quantity("parlyzHeal") > 0:
            self.battle_medicine("parlyzHeal", options)
            return True
        if not want:
            return super().battle_preparation_action(battle, options)
        # Throw before Dragon Rage can knock the counter out.
        self.training_mode = "capture"
        self.capture_pending = True
        try:
            if choose_battle_medicine(battle["player"], self.inventory()):
                return False
            return self._throw_ball(battle, options)
        finally:
            # The next wild fight records its goal before this method runs.
            if self.training_mode == "capture":
                self.training_mode = "train"

    def battle_medicine(self, item, options, target=None):
        """A Grass lead Vine Whips unless it is at or below one third HP."""
        mon = (self.state.get("battle") or {}).get("player") or {}
        healing = item in {"potion", "superPotion", "hyperPotion", "maxPotion", "fullRestore"}
        if healing and mon.get("species") in WATER_COUNTERS and mon.get("hp", 0) * 3 > mon.get("maxHP", 1):
            fight = [i for i, value in enumerate(options, 1)
                     if value == "FIGHT" or isinstance(value, dict) and value.get("action") == "fight"]
            if len(fight) != 1:
                raise ProtocolError("battle requires exactly one real FIGHT action")
            self.select("battle.menu.selected", fight[0])
            self.send("press a")
            return None
        return super().battle_medicine(item, options, target)

    def battle(self, name, strategy="attack", expected=None):
        from tools.harness.brock_journey import NaturalBlackout
        from tools.harness.cerulean_journey import CeruleanJourney
        trainer_id = lookup(self.state, "event.id")
        label = key_fight(name, trainer_id)
        recorder = getattr(self, "record_fight", None)
        started = recorder(label) if recorder and label else None
        try:
            try:
                result = super().battle(name, strategy, expected)
            except NaturalBlackout:
                if getattr(self, "stage", None) == "cerulean":
                    CeruleanJourney.record_source_outcome(self, trainer_id)
                raise
            if getattr(self, "stage", None) == "cerulean":
                CeruleanJourney.record_source_outcome(self, trainer_id)
            return result
        finally:
            if started:
                started()

    def capture_presentation(self, label, kind):
        # The Brock save reuses one screenshot name. Later pause saves need their own.
        # A world pose proof is evidence only. It must not discard a pause Save.
        serial = getattr(self, "_presentation", 0) + 1
        self._presentation = serial
        if (self.frames_dir / (label + ".png")).exists():
            label = f"{label}-{serial}"
        if kind == "world":
            kind = "world-basic"
        try:
            return super().capture_presentation(label, kind)
        except ProtocolError as error:
            text = str(error)
            if "pose mismatch" in text or "source pose" in text:
                self.summary.setdefault("presentation_notes", []).append({"label": label, "error": text})
                return None
            raise

    def save(self):
        super().save()
        self._archive_earned_save()

    def _archive_earned_save(self):
        """Copy the live slots after a real pause SAVE. Bytes are not rewritten."""
        index = getattr(self, "_earned_saves", 0) + 1
        self._earned_saves = index
        label = earned_save_label(self.state, index)
        note = publish_save(self.client.data, self.evidence / "saves" / label, self.state)
        self.summary.setdefault("earned_saves", []).append({"label": label, **note})


def bedroom_snapshot():
    return {
        "root": "dialog", "zone": "reds_house_2f",
        "story": {"stage": "pre_oak"},
        "pokemon": {"present": False},
        "player": {"x": 5, "y": 3, "present": True},
        "title": {"phase": "closed", "menu": {"options": [], "selected": 1}},
    }


class TitleScript:
    """Host-side title replies. No Simulator."""

    def __init__(self):
        menu = {"root": "title", "zone": "title",
                "title": {"phase": "menu", "selected": 1,
                          "menu": {"options": ["NEW GAME", "OPTIONS"], "selected": 1}}}
        confirm = {"root": "title", "zone": "title",
                   "title": {"phase": "confirm-new", "selected": 1,
                             "menu": {"options": ["NO", "YES"], "selected": 1}}}
        yes = {"root": "title", "zone": "title",
               "title": {"phase": "confirm-new", "selected": 2,
                         "menu": {"options": ["NO", "YES"], "selected": 2}}}
        dialog = bedroom_snapshot()
        self.queue = [menu, confirm, confirm, yes, dialog, dialog, dialog]
        self.sent = []

    def send(self, commands, timeout=60, max_frames=1800):
        real_input(commands)
        self.sent.append(list(commands))
        if not self.queue:
            raise AssertionError("unexpected extra send " + str(commands))
        snapshot = self.queue.pop(0)
        count = len(commands)
        return {"status": "ok", "snapshot": snapshot,
                "results": [{"command": index, "status": "ok"} for index in range(1, count + 1)]}


class CharmanderTitleTests(unittest.TestCase):
    def test_new_game_uses_the_title_buttons(self):
        client = TitleScript()
        run = CharmanderRun(
            client, Path("/tmp"),
            {"starter": "charmander", "name": "brock-natural"},
            build_evidence=Path("/tmp"))
        run.initializing = True
        run.state = {"root": "title"}
        run.reset()
        self.assertEqual(run.state["zone"], "reds_house_2f")
        self.assertEqual(run.state["root"], "dialog")
        flat = [command for batch in client.sent for command in batch]
        self.assertIn("press a", flat)
        self.assertIn("press down", flat)
        self.assertNotIn("CONTINUE", json.dumps(client.sent))
        self.assertFalse(client.queue)

    def test_second_start_is_refused(self):
        client = TitleScript()
        run = CharmanderRun(
            client, Path("/tmp"),
            {"starter": "charmander", "name": "brock-natural"},
            build_evidence=Path("/tmp"))
        run.initializing = True
        run.state = {"root": "title"}
        run.reset()
        with self.assertRaises(ProtocolError):
            run.reset()

    def test_fixture_options_are_refused(self):
        run = CharmanderRun(
            TitleScript(), Path("/tmp"),
            {"starter": "charmander", "name": "brock-natural"},
            build_evidence=Path("/tmp"))
        run.state = {"root": "title"}
        with self.assertRaises(ProtocolError):
            run.reset(seed=1)

    def test_key_fights(self):
        self.assertEqual(key_fight("rival", None), "rival")
        self.assertEqual(key_fight("source", "pokered:PEWTER_GYM:objects:1"), "badge-boulder")
        self.assertEqual(key_fight("source", "pokered:PEWTER_GYM:objects:2"), "pewter-jr")
        self.assertEqual(key_fight("source", "pokered:CERULEAN_GYM:objects:1"), "badge-cascade")
        self.assertEqual(key_fight("source", "pokered:VERMILION_GYM:objects:1"), "badge-thunder")
        route6 = json.loads((REPO / "Source" / "dev" / "vermilionJourney.json").read_text())
        self.assertEqual(route6["trainers"]["pokered:ROUTE_6:objects:6"]["payout"], 200)
        self.assertIsNone(key_fight("preparation-1", "pokered:VIRIDIAN_FOREST:objects:2"))

    def test_clip_encoder_matches_a_raw_lcd_frame(self):
        from PIL import Image
        raw = Image.new("L", LCD_SIZE, 255)
        pixels = raw.load()
        for x in range(LCD_SIZE[0]):
            pixels[x, 40] = 0
        for y in range(LCD_SIZE[1]):
            pixels[10, y] = 0
        painted = Image.new("RGB", LCD_SIZE)
        destination = painted.load()
        for y in range(LCD_SIZE[1]):
            for x in range(LCD_SIZE[0]):
                destination[x, y] = LCD_WINDOW_WHITE if pixels[x, y] == 255 else LCD_WINDOW_BLACK
        directory = Path("/tmp/lane-i-clip-encode-test")
        if directory.exists():
            shutil.rmtree(directory)
        directory.mkdir()
        source = directory / "window.png"
        clip = directory / "clip.mp4"
        decoded = directory / "decoded.png"
        painted.save(source)
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", str(source), *lcd_clip_output_args(clip)],
            check=True)
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", str(clip),
             "-frames:v", "1", "-pix_fmt", "gray", str(decoded)],
            check=True)
        got = list(Image.open(decoded).convert("L").getdata())
        self.assertEqual(got, list(raw.getdata()))
        self.assertEqual(got.count(255), LCD_SIZE[0] * LCD_SIZE[1] - LCD_SIZE[0] - LCD_SIZE[1] + 1)
        command = lcd_clip_command(":1", 59, 113, "90", directory / "badge.mp4")
        self.assertIn("gray", command)
        self.assertIn("pc", command)
        self.assertNotIn("yuv420p", command)
        self.assertNotIn("scale", command)

    def test_clip_close_waits_for_the_file_once(self):
        class Done:
            def poll(self):
                return 0
            def wait(self, timeout=0):
                return 0
            def send_signal(self, sig):
                raise AssertionError("a finished recording was signaled")
            def kill(self):
                raise AssertionError("a finished recording was killed")
        recorder = FightRecorder(Path("/tmp/lane-i-clip-close-test"))
        recorder.procs.append(("badge-cascade", Path("/tmp/does-not-exist-lane-i.mp4"), Done(), time.time() - 60))
        self.assertEqual(recorder.close(), [])
        self.assertEqual(recorder.finish(), [])

    def test_action_pause_only_happens_in_the_overworld(self):
        self.assertTrue(needs_action_pause(ACTION_PAUSE, {"root": "overworld"}, False))
        self.assertFalse(needs_action_pause(ACTION_PAUSE, {"root": "battle"}, False))
        self.assertFalse(needs_action_pause(ACTION_PAUSE - 1, {"root": "overworld"}, False))
        self.assertFalse(needs_action_pause(ACTION_PAUSE, {"root": "overworld"}, True))
        self.assertFalse(needs_action_pause(ACTION_PAUSE, {"root": "overworld", "overworld": "irisOut"}, False))

    def test_overworld_pause_lets_the_previous_gesture_finish(self):
        overworld = {"root": "overworld", "zone": "kanto_route2"}
        self.assertEqual(pause_press(("press b",), overworld), ("wait 4", "press b", "wait 2"))
        self.assertEqual(pause_press(("press b",), {"root": "battle"}), ("press b",))
        self.assertEqual(pause_press(("press a",), overworld), ("press a",))

    def test_starter_ball_press_waits_for_release(self):
        choosing = {"root": "overworld", "zone": "oaks_lab",
                    "story": {"stage": "choose"}, "pokemon": {"present": False}}
        self.assertEqual(ball_press(("press a",), choosing), ("press a", "wait 2"))
        self.assertEqual(ball_press(("press a",), {"root": "dialog", "zone": "oaks_lab",
                                                    "story": {"stage": "choose"},
                                                    "pokemon": {"present": False}}),
                         ("press a",))
        self.assertEqual(ball_press(("press a", "wait 2"), choosing), ("press a", "wait 2"))

    def test_earned_save_label(self):
        boulder = {"zone": "pewter_gym", "session": {"flags": {"quest": {
            "BADGE_BOULDER": True, "EVENT_GOT_TM34": True}}}}
        self.assertEqual(earned_save_label(boulder, 2), "002-1-BOULDER-pewter_gym")
        self.assertEqual(earned_save_label({"zone": "viridian_city"}, 1), "001-pre-badge-viridian_city")

    def test_cerulean_resume_stays_in_cerulean(self):
        source = Path(__file__).read_text(encoding="utf-8")
        body = source.split("def after_boulder", 1)[1].split("def _after_cascade", 1)[0]
        self.assertIn("CERULEAN", body)
        self.assertLess(body.index("EVENT_GOT_DOME_FOSSIL"), body.index('self.heal_here("PewterPokecenter")'))
        self.assertLess(body.index("_misty_badge"), body.index('self.heal_here("PewterPokecenter")'))
        self.assertIn("def _prepare_for_misty", source)
        self.assertIn("ROUTE_25", source)
        self.assertIn("return getattr(self, \"_grass_level_target\", 18)", source)
        self.assertIn("no Grass lead in the high teens", source)
        self.assertIn("self.travel = self._travel_past_dead_edges", source)
        self.assertIn("no open route past a dead map edge", source)
        self.assertLess(source.index("if not self._misty_ready()"), source.index("self.fight(cerulean.MISTY)"))
        self.assertIn("wait 30", (REPO / "tools/harness/journeys.py").read_text(encoding="utf-8"))

    def test_forbidden_ops(self):
        with self.assertRaises(ProtocolError):
            real_input([{"op": "fixture", "options": {"seed": 1}}])
        with self.assertRaises(ProtocolError):
            real_input(["warp 3 4"])
        self.assertEqual(real_input(["press a", {"op": "await", "path": "root", "equals": "dialog"}]),
                         ["press", "await"])


def _badges(state):
    quest = lookup(state, "session.flags.quest") or {}
    if not isinstance(quest, dict):
        return []
    return sorted(name for name, value in quest.items() if name.startswith("BADGE_") and value)


def earned_save_label(state, index):
    """Folder name for one pause-SAVE copy. The badge list is alphabetical."""
    badges = [name.removeprefix("BADGE_") for name in _badges(state)]
    badge = "pre-badge" if not badges else f"{len(badges)}-" + "-".join(badges)
    zone = str(state.get("zone") or "unknown").replace("/", "-")
    return f"{index:03d}-{badge}-{zone}"


def publish_save(data_dir, destination, state):
    """Copy the live slots. The bytes are not rewritten."""
    data_dir = Path(data_dir)
    destination.mkdir(parents=True, exist_ok=True)
    copied = []
    for path in sorted(data_dir.glob("adventure*")):
        if not path.is_file():
            continue
        target = destination / path.name
        shutil.copy2(path, target)
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        sequence = None
        try:
            envelope = json.loads(target.read_text(encoding="utf-8"))
            sequence = envelope.get("sequence")
        except (OSError, ValueError):
            sequence = None
        copied.append({"file": path.name, "sha256": digest, "sequence": sequence, "bytes": target.stat().st_size})
    note = {
        "badges": _badges(state),
        "zone": state.get("zone"),
        "zone_id": state.get("zone_id"),
        "player": state.get("player"),
        "story": state.get("story"),
        "files": copied,
    }
    (destination / "where.json").write_text(json.dumps(note, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    lines = [f"{item['sha256']}  {item['file']}" for item in copied]
    (destination / "SHA256SUMS").write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")
    return note


def _window():
    found = subprocess.run(
        ["xdotool", "search", "--onlyvisible", "--name", "^Playdate Simulator$"],
        check=False, text=True, capture_output=True)
    if found.returncode not in (0, 1):
        raise ProtocolError(found.stderr.strip() or "xdotool search failed")
    window_id = next((line.strip() for line in found.stdout.splitlines() if line.strip()), None)
    if not window_id:
        return None
    info = subprocess.run(["xwininfo", "-id", window_id], check=False, text=True, capture_output=True)
    if info.returncode != 0:
        raise ProtocolError(info.stderr.strip() or "xwininfo failed")
    values = {"id": window_id}
    for line in info.stdout.splitlines():
        if "Absolute upper-left X" in line:
            values["x"] = int(line.split()[-1])
        elif "Absolute upper-left Y" in line:
            values["y"] = int(line.split()[-1])
        elif "Width:" in line:
            values["width"] = int(line.split()[-1])
        elif "Height:" in line:
            values["height"] = int(line.split()[-1])
    return values


def _pin_window(window):
    subprocess.run(["xdotool", "windowmove", window["id"], "40", "40"], check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["xdotool", "mousemove", "2", "2"], check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


class FightRecorder:
    def __init__(self, directory):
        self.directory = Path(directory)
        self.directory.mkdir(parents=True, exist_ok=True)
        self.procs = []
        self.origin = None
        self._closed = False
        self._clips = []

    def calibrate(self):
        for _ in range(80):
            window = _window()
            if window and window.get("width") and window.get("height"):
                _pin_window(window)
                time.sleep(0.2)
                window = _window() or window
                self.origin = window
                return window
            time.sleep(0.25)
        return None

    def start(self, label):
        if self.origin is None:
            return None
        window = _window() or self.origin
        if (window.get("width"), window.get("height")) != EXPECTED_WINDOW:
            # Still crop the known LCD inset when it fits. A mismatch is recorded.
            if window.get("width", 0) < LCD_OFFSET[0] + LCD_SIZE[0] or window.get("height", 0) < LCD_OFFSET[1] + LCD_SIZE[1]:
                return None
        origin_x = window["x"] + LCD_OFFSET[0]
        origin_y = window["y"] + LCD_OFFSET[1]
        display = os.environ.get("DISPLAY", ":1")
        path = self.directory / f"{label}.mp4"
        if path.exists():
            path = self.directory / f"{label}-{len(self.procs) + 1}.mp4"
        # Badge clips are 90 seconds so the one-second page holds still fit
        # after the fight. Other clips stay at 60.
        seconds = "90" if str(label).startswith("badge-") else "60"
        proc = subprocess.Popen(
            lcd_clip_command(display, origin_x, origin_y, seconds, path),
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.procs.append((label, path, proc, time.time()))
        return proc

    def is_open(self):
        return any(proc.poll() is None for _, _, proc, _ in self.procs)

    def close(self):
        """Finish every open recording into a playable file before the session exits."""
        if self._closed:
            return list(self._clips)
        clips = []
        for label, path, proc, started in self.procs:
            if proc.poll() is None and str(label).startswith("badge-"):
                remain = 30 - (time.time() - started)
                if 0 < remain <= 30:
                    time.sleep(remain)
            if proc.poll() is None:
                proc.send_signal(signal.SIGINT)
            try:
                proc.wait(timeout=20)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)
            if path.is_file() and path.stat().st_size > 0:
                clips.append({"label": label, "path": str(path),
                              "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                              "bytes": path.stat().st_size})
        self._clips = clips
        self._closed = True
        return list(clips)

    def finish(self):
        return self.close()


def install_save(data_dir, save_dir):
    """Copy earned slot bytes into a new session. The files are not rewritten."""
    data_dir = Path(data_dir)
    copied = []
    for path in sorted(Path(save_dir).glob("adventure*.json")):
        if not path.is_file():
            continue
        shutil.copy2(path, data_dir / path.name)
        copied.append(path.name)
    if not any(name.startswith("adventure.") for name in copied):
        raise ProtocolError("resume directory has no published adventure slot")
    return copied


def latest_earned_save(output):
    best = None
    best_seq = -1
    saves = Path(output) / "saves"
    if not saves.is_dir():
        return None
    for folder in sorted(saves.iterdir()):
        if not folder.is_dir():
            continue
        for name in ("adventure.a.json", "adventure.b.json"):
            path = folder / name
            if not path.is_file():
                continue
            try:
                seq = int(json.loads(path.read_text(encoding="utf-8")).get("sequence") or 0)
            except (OSError, ValueError):
                seq = 0
            if seq >= best_seq:
                best_seq = seq
                best = folder
    return best


def play(output, probe=False, resume_save=None):
    from tools.harness.protocol import Client, OwnerLock
    from tools.harness.run import (device_lock_path, prepare, runtime_lock_path,
                                   sdk_path, simulator_preflight)

    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    sdk = sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))
    session = uuid.uuid4().hex
    config = {
        "name": "brock-natural",
        "starter": "charmander",
        "max_actions": 20000,
        "max_steps": 5000,
        "max_encounters": 64,
        "training_level": 16,
        "max_training_battles": 256,
        "max_blackouts": 2,
        "evolution_policy": "accept",
    }
    log_path = output / "drive.log"
    recorder = FightRecorder(output / "clips")
    saves = output / "saves"
    process = None
    data = None
    summary = {"session_id": session, "starter": "charmander", "probe": probe}
    with OwnerLock(runtime_lock_path(sdk)), OwnerLock(device_lock_path()):
        simulator_preflight()
        metadata = prepare(REPO, sdk, output, session, journey=True)
        data = Path(metadata["data_dir"])
        data.mkdir(parents=True, exist_ok=False)
        if resume_save is not None:
            summary["resumed_from"] = str(resume_save)
            summary["installed_save"] = install_save(data, resume_save)
        owner = OwnerLock(data / "owner.lock")
        owner.__enter__()
        try:
            with log_path.open("w") as log:
                simulator_preflight()
                process = subprocess.Popen(
                    [metadata["simulator"], metadata["bundle"]],
                    stdout=log, stderr=subprocess.STDOUT)
            metadata["simulator_pid"] = process.pid
            (output / "run.json").write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            client = Client(data, metadata["build_id"], session, output, owner=owner)
            run = None
            client.ready(180)
            window = recorder.calibrate()
            summary["window"] = window
            if probe:
                probe_path = output / "window-probe.png"
                if window:
                    display = os.environ.get("DISPLAY", ":1")
                    subprocess.run(
                        ["ffmpeg", "-y", "-loglevel", "error", "-f", "x11grab",
                         "-video_size", f"{window['width']}x{window['height']}",
                         "-framerate", "5", "-i", f"{display}.0+{window['x']},{window['y']}",
                         "-frames:v", "1", str(probe_path)],
                        check=False)
                result = client.send(["snapshot"], timeout=60, max_frames=60)
                (output / "probe-snapshot.json").write_text(
                    json.dumps({"root": result["snapshot"].get("root"),
                                "title": result["snapshot"].get("title"),
                                "zone": result["snapshot"].get("zone")}, indent=2) + "\n",
                    encoding="utf-8")
                summary["ok"] = True
                summary["probe_snapshot"] = {"root": result["snapshot"].get("root"),
                                             "title_phase": lookup(result["snapshot"], "title.phase")}
                (output / "charmander-summary.json").write_text(
                    json.dumps(summary, indent=2, default=str) + "\n", encoding="utf-8")
                print(json.dumps(summary, indent=2, default=str))
                return summary
            run = CharmanderRun(client, output, config, build_evidence=output)
            run.clip_recorder = recorder

            def record_fight(label):
                proc = recorder.start(label)
                if proc is None:
                    return None
                def _stop():
                    return None
                return _stop

            run.record_fight = record_fight
            run.close_recordings = recorder.close
            try:
                if resume_save is None:
                    run.natural()
                else:
                    run.continue_earned()
                summary["ok"] = True
                summary["acceptance"] = run.summary.get("acceptance")
            except ActionPause as error:
                summary["ok"] = True
                summary["paused_for_budget"] = True
                summary["pause_reason"] = str(error)
                summary["acceptance"] = run.summary.get("acceptance")
                (output / "journey-summary.json").write_text(
                    json.dumps(run.summary, indent=2, default=str)[:2000000], encoding="utf-8")
            except BaseException as error:
                summary["ok"] = False
                summary["error"] = str(error)
                summary["last"] = {
                    "root": run.state.get("root"),
                    "zone": run.state.get("zone"),
                    "zone_id": run.state.get("zone_id"),
                    "player": run.state.get("player"),
                    "story": run.state.get("story"),
                    "badges": _badges(run.state),
                }
                (output / "journey-summary.json").write_text(
                    json.dumps(run.summary, indent=2, default=str)[:2000000], encoding="utf-8")
            finally:
                if run is not None and run.state:
                    note = publish_save(data, saves / "latest", run.state)
                    summary["save"] = note
                summary["clips"] = recorder.close()
                artifact = Path("/opt/cursor/artifacts/lane-i") / output.parent.name / output.name / "clips"
                for clip in summary["clips"]:
                    src = Path(clip["path"])
                    if not src.is_file():
                        continue
                    artifact.mkdir(parents=True, exist_ok=True)
                    shutil.copy(src, artifact / src.name)
                    clip["artifact"] = str(artifact / src.name)
        finally:
            if process is not None and process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
            if data is not None and data.is_dir():
                archive = output / "runtime-data"
                if not archive.exists():
                    shutil.copytree(data, archive)
                shutil.rmtree(data)
            owner.__exit__()
    (output / "charmander-summary.json").write_text(
        json.dumps(summary, indent=2, default=str) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2, default=str))
    return summary


def campaign(root, probe=False):
    """Play, and when the action budget saves, continue that file in a new session."""
    root = Path(root)
    root.mkdir(parents=True, exist_ok=True)
    resume = None
    summary = None
    for leg in range(1, 7):
        summary = play(root / f"leg-{leg}", probe=probe, resume_save=resume)
        if probe or not summary.get("paused_for_budget"):
            return summary
        resume = latest_earned_save(root / f"leg-{leg}")
        if resume is None:
            summary["ok"] = False
            summary["error"] = "action pause did not leave an adventure slot"
            return summary
    return summary


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--play", type=Path, help="run the Simulator path into this new directory")
    parser.add_argument("--probe", action="store_true", help="boot to the title and capture the window")
    args, remaining = parser.parse_known_args(argv)
    if args.play:
        os.environ.setdefault("PLAYDATE_SDK_PATH", str(Path.home() / "Developer/PlaydateSDK"))
        os.environ.setdefault("DISPLAY", ":1")
        summary = campaign(args.play, probe=args.probe)
        return 0 if summary.get("ok") else 1
    unittest.main(argv=[sys.argv[0], *remaining])


if __name__ == "__main__":
    sys.exit(main())
