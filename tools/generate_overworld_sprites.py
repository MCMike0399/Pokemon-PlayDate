#!/usr/bin/env python3
"""Deterministically generate NPC overworld sprite grids from the real Gen 1
(pokered) overworld sprites, instead of hand-drawing approximations.

Reads the pokered sprite strips (16 x 16*frames, 4-shade), extracts the
down/up/left standing frames, maps the GB shades to our grid convention, and
writes Source/world/sprites/<key>.lua. RED is left alone (proven art).

Frame layout in pokered strips: 0=down, 1=up, 2=side(faces LEFT), 3..=walk.

Shade mapping is configurable (--map). The GB palette is:
  white(255) dark? -> our '.'   light-grey(170) -> '1'   dark-grey(85) -> '2'
  black(0) -> '#'
Run with the venv that has Pillow, e.g.:
  tools/shots/gen1ref/.venv/bin/python tools/generate_overworld_sprites.py --map bw
"""
import argparse, os, sys, urllib.request

SRC = "https://raw.githubusercontent.com/pret/pokered/master/gfx/sprites/{}.png"
# pokered file -> our sprite key
CHARS = {"blue": "rival", "oak": "oak", "mom": "mom", "daisy": "daisy"}
CACHE = os.path.join(os.path.dirname(__file__), "shots", "gen1ref")
OUT = os.path.join(os.path.dirname(__file__), "..", "Source", "world", "sprites")

# Shade-mapping strategies. Keys are the 4 ranked shades light->dark.
MAPS = {
    # faithful: keep all four shades (greys become dither in-engine)
    "faithful": {"white": ".", "light": "1", "dark": "2", "black": "#"},
    # bw: light grey -> white, dark grey -> black (pure B/W like RED)
    "bw":       {"white": ".", "light": ".", "dark": "#", "black": "#"},
    # greyhair: light grey -> white (clean, RED-like body/face), dark grey
    # kept as the `2` dither (textured grey hair instead of a solid-black blob)
    "greyhair": {"white": ".", "light": ".", "dark": "2", "black": "#"},
    # outline: both greys -> white, only true black survives (max-clean)
    "outline":  {"white": ".", "light": ".", "dark": ".", "black": "#"},
    # heavy: both greys -> black
    "heavy":    {"white": ".", "light": "#", "dark": "#", "black": "#"},
}


def load(name):
    from PIL import Image
    os.makedirs(CACHE, exist_ok=True)
    p = os.path.join(CACHE, name + ".png")
    if not os.path.exists(p):
        urllib.request.urlretrieve(SRC.format(name), p)
    return Image.open(p).convert("RGB")


def frame_to_grid(im, fi, mapping):
    px = im.load()
    # rank colours present in the WHOLE strip light->dark for a stable map
    cols = {}
    w, h = im.size
    for y in range(h):
        for x in range(w):
            cols[px[x, y]] = 1
    ranked = sorted(cols, key=lambda c: -(0.299*c[0]+0.587*c[1]+0.114*c[2]))
    # map ranked index -> shade name (white/light/dark/black) by position
    names = ["white", "light", "dark", "black"]
    idx2char = {}
    n = len(ranked)
    for i, c in enumerate(ranked):
        # collapse to 4 buckets if fewer/more colours
        bucket = names[min(i, 3)] if n >= 4 else names[i * 3 // max(1, n-1)]
        idx2char[c] = mapping[bucket]
    rows = []
    for y in range(16):
        rows.append("".join(idx2char[px[x, fi*16 + y]] for x in range(16)))
    return rows


def fmt(key, frames, mapname):
    def block(rows):
        return "\n".join('        "%s",' % r for r in rows)
    return (
        "-- %s: generated from the pokered Gen 1 overworld sprite by\n"
        "-- tools/generate_overworld_sprites.py --map %s --only %s\n"
        "-- (do not hand-edit; regenerate).\n"
        "SpriteFactory.grids.%s = {\n"
        "    down = {\n%s\n    },\n"
        "    up = {\n%s\n    },\n"
        "    left = {\n%s\n    },\n"
        "}\n"
    ) % (key, mapname, key, key,
         block(frames["down"]), block(frames["up"]), block(frames["left"]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--map", default="bw", choices=list(MAPS))
    ap.add_argument("--write", action="store_true", help="write the .lua files")
    ap.add_argument("--only", default="", help="comma-list of sprite keys to (re)generate")
    args = ap.parse_args()
    mapping = MAPS[args.map]
    only = set(k for k in args.only.split(",") if k)
    for src, key in CHARS.items():
        if only and key not in only:
            continue
        im = load(src)
        nframes = im.size[1] // 16
        frames = {
            "down": frame_to_grid(im, 0, mapping),
            "up":   frame_to_grid(im, 1 if nframes > 1 else 0, mapping),
            "left": frame_to_grid(im, 2 if nframes > 2 else 0, mapping),
        }
        out = fmt(key, frames, args.map)
        if args.write:
            with open(os.path.join(OUT, key + ".lua"), "w") as f:
                f.write(out)
            print("wrote", key + ".lua", "(map=%s)" % args.map)
        else:
            print(out)


if __name__ == "__main__":
    main()
