"""Hall of Fame and credits sequence from pret/pokered af519899.

The checklist is docs/validation/lane-g-hall-of-fame.md. This module turns a
party and a player card into the beats a capture must hit, and checks a frame
log or a directory of 400x240 frames against that order. It does not import
the game.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SOURCE_REVISION = "af519899719f0754965776faac0e836a3b906e6d"
GB_FRAME_HZ = 60
PLAYDATE_FRAME_HZ = 30
FRAME_SIZE = (400, 240)

# AnimateHallOfFame and HallOfFamePC, in DelayFrames counts.
HOF_FADE_FRAMES = 24  # GBFadeOutToWhite: 3 steps, 8 frames each
HOF_BLANK_FRAMES = 100
HOF_BACK_SCROLL_FRAMES = 56  # hSCX $C0, step +4, until $A0
HOF_FRONT_SCROLL_FRAMES = 40  # hSCX $A0, step -4, until 0
HOF_INFO_FRAMES = 80
HOF_BANNER_FRAMES = 180
HOF_TEXT_FRAMES = 120
CREDITS_CLEAR_FRAMES = 100
CREDITS_MUSIC_FRAMES = 128
CREDITS_FADE_FRAMES = 20  # FadeInCredits: 4 palettes, 5 frames each
CREDITS_HOLD = {
    "fade_mon": 90,
    "text_mon": 110,
    "fade": 120,
    "text": 140,
}
THE_END_DELAY_FRAMES = 16

COPYRIGHT_LINES = (
    "©'95.'96.'98 Nintendo",
    "©'95.'96.'98 Creatures inc.",
    "©'95.'96.'98 GAME FREAK inc.",
)

# Owned count is strictly less than the threshold. NUM_POKEMON is 151.
DEX_RATINGS = (
    (10, ("You still have", "lots to do.", "Look for Pokémon", "in grassy areas!")),
    (20, ("You're on the", "right track!", "Get a FLASH HM", "from my AIDE!")),
    (30, ("You still need", "more Pokémon!", "Try to catch", "other species!")),
    (40, ("Good, you're", "trying hard!", "Get an ITEMFINDER", "from my AIDE!")),
    (50, ("Looking good!", "Go find my AIDE", "when you get 50!")),
    (60, ("You finally got at", "least 50 species!", "Be sure to get", "EXP.ALL from my", "AIDE!")),
    (70, ("Ho! This is geting", "even better!")),
    (80, ("Very good!", "Go fish for some", "marine Pokémon!")),
    (90, ("Wonderful!", "Do you like to", "collect things?")),
    (100, ("I'm impressed!", "It must have been", "difficult to do!")),
    (110, ("You finally got at", "least 100 species!", "I can't believe", "how good you are!")),
    (120, ("You even have the", "evolved forms of", "Pokémon! Super!")),
    (130, ("Excellent! Trade", "with friends to", "get some more!")),
    (140, ("Outstanding!", "You've become a", "real pro at this!")),
    (150, ("I have nothing", "left to say!", "You're the", "authority now!")),
    (152, ("Your PokéDEX is", "entirely complete!", "Congratulations!")),
)

_CONTROL = {
    "CRED_TEXT_FADE_MON": "fade_mon",
    "CRED_TEXT_MON": "text_mon",
    "CRED_TEXT_FADE": "fade",
    "CRED_TEXT": "text",
    "CRED_THE_END": "the_end",
}


def rating_lines(owned):
    if not isinstance(owned, int) or isinstance(owned, bool) or owned < 0 or owned > 151:
        raise ValueError("owned must be an integer from 0 to 151")
    for limit, lines in DEX_RATINGS:
        if owned < limit:
            return lines
    raise ValueError(owned)


def money_text(amount):
    if not isinstance(amount, int) or isinstance(amount, bool) or amount < 0 or amount > 999999:
        raise ValueError("money must be an integer from 0 to 999999")
    if amount == 0:
        return "¥0"
    return "¥" + str(amount)


def play_time_text(hours, minutes):
    if not isinstance(hours, int) or isinstance(hours, bool) or hours < 0 or hours > 255:
        raise ValueError("hours must be an integer from 0 to 255")
    if not isinstance(minutes, int) or isinstance(minutes, bool) or minutes < 0 or minutes > 59:
        raise ValueError("minutes must be an integer from 0 to 59")
    return f"{hours}:{minutes:02d}"


def _norm(text):
    text = text.replace("#MON", "Pokémon").replace("#DEX", "PokéDEX").replace("#", "Poké")
    text = text.replace("POKéMON", "Pokémon").replace("POKéDEX", "PokéDEX")
    text = text.replace("©", "")
    return re.sub(r"\s+", "", text).casefold()


def _contains(haystack, needle):
    folded = _norm(haystack)
    wanted = _norm(needle)
    if wanted.isdigit():
        return re.search(rf"(?<!\d){wanted}(?!\d)", folded) is not None
    return wanted in folded


def credits_from_pokered(root):
    """Read hall-of-fame's credits list from a pret/pokered checkout."""
    root = Path(root)
    order_text = (root / "data/credits/credits_order.asm").read_text()
    text_src = (root / "data/credits/credits_text.asm").read_text()
    mons_text = (root / "data/credits/credits_mons.asm").read_text()
    constants = (root / "constants/credits_constants.asm").read_text()
    species = (root / "constants/pokemon_constants.asm").read_text()

    names = {}
    index = 0
    for line in constants.splitlines():
        match = re.match(r"\s*const (CRED_[A-Z0-9_]+)", line)
        if not match:
            if line.strip().startswith("const_def -1"):
                break
            continue
        names[match.group(1)] = index
        index += 1

    strings = {}
    blue = False
    red = False
    for raw in text_src.splitlines():
        line = raw.strip()
        if line.startswith("IF DEF(_BLUE)"):
            blue = True
            continue
        if line.startswith("IF DEF(_RED)"):
            red = True
            continue
        if line.startswith("ENDC"):
            blue = False
            red = False
            continue
        if red and not blue:
            continue
        match = re.match(r"^(Cred[A-Za-z0-9]+):", line)
        if match:
            current = match.group(1)
            continue
        match = re.match(r'\s*db\s+(-?\d+),\s+"(.*)"', raw)
        if match and "current" in locals():
            strings[current] = match.group(2).rstrip("@")

    label_for = {}
    for const, idx in names.items():
        label = "Cred" + "".join(part.capitalize() for part in const[len("CRED_"):].split("_"))
        # The const names and the labels disagree in three places.
        label = {
            "CredMasude": "CredMasuda",
            "CredUsStaff": "CredUSStaff",
            "CredUsCoord": "CredUSCoord",
            "CredPaad": "CredPAAD",
        }.get(label, label)
        label_for[const] = label
    missing = [const for const in names if label_for[const] not in strings]
    if missing:
        raise ValueError("credits text missing: " + ", ".join(missing))

    species_names = re.findall(r"^\s*const ([A-Z0-9_]+)", species, re.M)
    mons = []
    for line in mons_text.splitlines():
        match = re.match(r"\s*db ([A-Z0-9_]+)", line)
        if match:
            token = match.group(1)
            if token not in species_names:
                raise ValueError("unknown credits species " + token)
            mons.append(token)

    tokens = []
    for line in order_text.splitlines():
        code = line.split(";", 1)[0]
        if "db" not in code:
            continue
        tokens.extend(re.findall(r"CRED_[A-Z0-9_]+", code))
    screens = []
    lines = []
    mon_index = 0
    for token in tokens:
        if token == "CRED_COPYRIGHT":
            lines = list(COPYRIGHT_LINES)
            continue
        if token in _CONTROL:
            kind = _CONTROL[token]
            if kind == "the_end":
                screens.append({
                    "kind": "the_end",
                    "lines": ["THE END"],
                    "gb_frames": THE_END_DELAY_FRAMES,
                    "fade_gb_frames": CREDITS_FADE_FRAMES,
                })
                continue
            screen = {"kind": kind, "lines": list(lines), "gb_frames": CREDITS_HOLD[kind]}
            if kind in ("fade_mon", "text_mon"):
                screen["species"] = mons[mon_index]
                mon_index += 1
            if kind in ("fade_mon", "fade"):
                screen["fade_gb_frames"] = CREDITS_FADE_FRAMES
            screens.append(screen)
            lines = []
            continue
        lines.append(strings[label_for[token]])
    if lines:
        raise ValueError("credits order ended inside a screen")
    if mon_index != len(mons):
        raise ValueError("credits mon count does not match the order")
    return screens


