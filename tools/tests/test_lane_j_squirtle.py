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
from collections import deque
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
VIRIDIAN_SAVE = Path("/opt/cursor/artifacts/lane-j/saves/00f0664cc5b5")
VIRIDIAN_SAVE_SHA = "56f56cb938174c80ffc7465e41c75d83c76e7fbb1c311e7b0e64231638917122"
PEWTER_SAVE = Path("/opt/cursor/artifacts/lane-j/saves/d03e3f4459d1")
PEWTER_SAVE_SHA = "d8c3b1e1fa226fe42174ab076467d39a6bd21aa8505fae9df87d4f00e6488217"
BADGE_SAVE = Path("/opt/cursor/artifacts/lane-j/saves/a6328d508ccc")
BADGE_SAVE_SHA = "fca4f05f2567bd621c35b195f24c0f7db80655b09b67409d282e3e4550a1b05b"
ROUTE4_SAVE = Path("/opt/cursor/artifacts/lane-j/saves/ae6ff5c3ae0d")
ROUTE4_SAVE_SHA = "362f03f4ab81c87ca6421b4d419090fb17e557a79e3d27146398fc9f872772d9"
FOSSIL_SAVE = Path("/opt/cursor/artifacts/lane-j/saves/c964b798257f")
FOSSIL_SAVE_SHA = "d7c9172de14d727711569feeb8d1b5eac274d43f03223898d55afbcbdd47d2f4"
CLIFF_SAVE = Path("/opt/cursor/artifacts/lane-j/saves/5a428a2c98f5")
CLIFF_SAVE_SHA = "9f3237a35d79f667b80884f3b0711356450817f5f068e67611f02ffdd29e2a14"
POTION_SAVE = Path("/opt/cursor/artifacts/lane-j/saves/0c3f08774f1b")
POTION_SAVE_SHA = "eba0696ff186ffcf8beb0b9ffbd1e831f1d82949f67da036e0e1256b37d04354"
EIGHT_SAVE = Path("/opt/cursor/artifacts/lane-j/saves/e0f8ae50d17a")
EIGHT_SAVE_SHA = "9607c06671633cbcec45150d316937419197ae6741219eb202da39c8f00c4f9b"
BRIDGE_SAVE = Path("/opt/cursor/artifacts/lane-j/saves/f420d9c1884d")
BRIDGE_SAVE_SHA = "f0b12cacc9f2d7f7af0af17edfb5e09d6b2ac2fb34ee4e30a65087d526b8d8f2"
GYM_SAVE = Path("/opt/cursor/artifacts/lane-j/saves/gym-l22-seq15")
GYM_SAVE_SHA = "493a71e0b74dc71fd65041e92c5c6c6fdb9f2639f5375b1fd1ab3f3f5646837e"
CASCADE_SAVE = Path("/opt/cursor/artifacts/lane-j/saves/ef2bcb5caf63")
CASCADE_SAVE_SHA = "2ea6168fe10764c79740c173394672c21022f67591dbcc7de114570e696b7625"
TICKET_SAVE = Path("/opt/cursor/artifacts/lane-j/saves/191a86b9e4ed")
TICKET_SAVE_SHA = "1363fe0f4563c44e931da1db5199022186790131dd7cd45f5cf87830838ae4ad"
VERMILION_SAVE = Path("/opt/cursor/artifacts/lane-j/saves/de26045b6d06")
VERMILION_SAVE_SHA = "51ade10899094ca5582d70e13e6664bb0fe9adff6b95c19036ed86770c32a4e3"
# Route 6 grass after Bellsprout and Pidgey. Sequence 20. adventure.a is still sequence 19.
CATCH_SAVE = Path("/opt/cursor/artifacts/lane-j/saves/route6-l15")
CATCH_SAVE_SHA = "8a84abab8e13556594eb6b53b06dab8c59b4aa87f8b5b51fa83e1865924d0671"
# Overwritten as the bird levels. The loader prefers it over the L15 catch.
BIRD_SAVE = Path("/opt/cursor/artifacts/lane-j/saves/route6-bird")
MISTY = "pokered:CERULEAN_GYM:objects:1"
BILL_POKEMON = "pokered:BILLS_HOUSE:objects:1"
BILL = "pokered:BILLS_HOUSE:objects:2"
CERULEAN_NURSE = "pokered:CERULEAN_POKECENTER:objects:1"
VERMILION_NURSE = "pokered:VERMILION_POKECENTER:objects:1"
OLD_MAN = "pokered:VIRIDIAN_CITY:objects:7"
BROCK = "pokered:PEWTER_GYM:objects:1"


def disabled_move(message, options):
    """The move named by 'X was disabled'. A leftover page must not reject the cursor."""
    folded = "".join(ch for ch in str(message or "").upper() if ch.isalpha())
    disabled = "WASDISABLED" in folded or "ISDISABLED" in folded
    if not disabled or "NOLONGERDISABLED" in folded:
        return None
    for name in options or ():
        letters = "".join(ch for ch in str(name).upper() if ch.isalpha())
        if letters and letters not in {"DASH"} and letters in folded:
            return name
    return None


def preferred_move(options, skip=(), enemy_types=()):
    """Water Gun, then Bubble, then Bite. Bite leads when Water is resisted."""
    named = []
    skipped = set()
    for name in skip or ():
        skipped.add("".join(ch for ch in str(name).upper() if ch.isalpha()))
    for index, name in enumerate(options or [], start=1):
        letters = "".join(ch for ch in str(name).upper() if ch.isalpha())
        if letters in {"", "DASH"} or str(name).strip() in {"", "-"} or letters in skipped:
            continue
        named.append((index, name, letters))
    types = {str(kind).lower() for kind in (enemy_types or ()) if kind}
    resisted = "water" in types or "grass" in types
    order = ("BITE", "TACKLE", "WATERGUN", "BUBBLE") if resisted else ("WATERGUN", "BUBBLE", "BITE", "TACKLE")
    for want in order:
        for index, name, letters in named:
            if letters == want:
                return index, name
    if named:
        return named[0][0], named[0][1]
    return None, None


def forget_index(learning):
    """Replace Tail Whip, then Withdraw, then Bubble. Keep Water Gun."""
    order = ["tailWhip", "growl", "withdraw", "bubble", "tackle"]
    by_key = {move.get("key"): move.get("index") for move in (learning.get("known_moves") or [])}
    for key in order:
        if key in by_key:
            return by_key[key]
    return 4


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


def route3_cells():
    return open_map(ROOT / "Source/data/sourceSlice/Route3.json", 0, 70)


def route4_cells():
    return open_map(ROOT / "Source/data/sourceSlice/Route4.json", 0, 90)


def moon_cells():
    return open_map(ROOT / "Source/data/sourceSlice/MtMoon1F.json", 0, 40)


def moon_b1_cells():
    return open_map(ROOT / "Source/data/sourceSlice/MtMoonB1F.json", 0, 28)


def moon_b2_cells():
    return open_map(ROOT / "Source/data/sourceSlice/MtMoonB2F.json", 0, 40)


def moon_center_cells():
    return open_map(ROOT / "Source/data/sourceSlice/MtMoonPokecenter.json", 0, 14)


def cerulean_cells():
    return open_map(ROOT / "Source/data/sourceSlice/CeruleanCity.json", 0, 40)


EAST = ROOT / "Source/data/midgameEast"
SOUTH = ROOT / "Source/data/midgameSouth"


def route9_cells():
    return open_map(EAST / "Route9.json", 0, 60)


def route10_cells():
    return open_map(EAST / "Route10.json", 0, 20)


def rock_tunnel_1f_cells():
    return open_map(EAST / "RockTunnel1F.json", 0, 40)


def rock_tunnel_b1_cells():
    return open_map(EAST / "RockTunnelB1F.json", 0, 40)


def rock_tunnel_center_cells():
    return open_map(EAST / "RockTunnelPokecenter.json", 0, 14)


def lavender_cells():
    return open_map(EAST / "LavenderTown.json", 0, 20)


def route8_cells():
    return open_map(EAST / "Route8.json", 0, 60)


def route7_cells():
    return open_map(EAST / "Route7.json", 0, 20)


def underground_route8_cells():
    return open_map(EAST / "UndergroundPathRoute8.json", 2, 13)


def underground_we_cells():
    return open_map(EAST / "UndergroundPathWestEast.json", 0, 50)


def underground_route7_cells():
    return open_map(EAST / "UndergroundPathRoute7.json", 2, 13)


def celadon_cells():
    return open_map(EAST / "CeladonCity.json", 0, 50)


def celadon_mart_cells(floor):
    return open_map(EAST / f"CeladonMart{floor}F.json", 0, 20)


def celadon_gym_cells():
    return open_map(EAST / "CeladonGym.json", 1, 13)


def cerulean_gym_cells():
    return open_map(ROOT / "Source/data/sourceSlice/CeruleanGym.json", 1, 13)


def cerulean_center_cells():
    return open_map(ROOT / "Source/data/sourceSlice/CeruleanPokecenter.json", 0, 14)


def cerulean_mart_cells():
    return open_map(ROOT / "Source/data/sourceSlice/CeruleanMart.json", 2, 13)


def route24_cells():
    return open_map(ROOT / "Source/data/sourceSlice/Route24.json", 0, 20)


def route25_cells():
    return open_map(ROOT / "Source/data/sourceSlice/Route25.json", 0, 60)


def bills_house_cells():
    return open_map(ROOT / "Source/data/sourceSlice/BillsHouse.json", 2, 13)


def trashed_house_cells():
    return open_map(ROOT / "Source/data/sourceSlice/CeruleanTrashedHouse.json", 2, 13)


def route5_cells():
    return open_map(ROOT / "Source/data/vermilionPreparation/Route5.json", 0, 20)


def route6_cells():
    return open_map(ROOT / "Source/data/vermilionPreparation/Route6.json", 0, 20)


def underground_route5_cells():
    return open_map(ROOT / "Source/data/vermilionPreparation/UndergroundPathRoute5.json", 2, 13)


def underground_corridor_cells():
    return open_map(ROOT / "Source/data/vermilionPreparation/UndergroundPathNorthSouth.json", 2, 13)


def underground_route6_cells():
    return open_map(ROOT / "Source/data/vermilionPreparation/UndergroundPathRoute6.json", 2, 13)


def vermilion_cells():
    return open_map(ROOT / "Source/data/vermilionPreparation/VermilionCity.json", 0, 40)


def vermilion_center_cells():
    return open_map(ROOT / "Source/data/vermilionPreparation/VermilionPokecenter.json", 0, 14)


def vermilion_mart_cells():
    return open_map(ROOT / "Source/data/vermilionPreparation/VermilionMart.json", 2, 13)


def vermilion_dock_cells():
    return open_map(ROOT / "Source/data/vermilionPreparation/VermilionDock.json", 0, 28)


def ss_anne_1f_cells():
    return open_map(ROOT / "Source/data/vermilionPreparation/SSAnne1F.json", 0, 40)


def ss_anne_2f_cells():
    return open_map(ROOT / "Source/data/vermilionPreparation/SSAnne2F.json", 0, 40)


def captain_cells():
    return open_map(ROOT / "Source/data/vermilionPreparation/SSAnneCaptainsRoom.json", 3, 13)


def vermilion_gym_cells():
    return open_map(ROOT / "Source/data/vermilionPreparation/VermilionGym.json", 1, 13)


def route11_cells():
    return open_map(ROOT / "Source/data/vermilionPreparation/Route11.json", 0, 60)


def diglett_house_cells():
    return open_map(ROOT / "Source/data/vermilionPreparation/DiglettsCaveRoute11.json", 2, 13)


def diglett_route2_house_cells():
    return open_map(ROOT / "Source/data/vermilionPreparation/DiglettsCaveRoute2.json", 2, 13)


def diglett_cave_cells():
    return open_map(ROOT / "Source/data/vermilionPreparation/DiglettsCave.json", 0, 40)


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


def route(open_cells, start, goal, avoid=(), blocked_edges=()):
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
            if nxt in previous or nxt not in open_cells or nxt in blocked or (cell, nxt) in blocked_edges:
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


def map_surface(path, pad=0):
    """Foot tiles and ledge hops. pad matches open_map so route cells line up."""
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    by_id = {grid["id"]: grid for grid in data["grids"]}
    feet = {}
    for y, row in enumerate(data["tile_ids"]):
        for x, gid in enumerate(row):
            feet[(x + pad, y)] = by_id[gid]["terrain"]["foot_tile"]
    names = {(0, 1): "down", (0, -1): "up", (-1, 0): "left", (1, 0): "right"}
    buttons = {"PAD_DOWN": (0, 1), "PAD_UP": (0, -1), "PAD_LEFT": (-1, 0), "PAD_RIGHT": (1, 0)}
    ledges = []
    for rule in data["directional_rules"]["ledges"]:
        dx, dy = buttons[rule["input"]]
        ledges.append((rule["standing_foot_tile"], rule["target_foot_tile"], dx, dy, names[(dx, dy)]))
    return feet, ledges


def ledge_route(open_cells, feet, ledges, start, goal, avoid=()):
    """route(), plus a ledge hop as one step that lands two cells ahead."""
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
        x, y = cell
        foot = feet.get(cell)
        hopped = set()
        if foot is not None:
            for stand, front, dx, dy, direction in ledges:
                if foot != stand:
                    continue
                if feet.get((x + dx, y + dy)) != front:
                    continue
                hopped.add((dx, dy))
                landing = (x + 2 * dx, y + 2 * dy)
                if landing in previous or landing not in open_cells or landing in blocked:
                    continue
                previous[landing] = (cell, direction)
                if landing == goal:
                    return _unwind_route(previous, landing, start)
                queue.append(landing)
        for direction, (dx, dy) in DELTAS.items():
            if (dx, dy) in hopped:
                continue
            nxt = (x + dx, y + dy)
            if nxt in previous or nxt not in open_cells or nxt in blocked:
                continue
            previous[nxt] = (cell, direction)
            if nxt == goal:
                return _unwind_route(previous, nxt, start)
            queue.append(nxt)
    return None


def _unwind_route(previous, cursor, start):
    steps = []
    while cursor != start:
        cursor, direction = previous[cursor]
        steps.append(direction)
    steps.reverse()
    return steps


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
        self.assertEqual(preferred_move(["TACKLE", "WATER GUN", "BUBBLE", "WITHDRAW"]), (2, "WATER GUN"))
        self.assertEqual(preferred_move(["TACKLE", "WATER GUN", "BUBBLE", "BITE"], ["WATER GUN"]), (3, "BUBBLE"))
        self.assertEqual(preferred_move(["TACKLE", "-"])[1], "TACKLE")
        moves = ["TACKLE", "WATER GUN", "BUBBLE", "BITE"]
        self.assertEqual(disabled_move("WARTORTLE's WATER GUN was disabled!", moves), "WATER GUN")
        self.assertEqual(disabled_move("WARTORTLE's WATER GUN is disabled!", moves), "WATER GUN")
        self.assertIsNone(disabled_move("WARTORTLE is no longer disabled!", moves))
        self.assertIsNone(disabled_move("GRIMER used DISABLE!", moves))
        self.assertFalse(_lost({"kind": "none"}, {"kind": "run", "won": False}))
        self.assertTrue(_lost({"kind": "none"}, {"kind": "defeat", "won": False, "blackout": True}))
        self.assertEqual(preferred_move(moves, enemy_types=["water"])[1], "BITE")
        pallet = padded_open_cells("pallet_town")
        pallet.add((9, 0))
        self.assertIsNotNone(route(pallet, (12, 12), (9, 0), avoid={(5, 5), (13, 5), (12, 11)}))
        self.assertIn((11, 0), route1_cells())
        self.assertIn((6, 0), forest_south_cells())
        self.assertIn((6, 0), forest_north_cells())
        self.assertIsNotNone(route(route2_cells(), (3, 44), (3, 43), avoid={(12, 9), (3, 11)}))
        self.assertIsNotNone(route(route2_cells(), (3, 11), (8, 0), avoid={(12, 9)}))
        self.assertIsNotNone(route(viridian_cells(), (17, 6), (18, 0), avoid=set(VIRIDIAN_WARPS)))
        self.assertIsNotNone(route(center_cells(), (3, 7), (3, 3)))
        self.assertIsNotNone(route(gym_cells(), (5, 13), (5, 3), avoid=GYM_TRAINER))
        self.assertIsNotNone(route(forest_cells(), (16, 47), (1, 1)))
        self.assertIn((5, 3), gym_cells())
        self.assertEqual(sha256_file(LAB_SAVE / "adventure.a.json"), LAB_SAVE_SHA)
        self.assertEqual(sha256_file(VIRIDIAN_SAVE / "adventure.a.json"), VIRIDIAN_SAVE_SHA)
        self.assertEqual(sha256_file(PEWTER_SAVE / "adventure.b.json"), PEWTER_SAVE_SHA)
        self.assertEqual(sha256_file(BADGE_SAVE / "adventure.a.json"), BADGE_SAVE_SHA)
        self.assertEqual(sha256_file(ROUTE4_SAVE / "adventure.b.json"), ROUTE4_SAVE_SHA)
        self.assertIsNotNone(route(gym_cells(), (5, 2), (5, 12)))
        self.assertIsNotNone(route(route3_cells(), (0, 10), (59, 0)))
        self.assertIsNotNone(route(route3_cells(), (0, 10), (59, 0), route3_avoid()))
        self.assertIsNotNone(route(route4_cells(), (9, 17), (18, 6)))
        self.assertIsNotNone(route(moon_cells(), (14, 35), (5, 6)))
        self.assertIsNotNone(route(moon_cells(), (14, 35), (6, 5), moon_avoid()))
        self.assertIsNotNone(route(moon_cells(), (14, 35), (6, 5), moon_avoid() | MOON_1F_SKIP, MOON_1F_EDGES))
        self.assertIsNotNone(route(moon_b2_cells(), (21, 17), (6, 7),
                                   (MOON_B2_AVOID - {(12, 8)}) | {(5, 7), (13, 7)}, MOON_B2_EDGES))
        self.assertIn(((10, 22), (9, 22)), MOON_1F_EDGES)
        self.assertIsNotNone(route(moon_b2_cells(), (21, 17), (12, 7), MOON_B2_AVOID, MOON_B2_EDGES))
        self.assertIn((12, 6), route_cells(moon_b2_cells(), (12, 7), (6, 7), MOON_B2_AVOID))
        self.assertIn((5, 7), route_cells(moon_b2_cells(), (12, 7), (6, 7), MOON_B2_AVOID))
        self.assertNotIn((5, 7), route_cells(moon_b2_cells(), (12, 7), (6, 7), MOON_B2_AVOID | {(5, 7)}))
        self.assertIsNotNone(route(moon_b2_cells(), (21, 17), (6, 7), MOON_B2_AVOID))
        self.assertIsNotNone(route(moon_b1_cells(), (5, 6), (21, 16)))
        self.assertIsNotNone(route(moon_b2_cells(), (21, 17), (6, 7)))
        self.assertIsNotNone(route(moon_b1_cells(), (23, 4), (26, 3)))
        self.assertIsNotNone(route(route4_cells(), (24, 6), (59, 4)))
        self.assertIsNone(route(route4_cells(), (24, 6), (11, 6)))
        self.assertIsNone(route(route4_cells(), (59, 4), (11, 6)))
        self.assertEqual(route4_cite(23, 6)["foot_tile"], 0x24)
        self.assertEqual(route4_cite(23, 6)["collision"], 1)
        self.assertEqual(route4_cite(20, 6)["foot_tile"], 0x27)
        self.assertIsNone(route(route4_cells(), (59, 4), (61, 4)))
        line = route4_open_line()
        self.assertEqual(line[0], ("down", (59, 5)))
        self.assertEqual(line[1], ("down", (59, 6)))
        self.assertIn(("right", (60, 6)), line)
        self.assertIn(("down", (76, 8)), line)
        self.assertIn(("down", (76, 10)), line)
        self.assertEqual(line[-2], ("right", (89, 10)))
        self.assertNotIn((60, 4), [cell for _direction, cell in line if cell != "cerulean"])
        self.assertTrue(all(cell == "cerulean" or cell[0] >= 59 for _direction, cell in line))
        self.assertEqual(route4_cite(60, 4)["foot_tile"], 0x27)
        self.assertEqual(route4_cite(60, 4)["collision"], 1)
        self.assertEqual(route4_cite(60, 6)["foot_tile"], 0x2C)
        self.assertEqual(route4_cite(60, 6)["collision"], 0)
        self.assertEqual(route4_cite(76, 6)["foot_tile"], 0x39)
        self.assertEqual(route4_cite(76, 7)["foot_tile"], 0x36)
        self.assertEqual(route4_cite(76, 7)["collision"], 1)
        self.assertEqual(route4_cite(76, 8)["collision"], 0)
        self.assertEqual(route4_cite(76, 9)["foot_tile"], 0x36)
        self.assertEqual(route4_cite(76, 10)["foot_tile"], 0x39)
        self.assertEqual(route4_cite(76, 10)["collision"], 0)
        self.assertIn((0, 18), cerulean_cells())
        self.assertIsNotNone(route(cerulean_cells(), (0, 18), (19, 18), CERULEAN_DOORS | {(15, 18)}))
        self.assertIsNotNone(route(cerulean_gym_cells(), (5, 13), (6, 2), CERULEAN_GYM_AVOID))
        self.assertIsNone(route(cerulean_gym_cells(), (5, 13), (6, 2), CERULEAN_GYM_AVOID | CERULEAN_LASS_SIGHT))
        self.assertIsNotNone(route(cerulean_mart_cells(), (5, 6), (4, 5)))
        self.assertIn((5, 7), cerulean_mart_cells())
        self.assertEqual(sha256_file(BRIDGE_SAVE / "adventure.b.json"), BRIDGE_SAVE_SHA)
        self.assertEqual(sha256_file(GYM_SAVE / "adventure.a.json"), GYM_SAVE_SHA)
        self.assertIsNotNone(route(cerulean_cells(), (19, 18), (21, 0), CERULEAN_DOORS | {(15, 18), (30, 7), (30, 9)}))
        bridge = route24_cells()
        held = {(11, 31), (10, 28), (11, 25), (10, 22), (11, 19), (11, 15), (5, 20), (10, 5), (10, 15)}
        self.assertIsNotNone(route(bridge, (11, 35), (10, 19), held))
        self.assertIsNotNone(route(bridge, (10, 16), (5, 19), held - {(10, 15)}))
        self.assertIsNone(route(bridge, (10, 16), (5, 19), {(10, 15), (11, 15), (5, 20)}))
        self.assertEqual(sha256_file(CASCADE_SAVE / "adventure.a.json"), CASCADE_SAVE_SHA)
        self.assertIsNotNone(route(bills_house_cells(), (4, 7), (3, 5)))
        self.assertIsNotNone(route(route25_cells(), (0, 9), (45, 4), ROUTE25_SKIP))
        self.assertIsNotNone(route(trashed_house_cells(), (4, 7), (5, 1)))
        self.assertIsNotNone(route(route5_cells(), (16, 0), (17, 28), ROUTE5_SKIP))
        self.assertIsNotNone(route(underground_corridor_cells(), (7, 4), (4, 40)))
        self.assertIsNotNone(route(route6_cells(), (17, 14), (9, 35), ROUTE6_SKIP))
        self.assertIsNotNone(route(vermilion_cells(), (18, 0), (11, 4)))
        self.assertIsNone(route(vermilion_cells(), (18, 0), (12, 20)))
        self.assertIsNone(route(vermilion_cells(), (19, 0), (12, 20)))
        self.assertIsNotNone(route(vermilion_cells(), (11, 4), (23, 14), VERMILION_DOORS - {(23, 13)}))
        self.assertIsNotNone(route(vermilion_cells(), (11, 4), (18, 29), VERMILION_DOORS))
        self.assertIsNotNone(route(ss_anne_1f_cells(), (27, 0), (2, 7), ANNE1_SKIP))
        self.assertIsNotNone(route(ss_anne_2f_cells(), (2, 5), (36, 9), ANNE2_SKIP))
        self.assertIsNotNone(route(ss_anne_2f_cells(), (36, 5), (2, 5), ANNE2_SKIP - {(36, 4)}))
        self.assertIsNotNone(route(captain_cells(), (3, 7), (7, 3)))
        opened = set(vermilion_cells())
        opened.add((15, 18))
        self.assertIsNone(route(vermilion_cells(), (15, 17), (12, 20), VERMILION_DOORS - {(12, 19)}))
        self.assertIsNotNone(route(opened, (15, 17), (12, 20), VERMILION_DOORS - {(12, 19)}))
        self.assertIsNone(route(vermilion_cells(), (12, 20), (11, 4), VERMILION_DOORS - {(11, 3)}))
        self.assertIsNotNone(route(opened, (12, 20), (11, 4), VERMILION_DOORS - {(11, 3)}))
        self.assertIsNotNone(route(vermilion_cells(), (12, 20), (15, 19), VERMILION_DOORS))
        self.assertIsNone(route(vermilion_cells(), (12, 20), (15, 17), VERMILION_DOORS))
        self.assertIsNotNone(route(route6_cells(), (9, 35), (12, 30), ROUTE6_SKIP))
        floor = {(x, y) for (x, y) in route6_cells() if y < 14}
        bug = (set(ROUTE6_SKIP) | floor) - {(1, 15), (2, 15), (3, 15), (4, 15)}
        self.assertIsNotNone(route(route6_cells(), (9, 35), (1, 15), bug))
        self.assertIsNotNone(route(route11_cells(), (0, 6), (4, 6)))
        self.assertIsNotNone(route(route11_cells(), (0, 6), (10, 15), route11_avoid()))
        self.assertIsNotNone(route(route11_cells(), (44, 16), (0, 6), route11_avoid()))
        self.assertIsNotNone(route(route11_cells(), (0, 6), (14, 4), route11_avoid() | {(10, 5), (11, 5), (12, 5), (13, 5)}))
        self.assertIsNotNone(route(vermilion_cells(), (11, 4), (39, 14), VERMILION_DOORS))
        self.assertEqual(_can_index({"VERMILION_SCENE_V1_FIRST_1": True, "VERMILION_SCENE_V1_FIRST_3": True}, "FIRST"), 10)
        self.assertEqual(VERMILION_CANS[10], (7, 9))
        self.assertEqual(TRASH_SECONDS[0], (0, 3))
        self.assertIn(0, TRASH_SECONDS[14])
        self.assertIsNotNone(route(route11_cells(), (0, 6), (10, 12), route11_avoid()))
        self.assertIsNotNone(route(diglett_cave_cells(), (36, 31), (5, 6)))
        self.assertIsNone(route(route2_cells(), (12, 10), (8, 0), {(12, 9)}))
        cave_side = {(12, 9), (3, 11)}
        self.assertIsNotNone(route(route2_cells(), (11, 2), (5, 11), cave_side))
        self.assertNotIn((5, 10), route2_cells())
        self.assertIsNone(route(route2_cells(), (5, 11), (8, 0), cave_side))
        route2_cut = set(route2_cells())
        route2_cut.add((5, 10))
        self.assertIsNotNone(route(route2_cut, (5, 11), (8, 0), cave_side))
        self.assertIsNotNone(route(vermilion_gym_cells(), (5, 16), (2, 6), GYM_SIGHT))
        self.assertIsNone(route(vermilion_gym_cells(), (5, 16), (2, 8), GYM_SIGHT))
        self.assertIsNotNone(route(vermilion_gym_cells(), (5, 16), (6, 2), GYM_SIGHT))
        self.assertIsNone(route(vermilion_gym_cells(), (2, 12), (3, 9), GYM_SIGHT))
        self.assertIsNotNone(route(vermilion_gym_cells(), (2, 12), (5, 9), GYM_SIGHT))
        self.assertIsNotNone(route(cerulean_cells(), (27, 9), (30, 9), set(CERULEAN_DOORS) - {(27, 9)} | {(15, 18)}))
        self.assertIsNone(route(cerulean_cells(), (27, 9), (30, 10), set(CERULEAN_DOORS) - {(27, 9)}))
        city = set(cerulean_cells())
        self.assertIsNone(route(city, (0, 18), (39, 16), set(CERULEAN_DOORS) | CERULEAN_NPCS))
        city.add((19, 28))
        self.assertIsNotNone(route(city, (0, 18), (39, 16), set(CERULEAN_DOORS) | CERULEAN_NPCS))
        feet, ledges = map_surface(EAST / "Route9.json")
        self.assertIsNone(ledge_route(route9_cells(), feet, ledges, (0, 8), (59, 8), ROUTE9_AVOID))
        opened = set(route9_cells())
        opened.add((5, 8))
        self.assertIsNotNone(ledge_route(opened, feet, ledges, (0, 8), (59, 8), ROUTE9_AVOID))
        self.assertIsNotNone(route(route10_cells(), (0, 8), (11, 20), ROUTE10_AVOID | {(8, 17)}))
        self.assertIsNotNone(route(rock_tunnel_1f_cells(), (15, 4), (37, 3), TUNNEL_1F_AVOID))
        self.assertIsNotNone(route(rock_tunnel_b1_cells(), (33, 25), (3, 3), TUNNEL_B1_AVOID))
        self.assertIsNotNone(route(rock_tunnel_1f_cells(), (37, 17), (15, 33), TUNNEL_1F_AVOID))
        self.assertIsNotNone(route(lavender_cells(), (6, 1), (0, 8), LAVENDER_DOORS))
        self.assertIsNotNone(route(route8_cells(), (59, 8), (13, 4), ROUTE8_AVOID))
        self.assertIsNotNone(route(underground_route8_cells(), (5, 6), (6, 4), {(5, 4)}))
        self.assertIsNotNone(route(underground_we_cells(), (47, 2), (2, 5)))
        self.assertIsNotNone(route(underground_route7_cells(), (6, 4), (5, 6)))
        self.assertIsNotNone(route(route7_cells(), (5, 14), (0, 3), ROUTE7_GATES | {(5, 13)}))
        self.assertIsNotNone(route(route7_cells(), (5, 14), (8, 2), ROUTE7_GATES | {(5, 13)}))
        gym = set(celadon_gym_cells())
        gym_feet, gym_ledges = map_surface(EAST / "CeladonGym.json", 1)
        self.assertIsNone(ledge_route(gym, gym_feet, gym_ledges, (5, 16), (5, 4), set()))
        self.assertIsNotNone(ledge_route(gym, gym_feet, gym_ledges, (5, 16), (6, 8), set()))
        gym.add((6, 7))
        self.assertIsNotNone(ledge_route(gym, gym_feet, gym_ledges, (6, 8), (5, 4), {(5, 3)}))
        _k_trace()
        self.assertEqual(sha256_file(TICKET_SAVE / "adventure.b.json"), TICKET_SAVE_SHA)
        self.assertEqual(sha256_file(VERMILION_SAVE / "adventure.a.json"), VERMILION_SAVE_SHA)
        self.assertEqual(sha256_file(CATCH_SAVE / "adventure.b.json"), CATCH_SAVE_SHA)

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
        for _ in range(16):
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
                    # YES learns. Forget Tail Whip while it is still known.
                    # The stop menu's second row returns to that question.
                    selected = learning.get("selected") or 1
                    target = forget_index(learning) if phase == "replace" else {"ask": 1, "confirm": 1, "stop": 2}.get(phase, 1)
                    if selected == target:
                        self.press("a", wait=6)
                    else:
                        self.press("down" if target > selected else "up", wait=2)
            elif root == "tutorial-escort":
                # The hurry menu opens on YES. A during the catch demo is ignored
                # until the old man has already caught the Weedle.
                self.press("a", wait=8)
            elif root == "evolution":
                # B cancels the animation. Wait it out, then confirm the result.
                evo = self.state.get("evolution") or {}
                if evo.get("phase") == "animate":
                    self.send("wait 20")
                elif evo.get("dialog_ready"):
                    self.press("a", wait=6)
                else:
                    self.send("wait 6")
            elif root == "event":
                event = self.state.get("event") or {}
                phase = event.get("phase")
                menu = event.get("menu") or {}
                if phase == "heal-animation":
                    self.send("wait 20")
                elif phase == "vermilion-departure":
                    # The ship clock advances on its own. A does not skip it.
                    self.send("wait 20")
                elif phase == "heal-confirm" and menu.get("active") and "YES" in (menu.get("options") or []):
                    self.choose("event", "YES")
                else:
                    self.press("a", wait=6)
            elif root == "title":
                return False
            elif root == "pokedex":
                # The capture page closes on A. B would leave the same page.
                self.press("a", wait=6)
            else:
                self.send("wait 8")
        if self.state.get("root") == "battle":
            return False
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

    def follow(self, open_cells, goal, avoid, blocked_edges=()):
        blocked = set(avoid)
        for _ in range(40):
            if not self.exploring():
                return "overlay"
            cell = (self.state["player"]["x"], self.state["player"]["y"])
            if cell == goal:
                return "arrived"
            steps = route(open_cells, cell, goal, blocked, blocked_edges)
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

    def run_away(self, limit=240):
        """Leave a wild battle. A failed escape still takes a full attack page, so the budget counts those pages."""
        misses = 0
        for _ in range(limit):
            root = self.state.get("root")
            if root == "party":
                _send_out(self, None)
                continue
            if root != "battle":
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
                    continue
                mon = battle.get("player") or {}
                player_hp = mon.get("hp") or 0
                max_hp = mon.get("maxHP") or 0
                quantities = (self.state.get("inventory") or {}).get("quantities") or {}
                potions = int(quantities.get("potion") or 0) + int(quantities.get("superPotion") or 0)
                if potions > 0 and 0 < player_hp < max_hp and player_hp <= max(28, max_hp - 12):
                    if self.use_potion():
                        continue
                options = (battle.get("menu") or {}).get("options") or []
                if "RUN" not in options:
                    misses += 1
                    if misses >= 8:
                        return False
                    self.send("wait 4")
                    continue
                misses = 0
                self.choose("battle", "RUN")
                # Arena Trap rejects the run with no text and leaves the menu up.
                battle = self.state.get("battle") or {}
                options = (battle.get("menu") or {}).get("options") or []
                if (battle.get("phase") == "command" and (battle.get("runAttempts") or 0) == 0
                        and "RUN" in options):
                    misses += 1
                    if misses >= 2:
                        return False
                else:
                    misses = 0
            else:
                self.send("wait 4")
        return self.state.get("root") != "battle"

    def travel(self, open_cells, goal, avoid, limit=12, blocked_edges=(), potion_at=30):
        started = self.state.get("zone")
        for _ in range(limit):
            if started and self.state.get("zone") != started:
                return "warp"
            kind = self.follow(open_cells, goal, avoid, blocked_edges)
            if kind != "overlay":
                return kind
            root = self.state.get("root")
            if root == "battle":
                before = self.state.get("last_battle_outcome")
                trainer = (self.state.get("battle") or {}).get("trainerName")
                if trainer:
                    self.fight(limit=2500, potion_at=potion_at)
                elif not self.run_away():
                    self.fight(limit=2500, potion_at=potion_at)
                self.dismiss_until_explore(limit=80)
                after = self.state.get("last_battle_outcome") or {}
                if _lost(before, after):
                    return "blackout"
                continue
            if root in ("dialog", "learning", "oak", "naming", "tutorial-escort", "event"):
                self.dismiss_until_explore(limit=100)
                continue
            return kind
        return "lost"

    def fight(self, limit=700, potion_at=22, bite_only=False, shift_to=None, decline_moves=False, run_at=None):
        won = None
        rejected = set()
        for _ in range(limit):
            root = self.state.get("root")
            if root == "learning":
                move = ((self.state.get("learning") or {}).get("move_info") or {}).get("key")
                # Whirlwind, Agility, and Mirror Move are not the Erika plan.
                if decline_moves or move in ("whirlwind", "agility", "mirrorMove"):
                    _decline_new_move(self)
                    continue
                if not self.dismiss_until_explore(limit=80) and self.state.get("root") == "battle":
                    continue
                if self.state.get("root") != "battle":
                    break
            if root == "evolution":
                self.dismiss_until_explore(limit=40)
                continue
            if root == "party":
                _send_out(self, shift_to)
                continue
            if root == "dialog":
                dialog = self.state.get("dialog") or {}
                if dialog.get("ready"):
                    self.press("a", wait=4)
                else:
                    self.send("wait 4")
                continue
            if root != "battle":
                break
            battle = self.state.get("battle") or {}
            if battle.get("shift_choice"):
                # The question stays up for 10 frames before YES/NO takes input.
                # B declines. YES only after Kadabra, so the bird meets Ivysaur.
                self.send("wait 20", max_frames=80)
                battle = self.state.get("battle") or {}
                if battle.get("shift_choice") and self.state.get("root") == "battle":
                    fainted = ((battle.get("enemy") or {}).get("species") or "")
                    grass = fainted in (
                        "oddish", "bellsprout", "bulbasaur", "victreebel", "tangela", "vileplume")
                    active = ((battle.get("player") or {}).get("species") or "")
                    if shift_to and active != shift_to and (fainted == "kadabra" or grass):
                        self.press("a", wait=8)
                    else:
                        self.press("b", wait=8)
                continue
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
                player_hp = (battle.get("player") or {}).get("hp") or 0
                max_hp = (battle.get("player") or {}).get("maxHP") or 0
                quantities = (self.state.get("inventory") or {}).get("quantities") or {}
                potions = int(quantities.get("potion") or 0) + int(quantities.get("superPotion") or 0)
                # A Potion is applied before the foe moves. Starmie's Swift crit
                # is 31, so healing at 32 or below finishes at 45 or more.
                # Staryu's hits are about 9, so those turns stay on Bite.
                foe = ((battle.get("enemy") or {}).get("species") or "")
                ceiling = potion_at if bite_only or foe != "staryu" else min(potion_at, 18)
                menu = battle.get("menu") or {}
                # Ability text, such as Intimidate, keeps command phase with the menu closed.
                ready = bool(menu.get("active")) and not battle.get("inMoveSelect")
                if (ready and potions > 0 and 0 < player_hp <= ceiling
                        and player_hp < max_hp and self.use_potion()):
                    continue
                if ready and run_at and 0 < player_hp <= run_at and "RUN" in (menu.get("options") or []):
                    self.choose("battle", "RUN")
                    continue
                if not battle.get("inMoveSelect"):
                    if not ready or "FIGHT" not in (menu.get("options") or []):
                        self.send("wait 4")
                        continue
                    self.choose("battle", "FIGHT")
                else:
                    move_menu = battle.get("moveMenu") or {}
                    options = move_menu.get("options") or []
                    if not options:
                        self.send("wait 4")
                        continue
                    selected = move_menu.get("selected") or 1
                    message = battle.get("message") or ""
                    if "no longer disabled" in message.lower():
                        rejected.clear()
                    else:
                        named = disabled_move(message, options)
                        if named:
                            rejected.add(named)
                    enemy_types = ((battle.get("enemy") or {}).get("types") or [])
                    if bite_only:
                        enemy_types = ["water"]
                    species = ((battle.get("player") or {}).get("species") or "")
                    pp = ((battle.get("player") or {}).get("pp") or {})
                    for name in options:
                        letters = "".join(ch for ch in str(name).upper() if ch.isalpha())
                        for key, left in pp.items():
                            if "".join(ch for ch in str(key).upper() if ch.isalpha()) == letters and left == 0:
                                rejected.add(name)
                    if species in ("pidgey", "pidgeotto", "spearow", "fearow"):
                        for name in options:
                            letters = "".join(ch for ch in str(name).upper() if ch.isalpha())
                            if letters in ("WHIRLWIND", "MIRRORMOVE", "AGILITY"):
                                rejected.add(name)
                    forced = {
                        "pidgey": ("GUST",), "pidgeotto": ("WINGATTACK", "GUST"),
                        "spearow": ("DRILLPECK", "PECK"), "fearow": ("DRILLPECK", "PECK"),
                        "diglett": ("DIG",), "dugtrio": ("DIG",),
                    }.get(species) or ()
                    index = None
                    for want in forced:
                        for move_index, name in enumerate(options, start=1):
                            letters = "".join(ch for ch in str(name).upper() if ch.isalpha())
                            if letters == want and name not in rejected:
                                index = move_index
                                break
                        if index is not None:
                            break
                    if index is None:
                        index, _name = preferred_move(options, rejected, enemy_types)
                    if index and selected != index:
                        self.press("down" if index > selected else "up", wait=2)
                    else:
                        self.press("a", wait=4)
            else:
                self.send("wait 4")
        return won

    def use_potion(self):
        """Spend one battle turn on a Potion for the lead. The Lass outlasts Bite otherwise."""
        if (self.state.get("battle") or {}).get("inMoveSelect"):
            self.press("b", wait=4)
        try:
            self.choose("battle", "BAG")
        except RuntimeError:
            self.press("b", wait=4)
            return False
        for _ in range(16):
            root = self.state.get("root")
            if root == "battle":
                return True
            if root == "bag":
                bag = self.state.get("bag") or {}
                if bag.get("phase") not in (None, "list", "closed"):
                    self.press("a", wait=4)
                    continue
                slots = ((self.state.get("inventory") or {}).get("slots") or [])
                index = next((i for i, slot in enumerate(slots, start=1)
                              if slot.get("id") in ("potion", "superPotion")), None)
                if index is None:
                    self.press("b", wait=4)
                    return False
                selected = bag.get("selected") or 1
                if selected != index:
                    self.press("down" if index > selected else "up", wait=2)
                else:
                    self.press("a", wait=6)
            elif root == "party":
                species = ((self.state.get("battle") or {}).get("player") or {}).get("species")
                slot, mon = _member(self, species) if species else (None, None)
                if not mon or (mon.get("hp") or 0) <= 0:
                    slot = 1
                selected = ((self.state.get("party_info") or {}).get("selected") or 1)
                if selected != slot:
                    self.press("down" if slot > selected else "up", wait=2)
                else:
                    self.press("a", wait=8)
            else:
                self.send("wait 4")
        return False

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


