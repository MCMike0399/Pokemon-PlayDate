#!/usr/bin/env python3
"""Squirtle golden path. Real button presses only.

pret/pokered af519899719f0754965776faac0e836a3b906e6d:
- constants/player_constants.asm IF DEF(_BLUE): player BLUE/GARY/JOHN,
  rival RED/ASH/JACK. data/player/names.asm DefaultNamesPlayer starts
  with NEW NAME, then those three.
- scripts/OaksLab.asm OaksLab_Object: object_event 7, 3 is
  OAKSLAB_SQUIRTLE_POKE_BALL. Source/world/sourceMaps.lua adds the
  manifest padding (1) to event.x, so the ball the player faces is (8, 3).
  Source/game/story.lua BALLS uses that padded cell.

The driver sends press, wait, snapshot, and await. It does not send
move, warp, fixture, intro, battle, or an HP edit.
"""

import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REMAINDER = ROOT / "Source/data/zRemainder"
STORY = ROOT / "Source/game/story.lua"
NAMING = ROOT / "Source/game/namingState.lua"
INK_WHITE = 214
INK_BLACK = 49
THRESHOLD = (INK_WHITE + INK_BLACK) // 2 + 1  # 132
NAME_PRESS = ("down", "a")

# Padded grids. maps.lua registerPalletZones uses these pad/width pairs.
# OaksLab is also the imported kanto_oaks_lab grid: padding 1, width 13.
GRIDS = {
    "reds_house_2f": ("RedsHouse2F", 2, 13),
    "reds_house": ("RedsHouse1F", 2, 13),
    "pallet_town": ("PalletTown", 0, 20),
    "oaks_lab": ("OaksLab", 1, 13),
}
STAIR = (9, 1)
HOUSE_EXIT = (5, 7)
MOM = (7, 4)
PALLET_DOORS = {(5, 5), (13, 5), (12, 11)}
SQUIRTLE_BALL = (8, 3)
SQUIRTLE_FACE = (8, 4)
LAB_LANDING = (6, 4)
LAB_EXITS = {(5, 11), (6, 11)}
ALLOWED_OPS = {"press", "wait", "snapshot", "await", "shot"}


def threshold_byte(value):
    return 255 if value >= THRESHOLD else 0


def lossless_gray_argv(source, destination):
    return [
        "ffmpeg", "-y", "-loglevel", "error", "-i", str(source),
        "-vf", "format=gray,geq=lum='if(gte(lum(X,Y),%d),255,0)'" % THRESHOLD,
        "-an", "-c:v", "libx264rgb", "-crf", "0", "-preset", "veryfast",
        "-pix_fmt", "rgb24", str(destination),
    ]


def clip_path(folder, stamp, slug):
    if not stamp or not slug or "/" in slug or " " in slug:
        raise ValueError("clip slug must be a single path segment")
    return Path(folder) / f"{stamp}-{slug}.mp4"


MART_SAVE = Path("/opt/cursor/artifacts/lane-j/saves/mart-a7df918d")
MART_SAVE_SHA = "9a801867ea18179a35c24ced5379781cea0dc7a07fd796b741454c0c2b4a48f7"
LAB_SAVE = Path("/opt/cursor/artifacts/lane-j/saves/930683c875b3")
LAB_SAVE_SHA = "846b901711349edf2b2f4abfea505fb3b66593d290e4e3170e0e354aad7ced3a"
OLD_MAN = "pokered:VIRIDIAN_CITY:objects:7"
BROCK = "pokered:PEWTER_GYM:objects:1"


def preferred_move(options):
    """Bubble, then Water Gun. Tackle only when no water move is listed."""
    named = []
    for index, name in enumerate(options or [], start=1):
        letters = "".join(ch for ch in str(name).upper() if ch.isalpha())
        if letters in {"", "DASH"} or str(name).strip() in {"", "-"}:
            continue
        named.append((index, name, letters))
    for index, name, letters in named:
        if letters in {"BUBBLE", "WATERGUN"}:
            return index, name
    if named:
        return named[0][0], named[0][1]
    return None, None


def publish_clip(report, destination, duration, keep="end"):
    """Keep a 20–90s clip. A long handoff keeps its opening, not its tail."""
    if destination is None or not Path(destination).exists() or duration is None:
        return None
    destination = Path(destination)
    original = duration
    if duration > 90:
        trimmed = destination.with_name(destination.stem + "-part.mp4")
        argv = ["ffmpeg", "-y", "-loglevel", "error"]
        if keep == "start":
            argv += ["-i", str(destination), "-t", "85"]
        else:
            argv += ["-ss", f"{max(0, duration - 85):.3f}", "-i", str(destination), "-t", "85"]
        argv += ["-an", "-c:v", "libx264rgb", "-crf", "0", "-pix_fmt", "rgb24", str(trimmed)]
        subprocess.check_call(argv)
        destination.unlink()
        trimmed.replace(destination)
        duration = float(subprocess.check_output([
            "ffprobe", "-v", "error", "-show_entries", "format=duration",
            "-of", "csv=p=0", str(destination),
        ], text=True).strip())
    if not 20 <= duration <= 90:
        report["clip_short"] = {"path": str(destination), "duration": duration}
        return duration
    entry = {
        "path": str(destination.relative_to(ROOT)),
        "sha256": sha256_file(destination),
        "duration": duration,
    }
    if original > 90:
        entry["trimmed_from"] = original
        entry["keep"] = keep
    report.setdefault("clips", []).append(entry)
    return duration


def open_map(path, pad, width):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    rows = data["collision"]
    raw = len(rows[0])
    right = width - raw - pad
    if right < 0:
        raise ValueError(path)
    open_cells = set()
    for y, row in enumerate(rows):
        line = [1] * pad + list(row) + [1] * right
        for x, cell in enumerate(line):
            if cell == 0:
                open_cells.add((x, y))
    return open_cells


def padded_open_cells(map_name):
    file_name, pad, width = GRIDS[map_name]
    return open_map(REMAINDER / f"{file_name}.json", pad, width)


def route1_cells():
    return open_map(ROOT / "Source/data/viridianSlice/Route1.json", 0, 20)


def viridian_cells():
    return open_map(ROOT / "Source/data/viridianSlice/ViridianCity.json", 0, 40)


def mart_cells():
    return open_map(ROOT / "Source/data/viridianSlice/ViridianMart.json", 2, 13)


def route2_cells():
    return open_map(ROOT / "Source/data/pewterSlice/Route2.json", 0, 20)


def forest_cells():
    return open_map(ROOT / "Source/data/pewterSlice/ViridianForest.json", 0, 34)


def forest_south_cells():
    return open_map(ROOT / "Source/data/pewterSlice/ViridianForestSouthGate.json", 1, 13)


def forest_north_cells():
    return open_map(ROOT / "Source/data/pewterSlice/ViridianForestNorthGate.json", 1, 13)


def pewter_cells():
    return open_map(ROOT / "Source/data/pewterSlice/PewterCity.json", 0, 40)


def gym_cells():
    return open_map(ROOT / "Source/data/pewterSlice/PewterGym.json", 1, 13)


def center_cells():
    return open_map(ROOT / "Source/data/pewterSlice/PewterPokecenter.json", 0, 14)


# IntroMovie.SCENES. Copyright and the black bars ignore A. The shooting
# star accepts A as skip-to-fight, and the fight accepts A as finish.
INTRO_STEP_WAIT = 12
VIRIDIAN_WARPS = {(23, 25), (21, 15), (21, 9), (32, 7)}
VIRIDIAN_MART = (29, 19)
VIRIDIAN_SOUTH = (21, 35)


def intro_movie_frames(text):
    total = 0
    found = False
    for expr in re.findall(r'scene\(\s*"[^"]+"\s*,\s*([^,]+),', text):
        found = True
        if not re.fullmatch(r"[0-9*+\s]+", expr.strip()):
            raise ValueError(expr)
        for part in expr.split("+"):
            value = 1
            for factor in part.split("*"):
                factor = factor.strip()
                if not factor.isdecimal():
                    raise ValueError(expr)
                value *= int(factor)
            total += value
    if not found:
        raise ValueError("intro scenes missing")
    return total


