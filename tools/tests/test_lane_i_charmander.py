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

ACTION_PAUSE = 17000

FORBIDDEN_OPS = {"fixture", "warp", "debug", "intro", "seed", "battle", "encounters", "face"}
LCD_OFFSET = (18, 45)
LCD_SIZE = (400, 240)
EXPECTED_WINDOW = (486, 700)


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
    return (not stopping) and actions >= ACTION_PAUSE and (state or {}).get("root") == "overworld"


def key_fight(name, trainer_id):
    """Rival, the Pewter gym, and Brock are the early clips."""
    label = str(name or "")
    trainer = str(trainer_id or "")
    if label == "rival":
        return "rival"
    if trainer == "pokered:PEWTER_GYM:objects:2":
        return "pewter-jr"
    if trainer == "pokered:PEWTER_GYM:objects:1" or label.startswith("brock"):
        return "brock"
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
            self._stopping = True
            self.save()
            raise ActionPause("charmander saved so the next session can continue")
        commands = pause_press(ball_press(commands, self.state), self.state)
        real_input(commands)
        return super().send(*commands)

    def training_battle(self):
        super().training_battle()
        count = len(self.summary.get("training") or [])
        if count % 10 == 0 and self.state.get("root") == "overworld" and not getattr(self, "_stopping", False):
            self.save()

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
            self.save()
            self.summary["acceptance"] = "Brock badge already saved"
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

    def battle(self, name, strategy="attack", expected=None):
        trainer_id = lookup(self.state, "event.id")
        label = key_fight(name, trainer_id)
        recorder = getattr(self, "record_fight", None)
        started = recorder(label) if recorder and label else None
        try:
            return super().battle(name, strategy, expected)
        finally:
            if started:
                started()

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
        self.assertEqual(key_fight("source", "pokered:PEWTER_GYM:objects:1"), "brock")
        self.assertEqual(key_fight("source", "pokered:PEWTER_GYM:objects:2"), "pewter-jr")
        self.assertIsNone(key_fight("preparation-1", "pokered:VIRIDIAN_FOREST:objects:2"))

    def test_action_pause_only_happens_in_the_overworld(self):
        self.assertTrue(needs_action_pause(ACTION_PAUSE, {"root": "overworld"}, False))
        self.assertFalse(needs_action_pause(ACTION_PAUSE, {"root": "battle"}, False))
        self.assertFalse(needs_action_pause(ACTION_PAUSE - 1, {"root": "overworld"}, False))
        self.assertFalse(needs_action_pause(ACTION_PAUSE, {"root": "overworld"}, True))

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
        proc = subprocess.Popen(
            ["ffmpeg", "-y", "-loglevel", "error", "-f", "x11grab",
             "-video_size", f"{LCD_SIZE[0]}x{LCD_SIZE[1]}", "-framerate", "30",
             "-i", f"{display}.0+{origin_x},{origin_y}",
             "-t", "75", "-an", "-c:v", "libx264", "-pix_fmt", "yuv420p", str(path)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.procs.append((label, path, proc))
        return proc

    def finish(self):
        clips = []
        for label, path, proc in self.procs:
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.send_signal(signal.SIGINT)
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(timeout=5)
            if path.is_file() and path.stat().st_size > 0:
                clips.append({"label": label, "path": str(path),
                              "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                              "bytes": path.stat().st_size})
        return clips


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

            def record_fight(label):
                proc = recorder.start(label)
                if proc is None:
                    return None
                def _stop():
                    return None
                return _stop

            run.record_fight = record_fight
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
                summary["clips"] = recorder.finish()
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