def step_onto(player, cells, goal, avoid, direction, blocked_edges=()):
    """Walk to the cell before goal, then take one step onto it."""
    dx, dy = DELTAS[direction]
    before = (goal[0] - dx, goal[1] - dy)
    started = player.state.get("zone")
    kind = player.travel(cells, before, avoid, blocked_edges=blocked_edges)
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
            adjacent = (npc["x"] - dx, npc["y"] - dy)
            # A solid counter sits between the player and the nurse. Stand on
            # the open tile beyond it and face the counter.
            candidates = [adjacent] if adjacent in cells else [(npc["x"] - 2 * dx, npc["y"] - 2 * dy)]
            for spot in candidates:
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
            # A defeated trainer can still stand on the nearest tile.
            blocked.add(spot)
            continue
        if player.state["player"].get("facing") != direction:
            player.press(direction, wait=4)
        player.press("a", wait=8)
        if not player.exploring():
            player.dismiss_until_explore(limit=100)
            return "talked"
    return "silent"


def _walk_from_lab(player, report, display, clips, output):
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
        kind = player.travel(route1, (11, 0), set(), limit=30)
        report["route1_north"] = {"kind": kind, **summary(player.state)}
        if kind != "arrived":
            raise RuntimeError("could not cross Route 1: " + json.dumps(summary(player.state)))
        player.step("up")
        player.settle(limit=80)
        player.dismiss_until_explore(limit=20)
        report["viridian_enter"] = summary(player.state)
        if "viridian_city" not in str(player.state.get("zone")):
            raise RuntimeError("Route 1 did not reach Viridian: " + json.dumps(summary(player.state)))

    if display and clips and output:
        film(display, clips, output, "route1", report, "start", walk_route1)
    else:
        walk_route1()
    if player.exploring():
        report["saved_viridian"] = player.pause_save()


def play_to_brock(player, report, display=None, clips=None, output=None):
    """Lab save to the Boulder Badge. Route 1 and Brock are filmed."""
    player.leave_title()
    if not player.exploring():
        player.dismiss_until_explore(limit=40)
    report["continued"] = summary(player.state)
    zone = str(player.state.get("zone"))
    if zone == "oaks_lab":
        mode = "lab"
    elif "viridian_city" in zone:
        mode = "viridian"
    elif "pewter_city" in zone:
        mode = "pewter"
    else:
        raise RuntimeError("continue did not resume a walked save: " + json.dumps(summary(player.state)))
    if mode == "pewter":
        report["resumed_pewter"] = summary(player.state)
    else:
        _reach_pewter(player, report, display, clips, output, mode)
    _heal_and_fight_brock(player, report, display, clips, output)
def _reach_pewter(player, report, display, clips, output, mode):
    if mode == "lab":
        _walk_from_lab(player, report, display, clips, output)
    else:
        report["resumed_viridian"] = summary(player.state)
    city = viridian_cells()
    if mode == "lab":
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
    # (3, 11) is the north-gate tile we are standing on. Avoiding it makes the route refuse to start.
    kind = leave_map(player, route2, (8, 0), {(12, 9)}, "up")
    report["pewter_enter"] = {"kind": kind, **summary(player.state)}
    if "pewter_city" not in str(player.state.get("zone")):
        raise RuntimeError("Route 2 did not reach Pewter: " + json.dumps(summary(player.state)))
    if player.exploring():
        report["saved_pewter"] = player.pause_save()


# The junior trainer stands at (4, 7) facing right. (5, 7) is her open sight tile.
GYM_TRAINER = {(4, 7), (5, 7)}


def _heal_and_fight_brock(player, report, display, clips, output):
    pokemon = player.state.get("pokemon") or {}
    hp = pokemon.get("hp") or 0
    status = pokemon.get("status") or "none"
    if hp < 20 or status not in ("none", "healthy", ""):
        pewter = pewter_cells()
        kind = step_onto(player, pewter, (13, 25), set(), "up")
        report["center"] = {"kind": kind, **summary(player.state)}
        if "center" not in str(player.state.get("zone")):
            raise RuntimeError("Pewter did not enter the Center: " + json.dumps(summary(player.state)))
        nurse = talk_to(player, center_cells(), "pokered:PEWTER_POKECENTER:objects:1", set())
        report["nurse"] = nurse
        report["healed"] = summary(player.state)
        healed = player.state.get("pokemon") or {}
        if nurse != "talked" or (healed.get("hp") or 0) < 20 or (healed.get("status") or "none") not in ("none", "healthy", ""):
            raise RuntimeError("the nurse did not heal Squirtle: " + json.dumps(summary(player.state)))
        kind = step_onto(player, center_cells(), (3, 7), set(), "down")
        report["center_exit"] = {"kind": kind, **summary(player.state)}
        if "pewter_city" not in str(player.state.get("zone")):
            raise RuntimeError("the Center did not return to Pewter: " + json.dumps(summary(player.state)))
    pewter = pewter_cells()
    gym_avoid = {(14, 7), (19, 5), (29, 13), (23, 17), (7, 29), (13, 25)}
    kind = step_onto(player, pewter, (16, 17), gym_avoid, "up")
    report["gym_door"] = {"kind": kind, **summary(player.state)}
    if "gym" not in str(player.state.get("zone")):
        raise RuntimeError("Pewter did not enter the gym: " + json.dumps(summary(player.state)))
    gym = gym_cells()

    def battle_brock():
        talked = talk_to(player, gym, BROCK, GYM_TRAINER)
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


def _needs_heal(player):
    mon = player.state.get("pokemon") or {}
    status = mon.get("status") or "none"
    hp = mon.get("hp") or 0
    return hp < 28 or status not in ("none", "healthy", "")


def _heal_in(player, report, city, door, nurse_id, inside, label, outdoors, avoid=()):
    kind = step_onto(player, city, door, set(avoid), "up")
    report[label + "_door"] = {"kind": kind, **summary(player.state)}
    if "center" not in str(player.state.get("zone")):
        raise RuntimeError(f"{label} door did not open: " + json.dumps(summary(player.state)))
    talked = talk_to(player, inside, nurse_id, set())
    report[label + "_nurse"] = talked
    healed = player.state.get("pokemon") or {}
    if talked != "talked" or (healed.get("hp") or 0) < 20 or (healed.get("status") or "none") not in ("none", "healthy", ""):
        raise RuntimeError(f"{label} nurse missed: " + json.dumps(summary(player.state)))
    kind = step_onto(player, inside, (3, 7), set(), "down")
    report[label + "_left"] = {"kind": kind, **summary(player.state)}
    if outdoors not in str(player.state.get("zone")):
        raise RuntimeError(f"still inside {label}: " + json.dumps(summary(player.state)))


# Bodies of every Route 3 trainer, plus the sight of the ones the road can pass
# without fighting. The four remaining sight lines are the only way east.
ROUTE3_FIGHT = {(10, 6), (14, 4), (19, 5), (24, 6)}
ROUTE3_SKIP = (
    ((16, 9), "left", 2),
    ((23, 4), "left", 4),
    ((22, 9), "left", 3),
    ((33, 10), "up", 2),
    ((57, 11), "down", 0),
)


def moon_avoid():
    """Every Mt. Moon 1F trainer tile and sight line. The stairs stay open."""
    delta = {"up": (0, -1), "down": (0, 1), "left": (-1, 0), "right": (1, 0)}
    trainers = (
        ((5, 6), "down", 2),
        ((12, 16), "right", 3),
        ((30, 4), "down", 3),
        ((24, 31), "up", 3),
        ((16, 23), "down", 3),
        ((7, 22), "down", 3),
        ((30, 27), "right", 3),
    )
    avoid = set()
    for (x, y), facing, sight in trainers:
        avoid.add((x, y))
        dx, dy = delta[facing]
        for step in range(1, sight + 1):
            avoid.add((x + dx * step, y + dy * step))
    return avoid


# The fossil super nerd and the fossil he guards. The Rocket at (11, 16) still sees the stair path.
MOON_B2_AVOID = {(12, 8), (13, 6)}
# These stairs drop into a pocket that does not reach the exit.
MOON_1F_SKIP = {(17, 11), (25, 15)}


def pair_edges(filename):
    """Steps the engine refuses because the two foot tiles are a forbidden pair."""
    data = json.loads((ROOT / filename).read_text(encoding="utf-8"))
    by_id = {grid["id"]: grid for grid in data["grids"]}
    ids = data["tile_ids"]
    collision = data["collision"]
    forbidden = set()
    for left, right in data["directional_rules"]["forbidden_tile_pairs"]:
        forbidden.add((left, right))
        forbidden.add((right, left))

    def foot(x, y):
        return by_id[ids[y][x]]["terrain"]["foot_tile"]

    edges = set()
    height = len(collision)
    width = len(collision[0])
    for y in range(height):
        for x in range(width):
            if collision[y][x] != 0:
                continue
            for dx, dy in ((1, 0), (0, 1)):
                nx, ny = x + dx, y + dy
                if nx >= width or ny >= height or collision[ny][nx] != 0:
                    continue
                if (foot(x, y), foot(nx, ny)) in forbidden:
                    edges.add(((x, y), (nx, ny)))
                    edges.add(((nx, ny), (x, y)))
    return edges


MOON_1F_EDGES = pair_edges("Source/data/sourceSlice/MtMoon1F.json")
MOON_B1_EDGES = pair_edges("Source/data/sourceSlice/MtMoonB1F.json")
MOON_B2_EDGES = pair_edges("Source/data/sourceSlice/MtMoonB2F.json")


def route3_avoid():
    delta = {"up": (0, -1), "down": (0, 1), "left": (-1, 0), "right": (1, 0)}
    avoid = set(ROUTE3_FIGHT)
    for (x, y), facing, sight in ROUTE3_SKIP:
        avoid.add((x, y))
        dx, dy = delta[facing]
        for step in range(1, sight + 1):
            avoid.add((x + dx * step, y + dy * step))
    return avoid


def careful_travel(player, cells, goal, avoid, limit=40, hp_floor=22):
    """Walk until the goal, a zone change, or Squirtle needs the Center."""
    started = player.state.get("zone")
    for _ in range(limit):
        if started and player.state.get("zone") != started:
            return "warp"
        kind = player.follow(cells, goal, avoid)
        if kind != "overlay":
            return kind
        root = player.state.get("root")
        if root == "battle":
            trainer = (player.state.get("battle") or {}).get("trainerName")
            if trainer or not player.run_away():
                player.fight()
            player.dismiss_until_explore(limit=80)
        elif root in ("dialog", "learning", "oak", "naming", "tutorial-escort", "event", "evolution"):
            player.dismiss_until_explore(limit=80)
        else:
            return kind
        mon = player.state.get("pokemon") or {}
        status = mon.get("status") or "none"
        if (mon.get("hp") or 0) < hp_floor or status not in ("none", "healthy", ""):
            return "hurt"
    return "lost"


def _cross_route3(player, report, display, clips, output):
    """Walk Pewter's east road. Heal in Pewter between the trainers the road must cross."""
    doors = {(14, 7), (19, 5), (29, 13), (23, 17), (7, 29), (13, 25), (16, 17)}
    filmed = False
    avoid = route3_avoid()
    for attempt in range(6):
        zone = str(player.state.get("zone"))
        if "pewter_city" in zone:
            if _needs_heal(player):
                _heal_in(player, report, pewter_cells(), (13, 25),
                         "pokered:PEWTER_POKECENTER:objects:1", center_cells(), "pewter_heal", "pewter_city")
            here = (player.state["player"]["x"], player.state["player"]["y"])
            blocked = set(doors)
            blocked.discard(here)
            kind = player.travel(pewter_cells(), (39, 18), blocked, limit=8)
            report["pewter_east"] = kind
            if kind != "arrived":
                raise RuntimeError("could not reach Pewter's east edge: " + json.dumps(summary(player.state)))

            def walk(blocked=blocked):
                leave_map(player, pewter_cells(), (39, 18), blocked, "right")
                return careful_travel(player, route3_cells(), (59, 0), avoid)

            if not filmed:
                kind = film(display, clips, output, "route3", report, "start", walk)
                filmed = True
            else:
                kind = walk()
        elif "route_3" in zone:
            here = (player.state["player"]["x"], player.state["player"]["y"])
            blocked = set(avoid)
            blocked.discard(here)
            kind = careful_travel(player, route3_cells(), (59, 0), blocked)
        else:
            raise RuntimeError("Route 3 retry left the road: " + json.dumps(summary(player.state)))
        report[f"route3_{attempt}"] = {"kind": kind, **summary(player.state)}
        if player.state.get("zone") == "kanto_route_3" and (player.state["player"]["x"], player.state["player"]["y"]) == (59, 0):
            return
        if kind == "hurt" and "route_3" in str(player.state.get("zone")):
            _retreat_route3(player, avoid)
        if "pewter" in str(player.state.get("zone")):
            continue
        raise RuntimeError("Route 3 walk stopped early: " + json.dumps(summary(player.state)))
    raise RuntimeError("Route 3 did not reach Route 4: " + json.dumps(summary(player.state)))


def _retreat_route3(player, avoid):
    here = (player.state["player"]["x"], player.state["player"]["y"])
    blocked = set(avoid)
    blocked.discard(here)
    kind = careful_travel(player, route3_cells(), (0, 10), blocked, hp_floor=1)
    if player.state.get("zone") != "kanto_route_3":
        return
    if (player.state["player"]["x"], player.state["player"]["y"]) != (0, 10):
        raise RuntimeError("could not retreat to Pewter: " + json.dumps(summary(player.state)))
    leave_map(player, route3_cells(), (0, 10), blocked, "left")


def _settle_overlay(player, limit=16):
    """Finish a script or a trainer battle before the next step."""
    for _ in range(limit):
        root = player.state.get("root")
        if player.exploring():
            return True
        if root == "battle":
            player.fight(limit=2500, potion_at=16)
            player.dismiss_until_explore(limit=80)
            continue
        player.dismiss_until_explore(limit=100)
    return player.exploring()


def _outcome_stamp(player):
    outcome = player.state.get("last_battle_outcome") or {}
    return [
        outcome.get("won"), outcome.get("kind"), outcome.get("enemy_hp"),
        outcome.get("trainerName") or outcome.get("trainer_id"),
    ]


def _abort_if_lost(player, report):
    stamp = _outcome_stamp(player)
    if stamp == report.get("outcome_stamp"):
        return
    report["outcome_stamp"] = stamp
    if stamp[0] is False:
        raise RuntimeError("blackout before the gym: " + json.dumps(summary(player.state)))


def _return_to_bridge(player, report):
    """North edge (21, 0) is the bridge. The rival at (20, 6)/(21, 6) is on that walk."""
    if player.state.get("zone") == "kanto_route_24":
        return "there"
    _settle_overlay(player)
    avoid = set(CERULEAN_DOORS) | {(30, 7), (30, 9), (15, 18)}
    kind = "stayed"
    for cell in ((21, 0), (20, 0)):
        kind = player.travel(cerulean_cells(), cell, avoid, limit=30)
        _settle_overlay(player)
        if kind == "blackout":
            raise RuntimeError("blackout before the bridge: " + json.dumps(summary(player.state)))
        if (player.state["player"]["x"], player.state["player"]["y"]) != cell:
            continue
        if player.state["player"].get("facing") != "up":
            player.press("up", wait=4)
        player.step("up")
        _settle_overlay(player)
        if player.state.get("zone") == "kanto_route_24":
            break
    _abort_if_lost(player, report)
    report["bridge_entry"] = {"kind": kind, **summary(player.state)}
    if player.state.get("zone") != "kanto_route_24":
        raise RuntimeError("Route 24 did not open: " + json.dumps(summary(player.state)))
    return kind


def _heal_on_bridge(player, report, floor=24, come_back=True):
    hp = (player.state.get("pokemon") or {}).get("hp") or 0
    if hp >= floor and not _needs_heal(player):
        return
    if player.state.get("zone") == "kanto_route_24":
        avoid = {(11, 15), (5, 20)}
        if _item_count(player, "nugget") < 1:
            avoid.add((10, 15))
        for cell in ((11, 35), (10, 35)):
            player.travel(route24_cells(), cell, avoid, limit=30)
            _settle_overlay(player)
            if (player.state["player"]["x"], player.state["player"]["y"]) != cell:
                continue
            if player.state["player"].get("facing") != "down":
                player.press("down", wait=4)
            player.step("down")
            _settle_overlay(player)
            if player.state.get("zone") != "kanto_route_24":
                break
    if "cerulean_city" not in str(player.state.get("zone")):
        raise RuntimeError("the bridge did not return to Cerulean: " + json.dumps(summary(player.state)))
    _heal_in(player, report, cerulean_cells(), (19, 17), CERULEAN_NURSE,
             cerulean_center_cells(), "bridge_heal", "cerulean_city",
             avoid=CERULEAN_DOORS | {(15, 18), (30, 7), (30, 9)})
    if come_back:
        _return_to_bridge(player, report)


def _bridge_spot(player, report, spot, avoid):
    _return_to_bridge(player, report)
    kind = player.travel(route24_cells(), spot, avoid, limit=30)
    _settle_overlay(player)
    if kind == "blackout":
        raise RuntimeError("blackout on Nugget Bridge: " + json.dumps(summary(player.state)))
    _abort_if_lost(player, report)
    report.setdefault("bridge", []).append({"spot": list(spot), "kind": kind, **summary(player.state)})
    _heal_on_bridge(player, report)


def _take_nugget(player, report):
    """(10, 15) is the only walk north of the bridge. The Rocket battles after the gift."""
    _return_to_bridge(player, report)
    kind = player.travel(route24_cells(), (10, 16), {(10, 15), (11, 15), (5, 20)}, limit=30)
    _settle_overlay(player)
    if kind == "blackout":
        raise RuntimeError("blackout before the Nugget: " + json.dumps(summary(player.state)))
    if (player.state["player"]["x"], player.state["player"]["y"]) != (10, 16):
        raise RuntimeError("could not stand south of the Nugget: " + json.dumps(summary(player.state)))
    player.step("up")
    _settle_overlay(player, limit=24)
    _abort_if_lost(player, report)
    count = _item_count(player, "nugget")
    report["nugget"] = {"kind": kind, "count": count, **summary(player.state)}
    if count < 1:
        raise RuntimeError("the Nugget was not received: " + json.dumps(summary(player.state)))


def _sell_nugget_buy_potions(player, report, target=8):
    """Cerulean pays 5000 for the Nugget and does not stock Super Potions."""
    if player.state.get("zone") != "kanto_cerulean_city":
        leave_map(player, route24_cells(), (11, 35), set(), "down")
        _settle_overlay(player)
    doors = set(CERULEAN_DOORS)
    doors.discard((25, 25))
    kind = step_onto(player, cerulean_cells(), (25, 25), doors | {(15, 18), (30, 7), (30, 9)}, "up")
    _settle_overlay(player)
    report["nugget_mart_door"] = {"kind": kind, **summary(player.state)}
    if "mart" not in str(player.state.get("zone")):
        raise RuntimeError("Cerulean Mart did not open: " + json.dumps(summary(player.state)))
    cells = cerulean_mart_cells()
    opened = False
    for _ in range(8):
        if player.state.get("root") == "shop":
            opened = True
            break
        if not player.exploring():
            _settle_overlay(player)
        npc = npc_named(player.state, CERULEAN_CLERK)
        if npc is None:
            break
        spot = (npc["x"] + 2, npc["y"])
        player.travel(cells, spot, {(npc["x"], npc["y"])})
        if player.state["player"].get("facing") != "left":
            player.press("left", wait=4)
        player.press("a", wait=8)
        if player.state.get("root") == "shop":
            opened = True
            break
    if not opened:
        raise RuntimeError("the clerk did not open the mart: " + json.dumps(summary(player.state)))
    if _item_count(player, "nugget") >= 1:
        armed = False
        for _ in range(24):
            if _item_count(player, "nugget") == 0:
                break
            shop = player.state.get("shop") or {}
            phase = shop.get("phase")
            if phase == "browse" and not armed:
                player.press("b", wait=4)
            elif phase == "mode":
                player.choose("shop", "SELL")
                armed = True
            elif phase == "browse":
                if shop.get("item") == "nugget":
                    player.press("a", wait=4)
                else:
                    player.press("down", wait=2)
            elif phase == "quantity":
                if (shop.get("quantity") or 1) == 1 and shop.get("item") == "nugget":
                    player.press("a", wait=4)
                else:
                    player.press("b", wait=4)
            elif phase == "confirm":
                player.choose("shop", "YES")
            elif phase == "result":
                player.press("a", wait=4)
            else:
                player.send("wait 4")
    if _item_count(player, "nugget") != 0:
        raise RuntimeError("the Nugget did not sell: " + json.dumps(summary(player.state)))
    _shop_buy_potions(player, target)
    have = _item_count(player, "potion")
    report["potions"] = have
    report["money"] = int((player.state.get("inventory") or {}).get("money") or 0)
    if have < target:
        raise RuntimeError("the mart did not sell eight Potions: " + json.dumps(summary(player.state)))
    for _ in range(8):
        if player.state.get("root") != "shop":
            break
        phase = (player.state.get("shop") or {}).get("phase")
        if phase == "browse":
            player.press("b", wait=4)
        elif phase == "mode":
            player.choose("shop", "QUIT")
        else:
            player.press("b", wait=4)
    kind = "stayed"
    for _ in range(12):
        if "cerulean_city" in str(player.state.get("zone")):
            break
        for door in ((6, 7), (5, 7)):
            kind = step_onto(player, cells, door, set(), "down")
            if "cerulean_city" in str(player.state.get("zone")):
                break
        else:
            player.send("wait 18")
            continue
        break
    report["nugget_mart_left"] = {"kind": kind, **summary(player.state)}
    if "cerulean_city" not in str(player.state.get("zone")):
        raise RuntimeError("still inside the mart: " + json.dumps(summary(player.state)))


# Bodies plus the sight of Route 25 trainers the east walk can pass. The
# remaining four (hiker at (8, 4), lass at (18, 8), junior at (24, 4), lass at
# (37, 4)) are the only lines between the Route 24 exit and Bill's door.
ROUTE25_SKIP = {
    (14, 2), (14, 3), (14, 4),
    (18, 5), (18, 4), (18, 3), (18, 2),
    (24, 4), (18, 8), (32, 3), (31, 3), (30, 3), (29, 3), (28, 3),
    (37, 4), (8, 4), (23, 9), (23, 8), (23, 7), (13, 7), (14, 7), (15, 7),
    (22, 2),
}
# Route 6's south edge is inside the pair at (11, 30) and (11, 31). The other
# sight lines, the Saffron gates, and the talk-only pair stay off the walk.
ROUTE6_SKIP = {
    (10, 21), (11, 21), (0, 15), (1, 15), (2, 15), (3, 15), (4, 15),
    (11, 31), (11, 30), (19, 26), (18, 26), (17, 26), (16, 26),
    (9, 1), (10, 1), (10, 7),
}
# Objects 4 and 5 were beaten on the way into Vermilion. Sight 0 is talk-only.
ROUTE6_GRIND = (
    {"id": "pokered:ROUTE_6:objects:3", "xy": (0, 15), "face": "RIGHT", "sight": 4},
    {"id": "pokered:ROUTE_6:objects:1", "xy": (10, 21), "face": "RIGHT", "sight": 0},
    {"id": "pokered:ROUTE_6:objects:2", "xy": (11, 21), "face": "LEFT", "sight": 0},
    {"id": "pokered:ROUTE_6:objects:6", "xy": (19, 26), "face": "LEFT", "sight": 3},
)
# Water and normal trainers first. The three electric parties stay last.
ROUTE11_GRIND = (
    {"id": "pokered:ROUTE_11:objects:1", "xy": (10, 14), "face": "DOWN", "sight": 3},
    {"id": "pokered:ROUTE_11:objects:3", "xy": (13, 5), "face": "LEFT", "sight": 3},
    {"id": "pokered:ROUTE_11:objects:5", "xy": (22, 4), "face": "UP", "sight": 4},
    {"id": "pokered:ROUTE_11:objects:10", "xy": (22, 12), "face": "UP", "sight": 4},
    {"id": "pokered:ROUTE_11:objects:2", "xy": (26, 9), "face": "DOWN", "sight": 2},
    {"id": "pokered:ROUTE_11:objects:8", "xy": (43, 5), "face": "RIGHT", "sight": 4},
    {"id": "pokered:ROUTE_11:objects:7", "xy": (33, 3), "face": "UP", "sight": 3},
    {"id": "pokered:ROUTE_11:objects:4", "xy": (36, 11), "face": "DOWN", "sight": 3},
    {"id": "pokered:ROUTE_11:objects:6", "xy": (45, 7), "face": "DOWN", "sight": 3},
    {"id": "pokered:ROUTE_11:objects:9", "xy": (45, 16), "face": "LEFT", "sight": 3},
)
ROUTE5_SKIP = {(9, 29), (10, 29), (10, 33), (10, 21)}
VERMILION_DOORS = {(11, 3), (9, 13), (23, 13), (12, 19), (23, 19), (18, 31), (19, 31), (15, 13)}
# Room doors and the lower stairs. The captain door stays closed until the rival leaves.
ANNE1_SKIP = {(31, 8), (23, 8), (19, 8), (15, 8), (11, 8), (7, 8), (37, 15), (3, 16)}
ANNE2_SKIP = {(9, 11), (13, 11), (17, 11), (21, 11), (25, 11), (29, 11), (2, 12), (36, 4)}
# Source coordinates. The gym pad is 1, so the runtime can is (x + 1, y).
# Second lock from GymTrashCans. Can 0 is a candidate for every first can.
TRASH_SECONDS = {
    0: (0, 3),
    2: (0, 5),
    4: (0, 7),
    6: (0, 3, 7, 9),
    8: (0, 5, 7, 11),
    10: (0, 13),
    12: (0, 13),
    14: (0, 13),
}
VERMILION_CANS = (
    (1, 7), (1, 9), (1, 11), (3, 7), (3, 9), (3, 11), (5, 7), (5, 9), (5, 11),
    (7, 7), (7, 9), (7, 11), (9, 7), (9, 9), (9, 11),
)
# Runtime tiles. The rocker's left sight is the south side of can 0.
GYM_SIGHT = {
    (9, 6), (8, 6), (7, 6), (10, 6),
    (3, 8), (2, 8), (4, 8),
    (2, 10), (3, 10), (4, 10), (1, 10),
}
VERMILION_CLERK = "pokered:VERMILION_MART:objects:1"
SS_RIVAL = "pokered:SS_ANNE_2F:objects:2"
CAPTAIN = "pokered:SS_ANNE_CAPTAINS_ROOM:objects:1"
SURGE = "pokered:VERMILION_GYM:objects:1"


def _quest(player):
    return ((player.state.get("session") or {}).get("flags") or {}).get("quest") or {}


def _blackout(player, kind, label):
    if kind == "blackout":
        raise RuntimeError(f"blackout at {label}: " + json.dumps(summary(player.state)))


def _stand(player, cells, goal, avoid, label, limit=40, potion_at=30):
    # route() rejects a start or goal that is listed as blocked. The player can
    # already be standing on a door that the rest of the walk must not re-enter.
    avoid = set(avoid)
    here = (player.state["player"]["x"], player.state["player"]["y"])
    avoid.discard(here)
    avoid.discard(tuple(goal))
    kind = player.travel(cells, goal, avoid, limit=limit, potion_at=potion_at)
    _settle_overlay(player)
    _blackout(player, kind, label)
    here = (player.state["player"]["x"], player.state["player"]["y"])
    if here != tuple(goal):
        raise RuntimeError(f"missed {label} {goal}: {kind} " + json.dumps(summary(player.state)))
    return kind


def _leave(player, cells, cells_and_dirs, avoid, zone_part, label):
    """Walk off one of the edge cells. The first that changes maps wins."""
    last = "stayed"
    here = (player.state["player"]["x"], player.state["player"]["y"])
    for cell, direction in cells_and_dirs:
        local = set(avoid)
        local.discard(here)
        local.discard(cell)
        last = leave_map(player, cells, cell, local, direction)
        _settle_overlay(player)
        _blackout(player, last, label)
        if zone_part in str(player.state.get("zone")):
            return last
    raise RuntimeError(f"{label} stayed: {last} " + json.dumps(summary(player.state)))


def _enter(player, cells, goal, avoid, direction, zone_part, label):
    kind = step_onto(player, cells, goal, avoid, direction)
    _settle_overlay(player)
    _blackout(player, kind, label)
    if zone_part not in str(player.state.get("zone")):
        raise RuntimeError(f"{label} did not open: {kind} " + json.dumps(summary(player.state)))
    return kind


