#!/usr/bin/env python3
"""Import overworld NPC sprites from the pokered disassembly.

Downloads gfx/sprites/<name>.png from pret/pokered (16x16 frames stacked
vertically, 2-bit grayscale; frame 0 is the down-facing stand), reduces the
four GB shades to 1-bit, and emits it through the same border-flood-fill
alpha pass the player sprites use.

Only the darkest shade becomes black: keeping the outlines and dropping the
gray clothing fills matches the white-body/black-outline look of the player
and rival sprites (mapping dark gray to black turns characters with shaded
dresses, like Mom and Daisy, into silhouettes). Pass --dark-grays for
sprites whose outlines are drawn in dark gray.

Usage:
  python3 tools/import_pokered_sprite.py mom daisy
  python3 tools/import_pokered_sprite.py --frame 1 mom

Writes Source/images/overworld/<name>-down.png. After importing, add the
file to the NPC re-emit list in generate_side_sprites.py and a npcImages
entry in Source/world/npc.lua.

Requires: Pillow
"""

import argparse
import io
import os
import urllib.request

from PIL import Image

from generate_side_sprites import bw_to_sprite

POKERED_RAW = "https://raw.githubusercontent.com/pret/pokered/master/gfx/sprites/{}.png"


def fetch_sheet(name):
    with urllib.request.urlopen(POKERED_RAW.format(name), timeout=30) as resp:
        return Image.open(io.BytesIO(resp.read()))


def frame_to_bw(sheet, frame, threshold=50):
    """16x16 frame of a 4-shade GB sheet -> L-mode 1-bit (0 black, 255 white)."""
    tile = sheet.convert("L").crop((0, frame * 16, 16, (frame + 1) * 16))
    bw = Image.new("L", (16, 16), 255)
    for y in range(16):
        for x in range(16):
            if tile.getpixel((x, y)) < threshold:
                bw.putpixel((x, y), 0)
    return bw


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="+", help="pokered sprite names (e.g. mom daisy)")
    ap.add_argument("--frame", type=int, default=0, help="frame index (0 = down stand)")
    ap.add_argument("--dark-grays", action="store_true",
                    help="also map GB dark gray to black (for gray-outlined sprites)")
    args = ap.parse_args()
    threshold = 128 if args.dark_grays else 50

    script_dir = os.path.dirname(os.path.abspath(__file__))
    out_dir = os.path.join(script_dir, "..", "Source", "images", "overworld")

    for name in args.names:
        sheet = fetch_sheet(name)
        sprite = bw_to_sprite(frame_to_bw(sheet, args.frame, threshold))
        path = os.path.join(out_dir, f"{name}-down.png")
        sprite.save(path)
        print(f"Imported {path} (frame {args.frame} of {sheet.height // 16})")


if __name__ == "__main__":
    main()