def expected_beats(party, player, credits, version="blue"):
    if version not in ("blue", "red"):
        raise ValueError("version must be blue or red")
    if not party:
        raise ValueError("the Hall of Fame party is empty")
    beats = [
        {"id": "hof-blank", "gb_frames": HOF_BLANK_FRAMES, "text": []},
    ]
    for index, mon in enumerate(party):
        nickname = mon.get("nickname") or mon["species"]
        types = list(mon["types"])
        if not types or len(types) > 2:
            raise ValueError("a Hall of Fame mon has one or two types")
        info = [nickname, "LEVEL/", str(mon["level"]), "TYPE1/", types[0]]
        if len(types) == 1:
            info.append("TYPE2 erased")
        else:
            info.extend(["TYPE2/", types[1]])
        beats.append({
            "id": f"hof-mon-{index}",
            "party_index": index,
            "species": mon["species"],
            "gb_frames": HOF_INFO_FRAMES,
            "scroll_gb_frames": HOF_BACK_SCROLL_FRAMES + HOF_FRONT_SCROLL_FRAMES,
            "text": info,
        })
        beats.append({
            "id": f"hof-banner-{index}",
            "party_index": index,
            "species": mon["species"],
            "gb_frames": HOF_BANNER_FRAMES,
            "text": info + ["HALL OF FAME"],
        })
    seen = player["seen"]
    owned = player["owned"]
    beats.append({
        "id": "hof-player",
        "text": [
            player["name"],
            "PLAY TIME",
            play_time_text(player["hours"], player["minutes"]),
            "MONEY",
            money_text(player["money"]),
        ],
    })
    beats.append({
        "id": "hof-dex-seen",
        "gb_frames": HOF_TEXT_FRAMES,
        "text": ["PokéDEX   Seen:", str(seen), "Owned:", str(owned)],
    })
    beats.append({
        "id": "hof-dex-rating-label",
        "gb_frames": HOF_TEXT_FRAMES,
        "text": ["PokéDEX Rating"],
    })
    beats.append({
        "id": "hof-dex-rating",
        "gb_frames": HOF_TEXT_FRAMES,
        "text": list(rating_lines(owned)),
    })
    beats.append({"id": "credits-clear", "gb_frames": CREDITS_CLEAR_FRAMES, "text": []})
    beats.append({"id": "credits-music", "gb_frames": CREDITS_MUSIC_FRAMES, "text": []})
    for index, screen in enumerate(credits):
        if screen["kind"] == "the_end":
            beats.append({
                "id": "the-end",
                "gb_frames": screen["gb_frames"],
                "fade_gb_frames": screen["fade_gb_frames"],
                "text": ["THE END"],
            })
            continue
        lines = list(screen["lines"])
        if version == "red":
            lines = ["RED VERSION STAFF" if line == "BLUE VERSION STAFF" else line for line in lines]
        beat = {
            "id": f"credits-{index:02d}",
            "kind": screen["kind"],
            "gb_frames": screen["gb_frames"],
            "text": lines,
        }
        if "fade_gb_frames" in screen:
            beat["fade_gb_frames"] = screen["fade_gb_frames"]
        if "species" in screen:
            beat["species"] = screen["species"]
        beats.append(beat)
    return beats