def _bill(player, report, display, clips, output):
    """YES starts the separator. The PC is a hidden tile, then Bill gives the ticket."""
    cells = bills_house_cells()

    def receive():
        talked = talk_to(player, cells, BILL_POKEMON, set())
        report["bill_pokemon"] = {"result": talked, **summary(player.state)}
        if not player.exploring():
            player.dismiss_until_explore(limit=80)
        _stand(player, cells, (3, 5), set(), "Bill's PC")
        if player.state["player"].get("facing") != "up":
            player.press("up", wait=4)
        player.press("a", wait=8)
        if not player.exploring():
            # 134 ticks of the separator, then Bill walks out. A does not skip it.
            player.dismiss_until_explore(limit=160)
        talked = talk_to(player, cells, BILL, set())
        report["bill"] = {"result": talked, **summary(player.state)}
        if not player.exploring():
            player.dismiss_until_explore(limit=80)

    if display and clips and output:
        film(display, clips, output, "bill-ticket", report, "end", receive)
    else:
        receive()
    count = _item_count(player, "ssTicket")
    report["ss_ticket"] = {"count": count, "flag": _quest(player).get("EVENT_GOT_SS_TICKET"), **summary(player.state)}
    if player.exploring():
        report["saved_ticket"] = player.pause_save()
    if count < 1:
        raise RuntimeError("Bill did not give the S.S. Ticket: " + json.dumps(summary(player.state)))


def play_bill_vermilion(player, report, display, clips, output):
    """Gym exit, Bill's ticket, burgled house, Underground, Vermilion arrival."""
    player.leave_title()
    if not player.exploring():
        player.dismiss_until_explore(limit=40)
    report["resumed"] = summary(player.state)
    report["outcome_stamp"] = _outcome_stamp(player)
    bridge_avoid = {(10, 5), (11, 15), (5, 20)}
    if _item_count(player, "ssTicket") >= 1 and "vermilion_city" in str(player.state.get("zone")):
        report["vermilion"] = summary(player.state)
        report["vermilion_gym_path"] = route(
            vermilion_cells(),
            (player.state["player"]["x"], player.state["player"]["y"]),
            (12, 20),
            VERMILION_DOORS - {(12, 19)},
        ) is not None
        if player.exploring():
            report["saved_vermilion"] = player.pause_save()
        return
    if _item_count(player, "ssTicket") < 1:
        if "cerulean" not in str(player.state.get("zone")):
            raise RuntimeError("the ticket walk did not resume in Cerulean: " + json.dumps(summary(player.state)))
        if "gym" in str(player.state.get("zone")):
            _leave(player, cerulean_gym_cells(), [((5, 13), "down"), ((6, 13), "down")],
                   CERULEAN_GYM_AVOID, "cerulean_city", "gym exit")
        if _needs_heal(player) or ((player.state.get("pokemon") or {}).get("hp") or 0) < 40:
            _heal_in(player, report, cerulean_cells(), (19, 17), CERULEAN_NURSE,
                     cerulean_center_cells(), "before_bill", "cerulean_city",
                     avoid=CERULEAN_DOORS | {(15, 18), (30, 7), (30, 9)})
        _return_to_bridge(player, report)
        _stand(player, route24_cells(), (19, 8), bridge_avoid, "Route 24 east")
        _leave(player, route24_cells(), [((19, 8), "right"), ((19, 9), "right")],
               bridge_avoid, "route_25", "Route 25")
        _stand(player, route25_cells(), (45, 4), ROUTE25_SKIP, "Bill's door")
        _enter(player, route25_cells(), (45, 3), ROUTE25_SKIP, "up", "bills_house", "Bill's house")
        _bill(player, report, display, clips, output)
    if "bills_house" in str(player.state.get("zone")):
        _leave(player, bills_house_cells(), [((4, 7), "down"), ((5, 7), "down")],
           set(), "route_25", "Bill's exit")
    _stand(player, route25_cells(), (0, 9), ROUTE25_SKIP, "Route 25 west")
    _leave(player, route25_cells(), [((0, 9), "left"), ((0, 8), "left")],
           ROUTE25_SKIP, "route_24", "Route 24 return")
    _stand(player, route24_cells(), (11, 35), bridge_avoid, "Route 24 south")
    _leave(player, route24_cells(), [((11, 35), "down"), ((10, 35), "down")],
           bridge_avoid, "cerulean_city", "Cerulean return")
    if _needs_heal(player) or ((player.state.get("pokemon") or {}).get("hp") or 0) < 40:
        _heal_in(player, report, cerulean_cells(), (19, 17), CERULEAN_NURSE,
                 cerulean_center_cells(), "before_house", "cerulean_city",
                 avoid=CERULEAN_DOORS | {(15, 18), (30, 7), (30, 9)})
    house_doors = set(CERULEAN_DOORS) | {(15, 18), (30, 7), (30, 9)}
    house_doors.discard((27, 11))
    _enter(player, cerulean_cells(), (27, 11), house_doors, "up", "trashed_house", "burgled house")
    _enter(player, trashed_house_cells(), (5, 0), set(), "up", "cerulean_city", "burgled back door")
    # (27, 9) is the back door we just left. (30, 9) is the thief. (30, 10) is solid.
    _stand(player, cerulean_cells(), (30, 9), set(CERULEAN_DOORS) | {(15, 18)}, "Cerulean thief")
    south_avoid = set(CERULEAN_DOORS) | {(15, 18), (30, 8)}
    _stand(player, cerulean_cells(), (26, 35), south_avoid, "Cerulean south")
    _leave(player, cerulean_cells(), [((26, 35), "down"), ((25, 35), "down"), ((27, 35), "down"), ((28, 35), "down")],
           south_avoid, "route_5", "Route 5")
    _enter(player, route5_cells(), (17, 27), ROUTE5_SKIP, "up", "underground_path_route_5", "Route 5 underground")
    _enter(player, underground_route5_cells(), (6, 4), set(), "up", "underground_path_north_south", "north stairs")
    _enter(player, underground_corridor_cells(), (4, 41), set(), "down", "underground_path_route_6", "south stairs")
    _leave(player, underground_route6_cells(), [((5, 7), "down"), ((6, 7), "down")],
           set(), "route_6", "Route 6")

    def arrive():
        _stand(player, route6_cells(), (9, 35), ROUTE6_SKIP, "Route 6 south")
        _leave(player, route6_cells(), [((9, 35), "down"), ((8, 35), "down")],
               ROUTE6_SKIP, "vermilion_city", "Vermilion")

    if display and clips and output:
        film(display, clips, output, "vermilion", report, "end", arrive)
    else:
        arrive()
    report["vermilion"] = summary(player.state)
    if "vermilion_city" not in str(player.state.get("zone")):
        raise RuntimeError("Route 6 did not reach Vermilion: " + json.dumps(summary(player.state)))
    doors = set(VERMILION_DOORS)
    doors.discard((11, 3))
    _heal_in(player, report, vermilion_cells(), (11, 3), VERMILION_NURSE,
             vermilion_center_cells(), "vermilion", "vermilion_city", avoid=doors)
    here = (player.state["player"]["x"], player.state["player"]["y"])
    report["vermilion_gym_path"] = route(vermilion_cells(), here, (12, 20), VERMILION_DOORS - {(12, 19)}) is not None
    if player.exploring():
        report["saved_vermilion"] = player.pause_save()


def play_misty_assist(player, report, display, clips, output):
    """Nugget Bridge to level 20, eight Potions, then Bite-only Misty."""
    player.leave_title()
    if not player.exploring():
        player.dismiss_until_explore(limit=40)
    report["resumed"] = summary(player.state)
    report["outcome_stamp"] = _outcome_stamp(player)
    if "cerulean" not in str(player.state.get("zone")):
        raise RuntimeError("the assist did not resume in Cerulean: " + json.dumps(summary(player.state)))
    stocked = (_item_count(player, "potion") >= 8 and _item_count(player, "nugget") == 0
               and ((player.state.get("pokemon") or {}).get("level") or 0) >= 20)
    if not stocked:
        _prepare_misty(player, report)
    level = (player.state.get("pokemon") or {}).get("level") or 0
    report["level"] = level
    if level < 20:
        raise RuntimeError("Nugget Bridge ended below level 20: " + json.dumps(summary(player.state)))
    if _needs_heal(player) or ((player.state.get("pokemon") or {}).get("hp") or 0) < 40:
        _heal_in(player, report, cerulean_cells(), (19, 17), CERULEAN_NURSE,
                 cerulean_center_cells(), "before_misty", "cerulean_city",
                 avoid=CERULEAN_DOORS | {(15, 18), (30, 7), (30, 9)})
    if player.exploring():
        report["saved_before_gym"] = player.pause_save()
    _fight_misty(player, report, display, clips, output)


def _prepare_misty(player, report):
    """Bridge, Nugget, and eight Potions. The gym stays closed until this returns."""
    _heal_in(player, report, cerulean_cells(), (19, 17), CERULEAN_NURSE,
             cerulean_center_cells(), "before_bridge", "cerulean_city",
             avoid=CERULEAN_DOORS | {(15, 18), (30, 7), (30, 9)})
    # One Potion survives the rival's Vine Whip. The Nugget buy is still eight later.
    if _item_count(player, "potion") < 1 and _item_count(player, "nugget") < 1:
        money = int((player.state.get("inventory") or {}).get("money") or 0)
        if money >= 300:
            _sell_nugget_buy_potions(player, report, target=1)
    bodies = {(11, 31), (10, 28), (11, 25), (10, 22), (11, 19), (11, 15), (5, 20), (10, 5)}
    for spot in ((10, 31), (11, 28), (10, 25), (11, 22), (10, 19)):
        _bridge_spot(player, report, spot, bodies | {(10, 15)})
    _take_nugget(player, report)
    _bridge_spot(player, report, (5, 19), bodies)
    _heal_on_bridge(player, report, floor=51, come_back=False)
    _sell_nugget_buy_potions(player, report)
    report["level"] = (player.state.get("pokemon") or {}).get("level")


def _fight_misty(player, report, display, clips, output):
    """South door, Bite only, Potion at 26 or below."""
    gym_doors = set(CERULEAN_DOORS) | {(30, 7), (30, 9), (15, 18)}
    gym_doors.discard((30, 19))
    kind = step_onto(player, cerulean_cells(), (30, 19), gym_doors, "up")
    report["cerulean_gym_door"] = {"kind": kind, **summary(player.state)}
    if "gym" not in str(player.state.get("zone")):
        raise RuntimeError("Cerulean did not enter the gym: " + json.dumps(summary(player.state)))

    def battle_misty():
        cells = cerulean_gym_cells()
        kind = player.travel(cells, (6, 3), CERULEAN_GYM_AVOID, limit=20)
        report["lass_walk"] = {"kind": kind, **summary(player.state)}
        if player.state.get("root") == "battle":
            report["lass_won"] = player.fight(limit=900, potion_at=20)
            player.dismiss_until_explore(limit=80)
        talked = talk_to(player, cerulean_gym_cells(), MISTY, CERULEAN_GYM_AVOID)
        report["misty_talk"] = {"result": talked, **summary(player.state)}
        if player.state.get("root") == "battle" or talked == "talked":
            if player.state.get("root") != "battle":
                player.dismiss_until_explore(limit=20)
            if player.state.get("root") == "battle":
                report["misty_won"] = player.fight(limit=5000, potion_at=26, bite_only=True)
        else:
            raise RuntimeError("Misty did not battle: " + json.dumps(summary(player.state)))
        player.dismiss_until_explore(limit=120)

    if display and clips and output:
        film(display, clips, output, "gym-cerulean", report, "end", battle_misty)
    else:
        battle_misty()
    outcome = player.state.get("last_battle_outcome") or {}
    report["misty_outcome"] = outcome
    quest = ((player.state.get("session") or {}).get("flags") or {}).get("quest") or {}
    report["cascade"] = quest.get("BADGE_CASCADE")
    report["level"] = (player.state.get("pokemon") or {}).get("level")
    if player.exploring():
        report["saved_cascade"] = player.pause_save()
    if outcome.get("won") is not True or not quest.get("BADGE_CASCADE"):
        raise RuntimeError("Misty did not award the Cascade Badge: " + json.dumps(summary(player.state)))


def play_route4_line(player, report, display, clips, output):
    """Resume the (59, 4) pause and take the open line to Misty."""
    player.leave_title()
    if not player.exploring():
        player.dismiss_until_explore(limit=40)
    report["resumed"] = summary(player.state)
    _to_cerulean(player, report, display, clips, output)


def play_to_cerulean(player, report, display, clips, output):
    """Leave the Boulder Badge save, cross Route 3 and Mt. Moon, then try Cerulean."""
    player.leave_title()
    if not player.exploring():
        player.dismiss_until_explore(limit=40)
    zone = str(player.state.get("zone"))
    report["resumed"] = summary(player.state)
    if "mt_moon_b2f" in zone or "mt_moon_b1f" in zone:
        report["resumed_moon"] = summary(player.state)
        if _exit_moon(player, report) == "blackout":
            _from_route4(player, report, display, clips, output)
        else:
            _to_cerulean(player, report, display, clips, output)
        return
    if "route_4" in zone:
        report["resumed_route4"] = summary(player.state)
        if (player.state.get("player") or {}).get("x", 0) >= 20:
            _to_cerulean(player, report, display, clips, output)
        else:
            _from_route4(player, report, display, clips, output)
        return
    if "route_3" in zone:
        _cross_route3(player, report, display, clips, output)
        _from_route3_north(player, report, display, clips, output)
        return
    if "pewter_city" in zone:
        _cross_route3(player, report, display, clips, output)
        _from_route3_north(player, report, display, clips, output)
        return
    if "pewter_gym" not in zone:
        raise RuntimeError("continue did not resume a walked save: " + json.dumps(summary(player.state)))
    kind = player.travel( gym_cells(), (5, 12), set(), limit=8)
    report["gym_exit_walk"] = kind
    if kind != "arrived":
        raise RuntimeError("could not reach the gym door: " + json.dumps(summary(player.state)))
    kind = step_onto(player, gym_cells(), (5, 13), set(), "down")
    report["gym_left"] = {"kind": kind, "zone": player.state.get("zone"), "at": summary(player.state)}
    if player.state.get("zone") != "kanto_pewter_city":
        raise RuntimeError("gym door did not return to Pewter: " + json.dumps(summary(player.state)))
    _cross_route3(player, report, display, clips, output)
    _from_route3_north(player, report, display, clips, output)


def _from_route3_north(player, report, display, clips, output):
    kind = leave_map(player, route3_cells(), (59, 0), set(), "up")
    report["route4_enter"] = {"kind": kind, "zone": player.state.get("zone"), "at": summary(player.state)}
    if player.state.get("zone") != "kanto_route_4":
        raise RuntimeError("Route 3's north edge did not open Route 4: " + json.dumps(summary(player.state)))
    if player.exploring():
        report["saved_route4"] = player.pause_save()
        _keep_bird_save(report)
    _from_route4(player, report, display, clips, output)


def _from_route4(player, report, display, clips, output):
    for attempt in range(3):
        zone = str(player.state.get("zone"))
        if "pewter" in zone or "route_3" in zone:
            _cross_route3(player, report, display, clips, output)
            kind = leave_map(player, route3_cells(), (59, 0), set(), "up")
            report["route4_reenter"] = {"kind": kind, **summary(player.state)}
        if "route_4" in str(player.state.get("zone")):
            if _needs_heal(player):
                _heal_in(player, report, route4_cells(), (11, 5),
                         "pokered:MT_MOON_POKECENTER:objects:1", moon_center_cells(), "moon_heal", "route_4")
            kind = player.travel(route4_cells(), (18, 6), set(), limit=12)
            report["cave_approach"] = kind
            if kind != "arrived":
                raise RuntimeError("could not reach Mt. Moon: " + json.dumps(summary(player.state)))
            kind = step_onto(player, route4_cells(), (18, 5), set(), "up")
            report["moon_enter"] = {"kind": kind, "zone": player.state.get("zone"), "at": summary(player.state)}
        if player.state.get("zone") != "kanto_mt_moon_1f":
            raise RuntimeError("Mt. Moon entrance did not open: " + json.dumps(summary(player.state)))
        if _descend(player, report, display, clips, output) != "blackout":
            break
        report[f"moon_blackout_{attempt}"] = summary(player.state)
    else:
        raise RuntimeError("Mt. Moon blacked out three times: " + json.dumps(summary(player.state)))
    if player.state.get("zone") != "kanto_route_4":
        raise RuntimeError("Mt. Moon did not return to Route 4: " + json.dumps(summary(player.state)))
    if _quest(player).get("BADGE_CASCADE"):
        _enter_cerulean(player, report)
    else:
        _to_cerulean(player, report, display, clips, output)


def route4_open_line():
    """(59, 4) goes down, east through (60, 6), then two ledge hops onto y=10.

    (60, 4) is foot 0x27 and is not a step. The west mountain at x=23 is not a step.
    The first down from (76, 6) hops the 0x39/0x36 pair onto (76, 8). The second
    hops that pair again onto (76, 10). East from (89, 10) is Cerulean (0, 18).
    """
    steps = [("down", (59, 5)), ("down", (59, 6))]
    for x in range(60, 77):
        steps.append(("right", (x, 6)))
    steps.append(("down", (76, 8)))
    steps.append(("down", (76, 10)))
    for x in range(77, 90):
        steps.append(("right", (x, 10)))
    steps.append(("right", "cerulean"))
    return steps


# Swimmer sight and body, the lass's body, Misty, and the guide. The lass's
# sight row is the only way onto Misty's tile, so it stays walkable.
CERULEAN_LASS_SIGHT = {(4, 3), (5, 3), (6, 3)}
CERULEAN_GYM_AVOID = {(3, 3), (5, 2), (6, 7), (7, 7), (8, 7), (9, 7), (8, 10)}
CERULEAN_DOORS = {(4, 11), (9, 9), (9, 11), (13, 15), (13, 25), (19, 17), (25, 25), (27, 9), (27, 11), (30, 19)}


def route4_cite(x, y):
    """Source grid id, foot tile, and collision for one Route 4 cell."""
    data = json.loads((ROOT / "Source/data/sourceSlice/Route4.json").read_text(encoding="utf-8"))
    grid_id = data["tile_ids"][y][x]
    grid = next(item for item in data["grids"] if item["id"] == grid_id)
    foot = grid["terrain"]["foot_tile"]
    return {
        "x": x, "y": y, "grid_id": grid_id, "foot_tile": foot, "foot_hex": hex(foot),
        "collision": data["collision"][y][x],
        "land_passable": grid["terrain"]["land_passable"],
    }


def probe_west(player, report, display, clips, output):
    """Walk west from the Route 4 cliff. Do not step east into foot 0x27."""
    del display, clips, output
    player.leave_title()
    if not player.exploring():
        player.dismiss_until_explore(limit=40)
    report["resumed"] = summary(player.state)
    if player.state.get("zone") != "kanto_route_4":
        raise RuntimeError("west probe did not resume Route 4: " + json.dumps(summary(player.state)))
    kind = player.travel(route4_cells(), (24, 6), set(), limit=20)
    report["west_walk"] = {"kind": kind, **summary(player.state)}
    if kind != "arrived":
        raise RuntimeError("west probe did not reach the wall: " + json.dumps(summary(player.state)))
    kind = player.step("left")
    stood = player.state.get("player") or {}
    report["west_step"] = {
        "kind": kind,
        "x": stood.get("x"), "y": stood.get("y"), "facing": stood.get("facing"),
        "block": stood.get("lastTraversalBlock"),
        "runtime_tile": stood.get("tile"),
    }
    report["stand"] = route4_cite(stood.get("x"), stood.get("y"))
    report["ahead"] = route4_cite((stood.get("x") or 0) - 1, stood.get("y"))
    if player.exploring():
        report["saved_west"] = player.pause_save()
    if kind == "blocked" and player.state.get("zone") == "kanto_route_4":
        ahead = report["ahead"]
        raise RuntimeError(
            "west blocked at ({x},{y}) grid {grid_id} foot {foot_hex} collision {collision}; "
            "the Center is on the far side and there is no land gap".format(**ahead)
            + ": " + json.dumps(report["west_step"]))
    report["west_open"] = summary(player.state)


def _exit_moon(player, report):
    """Leave B2F through the stair at (5, 7). The walk to (6, 7) must not step on it."""
    if "b2f" in str(player.state.get("zone")):
        avoid = set(MOON_B2_AVOID)
        avoid.add((5, 7))
        avoid.add((13, 7))
        here = (player.state["player"]["x"], player.state["player"]["y"])
        if here != (6, 7):
            kind = player.travel(moon_b2_cells(), (6, 7), avoid, limit=40, blocked_edges=MOON_B2_EDGES)
            report["moon_b2_exit"] = kind
            if "pewter" in str(player.state.get("zone")):
                return "blackout"
            if not (kind == "warp" and player.state.get("zone") == "kanto_mt_moon_b1f"):
                if kind != "arrived":
                    raise RuntimeError("could not cross Mt. Moon B2F: " + json.dumps(summary(player.state)))
                kind = step_onto(player, moon_b2_cells(), (5, 7), MOON_B2_AVOID, "left", MOON_B2_EDGES)
                report["moon_exit_stairs"] = {"kind": kind, "zone": player.state.get("zone")}
        else:
            kind = step_onto(player, moon_b2_cells(), (5, 7), MOON_B2_AVOID, "left", MOON_B2_EDGES)
            report["moon_exit_stairs"] = {"kind": kind, "zone": player.state.get("zone")}
        if "pewter" in str(player.state.get("zone")):
            return "blackout"
        if player.state.get("zone") != "kanto_mt_moon_b1f":
            raise RuntimeError("B2F stairs did not return to B1F: " + json.dumps(summary(player.state)))
    if player.state.get("zone") != "kanto_mt_moon_b1f":
        raise RuntimeError("Mt. Moon exit started off the cave floors: " + json.dumps(summary(player.state)))
    here = (player.state["player"]["x"], player.state["player"]["y"])
    if here != (26, 3):
        kind = player.travel(moon_b1_cells(), (26, 3), set(), limit=20, blocked_edges=MOON_B1_EDGES)
        report["moon_exit_walk"] = kind
        if "pewter" in str(player.state.get("zone")):
            return "blackout"
        if kind != "arrived":
            raise RuntimeError("could not reach the cave exit: " + json.dumps(summary(player.state)))
    kind = step_onto(player, moon_b1_cells(), (27, 3), set(), "right", MOON_B1_EDGES)
    report["moon_exit"] = {"kind": kind, "zone": player.state.get("zone"), "at": summary(player.state)}
    return "through"


def _follow_route4_line(player, report):
    """Walk the open Route 4 line. Never step right on y=4 or west into x=23."""
    if player.state.get("zone") != "kanto_route_4":
        raise RuntimeError("Route 4 line did not resume the cliff: " + json.dumps(summary(player.state)))
    here = (player.state["player"]["x"], player.state["player"]["y"])
    if here[0] < 24:
        raise RuntimeError("refusing the west mountain at x=23: " + json.dumps(summary(player.state)))
    report["line_start"] = summary(player.state)
    for direction, expect in route4_open_line():
        if not player.exploring():
            if player.state.get("root") == "battle":
                player.fight()
            player.dismiss_until_explore(limit=40)
        if player.state.get("zone") == "kanto_cerulean_city" and expect == "cerulean":
            report["cerulean_entry"] = summary(player.state)
            return
        stood = (player.state["player"]["x"], player.state["player"]["y"])
        if stood[1] == 4 and direction == "right":
            raise RuntimeError("refusing the solid 0x27 step at (60,4)")
        if direction == "left" or (isinstance(expect, tuple) and expect[0] < 59):
            raise RuntimeError("refusing a west step off the open line")
        kind = player.step(direction)
        if kind == "overlay" or player.state.get("root") == "battle":
            if player.state.get("root") == "battle":
                player.fight()
            player.dismiss_until_explore(limit=40)
        if expect == "cerulean":
            if player.state.get("zone") != "kanto_cerulean_city":
                player.settle(limit=40)
                if not player.exploring():
                    player.dismiss_until_explore(limit=40)
            report["cerulean_entry"] = {"kind": kind, **summary(player.state)}
            if player.state.get("zone") != "kanto_cerulean_city":
                raise RuntimeError("Route 4 east did not open Cerulean: " + json.dumps(summary(player.state)))
            return
        landed = (player.state["player"]["x"], player.state["player"]["y"])
        if landed != expect or player.state.get("zone") != "kanto_route_4":
            report["line_miss"] = {"direction": direction, "expect": expect, "kind": kind, **summary(player.state)}
            raise RuntimeError(
                f"Route 4 line missed {expect} after {direction}: " + json.dumps(summary(player.state)))
    raise RuntimeError("Route 4 line ended before Cerulean")


CERULEAN_CLERK = "pokered:CERULEAN_MART:objects:1"


def _item_count(player, item):
    return int(((player.state.get("inventory") or {}).get("quantities") or {}).get(item) or 0)


