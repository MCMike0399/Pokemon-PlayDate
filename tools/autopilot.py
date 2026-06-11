#!/usr/bin/env python3
"""Drive the in-game autopilot (Source/dev/autopilot.lua) from the host.

Writes a command file into the Playdate Simulator's sandboxed Data folder,
waits for the game's ack file, and post-processes screenshots that the game
wrote into tools/shots/.

Usage:
  python3 tools/autopilot.py "encounters off" "move right 3" "shot town"
  python3 tools/autopilot.py "record walk-right 20" "move right 2" --strip walk-right

Options:
  --strip <prefix>   After commands finish (or standalone), assemble all
                     shots/<prefix>-NN.png frames into one magnified,
                     numbered film strip at shots/<prefix>-strip.png and
                     print per-frame pixel-diff counts.
  --crop <size>      Crop box (centered on screen center) used for the strip,
                     default 120. 0 = no crop (full 400x240 frames).
  --clean <prefix>   Delete shots/<prefix>*.png before sending commands.
  --timeout <sec>    Ack timeout (default 60).

Requires Pillow for --strip.
"""

import argparse
import glob
import os
import re
import sys
import time

DATA_DIR = os.path.expanduser("~/Developer/PlaydateSDK/Disk/Data/com.poc.pokemon")
SHOTS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "shots")
CMD_FILE = os.path.join(DATA_DIR, "autopilot.txt")
DONE_FILE = os.path.join(DATA_DIR, "autopilot-done.txt")

# Playdate screen; the camera keeps the player's center near screen center
SCREEN_W, SCREEN_H = 400, 240


def send(commands, timeout=60):
    os.makedirs(SHOTS_DIR, exist_ok=True)
    os.makedirs(DATA_DIR, exist_ok=True)
    if os.path.exists(DONE_FILE):
        os.remove(DONE_FILE)

    tmp = CMD_FILE + ".tmp"
    with open(tmp, "w") as f:
        f.write("\n".join(commands) + "\n")
    os.rename(tmp, CMD_FILE)  # atomic: the game never sees a partial file

    deadline = time.time() + timeout
    while time.time() < deadline:
        if os.path.exists(DONE_FILE):
            time.sleep(0.2)  # let the game finish writing
            with open(DONE_FILE) as f:
                ack = f.read().strip()
            os.remove(DONE_FILE)
            print(ack)
            return True
        time.sleep(0.1)
    print("TIMEOUT: no ack from the game — is the Simulator running the current build?", file=sys.stderr)
    return False


def frame_key(path):
    m = re.search(r"-(\d+)\.png$", path)
    return int(m.group(1)) if m else 0


def build_strip(prefix, crop=120, scale=2, columns=8, center=None):
    from PIL import Image, ImageDraw

    frames = sorted(
        glob.glob(os.path.join(SHOTS_DIR, f"{prefix}-[0-9]*.png")), key=frame_key
    )
    if not frames:
        print(f"no frames matching {prefix}-NN.png in {SHOTS_DIR}", file=sys.stderr)
        return None

    images = []
    for path in frames:
        img = Image.open(path).convert("L")
        if crop:
            cx, cy = center or (SCREEN_W // 2, SCREEN_H // 2)
            cx = max(crop // 2, min(SCREEN_W - crop // 2, cx))
            cy = max(crop // 2, min(SCREEN_H - crop // 2, cy))
            half = crop // 2
            img = img.crop((cx - half, cy - half, cx + half, cy + half))
        images.append(img)

    # Per-frame pixel diffs (raw 1x crops): spikes = pose snaps
    diffs = []
    for a, b in zip(images, images[1:]):
        pa, pb = a.tobytes(), b.tobytes()
        diffs.append(sum(1 for x, y in zip(pa, pb) if x != y))
    print("frame-to-frame pixel diffs:", diffs)

    tile_w = images[0].width * scale
    tile_h = images[0].height * scale
    label_h = 14
    cols = min(columns, len(images))
    rows = (len(images) + cols - 1) // cols
    sheet = Image.new("L", (cols * tile_w, rows * (tile_h + label_h)), 255)
    draw = ImageDraw.Draw(sheet)
    for i, img in enumerate(images):
        big = img.resize((tile_w, tile_h), Image.NEAREST)
        col, row = i % cols, i // cols
        x, y = col * tile_w, row * (tile_h + label_h)
        draw.text((x + 2, y + 1), str(i + 1), fill=0)
        sheet.paste(big, (x, y + label_h))

    out = os.path.join(SHOTS_DIR, f"{prefix}-strip.png")
    sheet.save(out)
    print(f"strip: {out} ({len(images)} frames)")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("commands", nargs="*", help="autopilot commands, one per arg")
    ap.add_argument("--strip", metavar="PREFIX")
    ap.add_argument("--crop", type=int, default=120)
    ap.add_argument("--at", metavar="X,Y", help="crop center in screen px (default: screen center)")
    ap.add_argument("--clean", metavar="PREFIX")
    ap.add_argument("--timeout", type=int, default=60)
    args = ap.parse_args()

    if args.clean:
        for f in glob.glob(os.path.join(SHOTS_DIR, f"{args.clean}*.png")):
            os.remove(f)

    if args.commands:
        if not send(args.commands, timeout=args.timeout):
            sys.exit(1)

    if args.strip:
        center = None
        if args.at:
            x, y = args.at.split(",")
            center = (int(x), int(y))
        if not build_strip(args.strip, crop=args.crop, center=center):
            sys.exit(1)


if __name__ == "__main__":
    main()