def title_action(options):
    """CONTINUE is the earned save. NEW GAME is only the first boot."""
    if "CONTINUE" in options:
        return "CONTINUE"
    if "NEW GAME" in options:
        return "NEW GAME"
    return None


DELTAS = {"up": (0, -1), "down": (0, 1), "left": (-1, 0), "right": (1, 0)}


def neighbor(cell, direction):
    dx, dy = DELTAS[direction]
    return cell[0] + dx, cell[1] + dy


def route(open_cells, start, goal, avoid=()):
    """Four-direction walk on open cells. The goal may be open. avoid is blocked.

    The start cell counts as open. Pallet's Route 1 seam (9, 0) is solid in
    the source grid and forced open at runtime, and the player is already
    standing on it.
    """
    blocked = set(avoid)
    open_cells = set(open_cells)
    open_cells.add(start)
    if start == goal:
        return []
    if goal not in open_cells or start in blocked or goal in blocked:
        return None
    queue = [start]
    previous = {start: None}
    while queue:
        cell = queue.pop(0)
        for direction in ("up", "down", "left", "right"):
            nxt = neighbor(cell, direction)
            if nxt in previous or nxt not in open_cells or nxt in blocked:
                continue
            previous[nxt] = (cell, direction)
            if nxt == goal:
                steps = []
                cursor = nxt
                while cursor != start:
                    cursor, direction = previous[cursor]
                    steps.append(direction)
                steps.reverse()
                return steps
            queue.append(nxt)
    return None


def first_cell(open_cells, start, predicate, avoid=()):
    blocked = set(avoid)
    open_cells = set(open_cells)
    open_cells.add(start)
    queue = [start]
    seen = {start}
    while queue:
        cell = queue.pop(0)
        if cell not in blocked and predicate(cell):
            return cell
        for direction in ("up", "down", "left", "right"):
            nxt = neighbor(cell, direction)
            if nxt in seen or nxt not in open_cells or nxt in blocked:
                continue
            seen.add(nxt)
            queue.append(nxt)
    return None


def command_op(command):
    if isinstance(command, str):
        return command.split()[0]
    if isinstance(command, dict):
        return command.get("op")
    return None


def assert_real_input(commands):
    for command in commands:
        op = command_op(command)
        if op not in ALLOWED_OPS:
            raise AssertionError(f"not a button command: {command!r}")