def _shop_buy_potions(player, target):
    """Buy Potions until target or the 300 price no longer fits. Leaves the list open."""
    buying = False
    have = _item_count(player, "potion")
    for _ in range(30):
        shop = player.state.get("shop") or {}
        phase = shop.get("phase")
        have = _item_count(player, "potion")
        money = int((player.state.get("inventory") or {}).get("money") or 0)
        if (have >= target or money < 300) and phase in ("browse", "mode") and buying:
            return have
        if phase == "mode":
            player.choose("shop", "BUY")
            buying = True
        elif phase == "browse" and not buying:
            player.press("b", wait=4)
        elif phase == "browse":
            if shop.get("item") == "potion":
                player.press("a", wait=4)
            else:
                player.press("down", wait=2)
        elif phase == "quantity":
            want = min(target - have, money // 300)
            quantity = shop.get("quantity") or 1
            if want < 1:
                player.press("b", wait=4)
            elif quantity < want:
                player.press("up", wait=2)
            else:
                player.press("a", wait=4)
        elif phase == "confirm":
            player.choose("shop", "YES")
        elif phase == "result":
            player.press("a", wait=4)
        else:
            player.send("wait 4")
    return have


def _buy_cerulean_potions(player, report, target=8, require=8):
    """Buy Potions, sell TM34, and buy what that pays for.

    Starmie's Recover outlasts five Potions. TM34 is Bide and sells for 1000.
    Quit and leave as soon as the bag holds the target.
    """
    if _item_count(player, "potion") >= target and _item_count(player, "tm34") == 0:
        report["potions"] = _item_count(player, "potion")
        return
    doors = set(CERULEAN_DOORS)
    doors.discard((25, 25))
    kind = step_onto(player, cerulean_cells(), (25, 25), doors | {(15, 18)}, "up")
    report["cerulean_mart_door"] = {"kind": kind, **summary(player.state)}
    if "mart" not in str(player.state.get("zone")):
        raise RuntimeError("Cerulean Mart did not open: " + json.dumps(summary(player.state)))
    cells = cerulean_mart_cells()
    opened = False
    for _ in range(8):
        if player.state.get("root") == "shop":
            opened = True
            break
        if not player.exploring():
            player.dismiss_until_explore(limit=20)
        npc = npc_named(player.state, CERULEAN_CLERK)
        if npc is None:
            break
        spot = (npc["x"] + 2, npc["y"])
        kind = player.travel(cells, spot, {(npc["x"], npc["y"])})
        if kind != "arrived":
            continue
        if player.state["player"].get("facing") != "left":
            player.press("left", wait=4)
        player.press("a", wait=8)
        if player.state.get("root") == "shop":
            opened = True
            break
    if not opened:
        raise RuntimeError("the clerk did not open the mart: " + json.dumps(summary(player.state)))
    for _ in range(24):
        shop = player.state.get("shop") or {}
        phase = shop.get("phase")
        have = int(((player.state.get("inventory") or {}).get("quantities") or {}).get("potion") or 0)
        if have >= 5 and phase in ("browse", "mode"):
            break
        if phase == "mode":
            player.choose("shop", "BUY")
        elif phase == "browse":
            if shop.get("item") == "potion":
                player.press("a", wait=4)
            else:
                selected = shop.get("selected") or 1
                player.press("down" if selected < 2 else "up", wait=2)
        elif phase == "quantity":
            quantity = shop.get("quantity") or 1
            if quantity < 5:
                player.press("up", wait=2)
            else:
                player.press("a", wait=4)
        elif phase == "confirm":
            player.choose("shop", "YES")
        elif phase == "result":
            player.press("a", wait=4)
        else:
            player.send("wait 4")
    have = _item_count(player, "potion")
    if have < 5:
        raise RuntimeError("the mart did not sell five Potions: " + json.dumps(summary(player.state)))
    if _item_count(player, "tm34") >= 1:
        armed = False
        for _ in range(24):
            if _item_count(player, "tm34") == 0:
                break
            shop = player.state.get("shop") or {}
            phase = shop.get("phase")
            if phase == "browse" and not armed:
                player.press("b", wait=4)
            elif phase == "mode":
                player.choose("shop", "SELL")
                armed = True
            elif phase == "browse":
                if shop.get("item") == "tm34":
                    player.press("a", wait=4)
                else:
                    player.press("down", wait=2)
            elif phase == "quantity":
                if (shop.get("quantity") or 1) == 1 and shop.get("item") == "tm34":
                    player.press("a", wait=4)
                else:
                    player.press("b", wait=4)
            elif phase == "confirm":
                player.choose("shop", "YES")
            elif phase == "result":
                player.press("a", wait=4)
            else:
                player.send("wait 4")
        if _item_count(player, "tm34") != 0:
            raise RuntimeError("TM34 did not sell: " + json.dumps(summary(player.state)))
        _shop_buy_potions(player, target)
    if _item_count(player, "tm34") == 0 and _item_count(player, "potion") < target:
        _shop_buy_potions(player, target)
    have = _item_count(player, "potion")
    report["potions"] = have
    report["money"] = int((player.state.get("inventory") or {}).get("money") or 0)
    if have < require:
        raise RuntimeError("the mart did not stock eight Potions: " + json.dumps(summary(player.state)))
    for _ in range(8):
        if player.state.get("root") != "shop":
            break
        phase = (player.state.get("shop") or {}).get("phase")
        if phase == "browse":
            player.press("b", wait=4)
        elif phase == "mode":
            player.choose("shop", "QUIT")
        else:
            player.press("b", wait=4)
    if player.state.get("root") == "shop":
        raise RuntimeError("the mart stayed open: " + json.dumps(summary(player.state)))
    # The clerk's neighbor walks the whole x=5 column. Wait for a gap, then use either mat.
    kind = "stayed"
    for _ in range(12):
        if "cerulean_city" in str(player.state.get("zone")):
            break
        for door in ((6, 7), (5, 7)):
            kind = step_onto(player, cells, door, set(), "down")
            if "cerulean_city" in str(player.state.get("zone")):
                break
        else:
            player.send("wait 18")
            continue
        break
    report["cerulean_mart_left"] = {"kind": kind, **summary(player.state)}
    if "cerulean_city" not in str(player.state.get("zone")):
        raise RuntimeError("still inside the mart: " + json.dumps(summary(player.state)))
    if player.exploring():
        report["saved_potions"] = player.pause_save()


def _to_cerulean(player, report, display, clips, output):
    """Route 4's open line, then the Cerulean Center and Misty."""
    if player.state.get("zone") == "kanto_route_4":
        if player.exploring() and (player.state["player"]["x"], player.state["player"]["y"]) != (59, 4):
            report["saved_route4_exit"] = player.pause_save()
        here = (player.state["player"]["x"], player.state["player"]["y"])
        if here != (59, 4) and here[0] >= 24 and route(route4_cells(), here, (59, 4)) is not None:
            kind = player.travel(route4_cells(), (59, 4), set(), limit=20)
            report["cliff"] = {"kind": kind, "at": summary(player.state)}
            if kind != "arrived":
                raise RuntimeError("could not reach the Route 4 cliff: " + json.dumps(summary(player.state)))
        _follow_route4_line(player, report)
    if player.state.get("zone") != "kanto_cerulean_city":
        raise RuntimeError("Cerulean did not open: " + json.dumps(summary(player.state)))
    report["cerulean"] = summary(player.state)
    if _needs_heal(player):
        _heal_in(player, report, cerulean_cells(), (19, 17), CERULEAN_NURSE,
                 cerulean_center_cells(), "cerulean_heal", "cerulean_city",
                 avoid=CERULEAN_DOORS | {(15, 18)})
    _buy_cerulean_potions(player, report)
    gym_doors = set(CERULEAN_DOORS)
    gym_doors.discard((30, 19))
    kind = step_onto(player, cerulean_cells(), (30, 19), gym_doors | {(15, 18)}, "up")
    report["cerulean_gym_door"] = {"kind": kind, **summary(player.state)}
    if "gym" not in str(player.state.get("zone")):
        raise RuntimeError("Cerulean did not enter the gym: " + json.dumps(summary(player.state)))

    def battle_misty():
        cells = cerulean_gym_cells()
        # The Lass watches every tile in front of Misty. Beat her first.
        kind = player.travel(cells, (6, 3), CERULEAN_GYM_AVOID, limit=20)
        report["lass_walk"] = {"kind": kind, **summary(player.state)}
        if player.state.get("root") == "battle":
            report["lass_won"] = player.fight(limit=900, potion_at=20)
            player.dismiss_until_explore(limit=80)
        if "gym" not in str(player.state.get("zone")):
            raise RuntimeError("the Lass fight left the gym: " + json.dumps(summary(player.state)))
        hp = (player.state.get("pokemon") or {}).get("hp") or 0
        if hp < 40:
            kind = step_onto(player, cells, (5, 13), CERULEAN_GYM_AVOID, "down")
            report["gym_heal_exit"] = {"kind": kind, **summary(player.state)}
            if "cerulean_city" not in str(player.state.get("zone")):
                raise RuntimeError("the gym exit did not open: " + json.dumps(summary(player.state)))
            _heal_in(player, report, cerulean_cells(), (19, 17), CERULEAN_NURSE,
                     cerulean_center_cells(), "cerulean_heal_again", "cerulean_city",
                     avoid=CERULEAN_DOORS | {(15, 18)})
        if "gym" not in str(player.state.get("zone")):
            doors = set(CERULEAN_DOORS)
            doors.discard((30, 19))
            kind = step_onto(player, cerulean_cells(), (30, 19), doors | {(15, 18)}, "up")
            report["gym_return"] = {"kind": kind, **summary(player.state)}
            if "gym" not in str(player.state.get("zone")):
                raise RuntimeError("Cerulean did not re-enter the gym: " + json.dumps(summary(player.state)))
        talked = talk_to(player, cerulean_gym_cells(), MISTY, CERULEAN_GYM_AVOID)
        report["misty_talk"] = {"result": talked, **summary(player.state)}
        if player.state.get("root") == "battle" or talked == "talked":
            if player.state.get("root") != "battle":
                player.dismiss_until_explore(limit=20)
            if player.state.get("root") == "battle":
                report["misty_won"] = player.fight(limit=5000, potion_at=26, bite_only=True)
        else:
            raise RuntimeError("Misty did not battle: " + json.dumps(summary(player.state)))
        player.dismiss_until_explore(limit=120)

    if display and clips and output:
        film(display, clips, output, "gym-cerulean", report, "end", battle_misty)
    else:
        battle_misty()
    outcome = player.state.get("last_battle_outcome") or {}
    report["misty_outcome"] = outcome
    quest = ((player.state.get("session") or {}).get("flags") or {}).get("quest") or {}
    report["cascade"] = quest.get("BADGE_CASCADE")
    if player.exploring():
        report["saved_cascade"] = player.pause_save()
    if outcome.get("won") is not True or not quest.get("BADGE_CASCADE"):
        raise RuntimeError("Misty did not award the Cascade Badge: " + json.dumps(summary(player.state)))


def take_dome_fossil(player, report):
    """The Dome Fossil sprite blocks the only stairs to the exit. Face it and accept YES."""
    for _ in range(4):
        if "pewter" in str(player.state.get("zone")):
            return "blackout"
        player_state = player.state.get("player") or {}
        cell = (player_state.get("x"), player_state.get("y"))
        if cell != (12, 7):
            kind = player.travel(moon_b2_cells(), (12, 7), MOON_B2_AVOID, limit=12, blocked_edges=MOON_B2_EDGES)
            if kind != "arrived":
                break
            continue
        if player_state.get("facing") != "up":
            player.press("up", wait=8)
            if player.state.get("root") != "overworld":
                player.dismiss_until_explore(limit=40)
            continue
        player.press("a", wait=8)
        player.dismiss_until_explore(limit=120)
        quantities = (player.state.get("inventory") or {}).get("quantities") or {}
        if int(quantities.get("domeFossil") or 0) >= 1:
            report["fossil"] = summary(player.state)
            if player.exploring():
                report["saved_fossil"] = player.pause_save()
            return "taken"
    raise RuntimeError("Dome Fossil was not taken: " + json.dumps(summary(player.state)))


def _descend(player, report, display, clips, output):
    """1F stairs, B1F to B2F, back up at the Route 4 exit stairs."""
    avoid = moon_avoid()

    def cross_floor():
        return player.travel(moon_cells(), (6, 5), avoid | MOON_1F_SKIP, limit=40, blocked_edges=MOON_1F_EDGES)

    kind = film(display, clips, output, "mt-moon", report, "end", cross_floor)
    report["moon_1f"] = {"kind": kind, **summary(player.state)}
    if "pewter" in str(player.state.get("zone")):
        return "blackout"
    if (player.state["player"]["x"], player.state["player"]["y"]) != (6, 5):
        raise RuntimeError("could not cross Mt. Moon 1F: " + json.dumps(summary(player.state)))
    kind = step_onto(player, moon_cells(), (5, 5), avoid | MOON_1F_SKIP, "left", MOON_1F_EDGES)
    report["moon_b1_enter"] = {"kind": kind, "zone": player.state.get("zone")}
    if player.state.get("zone") != "kanto_mt_moon_b1f":
        raise RuntimeError("1F stairs did not open B1F: " + json.dumps(summary(player.state)))
    kind = player.travel(moon_b1_cells(), (21, 16), set(), limit=40, blocked_edges=MOON_B1_EDGES)
    report["moon_b1"] = kind
    if "pewter" in str(player.state.get("zone")):
        return "blackout"
    if kind != "arrived":
        raise RuntimeError("could not cross Mt. Moon B1F: " + json.dumps(summary(player.state)))
    kind = step_onto(player, moon_b1_cells(), (21, 17), set(), "down", MOON_B1_EDGES)
    report["moon_b2_enter"] = {"kind": kind, "zone": player.state.get("zone")}
    if player.state.get("zone") != "kanto_mt_moon_b2f":
        raise RuntimeError("B1F stairs did not open B2F: " + json.dumps(summary(player.state)))
    if _item_count(player, "domeFossil") >= 1:
        # The fossil is already taken. The nerd now stands on (13, 7), and (12, 8) is the way past him.
        avoid = (set(MOON_B2_AVOID) - {(12, 8)}) | {(5, 7), (13, 7)}
        here = (player.state["player"]["x"], player.state["player"]["y"])
        avoid.discard(here)
        kind = player.travel(moon_b2_cells(), (6, 7), avoid, limit=40, blocked_edges=MOON_B2_EDGES)
        report["moon_b2"] = kind
        if "pewter" in str(player.state.get("zone")):
            return "blackout"
        if (player.state["player"]["x"], player.state["player"]["y"]) != (6, 7):
            raise RuntimeError("could not reach the Mt. Moon exit: " + json.dumps(summary(player.state)))
        return _exit_moon(player, report)
    kind = player.travel(moon_b2_cells(), (12, 7), MOON_B2_AVOID, limit=40, blocked_edges=MOON_B2_EDGES)
    report["moon_b2"] = kind
    if "pewter" in str(player.state.get("zone")):
        return "blackout"
    if kind != "arrived":
        raise RuntimeError("could not reach the Dome Fossil: " + json.dumps(summary(player.state)))
    if take_dome_fossil(player, report) == "blackout":
        return "blackout"
    return _exit_moon(player, report)


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
    report = {"session": session, "build": metadata.get("build_id"), "clips": [],
              "save_copied": report_copied, "data_dir": str(data)}
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


def _can_index(quest, name):
    value = 0
    for bit in range(4):
        if quest.get(f"VERMILION_SCENE_V1_{name}_{bit}"):
            value |= 1 << bit
    return value


def _member(player, species):
    for index, mon in enumerate((player.state.get("party") or {}).get("members") or [], start=1):
        if mon.get("species") == species:
            return index, mon
    return None, None


def _menu_label(player, key, text):
    options = player.menu(key).get("options") or []
    for label in options:
        if label == text or text in label:
            return label
    raise RuntimeError(f"{key} has no {text}: {options}")


def _through_scene(player, limit=6):
    """Clear an event. The ship clock needs a long wait; A does not skip it."""
    for _ in range(limit):
        if player.exploring():
            return "explore"
        if player.state.get("root") == "battle":
            return "battle"
        event = player.state.get("event") or {}
        phase = event.get("phase")
        zone = str(player.state.get("zone"))
        if phase == "vermilion-departure":
            step = 100
        elif "captains" in zone or "CAPTAINS_ROOM" in str(event.get("id") or ""):
            # Rub, the recovery, and the HM01 pages run longer than a sign.
            step = 160
        elif "gym" in zone:
            # Erika's greeting is nineteen lines. Forty presses stop on line 11.
            step = 160
        else:
            step = 40
        if not player.dismiss_until_explore(limit=step) and player.state.get("root") == "battle":
            return "battle"
        if player.exploring():
            return "explore"
    raise RuntimeError("scene did not finish: " + json.dumps(summary(player.state)))


def _lost(before, after):
    """A run is not a blackout. Defeat is."""
    if not after or after == before or after.get("kind") == "run":
        return False
    return after.get("won") is False or after.get("blackout") is True


def _decline_new_move(player):
    """NO on the learn question, then YES to abandon it. Whirlwind is 17 in B2W2."""
    for _ in range(16):
        if player.state.get("root") != "learning":
            return
        learning = player.state.get("learning") or {}
        phase = learning.get("phase")
        menu = learning.get("menu") or {}
        if phase in (None, "message", "closed") or learning.get("dialog_ready"):
            if learning.get("dialog_ready") or phase == "message":
                player.press("a", wait=6)
            else:
                player.send("wait 6")
        elif phase == "ask" and not menu.get("active"):
            player.press("a", wait=6)
        elif phase == "ask":
            selected = menu.get("selected") or 1
            if selected != 2:
                player.press("down", wait=2)
            else:
                player.press("a", wait=6)
        elif phase == "stop":
            selected = menu.get("selected") or 1
            if selected != 1:
                player.press("up", wait=2)
            else:
                player.press("a", wait=6)
        else:
            player.press("b", wait=4)


def _send_out(player, prefer):
    phase = (player.state.get("party_ui") or {}).get("phase")
    if phase == "notice":
        player.press("a", wait=4)
        return
    slot = None
    if prefer:
        slot, mon = _member(player, prefer)
        if mon and (mon.get("hp") or 0) <= 0:
            slot = None
        if slot is None and prefer == "pidgeotto":
            for evolved in ("pidgeot", "pidgey"):
                slot, mon = _member(player, evolved)
                if mon and (mon.get("hp") or 0) > 0:
                    break
                slot = None
    if slot is None:
        for want in ("wartortle", "blastoise", "squirtle"):
            slot, mon = _member(player, want)
            if mon and (mon.get("hp") or 0) > 0:
                break
            slot = None
        if slot is None:
            for index, mon in enumerate(((player.state.get("party") or {}).get("members") or []), start=1):
                if (mon.get("hp") or 0) > 0:
                    slot = index
                    break
    if slot is None:
        raise RuntimeError("no pokemon to send: " + json.dumps(summary(player.state)))
    _select_party(player, slot)
    player.press("a", wait=8)


def _settle_catch(player):
    """Dex page, nickname NO, then the battle's last page. B declines the nickname."""
    for _ in range(80):
        if player.exploring():
            return
        root = player.state.get("root")
        if root == "naming":
            player.press("b", wait=8)
        elif root == "pokedex":
            player.press("a", wait=8)
        elif root == "dialog":
            dialog = player.state.get("dialog") or {}
            if dialog.get("ready"):
                player.press("a", wait=6)
            else:
                player.send("wait 6")
        elif root == "battle":
            battle = player.state.get("battle") or {}
            if battle.get("phase") in ("ended", "script") or battle.get("waiting"):
                player.send("wait 8", "press a", max_frames=200)
            else:
                player.send("wait 4")
        elif root == "learning":
            _decline_new_move(player)
        else:
            player.dismiss_until_explore(limit=8)
    raise RuntimeError("catch did not return to the field: " + json.dumps(summary(player.state)))


def _throw_ball(player):
    """Throw one Poké Ball. Returns caught, miss, or left."""
    # The encounter intro is a script page. BAG is absent until the command menu opens.
    for _ in range(24):
        battle = player.state.get("battle") or {}
        options = (battle.get("menu") or {}).get("options") or []
        if battle.get("inMoveSelect"):
            player.press("b", wait=4)
        elif "BAG" in options and battle.get("phase") == "command":
            break
        elif battle.get("phase") == "script" and battle.get("waiting"):
            player.send("wait 8", "press a", max_frames=200)
        elif battle.get("phase") == "ended":
            return "left"
        else:
            player.send("wait 4")
    else:
        options = ((player.state.get("battle") or {}).get("menu") or {}).get("options") or []
        raise RuntimeError(f"battle command menu never offered BAG: {options}")
    player.choose("battle", "BAG")
    for _ in range(16):
        root = player.state.get("root")
        if root == "battle":
            break
        if root != "bag":
            player.send("wait 4")
            continue
        bag = player.state.get("bag") or {}
        if bag.get("phase") not in (None, "list", "closed"):
            player.press("a", wait=4)
            continue
        slots = (player.state.get("inventory") or {}).get("slots") or []
        index = next((i for i, slot in enumerate(slots, start=1) if slot.get("id") == "pokeBall"), None)
        if index is None:
            player.press("b", wait=4)
            return "left"
        selected = bag.get("selected") or 1
        if selected != index:
            player.press("down" if index > selected else "up", wait=2)
        else:
            player.press("a", wait=8)
    seen_script = False
    for tick in range(50):
        if player.state.get("root") != "battle":
            return "left"
        battle = player.state.get("battle") or {}
        phase = battle.get("phase")
        if phase == "ended":
            player.send("wait 12", "press a", max_frames=200)
        elif phase == "script":
            seen_script = True
            if battle.get("waiting"):
                player.send("wait 12", "press a", max_frames=200)
            else:
                player.send("wait 4")
        elif phase == "command" and not battle.get("inMoveSelect") and (seen_script or tick > 12):
            return "miss"
        else:
            player.send("wait 4")
    return "left" if player.state.get("root") != "battle" else "miss"


def _catch_wild(player, species):
    before = (player.state.get("party") or {}).get("count") or 1
    for _ in range(6):
        if player.state.get("root") != "battle":
            break
        if _item_count(player, "pokeBall") < 1:
            break
        _throw_ball(player)
        count = (player.state.get("party") or {}).get("count") or before
        if count > before or _member(player, species)[0]:
            _settle_catch(player)
            return True
        hp = ((player.state.get("pokemon") or {}).get("hp") or 0)
        if hp < 20:
            break
    if player.state.get("root") == "battle":
        if not player.run_away():
            before_outcome = player.state.get("last_battle_outcome")
            player.fight(limit=400, potion_at=34)
            after = player.state.get("last_battle_outcome") or {}
            if _lost(before_outcome, after):
                raise RuntimeError("blackout while catching: " + json.dumps(summary(player.state)))
        player.dismiss_until_explore(limit=30)
    _settle_catch(player)
    return _member(player, species)[0] is not None


def _hunt(player, cells, left, right, species, limit=30):
    """Pace two grass cells. Ball the target and run from everything else."""
    encounters = 0
    goal = right
    for _ in range(limit * 12):
        if _member(player, species)[0]:
            return True
        if encounters >= limit or _item_count(player, "pokeBall") < 1:
            return False
        if not player.exploring():
            if player.state.get("root") == "battle":
                pass
            else:
                _through_scene(player, 4)
                continue
        here = (player.state["player"]["x"], player.state["player"]["y"])
        if here == goal:
            goal = left if goal == right else right
        steps = route(cells, here, goal, set())
        if not steps:
            return False
        kind = player.step(steps[0])
        if kind not in ("overlay", "warp") and player.state.get("root") != "battle":
            continue
        if player.state.get("root") != "battle":
            if _through_scene(player, 4) != "battle":
                continue
        battle = player.state.get("battle") or {}
        encounters += 1
        enemy = battle.get("enemy") or {}
        before = player.state.get("last_battle_outcome")
        if battle.get("trainerName"):
            player.fight(limit=1200, potion_at=34)
        elif enemy.get("species") == species:
            if _catch_wild(player, species):
                return True
        elif not player.run_away():
            player.fight(limit=400, potion_at=34)
        if player.state.get("root") != "overworld":
            player.dismiss_until_explore(limit=30)
        after = player.state.get("last_battle_outcome") or {}
        if _lost(before, after):
            raise RuntimeError(f"blackout hunting {species}: " + json.dumps(summary(player.state)))
    return _member(player, species)[0] is not None


def _close_menus(player):
    for _ in range(8):
        if player.exploring():
            return
        root = player.state.get("root")
        if root == "pause":
            player.choose("pause", _menu_label(player, "pause", "EXIT"))
        elif root == "learning":
            player.dismiss_until_explore(limit=20)
        else:
            player.press("b", wait=6)


def _select_party(player, slot):
    for _ in range(6):
        selected = (player.state.get("party_ui") or {}).get("selected") or 1
        if selected == slot:
            return
        player.press("down" if slot > selected else "up", wait=2)
    raise RuntimeError(f"party did not select {slot}: " + json.dumps(summary(player.state)))


def _teach(player, item, species, move):
    slot, mon = _member(player, species)
    if slot is None:
        raise RuntimeError(f"no {species} to teach {item}")
    if move in (mon.get("moves") or []):
        return
    if not player.exploring():
        _close_menus(player)
    player.press("b", wait=10)
    player.choose("pause", _menu_label(player, "pause", "ITEM"))
    for _ in range(24):
        if player.state.get("root") != "bag":
            break
        bag = player.state.get("bag") or {}
        phase = bag.get("phase")
        if phase == "actions":
            player.choose("bag", "USE")
            continue
        if phase not in (None, "list", "closed"):
            player.press("a", wait=4)
            continue
        slots = (player.state.get("inventory") or {}).get("slots") or []
        index = next((i for i, entry in enumerate(slots, start=1) if entry.get("id") == item), None)
        if index is None:
            raise RuntimeError(f"{item} is not in the bag")
        selected = bag.get("selected") or 1
        if selected != index:
            player.press("down" if index > selected else "up", wait=2)
        else:
            player.press("a", wait=6)
    for _ in range(12):
        if player.state.get("root") == "learning":
            break
        if player.state.get("root") != "party":
            player.send("wait 4")
            continue
        _select_party(player, slot)
        player.press("a", wait=8)
    for _ in range(24):
        if player.state.get("root") != "learning":
            break
        learning = player.state.get("learning") or {}
        phase = learning.get("phase")
        if phase in (None, "message", "closed") or learning.get("dialog_ready"):
            if learning.get("dialog_ready") or phase == "message":
                player.press("a", wait=6)
            else:
                player.send("wait 6")
            continue
        selected = learning.get("selected") or 1
        target = forget_index(learning) if phase == "replace" else {"ask": 1, "confirm": 1, "stop": 2}.get(phase, 1)
        if selected == target:
            player.press("a", wait=6)
        else:
            player.press("down" if target > selected else "up", wait=2)
    _close_menus(player)
    _, mon = _member(player, species)
    if mon is None or move not in (mon.get("moves") or []):
        raise RuntimeError(f"{species} did not learn {move}: " + json.dumps(summary(player.state)))


def _lead(player, species):
    slot, _mon = _member(player, species)
    active = (player.state.get("party") or {}).get("active") or 1
    # A fainted switch sets the active index without moving slot 1.
    # Swapping slot 1 with itself still selects the first conscious member.
    if slot in (None, 1) and active == 1:
        return
    if not player.exploring():
        _close_menus(player)
    player.press("b", wait=10)
    player.choose("pause", _menu_label(player, "pause", "MON"))
    _select_party(player, slot)
    player.press("a", wait=6)
    player.choose("party_ui", "SWITCH")
    _select_party(player, 1)
    player.press("a", wait=8)
    _close_menus(player)


def _shop_buy(player, item, price, target):
    buying = False
    for _ in range(40):
        shop = player.state.get("shop") or {}
        phase = shop.get("phase")
        have = _item_count(player, item)
        money = int((player.state.get("inventory") or {}).get("money") or 0)
        if (have >= target or money < price) and phase in ("browse", "mode") and buying:
            return have
        if phase == "mode":
            player.choose("shop", "BUY")
            buying = True
        elif phase == "browse" and not buying:
            player.press("b", wait=4)
        elif phase == "browse":
            if shop.get("item") == item:
                player.press("a", wait=4)
            else:
                player.press("down", wait=2)
        elif phase == "quantity":
            want = min(target - have, money // price)
            quantity = shop.get("quantity") or 1
            if want < 1:
                player.press("b", wait=4)
            elif quantity < want:
                player.press("up", wait=2)
            else:
                player.press("a", wait=4)
        elif phase == "confirm":
            player.choose("shop", "YES")
        elif phase == "result":
            player.press("a", wait=4)
        else:
            player.send("wait 4")
    return _item_count(player, item)


def _buy_vermilion(player, report, balls=8, supers=6):
    doors = set(VERMILION_DOORS)
    doors.discard((23, 13))
    _enter(player, vermilion_cells(), (23, 13), doors, "up", "mart", "Vermilion Mart")
    cells = vermilion_mart_cells()
    opened = player.state.get("root") == "shop"
    for _ in range(8):
        if player.state.get("root") == "shop":
            opened = True
            break
        if not player.exploring():
            player.dismiss_until_explore(limit=16)
        npc = npc_named(player.state, VERMILION_CLERK)
        if npc is None:
            break
        spot = next((candidate for distance in (1, 2)
                     if (candidate := (npc["x"] + distance, npc["y"])) in cells), None)
        if spot is None:
            break
        player.travel(cells, spot, {(npc["x"], npc["y"])})
        if player.state["player"].get("facing") != "left":
            player.press("left", wait=4)
        player.press("a", wait=8)
    if not opened and player.state.get("root") != "shop":
        raise RuntimeError("the Vermilion clerk did not open: " + json.dumps(summary(player.state)))
    report["poke_balls"] = _shop_buy(player, "pokeBall", 200, balls)
    report["super_potions"] = _shop_buy(player, "superPotion", 700, supers)
    report["mart_money"] = int((player.state.get("inventory") or {}).get("money") or 0)
    money_left = report["mart_money"]
    short_balls = report["poke_balls"] < min(4, balls) and money_left >= 200
    short_supers = report["super_potions"] < min(4, supers) and money_left >= 700
    if short_balls or short_supers:
        raise RuntimeError("Vermilion Mart did not sell balls and Super Potions: " + json.dumps(summary(player.state)))
    for _ in range(8):
        if player.state.get("root") != "shop":
            break
        phase = (player.state.get("shop") or {}).get("phase")
        if phase == "mode":
            player.choose("shop", "QUIT")
        else:
            player.press("b", wait=4)
    kind = "stayed"
    for _ in range(8):
        if "vermilion_city" in str(player.state.get("zone")):
            break
        for door in ((6, 7), (5, 7)):
            kind = step_onto(player, cells, door, set(), "down")
            if "vermilion_city" in str(player.state.get("zone")):
                break
        else:
            player.send("wait 12")
            continue
        break
    report["mart_left"] = {"kind": kind, **summary(player.state)}
    if "vermilion_city" not in str(player.state.get("zone")):
        raise RuntimeError("still inside Vermilion Mart: " + json.dumps(summary(player.state)))


def _search_can(player, index):
    source_x, source_y = VERMILION_CANS[index]
    can = (source_x + 1, source_y)
    cells = vermilion_gym_cells()
    here = (player.state["player"]["x"], player.state["player"]["y"])
    stand, face = None, "up"
    for dx, dy, facing in ((0, 1, "up"), (0, -1, "down"), (-1, 0, "right"), (1, 0, "left")):
        spot = (can[0] + dx, can[1] + dy)
        if spot in cells and spot not in GYM_SIGHT and route(cells, here, spot, GYM_SIGHT):
            stand, face = spot, facing
            break
    if stand is None:
        raise RuntimeError(f"trash can {index} has no safe side")
    _stand(player, cells, stand, GYM_SIGHT, f"trash can {index}")
    if player.state["player"].get("facing") != face:
        player.press(face, wait=4)
    player.press("a", wait=8)
    _through_scene(player, 4)


def _solve_cans(player, report):
    """Start at can 0. A click is pressed again. Any other first can uses K's row."""
    guesses = {can: 0 for can in TRASH_SECONDS}
    for _ in range(30):
        if _quest(player).get("EVENT_2ND_LOCK_OPENED"):
            break
        first = None
        if not _quest(player).get("EVENT_1ST_LOCK_OPENED"):
            for can in TRASH_SECONDS:
                _search_can(player, can)
                if _quest(player).get("EVENT_2ND_LOCK_OPENED"):
                    break
                if _quest(player).get("EVENT_1ST_LOCK_OPENED"):
                    first = can
                    break
        else:
            first = _can_index(_quest(player), "FIRST")
        if _quest(player).get("EVENT_2ND_LOCK_OPENED"):
            break
        if first not in TRASH_SECONDS or not _quest(player).get("EVENT_1ST_LOCK_OPENED"):
            raise RuntimeError("no trash can clicked: " + json.dumps(summary(player.state)))
        options = TRASH_SECONDS[first]
        choice = options[guesses[first] % len(options)]
        guesses[first] += 1
        _search_can(player, choice)
    quest = _quest(player)
    report["cans"] = {
        "first": _can_index(quest, "FIRST"),
        "second": _can_index(quest, "SECOND"),
        "open": bool(quest.get("EVENT_2ND_LOCK_OPENED")),
    }
    if not quest.get("EVENT_2ND_LOCK_OPENED"):
        raise RuntimeError("the gym cans stayed shut: " + json.dumps(report["cans"]))


def _fight_once(player, label, potion_at, bite_only=False, shift_to=None, decline_moves=False):
    before = player.state.get("last_battle_outcome")
    if player.state.get("root") != "battle":
        _through_scene(player, 4)
    if player.state.get("root") != "battle":
        raise RuntimeError(f"{label} did not start: " + json.dumps(summary(player.state)))
    won = player.fight(limit=2500, potion_at=potion_at, bite_only=bite_only,
                       shift_to=shift_to, decline_moves=decline_moves)
    if player.state.get("root") != "overworld":
        player.dismiss_until_explore(limit=160)
    after = player.state.get("last_battle_outcome") or {}
    if _lost(before, after):
        raise RuntimeError(f"blackout at {label}: " + json.dumps(summary(player.state)))
    if won is not True and after.get("won") is not True:
        raise RuntimeError(f"{label} was not won: " + json.dumps(summary(player.state)))


def play_ss_anne(player, report, display, clips, output):
    """Board the S.S. Anne, take HM01, catch a Blue Cut user, then Lt. Surge."""
    player.leave_title()
    if not player.exploring():
        player.dismiss_until_explore(limit=40)
    report["resumed"] = summary(player.state)
    if "vermilion_city" not in str(player.state.get("zone")):
        raise RuntimeError("the ship walk did not resume in Vermilion: " + json.dumps(summary(player.state)))
    if _item_count(player, "ssTicket") < 1:
        raise RuntimeError("the S.S. Ticket is not in the bag")

    _buy_vermilion(player, report)

    def board_and_learn():
        doors = set(VERMILION_DOORS)
        _stand(player, vermilion_cells(), (18, 29), doors, "dock gate")
        player.step("down")
        if not player.exploring():
            _through_scene(player, 4)
        _enter(player, vermilion_cells(), (18, 31), doors, "down", "vermilion_dock", "Vermilion dock")
        _enter(player, vermilion_dock_cells(), (14, 2), set(), "down", "ss_anne_1f", "S.S. Anne")
        _enter(player, ss_anne_1f_cells(), (2, 6), ANNE1_SKIP, "up", "ss_anne_2f", "S.S. Anne 2F")
        _stand(player, ss_anne_2f_cells(), (36, 9), ANNE2_SKIP, "rival trigger")
        player.step("up")
        _fight_once(player, "the S.S. Anne rival", 34)
        report["anne_rival"] = summary(player.state)
        _enter(player, ss_anne_2f_cells(), (36, 4), ANNE2_SKIP - {(36, 4)}, "up", "captains_room", "captain")
        _stand(player, captain_cells(), (7, 3), set(), "captain")
        if player.state["player"].get("facing") != "up":
            player.press("up", wait=4)
        player.press("a", wait=8)
        _through_scene(player, 6)

    if display and clips and output:
        film(display, clips, output, "ss-anne", report, "end", board_and_learn)
    else:
        board_and_learn()
    report["hm01"] = {
        "count": _item_count(player, "hm01"),
        "flag": bool(_quest(player).get("EVENT_GOT_HM01")),
        **summary(player.state),
    }
    if report["hm01"]["count"] < 1 or not report["hm01"]["flag"]:
        raise RuntimeError("the captain did not give HM01: " + json.dumps(report["hm01"]))
    _leave(player, captain_cells(), [((3, 7), "down")], set(), "ss_anne_2f", "captain exit")
    _enter(player, ss_anne_2f_cells(), (2, 4), ANNE2_SKIP - {(36, 4)}, "up", "ss_anne_1f", "S.S. Anne stairs")
    _stand(player, ss_anne_1f_cells(), (27, 0), ANNE1_SKIP, "ship exit")
    player.step("up")
    _through_scene(player, 4)
    report["departed"] = {
        "left": bool(_quest(player).get("EVENT_SS_ANNE_LEFT")),
        **summary(player.state),
    }
    if player.exploring():
        report["saved_hm01"] = player.pause_save()

    # pret/pokered af519899 English Blue uses Bellsprout here, and it learns Cut.
    _leave(player, vermilion_cells(), [((19, 0), "up"), ((18, 0), "up")],
           VERMILION_DOORS, "route_6", "Route 6")
    _stand(player, route6_cells(), (12, 30), ROUTE6_SKIP, "Route 6 grass")
    caught = _hunt(player, route6_cells(), (12, 30), (13, 30), "bellsprout", limit=24)
    report["bellsprout"] = {"caught": bool(caught), **summary(player.state)}
    if not caught:
        raise RuntimeError("Route 6 did not yield a Bellsprout: " + json.dumps(summary(player.state)))
    _stand(player, route6_cells(), (9, 35), ROUTE6_SKIP, "Route 6 south")
    _leave(player, route6_cells(), [((9, 35), "down"), ((8, 35), "down")],
           ROUTE6_SKIP, "vermilion_city", "Vermilion return")
    _heal_in(player, report, vermilion_cells(), (11, 3), VERMILION_NURSE,
             vermilion_center_cells(), "before_cut", "vermilion_city", avoid=VERMILION_DOORS)
    _teach(player, "hm01", "bellsprout", "cut")
    doors = set(VERMILION_DOORS)
    _stand(player, vermilion_cells(), (15, 17), doors, "Cut tree")
    if player.state["player"].get("facing") != "down":
        player.press("down", wait=4)
    if not player.exploring():
        _close_menus(player)
    player.press("b", wait=10)
    player.choose("pause", _menu_label(player, "pause", "MON"))
    slot, _mon = _member(player, "bellsprout")
    _select_party(player, slot)
    player.press("a", wait=6)
    player.choose("party_ui", "CUT")
    for _ in range(16):
        if player.exploring():
            break
        if player.state.get("root") == "fieldMove":
            phase = (player.state.get("field_move") or {}).get("phase")
            if phase == "confirm":
                player.choose("field_move", "YES")
            elif phase == "announce":
                player.press("a", wait=8)
            else:
                player.send("wait 8")
        else:
            player.press("b", wait=4)
    _close_menus(player)
    opened = set(vermilion_cells())
    opened.add((15, 18))
    kind = player.travel(opened, (15, 18), doors)
    report["cut"] = {"kind": kind, **summary(player.state)}
    if (player.state["player"]["x"], player.state["player"]["y"]) != (15, 18):
        raise RuntimeError("Cut did not open the Vermilion tree: " + json.dumps(summary(player.state)))

    _stand(player, opened, (39, 14), doors, "Route 11")
    _leave(player, opened, [((39, 14), "right")], doors, "route_11", "Route 11")
    _enter(player, route11_cells(), (4, 5), set(), "up", "digletts_cave_route_11", "Diglett's Cave")
    kind = step_onto(player, diglett_house_cells(), (6, 4), {(4, 3)}, "up")
    _settle_overlay(player)
    if player.state.get("zone") != "kanto_digletts_cave":
        raise RuntimeError("the cave stairs did not open: " + json.dumps(summary(player.state)))
    dug = _hunt(player, diglett_cave_cells(), (35, 31), (36, 31), "diglett", limit=16)
    report["diglett"] = {"caught": bool(dug), **summary(player.state)}
    step_onto(player, diglett_cave_cells(), (37, 31), set(), "down")
    _settle_overlay(player)
    _leave(player, diglett_house_cells(), [((4, 7), "down"), ((5, 7), "down")],
           {(4, 3)}, "route_11", "cave exit")
    _leave(player, route11_cells(), [((0, 6), "left")], set(), "vermilion_city", "Vermilion from Route 11")
    _heal_in(player, report, opened, (11, 3), VERMILION_NURSE,
             vermilion_center_cells(), "before_surge", "vermilion_city", avoid=VERMILION_DOORS)
    if dug:
        _teach(player, "tm28", "diglett", "dig")
        _lead(player, "diglett")
    gym_doors = set(VERMILION_DOORS)
    gym_doors.discard((12, 19))
    _enter(player, opened, (12, 19), gym_doors, "up", "vermilion_gym", "Vermilion Gym")
    _solve_cans(player, report)

    def surge():
        _stand(player, vermilion_gym_cells(), (6, 2), GYM_SIGHT, "Lt. Surge")
        if player.state["player"].get("facing") != "up":
            player.press("up", wait=4)
        player.press("a", wait=8)
        _fight_once(player, "Lt. Surge", 48)

    if display and clips and output:
        film(display, clips, output, "gym-vermilion", report, "end", surge)
    else:
        surge()
    quest = _quest(player)
    report["thunder"] = {
        "badge": bool(quest.get("BADGE_THUNDER")),
        "beat": bool(quest.get("EVENT_BEAT_LT_SURGE")),
        **summary(player.state),
    }
    if not report["thunder"]["badge"]:
        raise RuntimeError("Lt. Surge did not give the Thunder Badge: " + json.dumps(report["thunder"]))
    if player.exploring():
        report["saved_thunder"] = player.pause_save()


def _route6_avoid():
    # The north ledges hop downward. The grass and the remaining trainers are south of them.
    return set(ROUTE6_SKIP) | {(x, y) for (x, y) in route6_cells() if y < 14}


def route11_avoid():
    # Diglett's door, both gates, and the Route 12 edge.
    blocked = {(4, 5), (49, 8), (49, 9), (58, 8), (58, 9)}
    blocked.update(cell for cell in route11_cells() if cell[0] >= 49)
    return blocked


def _sight_cells(trainer):
    x, y = trainer["xy"]
    dx, dy = DELTAS[{"RIGHT": "right", "LEFT": "left", "UP": "up", "DOWN": "down"}[trainer["face"]]]
    return [(x + dx * step, y + dy * step) for step in range(1, trainer["sight"] + 1)]


def _party(player):
    return [
        {"species": mon.get("species"), "level": mon.get("level"), "hp": mon.get("hp")}
        for mon in ((player.state.get("party") or {}).get("members") or [])
    ]


def _grind(player, cells, trainers, avoid, label):
    fought = []
    for trainer in trainers:
        if ((player.state.get("pokemon") or {}).get("level") or 0) >= 28:
            break
        name = f"{label} {trainer['id'].rsplit(':', 1)[-1]}"
        local = set(avoid) - set(_sight_cells(trainer))
        if trainer["sight"] == 0:
            if talk_to(player, cells, trainer["id"], local) == "missing":
                raise RuntimeError(f"missing {name}")
            if player.state.get("root") == "battle":
                _fight_once(player, name, 36)
        else:
            _stand(player, cells, _sight_cells(trainer)[0], local, name, potion_at=36)
        fought.append({"id": trainer["id"], **summary(player.state)})
    return fought


def _return_vermilion(player, label):
    zone = str(player.state.get("zone"))
    if "route_6" in zone:
        _stand(player, route6_cells(), (9, 35), _route6_avoid(), f"{label} south")
        _leave(player, route6_cells(), [((9, 35), "down"), ((8, 35), "down")],
               _route6_avoid(), "vermilion_city", label)
    elif "route_11" in zone:
        _stand(player, route11_cells(), (0, 6), route11_avoid(), f"{label} west")
        _leave(player, route11_cells(), [((0, 6), "left")],
               route11_avoid(), "vermilion_city", label)
    if "vermilion_city" not in str(player.state.get("zone")):
        raise RuntimeError(f"{label} did not reach Vermilion: " + json.dumps(summary(player.state)))


def _rest(player, report, label, supers, buy=True):
    _return_vermilion(player, label)
    doors = set(VERMILION_DOORS)
    doors.discard((11, 3))
    _heal_in(player, report, vermilion_cells(), (11, 3), VERMILION_NURSE,
             vermilion_center_cells(), label, "vermilion_city", avoid=doors)
    money = int((player.state.get("inventory") or {}).get("money") or 0)
    if buy and _item_count(player, "superPotion") < supers and money >= 700:
        _buy_vermilion(player, report, balls=8, supers=supers)


def _keep_bird_save(report):
    data = Path(report.get("data_dir") or "")
    if not data.is_dir():
        return
    BIRD_SAVE.mkdir(parents=True, exist_ok=True)
    for src in sorted(data.glob("adventure*.json")):
        shutil.copyfile(src, BIRD_SAVE / src.name)


def _pause(player, report, key):
    if not player.exploring():
        _settle_catch(player)
    report[key] = player.pause_save() or player.pause_save()
    if not report[key]:
        raise RuntimeError(f"{key} did not save: " + json.dumps(summary(player.state)))


def _to_route6_grass(player):
    if "route_6" not in str(player.state.get("zone")):
        if "vermilion_city" not in str(player.state.get("zone")):
            _return_vermilion(player, "Route 6 return")
        _leave(player, vermilion_cells(), [((19, 0), "up"), ((18, 0), "up")],
               VERMILION_DOORS, "route_6", "Route 6")
    _stand(player, route6_cells(), (12, 30), _route6_avoid(), "Route 6 grass")


def _raise_pidgey(player, report):
    """Gust wild battles to Pidgeotto 19. Decline Whirlwind; B2W2 offers it at 17."""
    _lead(player, "pidgey")
    left, right = (12, 30), (13, 30)
    goal = right
    battles = 0
    paused_level = 0
    while battles < 120:
        if not player.exploring():
            root = player.state.get("root")
            if root == "learning":
                _decline_new_move(player)
            elif root == "evolution":
                player.dismiss_until_explore(limit=40)
            else:
                _settle_catch(player)
            continue
        _slot, bird = _member(player, "pidgeotto")
        if bird is None:
            _slot, bird = _member(player, "pidgey")
        bird = bird or {}
        level = bird.get("level") or 0
        name = bird.get("species") or "pidgey"
        if name == "pidgeotto" and level >= 19:
            break
        if name == "pidgey" and level >= 21:
            raise RuntimeError("Pidgey reached 21 before it evolved: " + json.dumps(_party(player)))
        if level > paused_level:
            _pause(player, report, f"bird_l{level}")
            _keep_bird_save(report)
            paused_level = level
        # The Center is free. Super Potions stay in the bag for the rival.
        # A fainted switch leaves Wartortle active while the bird stays in slot 1.
        lead = (player.state.get("pokemon") or {}).get("species")
        if lead != name or (bird.get("hp") or 0) < 18:
            _rest(player, report, "bird heal", 4, buy=False)
            _to_route6_grass(player)
            _lead(player, name)
            if (player.state.get("pokemon") or {}).get("species") != name:
                raise RuntimeError("the bird is not leading: " + json.dumps(_party(player)))
            continue
        here = (player.state["player"]["x"], player.state["player"]["y"])
        if here == goal:
            goal = left if goal == right else right
        steps = route(route6_cells(), here, goal, set())
        if not steps:
            raise RuntimeError("lost the Route 6 grass: " + json.dumps(summary(player.state)))
        kind = player.step(steps[0])
        if kind not in ("overlay", "warp") and player.state.get("root") != "battle":
            continue
        if player.state.get("root") != "battle" and _through_scene(player, 4) != "battle":
            continue
        battles += 1
        before = player.state.get("last_battle_outcome")
        battle = player.state.get("battle") or {}
        if battle.get("trainerName"):
            player.fight(limit=800, potion_at=0, decline_moves=True)
        else:
            foe = battle.get("enemy") or {}
            # Meowth outspeeds and Bite chunks a 37 HP Pidgey. Bellsprout
            # takes super-effective Gust and Vine Whip is resisted.
            if foe.get("species") == "meowth" or (foe.get("level") or 99) > level + 3:
                if not player.run_away():
                    player.fight(limit=400, potion_at=0, decline_moves=True, run_at=8)
            else:
                player.fight(limit=500, potion_at=0, decline_moves=True)
        if player.state.get("root") != "overworld":
            _settle_catch(player)
        if _lost(before, player.state.get("last_battle_outcome") or {}):
            raise RuntimeError("blackout raising Pidgey: " + json.dumps(summary(player.state)))
    _slot, mon = _member(player, "pidgeotto")
    if mon is None:
        _slot, mon = _member(player, "pidgey")
    mon = mon or {}
    report["bird"] = {"battles": battles, "party": _party(player), **summary(player.state)}
    if mon.get("species") != "pidgeotto" or (mon.get("level") or 0) < 19:
        raise RuntimeError("Pidgey did not reach Pidgeotto 19: " + json.dumps(report["bird"]))
    _lead(player, "wartortle")


def _confirm_cut(player, facing):
    """Open the field menu and confirm Cut while facing the tree."""
    if player.state["player"].get("facing") != facing:
        player.press(facing, wait=4)
    if not player.exploring():
        _close_menus(player)
    player.press("b", wait=10)
    player.choose("pause", _menu_label(player, "pause", "MON"))
    slot, _mon = _member(player, "bellsprout")
    _select_party(player, slot)
    player.press("a", wait=6)
    player.choose("party_ui", "CUT")
    for _ in range(16):
        if player.exploring():
            break
        if player.state.get("root") == "fieldMove":
            phase = (player.state.get("field_move") or {}).get("phase")
            if phase == "confirm":
                player.choose("field_move", "YES")
            elif phase == "announce":
                player.press("a", wait=8)
            else:
                player.send("wait 8")
        else:
            player.press("b", wait=4)
    _close_menus(player)


def _use_cut(player, report, facing):
    """Cut the tile being faced. The caller is already standing beside the tree."""
    _confirm_cut(player, facing)
    opened = set(vermilion_cells())
    opened.add((15, 18))
    kind = player.travel(opened, (15, 18), set(VERMILION_DOORS))
    report["cut"] = {"kind": kind, "facing": facing, **summary(player.state)}
    if (player.state["player"]["x"], player.state["player"]["y"]) != (15, 18):
        raise RuntimeError("Cut did not open the Vermilion tree: " + json.dumps(summary(player.state)))
    return opened


def _cut_tree(player, report):
    doors = set(VERMILION_DOORS)
    here = (player.state["player"]["x"], player.state["player"]["y"])
    if "vermilion_city" in str(player.state.get("zone")) and here == (15, 18):
        opened = set(vermilion_cells())
        opened.add((15, 18))
        report["cut"] = {"kind": "already", **summary(player.state)}
        return opened
    _stand(player, vermilion_cells(), (15, 17), doors, "Cut tree")
    return _use_cut(player, report, "down")


def _mole(player):
    slot, mon = _member(player, "dugtrio")
    if mon is None:
        slot, mon = _member(player, "diglett")
    return slot, mon or {}


def _enter_diglett_cave(player):
    if player.state.get("zone") == "kanto_digletts_cave":
        return
    if "route_11" not in str(player.state.get("zone")):
        if "vermilion_city" not in str(player.state.get("zone")):
            _return_vermilion(player, "cave return")
        _leave(player, vermilion_cells(), [((39, 14), "right"), ((39, 15), "right")],
               VERMILION_DOORS, "route_11", "Route 11")
    _enter(player, route11_cells(), (4, 5), route11_avoid() - {(4, 5)}, "up",
           "digletts_cave_route_11", "Diglett's Cave")
    step_onto(player, diglett_house_cells(), (6, 4), {(4, 3)}, "up")
    _settle_overlay(player)
    if player.state.get("zone") != "kanto_digletts_cave":
        raise RuntimeError("the cave stairs did not open: " + json.dumps(summary(player.state)))


def _leave_diglett_cave(player):
    zone = str(player.state.get("zone"))
    if zone == "kanto_digletts_cave":
        step_onto(player, diglett_cave_cells(), (37, 31), set(), "down")
        _settle_overlay(player)
    if "digletts_cave_route_11" in str(player.state.get("zone")):
        _leave(player, diglett_house_cells(), [((4, 7), "down"), ((5, 7), "down")],
               {(4, 3)}, "route_11", "cave exit")


def _finish_wild(player, level, strong_at, potion_at=0):
    """A live command menu is still the fight. The catch settler only clears the pages after it."""
    for _ in range(4):
        if player.exploring():
            return
        if player.state.get("root") != "battle":
            if player.state.get("root") == "evolution":
                player.dismiss_until_explore(limit=40)
            else:
                _settle_catch(player)
            return
        foe = (player.state.get("battle") or {}).get("enemy") or {}
        foe_level = foe.get("level")
        too_strong = foe.get("species") == "dugtrio" or (
            foe_level is not None and foe_level > (level or 0) + strong_at)
        if too_strong:
            # Sand Veil Dugtrio can be fled. Arena Trap cannot.
            if player.run_away() or player.exploring():
                return
            supers = int(((player.state.get("inventory") or {}).get("quantities") or {}).get("superPotion") or 0)
            battler = ((player.state.get("battle") or {}).get("player") or {}).get("species")
            if supers < 2 and battler in ("diglett", "dugtrio"):
                # One Super Potion does not cover the charge turn. Wartortle's Water Gun does.
                if not (player.state.get("battle") or {}).get("inMoveSelect"):
                    player.choose("battle", "POKEMON")
                for _ in range(8):
                    if player.state.get("root") != "party":
                        break
                    _send_out(player, "wartortle")
                player.fight(limit=1200, potion_at=30)
            else:
                player.fight(limit=1200, potion_at=max(potion_at, 200))
            continue
        player.fight(limit=1200, potion_at=potion_at)
    if not player.exploring():
        raise RuntimeError("a wild battle stayed open: " + json.dumps(summary(player.state)))


def _raise_diglett(player, report):
    """Catch a Diglett and evolve it. Pokered Dig is 19. Dugtrio 26 is the Surge plan."""
    _, mon = _mole(player)
    if mon.get("species") == "dugtrio" and (mon.get("level") or 0) >= 26:
        report["diglett_level"] = {"species": mon.get("species"), "level": mon.get("level"), "moves": mon.get("moves")}
        return
    _enter_diglett_cave(player)
    if not _mole(player)[1]:
        caught = _hunt(player, diglett_cave_cells(), (35, 31), (36, 31), "diglett", limit=16)
        report["diglett"] = {"caught": bool(caught), "party": _party(player), **summary(player.state)}
        if not caught:
            raise RuntimeError("Diglett's Cave did not yield a Diglett: " + json.dumps(summary(player.state)))
    _lead(player, "diglett")
    left, right = (35, 31), (36, 31)
    goal = right
    paused = 0
    battles = 0
    while battles < 80:
        if not player.exploring():
            _, mon = _mole(player)
            _finish_wild(player, (mon or {}).get("level") or 0, 3, potion_at=22)
            continue
        _, mon = _mole(player)
        level = mon.get("level") or 0
        name = mon.get("species") or "diglett"
        if level > paused:
            _pause(player, report, f"mole_l{level}")
            _keep_bird_save(report)
            paused = level
        if name == "dugtrio" and level >= 26:
            break
        lead = (player.state.get("pokemon") or {}).get("species")
        dig_pp = (mon.get("pp") or {}).get("dig")
        # One cave hit can faint a Diglett that is still above 12 HP.
        max_hp = mon.get("maxHP") or 0
        if lead != name or (mon.get("hp") or 0) < max(20, max_hp // 2) or (dig_pp is not None and dig_pp < 4):
            _leave_diglett_cave(player)
            _rest(player, report, "mole heal", 4)
            _enter_diglett_cave(player)
            _lead(player, name if name == "dugtrio" else "diglett")
            if (player.state.get("pokemon") or {}).get("species") not in ("diglett", "dugtrio"):
                raise RuntimeError("the mole is not leading: " + json.dumps(_party(player)))
            continue
        here = (player.state["player"]["x"], player.state["player"]["y"])
        if here == goal:
            goal = left if goal == right else right
        steps = route(diglett_cave_cells(), here, goal, set())
        if not steps:
            _enter_diglett_cave(player)
            continue
        player.step(steps[0])
        if player.state.get("root") != "battle" and player.exploring():
            continue
        battles += 1
        before = player.state.get("last_battle_outcome")
        _finish_wild(player, level, 3, potion_at=22)
        if _lost(before, player.state.get("last_battle_outcome") or {}):
            raise RuntimeError("blackout raising Diglett: " + json.dumps(summary(player.state)))
    _leave_diglett_cave(player)
    _leave(player, route11_cells(), [((0, 6), "left")], route11_avoid(), "vermilion_city", "Vermilion from Route 11")
    _, mon = _mole(player)
    report["diglett_level"] = {"species": mon.get("species"), "level": mon.get("level"),
                               "moves": mon.get("moves"), "battles": battles}
    if mon.get("species") != "dugtrio" or (mon.get("level") or 0) < 26:
        raise RuntimeError("Diglett did not become Dugtrio 26: " + json.dumps(report["diglett_level"]))


def _raise_spearow(player, report):
    """Route 11 Spearow to Fearow 34. Pokered Drill Peck is that level."""
    if _member(player, "spearow")[0] is None and _member(player, "fearow")[0] is None:
        if "route_11" not in str(player.state.get("zone")):
            if "vermilion_city" not in str(player.state.get("zone")):
                _return_vermilion(player, "Spearow return")
            _leave(player, vermilion_cells(), [((39, 14), "right"), ((39, 15), "right")],
                   VERMILION_DOORS, "route_11", "Route 11")
        _stand(player, route11_cells(), (10, 12), route11_avoid(), "Route 11 grass")
        caught = _hunt(player, route11_cells(), (10, 12), (11, 12), "spearow", limit=20)
        report["spearow"] = {"caught": bool(caught), "party": _party(player), **summary(player.state)}
        if not caught:
            raise RuntimeError("Route 11 did not yield a Spearow: " + json.dumps(summary(player.state)))
    _lead(player, "spearow" if _member(player, "spearow")[0] else "fearow")
    left, right = (10, 12), (11, 12)
    goal = right
    paused = 0
    battles = 0
    while battles < 400:
        if not player.exploring():
            _slot, bird = _member(player, "fearow")
            if bird is None:
                _slot, bird = _member(player, "spearow")
            _finish_wild(player, (bird or {}).get("level") or 0, 4)
            continue
        _slot, bird = _member(player, "fearow")
        if bird is None:
            _slot, bird = _member(player, "spearow")
        bird = bird or {}
        level = bird.get("level") or 0
        name = bird.get("species") or "spearow"
        moves = bird.get("moves") or []
        if name == "fearow" and level >= 34 and "drillPeck" in moves:
            break
        if name == "spearow" and level >= 22:
            raise RuntimeError("Spearow reached 22 before it evolved: " + json.dumps(_party(player)))
        if level > paused:
            _pause(player, report, f"spearow_l{level}")
            _keep_bird_save(report)
            paused = level
        lead = (player.state.get("pokemon") or {}).get("species")
        bird_pp = bird.get("pp") or {}
        peck_empty = bird_pp.get("drillPeck") == 0 or (
            "drillPeck" not in moves and bird_pp.get("peck") == 0)
        if lead != name or (bird.get("hp") or 0) < 16 or peck_empty:
            if "route_11" in str(player.state.get("zone")):
                _return_vermilion(player, "spearow heal")
            _rest(player, report, "spearow heal", 4, buy=False)
            _leave(player, vermilion_cells(), [((39, 14), "right"), ((39, 15), "right")],
                   VERMILION_DOORS, "route_11", "Route 11")
            _stand(player, route11_cells(), (10, 12), route11_avoid(), "Route 11 grass")
            _lead(player, name)
            if (player.state.get("pokemon") or {}).get("species") != name:
                raise RuntimeError("the Spearow is not leading: " + json.dumps(_party(player)))
            continue
        here = (player.state["player"]["x"], player.state["player"]["y"])
        if here == goal:
            goal = left if goal == right else right
        steps = route(route11_cells(), here, goal, route11_avoid())
        if not steps:
            raise RuntimeError("lost the Route 11 grass: " + json.dumps(summary(player.state)))
        player.step(steps[0])
        if player.state.get("root") != "battle" and player.exploring():
            continue
        battles += 1
        before = player.state.get("last_battle_outcome")
        _finish_wild(player, level, 4)
        if _lost(before, player.state.get("last_battle_outcome") or {}):
            raise RuntimeError("blackout raising Spearow: " + json.dumps(summary(player.state)))
    _return_vermilion(player, "Fearow")
    _, bird = _member(player, "fearow")
    bird = bird or {}
    report["fearow"] = {"level": bird.get("level"), "moves": bird.get("moves"), "battles": battles,
                        "party": _party(player)}
    if bird.get("species") != "fearow" or (bird.get("level") or 0) < 34 or "drillPeck" not in (bird.get("moves") or []):
        raise RuntimeError("Spearow did not become Fearow 34 with Drill Peck: " + json.dumps(report["fearow"]))


def _enter_cerulean(player, report):
    """Route 4's open line into the city. Cascade is already set, so the gym stays closed."""
    if player.state.get("zone") == "kanto_route_4":
        if player.exploring() and (player.state["player"]["x"], player.state["player"]["y"]) != (59, 4):
            report["saved_route4_exit"] = player.pause_save()
            _keep_bird_save(report)
        here = (player.state["player"]["x"], player.state["player"]["y"])
        if here != (59, 4) and here[0] >= 24 and route(route4_cells(), here, (59, 4)) is not None:
            kind = player.travel(route4_cells(), (59, 4), set(), limit=20)
            report["cliff"] = {"kind": kind, "at": summary(player.state)}
            if kind != "arrived":
                raise RuntimeError("could not reach the Route 4 cliff: " + json.dumps(summary(player.state)))
        _follow_route4_line(player, report)
    if player.state.get("zone") != "kanto_cerulean_city":
        raise RuntimeError("Cerulean did not open: " + json.dumps(summary(player.state)))
    if _needs_heal(player):
        _heal_in(player, report, cerulean_cells(), (19, 17), CERULEAN_NURSE,
                 cerulean_center_cells(), "cerulean_return", "cerulean_city",
                 avoid=CERULEAN_DOORS | {(15, 18)})
    report["cerulean_return"] = summary(player.state)
    _pause(player, report, "saved_cerulean_return")
    _keep_bird_save(report)


ROUTE2_AVOID = {(12, 9), (3, 11)}


def _cut_route2_to_pewter(player, report, display=None, clips=None, output=None):
    """Cut the cave-side tree at (5, 10) and take the north edge to Pewter.

    The tree is back after a reload. Stand at (5, 11), face up, and cut before
    the walk north. (8, 0) lands on Pewter (18, 35).
    """
    blocked = set(ROUTE2_AVOID)
    cells = route2_cells()
    here = (player.state["player"]["x"], player.state["player"]["y"])
    if route(cells, here, (8, 0), blocked) is None:
        def cross():
            _stand(player, cells, (5, 11), blocked, "Route 2 tree")
            if player.state["player"].get("facing") != "up":
                player.press("up", wait=4)
            kind = player.step("up")
            landed = (player.state["player"]["x"], player.state["player"]["y"])
            opened = set(cells)
            opened.add((5, 10))
            if landed != (5, 10):
                _confirm_cut(player, "up")
                kind = player.travel(opened, (5, 10), blocked)
                landed = (player.state["player"]["x"], player.state["player"]["y"])
            report["route2_cut"] = {"kind": kind, "at": list(landed), **summary(player.state)}
            if landed != (5, 10):
                raise RuntimeError("Route 2 Cut did not open (5, 10): " + json.dumps(report["route2_cut"]))
            kind = leave_map(player, opened, (8, 0), blocked, "up")
            report["pewter_entry"] = {"kind": kind, **summary(player.state)}
            return kind

        if display and clips and output:
            film(display, clips, output, "route2", report, "end", cross)
        else:
            cross()
    else:
        kind = leave_map(player, cells, (8, 0), blocked, "up")
        report["pewter_entry"] = {"kind": kind, **summary(player.state)}
    if "pewter" not in str(player.state.get("zone")):
        raise RuntimeError("Route 2 did not reach Pewter: " + json.dumps(summary(player.state)))
    _pause(player, report, "saved_pewter_return")
    _keep_bird_save(report)


ROUTE9_AVOID = {
    (13, 10), (24, 7), (31, 7), (48, 8), (16, 15), (43, 3), (22, 2), (45, 15), (40, 8), (10, 15),
}
ROUTE10_AVOID = {(10, 44), (3, 57), (14, 64), (7, 25), (3, 61), (7, 54), (6, 39)}
TUNNEL_1F_AVOID = {(7, 5), (5, 16), (17, 15), (23, 8), (37, 21), (22, 24), (32, 24)}
TUNNEL_B1_AVOID = {(11, 13), (6, 10), (3, 5), (20, 21), (30, 10), (14, 28), (33, 5), (26, 30)}
LAVENDER_DOORS = {(3, 5), (14, 5), (7, 9), (15, 13), (3, 13), (7, 13)}
ROUTE8_AVOID = {(1, 9), (1, 10), (8, 9), (8, 10), (8, 5), (13, 9), (42, 6), (26, 3), (26, 4),
                (26, 5), (26, 6), (46, 13), (51, 12)}
ROUTE7_GATES = {(18, 9), (18, 10), (11, 9), (11, 10)}
CERULEAN_NPCS = {(30, 8), (31, 20), (15, 18), (9, 21), (28, 12), (29, 26), (28, 26), (9, 27), (4, 12), (27, 12)}
ROCK_NURSE = "pokered:ROCK_TUNNEL_POKECENTER:objects:1"
EAST_RESUME = {
    "kanto_cerulean_city", "kanto_route_9", "kanto_route_10", "kanto_rock_tunnel_1f",
    "kanto_rock_tunnel_b1f", "kanto_rock_tunnel_pokecenter", "kanto_lavender_town",
    "kanto_route_8", "kanto_underground_path_route_8", "kanto_underground_path_west_east",
    "kanto_underground_path_route_7", "kanto_route_7", "kanto_celadon_city",
    "kanto_celadon_mart_1f", "kanto_celadon_mart_2f", "kanto_celadon_gym",
}


def _walk(player, cells, surface, goal, avoid, limit=800, report=None, yield_after=2):
    """Recompute a ledge-aware step until the goal, a warp, or a blackout.

    Two trainer battles are enough for one session. The caller saves and exits.
    """
    feet, ledges = surface
    blocked = set()
    talked = set()
    fights = 0
    started = player.state.get("zone")
    for _ in range(limit):
        if player.state.get("zone") != started:
            return "warp"
        if not player.exploring():
            root = player.state.get("root")
            if root == "battle":
                before = player.state.get("last_battle_outcome")
                trainer = (player.state.get("battle") or {}).get("trainerName")
                if trainer:
                    player.fight(limit=2500, potion_at=30, shift_to="pidgeotto")
                elif not player.run_away():
                    player.fight(limit=2500, potion_at=30, shift_to="pidgeotto")
                player.dismiss_until_explore(limit=80)
                after = player.state.get("last_battle_outcome") or {}
                if _lost(before, after):
                    return "blackout"
                if trainer and report is not None:
                    fights += 1
                    if fights >= yield_after:
                        _checkpoint(player, report, "saved_east_yield")
                        return "yield"
                continue
            if root in ("dialog", "learning", "oak", "naming", "tutorial-escort", "event", "evolution"):
                player.dismiss_until_explore(limit=100)
                continue
            player.settle(limit=40)
            continue
        here = (player.state["player"]["x"], player.state["player"]["y"])
        if here == goal:
            return "arrived"
        steps = ledge_route(cells, feet, ledges, here, goal, set(avoid) | blocked)
        if not steps:
            return "no-route"
        kind = player.step(steps[0])
        if player.state.get("zone") != started or kind == "warp":
            return "warp"
        if kind == "blocked":
            nxt = neighbor(here, steps[0])
            npc = next((n for n in (player.state.get("npcs") or [])
                        if (n.get("x"), n.get("y")) == nxt), None)
            if npc and nxt not in talked:
                talked.add(nxt)
                player.press("a", wait=8)
                continue
            blocked.add(nxt)
    return "lost"


def _cut_facing(player, cells, surface, stand, facing, tree, avoid, report, key):
    """Open one Cut tile, then keep it in the walk set. Trees regrow on reload."""
    here = (player.state["player"]["x"], player.state["player"]["y"])
    if here != stand:
        kind = _walk(player, cells, surface, stand, avoid)
        if kind in ("blackout", "yield"):
            return kind, set(cells)
        if (player.state["player"]["x"], player.state["player"]["y"]) != stand:
            raise RuntimeError(f"could not stand at {stand} for Cut: " + json.dumps(summary(player.state)))
    if player.state["player"].get("facing") != facing:
        player.press(facing, wait=4)
    kind = player.step(facing)
    landed = (player.state["player"]["x"], player.state["player"]["y"])
    opened = set(cells)
    opened.add(tree)
    if landed != tree:
        _confirm_cut(player, facing)
        kind = player.step(facing)
        landed = (player.state["player"]["x"], player.state["player"]["y"])
    report[key] = {"kind": kind, "at": list(landed), **summary(player.state)}
    if landed != tree:
        raise RuntimeError(f"Cut did not open {tree}: " + json.dumps(report[key]))
    return "open", opened


def _checkpoint(player, report, key):
    _pause(player, report, key)
    _keep_bird_save(report)


def _note_blackout(report):
    report["blackouts"] = int(report.get("blackouts") or 0) + 1
    if report["blackouts"] >= 2:
        raise RuntimeError("a second blackout on the east road: " + json.dumps(summary_safe(report)))


def summary_safe(report):
    return {"blackouts": report.get("blackouts"), "zone": report.get("resumed")}


def _bird(player):
    for species in ("pidgeot", "fearow", "pidgeotto", "spearow", "pidgey"):
        slot, mon = _member(player, species)
        if slot:
            return species, mon or {}
    return None, {}


def _money(player):
    return int((player.state.get("inventory") or {}).get("money") or 0)


def _onto_warp(player, cells, surface, goal, avoid, report, key):
    """Walk onto a stair. Landing on it changes maps, so a warp is success."""
    started = player.state.get("zone")
    here = (player.state["player"]["x"], player.state["player"]["y"])
    if here != goal:
        kind = _walk(player, cells, surface, goal, avoid, report=report, yield_after=2)
        if kind in ("blackout", "yield"):
            return kind
        if kind == "warp" or player.state.get("zone") != started:
            report[key] = summary(player.state)
            return "open"
    if (player.state["player"]["x"], player.state["player"]["y"]) != goal:
        raise RuntimeError(f"{key} did not open: " + json.dumps(summary(player.state)))
    for direction, back in (("down", "up"), ("up", "down"), ("left", "right"), ("right", "left")):
        kind = player.step(direction)
        if kind == "warp" or player.state.get("zone") != started:
            report[key] = summary(player.state)
            return "open"
        if (player.state["player"]["x"], player.state["player"]["y"]) != goal:
            player.step(back)
            player.settle(limit=40)
            if player.state.get("zone") != started:
                report[key] = summary(player.state)
                return "open"
            break
    raise RuntimeError(f"{key} stayed put: " + json.dumps(summary(player.state)))


def _challenge(player, cells, surface, tile, avoid):
    """Talk to one trainer from an open side. A missing sprite is not a fight."""
    here = (player.state["player"]["x"], player.state["player"]["y"])
    spots = []
    for direction, (dx, dy) in DELTAS.items():
        spot = (tile[0] - dx, tile[1] - dy)
        if spot in cells and spot not in avoid and spot != tile:
            spots.append((abs(spot[0] - here[0]) + abs(spot[1] - here[1]), spot, direction))
    if not spots:
        return "skip"
    _distance, spot, direction = min(spots)
    if ledge_route(cells, surface[0], surface[1], here, spot, set(avoid) | {tile}) is None:
        return "skip"
    stamp = json.dumps(player.state.get("last_battle_outcome"), sort_keys=True, default=str)
    kind = _walk(player, cells, surface, spot, set(avoid) | {tile})
    if kind in ("blackout", "warp"):
        return kind
    # A sight battle beats the trainer before the talk, so the button only gets the after-text.
    if json.dumps(player.state.get("last_battle_outcome"), sort_keys=True, default=str) != stamp:
        if not player.exploring():
            player.dismiss_until_explore(limit=40)
        return "fought"
    if (player.state["player"]["x"], player.state["player"]["y"]) != spot:
        return "skip"
    if player.state["player"].get("facing") != direction:
        player.press(direction, wait=4)
    player.press("a", wait=8)
    for _ in range(8):
        if player.state.get("root") == "battle":
            before = player.state.get("last_battle_outcome")
            player.fight(limit=2500, potion_at=30, shift_to="pidgeotto")
            player.dismiss_until_explore(limit=80)
            after = player.state.get("last_battle_outcome") or {}
            return "blackout" if _lost(before, after) else "fought"
        if player.exploring():
            return "silent"
        player.dismiss_until_explore(limit=20)
    return "silent"


def _grind_bird(player, report, cells, left, right, avoid, level=31, limit=48):
    """Pace two grass tiles with the flyer in front until Wing Attack's level."""
    species, mon = _bird(player)
    if not species or (mon.get("level") or 0) >= level:
        report["grind"] = {"species": species, "level": (mon or {}).get("level"), "battles": 0}
        return "ready"
    _lead(player, species)
    battles = 0
    goal = right
    for _ in range(limit * 80):
        species, mon = _bird(player)
        if (mon.get("level") or 0) >= level or battles >= limit:
            break
        if not player.exploring():
            if player.state.get("root") == "battle":
                before = player.state.get("last_battle_outcome")
                player.fight(limit=1200, potion_at=50, shift_to=None)
                player.dismiss_until_explore(limit=40)
                battles += 1
                if battles % 8 == 0 and player.exploring():
                    _checkpoint(player, report, "saved_grind")
                if _lost(before, player.state.get("last_battle_outcome") or {}):
                    report["grind"] = {"species": species, "level": (mon or {}).get("level"), "battles": battles}
                    return "blackout"
            else:
                player.dismiss_until_explore(limit=20)
            continue
        here = (player.state["player"]["x"], player.state["player"]["y"])
        if here == goal:
            goal = left if goal == right else right
        steps = route(cells, here, goal, avoid)
        if not steps:
            break
        player.step(steps[0])
    species, mon = _bird(player)
    report["grind"] = {"species": species, "level": (mon or {}).get("level"), "battles": battles, "party": _party(player)}
    return "open"


def _leave_cerulean_east(player, report, display, clips, output):
    """The southeast tree at (19, 28) is the only join to the Route 9 edge."""
    cells = set(cerulean_cells())
    avoid = set(CERULEAN_DOORS) | CERULEAN_NPCS
    surface = map_surface(ROOT / "Source/data/sourceSlice/CeruleanCity.json")
    here = (player.state["player"]["x"], player.state["player"]["y"])
    if ledge_route(cells, surface[0], surface[1], here, (39, 16), avoid) is None:
        def cut():
            status, opened = _cut_facing(
                player, cells, surface, (19, 27), "down", (19, 28), avoid, report, "cerulean_tree")
            if status == "blackout":
                return status
            kind = _walk(player, opened, surface, (39, 16), avoid)
            if kind in ("blackout", "yield"):
                return kind
            if (player.state["player"]["x"], player.state["player"]["y"]) != (39, 16):
                raise RuntimeError("Cerulean east edge did not open: " + json.dumps(summary(player.state)))
            player.step("right")
            player.settle(limit=80)
            report["route9_entry"] = summary(player.state)
            return "left" if "route_9" in str(player.state.get("zone")) else "stayed"

        if display and clips and output:
            filmed = film(display, clips, output, "route9", report, "end", cut)
        else:
            filmed = cut()
        if filmed == "blackout":
            return "blackout"
        if "route_9" not in str(player.state.get("zone")):
            raise RuntimeError("Route 9 did not open: " + json.dumps(summary(player.state)))
    else:
        kind = _walk(player, cells, surface, (39, 16), avoid)
        if kind in ("blackout", "yield"):
            return kind
        player.step("right")
        player.settle(limit=80)
        report["route9_entry"] = summary(player.state)
        if "route_9" not in str(player.state.get("zone")):
            raise RuntimeError("Route 9 did not open: " + json.dumps(summary(player.state)))
    _checkpoint(player, report, "saved_route9")
    return "open"


def _cross_route9(player, report):
    cells = set(route9_cells())
    surface = map_surface(EAST / "Route9.json")
    here = (player.state["player"]["x"], player.state["player"]["y"])
    avoid = set(ROUTE9_AVOID)
    if here[0] <= 5 and ledge_route(cells, surface[0], surface[1], here, (59, 8), avoid) is None:
        status, cells = _cut_facing(player, cells, surface, (4, 8), "right", (5, 8), avoid, report, "route9_tree")
        if status == "blackout":
            return status
    _species, mon = _bird(player)
    if _money(player) < 2800 or (mon.get("level") or 0) < 28:
        for tile in ((13, 10), (16, 15), (22, 2), (24, 7), (31, 7), (40, 8), (43, 3), (45, 15), (48, 8)):
            result = _challenge(player, cells, surface, tile, set())
            if result == "blackout":
                return result
            if player.state.get("zone") != "kanto_route_9":
                return "open"
            if result == "fought":
                # One trainer, then a new session. A single sweep climbs past the simulator's memory.
                report["route9_trainers"] = {
                    "tile": list(tile), "money": _money(player),
                    "bird": (_bird(player)[1] or {}).get("level"), "party": _party(player),
                }
                _checkpoint(player, report, "saved_route9_trainers")
                return "yield"
        report["route9_trainers"] = {"money": _money(player), "bird": (_bird(player)[1] or {}).get("level")}
    kind = _walk(player, cells, surface, (59, 8), avoid, report=report, yield_after=2)
    if kind in ("blackout", "yield"):
        return kind
    if (player.state["player"]["x"], player.state["player"]["y"]) != (59, 8):
        raise RuntimeError("Route 9 did not reach Route 10: " + json.dumps(summary(player.state)))
    player.step("right")
    player.settle(limit=80)
    report["route10_entry"] = summary(player.state)
    if "route_10" not in str(player.state.get("zone")):
        raise RuntimeError("Route 10 did not open: " + json.dumps(summary(player.state)))
    return "open"


def _cross_route10(player, report):
    """North of the tunnel: heal, then the cave. South of it: Lavender."""
    y = player.state["player"]["y"]
    cells = route10_cells()
    surface = map_surface(EAST / "Route10.json")
    avoid = set(ROUTE10_AVOID)
    if y < 40:
        avoid |= {(8, 17), (8, 53)}
        if _needs_heal(player) or "center" not in str(report.get("tunnel_center") or ""):
            if (player.state["player"]["x"], player.state["player"]["y"]) != (11, 20):
                kind = _walk(player, cells, surface, (11, 20), avoid | {(11, 19)}, report=report, yield_after=2)
                if kind in ("blackout", "yield"):
                    return kind
            _heal_in(player, report, cells, (11, 19), ROCK_NURSE, rock_tunnel_center_cells(),
                     "tunnel", "route_10", avoid=avoid | {(11, 19)})
            report["tunnel_center"] = summary(player.state)
            _checkpoint(player, report, "saved_tunnel_center")
        avoid.discard((8, 17))
        kind = _walk(player, cells, surface, (8, 18), avoid, report=report, yield_after=2)
        if kind in ("blackout", "yield"):
            return kind
        player.step("up")
        player.settle(limit=80)
        report["tunnel_entry"] = summary(player.state)
        if "rock_tunnel" not in str(player.state.get("zone")):
            raise RuntimeError("Rock Tunnel did not open: " + json.dumps(summary(player.state)))
        return "open"
    kind = _walk(player, cells, surface, (8, 71), avoid | {(8, 17), (8, 53), (11, 19)}, report=report, yield_after=2)
    if kind in ("blackout", "yield"):
        return kind
    player.step("down")
    player.settle(limit=80)
    report["lavender_entry"] = summary(player.state)
    if "lavender" not in str(player.state.get("zone")):
        raise RuntimeError("Lavender did not open: " + json.dumps(summary(player.state)))
    _checkpoint(player, report, "saved_lavender")
    return "open"


def _cross_tunnel(player, report):
    zone = str(player.state.get("zone"))
    if "b1f" in zone:
        cells, surface, goal = rock_tunnel_b1_cells(), map_surface(EAST / "RockTunnelB1F.json"), (3, 3)
        avoid = set(TUNNEL_B1_AVOID)
    else:
        cells = rock_tunnel_1f_cells()
        surface = map_surface(EAST / "RockTunnel1F.json")
        here = (player.state["player"]["x"], player.state["player"]["y"])
        avoid = set(TUNNEL_1F_AVOID)
        if ledge_route(cells, surface[0], surface[1], here, (15, 33), avoid):
            goal = (15, 33)
        else:
            goal = (37, 3)
    return _onto_warp(player, cells, surface, goal, avoid, report, "tunnel_stair")


def _cross_lavender(player, report):
    kind = _walk(player, lavender_cells(), map_surface(EAST / "LavenderTown.json"), (0, 8), LAVENDER_DOORS, report=report, yield_after=2)
    if kind in ("blackout", "yield"):
        return kind
    player.step("left")
    player.settle(limit=80)
    report["route8_entry"] = summary(player.state)
    if "route_8" not in str(player.state.get("zone")):
        raise RuntimeError("Route 8 did not open: " + json.dumps(summary(player.state)))
    return "open"


def _cross_route8(player, report):
    gates = {(1, 9), (1, 10), (8, 9), (8, 10)}
    kind = _walk(player, route8_cells(), map_surface(EAST / "Route8.json"), (13, 4), gates, report=report, yield_after=2)
    if kind in ("blackout", "yield"):
        return kind
    player.step("up")
    player.settle(limit=80)
    report["underground_entry"] = summary(player.state)
    if "underground" not in str(player.state.get("zone")):
        raise RuntimeError("the Route 8 underground did not open: " + json.dumps(summary(player.state)))
    return "open"


def _cross_underground(player, report):
    zone = str(player.state.get("zone"))
    if zone == "kanto_underground_path_route_8":
        cells, surface, goal = underground_route8_cells(), map_surface(EAST / "UndergroundPathRoute8.json", 2), (6, 4)
        avoid = {(5, 4)}
    elif zone == "kanto_underground_path_west_east":
        cells, surface, goal = underground_we_cells(), map_surface(EAST / "UndergroundPathWestEast.json"), (2, 5)
        avoid = set()
    elif zone == "kanto_underground_path_route_7":
        cells, surface, goal = underground_route7_cells(), map_surface(EAST / "UndergroundPathRoute7.json", 2), (5, 7)
        avoid = {(4, 4)}
    else:
        raise RuntimeError("unknown underground room: " + zone)
    return _onto_warp(player, cells, surface, goal, avoid, report, "underground_step")


def _cross_route7(player, report, display, clips, output):
    cells = route7_cells()
    avoid = set(ROUTE7_GATES) | {(5, 13)}
    status = _grind_bird(player, report, cells, (8, 2), (9, 2), avoid)
    if status == "blackout":
        return status
    _lead(player, "wartortle")
    kind = _walk(player, cells, map_surface(EAST / "Route7.json"), (0, 3), avoid, report=report, yield_after=2)
    if kind in ("blackout", "yield"):
        return kind

    def enter():
        player.step("left")
        player.settle(limit=80)
        report["celadon_entry"] = summary(player.state)

    if display and clips and output:
        film(display, clips, output, "celadon", report, "end", enter)
    else:
        enter()
    if "celadon" not in str(player.state.get("zone")):
        raise RuntimeError("Celadon did not open: " + json.dumps(summary(player.state)))
    _checkpoint(player, report, "saved_celadon")
    return "open"


def _shop_stock(player):
    seen = []
    for _ in range(24):
        shop = player.state.get("shop") or {}
        phase = shop.get("phase")
        if phase == "mode":
            player.choose("shop", "BUY")
            continue
        if phase != "browse":
            player.press("b", wait=4)
            continue
        item = shop.get("item")
        if item in seen:
            return seen
        if item and item != "none":
            seen.append(item)
        player.press("down", wait=2)
    return seen


def _close_shop(player):
    for _ in range(8):
        if player.state.get("root") != "shop":
            break
        phase = (player.state.get("shop") or {}).get("phase")
        if phase == "mode":
            player.choose("shop", "QUIT")
        else:
            player.press("b", wait=4)
    _close_menus(player)


def _open_clerk(player, cells, surface, spot):
    kind = _walk(player, cells, surface, spot, {(1, 1), (12, 1), (16, 1), (14, 4), (19, 5)})
    if kind not in ("arrived", "open"):
        return kind
    if player.state["player"].get("facing") != "up":
        player.press("up", wait=4)
    player.press("a", wait=8)
    for _ in range(16):
        root = player.state.get("root")
        if root == "shop":
            return "shop"
        if root == "overworld":
            return "closed"
        player.press("a", wait=6)
    return "closed"


def _buy_celadon(player, report):
    """Dept. Store 2F sells Super Potions, Antidotes, and Paralyze Heals."""
    zone = str(player.state.get("zone"))
    if zone == "kanto_celadon_city":
        doors = {(8, 13), (10, 13), (12, 27), (24, 9), (24, 3), (25, 3), (41, 9),
                 (28, 19), (39, 19), (33, 19), (31, 27), (35, 27), (43, 27)}
        kind = _walk(player, celadon_cells(), map_surface(EAST / "CeladonCity.json"), (8, 14), doors)
        if kind in ("blackout", "yield"):
            return kind
        player.step("up")
        player.settle(limit=40)
        report["mart_door"] = summary(player.state)
        return "open"
    if "mart_1f" in zone:
        floor = celadon_mart_cells(1)
        surface = map_surface(EAST / "CeladonMart1F.json")
        if report.get("celadon_stocked"):
            return _onto_warp(player, floor, surface, (3, 7), {(1, 1), (12, 1), (8, 3)}, report, "mart_exit")
        kind = _walk(player, floor, surface, (12, 2), {(1, 1), (8, 3)})
        if kind in ("blackout", "yield"):
            return kind
        player.step("up")
        player.settle(limit=40)
        report["mart_stairs"] = summary(player.state)
        return "open"
    if "mart_2f" not in zone:
        raise RuntimeError("the Dept. Store floor is unknown: " + json.dumps(summary(player.state)))
    second = celadon_mart_cells(2)
    surface = map_surface(EAST / "CeladonMart2F.json")
    if report.get("celadon_stocked"):
        return _onto_warp(player, second, surface, (12, 1), {(1, 1), (16, 1)}, report, "mart_down")
    opened = "closed"
    for spot in ((5, 5), (6, 5)):
        opened = _open_clerk(player, second, surface, spot)
        if opened == "blackout":
            return opened
        if opened != "shop":
            continue
        stock = _shop_stock(player)
        report["mart_stock"] = stock
        if "superPotion" in stock or "antidote" in stock or "paralyzeHeal" in stock:
            break
        _close_shop(player)
        opened = "closed"
    if opened != "shop":
        raise RuntimeError("the Dept. Store clerk did not open: " + json.dumps(summary(player.state)))
    money = _money(player)
    supers = min(6, money // 700)
    left = money - supers * 700
    antidotes = min(5, left // 100)
    left -= antidotes * 100
    heals = min(5, left // 200)
    if supers:
        report["super_potions"] = _shop_buy(player, "superPotion", 700, _item_count(player, "superPotion") + supers)
    if antidotes:
        report["antidotes"] = _shop_buy(player, "antidote", 100, _item_count(player, "antidote") + antidotes)
    if heals:
        report["paralyze_heals"] = _shop_buy(player, "paralyzeHeal", 200, _item_count(player, "paralyzeHeal") + heals)
    report["mart_money"] = _money(player)
    bought = (report.get("super_potions") or 0) + (report.get("antidotes") or 0) + (report.get("paralyze_heals") or 0)
    if bought < 1 and money >= 100 and ("superPotion" in (report.get("mart_stock") or []) or "antidote" in (report.get("mart_stock") or [])):
        raise RuntimeError("Celadon did not sell the counter: " + json.dumps(summary(player.state)))
    _close_shop(player)
    report["celadon_stocked"] = True
    _checkpoint(player, report, "saved_celadon_mart")
    return "open"


def _fight_erika(player, report, display, clips, output):
    if _quest(player).get("BADGE_RAINBOW"):
        report["rainbow"] = {"badge": True, "party": _party(player), **summary(player.state)}
        return "badge"
    cells = celadon_cells()
    surface = map_surface(EAST / "CeladonCity.json")
    if "gym" not in str(player.state.get("zone")):
        kind = _walk(player, cells, surface, (12, 28), {(8, 13), (10, 13), (12, 27)})
        if kind in ("blackout", "yield"):
            return kind
        player.step("up")
        player.settle(limit=40)
        if "gym" not in str(player.state.get("zone")):
            raise RuntimeError("the Celadon gym did not open: " + json.dumps(summary(player.state)))
    gym = set(celadon_gym_cells())
    gym_surface = map_surface(EAST / "CeladonGym.json", 1)
    # The bottom bush is the door into Erika's room. The other two are side cuts.
    here = (player.state["player"]["x"], player.state["player"]["y"])
    if ledge_route(gym, gym_surface[0], gym_surface[1], here, (5, 4), set()) is None:
        status, gym = _cut_facing(player, gym, gym_surface, (6, 8), "up", (6, 7), set(), report, "erika_bush")
        if status == "blackout":
            return status
    trainers = {(3, 11), (8, 10), (10, 5), (2, 5), (7, 3), (4, 3), (6, 3), (5, 3)}

    def battle():
        kind = _walk(player, gym, gym_surface, (5, 4), trainers, report=report, yield_after=2)
        if kind in ("blackout", "yield"):
            return kind
        if player.state["player"].get("facing") != "up":
            player.press("up", wait=4)
        player.press("a", wait=8)
        _fight_once(player, "Erika", 30, shift_to="pidgeotto")
        report["erika"] = {"party": _party(player), **summary(player.state)}
        return "fought"

    if display and clips and output:
        battle = film(display, clips, output, "erika", report, "end", battle)
    if battle in ("blackout", "yield"):
        return battle
    quest = _quest(player)
    report["rainbow"] = {"badge": bool(quest.get("BADGE_RAINBOW")), "party": _party(player), **summary(player.state)}
    if report["rainbow"]["badge"]:
        _checkpoint(player, report, "saved_rainbow")
        return "badge"
    raise RuntimeError("Erika did not give the Rainbow Badge: " + json.dumps(report["rainbow"]))


K_ZONES = {
    "Route9": "kanto_route_9",
    "Route10": "kanto_route_10",
    "RockTunnelPokecenter": "kanto_rock_tunnel_pokecenter",
    "RockTunnel1F": "kanto_rock_tunnel_1f",
    "RockTunnelB1F": "kanto_rock_tunnel_b1f",
    "LavenderTown": "kanto_lavender_town",
    "LavenderPokecenter": "kanto_lavender_pokecenter",
    "PokemonTower1F": "kanto_pokemon_tower_1f",
    "PokemonTower2F": "kanto_pokemon_tower_2f",
    "PokemonTower3F": "kanto_pokemon_tower_3f",
    "PokemonTower4F": "kanto_pokemon_tower_4f",
    "PokemonTower5F": "kanto_pokemon_tower_5f",
    "PokemonTower6F": "kanto_pokemon_tower_6f",
    "PokemonTower7F": "kanto_pokemon_tower_7f",
    "MrFujisHouse": "kanto_mr_fujis_house",
    "Route8": "kanto_route_8",
    "Route12": "kanto_route_12",
    "Route12Gate1F": "kanto_route_12_gate_1f",
    "UndergroundPathRoute8": "kanto_underground_path_route_8",
    "UndergroundPathWestEast": "kanto_underground_path_west_east",
    "UndergroundPathRoute7": "kanto_underground_path_route_7",
    "Route7": "kanto_route_7",
    "CeladonCity": "kanto_celadon_city",
    "CeladonPokecenter": "kanto_celadon_pokecenter",
    "CeladonGym": "kanto_celadon_gym",
    "GameCorner": "kanto_game_corner",
    "RocketHideoutB1F": "kanto_rocket_hideout_b1f",
    "RocketHideoutB2F": "kanto_rocket_hideout_b2f",
    "RocketHideoutB3F": "kanto_rocket_hideout_b3f",
    "RocketHideoutB4F": "kanto_rocket_hideout_b4f",
    "RocketHideoutElevator": "kanto_rocket_hideout_elevator",
}
K_FILES = {
    "Route9": ("Route9.json", 0, 60),
    "Route10": ("Route10.json", 0, 20),
    "RockTunnelPokecenter": ("RockTunnelPokecenter.json", 0, 14),
    "RockTunnel1F": ("RockTunnel1F.json", 0, 40),
    "RockTunnelB1F": ("RockTunnelB1F.json", 0, 40),
    "LavenderTown": ("LavenderTown.json", 0, 20),
    "LavenderPokecenter": ("LavenderPokecenter.json", 0, 14),
    "Route8": ("Route8.json", 0, 60),
    "UndergroundPathRoute8": ("UndergroundPathRoute8.json", 2, 13),
    "UndergroundPathWestEast": ("UndergroundPathWestEast.json", 0, 50),
    "UndergroundPathRoute7": ("UndergroundPathRoute7.json", 2, 13),
    "Route7": ("Route7.json", 0, 20),
    "CeladonCity": ("CeladonCity.json", 0, 50),
    "CeladonPokecenter": ("CeladonPokecenter.json", 0, 14),
    "CeladonGym": ("CeladonGym.json", 1, 13),
}
K_NURSE = {
    "RockTunnelPokecenter": "pokered:ROCK_TUNNEL_POKECENTER:objects:1",
    "LavenderPokecenter": "pokered:LAVENDER_POKECENTER:objects:1",
    "CeladonPokecenter": "pokered:CELADON_POKECENTER:objects:1",
}
K_LINE = [
    ("walk", "up", 1, "Route9", 20, 11),
    ("walk", "right", 8, "Route9", 28, 11),
    ("walk", "down", 1, "Route9", 28, 12),
    ("walk", "right", 13, "Route9", 41, 12),
    ("walk", "up", 3, "Route9", 41, 9),
    ("fight", "up", "Route9", 41, 8),
    ("walk", "up", 1, "Route9", 41, 7),
    ("walk", "left", 2, "Route9", 39, 7),
    ("walk", "up", 3, "Route9", 39, 4),
    ("walk", "right", 5, "Route9", 44, 4),
    ("walk", "up", 1, "Route9", 44, 3),
    ("walk", "right", 6, "Route9", 50, 3),
    ("walk", "down", 1, "Route9", 50, 4),
    ("ledge", "down", "Route9", 50, 6),
    ("walk", "down", 1, "Route9", 50, 7),
    ("walk", "right", 1, "Route9", 51, 7),
    ("walk", "down", 1, "Route9", 51, 8),
    ("walk", "right", 8, "Route9", 59, 8),
    ("conn", "right", "Route10", 0, 8),
    ("walk", "down", 1, "Route10", 0, 9),
    ("walk", "right", 2, "Route10", 2, 9),
    ("walk", "down", 1, "Route10", 2, 10),
    ("ledge", "down", "Route10", 2, 12),
    ("walk", "down", 1, "Route10", 2, 13),
    ("walk", "right", 8, "Route10", 10, 13),
    ("walk", "down", 2, "Route10", 10, 15),
    ("walk", "right", 4, "Route10", 14, 15),
    ("walk", "down", 5, "Route10", 14, 20),
    ("walk", "left", 3, "Route10", 11, 20),
    ("warp", "up", "RockTunnelPokecenter", 3, 7),
    ("walk", "up", 4, "RockTunnelPokecenter", 3, 3),
    ("heal", "RockTunnelPokecenter"),
    ("walk", "down", 4, "RockTunnelPokecenter", 3, 7),
    ("warp", "down", "Route10", 11, 20),
    ("walk", "left", 1, "Route10", 10, 20),
    ("walk", "down", 5, "Route10", 10, 25),
    ("walk", "left", 1, "Route10", 9, 25),
    ("walk", "down", 1, "Route10", 9, 26),
    ("walk", "left", 6, "Route10", 3, 26),
    ("walk", "up", 8, "Route10", 3, 18),
    ("walk", "right", 5, "Route10", 8, 18),
    ("warp", "up", "RockTunnel1F", 15, 3),
    ("walk", "down", 4, "RockTunnel1F", 15, 7),
    ("walk", "right", 5, "RockTunnel1F", 20, 7),
    ("fight", "down", "RockTunnel1F", 20, 8),
    ("walk", "down", 2, "RockTunnel1F", 20, 10),
    ("walk", "right", 14, "RockTunnel1F", 34, 10),
    ("walk", "up", 7, "RockTunnel1F", 34, 3),
    ("walk", "right", 2, "RockTunnel1F", 36, 3),
    ("warp", "right", "RockTunnelB1F", 33, 25),
    ("walk", "left", 5, "RockTunnelB1F", 28, 25),
    ("walk", "down", 5, "RockTunnelB1F", 28, 30),
    ("walk", "left", 1, "RockTunnelB1F", 27, 30),
    ("walk", "down", 1, "RockTunnelB1F", 27, 31),
    ("fight", "left", "RockTunnelB1F", 26, 31),
    ("walk", "left", 9, "RockTunnelB1F", 17, 31),
    ("walk", "up", 2, "RockTunnelB1F", 17, 29),
    ("fight", "up", "RockTunnelB1F", 17, 28),
    ("walk", "up", 4, "RockTunnelB1F", 17, 24),
    ("walk", "right", 3, "RockTunnelB1F", 20, 24),
    ("walk", "up", 2, "RockTunnelB1F", 20, 22),
    ("walk", "right", 5, "RockTunnelB1F", 25, 22),
    ("walk", "up", 6, "RockTunnelB1F", 25, 16),
    ("walk", "right", 7, "RockTunnelB1F", 32, 16),
    ("walk", "up", 6, "RockTunnelB1F", 32, 10),
    ("walk", "right", 2, "RockTunnelB1F", 34, 10),
    ("walk", "up", 4, "RockTunnelB1F", 34, 6),
    ("walk", "right", 3, "RockTunnelB1F", 37, 6),
    ("walk", "up", 2, "RockTunnelB1F", 37, 4),
    ("walk", "left", 10, "RockTunnelB1F", 27, 4),
    ("warp", "up", "RockTunnel1F", 5, 3),
    ("walk", "left", 1, "RockTunnel1F", 4, 3),
    ("walk", "down", 18, "RockTunnel1F", 4, 21),
    ("walk", "right", 2, "RockTunnel1F", 6, 21),
    ("walk", "up", 3, "RockTunnel1F", 6, 18),
    ("walk", "right", 2, "RockTunnel1F", 8, 18),
    ("walk", "up", 4, "RockTunnel1F", 8, 14),
    ("walk", "right", 6, "RockTunnel1F", 14, 14),
    ("walk", "up", 3, "RockTunnel1F", 14, 11),
    ("walk", "right", 2, "RockTunnel1F", 16, 11),
    ("warp", "right", "RockTunnelB1F", 23, 11),
    ("walk", "left", 9, "RockTunnelB1F", 14, 11),
    ("walk", "down", 3, "RockTunnelB1F", 14, 14),
    ("walk", "left", 2, "RockTunnelB1F", 12, 14),
    ("fight", "left", "RockTunnelB1F", 11, 14),
    ("walk", "left", 3, "RockTunnelB1F", 8, 14),
    ("walk", "up", 1, "RockTunnelB1F", 8, 13),
    ("walk", "left", 1, "RockTunnelB1F", 7, 13),
    ("fight", "left", "RockTunnelB1F", 6, 13),
    ("walk", "left", 2, "RockTunnelB1F", 4, 13),
    ("walk", "up", 9, "RockTunnelB1F", 4, 4),
    ("walk", "left", 1, "RockTunnelB1F", 3, 4),
    ("warp", "up", "RockTunnel1F", 37, 17),
    ("walk", "left", 5, "RockTunnel1F", 32, 17),
    ("walk", "down", 6, "RockTunnel1F", 32, 23),
    ("walk", "right", 5, "RockTunnel1F", 37, 23),
    ("walk", "down", 2, "RockTunnel1F", 37, 25),
    ("walk", "left", 5, "RockTunnel1F", 32, 25),
    ("walk", "down", 3, "RockTunnel1F", 32, 28),
    ("walk", "left", 6, "RockTunnel1F", 26, 28),
    ("walk", "up", 1, "RockTunnel1F", 26, 27),
    ("walk", "left", 3, "RockTunnel1F", 23, 27),
    ("fight", "left", "RockTunnel1F", 22, 27),
    ("walk", "left", 7, "RockTunnel1F", 15, 27),
    ("walk", "down", 5, "RockTunnel1F", 15, 32),
    ("warp", "down", "Route10", 8, 54),
    ("walk", "right", 2, "Route10", 10, 54),
    ("walk", "down", 1, "Route10", 10, 55),
    ("walk", "right", 4, "Route10", 14, 55),
    ("walk", "down", 1, "Route10", 14, 56),
    ("ledge", "down", "Route10", 14, 58),
    ("walk", "down", 2, "Route10", 14, 60),
    ("ledge", "down", "Route10", 14, 62),
    ("walk", "down", 1, "Route10", 14, 63),
    ("walk", "right", 1, "Route10", 15, 63),
    ("walk", "down", 2, "Route10", 15, 65),
    ("walk", "left", 5, "Route10", 10, 65),
    ("walk", "down", 1, "Route10", 10, 66),
    ("ledge", "down", "Route10", 10, 68),
    ("walk", "left", 1, "Route10", 9, 68),
    ("walk", "down", 3, "Route10", 9, 71),
    ("conn", "down", "LavenderTown", 9, 0),
    ("walk", "left", 3, "LavenderTown", 6, 0),
    ("walk", "down", 6, "LavenderTown", 6, 6),
    ("walk", "left", 3, "LavenderTown", 3, 6),
    ("warp", "up", "LavenderPokecenter", 3, 7),
    ("walk", "up", 4, "LavenderPokecenter", 3, 3),
    ("heal", "LavenderPokecenter"),
    ("walk", "down", 4, "LavenderPokecenter", 3, 7),
    ("warp", "down", "LavenderTown", 3, 6),
    ("walk", "left", 3, "LavenderTown", 0, 6),
    ("walk", "down", 2, "LavenderTown", 0, 8),
    ("conn", "left", "Route8", 59, 8),
    ("walk", "left", 7, "Route8", 52, 8),
    ("walk", "down", 5, "Route8", 52, 13),
    ("walk", "left", 5, "Route8", 47, 13),
    ("fight", "up", "Route8", 47, 12),
    ("walk", "left", 5, "Route8", 42, 12),
    ("walk", "up", 3, "Route8", 42, 9),
    ("walk", "left", 1, "Route8", 41, 9),
    ("walk", "up", 2, "Route8", 41, 7),
    ("walk", "left", 1, "Route8", 40, 7),
    ("walk", "up", 1, "Route8", 40, 6),
    ("walk", "left", 11, "Route8", 29, 6),
    ("walk", "down", 1, "Route8", 29, 7),
    ("walk", "left", 6, "Route8", 23, 7),
    ("walk", "down", 3, "Route8", 23, 10),
    ("walk", "left", 1, "Route8", 22, 10),
    ("walk", "down", 2, "Route8", 22, 12),
    ("walk", "left", 8, "Route8", 14, 12),
    ("walk", "up", 8, "Route8", 14, 4),
    ("walk", "left", 1, "Route8", 13, 4),
    ("warp", "up", "UndergroundPathRoute8", 5, 7),
    ("walk", "up", 2, "UndergroundPathRoute8", 5, 5),
    ("walk", "right", 1, "UndergroundPathRoute8", 6, 5),
    ("warp", "up", "UndergroundPathWestEast", 47, 2),
    ("walk", "left", 45, "UndergroundPathWestEast", 2, 2),
    ("walk", "down", 2, "UndergroundPathWestEast", 2, 4),
    ("warp", "down", "UndergroundPathRoute7", 6, 4),
    ("walk", "down", 3, "UndergroundPathRoute7", 6, 7),
    ("warp", "down", "Route7", 5, 14),
    ("walk", "right", 3, "Route7", 8, 14),
    ("walk", "up", 5, "Route7", 8, 9),
    ("walk", "left", 4, "Route7", 4, 9),
    ("walk", "up", 3, "Route7", 4, 6),
    ("walk", "left", 2, "Route7", 2, 6),
    ("walk", "up", 3, "Route7", 2, 3),
    ("walk", "left", 2, "Route7", 0, 3),
    ("conn", "left", "CeladonCity", 49, 11),
    ("walk", "left", 8, "CeladonCity", 41, 11),
    ("walk", "up", 1, "CeladonCity", 41, 10),
    ("warp", "up", "CeladonPokecenter", 3, 7),
    ("walk", "up", 4, "CeladonPokecenter", 3, 3),
    ("heal", "CeladonPokecenter"),
    ("walk", "down", 4, "CeladonPokecenter", 3, 7),
    ("warp", "down", "CeladonCity", 41, 10),
    ("walk", "left", 5, "CeladonCity", 36, 10),
    ("walk", "down", 12, "CeladonCity", 36, 22),
    ("walk", "left", 10, "CeladonCity", 26, 22),
    ("walk", "down", 1, "CeladonCity", 26, 23),
    ("walk", "left", 1, "CeladonCity", 25, 23),
    ("walk", "down", 8, "CeladonCity", 25, 31),
    ("walk", "right", 10, "CeladonCity", 35, 31),
    ("cut", "down", "CeladonCity", 35, 31),
    ("walk", "down", 3, "CeladonCity", 35, 34),
    ("walk", "left", 30, "CeladonCity", 5, 34),
    ("walk", "up", 5, "CeladonCity", 5, 29),
    ("walk", "right", 7, "CeladonCity", 12, 29),
    ("walk", "up", 1, "CeladonCity", 12, 28),
    ("warp", "up", "CeladonGym", 5, 17),
    ("walk", "left", 3, "CeladonGym", 2, 17),
    ("walk", "up", 7, "CeladonGym", 2, 10),
    ("walk", "left", 1, "CeladonGym", 1, 10),
    ("walk", "up", 6, "CeladonGym", 1, 4),
    ("walk", "right", 1, "CeladonGym", 2, 4),
    ("cut", "right", "CeladonGym", 2, 4),
    ("walk", "right", 1, "CeladonGym", 3, 4),
    ("fight", "right", "CeladonGym", 4, 4),
    ("walk", "right", 1, "CeladonGym", 5, 4),
    ("erika",),
]


def _k_atoms():
    x, y, where = 20, 12, "Route9"
    atoms = []
    for item in K_LINE:
        kind = item[0]
        if kind == "walk":
            direction, count, place, end_x, end_y = item[1], item[2], item[3], item[4], item[5]
        elif kind == "fight":
            direction, count, place, end_x, end_y = item[1], 1, item[2], item[3], item[4]
        if kind in ("walk", "fight"):
            dx, dy = DELTAS[direction]
            for _ in range(count):
                x += dx
                y += dy
                atoms.append({"op": "step", "dir": direction, "map": where, "x": x, "y": y})
            if (where, x, y) != (place, end_x, end_y):
                raise RuntimeError(f"{item} landed {where} {x},{y}")
        elif kind == "ledge":
            atoms.append({"op": "ledge", "dir": item[1], "map": where, "x": item[-2], "y": item[-1]})
            x, y = item[-2], item[-1]
        elif kind in ("conn", "warp"):
            where, x, y = item[2], item[3], item[4]
            atoms.append({"op": kind, "dir": item[1], "map": where, "x": x, "y": y})
        elif kind == "heal":
            atoms.append({"op": "heal", "map": where, "x": x, "y": y})
        elif kind == "cut":
            atoms.append({"op": "cut", "dir": item[1], "map": where, "x": x, "y": y})
        elif kind == "erika":
            atoms.append({"op": "erika", "map": where, "x": x, "y": y})
    return atoms


def _k_runtime(name):
    blob = json.loads((ROOT / "Source/data/sourceMapCache" / f"runtime-{name}.json").read_text())
    grids = {grid["id"]: grid["terrain"] for grid in blob["definition"]["grids"]}
    rules = blob["definition"]["directional_rules"]
    pairs = {tuple(sorted(pair)) for pair in rules["forbidden_tile_pairs"]}
    return blob["tile_rows"], grids, pairs, rules["ledges"]


def _k_tile(name, x, y):
    pad = K_FILES[name][1]
    rows, grids, pairs, ledges = _k_runtime(name)
    sx = x - pad
    tile = grids[int(rows[y][sx * 2:sx * 2 + 2], 16)]
    return tile, pairs, ledges


def _k_trace():
    opens = {}
    extra = {}
    for cell in [(14, 14), *[(xx, 14) for xx in range(15, 20)], (19, 13), (19, 12), (20, 12)]:
        if cell not in route9_cells():
            raise RuntimeError(f"rejoin closed {cell}")
    x, y, where = 20, 12, "Route9"
    for atom in _k_atoms():
        if atom["map"] not in opens:
            path, pad, width = K_FILES[atom["map"]]
            opens[atom["map"]] = set(open_map(EAST / path, pad, width))
        if atom["op"] == "cut":
            dx, dy = DELTAS[atom["dir"]]
            extra.setdefault(where, set()).add((x + dx, y + dy))
            continue
        if atom["op"] in ("heal", "erika"):
            continue
        spot = (atom["x"], atom["y"])
        opened = extra.get(atom["map"], set())
        if spot not in opens[atom["map"]] | opened:
            raise RuntimeError(f"closed {atom}")
        if atom["op"] == "ledge":
            facing, pad_name, dx, dy = {
                "up": ("SPRITE_FACING_UP", "PAD_UP", 0, -1),
                "down": ("SPRITE_FACING_DOWN", "PAD_DOWN", 0, 1),
                "left": ("SPRITE_FACING_LEFT", "PAD_LEFT", -1, 0),
                "right": ("SPRITE_FACING_RIGHT", "PAD_RIGHT", 1, 0),
            }[atom["dir"]]
            if (x + dx * 2, y + dy * 2) != spot:
                raise RuntimeError(f"ledge span {atom}")
            stand, _pairs, ledges = _k_tile(where, x, y)
            front, _pairs, _ledges = _k_tile(where, x + dx, y + dy)
            if not any(rule["facing"] == facing and rule["input"] == pad_name and rule["standing_foot_tile"] == stand["foot_tile"] and rule["target_foot_tile"] == front["foot_tile"] for rule in ledges):
                raise RuntimeError(f"no ledge {where} {(x, y)} {atom['dir']}")
        elif atom["op"] == "step" and spot not in opened:
            stand, pairs, _ledges = _k_tile(where, x, y)
            dest, _pairs, _ledges = _k_tile(atom["map"], *spot)
            if not dest["land_passable"] or tuple(sorted((stand["foot_tile"], dest["foot_tile"]))) in pairs:
                raise RuntimeError(f"pair block {where} {(x, y)} -> {spot}")
        x, y, where = atom["x"], atom["y"], atom["map"]
    cuts = [atom for atom in _k_atoms() if atom["op"] == "cut" and atom["map"] == "CeladonGym"]
    if len(cuts) != 1 or cuts[0]["dir"] != "right" or (cuts[0]["x"], cuts[0]["y"]) != (2, 4):
        raise RuntimeError(f"gym cut {cuts}")


def _k_here(player):
    zone = str(player.state.get("zone"))
    body = player.state.get("player") or {}
    for name, key in K_ZONES.items():
        if zone == key:
            return name, body.get("x"), body.get("y")
    return None, body.get("x"), body.get("y")


def _k_clear(player, report):
    if player.state.get("root") != "battle":
        if not player.exploring():
            player.dismiss_until_explore(limit=40)
        return None
    before = player.state.get("last_battle_outcome")
    player.fight(limit=2500, potion_at=30, shift_to="pidgeotto")
    player.dismiss_until_explore(limit=80)
    if _lost(before, player.state.get("last_battle_outcome") or {}):
        _note_blackout(report)
        return "blackout"
    _checkpoint(player, report, "saved_k_line")
    return "yield"


def _k_go(player, report, direction, place, end_x, end_y):
    status = _k_clear(player, report)
    if status:
        return status
    player.step(direction)
    if player.state.get("root") == "battle":
        landed = _k_here(player)
        status = _k_clear(player, report)
        if status == "blackout":
            return status
        if landed != (place, end_x, end_y):
            raise RuntimeError(f"fight landed {landed} not {place} {end_x},{end_y}")
        return status
    if not player.exploring():
        status = _k_clear(player, report)
        if status:
            return status
    landed = _k_here(player)
    if landed != (place, end_x, end_y):
        block = (player.state.get("player") or {}).get("lastTraversalBlock")
        raise RuntimeError(f"{direction} landed {landed} not {place} {end_x},{end_y} block {block}")
    if place in ("LavenderTown", "CeladonCity") and (end_x, end_y) in ((9, 0), (49, 11)):
        _checkpoint(player, report, "saved_" + place)
    return None


def _rejoin_route9(player, report):
    while True:
        name, x, y = _k_here(player)
        if (name, x, y) == ("Route9", 20, 12):
            return None
        if name != "Route9":
            raise RuntimeError(f"rejoin left Route 9 at {name} {x},{y}")
        if y >= 15:
            direction, end = "up", (x, y - 1)
        elif y == 14 and x < 19:
            direction, end = "right", (x + 1, y)
        elif x == 19 and y > 12:
            direction, end = "up", (x, y - 1)
        elif y == 12 and x < 20:
            direction, end = "right", (x + 1, y)
        else:
            raise RuntimeError(f"Route 9 shelf has no rejoin at {x},{y}")
        status = _k_go(player, report, direction, "Route9", *end)
        if status:
            return status


def _grind_route7(player, report):
    species, mon = _bird(player)
    if not species or (mon.get("level") or 0) >= 31 or (mon.get("hp") or 0) <= 0:
        return None
    _lead(player, species)
    status = _grind_bird(player, report, route7_cells(), (8, 2), (9, 2), set(ROUTE7_GATES) | {(5, 13)}, level=31, limit=4)
    if status == "blackout":
        return "blackout"
    _walk(player, route7_cells(), map_surface(EAST / "Route7.json"), (5, 14), set(ROUTE7_GATES) | {(5, 13)})
    _checkpoint(player, report, "saved_route7_grind")
    _, mon = _bird(player)
    if (mon.get("level") or 0) < 31:
        return "yield"
    return None


def _one_step(player, report, direction, place, x, y, cut=False):
    """One real step. A tree on the known path is cut once, then stepped through."""
    status = _k_clear(player, report)
    if status:
        return status
    player.step(direction)
    if player.state.get("root") == "battle":
        return _k_clear(player, report)
    if _k_here(player) != (place, x, y) and cut:
        _confirm_cut(player, direction)
        player.step(direction)
        if player.state.get("root") == "battle":
            return _k_clear(player, report)
    landed = _k_here(player)
    if landed != (place, x, y):
        block = (player.state.get("player") or {}).get("lastTraversalBlock")
        raise RuntimeError(f"{direction} landed {landed} not {place} {x},{y} block {block}")
    return None


def _corner_walk(player, report, goal, avoid):
    """Follow open Game Corner floor tiles. The Rocket's own tile stays closed."""
    cells = set(open_map(EAST / "GameCorner.json", 0, 20))
    for _ in range(40):
        _name, x, y = _k_here(player)
        if (x, y) == goal:
            return None
        steps = route(cells, (x, y), goal, avoid)
        if not steps:
            raise RuntimeError(f"no Game Corner path {(x, y)} -> {goal}")
        dx, dy = DELTAS[steps[0]]
        status = _one_step(player, report, steps[0], "GameCorner", x + dx, y + dy)
        if status:
            return status
    raise RuntimeError("the Game Corner walk stalled at " + json.dumps(summary(player.state)))


def _settle_hideout_scene(player, limit=80):
    """Dialog takes A. The Rocket's walk finishes on its own."""
    for _ in range(limit):
        if player.exploring():
            return True
        if player.state.get("root") == "battle":
            return False
        phase = (player.state.get("event") or {}).get("phase")
        if phase in ("move-npc", "move"):
            player.send("wait 12")
            continue
        dialog = player.state.get("dialog") or {}
        if player.state.get("root") == "dialog" and not dialog.get("ready"):
            player.send("wait 6")
        else:
            player.press("a", wait=6)
    return player.exploring()


HIDEOUT_FLOORS = {
    "RocketHideoutB1F": {
        "file": "RocketHideoutB1F.json", "width": 30, "goal": (23, 2), "next": "b2f",
        "zone": "pokered:ROCKET_HIDEOUT_B1F",
        "warps": {(21, 2), (23, 2), (24, 19), (21, 24), (25, 19)},
        "up": (23, 2), "up_next": "b2f",
        # The $54 door stays shut until the Rocket behind it falls. His side is the lift.
        "blocked": {(26, 8), (12, 6), (18, 17), (15, 25), (28, 18), (11, 14), (9, 17), (24, 16), (25, 16)},
    },
    "RocketHideoutB2F": {
        "file": "RocketHideoutB2F.json", "width": 30, "goal": (21, 8), "next": "b3f",
        "zone": "pokered:ROCKET_HIDEOUT_B2F",
        "warps": {(27, 8), (21, 8), (24, 19), (21, 22), (25, 19)},
        "up": (27, 8), "up_next": "b1f",
        "blocked": {(20, 12), (20, 13), (20, 14), (20, 15), (20, 16), (1, 11), (16, 8), (6, 12), (3, 21)},
    },
    "RocketHideoutB3F": {
        "file": "RocketHideoutB3F.json", "width": 30, "goal": (19, 18), "next": "b4f",
        "zone": "pokered:ROCKET_HIDEOUT_B3F",
        "warps": {(25, 6), (19, 18)},
        "up": (25, 6), "up_next": "b2f",
        "blocked": {(10, 22), (26, 12), (26, 17), (20, 14)},
    },
}


def _spinner_ends(zone_id):
    data = json.loads((ROOT / "Source/data/rocketHideoutStory/scenes.json").read_text(encoding="utf-8"))
    ends = {}
    for spinner in data["scenes"]["spinners"].get(zone_id, []):
        x, y = spinner["x"], spinner["y"]
        for direction in spinner["path"]:
            x, y = neighbor((x, y), direction)
        ends[(spinner["x"], spinner["y"])] = (x, y)
    return ends


def _hideout_route(place, start, goal):
    """Open-floor walk. An arrow tile is one step that finishes at the script's end cell."""
    spec = HIDEOUT_FLOORS[place]
    cells = set(open_map(EAST / spec["file"], 0, spec["width"]))
    cells.add(start)
    spins = _spinner_ends(spec["zone"])
    avoid = set(spec["warps"]) | set(spec["blocked"])
    avoid.discard(start)
    avoid.discard(goal)
    previous = {start: None}
    queue = deque([start])
    while queue:
        here = queue.popleft()
        if here == goal:
            break
        for direction in DELTAS:
            nxt = neighbor(here, direction)
            if nxt not in cells or nxt in avoid or nxt in previous:
                continue
            if nxt in spins and nxt != goal:
                landed = spins[nxt]
                if landed in previous or landed in avoid:
                    continue
                previous[landed] = (here, direction, "spin", landed)
                queue.append(landed)
            else:
                kind = "warp" if nxt == goal else "step"
                previous[nxt] = (here, direction, kind, nxt)
                queue.append(nxt)
    if goal not in previous:
        raise RuntimeError(f"no {place} path {start} -> {goal}")
    steps = []
    cursor = goal
    while cursor != start:
        came, direction, kind, landed = previous[cursor]
        steps.append((direction, kind, landed))
        cursor = came
    steps.reverse()
    return steps


def _hideout_spin(player, report, direction, place, landed):
    status = _k_clear(player, report)
    if status:
        return status
    player.step(direction)
    if player.state.get("root") == "battle":
        return _k_clear(player, report)
    for _ in range(40):
        if player.exploring() and _k_here(player) == (place, landed[0], landed[1]):
            return None
        if not _settle_hideout_scene(player, 4):
            if player.state.get("root") == "battle":
                return _k_clear(player, report)
    raise RuntimeError(f"arrow stopped at {_k_here(player)} not {place} {landed}")


def _hideout_stairs(player, report, place, upward=False, goal=None, expect=None):
    spec = HIDEOUT_FLOORS[place]
    _name, x, y = _k_here(player)
    if goal is None:
        goal = spec["up"] if upward else spec["goal"]
    if expect is None:
        expect = spec["up_next"] if upward else spec["next"]
    if (x, y) == goal:
        for direction in DELTAS:
            nxt = neighbor(goal, direction)
            cells = set(open_map(EAST / spec["file"], 0, spec["width"]))
            if nxt in cells and nxt not in spec["blocked"] and nxt not in spec["warps"]:
                status = _k_go(player, report, direction, place, nxt[0], nxt[1])
                return status or "yield"
        raise RuntimeError("standing on the stair with no step off")
    for direction, kind, landed in _hideout_route(place, (x, y), goal):
        if kind == "warp":
            status = _k_clear(player, report)
            if status:
                return status
            player.step(direction)
            player.settle(limit=80)
            if player.state.get("root") == "battle":
                return _k_clear(player, report)
            if not player.exploring():
                status = _k_clear(player, report)
                if status:
                    return status
            zone = str(player.state.get("zone"))
            if expect not in zone:
                raise RuntimeError("the stair did not change floors: " + json.dumps(summary(player.state)))
            _checkpoint(player, report, "saved_hideout")
            return "yield"
        if kind == "spin":
            status = _hideout_spin(player, report, direction, place, landed)
        else:
            status = _k_go(player, report, direction, place, landed[0], landed[1])
        if status:
            return status
    raise RuntimeError("the stair walk ended on the same floor")


def _b4_walk(player, report, goal, avoid):
    cells = set(open_map(EAST / "RocketHideoutB4F.json", 0, 30))
    for _ in range(40):
        _name, x, y = _k_here(player)
        if (x, y) == goal:
            return None
        blocked = set(avoid)
        blocked.discard((x, y))
        steps = route(cells, (x, y), goal, blocked)
        if not steps:
            raise RuntimeError(f"no B4F path {(x, y)} -> {goal}")
        nxt = neighbor((x, y), steps[0])
        status = _k_go(player, report, steps[0], "RocketHideoutB4F", nxt[0], nxt[1])
        if status:
            return status
    raise RuntimeError("the B4F walk stalled at " + json.dumps(summary(player.state)))


def _hideout_b4(player, report):
    """The lift-key Rocket is on the stair side. The east door opens after two fights."""
    quest = _quest(player)
    avoid = {
        (19, 10), (24, 15), (25, 15), (25, 3), (23, 12), (26, 12),
        (11, 2), (25, 2), (9, 4), (10, 12), (12, 20), (10, 2),
    }
    if not quest.get("EVENT_ROCKET_HIDEOUT_4_DOOR_UNLOCKED"):
        avoid.update({(24, 11), (25, 11)})
    if not quest.get("EVENT_ROCKET_DROPPED_LIFT_KEY"):
        _name, x, y = _k_here(player)
        if (x, y) != (11, 3):
            status = _b4_walk(player, report, (11, 3), avoid)
            if status:
                return status
        if player.state.get("root") == "battle":
            return _k_clear(player, report)
        # The drop is the second talk, after the receipt is gone.
        if (player.state.get("player") or {}).get("facing") != "up":
            player.press("up", wait=8)
        player.press("a", wait=8)
        if player.state.get("root") == "battle":
            return _k_clear(player, report)
        if not _settle_hideout_scene(player, 40):
            raise RuntimeError("the lift key was not dropped: " + json.dumps(summary(player.state)))
        if not (_quest(player) or {}).get("EVENT_ROCKET_DROPPED_LIFT_KEY"):
            raise RuntimeError("the lift-key talk did not set the flag: " + json.dumps(summary(player.state)))
    avoid.discard((10, 2))
    if not _holding(player, "liftKey"):
        status = _b4_walk(player, report, (10, 3), avoid)
        if status:
            return status
        if (player.state.get("player") or {}).get("facing") != "up":
            player.press("up", wait=8)
        player.press("a", wait=8)
        if not _settle_hideout_scene(player, 30):
            raise RuntimeError("the lift key text did not finish: " + json.dumps(summary(player.state)))
        if not _holding(player, "liftKey"):
            raise RuntimeError("the lift key was not taken: " + json.dumps(summary(player.state)))
        _checkpoint(player, report, "saved_lift_key")
        return "yield"
    # The stair side does not connect to Giovanni. The B2F lift does.
    _name, x, y = _k_here(player)
    if x >= 22:
        return _hideout_east(player, report)
    status = _b4_walk(player, report, (19, 11), avoid)
    if status:
        return status
    player.step("up")
    player.settle(limit=80)
    if "b3f" not in str(player.state.get("zone")):
        raise RuntimeError("the B4F stair did not go up: " + json.dumps(summary(player.state)))
    _checkpoint(player, report, "saved_hideout")
    return "yield"


def _holding(player, item):
    def walk(value):
        if isinstance(value, dict):
            if value.get("id") == item and value.get("quantity", 0) > 0:
                return True
            if isinstance(value.get(item), (int, float)) and value[item] > 0:
                return True
            return any(walk(child) for child in value.values())
        if isinstance(value, list):
            return any(walk(child) for child in value)
        return False
    return walk(player.state.get("session") or {})


def _beaten(player, event_id):
    flags = ((player.state.get("session") or {}).get("flags") or {}).get("trainers") or {}
    if isinstance(flags, dict):
        return bool(flags.get(event_id))
    return event_id in flags


def _through_hideout(player, report):
    place, _x, _y = _k_here(player)
    if _holding(player, "silphScope"):
        return _leave_hideout(player, report)
    upward = _holding(player, "liftKey") and not _holding(player, "silphScope")
    if place == "RocketHideoutElevator":
        return _hideout_floor(player, report)
    if place == "RocketHideoutB2F" and upward:
        return _hideout_elevator(player, report)
    if place in HIDEOUT_FLOORS:
        return _hideout_stairs(player, report, place, upward=upward)
    if place == "RocketHideoutB4F":
        return _hideout_b4(player, report)
    raise RuntimeError("off the Hideout floors: " + json.dumps(summary(player.state)))


def _hideout_elevator(player, report):
    """B2F's lift opens onto Giovanni. B1F's door stays shut until the far Rocket falls."""
    goal = (24, 18)
    _name, x, y = _k_here(player)
    if (x, y) != goal:
        for direction, kind, landed in _hideout_route("RocketHideoutB2F", (x, y), goal):
            if kind == "spin":
                status = _hideout_spin(player, report, direction, "RocketHideoutB2F", landed)
            else:
                status = _k_go(player, report, direction, "RocketHideoutB2F", landed[0], landed[1])
            if status:
                return status
    status = _k_clear(player, report)
    if status:
        return status
    player.step("down")
    player.settle(limit=80)
    if "elevator" not in str(player.state.get("zone")):
        raise RuntimeError("the lift door stayed shut: " + json.dumps(summary(player.state)))
    return _hideout_floor(player, report)


def _hideout_floor(player, report, floor="B4F", expect="b4f"):
    """The panel is the wall left of the cabin exits. The menu is B1F, B2F, B4F."""
    _name, x, y = _k_here(player)
    if y != 1:
        status = _k_go(player, report, "up", "RocketHideoutElevator", x, 1)
        if status:
            return status
        _name, x, y = _k_here(player)
    if x != 5:
        status = _k_go(player, report, "left" if x > 5 else "right", "RocketHideoutElevator", 5, 1)
        if status:
            return status
    if (player.state.get("player") or {}).get("facing") != "left":
        player.press("left", wait=8)
    player.press("a", wait=8)
    for _ in range(12):
        options = ((player.state.get("event") or {}).get("menu") or {}).get("options") or []
        if floor in options:
            player.choose("event", floor)
            player.settle(limit=20)
            break
        if player.exploring():
            raise RuntimeError("the lift panel did not open: " + json.dumps(summary(player.state)))
        player.press("a", wait=8)
    else:
        raise RuntimeError(f"the lift never offered {floor}: " + json.dumps(summary(player.state)))
    if not player.exploring():
        if not player.dismiss_until_explore(limit=40):
            raise RuntimeError("the lift menu stayed up: " + json.dumps(summary(player.state)))
    player.step("down")
    player.settle(limit=30)
    player.step("up")
    player.settle(limit=80)
    if expect not in str(player.state.get("zone")):
        raise RuntimeError(f"the lift did not reach {floor}: " + json.dumps(summary(player.state)))
    _checkpoint(player, report, "saved_elevator")
    return "yield"


def _hideout_east(player, report):
    """The two sightless Rockets open the office door. Giovanni is the talk after that."""
    cells = set(open_map(EAST / "RocketHideoutB4F.json", 0, 30))
    quest = _quest(player)
    rockets = (
        "pokered:ROCKET_HIDEOUT_B4F:objects:2",
        "pokered:ROCKET_HIDEOUT_B4F:objects:3",
    )
    door_open = quest.get("EVENT_ROCKET_HIDEOUT_4_DOOR_UNLOCKED") or all(_beaten(player, event_id) for event_id in rockets)
    door = set() if door_open else {(24, 11), (25, 11)}
    avoid = {(19, 10), (24, 15), (25, 15), (25, 2), (10, 2), (11, 2), (9, 4), (10, 12), (12, 20)} | door
    _name, x, y = _k_here(player)
    if (x, y) in avoid:
        for direction, (dx, dy) in DELTAS.items():
            nxt = (x + dx, y + dy)
            if nxt in cells and nxt not in avoid:
                status = _k_go(player, report, direction, "RocketHideoutB4F", nxt[0], nxt[1])
                if status:
                    return status
                break
        else:
            raise RuntimeError("boxed in on the east side: " + json.dumps(summary(player.state)))
    for event_id in rockets:
        if _beaten(player, event_id):
            continue
        talked = talk_to(player, cells, event_id, avoid)
        if player.state.get("root") == "battle" or not player.exploring():
            return _k_clear(player, report)
        if talked != "talked":
            raise RuntimeError(f"{event_id} did not battle: " + json.dumps(summary(player.state)))
    if not _beaten(player, "pokered:ROCKET_HIDEOUT_B4F:objects:1"):
        talked = talk_to(player, cells, "pokered:ROCKET_HIDEOUT_B4F:objects:1", avoid)
        if player.state.get("root") == "battle" or not player.exploring():
            return _k_clear(player, report)
        if talked != "talked":
            raise RuntimeError("Giovanni did not battle: " + json.dumps(summary(player.state)))
    if not _holding(player, "silphScope"):
        status = _b4_walk(player, report, (26, 2), avoid)
        if status:
            return status
        if (player.state.get("player") or {}).get("facing") != "left":
            player.press("left", wait=8)
        player.press("a", wait=8)
        if not _settle_hideout_scene(player, 30):
            raise RuntimeError("the Silph Scope text did not finish: " + json.dumps(summary(player.state)))
        if not _holding(player, "silphScope"):
            raise RuntimeError("the Silph Scope was not taken: " + json.dumps(summary(player.state)))
        _checkpoint(player, report, "saved_scope")
        return "yield"
    _checkpoint(player, report, "saved_hideout_east")
    return "yield"


CELADON_DOORS = {
    (8, 13), (10, 13), (24, 9), (24, 3), (25, 3), (41, 9), (12, 27),
    (28, 19), (39, 19), (33, 19), (31, 27), (35, 27), (43, 27),
}


def _needs_center(player):
    members = (((player.state.get("session") or {}).get("party") or {}).get("members") or [])
    return any((mon.get("hp") or 0) <= 0 for mon in members)


def _leave_hideout(player, report):
    """The scope is in the bag. B2F's lift is the way out; B1F's door is still shut."""
    place, x, y = _k_here(player)
    if place == "RocketHideoutB4F":
        if (x, y) != (24, 14):
            status = _b4_walk(player, report, (24, 14), {(25, 15), (19, 10), (11, 2), (10, 2), (25, 2)})
            if status:
                return status
        player.step("down")
        player.settle(limit=80)
        if "elevator" not in str(player.state.get("zone")):
            raise RuntimeError("the lift did not open: " + json.dumps(summary(player.state)))
        return _hideout_floor(player, report, "B2F", "b2f")
    if place == "RocketHideoutElevator":
        return _hideout_floor(player, report, "B2F", "b2f")
    if place == "RocketHideoutB2F":
        return _hideout_stairs(player, report, place, upward=True)
    if place == "RocketHideoutB1F":
        return _hideout_stairs(player, report, place, goal=(21, 2), expect="game_corner")
    if place == "GameCorner":
        if (x, y) == (17, 4):
            status = _one_step(player, report, "down", "GameCorner", 17, 5)
            if status:
                return status
            _name, x, y = _k_here(player)
        avoid = {
            (17, 4), (15, 17), (16, 17), (9, 5),
            (2, 6), (5, 6), (2, 10), (2, 13), (5, 11), (8, 11), (8, 14), (11, 15), (14, 11), (17, 13),
        }
        avoid.discard((x, y))
        status = _corner_walk(player, report, (15, 16), avoid)
        if status:
            return status
        player.step("down")
        player.settle(limit=80)
        if _k_here(player)[:1] == ("GameCorner",) and _k_here(player)[2] == 17:
            # The street door is an edge mat: land on it, then walk down.
            player.step("down")
            player.settle(limit=80)
        if "celadon" not in str(player.state.get("zone")):
            raise RuntimeError("the Game Corner door stayed shut: " + json.dumps(summary(player.state)))
        _checkpoint(player, report, "saved_celadon")
        return "yield"
    raise RuntimeError("the scope leave left the Hideout: " + json.dumps(summary(player.state)))


def _city_walk(player, report, goal):
    cells = set(open_map(EAST / "CeladonCity.json", 0, 50))
    for _ in range(40):
        _name, x, y = _k_here(player)
        if (x, y) == goal:
            return None
        blocked = set(CELADON_DOORS)
        blocked.discard((x, y))
        blocked.discard(goal)
        steps = route(cells, (x, y), goal, blocked)
        if not steps:
            raise RuntimeError(f"no Celadon path {(x, y)} -> {goal}")
        nxt = neighbor((x, y), steps[0])
        status = _k_go(player, report, steps[0], "CeladonCity", nxt[0], nxt[1])
        if status:
            return status
    raise RuntimeError("the Celadon walk stalled at " + json.dumps(summary(player.state)))


def _center_heal(player, report):
    if not _needs_center(player):
        return None
    for y in (6, 5, 4, 3):
        if _k_here(player) == ("CeladonPokecenter", 3, y):
            break
        status = _one_step(player, report, "up", "CeladonPokecenter", 3, y)
        if status:
            return status
    cells = set(open_map(EAST / K_FILES["CeladonPokecenter"][0], *K_FILES["CeladonPokecenter"][1:]))
    talk_to(player, cells, K_NURSE["CeladonPokecenter"], set())
    if _needs_center(player):
        raise RuntimeError("the nurse did not heal: " + json.dumps(summary(player.state)))
    _checkpoint(player, report, "saved_scope_healed")
    return "yield"


def _scope_walk(player, report, filename, pad, width, place, goal, avoid):
    cells = set(open_map(EAST / filename, pad, width))
    for _ in range(60):
        _name, x, y = _k_here(player)
        if (x, y) == goal:
            return None
        blocked = set(avoid)
        blocked.discard((x, y))
        blocked.discard(goal)
        steps = route(cells, (x, y), goal, blocked)
        if not steps:
            raise RuntimeError(f"no {place} path {(x, y)} -> {goal}")
        nxt = neighbor((x, y), steps[0])
        status = _k_go(player, report, steps[0], place, nxt[0], nxt[1])
        if status:
            return status
    raise RuntimeError(f"the {place} walk stalled at " + json.dumps(summary(player.state)))


OPPOSITE = {"up": "down", "down": "up", "left": "right", "right": "left"}


def _back_along_route8(player, report):
    """Retrace K's Route 8 atoms from the basement stair to Lavender."""
    atoms = _k_atoms()
    start = next(i for i, atom in enumerate(atoms) if atom["op"] == "conn" and atom["map"] == "Route8")
    end = next(i for i, atom in enumerate(atoms)
               if atom["op"] == "step" and atom["map"] == "Route8" and (atom["x"], atom["y"]) == (13, 4))
    backs = []
    for atom in reversed(atoms[start + 1:end + 1]):
        dx, dy = DELTAS[atom["dir"]]
        backs.append((OPPOSITE[atom["dir"]], atom["x"] - dx, atom["y"] - dy))
    _name, x, y = _k_here(player)
    door = (atoms[start]["x"], atoms[start]["y"])
    if (x, y) == (13, 4):
        begin = 0
    elif (x, y) == door:
        begin = len(backs)
    else:
        hits = [i for i, step in enumerate(backs) if (step[1], step[2]) == (x, y)]
        if not hits:
            raise RuntimeError(f"off the Route 8 return at {(x, y)}")
        begin = hits[0] + 1
    species, _mon = _bird(player)
    if species:
        _lead(player, species)
    for direction, nx, ny in backs[begin:]:
        status = _k_go(player, report, direction, "Route8", nx, ny)
        if status:
            return status
    player.step("right")
    player.settle(limit=80)
    if "lavender" not in str(player.state.get("zone")):
        raise RuntimeError("Lavender did not open: " + json.dumps(summary(player.state)))
    _checkpoint(player, report, "saved_lavender")
    return "yield"


TOWER_UP = {
    "PokemonTower1F": ("PokemonTower2F", (18, 9)),
    "PokemonTower2F": ("PokemonTower3F", (3, 9)),
    "PokemonTower3F": ("PokemonTower4F", (18, 9)),
    "PokemonTower4F": ("PokemonTower5F", (3, 9)),
    "PokemonTower5F": ("PokemonTower6F", (18, 9)),
    "PokemonTower6F": ("PokemonTower7F", (9, 16)),
}
TOWER_FACE = {"LEFT": (-1, 0), "RIGHT": (1, 0), "UP": (0, -1), "DOWN": (0, 1)}


def _present_ids(player):
    return {npc.get("source_event_id") for npc in (player.state.get("npcs") or [])}


def _tower_layers(name, present):
    blob = json.loads((SOUTH / f"{name}.json").read_text())
    people, warps, items = set(), set(), []
    for obj in blob["events"]["objects"]:
        if obj["id"] not in present:
            continue
        cell = (obj["x"], obj["y"])
        if obj.get("kind") == "item":
            items.append((obj["id"], cell))
        else:
            people.add(cell)
    for warp in blob["events"]["warps"]:
        warps.add((warp["x"], warp["y"]))
    sight = set()
    trainers = json.loads((SOUTH / "trainers.json").read_text())["trainers"]
    floor = name[len("PokemonTower"):]
    for trainer in trainers.values():
        if trainer.get("map_id") != f"pokered:POKEMON_TOWER_{floor}" or trainer["id"] not in present:
            continue
        dx, dy = TOWER_FACE[trainer["facing_source"]]
        for step in range(1, int(trainer["sight_range_cells"]) + 1):
            sight.add((trainer["x"] + dx * step, trainer["y"] + dy * step))
    return people, warps, sight, items


def _tower_route(name, here, goal, present):
    cells = set(open_map(SOUTH / f"{name}.json", 0, 20))
    people, warps, sight, items = _tower_layers(name, present)
    item_cells = {cell for _item, cell in items}
    for extra in (sight, set()):
        avoid = set(people) | set(warps) | set(item_cells) | set(extra)
        avoid.discard(here)
        avoid.discard(goal)
        steps = route(cells, here, goal, avoid)
        if steps:
            return cells, steps, None
    for extra in (sight, set()):
        for item_id, cell in items:
            avoid = set(people) | set(warps) | (item_cells - {cell}) | set(extra)
            avoid.discard(here)
            avoid.discard(goal)
            if route(cells, here, goal, avoid):
                return cells, None, item_id
    return cells, None, None


def _tower_move(player, report, direction, place, nx, ny, nxt):
    status = _k_clear(player, report)
    if status:
        return status
    player.step(direction)
    if player.state.get("root") == "battle" or not player.exploring():
        status = _k_clear(player, report)
        if status:
            return status
    landed = _k_here(player)[0]
    if landed != place:
        if landed != nxt:
            raise RuntimeError(f"{direction} left {place} for {landed}, wanted {nxt}: " + json.dumps(summary(player.state)))
        _checkpoint(player, report, "saved_tower")
        return "yield"
    if _k_here(player) != (place, nx, ny):
        block = (player.state.get("player") or {}).get("lastTraversalBlock")
        raise RuntimeError(f"{direction} landed {_k_here(player)} not {place} {nx},{ny} block {block}")
    return None


def _pickup_item(player, report, place, item_id):
    """Face a floor item from an open neighbor. The ball's own tile is solid to a step."""
    present = _present_ids(player)
    people, warps, sight, items = _tower_layers(place, present)
    cell = next(item_cell for item, item_cell in items if item == item_id)
    cells = set(open_map(SOUTH / f"{place}.json", 0, 20))
    avoid = set(people) | set(warps) | set(sight) | {item_cell for _item, item_cell in items}
    _name, x, y = _k_here(player)
    spots = []
    for direction, (dx, dy) in DELTAS.items():
        spot = (cell[0] - dx, cell[1] - dy)
        if spot in cells and (spot not in avoid or spot == (x, y)):
            spots.append((abs(spot[0] - x) + abs(spot[1] - y), spot, direction))
    if not spots:
        raise RuntimeError(f"no open side of {item_id}")
    _distance, spot, direction = min(spots)
    if (x, y) != spot:
        blocked = set(avoid)
        blocked.discard((x, y))
        blocked.discard(spot)
        steps = route(cells, (x, y), spot, blocked)
        if not steps:
            raise RuntimeError(f"no path beside {item_id} from {(x, y)}")
        nx, ny = neighbor((x, y), steps[0])
        return _tower_move(player, report, steps[0], place, nx, ny, place)
    if player.state["player"].get("facing") != direction:
        player.press(direction, wait=4)
    player.press("a", wait=8)
    if not player.exploring():
        player.dismiss_until_explore(limit=40)
    if npc_named(player.state, item_id):
        raise RuntimeError(f"{item_id} stayed on the floor")
    return None


def _climb_tower(player, report):
    place = _k_here(player)[0]
    if place == "PokemonTower7F":
        return _rescue_fuji(player, report)
    nxt, goal = TOWER_UP[place]
    present = _present_ids(player)
    _name, x, y = _k_here(player)
    if (x, y) == goal:
        people, warps, _sight, items = _tower_layers(place, present)
        taken = {cell for _item, cell in items}
        cells = set(open_map(SOUTH / f"{place}.json", 0, 20))
        for direction, (dx, dy) in DELTAS.items():
            spot = (x + dx, y + dy)
            if spot in cells and spot not in people and spot not in warps and spot not in taken:
                status = _tower_move(player, report, direction, place, spot[0], spot[1], place)
                if status:
                    return status
                break
        else:
            raise RuntimeError(f"no step off the {place} stair")
    for _ in range(40):
        present = _present_ids(player)
        _name, x, y = _k_here(player)
        cells, steps, item_id = _tower_route(place, (x, y), goal, present)
        if item_id:
            status = _pickup_item(player, report, place, item_id)
            if status:
                return status
            continue
        if not steps:
            raise RuntimeError(f"no {place} stair from {(x, y)}")
        direction = steps[0]
        nx, ny = neighbor((x, y), direction)
        status = _tower_move(player, report, direction, place, nx, ny, nxt if (nx, ny) == goal else place)
        if status:
            return status
        if _k_here(player)[0] != place:
            return "yield"
    raise RuntimeError(f"the {place} stair stayed out of reach: " + json.dumps(summary(player.state)))


def _rescue_fuji(player, report):
    for _ in range(20):
        _name, x, y = _k_here(player)
        if (x, y) == (10, 4):
            break
        _cells, steps, item_id = _tower_route("PokemonTower7F", (x, y), (10, 4), _present_ids(player))
        if item_id or not steps:
            raise RuntimeError(f"no path to Fuji from {(x, y)} item {item_id}")
        direction = steps[0]
        nx, ny = neighbor((x, y), direction)
        status = _tower_move(player, report, direction, "PokemonTower7F", nx, ny, "PokemonTower7F")
        if status:
            return status
    cells = set(open_map(SOUTH / "PokemonTower7F.json", 0, 20))
    people, warps, _sight, _items = _tower_layers("PokemonTower7F", _present_ids(player))
    result = talk_to(player, cells, "pokered:POKEMON_TOWER_7F:objects:4", people | warps)
    if result != "talked":
        raise RuntimeError("Fuji did not answer: " + result + " " + json.dumps(summary(player.state)))
    if _k_here(player)[0] != "MrFujisHouse":
        raise RuntimeError("Fuji stayed in the tower: " + json.dumps(summary(player.state)))
    _checkpoint(player, report, "saved_fuji")
    return "yield"


def _grid_walk(player, report, folder, filename, pad, width, place, goal, avoid):
    cells = set(open_map(folder / filename, pad, width))
    for _ in range(40):
        _name, x, y = _k_here(player)
        if (x, y) == goal:
            return None
        blocked = set(avoid)
        blocked.discard((x, y))
        blocked.discard(goal)
        steps = route(cells, (x, y), goal, blocked)
        if not steps:
            raise RuntimeError(f"no {place} path {(x, y)} -> {goal}")
        nxt = neighbor((x, y), steps[0])
        status = _k_go(player, report, steps[0], place, nxt[0], nxt[1])
        if status:
            return status
    raise RuntimeError(f"the {place} walk stalled at " + json.dumps(summary(player.state)))


def _house_avoid():
    blob = json.loads((EAST / "MrFujisHouse.json").read_text())
    avoid = set()
    for obj in blob["events"]["objects"]:
        avoid.add((obj["x"] + 2, obj["y"]))
    for warp in blob["events"]["warps"]:
        avoid.add((warp["x"] + 2, warp["y"]))
    return avoid


def _leave_fujis_house(player, report):
    status = _grid_walk(player, report, EAST, "MrFujisHouse.json", 2, 13,
                        "MrFujisHouse", (4, 6), _house_avoid())
    if status:
        return status
    player.step("down")
    player.settle(limit=80)
    if _k_here(player)[0] == "MrFujisHouse" and _k_here(player)[2] == 7:
        player.step("down")
        player.settle(limit=80)
    if _k_here(player)[0] != "LavenderTown":
        raise RuntimeError("Fuji's door stayed shut: " + json.dumps(summary(player.state)))
    _checkpoint(player, report, "saved_flute_out")
    return "yield"


def _lavender_center(player, report):
    avoid = {(5, 3), (2, 6), (11, 2), (3, 1), (3, 7), (4, 7)}
    if _needs_center(player):
        status = _grid_walk(player, report, EAST, "LavenderPokecenter.json", 0, 14,
                            "LavenderPokecenter", (3, 3), avoid)
        if status:
            return status
        cells = set(open_map(EAST / "LavenderPokecenter.json", 0, 14))
        talk_to(player, cells, K_NURSE["LavenderPokecenter"], avoid)
        if _needs_center(player):
            raise RuntimeError("the Lavender nurse did not heal: " + json.dumps(summary(player.state)))
        _checkpoint(player, report, "saved_lavender_healed")
        return "yield"
    status = _grid_walk(player, report, EAST, "LavenderPokecenter.json", 0, 14,
                        "LavenderPokecenter", (3, 6), avoid)
    if status:
        return status
    player.step("down")
    player.settle(limit=80)
    if _k_here(player)[0] == "LavenderPokecenter":
        player.step("down")
        player.settle(limit=80)
    if _k_here(player)[0] != "LavenderTown":
        raise RuntimeError("the Center door stayed shut: " + json.dumps(summary(player.state)))
    _checkpoint(player, report, "saved_lavender_healed")
    return "yield"


def _flute_lavender(player, report):
    if _needs_center(player):
        status = _grid_walk(player, report, EAST, "LavenderTown.json", 0, 20,
                            "LavenderTown", (3, 6), set(LAVENDER_DOORS))
        if status:
            return status
        player.step("up")
        player.settle(limit=80)
        if _k_here(player)[0] != "LavenderPokecenter":
            raise RuntimeError("the Center door stayed shut: " + json.dumps(summary(player.state)))
        return _lavender_center(player, report)
    status = _grid_walk(player, report, EAST, "LavenderTown.json", 0, 20,
                        "LavenderTown", (8, 16), set(LAVENDER_DOORS) | {(8, 17), (9, 17)})
    if status:
        return status
    player.step("down")
    player.settle(limit=80)
    if _k_here(player)[0] == "LavenderTown" and _k_here(player)[2] == 17:
        player.step("down")
        player.settle(limit=80)
    if _k_here(player)[0] != "Route12":
        raise RuntimeError("Route 12 did not open: " + json.dumps(summary(player.state)))
    _checkpoint(player, report, "saved_route12")
    return "yield"


def _play_flute(player, report):
    if not player.exploring():
        player.dismiss_until_explore(limit=20)
    player.press("b", wait=10)
    player.choose("pause", _menu_label(player, "pause", "ITEM"))
    for _ in range(24):
        if player.state.get("root") != "bag":
            break
        bag = player.state.get("bag") or {}
        if bag.get("phase") == "actions":
            player.choose("bag", "USE")
            continue
        if bag.get("phase") not in (None, "list", "closed"):
            player.press("a", wait=4)
            continue
        slots = (player.state.get("inventory") or {}).get("slots") or []
        index = next((i for i, entry in enumerate(slots, start=1) if entry.get("id") == "pokeFlute"), None)
        if index is None:
            raise RuntimeError("the Poké Flute is not in the bag")
        selected = bag.get("selected") or 1
        if selected != index:
            player.press("down" if index > selected else "up", wait=2)
        else:
            player.press("a", wait=6)
    for _ in range(40):
        root = player.state.get("root")
        if root == "battle":
            return _k_clear(player, report)
        if root in ("dialog", "bag", "pause") or not player.exploring():
            player.press("a", wait=8)
            continue
        break
    if player.state.get("root") == "battle":
        return _k_clear(player, report)
    raise RuntimeError("the flute did nothing: " + json.dumps(summary(player.state)))


def _route12_gate(player, report):
    status = _grid_walk(player, report, SOUTH, "Route12.json", 0, 20, "Route12", (10, 14), {(10, 15), (11, 15)})
    if status:
        return status
    player.step("down")
    player.settle(limit=80)
    if _k_here(player) == ("Route12", 10, 15) or _k_here(player) == ("Route12", 11, 15):
        player.step("down")
        player.settle(limit=80)
    if _k_here(player)[0] != "Route12Gate1F":
        raise RuntimeError("the Route 12 gate stayed shut: " + json.dumps(summary(player.state)))
    _checkpoint(player, report, "saved_route12_gate")
    return "yield"


def _through_route12_gate(player, report):
    avoid = {(2, 3), (5, 0), (6, 0), (5, 7), (6, 7)}
    status = _grid_walk(player, report, SOUTH, "Route12Gate1F.json", 1, 13, "Route12Gate1F", (5, 6), avoid)
    if status:
        return status
    player.step("down")
    player.settle(limit=80)
    if _k_here(player)[0] == "Route12Gate1F" and _k_here(player)[2] == 7:
        player.step("down")
        player.settle(limit=80)
    if _k_here(player)[0] != "Route12":
        raise RuntimeError("the south side of Route 12 stayed shut: " + json.dumps(summary(player.state)))
    _checkpoint(player, report, "saved_route12_south")
    return "yield"


def _toward_snorlax(player, report):
    _place, _x, y = _k_here(player)
    if y < 20:
        return _route12_gate(player, report)
    species, _mon = _bird(player)
    if species and not _needs_center(player):
        _lead(player, species)
    goal = (10, 62) if _quest(player).get("EVENT_BEAT_ROUTE12_SNORLAX") else (10, 61)
    blob = json.loads((SOUTH / "Route12.json").read_text())
    present = _present_ids(player)
    people = {(obj["x"], obj["y"]) for obj in blob["events"]["objects"]
              if obj.get("kind") != "item" and obj["id"] in present}
    people.add((10, 62))
    misses = 0
    for _ in range(40):
        _name, x, y = _k_here(player)
        if (x, y) == goal and not _quest(player).get("EVENT_BEAT_ROUTE12_SNORLAX"):
            _checkpoint(player, report, "saved_snorlax")
            return _play_flute(player, report)
        if (x, y) == goal:
            raise RuntimeError("Snorlax is gone; Route 13 is next: " + json.dumps(summary(player.state)))
        cells = set(open_map(SOUTH / "Route12.json", 0, 20))
        avoid = set(people)
        for npc in player.state.get("npcs") or []:
            avoid.add((npc.get("x"), npc.get("y")))
        avoid.discard((x, y))
        avoid.discard(goal)
        steps = route(cells, (x, y), goal, avoid)
        if not steps:
            misses += 1
            if misses > 6:
                raise RuntimeError(f"no Route 12 path {(x, y)} -> {goal}")
            player.send("wait 30")
            continue
        misses = 0
        nxt = neighbor((x, y), steps[0])
        status = _k_go(player, report, steps[0], "Route12", nxt[0], nxt[1])
        if status:
            return status
    _checkpoint(player, report, "saved_route12")
    return "yield"


def _take_flute(player, report):
    if _holding(player, "pokeFlute"):
        return _leave_fujis_house(player, report)
    cells = set(open_map(EAST / "MrFujisHouse.json", 2, 13))
    blob = json.loads((EAST / "MrFujisHouse.json").read_text())
    avoid = set()
    for obj in blob["events"]["objects"]:
        avoid.add((obj["x"] + 2, obj["y"]))
    for warp in blob["events"]["warps"]:
        avoid.add((warp["x"] + 2, warp["y"]))
    here = (player.state["player"]["x"], player.state["player"]["y"])
    avoid.discard(here)
    result = talk_to(player, cells, "pokered:MR_FUJIS_HOUSE:objects:5", avoid)
    if result != "talked" or not _holding(player, "pokeFlute"):
        raise RuntimeError("the Poké Flute was not given: " + str(result) + " " + json.dumps(summary(player.state)))
    _checkpoint(player, report, "saved_flute")
    return "yield"


def _to_pokemon_tower(player, report):
    status = _scope_walk(player, report, "LavenderTown.json", 0, 20,
                         "LavenderTown", (14, 6), set(LAVENDER_DOORS))
    if status:
        return status
    player.step("up")
    player.settle(limit=80)
    if "tower" not in str(player.state.get("zone")):
        raise RuntimeError("the tower door stayed shut: " + json.dumps(summary(player.state)))
    _checkpoint(player, report, "saved_tower")
    return "yield"


def _with_scope(player, report):
    """Heal, then the underground to Lavender. The Saffron gate stays shut."""
    place = _k_here(player)[0]
    if place == "Route7":
        species, _mon = _bird(player)
        if species:
            _lead(player, species)
        status = _scope_walk(player, report, "Route7.json", 0, 20, "Route7", (5, 14),
                             {(18, 9), (18, 10), (11, 9), (11, 10), (5, 13)})
        if status:
            return status
        player.step("up")
        player.settle(limit=80)
        if "underground" not in str(player.state.get("zone")):
            raise RuntimeError("the Route 7 stair stayed shut: " + json.dumps(summary(player.state)))
        _checkpoint(player, report, "saved_underground")
        return "yield"
    if place == "UndergroundPathRoute7":
        status = _scope_walk(player, report, "UndergroundPathRoute7.json", 2, 13,
                             "UndergroundPathRoute7", (6, 5), {(5, 7), (6, 7), (6, 4)})
        if status:
            return status
        player.step("up")
        player.settle(limit=80)
        if "west_east" not in str(player.state.get("zone")):
            raise RuntimeError("the west passage stayed shut: " + json.dumps(summary(player.state)))
        _checkpoint(player, report, "saved_underground")
        return "yield"
    if place == "UndergroundPathWestEast":
        status = _scope_walk(player, report, "UndergroundPathWestEast.json", 0, 50,
                             "UndergroundPathWestEast", (46, 2), {(47, 2), (2, 5)})
        if status:
            return status
        player.step("right")
        player.settle(limit=80)
        if "route_8" not in str(player.state.get("zone")) and "underground" not in str(player.state.get("zone")):
            raise RuntimeError("the east passage stayed shut: " + json.dumps(summary(player.state)))
        _checkpoint(player, report, "saved_underground")
        return "yield"
    if place == "UndergroundPathRoute8":
        status = _scope_walk(player, report, "UndergroundPathRoute8.json", 2, 13,
                             "UndergroundPathRoute8", (5, 6), {(5, 7), (6, 7), (6, 4)})
        if status:
            return status
        player.step("down")
        player.settle(limit=80)
        if _k_here(player)[0] == "UndergroundPathRoute8":
            player.step("down")
            player.settle(limit=80)
        if str(player.state.get("zone")) != "kanto_route_8":
            raise RuntimeError("the Route 8 stair stayed shut: " + json.dumps(summary(player.state)))
        _checkpoint(player, report, "saved_route8")
        return "yield"
    if place == "Route8":
        return _back_along_route8(player, report)
    if place == "MrFujisHouse":
        return _take_flute(player, report)
    if place == "LavenderPokecenter" and _holding(player, "pokeFlute"):
        return _lavender_center(player, report)
    if place == "LavenderTown" and _holding(player, "pokeFlute"):
        return _flute_lavender(player, report)
    if place == "Route12":
        return _toward_snorlax(player, report)
    if place == "Route12Gate1F":
        return _through_route12_gate(player, report)
    if place == "LavenderTown":
        return _to_pokemon_tower(player, report)
    if place in TOWER_UP or place == "PokemonTower7F":
        return _climb_tower(player, report)
    if place in ("RocketHideoutB1F", "RocketHideoutB2F", "RocketHideoutB3F", "RocketHideoutB4F", "RocketHideoutElevator", "GameCorner"):
        return _leave_hideout(player, report)
    if place == "CeladonCity":
        if _needs_center(player):
            status = _city_walk(player, report, (41, 10))
            if status:
                return status
            player.step("up")
            player.settle(limit=80)
            if "pokecenter" not in str(player.state.get("zone")):
                raise RuntimeError("the Center door stayed shut: " + json.dumps(summary(player.state)))
        else:
            status = _city_walk(player, report, (48, 10))
            if status:
                return status
            player.step("right")
            player.settle(limit=80)
            if "celadon_city" in str(player.state.get("zone")) and _k_here(player)[1] == 49:
                player.step("right")
                player.settle(limit=80)
            if "route_7" not in str(player.state.get("zone")):
                raise RuntimeError("Route 7 did not open: " + json.dumps(summary(player.state)))
            _checkpoint(player, report, "saved_route7")
            return "yield"
    if _k_here(player)[0] == "CeladonPokecenter":
        status = _center_heal(player, report)
        if status:
            return status
        y = _k_here(player)[2]
        for step_y in range(y + 1, 8):
            status = _one_step(player, report, "down", "CeladonPokecenter", 3, step_y)
            if status:
                return status
        player.step("down")
        player.settle(limit=80)
        if "celadon_city" not in str(player.state.get("zone")):
            raise RuntimeError("the Center door stayed shut: " + json.dumps(summary(player.state)))
        _checkpoint(player, report, "saved_scope_healed")
        return "yield"
    raise RuntimeError("off the scope road: " + json.dumps(summary(player.state)))


def _rocket_stairs(player, report):
    """Face the poster Rocket and press A. After he leaves, the poster opens the stairs."""
    if "rocket_hideout" in str(player.state.get("zone")):
        return _through_hideout(player, report)
    if _k_here(player)[0] != "GameCorner":
        raise RuntimeError("off the Game Corner: " + json.dumps(summary(player.state)))
    avoid = {(15, 17), (16, 17), (17, 4), (9, 5)}
    _name, x, y = _k_here(player)
    if y == 17 and x in (15, 16):
        status = _one_step(player, report, "up", "GameCorner", x, 16)
        if status:
            return status
    guard = "pokered:GAME_CORNER:objects:11"
    if npc_named(player.state, guard):
        species, _mon = _bird(player)
        if species:
            _lead(player, species)
        cells = set(open_map(EAST / "GameCorner.json", 0, 20))
        talked = talk_to(player, cells, guard, avoid)
        report["corner_rocket"] = {"talked": talked, **summary(player.state)}
        if player.state.get("root") == "battle" or not player.exploring():
            _fight_once(player, "the Game Corner Rocket", 30, shift_to="pidgeotto")
        elif talked != "talked":
            raise RuntimeError("the poster Rocket did not battle: " + json.dumps(summary(player.state)))
        if not _settle_hideout_scene(player, 80):
            raise RuntimeError("the Rocket did not leave: " + json.dumps(summary(player.state)))
    if npc_named(player.state, guard):
        raise RuntimeError("the Rocket is still guarding the poster: " + json.dumps(summary(player.state)))
    avoid.discard((9, 5))
    status = _corner_walk(player, report, (9, 5), avoid)
    if status:
        return status
    if (player.state.get("player") or {}).get("facing") != "up":
        player.press("up", wait=8)
    player.press("a", wait=8)
    if not _settle_hideout_scene(player, 40):
        raise RuntimeError("the poster did not finish: " + json.dumps(summary(player.state)))
    status = _corner_walk(player, report, (17, 5), avoid)
    if status:
        return status
    player.step("up")
    player.settle(limit=80)
    if not player.exploring():
        _settle_hideout_scene(player, 20)
    if "rocket_hideout" not in str(player.state.get("zone")):
        raise RuntimeError("the poster did not open the stairs: " + json.dumps(summary(player.state)))
    _checkpoint(player, report, "saved_hideout")
    return "yield"


def _after_rainbow(player, report):
    """Leave Erika, heal the bird, and open the Game Corner door."""
    if _k_here(player)[0] == "CeladonGym":
        for direction, x, y, cut in (
            ("left", 4, 4, False),
            ("left", 3, 4, True),
            ("left", 2, 4, False),
            ("left", 1, 4, False),
            ("down", 1, 5, False),
            ("down", 1, 6, False),
            ("down", 1, 7, False),
            ("down", 1, 8, False),
            ("down", 1, 9, False),
            ("down", 1, 10, False),
            ("right", 2, 10, False),
            ("down", 2, 11, False),
            ("down", 2, 12, False),
            ("down", 2, 13, False),
            ("down", 2, 14, False),
            ("down", 2, 15, False),
            ("down", 2, 16, False),
            ("down", 2, 17, False),
            ("right", 3, 17, False),
            ("right", 4, 17, False),
            ("right", 5, 17, False),
        ):
            status = _one_step(player, report, direction, "CeladonGym", x, y, cut)
            if status:
                return status
        player.step("down")
        player.settle(limit=80)
        if not player.exploring():
            player.dismiss_until_explore(limit=40)
        if "celadon_city" not in str(player.state.get("zone")):
            raise RuntimeError("the gym door stayed shut: " + json.dumps(summary(player.state)))
    # The south road is the one that already reached the gym. The tree regrows.
    road = [(12, 28), (12, 29)]
    road += [(x, 29) for x in range(11, 4, -1)]
    road += [(5, y) for y in range(30, 35)]
    road += [(x, 34) for x in range(6, 36)]
    road += [(35, 33), (35, 32), (35, 31)]
    road += [(x, 31) for x in range(34, 24, -1)]
    road += [(25, y) for y in range(30, 22, -1)]
    road += [(26, 23), (26, 22)]
    road += [(x, 22) for x in range(27, 37)]
    road += [(36, y) for y in range(21, 9, -1)]
    road += [(x, 10) for x in range(37, 42)]
    here = _k_here(player)
    if here[0] == "CeladonCity":
        if (here[1], here[2]) not in road:
            raise RuntimeError("off the gym road: " + json.dumps(summary(player.state)))
        start = road.index((here[1], here[2])) + 1
        names = {"left": (-1, 0), "right": (1, 0), "up": (0, -1), "down": (0, 1)}
        for x, y in road[start:]:
            dx, dy = x - here[1], y - here[2]
            direction = next(name for name, delta in names.items() if delta == (dx, dy))
            status = _one_step(player, report, direction, "CeladonCity", x, y, cut=(x, y) == (35, 32))
            if status:
                return status
            here = _k_here(player)
        status = _one_step(player, report, "up", "CeladonPokecenter", 3, 7)
        if status:
            return status
    if _k_here(player)[0] == "CeladonPokecenter":
        _, mon = _bird(player)
        if (mon.get("hp") or 0) < 20:
            for y in (6, 5, 4, 3):
                if _k_here(player) == ("CeladonPokecenter", 3, y):
                    break
                status = _one_step(player, report, "up", "CeladonPokecenter", 3, y)
                if status:
                    return status
            cells = set(open_map(EAST / K_FILES["CeladonPokecenter"][0], *K_FILES["CeladonPokecenter"][1:]))
            talk_to(player, cells, K_NURSE["CeladonPokecenter"], set())
            healed = player.state.get("pokemon") or {}
            if (healed.get("hp") or 0) < 20:
                raise RuntimeError("the nurse did not heal: " + json.dumps(summary(player.state)))
            _checkpoint(player, report, "saved_after_erika")
        # The east-west street at y=10 reaches the north-south street at x=36.
        # The Game Corner door is (28, 19), faced from (28, 20).
        for y in range(_k_here(player)[2] + 1, 8):
            status = _one_step(player, report, "down", "CeladonPokecenter", 3, y)
            if status:
                return status
        player.step("down")
        player.settle(limit=80)
        if "celadon_city" not in str(player.state.get("zone")):
            raise RuntimeError("the Center door stayed shut: " + json.dumps(summary(player.state)))
        city = _k_here(player)
        report["center_exit"] = {"at": [city[1], city[2]], **summary(player.state)}
        if (city[1], city[2]) != (41, 10):
            raise RuntimeError("Center exit landed off (41, 10): " + json.dumps(summary(player.state)))
        for x in range(40, 35, -1):
            status = _one_step(player, report, "left", "CeladonCity", x, 10)
            if status:
                return status
        for y in range(11, 21):
            status = _one_step(player, report, "down", "CeladonCity", 36, y)
            if status:
                return status
        for x in range(35, 27, -1):
            status = _one_step(player, report, "left", "CeladonCity", x, 20)
            if status:
                return status
        player.step("up")
        player.settle(limit=80)
        if not player.exploring():
            player.dismiss_until_explore(limit=40)
        if "game_corner" not in str(player.state.get("zone")):
            raise RuntimeError("the Game Corner door stayed shut: " + json.dumps(summary(player.state)))
        _checkpoint(player, report, "saved_game_corner")
        return "yield"
    raise RuntimeError("the Center is not open: " + json.dumps(summary(player.state)))


def _face_erika(player, report, display, clips, output):
    if _quest(player).get("BADGE_RAINBOW"):
        return _after_rainbow(player, report)
    species, _ = _bird(player)
    if species:
        _lead(player, species)
    facing = (player.state.get("player") or {}).get("facing")
    if facing != "up":
        player.press("up", wait=8)
        player.settle(limit=8)
    def battle():
        player.press("a", wait=8)
        _fight_once(player, "Erika", 30, shift_to="pidgeotto")
    if display is not None and clips is not None:
        film(display, clips, output, "erika", report, "end", battle)
    else:
        battle()
    player.dismiss_until_explore(limit=40)
    flags = _quest(player)
    if flags.get("BADGE_RAINBOW") or flags.get("BADGE_RAINBOWBADGE"):
        _checkpoint(player, report, "saved_rainbow")
        return "badge"
    raise RuntimeError("Erika ended without the Rainbow Badge: " + json.dumps(player.summary())[:500])


def _follow_k(player, report, display, clips, output):
    atoms = _k_atoms()
    name, x, y = _k_here(player)
    on_line = (name, x, y) == ("Route9", 20, 12) or any(
        atom["op"] in ("step", "ledge", "conn", "warp") and (atom["map"], atom["x"], atom["y"]) == (name, x, y)
        for atom in atoms)
    if name == "Route9" and not on_line:
        status = _rejoin_route9(player, report)
        if status:
            return status
        name, x, y = _k_here(player)
    if (name, x, y) == ("Route9", 20, 12):
        start = 0
    else:
        hits = [index for index, atom in enumerate(atoms) if atom["op"] in ("step", "ledge", "conn", "warp") and (atom["map"], atom["x"], atom["y"]) == (name, x, y)]
        if not hits:
            raise RuntimeError(f"off K's line at {name} {x},{y}")
        start = hits[-1] + 1
    for atom in atoms[start:]:
        if _k_here(player) == ("Route7", 5, 14):
            status = _grind_route7(player, report)
            if status:
                return status
        if atom["op"] in ("step", "ledge", "conn", "warp"):
            status = _k_go(player, report, atom["dir"], atom["map"], atom["x"], atom["y"])
            if status:
                return status
        elif atom["op"] == "cut":
            _confirm_cut(player, atom["dir"])
        elif atom["op"] == "heal":
            talk_to(player, set(open_map(EAST / K_FILES[atom["map"]][0], *K_FILES[atom["map"]][1:])), K_NURSE[atom["map"]], set())
            healed = player.state.get("pokemon") or {}
            if (healed.get("hp") or 0) < 20:
                raise RuntimeError("the nurse did not heal: " + json.dumps(player.summary())[:400])
            _checkpoint(player, report, "saved_" + atom["map"])
            if atom["map"] == "CeladonPokecenter":
                species, mon = _bird(player)
                if species and (mon.get("level") or 0) < 31 and (mon.get("hp") or 0) > 0:
                    for x, y in ((3, 4), (3, 5), (3, 6), (3, 7)):
                        status = _k_go(player, report, "down", "CeladonPokecenter", x, y)
                        if status == "blackout":
                            return status
                    status = _k_go(player, report, "down", "CeladonCity", 41, 10)
                    if status == "blackout":
                        return status
                    status = _k_go(player, report, "down", "CeladonCity", 41, 11)
                    if status == "blackout":
                        return status
                    for x in range(42, 50):
                        status = _k_go(player, report, "right", "CeladonCity", x, 11)
                        if status == "blackout":
                            return status
                    status = _k_go(player, report, "right", "Route7", 0, 3)
                    if status == "blackout":
                        return status
                    _walk(player, route7_cells(), map_surface(EAST / "Route7.json"), (5, 14), set(ROUTE7_GATES) | {(5, 13)})
                    status = _grind_route7(player, report)
                    if status:
                        return status
        elif atom["op"] == "erika":
            return _face_erika(player, report, display, clips, output)
    raise RuntimeError("K's line ended short of Erika")


def _east_of_cerulean(player, report, display, clips, output):
    """K's line from the Route 9 shelf to Erika. One battle ends the session."""
    for _ in range(4):
        status = _follow_k(player, report, display, clips, output)
        if status in ("yield", None, "badge"):
            return status if status != "badge" else None
        if status != "blackout":
            return status
        zone = str(player.state.get("zone"))
        if zone in EAST_RESUME or "rock_tunnel" in zone or "celadon" in zone or "lavender" in zone or "underground_path" in zone:
            continue
        return "restart"
    raise RuntimeError("the east road did not finish: " + json.dumps(summary(player.state)))


def _continue_kanto(player, report, display, clips, output):
    """Pewter's east road, Mt. Moon, Route 4, then Route 9. Misty stays beaten."""
    zone = str(player.state.get("zone"))
    if zone in EAST_RESUME or "rock_tunnel" in zone or "celadon" in zone or "lavender" in zone or "underground_path_route" in zone or "underground_path_west_east" in zone:
        return _east_of_cerulean(player, report, display, clips, output)
    _lead(player, "wartortle")
    if "route_4" in zone or "mt_moon" in zone:
        _from_route4(player, report, display, clips, output)
        return
    if "pewter" in zone or "route_3" in zone:
        _cross_route3(player, report, display, clips, output)
        _from_route3_north(player, report, display, clips, output)
        return
    raise RuntimeError("the road east of Pewter is not open: " + json.dumps(summary(player.state)))


def _toward_celadon(player, report, display=None, clips=None, output=None):
    """After the badge: Diglett's Cave to Route 2, Cut (5, 10), then Pewter.

    A reload grows the tree back. The cave side reaches Pewter only after Cut
    from (5, 11). Cascade is already set, so Cerulean does not mean Misty.
    """
    zone = str(player.state.get("zone"))
    if _holding(player, "silphScope") and not _quest(player).get("BADGE_SOUL"):
        return _with_scope(player, report)
    if "game_corner" in zone or "rocket_hideout" in zone:
        return _rocket_stairs(player, report)
    if zone == "kanto_route2":
        _cut_route2_to_pewter(player, report, display, clips, output)
        _continue_kanto(player, report, display, clips, output)
        return
    if zone in ("kanto_pewter_city", "kanto_route_3", "kanto_route_4", "kanto_mt_moon_1f",
                "kanto_mt_moon_b1f", "kanto_mt_moon_b2f") or zone in EAST_RESUME:
        if _continue_kanto(player, report, display, clips, output) != "restart":
            return
        zone = str(player.state.get("zone"))
    if "vermilion_gym" in zone:
        _leave(player, vermilion_gym_cells(), [((5, 17), "down"), ((6, 17), "down")],
               GYM_SIGHT, "vermilion_city", "gym exit")
        zone = str(player.state.get("zone"))
    if "vermilion_city" in zone:
        # The gym pause dropped the city cut. The south side is the side this door can reach.
        opened = set(vermilion_cells())
        opened.add((15, 18))
        doors = set(VERMILION_DOORS)
        doors.discard((11, 3))
        here = (player.state["player"]["x"], player.state["player"]["y"])
        if here != (15, 18) and route(vermilion_cells(), here, (11, 4), doors) is None:
            _stand(player, vermilion_cells(), (15, 19), VERMILION_DOORS, "south of the tree")
            if player.state["player"].get("facing") != "up":
                player.press("up", wait=4)
            player.step("up")
            if (player.state["player"]["x"], player.state["player"]["y"]) != (15, 18):
                opened = _use_cut(player, report, "up")
            else:
                report["cut"] = {"kind": "open", **summary(player.state)}
        _heal_in(player, report, opened, (11, 3), VERMILION_NURSE,
                 vermilion_center_cells(), "after Surge", "vermilion_city", avoid=doors)
        if (_item_count(player, "superPotion") < 4
                and int((player.state.get("inventory") or {}).get("money") or 0) >= 700):
            _buy_vermilion(player, report, balls=8, supers=4)
        _pause(player, report, "saved_after_surge")
        _keep_bird_save(report)
        zone = str(player.state.get("zone"))
    if "celadon" in zone or "lavender" in zone or "rock_tunnel" in zone or zone in EAST_RESUME:
        _continue_kanto(player, report, display, clips, output)
        return
    if zone != "kanto_digletts_cave":
        if "route_11" not in zone and "digletts_cave_route_11" not in zone:
            if "vermilion_city" not in zone:
                _return_vermilion(player, "Route 2 return")
            _leave(player, vermilion_cells(), [((39, 14), "right"), ((39, 15), "right")],
                   VERMILION_DOORS, "route_11", "Route 11")
        if "digletts_cave_route_11" not in str(player.state.get("zone")) and player.state.get("zone") != "kanto_digletts_cave":
            _enter(player, route11_cells(), (4, 5), route11_avoid() - {(4, 5)}, "up",
                   "digletts_cave_route_11", "Diglett's Cave")
        if player.state.get("zone") != "kanto_digletts_cave":
            step_onto(player, diglett_house_cells(), (6, 4), {(4, 3)}, "up")
            _settle_overlay(player)
    if player.state.get("zone") != "kanto_digletts_cave":
        raise RuntimeError("the cave did not open for Route 2: " + json.dumps(summary(player.state)))
    step_onto(player, diglett_cave_cells(), (5, 5), set(), "up")
    _settle_overlay(player)
    if "digletts_cave_route_2" not in str(player.state.get("zone")):
        raise RuntimeError("the north stairs did not open: " + json.dumps(summary(player.state)))
    _leave(player, diglett_route2_house_cells(), [((4, 7), "down"), ((5, 7), "down")],
           {(4, 3)}, "route2", "Route 2")
    _pause(player, report, "saved_route2")
    _keep_bird_save(report)
    _cut_route2_to_pewter(player, report, display, clips, output)
    _continue_kanto(player, report, display, clips, output)


def play_vermilion_prep(player, report, display, clips, output):
    """K's Anne plan: Bellsprout, Pidgeotto 19, Bite then Gust, then HM01."""
    player.leave_title()
    if not player.exploring():
        player.dismiss_until_explore(limit=40)
    report["resumed"] = summary(player.state)
    if _quest(player).get("BADGE_THUNDER"):
        _toward_celadon(player, report, display, clips, output)
        return
    have_cut = _member(player, "bellsprout")[0]
    have_bird = _member(player, "pidgey")[0] or _member(player, "pidgeotto")[0]
    if not (have_cut and have_bird):
        if "vermilion_city" not in str(player.state.get("zone")):
            raise RuntimeError("the prep did not resume in Vermilion: " + json.dumps(summary(player.state)))
        _buy_vermilion(player, report, balls=8, supers=4)

    def catch():
        _leave(player, vermilion_cells(), [((19, 0), "up"), ((18, 0), "up")],
               VERMILION_DOORS, "route_6", "Route 6")
        _stand(player, route6_cells(), (12, 30), _route6_avoid(), "Route 6 grass")
        caught = _hunt(player, route6_cells(), (12, 30), (13, 30), "bellsprout", limit=20)
        report["bellsprout"] = {"caught": bool(caught), "party": _party(player), **summary(player.state)}
        if not caught:
            raise RuntimeError("Route 6 did not yield a Bellsprout: " + json.dumps(summary(player.state)))

    if not (have_cut and have_bird):
        film(display, clips, output, "bellsprout", report, "end", catch)
    if _member(player, "pidgey")[0] is None and _member(player, "pidgeotto")[0] is None:
        caught = _hunt(player, route6_cells(), (12, 30), (13, 30), "pidgey", limit=24)
        report["pidgey"] = {"caught": bool(caught), "party": _party(player), **summary(player.state)}
        if not caught:
            raise RuntimeError("Route 6 did not yield a Pidgey: " + json.dumps(summary(player.state)))
    if _item_count(player, "hm01") < 1 and not _quest(player).get("EVENT_GOT_HM01"):
        _pause(player, report, "saved_catches")
        _raise_pidgey(player, report)
        _rest(player, report, "before the rival", 4)
        _lead(player, "wartortle")
        _pause(player, report, "saved_before_rival")

        def rival():
            doors = set(VERMILION_DOORS)
            _stand(player, vermilion_cells(), (18, 29), doors, "dock gate")
            player.step("down")
            if not player.exploring():
                _through_scene(player, 4)
            _enter(player, vermilion_cells(), (18, 31), doors, "down", "vermilion_dock", "Vermilion dock")
            _enter(player, vermilion_dock_cells(), (14, 2), set(), "down", "ss_anne_1f", "S.S. Anne")
            _enter(player, ss_anne_1f_cells(), (2, 6), ANNE1_SKIP, "up", "ss_anne_2f", "S.S. Anne 2F")
            _stand(player, ss_anne_2f_cells(), (36, 9), ANNE2_SKIP, "rival trigger")
            player.step("up")
            _fight_once(player, "the S.S. Anne rival", 30, bite_only=True, shift_to="pidgeotto")
            report["anne_rival"] = {"party": _party(player), **summary(player.state)}

        film(display, clips, output, "ss-anne", report, "end", rival)
        _enter(player, ss_anne_2f_cells(), (36, 4), ANNE2_SKIP - {(36, 4)}, "up", "captains_room", "captain")
        _stand(player, captain_cells(), (7, 3), set(), "captain")
        if player.state["player"].get("facing") != "up":
            player.press("up", wait=4)
        player.press("a", wait=8)
        _through_scene(player, 6)
        report["hm01"] = {
            "count": _item_count(player, "hm01"),
            "flag": bool(_quest(player).get("EVENT_GOT_HM01")),
            **summary(player.state),
        }
        if report["hm01"]["count"] < 1 or not report["hm01"]["flag"]:
            raise RuntimeError("the captain did not give HM01: " + json.dumps(report["hm01"]))
        _teach(player, "hm01", "bellsprout", "cut")
        _leave(player, captain_cells(), [((3, 7), "down")], set(), "ss_anne_2f", "captain exit")
        _enter(player, ss_anne_2f_cells(), (2, 4), ANNE2_SKIP - {(36, 4)}, "up", "ss_anne_1f", "S.S. Anne stairs")
        if "ss_anne_1f" in str(player.state.get("zone")):
            # HM01 arms the departure. The ship can warp to the dock before (27, 0).
            player.travel(ss_anne_1f_cells(), (27, 0), set(ANNE1_SKIP), limit=40)
            _settle_overlay(player)
            here = (player.state["player"]["x"], player.state["player"]["y"])
            if "ss_anne_1f" in str(player.state.get("zone")) and here in ((26, 0), (27, 0)):
                player.step("up")
                _through_scene(player, 4)
        if not player.exploring():
            _through_scene(player, 4)
        if "vermilion_city" not in str(player.state.get("zone")):
            raise RuntimeError("the ship did not return to Vermilion: " + json.dumps(summary(player.state)))
        _pause(player, report, "saved_hm01")
        _keep_bird_save(report)
    _, sprout = _member(player, "bellsprout")
    if sprout and "cut" not in (sprout.get("moves") or []):
        _teach(player, "hm01", "bellsprout", "cut")

    _raise_diglett(player, report)
    _rest(player, report, "before Surge", 4)
    _, mole = _mole(player)
    if "dig" not in (mole.get("moves") or []):
        _teach(player, "tm28", mole.get("species") or "dugtrio", "dig")
    _lead(player, "dugtrio")
    opened = _cut_tree(player, report)
    _pause(player, report, "saved_before_surge")
    gym_doors = set(VERMILION_DOORS)
    gym_doors.discard((12, 19))
    _stand(player, opened, (12, 20), gym_doors, "gym door")
    player.step("up")
    _settle_overlay(player)
    if "vermilion_gym" not in str(player.state.get("zone")):
        raise RuntimeError("the gym door did not open: " + json.dumps(summary(player.state)))
    _solve_cans(player, report)
    if (_mole(player)[1].get("hp") or 0) <= 0:
        _leave(player, vermilion_gym_cells(), [((5, 17), "down"), ((6, 17), "down")],
               GYM_SIGHT, "vermilion_city", "gym heal")
        _rest(player, report, "gym heal", 4)
        _lead(player, "dugtrio")
        _enter(player, opened, (12, 19), gym_doors, "up", "vermilion_gym", "Vermilion Gym")

    def surge():
        _stand(player, vermilion_gym_cells(), (6, 2), GYM_SIGHT, "Lt. Surge")
        if player.state["player"].get("facing") != "up":
            player.press("up", wait=4)
        player.press("a", wait=8)
        _fight_once(player, "Lt. Surge", 20)

    film(display, clips, output, "gym-vermilion", report, "end", surge)
    quest = _quest(player)
    report["thunder"] = {
        "badge": bool(quest.get("BADGE_THUNDER")),
        "beat": bool(quest.get("EVENT_BEAT_LT_SURGE")),
        "party": _party(player),
        **summary(player.state),
    }
    if not report["thunder"]["badge"]:
        raise RuntimeError("Lt. Surge did not give the Thunder Badge: " + json.dumps(report["thunder"]))
    _pause(player, report, "saved_thunder")
    _keep_bird_save(report)
    _toward_celadon(player, report)


if __name__ == "__main__":
    import sys
    if "--play" not in sys.argv:
        unittest.main()
    else:
        clips = ROOT / "artifacts" / "lane-j"
        if "--line" in sys.argv:
            number = 81
            while Path(f"/tmp/lane-j-squirtle-{number}").exists():
                number += 1
            output = Path(f"/tmp/lane-j-squirtle-{number}")
            save_from = BIRD_SAVE if list(BIRD_SAVE.glob("adventure*.json")) else CATCH_SAVE
            if save_from == CATCH_SAVE:
                digest = sha256_file(save_from / "adventure.b.json")
                if digest != CATCH_SAVE_SHA:
                    raise SystemExit(f"catch save hash {digest}")
            if output.exists():
                raise SystemExit(f"{output} already exists")
            raise SystemExit(play(output, clips, save_from=save_from, story=play_vermilion_prep))
        if "--west" in sys.argv:
            output = Path("/tmp/lane-j-squirtle-25")
            save_from = CLIFF_SAVE
            digest = sha256_file(save_from / "adventure.a.json")
            if digest != CLIFF_SAVE_SHA:
                raise SystemExit(f"cliff save hash {digest}")
            if output.exists():
                raise SystemExit(f"{output} already exists")
            raise SystemExit(play(output, clips, save_from=save_from, story=probe_west))
        if "--east" in sys.argv:
            output = Path("/tmp/lane-j-squirtle-24")
            save_from = FOSSIL_SAVE
            digest = sha256_file(save_from / "adventure.a.json")
            if digest != FOSSIL_SAVE_SHA:
                raise SystemExit(f"fossil save hash {digest}")
            if output.exists():
                raise SystemExit(f"{output} already exists")
            raise SystemExit(play(output, clips, save_from=save_from, story=play_to_cerulean))
        if "--north" in sys.argv:
            output = Path("/tmp/lane-j-squirtle-10")
            save_from = PEWTER_SAVE
            digest = sha256_file(save_from / "adventure.b.json")
            if digest != PEWTER_SAVE_SHA:
                raise SystemExit(f"pewter save hash {digest}")
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
