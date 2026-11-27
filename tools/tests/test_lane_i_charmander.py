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
import threading
import time
import traceback
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


def dismiss_simulator_dialogs():
    """Close the Simulator's Heads up window before a grab.

    Its title bar sits on the bottom edge of the 400x240 LCD crop. The
    buttons go to that dialog only, then the pointer leaves the panel.
    """
    found = subprocess.run(
        ["xdotool", "search", "--onlyvisible", "--name", "^Heads up!$"],
        check=False, text=True, capture_output=True)
    if found.returncode not in (0, 1):
        return
    for window_id in (line.strip() for line in found.stdout.splitlines() if line.strip()):
        subprocess.run(
            ["xdotool", "key", "--window", window_id, "Return"],
            check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        geo = subprocess.run(
            ["xdotool", "getwindowgeometry", "--shell", window_id],
            check=False, text=True, capture_output=True)
        width = height = None
        for line in geo.stdout.splitlines():
            if line.startswith("WIDTH="):
                width = int(line.split("=", 1)[1])
            elif line.startswith("HEIGHT="):
                height = int(line.split("=", 1)[1])
        if width and height:
            subprocess.run(
                ["xdotool", "mousemove", "--window", window_id,
                 str(width // 2), str(int(height * 0.82)), "click", "1"],
                check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(
        ["xdotool", "mousemove", "2", "2"],
        check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


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
    if trainer == "pokered:CELADON_GYM:objects:1" or label.startswith("erika"):
        return "badge-rainbow"
    if trainer == "pokered:FUCHSIA_GYM:objects:1" or label.startswith("koga"):
        return "badge-soul"
    if trainer == "pokered:SAFFRON_GYM:objects:1" or label.startswith("sabrina"):
        return "badge-marsh"
    if trainer == "pokered:CINNABAR_GYM:objects:1" or label.startswith("blaine"):
        return "badge-volcano"
    if trainer == "pokered:VIRIDIAN_GYM:objects:1":
        return "badge-earth"
    if trainer == "pokered:ROUTE_22:objects:2":
        return "rival-2"
    if trainer == "pokered:LORELEIS_ROOM:objects:1":
        return "elite-lorelei"
    if trainer == "pokered:BRUNOS_ROOM:objects:1":
        return "elite-bruno"
    if trainer == "pokered:AGATHAS_ROOM:objects:1":
        return "elite-agatha"
    if trainer == "pokered:LANCES_ROOM:objects:1":
        return "elite-lance"
    if trainer == "pokered:CHAMPIONS_ROOM:objects:1":
        return "champion"
    return None


class _TunnelReturned(Exception):
    """A cave wipe restored the party at the center. The crossing starts over."""


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

    def dependencies(self):
        """Imported Pallet replaced the reviewed authored grids. Source maps load next."""
        from tools.harness.brock_journey import load_models
        self.models, self.doors, trainers = load_models(self.build_evidence, require_authored=False)
        self.source_trainers = {d["id"]: d for d in trainers}
        self.send("snapshot")
        for path in ["session.flags.quest", "session.flags.trainers", "session.inventory", "session.party", "session.checkpoint"]:
            if lookup(self.state, path) is None:
                raise ProtocolError("Brock runtime dependency missing: " + path)
        self.summary["build_evidence"] = str(self.build_evidence)

    def _open_continued_menu(self):
        """Copyright ignores A. The star and the fight skip, then the picture needs A."""
        self.send({"op": "await", "path": "root", "equals": "title", "frames": 1200})
        if lookup(self.state, "title.phase") == "intro":
            self.send("wait 260")
            self.send("press a", "wait 8")
            self.send("press a", "wait 20")
        for _ in range(16):
            phase = lookup(self.state, "title.phase")
            if phase == "menu":
                self.send("wait 24")
                return
            if phase == "title":
                self.send("press a", "wait 12")
            else:
                self.send("wait 20")
        phase = lookup(self.state, "title.phase")
        if phase != "menu":
            raise ProtocolError("title did not open the menu: " + str(phase))
        self.send("wait 24")

    def continue_earned(self):
        """Title CONTINUE, then the Brock steps the save has not finished."""
        self.dependencies()
        self._open_continued_menu()
        options = sequence(lookup(self.state, "title.menu.options"), "title options")
        if options.count("CONTINUE") != 1:
            raise ProtocolError("earned save did not offer CONTINUE")
        self.select("title.menu.selected", options.index("CONTINUE") + 1)
        self.send("press a", "wait 40")
        # CONTINUE opens the save card. A is ignored until CONTINUE_DELAY elapses.
        self.send("press a", "wait 12")
        for _ in range(80):
            if self.state.get("root") in {"overworld", "dialog", "event"}:
                break
            phase = lookup(self.state, "title.phase")
            if phase == "message":
                raise ProtocolError("continue was refused")
            self.send("wait 12")
        else:
            raise ProtocolError("continue did not leave the title: " + str(lookup(self.state, "title.phase")))
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
        if self.flag("TOGGLE_CERULEAN_CAVE_GUY"):
            self._play_postgame()
            return
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
        # sell_old_item spends TM34 once the bag fills after Cascade. The
        # receipt flag stays. A Boulder-only save must still hold the TM.
        sold_after_cascade = self.flag("BADGE_CASCADE") and self.flag("EVENT_GOT_TM34")
        if not self.defeated(BROCK) or not self.flag("BADGE_BOULDER") or not (
                self.quantity("tm34") == 1 or sold_after_cascade):
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
        if self.flag("BADGE_THUNDER"):
            self._pin_route_trainers()
            self._toward_erika()
            return
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

    def inspect_can(self, can):
        """Open a trash can. Overworld A fires on the release frame."""
        from tools.harness.journeys import DIRECTIONS
        point = (can["x"] + self.model().padding, can["y"])
        self.navigate(set(self.model().approaches(point)))
        direction = next((name for name, (dx, dy) in DIRECTIONS.items()
                          if (self.position()[0] + dx, self.position()[1] + dy) == point), None)
        if direction is None:
            raise ProtocolError("no adjacent source can pose")
        self.face(direction)
        self.send("press a", "wait 12")
        if lookup(self.state, "event.id") != can["id"] and self.state.get("root") == "overworld":
            self.send("press a", "wait 12")
        if lookup(self.state, "event.id") != can["id"]:
            raise ProtocolError("actual hidden can dispatch differs")
        self.drain()

    def _record_gym_entry(self):
        """One game-screen clip of the gym. The fight keeps playing underneath."""
        if getattr(self, "_gym_clip_started", False):
            return
        recorder = getattr(self, "record_fight", None)
        if not recorder:
            return
        self._gym_clip_started = True
        recorder("gym-vermilion")

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
            "teach_cut", "field_cut", "puzzle",
            "apply_world_observation", "leave_gym",
        ):
            setattr(self, name, getattr(vermilion.VermilionJourney, name).__get__(self, type(self)))
        self.require_shop_stock = type(self)._shop_stock.__get__(self, type(self))
        self._vermilion_bound = True
        return vermilion

    def _shop_stock(self, clerk, item):
        """Vermilion Mart is not in the Cerulean shop export."""
        shop = (getattr(self, "vermilion", {}) or {}).get("shops", {}).get(clerk)
        price = shop.get("prices", {}).get(item) if isinstance(shop, dict) else None
        if shop and item in shop.get("stock", ()) and type(price) is int and price > 0:
            return
        import tools.harness.cerulean_journey as cerulean
        return cerulean.CeruleanJourney.require_shop_stock(self, clerk, item)

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
                # The tree is the only staged link between the gym and the center.
                # Cut from whichever side we are on, cross, then Cut again.
                self._seal_cut_tree()
                self.field_cut(cutter)
                self.heal_here("VermilionPokecenter")
                self.save()
                self._seal_cut_tree()
                self.field_cut(cutter)
                self.fight(trainer_id)
            self._seal_cut_tree()
            self.field_cut(cutter)
            self.heal_here("VermilionPokecenter")
            self.save()
            self._seal_cut_tree()
            self.field_cut(cutter)
            self.travel(self.zone("VermilionGym"))
            self._record_gym_entry()
            self.puzzle()
            self.fight(vermilion.SURGE)
            if not all(self.flag(flag) for flag in ("BADGE_THUNDER", "EVENT_BEAT_LT_SURGE", "EVENT_GOT_TM24")) or self.quantity("tm24") != 1:
                raise ProtocolError("Lt. Surge win, badge, or TM24 is missing")
            self._seal_cut_tree()
            self.field_cut(cutter)
            self.heal_here("VermilionPokecenter")
            self.save()
        self.summary.update(acceptance="Thunder Badge earned", natural=True, forbidden_shortcuts=False)
        self._toward_erika()

    def _pin_cached_trainers(self):
        """Route 9, the tunnel, and Celadon are not in the Vermilion table.

        The content cache already stores each trainer's payout. A win still
        has to match that record. This does not invent a number, and it does
        not replace a rival party the Vermilion table already selected.
        """
        if getattr(self, "_cached_trainers_pinned", False):
            return
        root = REPO / "Source" / "data" / "contentCache" / "chunks-v2"
        for path in root.rglob("*.json"):
            try:
                record = json.loads(path.read_text())
            except (OSError, json.JSONDecodeError):
                continue
            if not isinstance(record, dict):
                continue
            trainer_id = record.get("id")
            if (not isinstance(trainer_id, str) or not trainer_id.startswith("pokered:")
                    or type(record.get("payout")) is not int or not isinstance(record.get("map_id"), str)
                    or trainer_id in self.source_trainers):
                continue
            self.source_trainers[trainer_id] = record
        self._cached_trainers_pinned = True

    def _pin_tower_rival(self):
        """The tower rival is a Rival2 party, not an ordinary cache trainer.

        HideoutTowerContent pays base money times the last party member's
        level. Charmander uses party index 4, which is 1625.
        """
        scenes = json.loads((REPO / "Source" / "data" / "towerStory" / "scenes.json").read_text())
        trainers = json.loads((REPO / "Source" / "data" / "midgameEast" / "trainers.json").read_text())
        index = scenes["scenes"]["rival"]["rival_party_indices"][self.starter]
        rival_class = trainers["rival_classes"]["OPP_RIVAL2"]
        party = rival_class["parties"][index - 1]["party"]
        rival = scenes["scenes"]["rival"]["id"]
        self.source_trainers[rival] = {
            "id": rival,
            "map_id": "pokered:POKEMON_TOWER_2F",
            "party": party,
            "payout": rival_class["base_money"] * party[-1]["level"],
        }

    def _pin_map_shops(self, map_name):
        """The Saffron clerk is outside the Vermilion shop table."""
        owners = self.observe("midgame-owners:" + map_name)
        shops = owners.get("shops") if isinstance(owners, dict) else None
        if not isinstance(shops, dict) or not shops:
            raise ProtocolError("actual shop owner unavailable: " + map_name)
        self.vermilion.setdefault("shops", {}).update(shops)

    def _pin_silph_rival(self):
        """The Silph rival is a starter Rival2 party, not a cache trainer.

        HideoutTowerContent pays base money times the last party member's
        level. Charmander uses party index 7, which is 2600.
        """
        scenes = json.loads((REPO / "Source" / "data" / "silphStory" / "scenes.json").read_text())
        trainers = json.loads((REPO / "Source" / "data" / "midgameSaffron" / "trainers.json").read_text())
        index = scenes["scenes"]["rival"]["rival_party_indices"][self.starter]
        rival_class = trainers["rival_classes"]["OPP_RIVAL2"]
        party = rival_class["parties"][index - 1]["party"]
        rival = scenes["scenes"]["rival"]["id"]
        self.source_trainers[rival] = {
            "id": rival,
            "map_id": "pokered:SILPH_CO_7F",
            "party": party,
            "payout": rival_class["base_money"] * party[-1]["level"],
        }

    def _zone_has(self, *tokens):
        zone = self.state.get("zone_id") or ""
        return any(token in zone for token in tokens)

    def _past_cerulean(self):
        return self._zone_has(
            "ROUTE_9", "ROUTE_10", "ROCK_TUNNEL", "LAVENDER", "ROUTE_8", "ROUTE_7", "CELADON",
            "UNDERGROUND_PATH_ROUTE_8", "UNDERGROUND_PATH_WEST_EAST", "UNDERGROUND_PATH_ROUTE_7")

    def _south_of_tunnel(self):
        return self.state.get("zone_id") == self.zone("Route10") and self.position()[1] > 40

    def _past_tunnel(self):
        if self._south_of_tunnel():
            return True
        return self._zone_has(
            "LAVENDER", "ROUTE_8", "ROUTE_7", "CELADON",
            "UNDERGROUND_PATH_ROUTE_8", "UNDERGROUND_PATH_WEST_EAST", "UNDERGROUND_PATH_ROUTE_7")

    def _owned_species(self):
        owned = lookup(self.state, "session.pokedex.owned")
        if not isinstance(owned, dict):
            return None
        return sum(1 for value in owned.values() if value)

    def _enter_route9(self):
        """Every Route 9 west arrival stops at the Cut tree, so it looks closed.

        Step onto the cell beside that tree. The south door back to Route 5
        is a different pocket and is not the way east.
        """
        if self.state.get("zone_id") == self.zone("Route9"):
            return
        self.travel(self.zone("CeruleanCity"))
        route9 = self.models[self.zone("Route9")]
        tree = (5 + route9.padding, 8)
        approaches = set(route9.approaches(tree))
        options = []
        for point, kind, detail in self.portals(self.model()):
            if kind != "connection":
                continue
            direction, destination = detail
            zone, dest = destination[0], tuple(destination[1])
            if zone != route9.name:
                continue
            try:
                route9.path(dest, approaches, set())
            except ProtocolError:
                continue
            try:
                route = self.model().path(self.position(), {point}, self.occupied())
            except ProtocolError:
                continue
            options.append((len(route), point, direction, zone, dest))
        if not options:
            raise ProtocolError("no source step from Cerulean onto the Route 9 tree")
        options.sort()
        _length, point, direction, zone, dest = options[0]
        if self.position() != point:
            self.navigate(point)
        origin = self.state["zone_id"]
        self.cross(direction, zone, dest)
        self.summary["transitions"].append({
            "from": origin, "kind": "connection", "source": direction, "to": [zone, list(dest)],
        })

    def _cut_tree(self, zone_name, cell):
        """Seal the Cut target, then use the party menu. A reload grows it back."""
        model = self.models[self.zone(zone_name)]
        x, y = cell[0] + model.padding, cell[1]
        model.collision[y][x] = 1
        index = next(i for i, mon in enumerate(self.party(), 1) if "cut" in mon["moves"])
        self.field_cut(index, zone_name, cell)

    def _buy_trip_medicine(self):
        clerk = self.zone("VermilionMart") + ":objects:1"
        shop = self.vermilion["shops"][clerk]
        self.travel(self.zone("VermilionMart"))
        price = shop["prices"]["superPotion"]
        count = min(5, max(0, 5 - self.quantity("superPotion")),
                    max(0, self.inventory()["money"] - 2000) // price)
        if count:
            self.buy_item(clerk, "superPotion", count, price)

    def _train_bench(self, enabled):
        self.summary.setdefault("training", [])
        self.summary.setdefault("battles", [])
        if enabled:
            self.training_mode = "train"
            self._arrange_lead("bench")
        else:
            self.training_mode = None

    def _recover_tunnel_blackout(self):
        """A cave wipe returns to the last center. Heal there and keep the walk."""
        self.recover_path_blackout("Rock Tunnel")
        self.training_mode = None
        if self.state.get("root") == "overworld" and not self._south_of_tunnel():
            self.heal_here("RockTunnelPokecenter")
            self.save()

    def _tunnel_warp(self, target, event_id):
        """Take one cave door. A wipe returns to the center, so the crossing restarts."""
        from tools.harness.brock_journey import NaturalBlackout
        try:
            self.warp(target, event_id)
        except NaturalBlackout:
            self._recover_tunnel_blackout()
            raise _TunnelReturned()

    def _probe_rock_tunnel(self):
        """Step cave grass. FieldEncounters spawns on Rock Tunnel grass."""
        from tools.harness.brock_journey import NaturalBlackout
        before = len(self.summary.get("training") or [])
        model = self.model()
        origin = self.position()
        candidates = []
        for y in range(model.height):
            for x in range(model.width):
                for other in ((x + 1, y), (x, y + 1)):
                    if not model.inside(other):
                        continue
                    ox, oy = other
                    if not model.grass[y][x] or not model.grass[oy][ox]:
                        continue
                    if model.collision[y][x] or model.collision[oy][ox]:
                        continue
                    dist = abs(x - origin[0]) + abs(y - origin[1])
                    candidates.append((dist, ((x, y), other)))
        candidates.sort(key=lambda row: row[0])
        self.training_mode = "train"
        self._arrange_lead("bench")
        pair = None
        for _, candidate in candidates[:8]:
            try:
                self.navigate(candidate[0])
            except NaturalBlackout:
                self._recover_tunnel_blackout()
                self.summary["rock_tunnel_grass_steps"] = 0
                self.summary["rock_tunnel_encounters"] = "blackout on the walk to the grass"
                return
            except ProtocolError:
                continue
            pair = candidate
            break
        steps = 0
        if pair is not None:
            left, right = pair
            for _ in range(20):
                target = right if self.position() != right else left
                try:
                    self.navigate(target)
                except NaturalBlackout:
                    self._recover_tunnel_blackout()
                    break
                except ProtocolError:
                    break
                steps += 1
                if len(self.summary.get("training") or []) > before:
                    break
        gained = len(self.summary.get("training") or []) - before
        self.summary["rock_tunnel_grass_steps"] = steps
        if gained > 0:
            self.summary["rock_tunnel_encounters"] = gained
        elif steps >= 12:
            self.summary["rock_tunnel_encounters"] = "none after 12 Rock Tunnel grass steps"
        else:
            self.summary["rock_tunnel_encounters"] = "unchecked; the grass walk was shorter than 12 steps"

    def _cross_rock_tunnel(self):
        """North door, grass, then the ladder chain. A wipe restarts from the center."""
        for _ in range(12):
            try:
                self._cross_rock_tunnel_once()
            except _TunnelReturned:
                continue
            if self._past_tunnel():
                return
        raise ProtocolError("Rock Tunnel crossing stopped north of the south exit")

    def _cross_rock_tunnel_once(self):
        zone = self.state.get("zone_id")
        if zone == self.zone("RockTunnelB1F"):
            self._tunnel_warp(self.zone("RockTunnel1F"), self.zone("RockTunnelB1F") + ":warps:2")
            zone = self.state.get("zone_id")
        if zone == self.zone("RockTunnel1F"):
            self._tunnel_warp(self.zone("Route10"), self.zone("RockTunnel1F") + ":warps:1")
        if self._south_of_tunnel():
            return
        if self._needs_heal() or self.state.get("zone_id") == self.zone("RockTunnelPokecenter"):
            self.training_mode = None
            self.heal_here("RockTunnelPokecenter")
            self.save()
            self.travel(self.zone("Route10"))
        self._tunnel_warp(self.zone("RockTunnel1F"), self.zone("Route10") + ":warps:2")
        self._probe_rock_tunnel()
        # The grass probe leads Pidgey. The ladder trainers are the starter's fights.
        self.training_mode = "train"
        self._arrange_lead("starter")
        ladders = (
            ("RockTunnel1F", 5, "RockTunnelB1F"),
            ("RockTunnelB1F", 2, "RockTunnel1F"),
            ("RockTunnel1F", 7, "RockTunnelB1F"),
            ("RockTunnelB1F", 4, "RockTunnel1F"),
            ("RockTunnel1F", 3, "Route10"),
        )
        for name, warp, target in ladders:
            if self.state.get("zone_id") != self.zone(name):
                break
            if self._needs_heal():
                self.training_mode = None
                self.heal_here("RockTunnelPokecenter")
                self.save()
                break
            self._tunnel_warp(self.zone(target), self.zone(name) + ":warps:" + str(warp))

    def _toward_erika(self):
        """Underground to Cerulean, then Route 9, Rock Tunnel, and Erika.

        The Route 2 aide wants 10 owned species before HM05. This party is
        still short of that, and the tunnel ladders do not need Flash.
        Diglett's Cave is the long way to the aide, so it stays unused.
        """
        if self.flag("BADGE_RAINBOW"):
            self._toward_koga()
            return
        self.summary["acceptance"] = "walking toward the Rainbow Badge"
        self._vermilion_tools()
        self._pin_route_trainers()
        self._pin_cached_trainers()
        self.config["max_training_battles"] = 800
        self.summary["flash"] = {
            "taught": bool(self.flag("EVENT_GOT_HM05")),
            "owned": self._owned_species(),
            "aide_threshold": 10,
        }
        if not self._past_cerulean() and not self._zone_has("CERULEAN"):
            if self._zone_has("VERMILION"):
                self._buy_trip_medicine()
            self.training_mode = None
            for name in ("Route6", "UndergroundPathRoute6", "UndergroundPathNorthSouth",
                         "UndergroundPathRoute5", "Route5"):
                self.travel(self.zone(name))
            self.heal_here("CeruleanPokecenter")
            self.save()
        if not self._past_tunnel() and not self._zone_has("ROUTE_10", "ROCK_TUNNEL"):
            if self.state.get("zone_id") != self.zone("Route9"):
                self._cut_tree("CeruleanCity", (19, 28))
            self._train_bench(True)
            if self.state.get("zone_id") != self.zone("Route9") or self.position()[0] <= 15:
                self._enter_route9()
                self._cut_tree("Route9", (5, 8))
            self.travel(self.zone("Route10"))
            self.heal_here("RockTunnelPokecenter")
            self.save()
        if not self._past_tunnel():
            self._cross_rock_tunnel()
            self._train_bench(False)
            self.heal_here("LavenderPokecenter")
            self.save()
        if not self._zone_has("CELADON"):
            self._train_bench(True)
            for name in ("Route8", "UndergroundPathRoute8", "UndergroundPathWestEast",
                         "UndergroundPathRoute7", "Route7"):
                self.travel(self.zone(name))
            self._train_bench(False)
            self.heal_here("CeladonPokecenter")
            self.save()
        self._train_bench(False)
        self._arrange_lead("starter")
        import tools.harness.cerulean_journey as cerulean
        erika = cerulean.sid("CELADON_GYM", 1)
        previous = self.config.get("max_blackouts", 1)
        self.config["max_blackouts"] = 0
        try:
            for attempt in range(3):
                self._arrange_lead("starter")
                # The city tree is the only modeled link from the center to the gym.
                self._cut_tree("CeladonCity", (35, 32))
                self._cut_tree("CeladonGym", (5, 7))
                try:
                    self.fight(erika)
                    break
                except ProtocolError as error:
                    if "blackout" not in str(error).lower() or attempt == 2:
                        raise
                    self.heal_here("CeladonPokecenter")
                    self.save()
        finally:
            self.config["max_blackouts"] = previous
        if not self.flag("BADGE_RAINBOW"):
            raise ProtocolError("Erika win did not award the Rainbow Badge")
        # Leaving the gym starts a new city visit and the tree is back.
        self._cut_tree("CeladonCity", (35, 32))
        self.heal_here("CeladonPokecenter")
        self.save()
        self.summary.update(acceptance="Rainbow Badge earned", natural=True, forbidden_shortcuts=False)
        self._toward_koga()

    def _bind_post_rainbow(self):
        """Reuse the hideout, tower, and east-road button scripts."""
        if getattr(self, "_post_rainbow", False):
            return
        import tools.harness.midgame_journey as midgame
        import tools.harness.vermilion_journey as vermilion
        self.completed_steps = set()
        self.floor_choice = None
        self.scripted_wild = None
        self.event_choices = {}
        for name in (
            "scene_data", "source_waypoint", "background", "fixed_hideout",
            "fixed_warp", "fixed_leg", "pickup", "exit_hideout_lift", "use_item",
            "wake_snorlax", "enter_route14_from_east",
            "finish_eastern_road_to_fuchsia", "refill_after_route13",
            "event_offer", "restock", "ride_silph", "key_door", "c_gift",
            "party_is_restored", "ensure_room", "sell_old_item", "store_unused_items",
            "celadon_service",
            "return_from_fuchsia_to_route12", "return_from_route12_to_lavender",
            "route_c_guard", "route_c_silph", "route_c_sabrina", "complete_at_center",
            "safari_observation", "safari_journey", "prepared_safari_route",
            "advance_safari_battle", "teach", "use_field", "ensure_surf_user",
            "retrieve_hm_user",
        ):
            setattr(self, name, getattr(midgame.MidgameJourney, name).__get__(self, type(self)))
        base_fixed_warp = self.fixed_warp
        def fixed_warp(index, approach=None):
            # A facility teleporter on the bottom row is an edge door. Stepping
            # onto it does not leave. Walk down from the pad.
            event = next((e for e in self.model().events["warps"] if e["source_index"] == index), None)
            try:
                return base_fixed_warp(index, approach)
            except ProtocolError as error:
                text = str(error)
                if event is None or "expected player." not in text:
                    raise
                pad = self.model().padding
                on_pad = self.position() in {(event["x"], event["y"]), (event["x"] + pad, event["y"])}
                bottom = event["y"] in {self.model().height - 1, self.model().height - 1 - pad}
                if not on_pad or not bottom:
                    raise
                target, position = self.warp_projection(event)
                self.send("press down", "wait 15")
                self.drain()
                self.require(zone_id=target, **{"player.x": position[0], "player.y": position[1]})
                self.refresh_world()
        self.fixed_warp = fixed_warp
        self.visit_event = vermilion.VermilionJourney.visit_event.__get__(self, type(self))
        self.event_map = vermilion.VermilionJourney.event_map.__get__(self, type(self))
        self.collection_owner = vermilion.VermilionJourney.collection_owner.__get__(self, type(self))
        self.species_count = midgame.MidgameJourney.species_count
        base_key_door = self.key_door
        def key_door(point, facing, flag):
            # face() presses the direction. An open door would take that step.
            if self.flag(flag):
                return
            return base_key_door(point, facing, flag)
        self.key_door = key_door
        def fixed_leg(filename, label):
            # A trainer notice can consume the scripted press. Walk that cell again.
            path = midgame.SCENARIOS / filename
            route = json.loads(path.read_bytes())["routes"][label]
            self.require(zone_id=self.zone(route["map"]))
            padding = self.model().padding
            if self.position() != (route["start"][0] + padding, route["start"][1]):
                raise ProtocolError("fixed script entry differs: " + label + ":" + str(self.position()))
            self.summary.setdefault("fixed_scripts", []).append(dict(
                script=filename, route=label, sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
            for number, step in enumerate(route["steps"]):
                wait = "18" if step["kind"] == "ledge" else "10"
                self.send("press " + step["direction"], "wait " + wait)
                self.drain()
                target = route.get("destination")
                arrived = (step["to"][0] + padding, step["to"][1])
                if not (target and number == len(route["steps"]) - 1 and self.state["zone_id"] == self.zone(target)):
                    if self.position() != arrived:
                        self.send("press " + step["direction"], "wait " + wait)
                        self.drain()
                if target and number == len(route["steps"]) - 1:
                    self.require(zone_id=self.zone(target))
                elif self.position() != arrived:
                    block = (self.state.get("player") or {}).get("lastTraversalBlock") or {}
                    # A defeated trainer can remain on the next scripted cell.
                    # Walk around to the script's last cell instead of that tile.
                    if block.get("kind") == "npc":
                        final = route["steps"][-1]["to"]
                        self.navigate((final[0] + padding, final[1]))
                        break
                    raise ProtocolError("fixed source script step failed: " + label + ":" + str(step))
            self.refresh_world()
        self.fixed_leg = fixed_leg
        self.refresh_world = vermilion.VermilionJourney.refresh_world.__get__(self, type(self))
        self.require_event = lambda stable: None
        base_project = self.project_warp
        def project_warp(model, event):
            scenes = self.scene_data("data/rocketHideoutStory/scenes.json")
            for floor in scenes["elevator"]:
                if model.name != floor["map_id"]:
                    continue
                for index, exit in enumerate(floor["exits"], start=1):
                    if event["source_index"] == exit["warp"]:
                        cabin = self.models[self.zone("RocketHideoutElevator")]
                        return cabin.name, (index + 1 + cabin.padding, 1)
            return base_project(model, event)
        self.project_warp = project_warp
        base_advance = self.advance_event
        def advance_event(stop_phase=None):
            root = self.state.get("root")
            if root == "coastSwitch":
                # The statue menu opens on YES. That toggles the mansion doors.
                self.send("press a")
                return True
            if root == "coastQuiz":
                if getattr(self, "_quiz_answer", "yes") == "no" and not getattr(self, "_quiz_armed", False):
                    self._quiz_armed = True
                    self.send("press down")
                    return True
                self._quiz_armed = False
                self.send("press a")
                return True
            if root in {"safariBattle", "safariPassage"}:
                return midgame.MidgameJourney.advance_event(self, stop_phase)
            if self.state.get("root") == "fieldTravel":
                return midgame.MidgameJourney.advance_travel(self)
            if self.state.get("root") == "fieldGear":
                return midgame.MidgameJourney.advance_event(self, stop_phase)
            phase = lookup(self.state, "event.phase")
            if (self.state.get("root") == "event"
                    and lookup(self.state, "event.menu.active") is True):
                options = sequence(lookup(self.state, "event.menu.options"), "event options")
                if phase == "celadon-menu":
                    choices = getattr(self, "celadon_choices", None)
                    if not choices:
                        raise ProtocolError("unplanned Celadon menu: " + str(options))
                    choice = choices.pop(0)
                    if options.count(choice) != 1:
                        raise ProtocolError("fixed Celadon choice absent: " + choice + ": " + str(options))
                    self.select("event.menu.selected", options.index(choice) + 1)
                    self.send("press a")
                    return True
                if phase in {"hideout-floor", "silph-floor"}:
                    choice = getattr(self, "floor_choice", None)
                    if choice is None or options.count(choice) != 1:
                        raise ProtocolError("unplanned actual elevator menu: " + str(options))
                    self.select("event.menu.selected", options.index(choice) + 1)
                    self.send("press a")
                    return True
                event = lookup(self.state, "event.id")
                choice = getattr(self, "event_choices", {}).get(event)
                if choice is not None:
                    if options.count(choice) != 1:
                        raise ProtocolError("source service menu differs: " + str(event) + ": " + str(options))
                    self.select("event.menu.selected", options.index(choice) + 1)
                    self.send("press a")
                    return True
            return base_advance(stop_phase)
        self.advance_event = advance_event
        # The mart elevator is a floor menu. Its static warp points at 1F, but
        # the door stays closed until a floor is chosen. Stairs are the exit.
        base_portals = self.portals
        stairs = {
            "CELADON_MART_1F": {1, 2, 3, 4, 5},
            "CELADON_MART_2F": {1, 2},
            "CELADON_MART_3F": {1, 2},
            "CELADON_MART_4F": {1, 2},
            "CELADON_MART_5F": {1, 2},
            "CELADON_MART_ROOF": {1},
        }
        def portals(model):
            source = getattr(model, "source_data", None) or {}
            allowed = stairs.get(source.get("source_map_constant"))
            for point, kind, detail in base_portals(model):
                if allowed is not None and kind == "warp" and detail["source_index"] not in allowed:
                    continue
                yield point, kind, detail
        self.portals = portals
        self._post_rainbow = True

    def _fight_story(self, trainer_id):
        if self.defeated(trainer_id):
            return
        # The tower rival is a story scene, not a payout pin.
        if trainer_id not in getattr(self, "source_trainers", {}):
            self.travel(trainer_id.rsplit(":", 2)[0])
            self.interact(source_id=trainer_id)
            if not self.defeated(trainer_id):
                raise ProtocolError("story trainer was not defeated: " + trainer_id)
            return
        self.fight(trainer_id)

    def _visit_story(self, event_id):
        self.travel(event_id.rsplit(":", 2)[0])
        self.interact(source_id=event_id)

    def _rocket_hideout(self):
        """Game Corner poster, then the lift, Giovanni, and the Silph Scope."""
        import tools.harness.cerulean_journey as cerulean
        self.training_mode = None
        self._arrange_lead("starter")
        guard = cerulean.sid("GAME_CORNER", 11)
        self.travel(self.zone("GameCorner"))
        self.source_waypoint(9, 6)
        self._fight_story(guard)
        if not self.flag("ROCKET_HIDEOUT_SCENE_V1_GUARD_LEFT"):
            self._visit_story(guard)
        self.background("pokered:GAME_CORNER:background_events:1")
        self.warp(self.zone("RocketHideoutB1F"), "pokered:GAME_CORNER:warps:3")
        self.warp(self.zone("RocketHideoutB2F"), "pokered:ROCKET_HIDEOUT_B1F:warps:1")
        self.fixed_hideout(0, "RocketHideoutB3F")
        self.fixed_hideout(1, "RocketHideoutB4F")
        key_rocket = cerulean.sid("ROCKET_HIDEOUT_B4F", 4)
        self._fight_story(key_rocket)
        self._visit_story(key_rocket)
        if not self.flag("EVENT_ROCKET_DROPPED_LIFT_KEY"):
            raise ProtocolError("actual defeated Rocket did not drop Lift Key")
        self.visit_event = self._visit_story
        self.pickup(cerulean.sid("ROCKET_HIDEOUT_B4F", 9), "liftKey")
        self.warp(self.zone("RocketHideoutB3F"), "pokered:ROCKET_HIDEOUT_B4F:warps:1")
        self.fixed_hideout(2, "RocketHideoutB2F")
        self.fixed_hideout(3, "RocketHideoutElevator")
        self.floor_choice = "B4F"
        self.background("pokered:ROCKET_HIDEOUT_ELEVATOR:background_events:1")
        self.floor_choice = None
        self.exit_hideout_lift("RocketHideoutB4F")
        self._fight_story(cerulean.sid("ROCKET_HIDEOUT_B4F", 2))
        self._fight_story(cerulean.sid("ROCKET_HIDEOUT_B4F", 3))
        self.warp(self.zone("RocketHideoutElevator"))
        self.exit_hideout_lift("RocketHideoutB4F")
        self._fight_story(cerulean.sid("ROCKET_HIDEOUT_B4F", 1))
        self.pickup(cerulean.sid("ROCKET_HIDEOUT_B4F", 8), "silphScope")
        if self.quantity("silphScope") != 1:
            raise ProtocolError("Rocket Hideout did not give the Silph Scope")
        self.save()
        self.floor_choice = "B2F"
        self.warp(self.zone("RocketHideoutElevator"))
        self.background("pokered:ROCKET_HIDEOUT_ELEVATOR:background_events:1")
        self.floor_choice = None
        self.exit_hideout_lift("RocketHideoutB2F")
        self.fixed_hideout(4, "RocketHideoutB2F")
        self.fixed_warp(1, (26, 8))
        self.source_waypoint(22, 3)
        self.fixed_warp(2, (22, 2))
        self.heal_here("CeladonPokecenter")
        self.save()

    def _pokemon_tower(self):
        """Climb to the ghost, then Fuji's house for the Poké Flute."""
        import tools.harness.cerulean_journey as cerulean
        self.training_mode = None
        self._arrange_lead("starter")
        self._pin_tower_rival()
        self.heal_here("LavenderPokecenter")
        self.save()
        self.travel(self.zone("PokemonTower1F"))
        for floor in range(2, 7):
            self.warp(self.zone("PokemonTower" + str(floor) + "F"))
            if floor == 2:
                rival = cerulean.sid("POKEMON_TOWER_2F", 1)
                self._fight_story(rival)
        self.visit_event = self._visit_story
        self.pickup(cerulean.sid("POKEMON_TOWER_6F", 4), "rareCandy")
        scenes = self.scene_data("data/towerStory/scenes.json")
        self.scripted_wild = {"species": scenes["ghost"]["species"], "level": scenes["ghost"]["level"]}
        self.source_waypoint(10, 15)
        self.send("press down", "wait 10")
        self.drain()
        self.scripted_wild = None
        if not self.flag("EVENT_BEAT_GHOST_MAROWAK"):
            raise ProtocolError("unavailable/unconfirmed actual Scope ghost victory")
        self.warp(self.zone("PokemonTower7F"))
        for index in (1, 2, 3):
            self._fight_story(cerulean.sid("POKEMON_TOWER_7F", index))
        self._visit_story(cerulean.sid("POKEMON_TOWER_7F", 4))
        self.pickup(cerulean.sid("MR_FUJIS_HOUSE", 5), "pokeFlute", "EVENT_GOT_POKE_FLUTE")
        if not self.flag("EVENT_GOT_POKE_FLUTE") or not self.flag("EVENT_RESCUED_MR_FUJI"):
            raise ProtocolError("actual Fuji rescue or Poké Flute is missing")
        self.heal_here("LavenderPokecenter")
        self.save()

    def _through_route12_gate(self):
        """The gate is a warp, so the north edge looks closed to a plain path."""
        route12 = self.zone("Route12")
        if self.state["zone_id"] == route12 and self.position()[1] > 18:
            return
        self.travel(self.zone("LavenderTown"))
        self.travel(route12)
        if self.state["zone_id"] == route12 and self.position()[1] > 18:
            return
        self.warp(self.zone("Route12Gate1F"), "pokered:ROUTE_12:warps:1")
        self.warp(route12, "pokered:ROUTE_12_GATE_1F:warps:3")

    def _wake_route12(self):
        if self.flag("EVENT_BEAT_ROUTE12_SNORLAX"):
            return
        self.training_mode = None
        self._through_route12_gate()
        self.source_waypoint(10, 61)
        self.scripted_wild = {"species": "snorlax", "level": 30}
        self.use_item("pokeFlute")
        self.scripted_wild = None
        if not self.flag("EVENT_BEAT_ROUTE12_SNORLAX"):
            raise ProtocolError("actual source Snorlax battle did not remove blocker")
        self.refresh_world()

    def _reach_route13(self):
        if self.state["zone_id"] == self.zone("Route13"):
            return
        from tools.harness.cerulean_journey import connection_projection
        self._through_route12_gate()
        point = (11, 107)
        zone, dest = connection_projection(self.models, self.model(), point, "down")
        self.navigate(point)
        self.cross("down", zone, dest)

    def _koga(self):
        import tools.harness.cerulean_journey as cerulean
        self.training_mode = None
        self._arrange_lead("starter")
        self.heal_here("FuchsiaPokecenter")
        self.save()
        self._fight_story(cerulean.sid("FUCHSIA_GYM", 1))
        if not self.flag("BADGE_SOUL") or self.quantity("tm06") < 1:
            raise ProtocolError("Koga win did not award the Soul Badge and TM06")
        self.heal_here("FuchsiaPokecenter")
        self.save()
        self.summary.update(acceptance="Soul Badge earned", natural=True, forbidden_shortcuts=False)

    def _in_fuchsia(self):
        return self.state.get("zone_id") in {
            self.zone("FuchsiaCity"),
            self.zone("FuchsiaPokecenter"),
            self.zone("FuchsiaGym"),
        }

    def _toward_sabrina(self):
        """Fresh Water for the gate, then Silph Co. and Sabrina."""
        self.summary["acceptance"] = "walking toward the Marsh Badge"
        self._vermilion_tools()
        self._pin_route_trainers()
        self._pin_cached_trainers()
        self._pin_silph_rival()
        self._bind_post_rainbow()
        self._pin_map_shops("SaffronMart")
        # restock() reads packet. The 5.5b list is the large stack. This walk
        # buys the ordinary antidote and Super Potion counts.
        self.config.setdefault("packet", "lane-i")
        self.training_mode = None
        self._arrange_lead("starter")
        # A later save is already in Fuchsia. Going back to Saffron from here
        # walks onto the Cycling Road, and that door crashes without a Bicycle.
        if self.flag("BADGE_MARSH") and self.flag("EVENT_GOT_TM46") and self.quantity("tm46") >= 1:
            self.summary.update(acceptance="Marsh Badge earned", natural=True, forbidden_shortcuts=False)
            self._toward_blaine()
            return
        self.route_c_guard()
        from tools.harness.brock_journey import NaturalBlackout
        silph_done = (self.flag("EVENT_GOT_MASTER_BALL") and self.quantity("masterBall") >= 1
                      and self.flag("EVENT_BEAT_SILPH_CO_GIOVANNI") and self.flag("BIT_GOT_LAPRAS"))
        if silph_done:
            self.completed_steps.add("silph-rival-lapras-giovanni-president")
        blackouts = 0
        for _boundary in range(8):
            if "silph-rival-lapras-giovanni-president" in self.completed_steps:
                break
            try:
                self.route_c_silph()
                break
            except NaturalBlackout:
                # Giovanni follows the rival with no center. A wipe already
                # restored the party at the Saffron checkpoint. Re-enter healed.
                blackouts += 1
                if blackouts > 2:
                    raise
                self.summary.setdefault("silph_blackouts", []).append(self.state.get("zone_id"))
                self._arrange_lead("starter")
            except ProtocolError as error:
                text = str(error)
                if "Save boundary" not in text:
                    raise
                # The split already saved. The next call takes the following branch.
                self.summary.setdefault("silph_boundaries", []).append(text)
        else:
            raise ProtocolError("Silph save boundary repeated")
        marsh = (self.flag("BADGE_MARSH") and self.flag("EVENT_GOT_TM46") and self.quantity("tm46") >= 1)
        if not marsh:
            for _attempt in range(3):
                try:
                    self.route_c_sabrina()
                    break
                except NaturalBlackout:
                    if _attempt == 2:
                        raise
                    self.summary.setdefault("sabrina_blackouts", []).append(self.state.get("zone_id"))
                    self._arrange_lead("starter")
            else:
                raise ProtocolError("Sabrina blackout retry exhausted")
        self.summary.update(acceptance="Marsh Badge earned", natural=True, forbidden_shortcuts=False)
        self._toward_blaine()

    def _surf_known(self):
        return any("surf" in mon["moves"] for mon in self.party())

    def _toward_blaine(self):
        """Escape Rope, then the Safari Zone for HM03 and Surf."""
        self.summary["acceptance"] = "walking toward the Volcano Badge"
        self.config["content_scope"] = "lane-i"
        if self._surf_known():
            self._to_cinnabar()
            return
        self._pin_map_shops("SaffronMart")
        if self.quantity("escapeRope") < 1:
            clerk = self.zone("SaffronMart") + ":objects:1"
            shop = self.vermilion["shops"][clerk]
            price = shop["prices"]["escapeRope"]
            if "escapeRope" not in shop.get("stock", ()) or type(price) is not int or price <= 0:
                raise ProtocolError("Saffron Mart does not sell an Escape Rope")
            self.travel(self.zone("SaffronMart"))
            self.buy_item(clerk, "escapeRope", 1, price)
        if self.quantity("escapeRope") < 1:
            raise ProtocolError("Escape Rope was not bought")
        # The rope fills the bag. Sell the old TMs here. FuchsiaMart is past
        # the Celadon edge, and that edge is a dead pocket.
        self.ensure_room("SaffronMart")
        zone = self.state.get("zone_id") or ""
        if "FUCHSIA" not in zone and "SAFARI_ZONE" not in zone:
            self._east_to_fuchsia()
        self.safari_journey()
        self._to_cinnabar()

    def _east_to_fuchsia(self):
        """Saffron's west edge dead-ends on Celadon. The east road reaches Fuchsia."""
        from tools.harness.cerulean_journey import connection_projection
        zone = self.state.get("zone_id") or ""
        if self.state.get("zone_id") == self.zone("Route8"):
            self._through_route8_gate()
            self.navigate((59, 8))
            name, dest = connection_projection(self.models, self.model(), self.position(), "right")
            self.cross("right", name, dest)
            self.require(zone_id=self.zone("LavenderTown"))
        elif not any(token in zone for token in ("LAVENDER", "ROUTE_12", "ROUTE_13", "ROUTE_14", "ROUTE_15")):
            if self.state.get("zone_id") != self.zone("SaffronCity"):
                self.travel(self.zone("SaffronCity"))
            self.navigate((39, 16))
            name, dest = connection_projection(self.models, self.model(), self.position(), "right")
            self.cross("right", name, dest)
            self._through_route8_gate()
            self.navigate((59, 8))
            name, dest = connection_projection(self.models, self.model(), self.position(), "right")
            self.cross("right", name, dest)
            self.require(zone_id=self.zone("LavenderTown"))
        self._reach_route13()
        self.enter_route14_from_east()
        self.finish_eastern_road_to_fuchsia()
        self.heal_here("FuchsiaPokecenter")
        self.save()

    def _through_route8_gate(self):
        """The west gate splits Route 8. The road continues on the far side."""
        if self.state["zone_id"] != self.zone("Route8") or self.position()[0] >= 8:
            return
        self.warp(self.zone("Route8Gate"), "pokered:ROUTE_8:warps:1")
        self.warp(self.zone("Route8"), "pokered:ROUTE_8_GATE:warps:3")

    def _to_cinnabar(self):
        """Pallet, then Surf south on Route 21. The Route 20 rock stays closed."""
        from tools.harness.brock_journey import NaturalBlackout
        self.summary["acceptance"] = "walking toward the Volcano Badge"
        self.training_mode = None
        for _ in range(3):
            try:
                self._cinnabar_once()
                return
            except NaturalBlackout:
                self.summary.setdefault("cinnabar_blackouts", []).append(self.state.get("zone_id"))
                self._arrange_lead("starter")
        raise ProtocolError("Cinnabar walk blacked out")

    def _cinnabar_once(self):
        self._arrange_lead("starter")
        zone = self.state.get("zone_id") or ""
        if self.flag("BADGE_VOLCANO"):
            self._toward_giovanni()
            return
        if "CINNABAR" in zone or "MANSION" in zone:
            self._mansion_and_blaine()
            return
        if "ROUTE_21" in zone:
            self._follow_route21()
            self._mansion_and_blaine()
            return
        if "PALLET" in zone or zone == "pallet_town":
            self._surf_from_pallet()
            self._mansion_and_blaine()
            return
        if "ROUTE_19" in zone or "ROUTE_20" in zone or "SEAFOAM" in zone:
            self._surf_coast()
            self._mansion_and_blaine()
            return
        self._coast_to_cinnabar()
        self._mansion_and_blaine()

    def _map_name(self):
        return self.state.get("zone_id") or ""

    def _on(self, name):
        return self._map_name() == self.zone(name)

    def _cross_edge(self, direction):
        """Walk onto the nearest passable header edge and take that connection."""
        from tools.harness.cerulean_journey import connection_projection
        # A cut tree stays open in the save. The planner starts from the authored wall.
        self.apply_world_observation(self.observe("vermilion-world"))
        model = self.model()
        if direction == "down":
            points = [(x, model.height - 1) for x in range(model.width)]
        elif direction == "up":
            points = [(x, 0) for x in range(model.width)]
        elif direction == "left":
            points = [(0, y) for y in range(model.height)]
        else:
            points = [(model.width - 1, y) for y in range(model.height)]
        options = []
        for point in points:
            if model.collision[point[1]][point[0]]:
                continue
            try:
                connection_projection(self.models, model, point, direction)
            except ProtocolError:
                continue
            try:
                route = model.path(self.position(), {point}, self.occupied())
            except ProtocolError:
                continue
            options.append((len(route), point))
        if not options:
            raise ProtocolError("no open " + direction + " edge from " + self._map_name())
        options.sort()
        point = options[0][1]
        if self.position() != point:
            self.navigate(point)
        zone, dest = self.project(direction)
        self.cross(direction, zone, dest)

    def _coast_to_cinnabar(self):
        """Route 4's west ledge blocks Mt. Moon. Surf Route 19 onto Route 20."""
        self._return_to_fuchsia_shore()
        self._surf_coast()

    def _return_to_fuchsia_shore(self):
        for _ in range(24):
            zone = self._map_name()
            if "ROUTE_19" in zone or "ROUTE_20" in zone or "CINNABAR" in zone:
                return
            if "FUCHSIA_CITY" in zone:
                self.heal_here("FuchsiaPokecenter")
                self.save()
                self.warp(self.zone("FuchsiaCity"))
                self.navigate((23, 35))
                self.cross("down", self.zone("Route19"), (13, 0))
                return
            if "FUCHSIA" in zone:
                self.warp(self.zone("FuchsiaCity"))
                continue
            if "ROUTE_4" in zone:
                self._cross_edge("right")
                continue
            if "CERULEAN_POKECENTER" in zone:
                self.warp(self.zone("CeruleanCity"))
                continue
            if "CERULEAN" in zone:
                self.apply_world_observation(self.observe("vermilion-world"))
                if self.model().collision[28][19]:
                    self._cut_tree("CeruleanCity", (19, 28))
                self._cross_edge("down")
                continue
            if self._on("Route5Gate"):
                self.warp(self.zone("Route5"), self.zone("Route5Gate") + ":warps:1")
                continue
            if self._on("Route5"):
                if self.position()[1] <= 30:
                    self.warp(self.zone("Route5Gate"), self.zone("Route5") + ":warps:1")
                    self.warp(self.zone("Route5"), self.zone("Route5Gate") + ":warps:1")
                self._cross_edge("down")
                continue
            if "SAFFRON_POKECENTER" in zone or "SAFFRON_MART" in zone:
                self.warp(self.zone("SaffronCity"))
                continue
            if "SAFFRON" in zone:
                self._cross_edge("right")
                continue
            if self._on("Route8Gate"):
                self.warp(self.zone("Route8"), self.zone("Route8Gate") + ":warps:3")
                continue
            if self._on("Route8"):
                if self.position()[0] < 8:
                    self.warp(self.zone("Route8Gate"), self.zone("Route8") + ":warps:1")
                    self.warp(self.zone("Route8"), self.zone("Route8Gate") + ":warps:3")
                self._cross_edge("right")
                continue
            if "LAVENDER_POKECENTER" in zone:
                self.warp(self.zone("LavenderTown"))
                continue
            if "LAVENDER" in zone and "ROUTE" not in zone:
                self.source_waypoint(9, 17)
                self.cross("down", self.zone("Route12"), (9, 0))
                continue
            if self._on("Route12Gate1F"):
                self.warp(self.zone("Route12"), self.zone("Route12Gate1F") + ":warps:3")
                continue
            if self._on("Route12"):
                if self.position()[1] < 21:
                    self.warp(self.zone("Route12Gate1F"), self.zone("Route12") + ":warps:1")
                    self.warp(self.zone("Route12"), self.zone("Route12Gate1F") + ":warps:3")
                self.source_waypoint(11, 107)
                self.cross("down", self.zone("Route13"), (51, 0))
                continue
            if self._on("Route13"):
                # The north door lands on Route 14 y=6, and that trainer blocks the road.
                self.source_waypoint(0, 10)
                self.cross("left", self.zone("Route14"), (19, 10))
                continue
            if self._on("Route14"):
                if self.position()[1] < 10:
                    self._cross_edge("right")
                    continue
                self.finish_eastern_road_to_fuchsia()
                continue
            if self._on("Route15Gate1F"):
                self.warp(self.zone("Route15"), self.zone("Route15Gate1F") + ":warps:2")
                continue
            if self._on("Route15"):
                if self.position()[0] > 10:
                    self.warp(self.zone("Route15Gate1F"), self.zone("Route15") + ":warps:4")
                    self.warp(self.zone("Route15"), self.zone("Route15Gate1F") + ":warps:2")
                self.source_waypoint(0, 8)
                self.cross("left", self.zone("FuchsiaCity"), (39, 16))
                continue
            raise ProtocolError("no coast return from " + zone + " " + str(self.position()))
        raise ProtocolError("coast return did not reach Fuchsia: " + self._map_name())

    _SURF_FEET = {0x14, 0x32, 0x48}

    def _surf_goals(self, ys):
        model = self.model()
        return [(0, y) for y in ys if model.feet[y][0] in self._SURF_FEET]

    def _surf_follow(self, goals):
        from collections import deque
        goals = set(goals)
        for _ in range(8):
            if self._on("CinnabarIsland"):
                return
            model = self.model()
            start = self.position()
            if start in goals:
                return
            blocked = set(self.occupied())
            queue, prev = deque([start]), {start: None}
            found = None
            while queue:
                x, y = queue.popleft()
                for dx, dy, name in ((1, 0, "right"), (-1, 0, "left"), (0, 1, "down"), (0, -1, "up")):
                    nxt = (x + dx, y + dy)
                    if nxt in prev or nxt[0] < 0 or nxt[1] < 0 or nxt[0] >= model.width or nxt[1] >= model.height:
                        continue
                    if model.feet[nxt[1]][nxt[0]] not in self._SURF_FEET or nxt in blocked:
                        continue
                    prev[nxt] = ((x, y), name)
                    if nxt in goals:
                        found = nxt
                        queue.clear()
                        break
                    queue.append(nxt)
            if found is None:
                raise ProtocolError("no surf route on " + self._map_name() + " from " + str(start))
            steps, cur = [], found
            while prev[cur] is not None:
                parent, name = prev[cur]
                steps.append(name)
                cur = parent
            steps.reverse()
            moved = False
            for name in steps:
                before, zone = self.position(), self._map_name()
                step = {"right": (1, 0), "left": (-1, 0), "down": (0, 1), "up": (0, -1)}[name]
                self._surf_press(name, 1)
                if self._map_name() != zone or self._on("CinnabarIsland"):
                    return
                if self.position() != before:
                    moved = True
                if self.position() != (before[0] + step[0], before[1] + step[1]):
                    break
            else:
                return
            if not moved:
                raise ProtocolError("surf step did not move from " + str(start) + " on " + self._map_name())
        raise ProtocolError("surf route did not settle on " + self._map_name() + " " + str(self.position()))

    def _surf_off(self, direction):
        self.send("press " + direction, "wait 12")
        self.drain()

    def _surf_coast(self):
        if self._on("Route19"):
            if self.model().collision[self.position()[1]][self.position()[0]] == 0:
                self.navigate((13, 9))
                self.face("down")
                index = next(i for i, mon in enumerate(self.party(), 1) if "surf" in mon["moves"])
                self.use_field(index, "surf")
                if self.model().collision[self.position()[1]][self.position()[0]] == 0:
                    self._surf_press("down", 1)
            self._surf_follow(self._surf_goals(range(40, 53)))
            if not self._on("Route20"):
                self._surf_off("left")
            if not self._on("Route20"):
                raise ProtocolError("Route 19 Surf did not enter Route 20: " + self._map_name() + " " + str(self.position()))
        if "SEAFOAM" in self._map_name() or self._on("Route20"):
            self._cross_seafoam()
        if not self._on("CinnabarIsland"):
            raise ProtocolError("Route 20 Surf did not reach Cinnabar: " + self._map_name() + " " + str(self.position()))
        x, y = self.position()
        if self.model().collision[y][x] != 0:
            raise ProtocolError("Cinnabar arrival is still water: " + str(self.position()))
        self._record_screen("cinnabar-arrival", 20)

    def _route20_side(self):
        x, y = self.position()
        foot = self.model().feet[y][x]
        if self.model().collision[y][x] == 0 and 56 <= x <= 61 and y >= 9:
            return "west-land"
        if x < 62 and foot in self._SURF_FEET:
            return "west-water"
        return "east"

    def _cross_seafoam(self):
        """The faithful rock splits Route 20. Surfing B3F joins the two shores."""
        if self._on("Route20") and self._route20_side() == "east":
            self._surf_follow([(62, y) for y in range(2, 6)])
            if self.position()[0] == 62:
                self._surf_off("left")
            x, y = self.position()
            if self.model().collision[y][x] != 0:
                raise ProtocolError("Seafoam shore did not accept the dismount: " + str(self.position()))
            self.warp(self.zone("SeafoamIslands1F"), self.zone("Route20") + ":warps:1")
        if "SEAFOAM" in self._map_name():
            self._seafoam_stairs()
        if self._on("Route20") and self._route20_side() == "west-land":
            self.navigate((58, 11))
            self.face("down")
            index = next(i for i, mon in enumerate(self.party(), 1) if "surf" in mon["moves"])
            self.use_field(index, "surf")
            if self.position() == (58, 11):
                self._surf_press("down", 1)
        if self._on("Route20") and self._route20_side() == "west-water":
            self._surf_follow(self._surf_goals(range(4, 14)))
            self._surf_off("left")

    def _seafoam_stairs(self):
        """Both B3F boulders stop the current. Surf then climbs out the west door."""
        if not self._on("SeafoamIslands1F"):
            raise ProtocolError("Seafoam stairs expected 1F and found " + self._map_name())
        if self.flag("EVENT_SEAFOAM3_BOULDER1_DOWN_HOLE") and self.flag("EVENT_SEAFOAM3_BOULDER2_DOWN_HOLE"):
            for source, index, target in (
                ("SeafoamIslands1F", 5, "SeafoamIslandsB1F"),
                ("SeafoamIslandsB1F", 3, "SeafoamIslandsB2F"),
                ("SeafoamIslandsB2F", 2, "SeafoamIslandsB3F"),
            ):
                self.warp(self.zone(target), self.zone(source) + ":warps:" + str(index))
        else:
            self._drop_seafoam_boulders()
        self._surf_calm_channel()
        if not self._on("SeafoamIslands1F") or self.position()[0] < 20:
            raise ProtocolError("Seafoam channel missed the west shore: " + self._map_name() + " " + str(self.position()))
        self.warp(self.zone("Route20"), self.zone("SeafoamIslands1F") + ":warps:3")

    def _record_screen(self, label, seconds=30):
        """One LCD crop. The grab is the panel only, with the pointer hidden."""
        if getattr(self, "_screen_clip", None) == label:
            return
        recorder = getattr(self, "clip_recorder", None)
        start = getattr(recorder, "start", None)
        if not start:
            return
        if start(label, seconds=seconds):
            self._screen_clip = label

    def _use_strength(self):
        travel = self.observe("midgame-state").get("fieldTravel") or {}
        if travel.get("strength") is True:
            return
        index = next(i for i, mon in enumerate(self.party(), 1) if "strength" in mon["moves"])
        self.use_field(index, "strength")

    def _step(self, direction):
        before = self.position()
        grinding = (getattr(self, "_bench_share", False)
                    and not getattr(self, "_stopping", False)
                    and not getattr(self, "_puzzle", False)
                    and not getattr(self, "_flee_wilds", False))
        if grinding:
            self.training_mode = "league-bench"
        try:
            self.send("press " + direction, "wait 10")
            self.drain()
        finally:
            if grinding:
                self.training_mode = None
        return self.position() != before

    def _shove(self, direction):
        """The first press arms the boulder. The second moves it. The player stays put."""
        before = self.position()
        self.send("press " + direction, "wait 8")
        self.drain()
        if self.position() != before:
            raise ProtocolError("boulder arm walked from " + str(before))
        self.send("press " + direction, "wait 12")
        self.drain()
        if self.position() != before:
            raise ProtocolError("boulder push walked from " + str(before))

    def _shove_line(self, direction, count):
        """Each push leaves the player one tile behind, so the next one steps up first."""
        for index in range(count):
            if index and not self._step(direction):
                raise ProtocolError("could not follow the boulder " + direction + " from " + str(self.position()))
            self._shove(direction)

    def _require_flag(self, name):
        for _ in range(6):
            if self.flag(name):
                return
            self.send("wait 8")
            self.drain()
        raise ProtocolError("Seafoam boulder did not fall: " + name)

    def _drop_seafoam_boulders(self):
        """Push each boulder into its own hole. (15, 8) stays a current until both B3F flags are set."""
        self._use_strength()
        self.navigate((19, 10))
        self._shove("left")
        self.navigate((17, 11))
        self._shove_line("up", 4)
        self._require_flag("EVENT_SEAFOAM1_BOULDER1_DOWN_HOLE")
        self.navigate((23, 8))
        self.navigate((27, 7))
        self._shove_line("left", 2)
        self.navigate((24, 8))
        self._shove("up")
        self._require_flag("EVENT_SEAFOAM1_BOULDER2_DOWN_HOLE")
        self.warp(self.zone("SeafoamIslandsB1F"), self.zone("SeafoamIslands1F") + ":warps:5")
        self._use_strength()
        self.navigate((16, 6))
        self._shove("right")
        self._require_flag("EVENT_SEAFOAM2_BOULDER1_DOWN_HOLE")
        self.warp(self.zone("SeafoamIslandsB2F"), self.zone("SeafoamIslandsB1F") + ":warps:1")
        self._use_strength()
        self.navigate((17, 6))
        self._shove("right")
        self._require_flag("EVENT_SEAFOAM3_BOULDER1_DOWN_HOLE")
        self.warp(self.zone("SeafoamIslandsB1F"), self.zone("SeafoamIslandsB2F") + ":warps:1")
        self.warp(self.zone("SeafoamIslands1F"), self.zone("SeafoamIslandsB1F") + ":warps:2")
        # (23, 8) to the stair is the same length through the hole. Stay on x=25.
        self.navigate((23, 8))
        self.navigate((25, 8))
        self.warp(self.zone("SeafoamIslandsB1F"), self.zone("SeafoamIslands1F") + ":warps:6")
        self._use_strength()
        self.navigate((21, 6))
        self._shove("right")
        self._require_flag("EVENT_SEAFOAM2_BOULDER2_DOWN_HOLE")
        if not self._step("right") or not self._step("right"):
            raise ProtocolError("could not step into the B1F hole from " + str(self.position()))
        if not self._on("SeafoamIslandsB2F"):
            raise ProtocolError("B1F hole missed B2F: " + self._map_name() + " " + str(self.position()))
        self._use_strength()
        self.navigate((24, 6))
        self._shove("left")
        self._require_flag("EVENT_SEAFOAM3_BOULDER2_DOWN_HOLE")
        self.warp(self.zone("SeafoamIslandsB3F"), self.zone("SeafoamIslandsB2F") + ":warps:5")
        self.warp(self.zone("SeafoamIslandsB4F"), self.zone("SeafoamIslandsB3F") + ":warps:3")
        self.warp(self.zone("SeafoamIslandsB3F"), self.zone("SeafoamIslandsB4F") + ":warps:3")

    def _surf_calm_channel(self):
        """(15, 8) is ordinary water once both boulders are down. (23, 9) is the west shore."""
        if not self._on("SeafoamIslandsB3F"):
            raise ProtocolError("calm channel expected B3F and found " + self._map_name())
        self.navigate((15, 7))
        self._record_screen("seafoam-crossing", 30)
        index = next(i for i, mon in enumerate(self.party(), 1) if "surf" in mon["moves"])
        self.use_field(index, "surf")
        if self.position() == (15, 7):
            self._surf_press("down", 1)
        if not self._on("SeafoamIslandsB3F") or self.position() != (15, 8):
            raise ProtocolError("B3F channel did not take Surf: " + self._map_name() + " " + str(self.position()))
        self._surf_follow([(23, 10)])
        self._surf_press("up", 1)
        if self.position() != (23, 9):
            raise ProtocolError("B3F channel did not reach the west shore: " + str(self.position()))
        # Stepping onto (25, 14) is the stair. warp() arms that transition.
        self.warp(self.zone("SeafoamIslandsB2F"), self.zone("SeafoamIslandsB3F") + ":warps:5")
        self.warp(self.zone("SeafoamIslandsB1F"), self.zone("SeafoamIslandsB2F") + ":warps:6")
        self.warp(self.zone("SeafoamIslands1F"), self.zone("SeafoamIslandsB1F") + ":warps:5")

    def _surf_press(self, direction, count):
        for _ in range(count):
            if self._on("CinnabarIsland"):
                return
            self.send("press " + direction, "wait 10")
            self.drain()

    def _surf_from_pallet(self):
        if "PALLET" not in self._map_name() and self._map_name() != "pallet_town":
            return
        self.navigate((8, 16))
        self.face("left")
        index = next(i for i, mon in enumerate(self.party(), 1) if "surf" in mon["moves"])
        self.use_field(index, "surf")
        if self.position() == (8, 16):
            self._surf_press("left", 1)
        self._surf_press("down", 3)
        if not self._on("Route21"):
            raise ProtocolError("Surf south from Pallet did not enter Route 21: " + str(self.position()))
        self._follow_route21()

    def _follow_route21(self):
        """Water from the north shore (6, 0) reaches Cinnabar at (3, 89)."""
        if self.position()[1] == 0 and self.position()[0] != 6:
            direction = "left" if self.position()[0] > 6 else "right"
            self._surf_press(direction, abs(self.position()[0] - 6))
        if self.position() == (6, 0):
            self._surf_press("down", 23)
            self._surf_press("left", 3)
            self._surf_press("down", 67)
        elif not self._on("CinnabarIsland"):
            self._surf_press("down", 90)
        if not self._on("CinnabarIsland"):
            raise ProtocolError("Route 21 Surf did not reach Cinnabar: " + str(self.position()))
        for _ in range(8):
            x, y = self.position()
            if self.model().collision[y][x] == 0:
                break
            self._surf_press("down" if y < 4 else "right", 1)
        x, y = self.position()
        if self.model().collision[y][x] != 0:
            raise ProtocolError("Cinnabar Surf did not reach land: " + str(self.position()))

    _MANSION_DOORS = {
        "PokemonMansion1F": ((12, 6, 0x0e, 0x2d), (8, 3, 0x2d, 0x0e), (10, 8, 0x2d, 0x0e), (13, 13, 0x2d, 0x0e)),
        "PokemonMansion2F": ((4, 2, 0x0e, 0x5f), (9, 4, 0x54, 0x0e), (3, 11, 0x5f, 0x0e)),
        "PokemonMansion3F": ((7, 2, 0x0e, 0x5f), (7, 5, 0x5f, 0x0e)),
        "PokemonMansionB1F": ((13, 8, 0x0e, 0x2d), (6, 11, 0x0e, 0x5f), (4, 3, 0x5f, 0x0e), (8, 8, 0x54, 0x0e)),
    }
    _GATE_SOLID = {
        0x0e: (False, False, False, False),
        0x2d: (False, False, True, True),
        0x5f: (False, True, False, True),
        0x54: (True, True, False, False),
    }
    _GYM_GATES = (
        (1, 9, 3, 0x54), (2, 6, 3, 0x54), (3, 6, 6, 0x54),
        (4, 3, 8, 0x5f), (5, 2, 6, 0x54), (6, 2, 3, 0x54),
    )

    def _paint_gates(self, doors):
        """Replace each 2x2 gate. A closed door also opens the quadrants the block leaves empty."""
        model = self.model()
        if not hasattr(model, "_gate_base"):
            model._gate_base = [row[:] for row in model.collision]
        for y, row in enumerate(model.collision):
            row[:] = model._gate_base[y]
        for bx, by, block in doors:
            pattern = self._GATE_SOLID[block]
            for dy in (0, 1):
                for dx in (0, 1):
                    model.collision[by * 2 + dy][bx * 2 + dx] = 1 if pattern[dy * 2 + dx] else 0
        return model

    def _apply_mansion_gates(self):
        floor = next((name for name in self._MANSION_DOORS if self._on(name)), None)
        if floor is None:
            return
        on = self.flag("EVENT_MANSION_SWITCH_ON")
        doors = tuple((bx, by, onb if on else off) for bx, by, off, onb in self._MANSION_DOORS[floor])
        model = self._paint_gates(doors)
        if floor == "PokemonMansion3F":
            for x, y in ((16, 14), (17, 14), (19, 14)):
                model.collision[y][x] = 1

    def _press_mansion_switch(self, stand):
        self._apply_mansion_gates()
        self.navigate(stand)
        self.face("up")
        before = self.flag("EVENT_MANSION_SWITCH_ON")
        self.send("press a")
        if self.state.get("root") == "overworld":
            self.send("wait 12")
        self.drain()
        if self.flag("EVENT_MANSION_SWITCH_ON") == before:
            raise ProtocolError("mansion switch did not toggle at " + str(stand))
        self._apply_mansion_gates()

    def _collect_secret_key(self):
        """3F's switch opens the hole. The basement switches then open the key room."""
        if not self._on("PokemonMansion1F"):
            if not self._on("CinnabarIsland"):
                self.warp(self.zone("CinnabarIsland"))
            self.warp(self.zone("PokemonMansion1F"), "pokered:CINNABAR_ISLAND:warps:1")
        self._apply_mansion_gates()
        self.warp(self.zone("PokemonMansion2F"), self.zone("PokemonMansion1F") + ":warps:5")
        self._apply_mansion_gates()
        # 2F's east stair is the next cell. Step through it and come straight back.
        self.warp(self.zone("PokemonMansion3F"), self.zone("PokemonMansion2F") + ":warps:2")
        self._apply_mansion_gates()
        self.warp(self.zone("PokemonMansion2F"), self.zone("PokemonMansion3F") + ":warps:1")
        self._apply_mansion_gates()
        self.warp(self.zone("PokemonMansion3F"), self.zone("PokemonMansion2F") + ":warps:4")
        self._apply_mansion_gates()
        self._press_mansion_switch((10, 6))
        self.navigate((16, 13))
        self.send("press down", "wait 15")
        self.drain()
        if not self._on("PokemonMansion1F"):
            raise ProtocolError("mansion hole missed 1F: " + self._map_name() + " " + str(self.position()))
        self._apply_mansion_gates()
        self.warp(self.zone("PokemonMansionB1F"), self.zone("PokemonMansion1F") + ":warps:6")
        self._apply_mansion_gates()
        self._press_mansion_switch((18, 26))
        self._press_mansion_switch((20, 4))
        self.interact(source_id="pokered:POKEMON_MANSION_B1F:objects:8")
        if self.state.get("root") != "overworld":
            self.drain()
        if self.quantity("secretKey") < 1:
            raise ProtocolError("secret key was not picked up")
        self._leave_mansion()

    def _leave_mansion(self):
        """The key switch closes the stair. The other switch reopens 1F's southeast door."""
        if self._on("PokemonMansionB1F"):
            if self.flag("EVENT_MANSION_SWITCH_ON"):
                self._press_mansion_switch((20, 4))
            self._press_mansion_switch((18, 26))
            self._apply_mansion_gates()
            self.warp(self.zone("PokemonMansion1F"), self.zone("PokemonMansionB1F") + ":warps:1")
        if not self._on("CinnabarIsland"):
            self._apply_mansion_gates()
            # The scientist looks along y=17. The southeast door is the other way.
            for x in range(17):
                self.model().collision[17][x] = 1
            self.navigate((26, 26))
            self.send("press down", "wait 15")
            self.drain()
            if self._on("PokemonMansion1F") and self.position() == (26, 27):
                self.send("press down", "wait 15")
                self.drain()
        if not self._on("CinnabarIsland"):
            raise ProtocolError("mansion exit missed Cinnabar: " + self._map_name() + " " + str(self.position()))

    def _apply_cinnabar_gates(self):
        if not self._on("CinnabarGym"):
            return
        doors = tuple(
            (bx, by, 0x0e if self.flag("EVENT_CINNABAR_GYM_GATE" + str(index) + "_UNLOCKED") else closed)
            for index, bx, by, closed in self._GYM_GATES
        )
        self._paint_gates(doors)

    def _pin_gym_payouts(self):
        """The coast gym is fought by talk. Publish the payout only while the battle is scored."""
        if getattr(self, "_gym_payouts", False):
            return
        payouts = {
            "pokered:CINNABAR_GYM:objects:" + str(index): payout
            for index, payout in enumerate((4653, 900, 3240, 850, 3690, 1025, 3330, 925), start=1)
        }
        payouts.update({
            "pokered:VIRIDIAN_GYM:objects:1": 4950,
            "pokered:VIRIDIAN_GYM:objects:2": 1365,
            "pokered:VIRIDIAN_GYM:objects:3": 1000,
            "pokered:VIRIDIAN_GYM:objects:4": 1720,
            "pokered:VIRIDIAN_GYM:objects:5": 1075,
            "pokered:VIRIDIAN_GYM:objects:6": 1505,
            "pokered:VIRIDIAN_GYM:objects:7": 950,
            "pokered:VIRIDIAN_GYM:objects:8": 1560,
            "pokered:VIRIDIAN_GYM:objects:9": 1365,
        })
        base = self.battle

        def battle(name, strategy="attack", expected=None):
            trainer_id = lookup(self.state, "event.id")
            pinned = trainer_id in payouts and trainer_id not in self.source_trainers
            if pinned:
                self.source_trainers[trainer_id] = {"payout": payouts[trainer_id]}
            try:
                return base(name, strategy=strategy, expected=expected)
            finally:
                if pinned:
                    self.source_trainers.pop(trainer_id, None)

        self.battle = battle
        self._gym_payouts = True

    def _answer_quiz(self, stand, answer, flag):
        if self.flag(flag):
            return
        self._apply_cinnabar_gates()
        self.navigate(stand)
        self.face("up")
        self._quiz_answer = answer
        self._quiz_armed = False
        self.send("press a")
        if self.state.get("root") == "overworld":
            self.send("wait 12")
        self.drain()
        if not self.flag(flag):
            raise ProtocolError("Cinnabar quiz did not open " + flag)
        self._apply_cinnabar_gates()

    def _mansion_and_blaine(self):
        if self.flag("BADGE_VOLCANO"):
            self._toward_giovanni()
            return
        if len(self.inventory()["slots"]) > 15:
            self.store_unused_items("CinnabarPokecenter")
        if "MANSION" not in self._map_name() and "GYM" not in self._map_name():
            if not self._on("CinnabarIsland"):
                self.warp(self.zone("CinnabarIsland"))
            self.heal_here("CinnabarPokecenter")
            self.save()
        if self.quantity("secretKey") < 1 and not self.flag("PICKUP:pokered:POKEMON_MANSION_B1F:objects:8"):
            self._collect_secret_key()
        self.heal_here("CinnabarPokecenter")
        self.save()
        self._arrange_lead("starter")
        if self._on("CinnabarPokecenter"):
            # The center door is the last outdoor map. Step out; do not project it as Viridian.
            self.navigate((3, 6))
            self.send("press down", "wait 15")
            self.drain()
            if self._on("CinnabarPokecenter"):
                self.send("press down", "wait 15")
                self.drain()
        if not self._on("CinnabarIsland"):
            raise ProtocolError("Cinnabar Center did not open onto the island: " + self._map_name() + " " + str(self.position()))
        self.warp(self.zone("CinnabarGym"), "pokered:CINNABAR_ISLAND:warps:2")
        self._pin_gym_payouts()
        for stand, answer, number in (
            ((15, 8), "yes", 1), ((10, 2), "no", 2), ((9, 8), "no", 3),
            ((9, 14), "no", 4), ((1, 14), "yes", 5), ((1, 8), "no", 6),
        ):
            self._answer_quiz(stand, answer, "EVENT_CINNABAR_GYM_GATE" + str(number) + "_UNLOCKED")
        self._apply_cinnabar_gates()
        self._fight_story("pokered:CINNABAR_GYM:objects:1")
        if not self.flag("BADGE_VOLCANO"):
            raise ProtocolError("Blaine did not award the Volcano Badge")
        self.heal_here("CinnabarPokecenter")
        self.save()
        self.summary.update(acceptance="Volcano Badge earned", natural=True, forbidden_shortcuts=False)
        self._toward_giovanni()

    def _surf_route21_north(self):
        """The south channel is column 3 until the jog at row 23, then column 6 into Pallet."""
        stalls = 0
        for _ in range(120):
            if not self._on("Route21"):
                return
            x, y = self.position()
            if y > 23 and x != 3:
                direction = "left" if x > 3 else "right"
            elif y > 23 or x == 6:
                direction = "up"
            else:
                direction = "left" if x > 6 else "right"
            before = self.position()
            self._surf_press(direction, 1)
            if self._on("Route21") and self.position() == before:
                stalls += 1
                if stalls > 6:
                    raise ProtocolError("Route 21 surf stalled at " + str(self.position()))
            else:
                stalls = 0
        if self._on("Route21"):
            raise ProtocolError("Route 21 surf did not reach Pallet: " + str(self.position()))

    def _settle_gym(self):
        for _ in range(160):
            root = self.state.get("root")
            if root == "battle":
                if lookup(self.state, "battle.trainerName"):
                    self.battle("viridian-gym")
                else:
                    self.flee()
                continue
            if root == "dialog":
                self.dialog()
                continue
            if root == "learning":
                self.learning()
                continue
            if root == "evolution":
                self.evolution()
                continue
            if (root == "overworld" and self.state.get("overworld") in (None, "explore")
                    and lookup(self.state, "player.settled") is True):
                return
            self.send("wait 3")
        raise ProtocolError("Viridian Gym input did not settle: " + str(self.state.get("root")))

    def _gym_presses(self, direction, count, landing):
        for _ in range(count):
            self.send("press " + direction, "wait 10")
            self._settle_gym()
        if self.position() != landing or not self._on("ViridianGym"):
            raise ProtocolError("Viridian Gym path missed " + str(landing) + " at " + str(self.position()))

    def _walk_viridian_gym(self):
        """Ride the east arrows and fight the corridor blackbelt from his side.

        He watches every tile of the only walk to Giovanni. A fight from the
        south leaves him standing on that door. The top arrow stops on his
        east side, so the battle keeps him on his own tile.
        """
        if self.position() != (16, 17):
            raise ProtocolError("Viridian Gym door landed at " + str(self.position()))
        for direction, count, landing in (
            ("up", 1, (16, 16)),
            ("right", 1, (17, 16)),
            ("up", 4, (17, 12)),
            ("right", 2, (19, 12)),
        ):
            self._gym_presses(direction, count, landing)
        self._gym_presses("up", 1, (19, 2))
        self._gym_presses("up", 1, (11, 1))
        self.face("left")
        self.send("press a")
        if self.state.get("root") == "overworld":
            self.send("wait 12")
        self._settle_gym()
        if self.position() != (11, 1):
            raise ProtocolError("Viridian Gym blackbelt fight left " + str(self.position()))
        self._gym_presses("down", 1, (17, 2))
        self._gym_presses("right", 1, (18, 11))
        for direction, count, landing in (
            ("down", 1, (18, 12)),
            ("left", 4, (14, 12)),
            ("up", 3, (14, 9)),
            ("left", 1, (13, 9)),
            ("up", 2, (13, 7)),
            ("right", 2, (15, 7)),
            ("up", 1, (15, 6)),
            ("right", 1, (16, 6)),
            ("up", 1, (16, 5)),
            ("up", 1, (16, 4)),
            ("left", 4, (12, 4)),
            ("down", 1, (12, 5)),
            ("left", 2, (10, 5)),
            ("up", 3, (10, 2)),
            ("left", 3, (7, 2)),
            ("down", 2, (7, 4)),
            ("left", 3, (4, 4)),
            ("up", 3, (4, 1)),
            ("left", 1, (3, 1)),
        ):
            self._gym_presses(direction, count, landing)
        self.face("left")
        self.send("press a")
        if self.state.get("root") == "overworld":
            self.send("wait 12")
        self._settle_gym()

    def _leave_viridian_gym(self):
        """Retrace the corridor. The tile east of (10, 2) is a right-arrow."""
        if self.position() != (3, 1):
            raise ProtocolError("Earth Badge exit did not start at Giovanni: " + str(self.position()))
        for direction, count, landing in (
            ("right", 1, (4, 1)),
            ("down", 3, (4, 4)),
            ("right", 3, (7, 4)),
            ("up", 2, (7, 2)),
            ("right", 3, (10, 2)),
            ("down", 3, (10, 5)),
            ("right", 1, (11, 5)),
            ("right", 1, (12, 5)),
            ("up", 1, (12, 4)),
            ("right", 3, (15, 4)),
            # He stands on (15, 5), and (14, 6) is a wall. The east aisle is open.
            ("right", 1, (16, 4)),
            ("down", 3, (16, 7)),
            ("left", 3, (13, 7)),
            ("down", 4, (13, 11)),
            ("right", 1, (14, 11)),
            ("down", 5, (14, 16)),
            ("right", 2, (16, 16)),
        ):
            self._gym_presses(direction, count, landing)
        self.send("press down", "wait 15")
        self.drain()
        if self._on("ViridianGym"):
            self.send("press down", "wait 15")
            self.drain()
        if self._on("ViridianGym"):
            raise ProtocolError("Viridian Gym door did not return to the city: " + str(self.position()))

    def _toward_giovanni(self):
        from tools.harness.brock_journey import NaturalBlackout
        for _ in range(3):
            try:
                self._giovanni_once()
                return
            except NaturalBlackout:
                if self.flag("BADGE_EARTH"):
                    self.recover_blackout()
                    if self._league_loss_stops():
                        return
                    self._lead_starter()
                    continue
                if self.state.get("root") == "dialog":
                    self.dialog()
                self._arrange_lead("starter")
        raise ProtocolError("Giovanni walk blacked out")

    def _giovanni_once(self):
        """Surf back up Route 21. Viridian Gym opens once Earth is the missing badge."""
        self.summary["acceptance"] = "walking toward the Earth Badge"
        self._arrange_lead("starter")
        if self.flag("BADGE_EARTH"):
            if self._on("ViridianGym"):
                self._leave_viridian_gym()
            # A save already on the league road must not walk back to Viridian.
            if not any(token in (self._map_name() or "") for token in (
                    "ROUTE_22", "ROUTE_23", "VICTORY_ROAD", "INDIGO_PLATEAU",
                    "LORELEIS_ROOM", "BRUNOS_ROOM", "AGATHAS_ROOM", "LANCES_ROOM",
                    "CHAMPIONS_ROOM", "HALL_OF_FAME")):
                self.heal_here("ViridianPokecenter")
                self.save()
            self.summary.update(acceptance="Earth Badge earned", natural=True, forbidden_shortcuts=False)
            self._toward_league()
            return
        zone = self._map_name()
        if "CINNABAR" in zone or "MANSION" in zone:
            if self._on("CinnabarPokecenter"):
                self.navigate((3, 6))
                self.send("press down", "wait 15")
                self.drain()
                if self._on("CinnabarPokecenter"):
                    self.send("press down", "wait 15")
                    self.drain()
            elif not self._on("CinnabarIsland"):
                self.warp(self.zone("CinnabarIsland"))
            self.navigate((4, 4))
            self.face("left")
            index = next(i for i, mon in enumerate(self.party(), 1) if "surf" in mon["moves"])
            if self.model().collision[self.position()[1]][self.position()[0]] == 0:
                self.use_field(index, "surf")
            # Arrival surfing stops on Cinnabar. Leaving has to keep the button down.
            for _ in range(8):
                if not self._on("CinnabarIsland"):
                    break
                self.send("press up", "wait 10")
                self.drain()
        if self._on("Route21"):
            self._surf_route21_north()
        if "PALLET" in self._map_name() or self._map_name() == "pallet_town":
            x, y = self.position()
            if self.model().collision[y][x] != 0:
                self._surf_press("up", 2)
                self._surf_press("right", 3)
            self.navigate((10, 0))
            self._cross_edge("up")
        if self._on("Route1"):
            self.navigate((10, 0))
            self._cross_edge("up")
        if "VIRIDIAN" in self._map_name() and "FOREST" not in self._map_name():
            self.heal_here("ViridianPokecenter")
            self.save()
            self._pin_gym_payouts()
            self.warp(self.zone("ViridianCity"))
            self.warp(self.zone("ViridianGym"), "pokered:VIRIDIAN_CITY:warps:5")
            self._walk_viridian_gym()
        if not self.flag("BADGE_EARTH"):
            raise ProtocolError("Giovanni did not award the Earth Badge: " + self._map_name() + " " + str(self.position()))
        # The exit walk can miss a trainer who moved. Keep the badge first.
        self.save()
        if self._on("ViridianGym"):
            self._leave_viridian_gym()
        self.heal_here("ViridianPokecenter")
        self.save()
        self.summary.update(acceptance="Earth Badge earned", natural=True, forbidden_shortcuts=False)
        self._toward_league()

    def _toward_league(self):
        """The second rival stands on Route 22. The badge gates are the next road."""
        if self.flag("EVENT_BEAT_ROUTE22_RIVAL_2ND_BATTLE"):
            self.summary.update(acceptance="Route 22 rival defeated", natural=True, forbidden_shortcuts=False)
            self._climb_route23()
            return
        self.summary["acceptance"] = "walking toward the Route 22 rival"
        self._arrange_lead("starter")
        # The Cerulean pin lists the first rival's payout. The second fight
        # pays the story amount. A missing pin must not reject a real win.
        self.source_trainers["pokered:ROUTE_22:objects:2"] = {
            "id": "pokered:ROUTE_22:objects:2",
            "payout": 3445,
            "map_id": "pokered:ROUTE_22",
        }
        # Giovanni arms the second fight. The first rival was never battled,
        # so the trigger tiles no-op. BLUE walks east along y=5; stand above
        # him so that walk is clear, then talk.
        self.travel(self.zone("Route22"))
        self.navigate((25, 4))
        self.face("down")
        self.send("press a", "wait 8")
        self.drain()
        if not self.flag("EVENT_BEAT_ROUTE22_RIVAL_2ND_BATTLE"):
            raise ProtocolError("Route 22 rival did not start: " + self._map_name() + " " + str(self.position()))
        self.heal_here("ViridianPokecenter")
        self.save()
        self.summary.update(acceptance="Route 22 rival defeated", natural=True, forbidden_shortcuts=False)
        self._climb_route23()

    def _cell_kind(self, x, y):
        """Land is ordinary collision. Route 23 water uses the surf foot tile."""
        model = self.model()
        if not model.inside((x, y)):
            return None
        if model.collision[y][x] == 0:
            return "land"
        if model.feet[y][x] == 0x14:
            return "water"
        return None

    def _follow_route(self, goals):
        """Walk land and surf the gaps. Replan after every step, guard, and wild flee."""
        from collections import deque
        goals = set(goals)
        for _ in range(800):
            if not self._on("Route23"):
                return
            if self.position() in goals:
                return
            model = self.model()
            start = self.position()
            blocked = set(self.occupied()) | set(model.warps)
            blocked -= goals
            blocked.discard(start)
            queue, prev = deque([start]), {start: None}
            found = None
            while queue:
                x, y = queue.popleft()
                for dx, dy, name in ((0, -1, "up"), (0, 1, "down"), (1, 0, "right"), (-1, 0, "left")):
                    nxt = (x + dx, y + dy)
                    if nxt in prev or nxt in blocked or self._cell_kind(*nxt) is None:
                        continue
                    prev[nxt] = ((x, y), name)
                    queue.append(nxt)
                    if nxt in goals:
                        found = nxt
                        queue.clear()
                        break
            if found is None:
                raise ProtocolError("no Route 23 path from " + str(start))
            step_name, nxt = None, found
            while prev[nxt] is not None:
                parent, step_name = prev[nxt]
                landing, nxt = nxt, parent
            here, there = self._cell_kind(*start), self._cell_kind(*landing)
            before = self.position()
            if here == "land" and there == "water":
                self.face(step_name)
                if (self.observe("midgame-state").get("fieldTravel") or {}).get("mode") != "surfing":
                    index = next(i for i, mon in enumerate(self.party(), 1) if "surf" in mon["moves"])
                    self.use_field(index, "surf")
                self._surf_press(step_name, 1)
            elif here == "water":
                self._surf_press(step_name, 1)
            elif not self._step(step_name):
                raise ProtocolError("Route 23 step stayed at " + str(before))
        else:
            raise ProtocolError("Route 23 walk exceeded its step bound at " + str(self.position()))

    def _climb_route23(self):
        """Badge gates, then the south door of Victory Road. Save on the mat."""
        self.summary["acceptance"] = "walking Route 23 toward Victory Road"
        if not self._lorelei_bench_ready():
            # The cave clear is the grind. A starter lead one-shots the wilds
            # and the backups earn nothing.
            self._bench_share = True
            self._pin_victory_trainers()
        self._arrange_lead("starter")
        zone = self._map_name() or ""
        if "VICTORY_ROAD" in zone:
            # A paused Lapras leg resumes in the east pocket. Finish Ice
            # Beam before the boulder path walks back to Indigo.
            if (self._on("VictoryRoad2F") and self._reachable((28, 7))
                    and self._lapras_needs_ice_beam()):
                self._level_bench_for_lance()
                self._indigo_plateau()
                return
            # (24, 13) is the alcove behind the gate Route 23 closed. The
            # boulder script has no path from there, so leave and re-enter
            # from the south door instead of pushing from the wrong room.
            if not self._on("VictoryRoad1F") and not self._can_reach_boulder(
                    "pokered:VICTORY_ROAD_2F:objects:11"):
                self._indigo_plateau()
                return
            self._puzzle = True
            try:
                if self._on("VictoryRoad1F"):
                    self._victory_road_1f()
                self._victory_road_2f()
            finally:
                self._puzzle = False
            return
        if any(name in zone for name in (
            "INDIGO_PLATEAU", "LORELEIS_ROOM", "BRUNOS_ROOM", "AGATHAS_ROOM",
            "LANCES_ROOM", "CHAMPIONS_ROOM", "HALL_OF_FAME",
        )):
            self._indigo_plateau()
            return
        # (4, 31) is the 1F door. A resume already standing south of it keeps
        # the entrance save and steps through. North of that door, and the
        # east cave exit at (14, 32), continue toward Indigo.
        at_door = self._on("Route23") and self.position() in {(4, 32), (4, 31)}
        if self._on("Route23") and not at_door:
            x, y = self.position()
            if y < 31 or (y <= 32 and x >= 14):
                self._indigo_plateau()
                return
        if not at_door:
            if not self._on("Route23"):
                self.travel(self.zone("Route23"))
            self._follow_route({(4, 32)})
            if not self._on("Route23") or self.position() != (4, 32):
                raise ProtocolError("Victory Road entrance missed: " + self._map_name() + " " + str(self.position()))
            self.save()
            self.summary.update(acceptance="Victory Road entrance", natural=True, forbidden_shortcuts=False)
        if self._bench_share and self._party_needs_center():
            self.heal_here("ViridianPokecenter")
            if not self._on("Route23"):
                self.travel(self.zone("Route23"))
                self._follow_route({(4, 32)})
        self._puzzle = True
        try:
            self._enter_victory_road()
            self._victory_road_1f()
            self._victory_road_2f()
        finally:
            self._puzzle = False

    def _pin_victory_trainers(self):
        for trainer_id, payout, map_id in (
            ("pokered:VICTORY_ROAD_1F:objects:1", 1540, "pokered:VICTORY_ROAD_1F"),
            ("pokered:VICTORY_ROAD_1F:objects:2", 1470, "pokered:VICTORY_ROAD_1F"),
            ("pokered:VICTORY_ROAD_2F:objects:1", 1075, "pokered:VICTORY_ROAD_2F"),
            ("pokered:VICTORY_ROAD_2F:objects:2", 1435, "pokered:VICTORY_ROAD_2F"),
            ("pokered:VICTORY_ROAD_2F:objects:3", 1760, "pokered:VICTORY_ROAD_2F"),
            ("pokered:VICTORY_ROAD_2F:objects:4", 2000, "pokered:VICTORY_ROAD_2F"),
            ("pokered:VICTORY_ROAD_2F:objects:5", 1680, "pokered:VICTORY_ROAD_2F"),
            ("pokered:VICTORY_ROAD_3F:objects:1", 1505, "pokered:VICTORY_ROAD_3F"),
            ("pokered:VICTORY_ROAD_3F:objects:2", 1505, "pokered:VICTORY_ROAD_3F"),
            ("pokered:VICTORY_ROAD_3F:objects:3", 1505, "pokered:VICTORY_ROAD_3F"),
            ("pokered:VICTORY_ROAD_3F:objects:4", 1505, "pokered:VICTORY_ROAD_3F"),
        ):
            self.source_trainers[trainer_id] = {"id": trainer_id, "payout": payout, "map_id": map_id}

    def _play_groups(self, groups):
        for kind, name, count in groups:
            for _ in range(count):
                if kind == "push":
                    self._shove(name)
                    continue
                moved = False
                for _attempt in range(3):
                    if self._step(name):
                        moved = True
                        break
                    self.drain()
                if not moved:
                    raise ProtocolError("Victory Road step stayed at " + str(self.position()))

    def _enter_victory_road(self):
        if not self._on("Route23") or self.position() not in {(4, 32), (4, 31)}:
            return
        # The tile ahead is open, so the press walks onto the door. A second
        # press leaves through it if the first step only landed on the mat.
        for _ in range(2):
            if not self._on("Route23"):
                break
            self.send("press up", "wait 15")
            self.drain()
        if not self._on("VictoryRoad1F"):
            raise ProtocolError("Victory Road door did not open: " + self._map_name() + " " + str(self.position()))

    def _victory_road_1f(self):
        """Push the south boulder onto (17, 13), then stand beside the 2F stair."""
        if not self._on("VictoryRoad1F"):
            return
        self._pin_victory_trainers()
        if not self.flag("EVENT_VICTORY_ROAD_1_BOULDER_ON_SWITCH"):
            self._use_strength()
            if self.position() != (8, 16):
                self.navigate((8, 16))
            self._play_groups((
                ("walk", "left", 4), ("walk", "up", 2), ("walk", "right", 1),
                ("push", "down", 1), ("walk", "down", 1), ("walk", "left", 1), ("walk", "down", 1),
                ("push", "right", 1), ("walk", "right", 1),
                ("push", "right", 1), ("walk", "right", 1),
                ("push", "right", 1), ("walk", "right", 1),
                ("push", "right", 1), ("walk", "down", 1), ("walk", "right", 2),
                ("push", "up", 1), ("walk", "up", 1),
                ("push", "up", 1), ("walk", "up", 1), ("walk", "left", 1), ("walk", "up", 1),
                ("push", "right", 1), ("walk", "right", 1),
                ("push", "right", 1), ("walk", "right", 1),
                ("push", "right", 1), ("walk", "right", 1),
                ("push", "right", 1), ("walk", "right", 1),
                ("push", "right", 1), ("walk", "right", 1),
                ("push", "right", 1), ("walk", "right", 1),
                ("push", "right", 1), ("walk", "down", 1), ("walk", "right", 2),
                ("push", "up", 1), ("walk", "up", 1),
                ("push", "up", 1), ("walk", "left", 2), ("walk", "up", 2), ("walk", "right", 1),
                ("push", "right", 1), ("walk", "up", 1), ("walk", "right", 2),
                ("push", "down", 1),
            ))
            self._require_flag("EVENT_VICTORY_ROAD_1_BOULDER_ON_SWITCH")
            self.save()
            self.summary.update(acceptance="Victory Road 1F switch", natural=True, forbidden_shortcuts=False)
        if self.flag("EVENT_VICTORY_ROAD_1_BOULDER_ON_SWITCH") and self.position() not in {(2, 1), (1, 1)}:
            # The opened gate is not in the static collision model. This
            # walk starts on (17, 11), just above the switch. The cooltrainer
            # stands on (3, 3), so the last climb uses column 2.
            if self.position() != (17, 11):
                raise ProtocolError("Victory Road 1F stair walk starts at (17, 11), not " + str(self.position()))
            self._play_groups((
                ("walk", "down", 1), ("walk", "left", 1), ("walk", "down", 2),
                ("walk", "left", 7), ("walk", "up", 2), ("walk", "right", 2),
                ("walk", "up", 6), ("walk", "left", 4), ("walk", "down", 2),
                ("walk", "left", 4), ("walk", "up", 3), ("walk", "left", 1),
                ("walk", "up", 4),
            ))
            if self.position() != (2, 1):
                raise ProtocolError("Victory Road 1F stairs missed: " + str(self.position()))
            self.save()
        if self.position() in {(2, 1), (1, 1)} and self.flag("EVENT_VICTORY_ROAD_1_BOULDER_ON_SWITCH"):
            # The stair tile is open, so the press walks onto the warp.
            for _ in range(2):
                if not self._on("VictoryRoad1F"):
                    break
                self.send("press left", "wait 15")
                self.drain()
            if self._on("VictoryRoad2F"):
                self.save()
                self.summary.update(acceptance="Victory Road 2F", natural=True, forbidden_shortcuts=False)

    def _actor_at(self, source_id):
        from tools.harness.parcel_journey import sequence
        for npc in sequence(self.state.get("npcs") or [], "npcs"):
            if npc.get("source_event_id") == source_id or npc.get("id") == source_id:
                return npc["x"], npc["y"]
        return None

    def model(self):
        model = super().model()
        # Route 23 clears the switches. A gate opened earlier in this
        # process must close again or the next walk steps into the wall.
        if self.state.get("zone_id") == self.zone("VictoryRoad2F"):
            self._sync_victory_gates(model)
        return model

    def _sync_victory_gates(self, model):
        for event, cells in (
            ("EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1", ((6, 8, 5), (7, 8, 5), (6, 9, 5), (7, 9, 5))),
            ("EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH2", ((22, 14, 5), (23, 14, 5), (22, 15, 16), (23, 15, 16))),
        ):
            open_gate = self.flag(event)
            for x, y, foot in cells:
                model.collision[y][x] = 0 if open_gate else 1
                if open_gate:
                    model.feet[y][x] = foot

    def _open_victory_gates(self):
        """The harness map stays closed. The live switch paints these cells open."""
        if self._on("VictoryRoad2F"):
            self._sync_victory_gates(super().model())

    def _plan_boulder(self, player, boulder, goal):
        """One legal step that moves this boulder onto its switch."""
        from collections import deque
        model = self.model()
        blocked = set(self.occupied())
        blocked.discard(boulder)
        blocked.discard(player)
        warps = set(model.warps)
        start = (player, boulder)
        queue, prev = deque([start]), {start: None}
        found = None
        while queue:
            pos, rock = queue.popleft()
            if rock == goal:
                found = (pos, rock)
                break
            for name, dx, dy in (("up", 0, -1), ("down", 0, 1), ("right", 1, 0), ("left", -1, 0)):
                nxt = (pos[0] + dx, pos[1] + dy)
                if nxt == rock:
                    dest = (rock[0] + dx, rock[1] + dy)
                    if (dest in blocked or dest in warps or not model.inside(dest)
                            or model.collision[dest[1]][dest[0]]
                            or model.feet[dest[1]][dest[0]] == 0x15):
                        continue
                    player_foot = model.feet[pos[1]][pos[0]]
                    dest_foot = model.feet[dest[1]][dest[0]]
                    if any((player_foot == first and dest_foot == second)
                           or (player_foot == second and dest_foot == first)
                           for first, second in model.pairs):
                        continue
                    state = (pos, dest)
                    if state not in prev:
                        prev[state] = (pos, rock, "push", name)
                        queue.append(state)
                    continue
                if nxt in blocked or nxt in warps or not model.inside(nxt):
                    continue
                step = model.terrain_step(pos, name)
                if step is None or step.destination != nxt:
                    continue
                state = (nxt, rock)
                if state not in prev:
                    prev[state] = (pos, rock, "walk", name)
                    queue.append(state)
        if found is None:
            return None
        kind = name = None
        cursor = found
        while prev[cursor] is not None:
            parent_pos, parent_rock, kind, name = prev[cursor]
            cursor = (parent_pos, parent_rock)
        return kind, name

    def _push_boulder(self, direction):
        """Arm, then push. A press that walks the player is not a shove."""
        before = self.position()
        self.send("press " + direction, "wait 8")
        self.drain()
        if self.position() != before:
            return "walked"
        self.send("press " + direction, "wait 12")
        self.drain()
        if self.position() != before:
            return "walked"
        return "pushed"

    def _solve_boulder(self, source_id, goal, flag):
        self._use_strength()
        for _ in range(240):
            self._open_victory_gates()
            if self.flag(flag):
                return
            rock = self._actor_at(source_id)
            if rock is None:
                raise ProtocolError("Victory Road boulder is not on the map: " + source_id)
            if rock == goal:
                for _wait in range(6):
                    if self.flag(flag):
                        return
                    self.send("wait 8")
                    self.drain()
                raise ProtocolError("boulder is on the switch without " + flag)
            action = self._plan_boulder(self.position(), rock, goal)
            if action is None:
                raise ProtocolError(
                    "no boulder path for " + source_id + " at " + str(rock)
                    + " from " + str(self.position()))
            kind, direction = action
            if kind == "walk":
                if not self._step(direction):
                    self.drain()
                continue
            if self._push_boulder(direction) == "walked":
                continue
            moved = self._actor_at(source_id)
            if moved == rock:
                raise ProtocolError("boulder did not move: " + source_id + " at " + str(rock))
        raise ProtocolError("boulder puzzle exceeded its step bound at " + str(self.position()))

    def _walk_avoiding_warps(self, goal):
        from collections import deque
        for _ in range(200):
            if self.position() == goal:
                return
            model = self.model()
            start = self.position()
            blocked = set(self.occupied()) | set(model.warps) | set(model.signs)
            if self._on("VictoryRoad3F"):
                # Standing here falls to 2F unless the hole boulder is on its switch.
                blocked.add((23, 15))
            blocked.discard(start)
            queue, prev = deque([start]), {start: None}
            found = None
            while queue:
                point = queue.popleft()
                for name, dx, dy in (("up", 0, -1), ("down", 0, 1), ("right", 1, 0), ("left", -1, 0)):
                    nxt = (point[0] + dx, point[1] + dy)
                    if nxt in prev or nxt in blocked:
                        continue
                    step = model.terrain_step(point, name)
                    if step is None or step.destination != nxt:
                        continue
                    prev[nxt] = (point, name)
                    queue.append(nxt)
                    if nxt == goal:
                        found = nxt
                        queue.clear()
                        break
            if found is None:
                raise ProtocolError("no cave path from " + str(start) + " to " + str(goal))
            step_name, cursor = None, found
            while prev[cursor] is not None:
                parent, step_name = prev[cursor]
                cursor = parent
            if not self._step(step_name):
                self.drain()
        else:
            raise ProtocolError("cave walk exceeded its step bound at " + str(self.position()))

    def _step_onto_warp(self, direction):
        for _ in range(3):
            if not self._on("VictoryRoad2F") and not self._on("VictoryRoad3F"):
                return
            self.send("press " + direction, "wait 15")
            self.drain()

    def _victory_road_2f(self):
        """Push both 2F boulders, cross 3F, and leave by the east stair."""
        if self._on("VictoryRoad3F"):
            self._victory_road_3f_exit()
            return
        if not self._on("VictoryRoad2F"):
            return
        self._pin_victory_trainers()
        self._open_victory_gates()
        if not self.flag("EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1"):
            self._solve_boulder(
                "pokered:VICTORY_ROAD_2F:objects:11", (1, 16),
                "EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1")
            self.save()
            self.summary.update(acceptance="Victory Road 2F switch 1", natural=True, forbidden_shortcuts=False)
        if not self.flag("EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH2"):
            self._solve_boulder(
                "pokered:VICTORY_ROAD_2F:objects:13", (9, 16),
                "EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH2")
            self.save()
            self.summary.update(acceptance="Victory Road 2F switch 2", natural=True, forbidden_shortcuts=False)
        # Route 23 closes these gates on entry. Collect the payout first.
        if (self.flag("EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1")
                and self.flag("EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH2")
                and self._bench_share and not self._lorelei_bench_ready()):
            self._collect_victory_payout()
        if (self.position()[0] >= 27
                and self.flag("EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1")
                and self.flag("EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH2")):
            self._victory_road_3f_exit()
            return
        if self.position() != (24, 14):
            self._walk_avoiding_warps((24, 14))
        self._step_onto_warp("right")
        if not self._on("VictoryRoad3F"):
            raise ProtocolError("2F stair missed 3F: " + self._map_name() + " " + str(self.position()))
        self._victory_road_3f_exit()

    def _victory_road_3f_exit(self):
        """The east stair is the pocket behind the 3F drop, then Route 23."""
        self._pin_victory_trainers()
        if self._on("VictoryRoad3F"):
            if self.position() != (27, 8):
                self._walk_avoiding_warps((27, 8))
            self._step_onto_warp("left")
        if not self._on("VictoryRoad2F"):
            raise ProtocolError("3F stair missed the east 2F pocket: " + self._map_name() + " " + str(self.position()))
        if self.position() != (28, 7):
            self._walk_avoiding_warps((28, 7))
        self._record_screen("victory-road", 90)
        self._step_onto_warp("right")
        if not self._on("Route23"):
            raise ProtocolError("Victory Road east exit missed Route 23: " + self._map_name() + " " + str(self.position()))
        self.save()
        self.summary.update(acceptance="Victory Road cleared", natural=True, forbidden_shortcuts=False)
        if getattr(self, "_grinding", False):
            return
        self._indigo_plateau()

    def _pin_elite_trainers(self):
        for trainer_id, payout, map_id in (
            ("pokered:LORELEIS_ROOM:objects:1", 5544, "pokered:LORELEIS_ROOM"),
            ("pokered:BRUNOS_ROOM:objects:1", 5742, "pokered:BRUNOS_ROOM"),
            ("pokered:AGATHAS_ROOM:objects:1", 5940, "pokered:AGATHAS_ROOM"),
            ("pokered:LANCES_ROOM:objects:1", 6138, "pokered:LANCES_ROOM"),
            ("pokered:CHAMPIONS_ROOM:objects:1", 6435, "pokered:CHAMPIONS_ROOM"),
        ):
            self.source_trainers[trainer_id] = {"id": trainer_id, "payout": payout, "map_id": map_id}

    def _heal_indigo(self):
        nurse = self.zone("IndigoPlateauLobby") + ":objects:1"
        self.interact(source_id=nurse, stop_phase="heal-confirm")
        self.select("event.menu.selected", 1)
        self.send("press a")
        self.drain()
        for mon in self.party():
            if mon["hp"] != mon["maxHP"] or mon["status"] not in {None, "none"} or mon["pp"] != mon["maxPP"]:
                raise ProtocolError("Indigo restoration incomplete")

    def _talk_up(self, tile):
        self.navigate(tile)
        if lookup(self.state, "player.facing") != "up":
            self.face("up")
        self.send("press a", "wait 8")
        self.drain()

    def _talk_to_actor(self, source_id):
        """Stand on the cell south of the live sprite and press A.

        Lorelei, Bruno, and Agatha are padded one cell east of their
        source coordinates. The unpadded cell (5, 3) faces an empty tile.
        """
        pos = self._actor_at(source_id)
        if pos is None:
            raise ProtocolError("missing actor " + source_id)
        stand = (pos[0], pos[1] + 1)
        if self.position() != stand:
            self.navigate(stand)
        if lookup(self.state, "player.facing") != "up":
            self.face("up")
        self.send("press a", "wait 8")
        self.drain()

    def _north_stand(self):
        north = [warp for warp in self.model().warps if warp[1] == 0]
        if not north:
            raise ProtocolError("no north warp in " + str(self._map_name()))
        left = min(north)
        return (left[0], left[1] + 1)

    def _leave_north(self, room, stand):
        if self.position() != stand:
            self.navigate(stand)
        for _ in range(4):
            if not self._on(room):
                return
            before = self.position()
            self.send("press up", "wait 15")
            self.drain()
            if self._on(room) and self.position() == before:
                raise ProtocolError(room + " north door stayed closed at " + str(before))

    def _healing_items(self):
        return self.quantity("fullRestore") + self.quantity("maxPotion")

    def _starter_mon(self):
        return next((mon for mon in self.party() if mon["species"] == "charizard"), None)

    def _top_off_in_field(self):
        """Use a Max Potion or Full Restore before the next door.

        Any missing HP is enough. A Max Potion fills 35/191 before Agatha.
        The south door of a beaten room stays shut, so this is the heal.
        """
        starter = self._starter_mon()
        if starter is None or starter["hp"] <= 0:
            return
        index = next(i for i, mon in enumerate(self.party(), 1) if mon["species"] == "charizard")
        if starter["status"] not in {None, "none"} and self.quantity("fullHeal") > 0:
            self._field_item("fullHeal", index)
            starter = self._starter_mon()
        if starter is None or starter["hp"] <= 0 or starter["hp"] >= starter["maxHP"]:
            return
        item = "fullRestore" if self.quantity("fullRestore") else "maxPotion" if self.quantity("maxPotion") else None
        if item is None:
            return
        self._field_item(item, index)

    def _needs_league_heal(self):
        """Leave for the nurse only when the bag cannot cover the next room.

        A Revive or Full Restore is used in the battle. Walking back into
        the lobby clears the Elite Four, so a stocked bag stays on the north door.
        """
        if (self.quantity("revive") or self.quantity("maxRevive")
                or self.quantity("fullRestore") or self.quantity("maxPotion")):
            return False
        starter = self._starter_mon()
        if starter is None or starter["hp"] <= 0:
            return True
        if starter["status"] not in {None, "none"}:
            return True
        return starter["hp"] * 2 < starter["maxHP"]

    def _retreat_to_lobby(self):
        """Walk the south mats back to the Indigo nurse.

        Those mats are edge doors: landing on the tile does not warp, and
        the next step down does. The lobby reset clears the Elite Four
        flags. That is the nurse, and the payout is what buys the heals.
        """
        rooms = ("ChampionsRoom", "LancesRoom", "AgathasRoom", "BrunosRoom", "LoreleisRoom")
        for _ in range(8):
            if self._on("IndigoPlateauLobby") or self._on("IndigoPlateau"):
                return True
            if not any(self._on(name) for name in rooms):
                return True
            south = [warp for warp in self.model().warps if warp[1] > 0]
            if not south:
                return False
            door = max(south, key=lambda warp: (warp[1], warp[0]))
            if door[1] == self.model().height - 1:
                above = (door[0], door[1] - 1)
                if self.position() != door:
                    if self.position() != above:
                        self.navigate(above)
                    self.send("press down", "wait 15")
                    self.drain()
                for _ in range(3):
                    if not any(self._on(name) for name in rooms):
                        return True
                    if self.position() != door:
                        break
                    self.send("press down", "wait 20")
                    self.drain()
            else:
                above = (door[0], max(0, door[1] - 1))
                if self.position() not in {door, above}:
                    self.navigate(above)
                if self.position() != door:
                    self.send("press down", "wait 15")
                    self.drain()
        return self._on("IndigoPlateauLobby") or self._on("IndigoPlateau")

    def _advance_or_bank(self, room):
        """The north door is the only way on. The lobby mats clear the wins."""
        self._revive_fainted()
        self._top_off_in_field()
        self._leave_north(room, self._north_stand())
        return "forward"

    def _reopen_lorelei(self):
        """Step out to the lobby and back through the north door.

        A continue that already cleared STARTED still has her trainer bit.
        Entering her room sets STARTED, and the lobby reset clears the bit
        on the way out. The second talk is the battle.
        """
        door = max(self.model().warps, key=lambda warp: (warp[1], warp[0]))
        stand = (door[0], door[1] - 1)
        if self.position() != stand:
            self.navigate(stand)
        for _ in range(4):
            if self._on("IndigoPlateauLobby"):
                break
            self.send("press down", "wait 15")
            self.drain()
        if not self._on("IndigoPlateauLobby"):
            raise ProtocolError("Lorelei exit stayed in " + self._map_name() + " " + str(self.position()))
        self.navigate((8, 1))
        for _ in range(4):
            if self._on("LoreleisRoom"):
                break
            self.send("press up", "wait 15")
            self.drain()
        if not self._on("LoreleisRoom"):
            raise ProtocolError("Lorelei door stayed closed at " + str(self.position()))

    def _elite_four(self):
        """Real fights from the lobby north door through the Champion."""
        self._pin_elite_trainers()
        rooms = (
            ("LoreleisRoom", "pokered:LORELEIS_ROOM:objects:1", "EVENT_BEAT_LORELEIS_ROOM_TRAINER_0", "Lorelei"),
            ("BrunosRoom", "pokered:BRUNOS_ROOM:objects:1", "EVENT_BEAT_BRUNOS_ROOM_TRAINER_0", "Bruno"),
            ("AgathasRoom", "pokered:AGATHAS_ROOM:objects:1", "EVENT_BEAT_AGATHAS_ROOM_TRAINER_0", "Agatha"),
        )
        for room, actor, flag, label in rooms:
            if not self._on(room):
                continue
            self.drain()
            if not self.flag(flag):
                self._revive_fainted()
                self._top_off_in_field()
                self._lead_starter()
                if label == "Lorelei":
                    self._record_screen("lorelei", 60)
                self._talk_to_actor(actor)
            if not self.flag(flag) and room == "LoreleisRoom":
                # The room entry sets STARTED. The lobby clears the trainer
                # bit only on that later visit, so walk out and back in.
                self._reopen_lorelei()
                self._record_screen("lorelei", 60)
                self._talk_to_actor(actor)
            if not self.flag(flag):
                raise ProtocolError(label + " did not start: " + str(self.position()))
            if label == "Lorelei":
                self._record_screen("lorelei-win", 30)
            self.save()
            self.summary.update(acceptance=label + " defeated", natural=True, forbidden_shortcuts=False)
            if self._advance_or_bank(room) == "bank":
                return
        if self._on("LancesRoom"):
            self.drain()
            # The 1200-input cap is one battle. This save is the next leg.
            self.save()
            if not self.flag("EVENT_BEAT_LANCES_ROOM_TRAINER_0"):
                self._lead_for_lance(None)
                self._record_screen("lance", 60)
                self._talk_to_actor("pokered:LANCES_ROOM:objects:1")
            if not self.flag("EVENT_BEAT_LANCES_ROOM_TRAINER_0"):
                raise ProtocolError("Lance did not start: " + str(self.position()))
            self._record_screen("lance-win", 30)
            self.save()
            self.summary.update(acceptance="Lance defeated", natural=True, forbidden_shortcuts=False)
            if self._advance_or_bank("LancesRoom") == "bank":
                return
        if self._on("ChampionsRoom") or "HALL_OF_FAME" in (self._map_name() or ""):
            self._champion()

    def _surfing(self):
        travel = (self.observe("midgame-state").get("fieldTravel") or {})
        return travel.get("mode") == "surfing"

    def _cave_passable(self, model, point, goals):
        if not model.inside(point):
            return False
        if point in model.warps and point not in goals:
            return False
        x, y = point
        if model.collision[y][x] == 0:
            return True
        return model.feet[y][x] in self._SURF_FEET

    def _cave_cross(self, goals):
        """Walk land and Surf the cave water. The goal warp changes the floor."""
        from collections import deque
        goals = set(goals)
        origin = self._map_name()
        dirs = ((1, 0, "right"), (-1, 0, "left"), (0, 1, "down"), (0, -1, "up"))
        for _ in range(240):
            if self._map_name() != origin or self.position() in goals:
                return
            model = self.model()
            start = self.position()
            blocked = set(self.occupied())
            queue, prev = deque([start]), {start: None}
            found = None
            while queue:
                x, y = queue.popleft()
                for dx, dy, name in dirs:
                    nxt = (x + dx, y + dy)
                    if nxt in prev or nxt in blocked or not self._cave_passable(model, nxt, goals):
                        continue
                    prev[nxt] = ((x, y), name)
                    if nxt in goals:
                        found = nxt
                        queue.clear()
                        break
                    queue.append(nxt)
            if found is None:
                raise ProtocolError("no cave route on " + origin + " from " + str(start) + " to " + str(sorted(goals)))
            cur = found
            while prev[cur] is not None and prev[prev[cur][0]] is not None:
                cur = prev[cur][0]
            name = prev[cur][1]
            before = self.position()
            nxt = (before[0] + {"right": 1, "left": -1, "down": 0, "up": 0}[name],
                   before[1] + {"right": 0, "left": 0, "down": 1, "up": -1}[name])
            entering = model.feet[nxt[1]][nxt[0]] in self._SURF_FEET and model.collision[nxt[1]][nxt[0]] != 0
            if model.collision[before[1]][before[0]] == 0 and entering and not self._surfing():
                self.face(name)
                index = next(i for i, mon in enumerate(self.party(), 1) if "surf" in mon["moves"])
                self.use_field(index, "surf")
            elif entering or self._surfing():
                self._surf_press(name, 1)
            else:
                self._step(name)
            if self.position() == before and self._map_name() == origin:
                raise ProtocolError("cave step stayed at " + str(before))
        raise ProtocolError("cave crossing stayed on " + origin + " " + str(self.position()))

    def _play_postgame(self):
        """Heal, cross to Cerulean Cave, and face Mewtwo. The Mew giver has no script."""
        self._bind_kanto_route()
        self.config["name"] = "cerulean-natural"
        self.config["max_blackouts"] = 4
        self._flee_wilds = True
        self.summary["acceptance"] = "walking to Cerulean Cave"
        if self.state.get("zone_id") == self.zone("HallOfFame"):
            raise ProtocolError("post-Hall continue stayed in the Hall of Fame at "
                                + str(self.position()) + "; Pallet relocation did not run")
        if any(mon["hp"] <= 0 or mon["hp"] < mon["maxHP"] for mon in self.party()):
            self.heal_here("ViridianPokecenter")
            self.save()
        cave = self.zone("CeruleanCave1F")
        scientist = next(event for event in self.models[cave].events["objects"]
                         if event["id"] == "postgame:CERULEAN_CAVE_1F:mew-gift")
        if not self._on("CeruleanCave1F") and not self._on("CeruleanCaveB1F"):
            self.travel(cave, set(self.models[cave].approaches((scientist["x"], scientist["y"]))))
        if self._on("CeruleanCave1F") and not self.summary.get("mew_gift"):
            self._record_screen("cerulean-cave", 20)
            self._record_screen("mew-gift", 25)
            self.interact(source_id=scientist["id"])
            gifted = any(mon["species"] == "mew" for mon in self.party())
            self.summary["mew_gift"] = "received" if gifted else "giver has no script"
        if not self.flag("EVENT_BEAT_MEWTWO"):
            if not self._on("CeruleanCaveB1F"):
                ladder = next(event for event in self.models[cave].events["warps"]
                              if event["id"] == "pokered:CERULEAN_CAVE_1F:warps:9")
                self._cave_cross({(ladder["x"], ladder["y"])})
            if not self._on("CeruleanCaveB1F"):
                raise ProtocolError("cave ladder stayed on " + self._map_name() + " " + str(self.position()))
            basement = self.zone("CeruleanCaveB1F")
            mewtwo = next(event for event in self.models[basement].events["objects"]
                          if event["id"] == "pokered:CERULEAN_CAVE_B1F:objects:1")
            self._cave_cross(set(self.models[basement].approaches((mewtwo["x"], mewtwo["y"]))))
            self._record_screen("mewtwo", 70)
            self.interact(source_id=mewtwo["id"])
        if not self.flag("EVENT_BEAT_MEWTWO"):
            raise ProtocolError("Mewtwo did not finish: " + str(self.position()))
        self._record_screen("mewtwo-result", 20)
        self.save()
        self.summary.update(acceptance="Mewtwo faced", natural=True, forbidden_shortcuts=False)

    def drain(self, stop_phase=None):
        # The Hall of Fame script saves, rolls the credits, and returns to the
        # title. Opening the pause menu there asserts. Leave the win text up
        # so the result clip starts on it.
        if self._hold_champion_ending():
            return
        return super().drain(stop_phase)

    def _hold_champion_ending(self):
        root = self.state.get("root")
        if root in {"battle", "party", "learning", "evolution"}:
            return False
        zone = self._map_name() or ""
        if root == "title":
            return getattr(self, "_ceremony", False)
        if "HALL_OF_FAME" in zone:
            return True
        if "CHAMPIONS_ROOM" not in zone:
            return False
        outcome = self.state.get("last_battle_outcome") or {}
        trainer = str(outcome.get("trainer_id") or "")
        return outcome.get("won") is True and "CHAMPIONS_ROOM" in trainer

    def _champion(self):
        self._pin_elite_trainers()
        if self._on("ChampionsRoom") and not self.flag("EVENT_BEAT_CHAMPION_RIVAL"):
            self.drain()
            if not self.flag("EVENT_BEAT_CHAMPION_RIVAL") and not self._hold_champion_ending():
                self._talk_to_actor("pokered:CHAMPIONS_ROOM:objects:1")
            if not self.flag("EVENT_BEAT_CHAMPION_RIVAL") and not self._hold_champion_ending():
                raise ProtocolError("Champion did not start: " + str(self.position()))
        self._record_screen("champion-win", 45)
        self.summary.update(acceptance="Champion defeated", natural=True, forbidden_shortcuts=False)
        self._finish_ceremony()

    def _slot_sequence(self):
        best = 0
        data = Path(self.client.data)
        for name in ("adventure.a.json", "adventure.b.json"):
            path = data / name
            if not path.is_file():
                continue
            try:
                best = max(best, int(json.loads(path.read_text(encoding="utf-8")).get("sequence") or 0))
            except (OSError, ValueError):
                continue
        return best

    def _finish_ceremony(self):
        """Press the Champion text, then let the Hall of Fame and credits run.

        HallOfFamePC writes the post-Hall save and then the title. That save
        is the one to archive. The pause menu is not on the title.
        """
        recorded = False
        self._ceremony = True
        before = self._slot_sequence()
        for _ in range(6000):
            root = self.state.get("root")
            phase = lookup(self.state, "event.phase") if root == "event" else None
            if phase == "credits" and not recorded:
                self._record_screen("credits", 90)
                recorded = True
            if root == "title":
                break
            if phase == "failed":
                raise ProtocolError("hall event failed: " + str(lookup(self.state, "event.waiting")))
            if root == "dialog":
                self.dialog()
            elif phase == "dialog":
                self.send("press a", "wait 6")
            else:
                self.send("wait 12")
        else:
            raise ProtocolError(
                "credits did not return to the title: "
                + str(self.state.get("root")) + " " + str(self._map_name()))
        if not recorded:
            raise ProtocolError("credits never started")
        for _ in range(40):
            if self._slot_sequence() > before:
                self._archive_earned_save()
                self.summary.update(acceptance="Hall of Fame saved", natural=True, forbidden_shortcuts=False)
                return
            self.send("wait 4")
        raise ProtocolError("hall save did not land after the credits")

    _LORELEI_BENCH = {"weepinbell", "victreebel", "pidgeotto", "pidgeot"}
    _BENCH_LEVEL = 47
    _INDIGO_CLERK = "pokered:INDIGO_PLATEAU_LOBBY:objects:4"
    _INDIGO_PRICES = {
        "fullHeal": 600,
        "revive": 1500,
        "fullRestore": 3000,
        "maxPotion": 2500,
    }

    def _bench_levels(self):
        return [
            (mon["species"], mon["level"], mon["hp"])
            for mon in self.party() if mon["species"] in self._LORELEI_BENCH
        ]

    def _lorelei_bench_ready(self):
        rows = [mon for mon in self.party() if mon["species"] in self._LORELEI_BENCH]
        return len(rows) >= 2 and all(mon["level"] >= self._BENCH_LEVEL for mon in rows)

    def _agatha_levels(self):
        return {
            mon["species"]: mon["level"]
            for mon in self.party() if mon["species"] in {"lapras", "weepinbell"}
        }

    def _agatha_bench_ready(self):
        """Lapras and Weepinbell both sit in the mid 40s before the next Elite Four."""
        levels = self._agatha_levels()
        return levels.get("lapras", 0) >= 45 and levels.get("weepinbell", 0) >= 45

    def _trainee_index(self):
        short, alive = [], []
        if getattr(self, "_agatha_training", False):
            best = None
            for index, mon in enumerate(self.party(), 1):
                if mon["species"] not in {"lapras", "weepinbell"} or mon["hp"] <= 0:
                    continue
                if mon["level"] >= 45:
                    continue
                if best is None or mon["level"] < best[0]:
                    best = (mon["level"], index)
            return best[1] if best else None
        if getattr(self, "_lance_training", False):
            best = None
            for index, mon in enumerate(self.party(), 1):
                if mon["species"] not in {"lapras", "pidgeotto", "pidgeot", "weepinbell"} or mon["hp"] <= 0:
                    continue
                if best is None or mon["level"] < best[0]:
                    best = (mon["level"], index)
            return best[1] if best else None
        for index, mon in enumerate(self.party(), 1):
            if mon["species"] not in self._LORELEI_BENCH or mon["hp"] <= 0:
                continue
            alive.append((mon["level"], index))
            if mon["level"] < self._BENCH_LEVEL:
                short.append((mon["level"], index))
        pool = short or alive
        if not pool:
            return None
        return min(pool)[1]

    def _lead_trainee(self):
        index = self._trainee_index()
        if index is None:
            return
        active = lookup(self.state, "session.party.active") or 1
        if index != active:
            self.field_swap(index, active)

    def _move_pp(self, mon):
        pp = mon.get("pp")
        if not isinstance(pp, dict):
            return 99
        return sum(value for value in pp.values() if type(value) is int)

    def _share_bench(self, battle, options):
        """The backup has to be conscious at the KO or it earns nothing."""
        trainee = self._trainee_index()
        if trainee is None:
            return False
        active = lookup(self.state, "session.party.active")
        enemy = battle.get("enemy") or {}
        mon = self.party()[trainee - 1]
        # Anything above the backup's level is Charizard's fight. The backup
        # still has to start the battle, or a one-shot gives them no experience.
        dangerous = (enemy.get("level") or 100) > mon["level"] or mon["hp"] * 2 < mon["maxHP"]
        starter = self.starter_index()
        if active == trainee and dangerous and starter != trainee and self.party()[starter - 1]["hp"] > 0:
            return bool(self.battle_switch(starter, options, "bench-cover"))
        enemy_hp, enemy_max = enemy.get("hp") or 0, enemy.get("maxHP") or 0
        if (active != trainee and not dangerous and mon["hp"] * 2 >= mon["maxHP"]
                and enemy_max and enemy_hp * 3 <= enemy_max):
            return bool(self.battle_switch(trainee, options, "bench-finish"))
        player = battle.get("player") or {}
        if (self._spare_healing() == "fullRestore" and player.get("hp", 1) < player.get("maxHP", 1)
                and self._move_pp(self.party()[active - 1]) < 6):
            self.battle_medicine("fullRestore", options)
            return True
        return False

    def _field_item(self, item, index):
        quantity = self.quantity(item)
        if quantity <= 0:
            return False
        self.send("press b")
        self.pause_option("ITEM")
        self.send("press a")
        slots = sequence(self.inventory()["slots"], "inventory.slots")
        slot = next(i for i, row in enumerate(slots, 1) if row["id"] == item)
        self.select("bag.selected", slot)
        self.send("press a")
        self.require(**{"bag.phase": "actions"})
        self.select("bag.menu.selected", 1)
        self.send("press a")
        self.require(root="party")
        self.select("party_ui.selected", index)
        self.send("press a")
        self.require(root="bag", **{"bag.phase": "message"})
        if self.quantity(item) != quantity - 1:
            raise ProtocolError("field item did not consume one " + item)
        self.send("press a", "press b")
        self.drain()
        self.require(root="overworld")
        return True

    def _revive_fainted(self):
        if self.state.get("root") != "overworld":
            return
        for index, mon in enumerate(self.party(), 1):
            if mon["hp"] > 0:
                continue
            item = "revive" if self.quantity("revive") else "maxRevive" if self.quantity("maxRevive") else None
            if item is None:
                return
            self._field_item(item, index)

    def _stock_league_items(self):
        """Indigo's clerk sells Revives, Full Restores and Max Potions."""
        if not self._on("IndigoPlateauLobby"):
            return
        previous = self.require_shop_stock

        def allow(clerk, item):
            if clerk == self._INDIGO_CLERK and item in self._INDIGO_PRICES:
                return None
            return previous(clerk, item)

        self.require_shop_stock = allow
        try:
            # The clerk sells Revive, Max Potion, Full Restore, and Full Heal.
            # Hyper Potion is not on the shelf. Status cures come last.
            for item, cap in (
                ("revive", 3),
                ("fullRestore", 2),
                ("maxPotion", 2),
                ("fullHeal", 4),
            ):
                price = self._INDIGO_PRICES[item]
                have = self.quantity(item)
                slots = self.inventory().get("slots") or []
                # A new stack needs a free pocket. The clerk refuses at 20.
                if have <= 0 and len(slots) >= 20:
                    continue
                count = min(cap - have, self.inventory()["money"] // price)
                if count > 0:
                    self.buy_item(self._INDIGO_CLERK, item, count, price)
        finally:
            self.require_shop_stock = previous
        self.summary["league_bag"] = {
            "money": self.inventory()["money"],
            "fullHeal": self.quantity("fullHeal"),
            "revive": self.quantity("revive"),
            "maxPotion": self.quantity("maxPotion"),
        }

    def _want_league_shop(self):
        money = self.inventory()["money"]
        if self.quantity("revive") < 2 and money >= self._INDIGO_PRICES["revive"] * min(2, max(1, money // self._INDIGO_PRICES["revive"])):
            return self.quantity("revive") < 2
        if self.quantity("fullRestore") < 2 and money >= self._INDIGO_PRICES["fullRestore"]:
            return True
        return False

    def _exit_lobby_south(self):
        if not self._on("IndigoPlateauLobby"):
            return
        if self.position()[1] < 11:
            self.navigate((8, 11))
        for _ in range(4):
            if not self._on("IndigoPlateauLobby"):
                return
            self.send("press down", "wait 15")
            self.drain()
        raise ProtocolError("lobby south door stayed at " + str(self.position()))

    def _reach_lobby(self):
        if self._on("VictoryRoad1F") or self._on("VictoryRoad2F") or self._on("VictoryRoad3F"):
            self._leave_east_cave()
        if self._on("Route23"):
            self._follow_route({(9, 0), (10, 0)})
            if self.position() not in {(9, 0), (10, 0)}:
                raise ProtocolError("Indigo crossing missed: " + str(self.position()))
            self._cross_edge("up")
        if self._on("IndigoPlateau"):
            door = (9, 6) if self.position()[0] <= 9 else (10, 6)
            if self.position() != door:
                self.navigate(door)
            for _ in range(3):
                if not self._on("IndigoPlateau"):
                    break
                self.send("press up", "wait 15")
                self.drain()
        if not self._on("IndigoPlateauLobby"):
            raise ProtocolError("lobby shop walk stopped at " + self._map_name() + " " + str(self.position()))

    def _enter_east_cave(self):
        if self._on("VictoryRoad2F"):
            return
        if self._on("IndigoPlateauLobby"):
            self._exit_lobby_south()
        if self._on("IndigoPlateau"):
            self._cross_edge("down")
        if not self._on("Route23"):
            raise ProtocolError("east cave walk left " + self._map_name())
        if self.position() not in {(14, 31), (14, 32)}:
            self._follow_route({(14, 32)})
        for _ in range(3):
            if self._on("VictoryRoad2F"):
                if self.position()[0] >= 29:
                    self._step("left")
                return
            self.send("press up", "wait 15")
            self.drain()
        raise ProtocolError("east cave door stayed at " + str(self.position()))

    def _leave_east_cave(self):
        if self._on("Route23") or self._on("IndigoPlateau") or self._on("IndigoPlateauLobby"):
            return
        if self._on("VictoryRoad2F") and not self._reachable((28, 7)):
            self._walk_avoiding_warps((25, 13))
            self._step_onto_warp("down")
        if self._on("VictoryRoad3F"):
            if self.position() == (27, 15):
                self._step("up")
            self._walk_avoiding_warps((26, 9))
            self._step_onto_warp("up")
            if self.position() == (27, 7):
                self._step("right")
        if not self._on("VictoryRoad2F"):
            return
        if self.position() != (28, 7):
            self._walk_avoiding_warps((28, 7))
        self._step_onto_warp("right")
        if not self._on("Route23"):
            raise ProtocolError("east cave exit missed Route 23: " + self._map_name() + " " + str(self.position()))

    def _fight_if_here(self, source_id):
        zone = source_id.split(":objects:")[0]
        if self.state.get("zone_id") != zone or self.defeated(source_id):
            return False
        pos = self._actor_at(source_id)
        if pos is None:
            return False
        approaches = self.model().approaches(pos)
        if self.position() not in approaches:
            try:
                self.model().path(self.position(), set(approaches), self.occupied())
            except ProtocolError:
                return False
        if getattr(self, "_flee_wilds", False):
            self._lead_starter()
        else:
            self._lead_trainee()
        self._record_screen("victory-road", 60)
        self.interact(source_id=source_id)
        self._revive_fainted()
        return True

    def _pace_tiles(self, a, b, battles):
        if getattr(self, "_flee_wilds", False):
            return
        if self.position() not in {a, b}:
            self._walk_avoiding_warps(a)
        start = len(self.summary.get("training") or [])
        steps = 0
        while len(self.summary.get("training") or []) < start + battles and steps < 220:
            if self._lorelei_bench_ready() or not self._on("VictoryRoad2F") or self._party_needs_center():
                return
            goal = b if self.position() == a else a
            dx, dy = goal[0] - self.position()[0], goal[1] - self.position()[1]
            name = "down" if dy > 0 else "up" if dy < 0 else "right" if dx > 0 else "left"
            self._lead_trainee()
            if not self._step(name) and self.state.get("root") == "overworld":
                return
            self._revive_fainted()
            steps += 1

    def _try_south_grass(self):
        if getattr(self, "_flee_wilds", False) or not self._on("Route23"):
            return
        self._follow_route({(14, 37)})
        for _ in range(16):
            if not self._on("Route23") or self.position()[1] >= 44:
                break
            before = self.position()
            self._step("down")
            if self.position() == before:
                return
        if not self._on("Route23") or self.position()[1] < 44:
            return
        self._follow_route({(10, 44), (11, 44)})
        a, b = (10, 44), (11, 44)
        start = len(self.summary.get("training") or [])
        steps = 0
        while len(self.summary.get("training") or []) < start + 6 and steps < 180:
            if not self._on("Route23") or self._lorelei_bench_ready():
                return
            goal = b if self.position() == a else a
            if self.position() not in {a, b}:
                self._follow_route({a})
            dx = goal[0] - self.position()[0]
            self._lead_trainee()
            self._step("right" if dx > 0 else "left")
            self._revive_fainted()
            steps += 1

    def _party_needs_center(self):
        """A fainted or half-health backup stops earning, and a low Charizard cannot cover."""
        trainee = self._trainee_index()
        for index, mon in enumerate(self.party(), 1):
            if mon["hp"] <= 0:
                return True
            if trainee and index == trainee and mon["hp"] * 2 < mon["maxHP"]:
                return True
            if mon["species"] == "charizard" and mon["hp"] * 3 < mon["maxHP"]:
                return True
        return False

    def _reachable(self, goal):
        if self.position() == goal:
            return True
        try:
            self.model().path(self.position(), {goal}, self.occupied())
        except ProtocolError:
            return False
        return True

    def _can_reach_boulder(self, source_id):
        """True when a neighboring tile of the boulder is on this floor."""
        if not self._on("VictoryRoad2F"):
            return False
        rock = self._actor_at(source_id)
        if rock is None:
            return False
        approaches = {(rock[0] + dx, rock[1] + dy) for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0))}
        try:
            self.model().path(self.position(), approaches, self.occupied())
        except ProtocolError:
            return False
        return True

    def _collect_victory_payout(self):
        """Beat the trainers the open gates can reach. One payout buys a Revive."""
        self._pin_victory_trainers()
        self._open_victory_gates()
        for trainer in (
            "pokered:VICTORY_ROAD_2F:objects:2",
            "pokered:VICTORY_ROAD_2F:objects:3",
            "pokered:VICTORY_ROAD_2F:objects:5",
            "pokered:VICTORY_ROAD_2F:objects:1",
        ):
            # A paralyzed or low Charizard cannot buy the Revive. Stop and heal.
            if self._needs_field_heal():
                return
            if self.inventory()["money"] >= 1500 and self._lorelei_bench_ready():
                return
            if self._fight_if_here(trainer):
                self.save()

    def _join_victory_floor(self):
        """The Route 23 door opens into a walled pocket. Trainers are past it.

        Left from (28, 7) climbs to 3F (26, 8). That pocket does not connect
        to (23, 6). Its south stair (27, 15) returns to 2F (25, 14), which
        does reach the trainers.
        """
        on_pocket = self._on("VictoryRoad2F") and self._reachable((28, 7))
        if on_pocket:
            if self.position() != (28, 7):
                self._walk_avoiding_warps((28, 7))
            self.send("press left", "wait 15")
            self.drain()
        if self._on("VictoryRoad2F") and not self._reachable((28, 7)):
            return
        if not self._on("VictoryRoad3F"):
            raise ProtocolError("east stair stayed on " + self._map_name() + " " + str(self.position()))
        if self.position() == (27, 15):
            self._step("up")
        self._walk_avoiding_warps((27, 14))
        self.send("press down", "wait 15")
        self.drain()
        if not self._on("VictoryRoad2F") or self.position() != (25, 14):
            raise ProtocolError("3F south stair missed the trainer floor: " + self._map_name() + " " + str(self.position()))
        self._step("up")

    def _grind_east_cave(self):
        self._enter_east_cave()
        self._join_victory_floor()
        for trainer in (
            "pokered:VICTORY_ROAD_2F:objects:5",
            "pokered:VICTORY_ROAD_2F:objects:3",
            "pokered:VICTORY_ROAD_2F:objects:2",
            "pokered:VICTORY_ROAD_2F:objects:4",
        ):
            if self._lorelei_bench_ready():
                break
            self._fight_if_here(trainer)
        if self._on("VictoryRoad2F") and not self._lorelei_bench_ready():
            # (28, 7) is the east pocket. The trainer floor cannot walk there,
            # and (25, 14) between the open tiles is the stair back to 3F.
            if self._reachable((28, 7)):
                self._pace_tiles((28, 7), (28, 8), 6)
            else:
                self._pace_tiles((24, 12), (24, 13), 6)
        self._leave_east_cave()
        if not self._lorelei_bench_ready():
            self._try_south_grass()

    def _needs_field_heal(self):
        """Paralysis and a low Charizard both stop a trainer payout."""
        for mon in self.party():
            if mon["hp"] <= 0 or mon["status"] not in {None, "none"}:
                return True
            if mon["species"] == "charizard" and mon["hp"] * 3 < mon["maxHP"] * 2:
                return True
        return self._party_needs_center()

    def _can_attempt_lorelei(self):
        """Lorelei starts once the bench is in the mid 40s and Charizard is healthy."""
        if not self._agatha_bench_ready():
            return False
        starter = next((mon for mon in self.party() if mon["species"] == "charizard"), None)
        if starter is None or starter["hp"] <= 0 or starter["hp"] * 3 < starter["maxHP"] * 2:
            return False
        if starter["status"] not in {None, "none"}:
            return False
        if self._lorelei_bench_ready():
            return True
        # Ice Beam is the Lance gate. Full Heals cover the return trip.
        if not self._lapras_needs_ice_beam():
            return True
        return (self.quantity("revive") >= 1 or self.quantity("maxRevive") >= 1
                or self.quantity("fullRestore") >= 1)

    def _heal_reachable_center(self):
        """The east cave door only joins the Indigo side of Route 23. Viridian is behind that wall."""
        if not self._on("IndigoPlateauLobby"):
            self._reach_lobby()
        composition = (REPO / "Source/game/healingComposition.lua").read_text(encoding="utf-8")
        if "pokered:INDIGO_PLATEAU_LOBBY" in composition:
            self._heal_indigo()

    def _fund_revive(self):
        """The east door cannot reach a trainer. One owned Rare Candy sells for a Revive."""
        if (self.quantity("revive") >= 1 or self.quantity("maxRevive") >= 1
                or self.inventory()["money"] >= 1500 or self.quantity("rareCandy") < 1):
            return
        if not self._on("IndigoPlateauLobby"):
            self._reach_lobby()
        before, qty = self.inventory()["money"], self.quantity("rareCandy")
        self.interact(source_id=self._INDIGO_CLERK)
        self.require(root="shop", **{"shop.phase": "mode"})
        self.select("shop.menu.selected", 2)
        self.send("press a")
        visited = set()
        for _ in range(24):
            current = lookup(self.state, "shop.item")
            if current == "rareCandy":
                break
            if current in visited:
                raise ProtocolError("Rare Candy absent from the Indigo sell list")
            visited.add(current)
            self.send("press down")
        else:
            raise ProtocolError("Indigo sell browse exceeded")
        self.send("press a")
        self.require(**{"shop.phase": "quantity", "shop.quantity": 1})
        self.send("press a")
        self.require(**{"shop.phase": "confirm"})
        self.select("shop.menu.selected", 1)
        self.send("press a")
        self.require(**{"shop.phase": "result", "shop.result.ok": True})
        total = lookup(self.state, "shop.result.total")
        if type(total) is not int or total < 1500 or self.inventory()["money"] != before + total or self.quantity("rareCandy") != qty - 1:
            raise ProtocolError("Rare Candy sale did not fund a Revive")
        self.send("press a", "press b", "press b")
        self.drain()
        self._stock_league_items()
        self.save()

    def _reopen_and_farm_trainers(self):
        """Route 23 closed the gates. Re-solve both floors, then take the trainer payout."""
        self._lead_starter()
        if self._on("VictoryRoad2F") or self._on("VictoryRoad3F"):
            self._leave_east_cave()
        if self._on("IndigoPlateauLobby"):
            self._exit_lobby_south()
        if self._on("IndigoPlateau"):
            self._cross_edge("down")
        if not self._on("VictoryRoad1F"):
            if not self._on("Route23"):
                self.travel(self.zone("Route23"))
            if self.position() != (4, 32):
                self._follow_route({(4, 32)})
            if not self._on("Route23") or self.position() != (4, 32):
                raise ProtocolError(
                    "Victory Road south door missed: " + self._map_name() + " " + str(self.position()))
        self._puzzle = True
        try:
            if not self._on("VictoryRoad1F"):
                self._enter_victory_road()
            self._victory_road_1f()
            self._victory_road_2f()
        finally:
            self._puzzle = False

    def _raise_lorelei_bench(self):
        """Level Lapras and Weepinbell, then heal and stock before Lorelei."""
        self._grind_agatha_bench()
        if self._can_attempt_lorelei():
            self._bench_share = False
            self.training_mode = None
            self._flee_wilds = False
            return
        from tools.harness.brock_journey import NaturalBlackout
        self._grinding = True
        self._bench_share = True
        self._flee_wilds = True
        self._pin_victory_trainers()
        self.summary["acceptance"] = "earning a Revive for Lorelei"
        try:
            while not self._can_attempt_lorelei():
                battles = len(self.summary["battles"])
                trained = len(self.summary.get("training") or [])
                money = self.inventory()["money"]
                try:
                    self._lead_starter()
                    if money >= 1500 and (self._want_league_shop() or self._needs_field_heal()):
                        if not self._on("IndigoPlateauLobby"):
                            self._reach_lobby()
                        if self._want_league_shop():
                            self._stock_league_items()
                        if any(mon["hp"] < mon["maxHP"] or mon["status"] not in {None, "none"}
                               for mon in self.party()):
                            self._heal_indigo()
                        self._lead_starter()
                    elif self._needs_field_heal():
                        self._heal_reachable_center()
                        self._lead_starter()
                    if self._can_attempt_lorelei():
                        break
                    if (self.quantity("revive") < 1 and self.quantity("maxRevive") < 1
                            and self.quantity("fullRestore") < 1):
                        # Route 23 walls the south door off from the east cave. Sell one
                        # Rare Candy at the lobby clerk, then buy the Revive.
                        self._fund_revive()
                    elif (self.inventory()["money"] < 1500
                            and not self.flag("EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1")):
                        self._reopen_and_farm_trainers()
                    else:
                        self._grind_east_cave()
                    self._revive_fainted()
                    self.save()
                except NaturalBlackout:
                    self.recover_blackout()
                    self._lead_starter()
                    if not any(self._on(name) for name in (
                        "Route23", "IndigoPlateau", "IndigoPlateauLobby",
                        "VictoryRoad1F", "VictoryRoad2F", "VictoryRoad3F",
                    )):
                        self._climb_route23()
                self.summary["bench"] = self._bench_levels()
                if (len(self.summary["battles"]) == battles
                        and len(self.summary.get("training") or []) == trained
                        and not self._can_attempt_lorelei()
                        and self.inventory()["money"] <= money):
                    raise ProtocolError(
                        "league grind made no progress at "
                        + self._map_name() + " " + str(self.position())
                        + " ¥" + str(self.inventory()["money"])
                        + " bench " + str(self._bench_levels()))
        finally:
            self._grinding = False
            self._bench_share = False
            self.training_mode = None
            self._flee_wilds = False
        self._lead_starter()
        self.summary["bench"] = self._bench_levels()

    def _indigo_plateau(self):
        """North from the cave exit, heal, then the Elite Four."""
        # A beaten room does not open the south door. pokered's DefaultScript
        # still says "Don't run away!" there. Training is from the lobby,
        # before that door, or after a blackout.
        rooms = ("LoreleisRoom", "BrunosRoom", "AgathasRoom", "LancesRoom", "ChampionsRoom")
        if not any(self._on(name) for name in rooms):
            self._raise_lorelei_bench()
        self.summary["acceptance"] = "walking to Indigo Plateau"
        self._pin_elite_trainers()
        if self._on("Route23"):
            self._follow_route({(9, 0), (10, 0)})
            if self.position() not in {(9, 0), (10, 0)}:
                raise ProtocolError("Indigo crossing missed: " + str(self.position()))
            self._cross_edge("up")
        if self._on("IndigoPlateau"):
            door = (9, 6) if self.position()[0] <= 9 else (10, 6)
            if self.position() != door:
                self.navigate(door)
            for _ in range(3):
                if not self._on("IndigoPlateau"):
                    break
                self.send("press up", "wait 15")
                self.drain()
        for _ in range(4):
            if self._on("IndigoPlateauLobby"):
                # The lobby machine is placed beside the nurse. Heal when that
                # layout is in Source; skip it on a tree that still asserts a Center.
                composition = (REPO / "Source/game/healingComposition.lua").read_text(encoding="utf-8")
                if "pokered:INDIGO_PLATEAU_LOBBY" in composition:
                    self._heal_indigo()
                self._stock_league_items()
                self._league_push = self._healing_items() >= 2
                self._lead_starter()
                self.save()
                self.summary.update(acceptance="Indigo Plateau", natural=True, forbidden_shortcuts=False)
                self.navigate((8, 1))
                for _ in range(3):
                    if not self._on("IndigoPlateauLobby"):
                        break
                    self.send("press up", "wait 15")
                    self.drain()
            self._elite_four()
            if not self._on("IndigoPlateauLobby"):
                break
        if self._on("Route23") or self._on("IndigoPlateau") or self._on("IndigoPlateauLobby"):
            raise ProtocolError("Indigo approach stopped at " + self._map_name() + " " + str(self.position()))

    def _toward_koga(self):
        """Hideout Scope, Tower flute, then the east road to Koga."""
        if self.flag("BADGE_SOUL") and self.quantity("tm06") >= 1:
            self.summary.update(acceptance="Soul Badge earned", natural=True, forbidden_shortcuts=False)
            self._toward_sabrina()
            return
        self.summary["acceptance"] = "walking toward the Soul Badge"
        self._vermilion_tools()
        self._pin_route_trainers()
        self._pin_cached_trainers()
        self._bind_post_rainbow()
        self.training_mode = None
        self._arrange_lead("starter")
        self.config["max_blackouts"] = 6
        if self.quantity("silphScope") != 1:
            self._rocket_hideout()
        if not self.flag("EVENT_GOT_POKE_FLUTE"):
            self._pokemon_tower()
        # Sequence 184 is already inside the Fuchsia Center. Walking the east
        # road again treats the gate as a dead edge on the way back to Lavender.
        if not self._in_fuchsia():
            from tools.harness.brock_journey import NaturalBlackout
            for attempt in range(4):
                try:
                    if not self.flag("EVENT_BEAT_ROUTE12_SNORLAX"):
                        self._wake_route12()
                        self.save()
                    self._arrange_lead("starter")
                    self._reach_route13()
                    self.enter_route14_from_east()
                    self.finish_eastern_road_to_fuchsia()
                    break
                except NaturalBlackout:
                    if attempt == 3:
                        raise
                    self.recover_path_blackout("east road")
                    self._arrange_lead("starter")
                    self.heal_here("LavenderPokecenter")
                    self.save()
        self._koga()
        self._toward_sabrina()

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

    def _clear_status(self, mon):
        return (mon or {}).get("status") in {None, "none"}

    def _mon_healthy(self, mon):
        maximum = mon.get("maxHP") or 0
        return (mon["hp"] > 0 and self._clear_status(mon)
                and maximum > 0 and mon["hp"] * 2 > maximum)

    def _lapras_needs_ice_beam(self):
        mon = next((row for row in self.party() if row["species"] == "lapras"), None)
        return mon is not None and mon["level"] < 38

    def _battle_members(self, battle):
        """Overlay the active fighter's live HP. The session copy lags a hit."""
        party = [dict(mon) for mon in self.party()]
        active = lookup(self.state, "session.party.active") or 1
        player = (battle or {}).get("player") or {}
        if 1 <= active <= len(party) and player.get("species") == party[active - 1].get("species"):
            for key in ("hp", "maxHP", "status"):
                if player.get(key) is not None:
                    party[active - 1][key] = player[key]
        return party, active

    def _lance_choice(self, party, enemy):
        """Charizard carries Lance while healthy. Ice Beam Lapras covers the gap."""
        enemy = (enemy or "").lower()

        def slot(species, healthy=False):
            names = {"pidgeotto", "pidgeot"} if species == "pidgeotto" else {species}
            for index, mon in enumerate(party, 1):
                if mon["species"] not in names or mon["hp"] <= 0 or not self._clear_status(mon):
                    continue
                if healthy and not self._mon_healthy(mon):
                    continue
                return index
            return None

        if enemy in {"gyarados", "aerodactyl"}:
            return slot("charizard", True) or slot("lapras") or slot("pidgeotto") or slot("weepinbell")
        if enemy in {"dragonair", "dragonite"}:
            return (slot("charizard", True) or slot("lapras") or slot("pidgeotto")
                    or slot("weepinbell") or slot("charizard"))
        return (slot("charizard", True) or slot("charizard") or slot("pidgeotto")
                or slot("lapras") or slot("weepinbell"))

    def _agatha_choice(self, party, enemy):
        """Poison and Ghost resist Fire. Lapras leads with Ice while it can take a hit."""
        enemy = (enemy or "").lower()

        def slot(species, healthy=False):
            for index, mon in enumerate(party, 1):
                if mon["species"] != species or mon["hp"] <= 0 or not self._clear_status(mon):
                    continue
                if healthy and not self._mon_healthy(mon):
                    continue
                return index
            return None

        if enemy not in {"gengar", "haunter", "golbat", "arbok"}:
            return slot("charizard", True) or slot("charizard")
        lapras = slot("lapras", True)
        if lapras is not None:
            moves = set(party[lapras - 1].get("moves") or [])
            if moves & {"iceBeam", "iceShard", "blizzard"}:
                return lapras
        return slot("charizard", True) or slot("lapras") or slot("charizard")

    def _lead_for_lance(self, enemy):
        """Charizard takes Gyarados and Aerodactyl only while he is healthy."""
        party = self.party()
        active = lookup(self.state, "session.party.active") or 1
        choice = self._lance_choice(party, enemy)
        if choice and choice != active:
            self.field_swap(choice, active)

    def choose_forced_switch(self):
        """A fainted lead yields to the matchup, not the next party slot."""
        battle = self.state.get("battle") or {}
        party, active = self._battle_members(battle)
        enemy = ((battle.get("enemy") or {}).get("species"))
        choice = self._lance_choice(party, enemy)
        if choice and choice != active:
            return choice
        conscious = [index for index, mon in enumerate(party, 1) if index != active and mon["hp"] > 0]
        clear = [index for index in conscious if self._clear_status(party[index - 1])]
        pool = clear or conscious
        return pool[0] if pool else None

    def _league_loss_stops(self):
        """One Lance loss leaves the plateau to raise Lapras. A second one stops."""
        last = (self.summary.get("battles") or [None])[-1] or {}
        outcome = last.get("outcome") if isinstance(last.get("outcome"), dict) else {}
        ident = " ".join(str(part or "") for part in (
            last.get("trainer_id"), last.get("trainer"), last.get("name"),
            outcome.get("trainer_id"),
        ))
        if "LANCES_ROOM" not in ident and "LANCE" not in ident.upper() and "CHAMPIONS_ROOM" not in ident:
            return False
        if getattr(self, "_lance_leveled", False):
            raise ProtocolError("Lance failed after the bench was leveled")
        self._lance_leveled = True
        self._level_bench_for_lance()
        self._indigo_plateau()
        return True

    def _level_bench_for_lance(self):
        """Victory Road's cave floor. Pokered teaches Lapras Ice Beam at 38."""
        from tools.harness.brock_journey import NaturalBlackout
        self.summary["acceptance"] = "leveling Lapras for Ice Beam"
        self._bench_share = True
        self._flee_wilds = False
        self._lance_training = True
        try:
            self._prepare_victory_cave()
            a, b = (28, 7), (28, 8)
            if self.position() not in {a, b}:
                self._walk_avoiding_warps(a)
            steps, quiet, extra = 0, 0, 0
            while steps < 900:
                lapras = next((mon for mon in self.party() if mon["species"] == "lapras"), None)
                if lapras and lapras["level"] >= 38:
                    extra += 1
                    if extra >= 60:
                        break
                if any(mon["hp"] <= 0 or not self._clear_status(mon) for mon in self.party()):
                    self._prepare_victory_cave()
                    if self.position() not in {a, b}:
                        self._walk_avoiding_warps(a)
                index = self._trainee_index()
                active = lookup(self.state, "session.party.active") or 1
                if index and index != active:
                    self.field_swap(index, active)
                before = len(self.summary.get("training") or [])
                goal = b if self.position() == a else a
                try:
                    self._step("down" if goal[1] > self.position()[1] else "up")
                except NaturalBlackout:
                    self.recover_blackout()
                    self._prepare_victory_cave()
                    continue
                after = len(self.summary.get("training") or [])
                quiet = 0 if after > before else quiet + 1
                # Blue's cave rate is 10/256. Eighty dry steps is a normal miss.
                if quiet >= 400:
                    self.save()
                    raise ProtocolError("Victory Road east pocket had no wild battle")
                steps += 1
            self.save()
            self._leave_east_cave()
        finally:
            self._bench_share = False
            self._flee_wilds = False
            self._lance_training = False

    def _needs_league_stock(self):
        money = self.inventory()["money"]
        for item, cap in (("revive", 3), ("maxPotion", 2), ("fullRestore", 2), ("fullHeal", 4)):
            if self.quantity(item) < cap and money >= self._INDIGO_PRICES[item]:
                return True
        return False

    def _grind_agatha_bench(self):
        """Victory Road wilds until Lapras and Weepinbell are both level 45.

        The east pocket is the open grass beside the Indigo door. Charizard
        covers a higher wild, and the trainee comes back for the finish so
        the experience lands on the bench. Route 23 is the fallback grass.
        """
        if self._agatha_bench_ready():
            return
        from tools.harness.brock_journey import NaturalBlackout
        self.summary["acceptance"] = "leveling Lapras and Weepinbell"
        self._bench_share = True
        self._flee_wilds = False
        self._agatha_training = True
        try:
            self._prepare_victory_cave()
            a, b = (28, 7), (28, 8)
            if self._on("VictoryRoad2F") and self.position() not in {a, b}:
                self._walk_avoiding_warps(a)
            steps, quiet, dry = 0, 0, 0
            seen = self._agatha_levels()
            while steps < 6000 and not self._agatha_bench_ready():
                if self._party_needs_center():
                    self._prepare_victory_cave()
                    quiet = 0
                if self._on("VictoryRoad2F") and self._reachable((28, 7)) and self.position() not in {a, b}:
                    self._walk_avoiding_warps(a)
                index = self._trainee_index()
                active = lookup(self.state, "session.party.active") or 1
                if index and index != active and self.state.get("root") == "overworld":
                    self.field_swap(index, active)
                before = len(self.summary.get("training") or [])
                goal = b if self.position() == a else a
                try:
                    if self._on("VictoryRoad2F") and self.position() in {a, b}:
                        self._step("down" if goal[1] > self.position()[1] else "up")
                    else:
                        self._try_south_grass()
                except NaturalBlackout:
                    self.recover_blackout()
                    self._prepare_victory_cave()
                    continue
                after = len(self.summary.get("training") or [])
                if after > before:
                    quiet = 0
                    dry = 0
                else:
                    quiet += 1
                levels = self._agatha_levels()
                if levels != seen:
                    seen = levels
                    self.summary["bench"] = levels
                    self.save()
                if quiet >= 400:
                    self.save()
                    dry += 1
                    quiet = 0
                    if dry >= 2:
                        raise ProtocolError(
                            "no wild battle while leveling at "
                            + self._map_name() + " " + str(self.position())
                            + " " + str(self._agatha_levels()))
                    self._try_south_grass()
                    self._prepare_victory_cave()
                steps += 1
            self.save()
            if not self._agatha_bench_ready():
                raise ProtocolError("bench stopped at " + str(self._agatha_levels()))
            if self._on("VictoryRoad2F") or self._on("VictoryRoad3F"):
                self._leave_east_cave()
        finally:
            self._bench_share = False
            self._flee_wilds = False
            self._agatha_training = False

    def _prepare_victory_cave(self):
        """Lobby Full Heals, then the east door. Route 23 grass stays walled off."""
        # A half-health trainee never comes back for the KO, so Charizard
        # solos and the bench stops gaining. Low HP has to walk to the nurse.
        hurt = self._party_needs_center() or any(
            not self._clear_status(mon) for mon in self.party())
        if self._on("VictoryRoad2F") and self._reachable((28, 7)) and not hurt and not self._needs_league_stock():
            return
        if self._on("VictoryRoad2F") or self._on("VictoryRoad3F"):
            self._leave_east_cave()
        if not self._on("IndigoPlateauLobby"):
            self._reach_lobby()
        self._heal_indigo()
        self._stock_league_items()
        self.save()
        self._enter_east_cave()

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
        if getattr(self, "_bench_share", False):
            self._lead_trainee()
            return
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

    def _throw_master_ball(self, battle, options):
        """The Master Ball is the one capture. A miss falls through to the fight."""
        if self.quantity("masterBall") <= 0:
            return False
        before = self.quantity("masterBall")
        positions = [i for i, value in enumerate(options, 1)
                     if value == "BAG" or isinstance(value, dict) and value.get("action") == "bag"]
        if len(positions) != 1:
            return False
        self.select("battle.menu.selected", positions[0])
        self.send("press a")
        self.require(root="bag")
        index = next((i for i, row in enumerate(sequence(self.inventory()["slots"], "inventory.slots"), 1)
                      if row["id"] == "masterBall"), None)
        if index is None:
            return False
        self.select("bag.selected", index)
        self.send("press a")
        self.require(root="battle")
        if self.quantity("masterBall") != before - 1:
            raise ProtocolError("Master Ball was not thrown")
        result = lookup(self.state, "battle.capture_result")
        self.summary.setdefault("captures", []).append({
            "enemy": battle.get("enemy"), "result": result, "ball": "masterBall",
        })
        return True

    def _spare_healing(self):
        """A battle may spend a spare Full Restore. The last one fills the next door.

        The field heal before each north door uses any missing Charizard HP.
        Spending the last bottle in Bruno leaves Lance and Blue short.
        """
        if self.quantity("fullRestore") > 1:
            return "fullRestore"
        if self.quantity("maxPotion"):
            return "maxPotion"
        return None

    def _spare_revive(self, battle):
        """A battle may spend a spare Revive. The last one stays for the next door.

        When nobody else is conscious, that last Revive is the only way to
        keep the fight going, so it is spent.
        """
        if self.quantity("maxRevive"):
            return "maxRevive"
        have = self.quantity("revive")
        if have > 1:
            return "revive"
        if have == 1:
            party, _active = self._battle_members(battle)
            if not any(mon["hp"] > 0 for mon in party):
                return "revive"
        return None

    def _revive_lance_bench(self, battle, options):
        """Spend a Revive on Lapras when Charizard cannot safely stay in."""
        enemy = ((battle.get("enemy") or {}).get("species") or "").lower()
        if enemy not in {"gyarados", "aerodactyl", "dragonair", "dragonite"}:
            return False
        party, _active = self._battle_members(battle)
        if any(mon["species"] == "charizard" and self._mon_healthy(mon) for mon in party):
            return False
        bench = {"lapras", "pidgeotto", "pidgeot", "weepinbell"}
        if any(mon["species"] in bench and mon["hp"] > 0 and self._clear_status(mon) for mon in party):
            return False
        item = self._spare_revive(battle)
        if item is None:
            return False
        for species in ("lapras", "pidgeot", "pidgeotto", "weepinbell"):
            for index, mon in enumerate(party, 1):
                if mon["species"] == species and mon["hp"] <= 0:
                    self.battle_medicine(item, options, target=index)
                    self._revive_switch = index
                    return True
        return False

    def _revive_starter(self, battle, options):
        """Bring Charizard back and send him in. The reserve does not finish Lorelei."""
        active = lookup(self.state, "session.party.active")
        switch = getattr(self, "_revive_switch", None)
        if switch:
            self._revive_switch = None
            enemy = ((battle.get("enemy") or {}).get("species") or "")
            mon = self.party()[switch - 1] if 1 <= switch <= len(self.party()) else None
            if (mon and mon["species"] == "charizard"
                    and enemy in {"gyarados", "aerodactyl", "dragonair", "dragonite"}
                    and not self._mon_healthy(mon)):
                return False
            if mon and mon["hp"] > 0 and active != switch:
                return bool(self.battle_switch(switch, options, "revive-starter"))
            return False
        player = battle.get("player") or {}
        if player.get("species") == "charizard" and (player.get("hp") or 0) > 0:
            return False
        for index, mon in enumerate(self.party(), 1):
            if mon["species"] != "charizard" or mon["hp"] > 0:
                continue
            item = self._spare_revive(battle)
            if item is None:
                return False
            self.battle_medicine(item, options, target=index)
            self._revive_switch = index
            return True
        return False

    def _top_off_starter(self, battle, options):
        zone = self.state.get("zone_id") or ""
        if not any(token in zone for token in (
            "LORELEIS_ROOM", "BRUNOS_ROOM", "AGATHAS_ROOM", "LANCES_ROOM", "CHAMPIONS_ROOM",
        )):
            return False
        player = battle.get("player") or {}
        if player.get("species") != "charizard":
            return False
        hp, maximum = player.get("hp") or 0, player.get("maxHP") or 1
        if hp <= 0 or hp * 3 > maximum * 2:
            return False
        item = self._spare_healing()
        if item is None:
            return False
        self.battle_medicine(item, options)
        return True

    def battle_preparation_action(self, battle, options):
        enemy = (battle.get("enemy") or {}).get("species")
        if enemy == "mewtwo" and not getattr(self, "_mewtwo_ball", False):
            self._mewtwo_ball = True
            if self._throw_master_ball(battle, options):
                return True
        player = battle.get("player") or {}
        status = player.get("status")
        if (player.get("hp") or 0) > 0 and status not in {None, "none"}:
            if status in {"paralysis", "paralyze", "paralyzed"} and self.quantity("parlyzHeal") > 0:
                self.battle_medicine("parlyzHeal", options)
                return True
            if self.quantity("fullHeal") > 0:
                self.battle_medicine("fullHeal", options)
                return True
            if self._spare_healing() == "fullRestore":
                self.battle_medicine("fullRestore", options)
                return True
            party, active = self._battle_members(battle)
            for index, mon in enumerate(party, 1):
                if index != active and mon["hp"] > 0 and self._clear_status(mon):
                    if self.battle_switch(index, options, "status-switch"):
                        return True
                    break
        enemy = ((battle.get("enemy") or {}).get("species") or "")
        zone = self.state.get("zone_id") or ""
        # A Max Potion makes Charizard the healthy lead before the matchup switch.
        if self._top_off_starter(battle, options):
            return True
        if "AGATHAS_ROOM" in zone and enemy:
            party, active = self._battle_members(battle)
            choice = self._agatha_choice(party, enemy)
            if choice and choice != active and self.battle_switch(choice, options, "agatha-matchup"):
                return True
        if any(token in zone for token in ("LANCES_ROOM", "CHAMPIONS_ROOM")) and enemy:
            party, active = self._battle_members(battle)
            choice = self._lance_choice(party, enemy)
            chosen = party[choice - 1] if choice else None
            hurt_starter = chosen and chosen["species"] == "charizard" and not self._mon_healthy(chosen)
            if (choice is None or hurt_starter) and self._revive_lance_bench(battle, options):
                return True
            if choice and choice != active and self.battle_switch(choice, options, "lance-matchup"):
                return True
        if self._revive_starter(battle, options):
            return True
        if getattr(self, "_bench_share", False) and self._share_bench(battle, options):
            return True
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

    def flee(self):
        """A Scope ghost or a flute Snorlax is a real battle. Other wilds run."""
        enemy = lookup(self.state, "battle.enemy")
        if isinstance(enemy, dict) and enemy.get("species") == "mewtwo":
            return self.battle("mewtwo")
        expected = getattr(self, "scripted_wild", None)
        enemy = lookup(self.state, "battle.enemy")
        if (expected and isinstance(enemy, dict)
                and enemy.get("species") == expected["species"]
                and enemy.get("level") == expected["level"]):
            return self.battle("source-" + expected["species"], expected="win")
        return super().flee()

    def battle(self, name, strategy="attack", expected=None):
        from tools.harness.brock_journey import NaturalBlackout
        from tools.harness.cerulean_journey import CeruleanJourney
        trainer_id = lookup(self.state, "event.id")
        # A finished trainer leaves event.id set. The next wild fight must not
        # be checked against that leftover id.
        trainer_battle = bool(lookup(self.state, "battle.trainerName"))
        label = key_fight(name, trainer_id if trainer_battle else None)
        recorder = getattr(self, "record_fight", None)
        started = recorder(label) if recorder and label else None
        import tools.harness.brock_journey as journey
        original_choice = journey.choose_move

        def pick(moves, level=None):
            enemy = (self.state.get("battle") or {}).get("enemy") or {}
            # Growlithe's Flash Fire absorbs Charizard's fire moves. The type
            # chart still calls them not-very-effective, so the damage score
            # would keep selecting Flamethrower.
            if enemy.get("species") == "growlithe":
                covered = [move for move in moves if move.get("type") != "fire"]
                if covered:
                    moves = covered
            return original_choice(moves, level)

        journey.choose_move = pick
        try:
            try:
                result = super().battle(name, strategy, expected)
            except NaturalBlackout:
                if getattr(self, "stage", None) == "cerulean" and trainer_battle:
                    CeruleanJourney.record_source_outcome(self, trainer_id)
                raise
            if getattr(self, "stage", None) == "cerulean" and trainer_battle:
                CeruleanJourney.record_source_outcome(self, trainer_id)
            return result
        finally:
            journey.choose_move = original_choice
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
        store = archive_agent_save(self.client.data, self.state)
        if store is not None:
            note["store"] = store.get("files")
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
        self.assertEqual(key_fight("source", "pokered:CELADON_GYM:objects:1"), "badge-rainbow")
        self.assertEqual(key_fight("source", "pokered:FUCHSIA_GYM:objects:1"), "badge-soul")
        self.assertEqual(key_fight("source", "pokered:SAFFRON_GYM:objects:1"), "badge-marsh")
        source = Path(__file__).read_text(encoding="utf-8")
        self.assertIn('self.config.setdefault("packet", "lane-i")', source)
        sabrina = source.split("def _toward_sabrina", 1)[1].split("def _toward_blaine", 1)[0]
        self.assertLess(sabrina.index('if self.flag("BADGE_MARSH")'), sabrina.index("self.route_c_guard()"))
        self.assertIn("press down", source.split("def fixed_warp", 1)[1].split("def key_door", 1)[0])
        blaine = source.split("def _toward_blaine", 1)[1].split("def _east_to_fuchsia", 1)[0]
        self.assertLess(blaine.index("self._surf_known()"), blaine.index('self.quantity("escapeRope")'))
        self.assertLess(blaine.index('self.ensure_room("SaffronMart")'), blaine.index("self.safari_journey()"))
        self.assertIn("self._east_to_fuchsia()", blaine)
        east = source.split("def _east_to_fuchsia", 1)[1].split("def _toward_koga", 1)[0]
        self.assertIn("Route8Gate", east)
        advance = source.split("def advance_event", 1)[1].split("def portals", 1)[0]
        self.assertIn("advance_travel", advance)
        self.assertEqual(key_fight("source", "pokered:CINNABAR_GYM:objects:1"), "badge-volcano")
        self.assertEqual(key_fight("source", "pokered:VIRIDIAN_GYM:objects:1"), "badge-earth")
        self.assertEqual(key_fight("source", "pokered:ROUTE_22:objects:2"), "rival-2")
        self.assertEqual(key_fight("source", "pokered:LORELEIS_ROOM:objects:1"), "elite-lorelei")
        self.assertEqual(key_fight("source", "pokered:CHAMPIONS_ROOM:objects:1"), "champion")
        stock = source.split("def _stock_league_items", 1)[1].split("def _want_league_shop", 1)[0]
        self.assertLess(stock.index('"fullRestore", 2'), stock.index('"maxPotion", 2'))
        self.assertLess(stock.index("len(slots) >= 20"), stock.index("self.buy_item"))
        self.assertIn("def _spare_revive", source)
        self.assertIn("def _spare_healing", source)
        door = source.split("def _top_off_in_field", 1)[1].split("def _needs_league_heal", 1)[0]
        battle_heal = source.split("def _top_off_starter", 1)[1].split("def battle_preparation_action", 1)[0]
        self.assertIn('self.quantity("fullRestore")', door)
        self.assertIn("self._spare_healing()", battle_heal)
        climb = source.split("def _climb_route23", 1)[1].split("def _pin_victory_trainers", 1)[0]
        self.assertIn("self._victory_road_2f()", climb)
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
        source = Path(__file__).read_text(encoding="utf-8")
        self.assertIn(
            "dismiss_simulator_dialogs()\n        proc = subprocess.Popen(",
            source)

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
        self.assertIn("sold_after_cascade", body)
        self.assertLess(body.index("sold_after_cascade"), body.index("EVENT_GOT_DOME_FOSSIL"))
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


def archive_agent_save(data_dir, state):
    """Keep one folder per adventure sequence outside the VM's temporary disk."""
    data_dir = Path(data_dir)
    sequences = []
    for path in data_dir.glob("adventure*.json"):
        try:
            sequences.append(int(json.loads(path.read_text(encoding="utf-8")).get("sequence")))
        except (OSError, ValueError, TypeError):
            continue
    if not sequences:
        return None
    destination = (Path("/cursor/stores/self/artifacts/lane-i/charmander-8/saves")
                   / ("seq-%03d" % max(sequences)))
    return publish_save(data_dir, destination, state)


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
                dismiss_simulator_dialogs()
                window = _window() or window
                self.origin = window
                return window
            time.sleep(0.25)
        return None

    def start(self, label, seconds=None):
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
        # after the fight. Other clips stay at 60 unless a milestone asks shorter.
        if seconds is None:
            # Giovanni's five Pokémon run past a 90-second page. The prize
            # line is the frame that has to show the yen.
            if label == "badge-earth":
                seconds = "180"
            elif label == "rival-2":
                seconds = "90"
            elif label in {"elite-lorelei", "elite-bruno", "elite-agatha", "elite-lance", "champion", "victory-road"}:
                seconds = "90"
            elif str(label).startswith("badge-"):
                seconds = "90"
            else:
                seconds = "60"
        seconds = str(seconds)
        # The Heads up title must be gone before the LCD grab.
        dismiss_simulator_dialogs()
        proc = subprocess.Popen(
            lcd_clip_command(display, origin_x, origin_y, seconds, path),
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.procs.append((label, path, proc, time.time()))

        def publish():
            proc.wait()
            if not path.is_file() or path.stat().st_size <= 0:
                return
            store = Path("/cursor/stores/self/clips")
            store.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, store / path.name)

        threading.Thread(target=publish, daemon=True).start()
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
                summary["trace"] = traceback.format_exc(limit=15)
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
                    store = archive_agent_save(data, run.state)
                    if store is not None:
                        note["store"] = str(Path("/cursor/stores/self/artifacts/lane-i/charmander-8/saves"))
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