def _frame_text(frame):
    value = frame.get("text", "")
    if isinstance(value, list):
        return "\n".join(str(item) for item in value)
    return str(value)


def _check_timing(frame, beat, errors, where):
    if "gb_frames" in frame and "gb_frames" in beat and frame["gb_frames"] != beat["gb_frames"]:
        errors.append(f"{where}: gb_frames is {frame['gb_frames']}, pokered holds {beat['gb_frames']}")
    if "playdate_frames" in frame and "gb_frames" in beat:
        expected = beat["gb_frames"] * PLAYDATE_FRAME_HZ // GB_FRAME_HZ
        if frame["playdate_frames"] != expected:
            errors.append(
                f"{where}: playdate_frames is {frame['playdate_frames']}, "
                f"{beat['gb_frames']} GB frames is {expected} at 30fps"
            )
    if "seconds" in frame and "gb_frames" in beat:
        expected = beat["gb_frames"] / GB_FRAME_HZ
        if abs(float(frame["seconds"]) - expected) > 0.05:
            errors.append(f"{where}: seconds is {frame['seconds']}, pokered holds {expected:.3f}")
    if "fade_gb_frames" in frame and "fade_gb_frames" in beat and frame["fade_gb_frames"] != beat["fade_gb_frames"]:
        errors.append(
            f"{where}: fade_gb_frames is {frame['fade_gb_frames']}, pokered fades for {beat['fade_gb_frames']}"
        )