class SquirtleRouteTests(unittest.TestCase):
    def test_blue_name_presets_match_the_port(self):
        text = NAMING.read_text(encoding="utf-8")
        self.assertIn('NamingScreen.PLAYER_PRESETS = {"NEW NAME", "BLUE", "GARY", "JOHN"}', text)
        self.assertIn('NamingScreen.RIVAL_PRESETS = {"NEW NAME", "RED", "ASH", "JACK"}', text)
        # NamingScreen.new starts cursor at 1, which is NEW NAME.
        # One down, then A, selects BLUE for the player and RED for the rival.
        self.assertIn("cursor = 1", text)
        self.assertEqual(NAME_PRESS, ("down", "a"))

    def test_squirtle_ball_is_the_padded_oaks_lab_object(self):
        text = STORY.read_text(encoding="utf-8")
        self.assertIn('{ x = 8, y = 3, species = "squirtle" }', text)
        data = json.loads((REMAINDER / "OaksLab.json").read_text(encoding="utf-8"))
        balls = [obj for obj in data["events"]["objects"] if obj.get("text_id") == "TEXT_OAKSLAB_SQUIRTLE_POKE_BALL"]
        self.assertEqual(len(balls), 1)
        self.assertEqual((balls[0]["x"], balls[0]["y"]), (7, 3))
        self.assertEqual((balls[0]["x"] + 1, balls[0]["y"]), SQUIRTLE_BALL)

    def test_bedroom_stairs_house_exit_and_pallet_grass_are_open(self):
        bedroom = padded_open_cells("reds_house_2f")
        house = padded_open_cells("reds_house")
        pallet = padded_open_cells("pallet_town")
        lab = padded_open_cells("oaks_lab")
        stairs = route(bedroom, (5, 3), STAIR)
        self.assertEqual(route_cells(bedroom, (5, 3), STAIR)[0], (5, 3))
        self.assertEqual(route_cells(bedroom, (5, 3), STAIR)[-1], STAIR)
        self.assertTrue(set(route_cells(bedroom, (5, 3), STAIR)) <= bedroom)
        self.assertGreaterEqual(len(stairs), 2)
        self.assertNotIn(MOM, route_cells(house, (9, 1), HOUSE_EXIT, avoid={MOM}))
        self.assertIsNotNone(route(house, (9, 1), HOUSE_EXIT, avoid={MOM}))
        north = first_cell(pallet, (5, 6), lambda cell: cell[1] <= 2, avoid=PALLET_DOORS)
        self.assertIsNotNone(north)
        self.assertLessEqual(north[1], 2)
        walked = route_cells(pallet, (5, 6), north, avoid=PALLET_DOORS)
        self.assertTrue(PALLET_DOORS.isdisjoint(walked))
        self.assertIn(SQUIRTLE_FACE, lab)
        self.assertNotIn(SQUIRTLE_BALL, lab)
        self.assertIsNotNone(route(lab, LAB_LANDING, SQUIRTLE_FACE))
        self.assertTrue(LAB_EXITS <= lab)
        route1 = route1_cells()
        self.assertIn((10, 35), route1)
        north = first_cell(route1, (10, 35), lambda cell: cell[1] == 0)
        self.assertIsNotNone(north)
        self.assertIsNotNone(route(route1, (10, 35), north))
        city = viridian_cells()
        self.assertIn(VIRIDIAN_SOUTH, city)
        self.assertIn(VIRIDIAN_MART, city)
        walked = route_cells(city, VIRIDIAN_SOUTH, VIRIDIAN_MART, avoid=VIRIDIAN_WARPS)
        self.assertTrue(VIRIDIAN_WARPS.isdisjoint(walked))
        self.assertEqual(walked[-1], VIRIDIAN_MART)

    def test_intro_skip_presses_a_instead_of_sitting_on_the_copyright(self):
        frames = intro_movie_frames((ROOT / "Source/game/introMovie.lua").read_text(encoding="utf-8"))
        self.assertGreaterEqual(frames, 180 + 64)
        covered = 0
        presses = 0
        while covered < frames:
            self.assertLessEqual(INTRO_STEP_WAIT, 30)
            covered += INTRO_STEP_WAIT + 1
            presses += 1
        self.assertGreater(presses, 1)
        self.assertGreaterEqual(covered, frames)
        self.assertEqual(INTRO_STEP_WAIT, 12)

    def test_continue_is_the_earned_title_row(self):
        self.assertEqual(title_action(["CONTINUE", "NEW GAME", "OPTION"]), "CONTINUE")
        self.assertEqual(title_action(["NEW GAME", "OPTION"]), "NEW GAME")
        self.assertIsNone(title_action(["OPTION"]))
        mart = mart_cells()
        self.assertEqual(route(mart, (4, 5), (6, 7)), ["down", "down", "right", "right"])
        self.assertIsNotNone(route(padded_open_cells("pallet_town"), (10, 0), (12, 11), avoid={(5, 5), (13, 5)}))
        pallet = padded_open_cells("pallet_town")
        self.assertNotIn((9, 0), pallet)
        seam = route(pallet, (9, 0), (12, 11), avoid={(5, 5), (13, 5)})
        self.assertIsNotNone(seam)
        self.assertNotIn((5, 5), route_cells(pallet, (9, 0), (12, 11), avoid={(5, 5), (13, 5)}))

    def test_button_vocabulary_excludes_warps_and_fixtures(self):
        assert_real_input(["press a", "wait 12", "snapshot", {"op": "await", "path": "zone", "equals": "oaks_lab"}])
        with self.assertRaises(AssertionError):
            assert_real_input(["warp oaks_lab", "press a"])
        with self.assertRaises(AssertionError):
            assert_real_input([{"op": "fixture", "options": {}}])

    def test_water_move_is_preferred_and_the_north_path_is_open(self):
        self.assertEqual(preferred_move(["TACKLE", "TAIL WHIP", "BUBBLE", "-"]), (3, "BUBBLE"))
        self.assertEqual(preferred_move(["TACKLE", "-"])[1], "TACKLE")
        pallet = padded_open_cells("pallet_town")
        pallet.add((9, 0))
        self.assertIsNotNone(route(pallet, (12, 12), (9, 0), avoid={(5, 5), (13, 5), (12, 11)}))
        self.assertIn((11, 0), route1_cells())
        self.assertIn((6, 0), forest_south_cells())
        self.assertIn((6, 0), forest_north_cells())
        self.assertIsNotNone(route(route2_cells(), (3, 44), (3, 43), avoid={(12, 9), (3, 11)}))
        self.assertIsNotNone(route(route2_cells(), (3, 10), (8, 0), avoid={(12, 9), (3, 11)}))
        self.assertIsNotNone(route(forest_cells(), (16, 47), (1, 1)))
        self.assertIn((5, 3), gym_cells())
        self.assertEqual(sha256_file(LAB_SAVE / "adventure.a.json"), LAB_SAVE_SHA)

    def test_mart_resume_and_pokedex_clip_are_named(self):
        source = (ROOT / "tools/tests/test_lane_j_squirtle.py").read_text(encoding="utf-8")
        self.assertIn("pokedex-lab", source)
        self.assertIn(MART_SAVE_SHA, source)
        self.assertEqual(sha256_file(MART_SAVE / "adventure.b.json"), MART_SAVE_SHA)
        lab = (ROOT / "Source/data/maps.lua").read_text(encoding="utf-8")
        block = lab.split('zone("oaks_lab"', 1)[1].split('zone("pallet_town"', 1)[0]
        self.assertIn('name = "OAK"', block)
        self.assertIn("gridX = 6", block)
        self.assertIn("gridY = 2", block)

    def test_clip_name_uses_the_lane_j_folder(self):
        path = clip_path("artifacts/lane-j", "20261119T235900Z", "rival-lab")
        self.assertEqual(path.as_posix(), "artifacts/lane-j/20261119T235900Z-rival-lab.mp4")
        with self.assertRaises(ValueError):
            clip_path("artifacts/lane-j", "20261119T235900Z", "gym/pewter")

    def test_threshold_splits_the_simulator_inks(self):
        self.assertEqual(threshold_byte(INK_WHITE), 255)
        self.assertEqual(threshold_byte(203), 255)
        self.assertEqual(threshold_byte(INK_BLACK), 0)
        self.assertEqual(threshold_byte(0), 0)
        self.assertEqual(threshold_byte(255), 255)
        argv = lossless_gray_argv("in.nut", "out.mp4")
        self.assertNotIn("yuv420p", argv)
        self.assertNotIn("yuv444p", argv)
        self.assertIn("libx264rgb", argv)
        self.assertIn("rgb24", argv)

    def test_ffmpeg_threshold_frame_is_only_black_and_white(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            source = folder / "inks.png"
            encoded = folder / "clip.mp4"
            decoded = folder / "back.raw"
            subprocess.check_call([
                "ffmpeg", "-y", "-loglevel", "error",
                "-f", "lavfi", "-i", "color=c=0xD6D3CB:s=8x4",
                "-f", "lavfi", "-i", "color=c=0x312E28:s=8x4",
                "-filter_complex", "[0][1]hstack", "-frames:v", "1", str(source),
            ])
            subprocess.check_call(lossless_gray_argv(source, encoded))
            subprocess.check_call([
                "ffmpeg", "-y", "-loglevel", "error", "-i", str(encoded),
                "-f", "rawvideo", "-pix_fmt", "gray", str(decoded),
            ])
            raw = decoded.read_bytes()
            self.assertEqual(len(raw), 16 * 4)
            self.assertEqual(set(raw[:8]), {255})
            self.assertEqual(set(raw[8:16]), {0})


def route_cells(open_cells, start, goal, avoid=()):
    steps = route(open_cells, start, goal, avoid)
    if steps is None:
        raise AssertionError(f"no route {start} -> {goal}")
    cells = [start]
    cell = start
    for direction in steps:
        cell = neighbor(cell, direction)
        cells.append(cell)
    return cells


def summary(state):
    player = state.get("player") or {}
    title = state.get("title") or {}
    battle = state.get("battle") or {}
    pokemon = state.get("pokemon") or {}
    story = state.get("story") or {}
    return {
        "root": state.get("root"),
        "stack": state.get("stack"),
        "zone": state.get("zone"),
        "overworld": state.get("overworld"),
        "x": player.get("x"),
        "y": player.get("y"),
        "facing": player.get("facing"),
        "settled": player.get("settled"),
        "title": title.get("phase"),
        "story": story.get("stage"),
        "starter": story.get("starter"),
        "species": pokemon.get("species"),
        "level": pokemon.get("level"),
        "hp": pokemon.get("hp"),
        "battle": battle.get("phase"),
        "enemy": (battle.get("enemy") or {}).get("species"),
    }


class Player:
    """One identified Simulator session. Commands stay on the button path."""

    def __init__(self, client, log):
        self.client = client
        self.log = log
        self.state = {}

    def send(self, *commands, timeout=90, max_frames=1800):
        assert_real_input(commands)
        result = self.client.send(list(commands), timeout=timeout, max_frames=max_frames)
        self.state = result["snapshot"]
        self.log.write(json.dumps({"commands": [c if isinstance(c, str) else c.get("op") for c in commands],
                                   "state": summary(self.state)}) + "\n")
        self.log.flush()
        return self.state

    def press(self, button, wait=1, timeout=120):
        commands = [f"press {button}"]
        if wait:
            commands.append(f"wait {wait}")
        return self.send(*commands, timeout=timeout, max_frames=max(1800, wait + 30))

    def pos(self):
        player = self.state.get("player") or {}
        return self.state.get("zone"), player.get("x"), player.get("y")

    def exploring(self):
        player = self.state.get("player") or {}
        return (self.state.get("root") == "overworld" and self.state.get("overworld") == "explore"
                and player.get("settled") is True)

    def settle(self, limit=80):
        for _ in range(limit):
            if self.state.get("root") != "overworld":
                return
            if self.exploring():
                return
            self.send("wait 6", timeout=120, max_frames=400)

    def step(self, direction):
        if not self.exploring():
            self.settle()
        if not self.exploring():
            return "overlay"
        zone, x, y = self.pos()
        self.press(direction, wait=12)
        self.settle()
        if self.state.get("root") != "overworld":
            return "overlay"
        if self.state.get("zone") != zone:
            return "warp"
        player = self.state.get("player") or {}
        if (player.get("x"), player.get("y")) != (x, y):
            return "moved"
        return "blocked"

    def menu(self, key):
        node = self.state.get(key) or {}
        menu = node.get("menu") or {}
        return menu

    def choose(self, key, label):
        for _ in range(8):
            menu = self.menu(key)
            options = menu.get("options") or []
            if label not in options:
                raise RuntimeError(f"{key} has no {label}: {options}")
            selected = menu.get("selected") or 1
            target = options.index(label) + 1
            if selected == target:
                self.press("a", wait=6)
                return
            cols = menu.get("columns") or 1
            row, col = divmod(selected - 1, cols)
            goal_row, goal_col = divmod(target - 1, cols)
            if row != goal_row:
                self.press("down" if goal_row > row else "up", wait=2)
            else:
                self.press("right" if goal_col > col else "left", wait=2)
        raise RuntimeError(f"could not select {label} on {key}")

    def dismiss_until_explore(self, limit=80):
        for _ in range(limit):
            if self.exploring():
                return True
            root = self.state.get("root")
            if root == "battle":
                return False
            if root == "dialog":
                dialog = self.state.get("dialog") or {}
                if dialog.get("ready"):
                    self.press("a", wait=4)
                else:
                    self.send("wait 6")
            elif root == "oak":
                self.send("wait 25", "press a", max_frames=200)
            elif root == "naming":
                self.press("down", wait=2)
                if self.state.get("root") == "naming":
                    self.press("a", wait=6)
            elif root == "learning":
                learning = self.state.get("learning") or {}
                phase = learning.get("phase")
                if phase in (None, "message", "closed") or learning.get("dialog_ready"):
                    if learning.get("dialog_ready") or phase == "message":
                        self.press("a", wait=6)
                    else:
                        self.send("wait 6")
                else:
                    # YES learns. The second move is Tail Whip, the one Bubble replaces.
                    # The stop menu's second row returns to that question.
                    selected = learning.get("selected") or 1
                    target = {"ask": 1, "confirm": 1, "replace": 2, "stop": 2}.get(phase, 1)
                    if selected == target:
                        self.press("a", wait=6)
                    else:
                        self.press("down" if target > selected else "up", wait=2)
            elif root == "tutorial-escort":
                # The hurry menu opens on YES. A during the catch demo is ignored
                # until the old man has already caught the Weedle.
                self.press("a", wait=8)
            elif root == "event":
                self.press("a", wait=6)
            elif root == "title":
                return False
            else:
                self.send("wait 8")
        raise RuntimeError(f"overlay did not clear: {summary(self.state)}")

    def skip_intro(self):
        # Copyright (180) and the black bars (64) ignore A. The shooting star
        # accepts A as skip-to-fight, and the fight accepts A as finish.
        # pret/pokered engine/movie/intro.asm PlayIntroScene. A short wait
        # plus A keeps the movie moving; one long wait sits on the copyright.
        text = (ROOT / "Source/game/introMovie.lua").read_text(encoding="utf-8")
        frames = intro_movie_frames(text)
        covered = 0
        while covered <= frames:
            if self.state.get("root") not in (None, "", "title"):
                return
            phase = (self.state.get("title") or {}).get("phase")
            if phase != "intro":
                return
            self.send(f"wait {INTRO_STEP_WAIT}", timeout=60, max_frames=40)
            covered += INTRO_STEP_WAIT
            phase = (self.state.get("title") or {}).get("phase")
            if phase != "intro":
                return
            self.press("a", wait=1)
            covered += 2
        if (self.state.get("title") or {}).get("phase") == "intro":
            raise RuntimeError("intro did not finish: " + json.dumps(summary(self.state)))

    def leave_title(self):
        if not self.state.get("root"):
            self.send("wait 1")
        self.skip_intro()
        for _ in range(40):
            root = self.state.get("root")
            if root and root != "title":
                return
            phase = (self.state.get("title") or {}).get("phase")
            if phase == "intro":
                self.skip_intro()
            elif phase in ("preparing", "closed", None):
                self.send("wait 30", timeout=180, max_frames=800)
            elif phase == "title":
                self.press("a", wait=25)
            elif phase == "menu":
                self.send("wait 25", max_frames=200)
                action = title_action(self.menu("title").get("options") or [])
                if action is None:
                    self.send("wait 20")
                    continue
                self.choose("title", action)
            elif phase == "continue-info":
                # TitleIdle.CONTINUE_DELAY is 30. A before that is ignored.
                self.send("wait 35", max_frames=80)
                self.press("a", wait=20, timeout=180)
            elif phase == "confirm-new":
                self.send("wait 8")
                self.choose("title", "YES")
            else:
                self.send("wait 10")
        raise RuntimeError(f"title did not start the game: {summary(self.state)}")

    def follow(self, open_cells, goal, avoid):
        blocked = set(avoid)
        for _ in range(12):
            if not self.exploring():
                return "overlay"
            cell = (self.state["player"]["x"], self.state["player"]["y"])
            if cell == goal:
                return "arrived"
            steps = route(open_cells, cell, goal, blocked)
            if not steps:
                return "no-route"
            for direction in steps:
                kind = self.step(direction)
                if kind in ("overlay", "warp"):
                    return kind
                if kind == "blocked":
                    blocked.add(neighbor(cell, direction))
                    break
                cell = (self.state["player"]["x"], self.state["player"]["y"])
            else:
                if cell == goal:
                    return "arrived"
        return "lost"

    def run_away(self, limit=80):
        for _ in range(limit):
            if self.state.get("root") != "battle":
                return True
            battle = self.state.get("battle") or {}
            phase = battle.get("phase")
            if phase == "ended":
                self.send("wait 12", "press a", max_frames=200)
            elif phase == "script":
                if battle.get("waiting"):
                    self.send("wait 12", "press a", max_frames=200)
                else:
                    self.send("wait 2")
            elif phase == "command":
                if battle.get("inMoveSelect"):
                    self.press("b", wait=4)
                else:
                    options = (battle.get("menu") or {}).get("options") or []
                    if "RUN" not in options:
                        return False
                    self.choose("battle", "RUN")
            else:
                self.send("wait 4")
        return self.state.get("root") != "battle"

    def travel(self, open_cells, goal, avoid, limit=12):
        started = self.state.get("zone")
        for _ in range(limit):
            if started and self.state.get("zone") != started:
                return "warp"
            kind = self.follow(open_cells, goal, avoid)
            if kind != "overlay":
                return kind
            root = self.state.get("root")
            if root == "battle":
                trainer = (self.state.get("battle") or {}).get("trainerName")
                if trainer:
                    self.fight()
                elif not self.run_away():
                    self.fight()
                self.dismiss_until_explore(limit=30)
                continue
            if root in ("dialog", "learning", "oak", "naming", "tutorial-escort", "event"):
                self.dismiss_until_explore(limit=40)
                continue
            return kind
        return "lost"

    def fight(self, limit=700):
        won = None
        for _ in range(limit):
            root = self.state.get("root")
            if root == "learning":
                if not self.dismiss_until_explore(limit=8) and self.state.get("root") == "battle":
                    continue
                if self.state.get("root") != "battle":
                    break
            if root != "battle":
                break
            battle = self.state.get("battle") or {}
            phase = battle.get("phase")
            if phase == "ended":
                enemy = (battle.get("enemy") or {}).get("hp")
                player = (battle.get("player") or {}).get("hp")
                if enemy is not None and player is not None:
                    won = enemy <= 0 and player > 0
                self.send("wait 20", "press a", max_frames=200)
            elif phase == "script":
                if not battle.get("waiting"):
                    self.send("wait 2")
                else:
                    self.send("wait 18", "press a", max_frames=200)
            elif phase == "command":
                if not battle.get("inMoveSelect"):
                    self.choose("battle", "FIGHT")
                else:
                    move_menu = battle.get("moveMenu") or {}
                    index, _name = preferred_move(move_menu.get("options"))
                    selected = move_menu.get("selected") or 1
                    if index and selected != index:
                        self.press("down" if index > selected else "up", wait=2)
                    else:
                        self.press("a", wait=4)
            else:
                self.send("wait 4")
        return won

    def pause_save(self):
        if not self.exploring():
            return False
        self.press("b", wait=10)
        if self.state.get("root") != "pause":
            return False
        self.choose("pause", "SAVE")
        if self.state.get("root") != "pause":
            return False
        self.choose("pause", "YES")
        self.dismiss_until_explore(limit=20)
        return self.exploring()


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


class LcdRecorder:
    """Grab the 400x240 LCD from the Simulator window and write a gray mp4."""

    WINDOW = (486, 700)
    LCD = (400, 240)
    OFFSET = (18, 45)

    def __init__(self, display):
        self.display = display
        self.process = None
        self.raw = None
        self.started = None

    def _window(self):
        env = {"DISPLAY": self.display, "PATH": os.environ.get("PATH", "")}
        found = subprocess.run(
            ["xdotool", "search", "--onlyvisible", "--name", "^Playdate Simulator$"],
            check=False, text=True, capture_output=True, env={**os.environ, **env},
        )
        window_id = next((line.strip() for line in found.stdout.splitlines() if line.strip()), None)
        if not window_id:
            raise RuntimeError("Playdate Simulator window is not open")
        info = subprocess.run(["xwininfo", "-id", window_id], check=True, text=True, capture_output=True,
                              env={**os.environ, **env})
        values = {}
        for line in info.stdout.splitlines():
            for key in ("Absolute upper-left X", "Absolute upper-left Y", "Width", "Height"):
                if line.strip().startswith(key + ":"):
                    values[key] = int(line.split()[-1])
        width, height = values["Width"], values["Height"]
        if (width, height) != self.WINDOW:
            raise RuntimeError(f"simulator window is {width}x{height}")
        return values["Absolute upper-left X"] + self.OFFSET[0], values["Absolute upper-left Y"] + self.OFFSET[1]

    def start(self, raw_path):
        import time
        origin = self._window()
        raw_path.parent.mkdir(parents=True, exist_ok=True)
        self.raw = Path(raw_path)
        self.started = time.monotonic()
        self.process = subprocess.Popen([
            "ffmpeg", "-y", "-loglevel", "error", "-f", "x11grab",
            "-video_size", "400x240", "-framerate", "30",
            "-i", f"{self.display}.0+{origin[0]},{origin[1]}",
            "-an", "-c:v", "ffv1", str(self.raw),
        ], env={**os.environ, "DISPLAY": self.display})

    def elapsed(self):
        import time
        if self.started is None:
            return 0
        return time.monotonic() - self.started

    def stop(self, destination):
        if self.process is None:
            return None
        self.process.terminate()
        try:
            self.process.wait(timeout=8)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait(timeout=5)
        self.process = None
        if not self.raw or not self.raw.exists() or self.raw.stat().st_size == 0:
            return None
        destination = Path(destination)
        destination.parent.mkdir(parents=True, exist_ok=True)
        subprocess.check_call(lossless_gray_argv(self.raw, destination))
        probe = subprocess.check_output([
            "ffprobe", "-v", "error", "-show_entries", "format=duration",
            "-of", "csv=p=0", str(destination),
        ], text=True).strip()
        return float(probe)



def play_story(player, report, display, clips, output):
    import time
    player.leave_title()
    if not player.exploring():
        player.dismiss_until_explore(limit=220)
    report["after_oak"] = summary(player.state)
    if not player.exploring():
        raise RuntimeError("new game did not reach the bedroom: " + json.dumps(summary(player.state)))
    bedroom = padded_open_cells("reds_house_2f")
    house = padded_open_cells("reds_house")
    pallet = padded_open_cells("pallet_town")
    lab = padded_open_cells("oaks_lab")
    kind = player.follow(bedroom, STAIR, set())
    report["stairs"] = {"kind": kind, **summary(player.state)}
    if kind == "warp" or player.state.get("zone") == "reds_house":
        player.settle()
    if player.state.get("zone") != "reds_house":
        raise RuntimeError("stairs did not reach Red's house: " + json.dumps(summary(player.state)))
    kind = player.follow(house, HOUSE_EXIT, {MOM})
    report["house_exit"] = {"kind": kind, **summary(player.state)}
    if kind != "arrived":
        raise RuntimeError("could not reach the house mat: " + json.dumps(summary(player.state)))
    player.press("down", wait=12)
    player.settle(limit=100)
    player.dismiss_until_explore(limit=20)
    report["outside"] = summary(player.state)
    if player.state.get("zone") != "pallet_town":
        raise RuntimeError("house door did not reach Pallet: " + json.dumps(summary(player.state)))
    here = (player.state["player"]["x"], player.state["player"]["y"])
    north = first_cell(pallet, here, lambda cell: cell[1] <= 2, avoid=PALLET_DOORS)
    if north is None:
        raise RuntimeError("no path to the Route 1 grass: " + json.dumps(summary(player.state)))
    kind = player.follow(pallet, north, set(PALLET_DOORS))
    report["oak_stop"] = {"kind": kind, **summary(player.state)}
    player.dismiss_until_explore(limit=160)
    report["lab"] = summary(player.state)
    if player.state.get("zone") not in ("kanto_oaks_lab", "oaks_lab"):
        raise RuntimeError("Oak did not enter the lab: " + json.dumps(summary(player.state)))
    kind = player.follow(lab, SQUIRTLE_FACE, set())
    report["ball"] = {"kind": kind, **summary(player.state)}
    if kind != "arrived":
        raise RuntimeError("could not face Squirtle: " + json.dumps(summary(player.state)))
    if player.state["player"].get("facing") != "up":
        player.press("up", wait=4)
    player.press("a", wait=8)
    player.dismiss_until_explore(limit=50)
    report["chosen"] = summary(player.state)
    if (player.state.get("story") or {}).get("starter") != "squirtle":
        raise RuntimeError("starter is not Squirtle: " + json.dumps(summary(player.state)))
    here = (player.state["player"]["x"], player.state["player"]["y"])
    south = first_cell(lab, here, lambda cell: cell[1] >= 8)
    if south is None:
        raise RuntimeError("no path to the rival: " + json.dumps(summary(player.state)))
    kind = player.follow(lab, south, set())
    report["rival_trigger"] = {"kind": kind, **summary(player.state)}
    if player.state.get("root") != "battle":
        player.dismiss_until_explore(limit=40)
    if player.state.get("root") != "battle":
        raise RuntimeError("rival battle did not start: " + json.dumps(summary(player.state)))
    recorder = LcdRecorder(display)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    raw = output / "clips" / "rival-lab.nut"
    slug = "rival-lab"
    destination = clip_path(clips, stamp, slug)
    duration = None
    won = None
    recorder.start(raw)
    try:
        won = player.fight()
    finally:
        try:
            duration = recorder.stop(destination)
        except Exception as error:
            report["clip_error"] = str(error)
    if won is False and destination.exists():
        loss = clip_path(clips, stamp, "rival-lab-loss")
        destination.replace(loss)
        destination = loss
    report["rival"] = {"won": won, "duration": duration, "clip": str(destination), **summary(player.state)}
    if destination.exists() and duration is not None and 20 <= duration <= 90:
        report["clips"].append({
            "path": str(destination.relative_to(ROOT)),
            "sha256": sha256_file(destination),
            "duration": duration,
            "won": won,
        })
    elif destination.exists() and duration is not None and duration > 90:
        trimmed = destination.with_name(destination.stem + "-tail.mp4")
        start = max(0, duration - 85)
        subprocess.check_call([
            "ffmpeg", "-y", "-loglevel", "error", "-ss", f"{start:.3f}", "-i", str(destination),
            "-t", "85", "-an", "-c:v", "libx264rgb", "-crf", "0", "-pix_fmt", "rgb24",
            str(trimmed),
        ])
        destination.unlink()
        trimmed.replace(destination)
        probe = subprocess.check_output([
            "ffprobe", "-v", "error", "-show_entries", "format=duration",
            "-of", "csv=p=0", str(destination),
        ], text=True).strip()
        report["clips"].append({
            "path": str(destination.relative_to(ROOT)),
            "sha256": sha256_file(destination),
            "duration": float(probe),
            "won": won,
            "trimmed_from": duration,
        })
    # Battle end returns to the overworld on the A press. Story.check fires
    # on a later explore frame, so one wait lets the goodbye dialog start.
    if (player.state.get("story") or {}).get("stage") == "goodbye":
        player.send("wait 6")
    player.dismiss_until_explore(limit=40)
    report["after_rival"] = summary(player.state)
    if (player.state.get("story") or {}).get("stage") != "done":
        raise RuntimeError("rival goodbye did not finish: " + json.dumps(summary(player.state)))
    if player.exploring():
        report["saved"] = player.pause_save()
        report["after_save"] = summary(player.state)
    kind = player.travel(lab, (6, 11), set())
    report["lab_mat"] = {"kind": kind, **summary(player.state)}
    if kind != "arrived":
        raise RuntimeError("could not reach the lab exit: " + json.dumps(summary(player.state)))
    player.press("down", wait=12)
    player.settle(limit=120)
    player.dismiss_until_explore(limit=20)
    report["pallet_again"] = summary(player.state)
    if "pallet" not in str(player.state.get("zone")):
        raise RuntimeError("lab exit did not reach Pallet: " + json.dumps(summary(player.state)))
    pallet_here = (player.state["player"]["x"], player.state["player"]["y"])
    north = first_cell(pallet, pallet_here, lambda cell: cell[1] == 0, avoid=PALLET_DOORS)
    if north is None:
        raise RuntimeError("no path to Route 1: " + json.dumps(summary(player.state)))
    kind = player.travel(pallet, north, set(PALLET_DOORS), limit=20)
    report["route1_gate"] = {"kind": kind, "goal": north, **summary(player.state)}
    if kind != "arrived":
        raise RuntimeError("could not reach the north edge: " + json.dumps(summary(player.state)))
    player.press("up", wait=12)
    player.settle(limit=120)
    player.dismiss_until_explore(limit=20)
    report["route1"] = summary(player.state)
    if "route" not in str(player.state.get("zone")):
        raise RuntimeError("Pallet north did not reach Route 1: " + json.dumps(summary(player.state)))
    route1 = route1_cells()
    route_here = (player.state["player"]["x"], player.state["player"]["y"])
    route_north = first_cell(route1, route_here, lambda cell: cell[1] == 0)
    if route_north is None:
        report["route1_blocked"] = summary(player.state)
        return
    kind = player.travel(route1, route_north, set(), limit=40)
    report["route1_north"] = {"kind": kind, "goal": route_north, **summary(player.state)}
    if kind == "arrived":
        player.press("up", wait=12)
        player.settle(limit=120)
        player.dismiss_until_explore(limit=20)
        report["after_route1"] = summary(player.state)
    if player.exploring():
        report["saved_route"] = player.pause_save()
        report["after_route_save"] = summary(player.state)


def parcel_count(state):
    quantities = (state.get("inventory") or {}).get("quantities") or {}
    return quantities.get("oaksParcel") or 0


def play_continue(player, report, display=None, clips=None, output=None):
    """Earned CONTINUE from Viridian. The mart clerk's entry script gives Oak's parcel."""
    player.leave_title()
    if not player.exploring():
        player.dismiss_until_explore(limit=80)
    report["continued"] = summary(player.state)
    if "viridian" not in str(player.state.get("zone")):
        raise RuntimeError("continue did not resume Viridian: " + json.dumps(summary(player.state)))
    if (player.state.get("story") or {}).get("starter") != "squirtle":
        raise RuntimeError("continued starter is not Squirtle: " + json.dumps(summary(player.state)))
    city = viridian_cells()
    kind = player.travel(city, VIRIDIAN_MART, set(VIRIDIAN_WARPS), limit=20)
    report["mart_door"] = {"kind": kind, **summary(player.state)}
    if "mart" not in str(player.state.get("zone")):
        if kind == "arrived":
            # A step door fires again when the player leaves the tile and returns.
            player.press("down", wait=12)
            player.settle()
            player.press("up", wait=12)
            player.settle(limit=120)
        player.dismiss_until_explore(limit=20)
    report["mart"] = summary(player.state)
    if "mart" not in str(player.state.get("zone")):
        raise RuntimeError("Viridian Mart door did not open: " + json.dumps(summary(player.state)))
    player.dismiss_until_explore(limit=80)
    # The entry program speaks, walks the player to the counter, and gives the parcel.
    for _ in range(8):
        if parcel_count(player.state) >= 1 and player.exploring():
            break
        if player.state.get("root") == "battle":
            raise RuntimeError("unexpected battle in the mart: " + json.dumps(summary(player.state)))
        player.dismiss_until_explore(limit=20)
        if not player.exploring():
            player.send("wait 8")
    report["parcel"] = parcel_count(player.state)
    report["after_parcel"] = summary(player.state)
    if parcel_count(player.state) < 1:
        raise RuntimeError("Oak's parcel was not received: " + json.dumps(summary(player.state)))
    if player.exploring():
        report["saved_parcel"] = player.pause_save()
        report["after_parcel_save"] = summary(player.state)


def play_deliver(player, report, display=None, clips=None, output=None):
    """Carry Oak's Parcel from the Mart back to Oak and film the Pokédex."""
    import time
    player.leave_title()
    if not player.exploring():
        player.dismiss_until_explore(limit=40)
    report["continued"] = summary(player.state)
    if "mart" not in str(player.state.get("zone")):
        raise RuntimeError("continue did not resume the Mart: " + json.dumps(summary(player.state)))
    if parcel_count(player.state) < 1:
        raise RuntimeError("the Mart save has no parcel: " + json.dumps(summary(player.state)))
    kind = player.travel(mart_cells(), (6, 7), set())
    report["mart_exit"] = {"kind": kind, **summary(player.state)}
    if kind != "arrived":
        raise RuntimeError("could not reach the Mart mat: " + json.dumps(summary(player.state)))
    player.press("down", wait=12)
    player.settle(limit=120)
    player.dismiss_until_explore(limit=20)
    report["outside_mart"] = summary(player.state)
    if "viridian_city" not in str(player.state.get("zone")):
        raise RuntimeError("Mart door did not return to Viridian: " + json.dumps(summary(player.state)))
    city = viridian_cells()
    here = (player.state["player"]["x"], player.state["player"]["y"])
    kind = player.travel(city, VIRIDIAN_SOUTH, set(VIRIDIAN_WARPS), limit=20)
    report["south_gate"] = {"kind": kind, **summary(player.state)}
    if kind != "arrived":
        raise RuntimeError("could not reach Viridian's south edge: " + json.dumps(summary(player.state)))
    player.press("down", wait=12)
    player.settle(limit=120)
    player.dismiss_until_explore(limit=20)
    report["route1_return"] = summary(player.state)
    if "route" not in str(player.state.get("zone")):
        raise RuntimeError("Viridian south did not reach Route 1: " + json.dumps(summary(player.state)))
    route1 = route1_cells()
    here = (player.state["player"]["x"], player.state["player"]["y"])
    south = first_cell(route1, here, lambda cell: cell[1] == 35 and cell[0] == 10)
    if south is None:
        south = first_cell(route1, here, lambda cell: cell[1] == 35)
    kind = player.travel(route1, south, set(), limit=40)
    report["route1_south"] = {"kind": kind, "goal": south, **summary(player.state)}
    if kind != "arrived":
        raise RuntimeError("could not reach Route 1's south edge: " + json.dumps(summary(player.state)))
    player.press("down", wait=12)
    player.settle(limit=120)
    player.dismiss_until_explore(limit=20)
    report["pallet_return"] = summary(player.state)
    if "pallet" not in str(player.state.get("zone")):
        raise RuntimeError("Route 1 did not reach Pallet: " + json.dumps(summary(player.state)))
    pallet = padded_open_cells("pallet_town")
    here = (player.state["player"]["x"], player.state["player"]["y"])
    kind = player.travel(pallet, (12, 11), {(5, 5), (13, 5)}, limit=20)
    report["lab_door"] = {"kind": kind, **summary(player.state)}
    if "lab" not in str(player.state.get("zone")) and kind == "arrived":
        player.press("up", wait=12)
        player.settle(limit=120)
    player.dismiss_until_explore(limit=30)
    report["lab_return"] = summary(player.state)
    if "lab" not in str(player.state.get("zone")):
        raise RuntimeError("Pallet did not enter the lab: " + json.dumps(summary(player.state)))
    lab = padded_open_cells("oaks_lab")
    kind = player.travel(lab, (6, 3), set(), limit=15)
    report["oak"] = {"kind": kind, **summary(player.state)}
    recorder = LcdRecorder(display) if display and clips and output else None
    destination = None
    duration = None
    if recorder:
        stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
        destination = clip_path(clips, stamp, "pokedex-lab")
        recorder.start(output / "clips" / "pokedex-lab.nut")
    try:
        if player.state["player"].get("facing") != "up":
            player.press("up", wait=4)
        player.press("a", wait=8)
        # The handoff, the rival's walk, and the Pokédex pages are one scene.
        player.dismiss_until_explore(limit=180)
    finally:
        if recorder is not None and recorder.process is not None:
            try:
                duration = recorder.stop(destination)
            except Exception as error:
                report["clip_error"] = str(error)
    if destination is not None:
        publish_clip(report, destination, duration, keep="start")
        report["pokedex_clip"] = {"path": str(destination), "duration": duration}
    report["after_oak"] = summary(player.state)
    report["parcel_left"] = parcel_count(player.state)
    if parcel_count(player.state) >= 1:
        raise RuntimeError("Oak did not take the parcel: " + json.dumps(summary(player.state)))
    if player.exploring():
        report["saved_oak"] = player.pause_save()
        report["after_oak_save"] = summary(player.state)


def film(display, clips, output, slug, report, keep, action):
    import time
    recorder = LcdRecorder(display)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    destination = clip_path(clips, stamp, slug)
    recorder.start(output / "clips" / f"{slug}.nut")
    try:
        return action()
    finally:
        duration = None
        if recorder.process is not None:
            try:
                duration = recorder.stop(destination)
            except Exception as error:
                report["clip_error"] = str(error)
        publish_clip(report, destination, duration, keep=keep)
        report[slug] = {"path": str(destination), "duration": duration}


def npc_named(state, event_id):
    for npc in state.get("npcs") or []:
        if npc.get("source_event_id") == event_id:
            return npc
    return None


def step_onto(player, cells, goal, avoid, direction):
    """Walk to the cell before goal, then take one step onto it."""
    dx, dy = DELTAS[direction]
    before = (goal[0] - dx, goal[1] - dy)
    started = player.state.get("zone")
    kind = player.travel(cells, before, avoid)
    if player.state.get("zone") != started:
        return "warp"
    if kind != "arrived":
        return kind
    kind = player.step(direction)
    if player.state.get("zone") != started:
        return "warp"
    here = (player.state["player"]["x"], player.state["player"]["y"])
    if here == goal:
        player.step(direction)
        player.settle(limit=80)
        if player.state.get("root") not in (None, "overworld"):
            player.dismiss_until_explore(limit=20)
        if player.state.get("zone") != started:
            return "warp"
    return kind


def leave_map(player, cells, cell, avoid, direction):
    """Stand on an edge cell and walk off the map."""
    started = player.state.get("zone")
    kind = player.travel(cells, cell, avoid)
    if player.state.get("zone") != started:
        return "warp"
    if kind != "arrived":
        return kind
    player.step(direction)
    player.settle(limit=80)
    if player.state.get("root") not in (None, "overworld"):
        player.dismiss_until_explore(limit=30)
    if player.state.get("zone") != started:
        return "warp"
    return "stayed"


def talk_to(player, cells, event_id, avoid):
    blocked = set(avoid)
    for _ in range(8):
        if not player.exploring():
            player.dismiss_until_explore(limit=40)
        npc = npc_named(player.state, event_id)
        if npc is None:
            return "missing"
        here = (player.state["player"]["x"], player.state["player"]["y"])
        spots = []
        for direction, (dx, dy) in DELTAS.items():
            spot = (npc["x"] - dx, npc["y"] - dy)
            if spot in cells and spot not in blocked and spot != (npc["x"], npc["y"]):
                spots.append((abs(spot[0] - here[0]) + abs(spot[1] - here[1]), spot, direction))
        if not spots:
            player.send("wait 10")
            continue
        _distance, spot, direction = min(spots)
        kind = player.travel(cells, spot, blocked | {(npc["x"], npc["y"])})
        if kind == "warp":
            return "warp"
        if not player.exploring():
            continue
        if (player.state["player"]["x"], player.state["player"]["y"]) != spot:
            continue
        if player.state["player"].get("facing") != direction:
            player.press(direction, wait=4)
        player.press("a", wait=8)
        if not player.exploring():
            player.dismiss_until_explore(limit=100)
            return "talked"
    return "silent"


def play_to_brock(player, report, display=None, clips=None, output=None):
    """Lab save to the Boulder Badge. Route 1 and Brock are filmed."""
    player.leave_title()
    if not player.exploring():
        player.dismiss_until_explore(limit=40)
    report["continued"] = summary(player.state)
    if player.state.get("zone") != "oaks_lab":
        raise RuntimeError("continue did not resume the lab: " + json.dumps(summary(player.state)))
    lab = padded_open_cells("oaks_lab")
    kind = leave_map(player, lab, (6, 11), set(), "down")
    report["lab_exit"] = {"kind": kind, **summary(player.state)}
    if player.state.get("zone") != "pallet_town":
        player.settle(limit=80)
        player.dismiss_until_explore(limit=20)
    if player.state.get("zone") != "pallet_town":
        raise RuntimeError("lab door did not reach Pallet: " + json.dumps(summary(player.state)))
    pallet = padded_open_cells("pallet_town")
    # maps.lua opens (9, 0) at runtime. The source grid leaves that seam solid.
    pallet.add((9, 0))
    kind = player.travel(pallet, (9, 0), {(5, 5), (13, 5), (12, 11)})
    report["pallet_north"] = {"kind": kind, **summary(player.state)}
    if kind != "arrived":
        raise RuntimeError("could not reach Pallet's north seam: " + json.dumps(summary(player.state)))

    def walk_route1():
        player.press("up", wait=12)
        player.settle(limit=80)
        player.dismiss_until_explore(limit=20)
        report["route1_enter"] = summary(player.state)
        if "route1" not in str(player.state.get("zone")):
            raise RuntimeError("Pallet north did not reach Route 1: " + json.dumps(summary(player.state)))
        route1 = route1_cells()
        here = (player.state["player"]["x"], player.state["player"]["y"])
        kind = player.travel(route1, (11, 0), set(), limit=30)
        report["route1_north"] = {"kind": kind, **summary(player.state)}
        if kind != "arrived":
            raise RuntimeError("could not cross Route 1: " + json.dumps(summary(player.state)))
        stepped = player.step("up")
        player.settle(limit=80)
        player.dismiss_until_explore(limit=20)
        report["viridian_enter"] = {"kind": stepped, **summary(player.state)}
        if "viridian_city" not in str(player.state.get("zone")):
            raise RuntimeError("Route 1 did not reach Viridian: " + json.dumps(summary(player.state)))

    if display and clips and output:
        film(display, clips, output, "route1", report, "start", walk_route1)
    else:
        walk_route1()
    if player.exploring():
        report["saved_viridian"] = player.pause_save()

    city = viridian_cells()
    talked = talk_to(player, city, OLD_MAN, set(VIRIDIAN_WARPS))
    report["old_man"] = {"result": talked, **summary(player.state)}
    if talked != "talked":
        raise RuntimeError("the old man did not open the north road: " + json.dumps(summary(player.state)))
    if player.exploring():
        report["saved_old_man"] = player.pause_save()
    kind = leave_map(player, city, (18, 0), set(VIRIDIAN_WARPS), "up")
    report["route2_enter"] = {"kind": kind, **summary(player.state)}
    if "route2" not in str(player.state.get("zone")):
        raise RuntimeError("Viridian north did not reach Route 2: " + json.dumps(summary(player.state)))
    route2 = route2_cells()
    route2_avoid = {(12, 9), (15, 19), (16, 35), (15, 39), (3, 11)}
    kind = step_onto(player, route2, (3, 43), route2_avoid, "up")
    report["forest_gate"] = {"kind": kind, **summary(player.state)}
    if "forest_south" not in str(player.state.get("zone")) and "south_gate" not in str(player.state.get("zone")):
        raise RuntimeError("Route 2 did not enter the forest gate: " + json.dumps(summary(player.state)))
    south = forest_south_cells()
    kind = step_onto(player, south, (6, 0), set(), "up")
    report["forest_enter"] = {"kind": kind, **summary(player.state)}
    if player.state.get("zone") != "kanto_viridian_forest":
        raise RuntimeError("the south gate did not enter the forest: " + json.dumps(summary(player.state)))
    forest = forest_cells()
    kind = step_onto(player, forest, (1, 0), set(), "up")
    report["forest_north"] = {"kind": kind, **summary(player.state)}
    if "north_gate" not in str(player.state.get("zone")):
        raise RuntimeError("the forest did not reach its north gate: " + json.dumps(summary(player.state)))
    north = forest_north_cells()
    kind = step_onto(player, north, (6, 0), set(), "up")
    report["route2_north"] = {"kind": kind, **summary(player.state)}
    if not str(player.state.get("zone")).endswith("route2") and "route2" not in str(player.state.get("zone")):
        raise RuntimeError("the north gate did not return to Route 2: " + json.dumps(summary(player.state)))
    kind = leave_map(player, route2, (8, 0), {(12, 9), (3, 11)}, "up")
    report["pewter_enter"] = {"kind": kind, **summary(player.state)}
    if "pewter_city" not in str(player.state.get("zone")):
        raise RuntimeError("Route 2 did not reach Pewter: " + json.dumps(summary(player.state)))
    if player.exploring():
        report["saved_pewter"] = player.pause_save()
    hp = (player.state.get("pokemon") or {}).get("hp") or 0
    if hp < 15:
        pewter = pewter_cells()
        kind = step_onto(player, pewter, (13, 25), set(), "up")
        report["center"] = {"kind": kind, **summary(player.state)}
        if "center" in str(player.state.get("zone")):
            talk_to(player, center_cells(), "pokered:PEWTER_POKECENTER:objects:1", set())
            report["healed"] = summary(player.state)
            step_onto(player, center_cells(), (3, 7), set(), "down")
    pewter = pewter_cells()
    gym_avoid = {(14, 7), (19, 5), (29, 13), (23, 17), (7, 29), (13, 25)}
    kind = step_onto(player, pewter, (16, 17), gym_avoid, "up")
    report["gym_door"] = {"kind": kind, **summary(player.state)}
    if "gym" not in str(player.state.get("zone")):
        raise RuntimeError("Pewter did not enter the gym: " + json.dumps(summary(player.state)))
    gym = gym_cells()

    def battle_brock():
        talked = talk_to(player, gym, BROCK, set())
        report["brock_talk"] = {"result": talked, **summary(player.state)}
        if player.state.get("root") == "battle" or talked == "talked":
            if player.state.get("root") != "battle":
                player.dismiss_until_explore(limit=20)
            if player.state.get("root") == "battle":
                report["brock_won"] = player.fight(limit=900)
        else:
            raise RuntimeError("Brock did not battle: " + json.dumps(summary(player.state)))
        player.dismiss_until_explore(limit=120)
        report["after_brock"] = summary(player.state)

    if display and clips and output:
        film(display, clips, output, "gym-pewter", report, "end", battle_brock)
    else:
        battle_brock()
    outcome = player.state.get("last_battle_outcome") or {}
    report["brock_outcome"] = outcome
    quantities = (player.state.get("inventory") or {}).get("quantities") or {}
    report["tm34"] = quantities.get("tm34") or 0
    if outcome.get("won") is not True:
        raise RuntimeError("Brock was not won: " + json.dumps(summary(player.state)))
    if player.exploring():
        report["saved_badge"] = player.pause_save()


def play(output, clips, save_from=None, story=None):
    import sys
    import uuid
    if str(ROOT) not in sys.path:
        sys.path.insert(0, str(ROOT))
    from tools.harness.protocol import Client, OwnerLock
    from tools.harness import run as harness

    display = os.environ.setdefault("DISPLAY", ":99")
    os.environ["PLAYDATE_SDK_PATH"] = str(Path.home() / "Developer/PlaydateSDK")
    sdk = harness.sdk_path()
    session = uuid.uuid4().hex
    output.mkdir(parents=True, exist_ok=False)
    metadata = harness.prepare(harness.PROJECT, sdk, output, session, journey=True)
    data = Path(metadata["data_dir"])
    data.mkdir(parents=True, exist_ok=False)
    if save_from is not None:
        copied = []
        for src in sorted(Path(save_from).glob("adventure*.json")):
            dest = data / src.name
            shutil.copyfile(src, dest)
            copied.append({"name": src.name, "sha256": sha256_file(dest)})
        if not copied:
            raise RuntimeError(f"no earned save in {save_from}")
        report_copied = copied
    else:
        report_copied = []
    report = {"session": session, "build": metadata.get("build_id"), "clips": [], "save_copied": report_copied}
    process = None
    owner_runtime = OwnerLock(harness.runtime_lock_path(sdk))
    owner_device = OwnerLock(harness.device_lock_path())
    owner_runtime.__enter__()
    owner_device.__enter__()
    client = None
    try:
        harness.simulator_preflight()
        with (output / "player.jsonl").open("w", encoding="utf-8") as log, (output / "simulator.log").open("w") as sim_log:
            process = subprocess.Popen(
                [metadata["simulator"], metadata["bundle"]],
                stdout=sim_log, stderr=subprocess.STDOUT,
                env={**os.environ, "DISPLAY": display},
            )
            client = Client(data, metadata["build_id"], session, output)
            client.ready(180)
            player = Player(client, log)
            try:
                if story is None:
                    play_story(player, report, display, clips, output)
                else:
                    story(player, report, display, clips, output)
            except Exception as error:
                report["error"] = str(error)
                report["last"] = summary(player.state)
                raise
            finally:
                kept = Path("/opt/cursor/artifacts/lane-j/saves") / session[:12]
                kept.mkdir(parents=True, exist_ok=True)
                files = []
                for src in sorted(data.glob("adventure*.json")):
                    dest = kept / src.name
                    shutil.copyfile(src, dest)
                    files.append({"name": src.name, "sha256": sha256_file(dest)})
                report["save_kept"] = {"dir": str(kept), "files": files}
                (output / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
                print(json.dumps(report, indent=2))
        return 0 if "error" not in report else 1
    finally:
        if client is not None:
            client.close()
        if process is not None and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
        owner_device.__exit__(None, None, None)
        owner_runtime.__exit__(None, None, None)


if __name__ == "__main__":
    import sys
    if "--play" not in sys.argv:
        unittest.main()
    else:
        clips = ROOT / "artifacts" / "lane-j"
        if "--north" in sys.argv:
            output = Path("/tmp/lane-j-squirtle-8")
            save_from = LAB_SAVE
            digest = sha256_file(save_from / "adventure.a.json")
            if digest != LAB_SAVE_SHA:
                raise SystemExit(f"lab save hash {digest}")
            if output.exists():
                raise SystemExit(f"{output} already exists")
            raise SystemExit(play(output, clips, save_from=save_from, story=play_to_brock))
        if "--deliver" in sys.argv:
            output = Path("/tmp/lane-j-squirtle-6")
            save_from = MART_SAVE
            digest = sha256_file(save_from / "adventure.b.json")
            if digest != MART_SAVE_SHA:
                raise SystemExit(f"mart save hash {digest}")
            if output.exists():
                raise SystemExit(f"{output} already exists")
            raise SystemExit(play(output, clips, save_from=save_from, story=play_deliver))
        if "--continue" in sys.argv:
            output = Path("/tmp/lane-j-squirtle-3")
            save_from = Path.home() / "Developer/PlaydateSDK/Disk/Data/com.poc.pokemon.harness.3548dbef55f74fdd867104123d77c2df"
            if output.exists():
                raise SystemExit(f"{output} already exists")
            raise SystemExit(play(output, clips, save_from=save_from, story=play_continue))
        output = Path("/tmp/lane-j-squirtle-2")
        if output.exists():
            raise SystemExit(f"{output} already exists")
        raise SystemExit(play(output, clips))
