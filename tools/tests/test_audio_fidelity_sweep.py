"""Map songs, event cues, and trainer-spotted music against pret/pokered.

The expected rows are parsed from the pinned sources. The actual rows are the
generated tables and the select.lua decisions the game calls. Champion, Hall
of Fame, and credits playback are not part of this sweep.
"""
import os
import re
import subprocess
import unittest
from pathlib import Path

from tools.audio.scores import ASSETS

ROOT = Path(__file__).resolve().parents[2]
POKERED = Path(os.environ["POKERED_REFERENCE_DIR"])

# songs.asm maps the sweep calls out by name. The score still comes from the
# parsed row; these names only choose which rows the test reports.
SPOTLIGHT = (
    "PALLET_TOWN",
    "VIRIDIAN_CITY",
    "ROUTE_1",
    "ROUTE_2",
    "PEWTER_CITY",
    "PEWTER_GYM",
    "CERULEAN_CITY",
    "CERULEAN_CAVE_1F",
    "MT_MOON_1F",
    "ROCK_TUNNEL_1F",
    "VERMILION_CITY",
    "LAVENDER_TOWN",
    "POKEMON_TOWER_1F",
    "CELADON_CITY",
    "CELADON_GYM",
    "SAFFRON_CITY",
    "SILPH_CO_1F",
    "SILPH_CO_11F",
    "FUCHSIA_CITY",
    "SAFARI_ZONE_CENTER",
    "SAFARI_ZONE_EAST",
    "CINNABAR_ISLAND",
    "CINNABAR_GYM",
)

# Cue name, pokered token, and the file that plays it. Badge scripts name the
# key-item opcode; the item-fanfare handoff is a separate patch.
CUES = (
    ("heal", "MUSIC_PKMN_HEALED", "engine/overworld/healing_machine.asm"),
    ("healing_machine", "SFX_HEALING_MACHINE", "engine/overworld/healing_machine.asm"),
    ("item", "SFX_GET_ITEM_1", "home/text.asm"),
    ("key_item", "SFX_GET_KEY_ITEM", "home/text.asm"),
    ("badge", "SFX_GET_KEY_ITEM", "home/text.asm"),
    ("evolution", "MUSIC_SAFARI_ZONE", "engine/movie/evolution.asm"),
    ("tink", "SFX_TINK", "engine/movie/evolution.asm"),
    ("caught", "SFX_CAUGHT_MON", "home/text.asm"),
    ("level_up", "SFX_LEVEL_UP", "engine/pokemon/learn_move.asm"),
    ("pc_on", "SFX_TURN_ON_PC", "engine/menus/pc.asm"),
    ("pc_enter", "SFX_ENTER_PC", "engine/menus/pc.asm"),
    ("pc_off", "SFX_TURN_OFF_PC", "engine/menus/pc.asm"),
    ("pc_withdraw", "SFX_WITHDRAW_DEPOSIT", "engine/menus/players_pc.asm"),
    ("go_inside", "SFX_GO_INSIDE", "home/overworld.asm"),
    ("go_outside", "SFX_GO_OUTSIDE", "home/overworld.asm"),
    ("ledge", "SFX_LEDGE", "engine/overworld/ledges.asm"),
    ("collision", "SFX_COLLISION", "home/overworld.asm"),
    ("start_menu", "SFX_START_MENU", "home/start_menu.asm"),
    ("menu", "SFX_PRESS_AB", "home/joypad2.asm"),
    ("surf", "MUSIC_SURFING", "home/audio.asm"),
    ("bicycle", "MUSIC_BIKE_RIDING", "home/audio.asm"),
    ("meet_male", "MUSIC_MEET_MALE_TRAINER", "home/trainers.asm"),
    ("meet_female", "MUSIC_MEET_FEMALE_TRAINER", "home/trainers.asm"),
    ("meet_evil", "MUSIC_MEET_EVIL_TRAINER", "home/trainers.asm"),
)


def _code(line):
    return line.split(";", 1)[0].strip()


def _songs(root):
    symbols = {}
    constants = (root / "constants/music_constants.asm").read_text()
    for line in constants.splitlines():
        match = re.search(r"music_const\s+(MUSIC_[A-Z0-9_]+),\s+(Music_[A-Za-z0-9_]+)", _code(line))
        if match:
            symbols[match.group(1)] = match.group(2)
    by_label = {}
    for name, asset in ASSETS.items():
        label = asset.split(":", 1)[1]
        by_label.setdefault(label, []).append(name)
    rows = {}
    for line in (root / "data/maps/songs.asm").read_text().splitlines():
        match = re.search(
            r"db\s+(MUSIC_[A-Z0-9_]+),\s+BANK\((Music_[A-Za-z0-9_]+)\)\s*;\s*([A-Z0-9_]+)",
            line,
        )
        if not match:
            continue
        symbol, label, map_name = match.groups()
        if symbols.get(symbol) != label:
            raise AssertionError(f"{map_name}: {symbol} is not {label}")
        names = by_label.get(label)
        if not names or len(set(names)) != 1:
            raise AssertionError(f"{label} does not name one score: {names}")
        rows[map_name] = names[0]
    return rows