def _check_png(frame, root, errors, where):
    png = frame.get("png")
    if not png:
        return
    path = Path(png)
    if not path.is_absolute():
        path = root / path
    if not path.is_file():
        errors.append(f"{where}: missing frame {path}")
        return
    from PIL import Image
    with Image.open(path) as image:
        if image.size != FRAME_SIZE:
            errors.append(f"{where}: {path.name} is {image.size[0]}x{image.size[1]}, expected 400x240")


def check_log(log, credits, root=None):
    """Return a list of mismatches. An empty list means the log follows pokered."""
    root = Path(root) if root is not None else Path.cwd()
    errors = []
    version = log.get("version", "blue")
    try:
        beats = expected_beats(log["party"], log["player"], credits, version)
    except (KeyError, TypeError, ValueError) as exc:
        return [str(exc)]
    frames = [frame for frame in log.get("frames", []) if not frame.get("skip")]
    required = [beat for beat in beats if beat["text"] or beat["id"] in ("hof-blank", "credits-clear", "credits-music")]
    # Blank and music holds are required only when the log includes them.
    # A capture log must include every beat that has visible text.
    visible = [beat for beat in beats if beat["text"]]
    cursor = 0
    for beat in visible:
        match = None
        while cursor < len(frames):
            frame = frames[cursor]
            cursor += 1
            if frame.get("beat") == beat["id"] or frame.get("id") == beat["id"]:
                match = frame
                break
            if frame.get("beat") in ("hof-blank", "credits-clear", "credits-music"):
                blank = next(item for item in required if item["id"] == frame.get("beat"))
                _check_timing(frame, blank, errors, frame.get("beat"))
                continue
            errors.append(f"unexpected beat {frame.get('beat') or frame.get('id')} before {beat['id']}")
        if match is None:
            errors.append(f"missing beat {beat['id']}")
            continue
        text = _frame_text(match)
        for needle in beat["text"]:
            if needle == "TYPE2 erased":
                if _contains(text, "TYPE2/"):
                    errors.append(f"{beat['id']}: TYPE2/ is erased for a single-type species")
                continue
            if needle == "THE END":
                if _norm(text).replace(" ", "") != "theend" and "theend" not in _norm(text):
                    errors.append(f"{beat['id']}: text does not show THE END")
                continue
            if not _contains(text, needle):
                errors.append(f"{beat['id']}: missing {needle}")
        if "species" in beat:
            got = match.get("species")
            if got is None or str(got).replace(" ", "").casefold() != str(beat["species"]).replace(" ", "").casefold():
                errors.append(f"{beat['id']}: species is {got}, pokered shows {beat['species']}")
        _check_timing(match, beat, errors, beat["id"])
        _check_png(match, root, errors, beat["id"])
    while cursor < len(frames):
        frame = frames[cursor]
        cursor += 1
        name = frame.get("beat") or frame.get("id")
        if name in ("hof-blank", "credits-clear", "credits-music"):
            continue
        errors.append(f"unexpected beat {name} after THE END")
    return errors


def main(argv=None):
    parser = argparse.ArgumentParser(description="Check a Hall of Fame / credits frame log against pokered af519899.")
    parser.add_argument("--log", type=Path, help="JSON frame log")
    parser.add_argument("--pokered", type=Path, help="pret/pokered checkout; defaults to $POKERED or /tmp/pokered")
    parser.add_argument("--credits", type=Path, help="frozen credits JSON, used when --pokered is omitted")
    args = parser.parse_args(argv)
    if args.pokered:
        credits = credits_from_pokered(args.pokered)
    elif args.credits:
        credits = json.loads(args.credits.read_text())
    else:
        default = Path("/tmp/pokered")
        if default.joinpath("data/credits/credits_order.asm").is_file():
            credits = credits_from_pokered(default)
        else:
            parser.error("pass --pokered or --credits")
            return 2
    if args.log is None:
        json.dump(credits, sys.stdout, indent=2)
        sys.stdout.write("\n")
        return 0
    log = json.loads(args.log.read_text())
    errors = check_log(log, credits, root=args.log.parent)
    if errors:
        for error in errors:
            print(error)
        return 1
    print(f"hall-of-fame ok ({len(log.get('frames', []))} frames)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
