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

from tools.harness.brock_journey import BrockJourney
from tools.harness.journeys import lookup
from tools.harness.parcel_journey import sequence
from tools.harness.protocol import ProtocolError

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
        real_input(commands)
        return super().send(*commands)

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


def play(output, probe=False):
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
                run.natural()
                summary["ok"] = True
                summary["acceptance"] = run.summary.get("acceptance")
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


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--play", type=Path, help="run the Simulator path into this new directory")
    parser.add_argument("--probe", action="store_true", help="boot to the title and capture the window")
    args, remaining = parser.parse_known_args(argv)
    if args.play:
        os.environ.setdefault("PLAYDATE_SDK_PATH", str(Path.home() / "Developer/PlaydateSDK"))
        os.environ.setdefault("DISPLAY", ":1")
        summary = play(args.play, probe=args.probe)
        return 0 if summary.get("ok") else 1
    unittest.main(argv=[sys.argv[0], *remaining])


if __name__ == "__main__":
    sys.exit(main())