def _game_maps():
    text = (ROOT / "Source/audio/eventMaps.lua").read_text()
    return dict(re.findall(r'\["(pokered:[A-Z0-9_]+)"\] = "([a-z0-9_]+)"', text))


def _game_cues():
    text = (ROOT / "Source/audio/events.lua").read_text()
    rows = {}
    for name, score, kind, source, token in re.findall(
        r'\["([a-z0-9_]+)"\] = \{score="([a-z0-9_]+)", kind="([a-z]+)", '
        r'source="([^"]+)", token="([^"]+)"\}',
        text,
    ):
        rows[name] = {"score": score, "kind": kind, "source": source, "token": token}
    return rows


def _listed(text, label):
    rows = []
    inside = False
    for raw in text.splitlines():
        code = _code(raw)
        if code.startswith(label):
            inside = True
            continue
        if not inside:
            continue
        if code.startswith("db -1"):
            break
        match = re.fullmatch(r"db\s+(OPP_[A-Z0-9_]+)", code)
        if not match:
            raise AssertionError(f"unsupported {label} row: {code}")
        rows.append(match.group(1))
    return rows


def _classes(root):
    classes = []
    for line in (root / "constants/trainer_constants.asm").read_text().splitlines():
        match = re.search(r"trainer_const\s+([A-Z0-9_]+)", _code(line))
        if match and match.group(1) != "NOBODY":
            classes.append("OPP_" + match.group(1))
    return classes


def _jingles(classes):
    quoted = ", ".join(f'"{name}"' for name in classes)
    script = f"""
local root = [[{ROOT}]]
playdate = {{ file = {{ run = function() end }} }}
dofile(root .. "/Source/audio/events.lua")
dofile(root .. "/Source/audio/select.lua")
local function show(kind, flag, value)
    if value == nil then value = "nil" end
    io.write(kind, "\\t", flag, "\\t", tostring(value), "\\n")
end
local classes = {{ {quoted} }}
for _, class in ipairs(classes) do
    show(class, "0", KantoEvents.trainerJingle(class, 0))
    show(class, "1", KantoEvents.trainerJingle(class, 1))
end
show("bed", "surf", KantoEvents.fieldBed("surfing", "pallet"))
show("bed", "bike", KantoEvents.fieldBed("bicycle", "pallet"))
show("bed", "walk", KantoEvents.fieldBed(nil, "pallet"))
"""
    completed = subprocess.run(["lua", "-e", script], check=True, capture_output=True, text=True)
    rows = {}
    for line in completed.stdout.splitlines():
        kind, flag, value = line.split("\t")
        rows[(kind, flag)] = value
    return rows


class AudioFidelitySweepTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.songs = _songs(POKERED)
        cls.maps = _game_maps()
        cls.cues = _game_cues()
        encounter = (POKERED / "data/trainers/encounter_types.asm").read_text()
        cls.evil = set(_listed(encounter, "EvilTrainerList::"))
        cls.female = set(_listed(encounter, "FemaleTrainerList::"))
        cls.classes = _classes(POKERED)
        cls.jingles = _jingles(cls.classes)

    def test_every_songs_row_matches_the_map_table(self):
        self.assertEqual(len(self.songs), len(self.maps))
        for map_name, score in self.songs.items():
            self.assertEqual(self.maps.get("pokered:" + map_name), score, map_name)
        for map_name in SPOTLIGHT:
            self.assertIn(map_name, self.songs)
            self.assertEqual(self.maps["pokered:" + map_name], self.songs[map_name], map_name)

    def test_bike_and_surf_replace_the_map_bed(self):
        audio = (POKERED / "home/audio.asm").read_text()
        self.assertIn("MUSIC_SURFING", audio)
        self.assertIn("MUSIC_BIKE_RIDING", audio)
        self.assertEqual(self.jingles[("bed", "surf")], "surfing")
        self.assertEqual(self.jingles[("bed", "bike")], "bicycle")
        self.assertEqual(self.jingles[("bed", "walk")], "pallet")
        self.assertEqual(self.cues["surf"]["score"], "surfing")
        self.assertEqual(self.cues["bicycle"]["score"], "bicycle")

    def test_event_cues_use_the_pokered_tokens(self):
        for name, token, path in CUES:
            cue = self.cues[name]
            self.assertEqual(cue["token"], token, name)
            self.assertTrue(cue["source"].startswith(path), cue["source"])
            self.assertIn(token, (POKERED / path).read_text())

    def test_trainer_spotted_music_follows_the_encounter_lists(self):
        rivals = {"OPP_RIVAL1", "OPP_RIVAL2", "OPP_RIVAL3"}
        self.assertTrue(rivals <= set(self.classes))
        self.assertTrue(self.evil <= set(self.classes))
        self.assertTrue(self.female <= set(self.classes))
        self.assertTrue(self.evil.isdisjoint(self.female))
        for class_name in self.classes:
            if class_name in rivals:
                expected = "nil"
            elif class_name in self.evil:
                expected = "meet_evil"
            elif class_name in self.female:
                expected = "meet_female"
            else:
                expected = "meet_male"
            self.assertEqual(self.jingles[(class_name, "0")], expected, class_name)
            # PlayTrainerMusic returns before the lists when wGymLeaderNo is set.
            self.assertEqual(self.jingles[(class_name, "1")], "nil", class_name)
