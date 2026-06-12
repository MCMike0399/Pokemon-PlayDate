#!/usr/bin/env python3
"""Generate the player overworld sprites for the Playdate Pokemon PoC.

Side-facing frames are authored here as text grids based on the Pokemon
Red/Blue Game Boy sprite (pokered decompilation). Unlike Gen 1 (which had a
single side walk frame), we author TWO distinct stride frames — the scheme
GBA-era Pokemon used — so left/right steps can alternate lead legs and the
walk reads smoothly.

All frames (including down/up, which are re-emitted from their existing
PNGs) get proper sprite alpha:
  - transparent OUTSIDE the character outline (no white box over tiles)
  - opaque white INSIDE the body (tile dither never bleeds through)
computed via a border flood-fill over the white pixels.

Right-facing sprites are generated at runtime by flipping left-facing ones.

Requires: Pillow (pip install Pillow)
"""

from collections import deque
import os

from PIL import Image

# '#' = black pixel, '.' = white (interior stays opaque, exterior becomes
# transparent via flood fill)

_HEAD = [
    "................",  # 0  empty (matches all other sprites)
    ".....######.....",  # 1  cap top
    "....#......#....",  # 2  cap outline
    "...#........#...",  # 3  head
    "..##........#...",  # 4  brim + head
    ".#.........###..",  # 5  brim extends + hair
    "..##...#######..",  # 6  face
    "...#.#..######..",  # 7  eye + face
    "...#.#..#..##...",  # 8  lower face
]

# Standing body: GB Frame 2 (compact, legs together)
STANDING = _HEAD + [
    "....#....##.#...",  # 9  neck/chest
    ".....#####..#...",  # 10 torso + trailing arm
    "......##..#.#...",  # 11 waist + detail
    "......##..#.#...",  # 12 waist
    ".....#..####....",  # 13 hips/upper legs
    ".....#....#.....",  # 14 legs together
    "......####......",  # 15 feet together
]

# Down/up frames: heads and torsos keep the authentic GB art; the leg rows
# follow the authentic pokered frames (gfx/sprites/red.png frames 0/1/3/4) —
# outlined legs with white interiors, not solid blocks. The walk pose has
# ONE clearly lifted foot; the runtime X-flips it on alternate steps (Gen
# 1's trick), so the lifted foot must read unambiguously left or right.
#
# Walk frames are drawn 1px lower than standing (Gen 1 body bob). The
# silhouette stays NARROW — one leg planted near center, the other foot
# raised BEHIND the body beside the hip. No lateral kick (a kicked-out
# foot reads as a frog hop at this scale).

# Authentic GB standing legs (pokered red.png frames 0/1 rows 13-15):
# outlined with white interiors — black only at the edges plus the shorts
# hem — instead of solid blocks, matching the side frames' leg weight.
_LEGS_STAND_DOWN = [
    "...#.##..##.#...",  # 13 thighs, shorts hem
    "...#...##...#...",  # 14 shins, inner-leg shadow
    "....###..###....",  # 15 feet
]

# Up legs differ only at the thigh row: a dark band under the backpack.
_LEGS_STAND_UP = [
    "...#.######.#...",  # 13 thighs under the backpack shadow
    "...#...##...#...",  # 14 shins, inner-leg shadow
    "....###..###....",  # 15 feet
]

DOWN = [
    "................",  # 0
    ".....######.....",  # 1  cap top
    "....#......#....",  # 2
    "...#........#...",  # 3
    "...#........#...",  # 4
    "..###......###..",  # 5  cap sides
    "..############..",  # 6  brim
    ".#.#........#.#.",  # 7  face + ears
    ".#....#..#....#.",  # 8  eyes
    ".###..#..#..##..",  # 9  face bottom
    ".#.##......#.#..",  # 10 collar
    "..##########.#..",  # 11 shoulders
    "...##.####..##..",  # 12 arms + shirt
] + _LEGS_STAND_DOWN

DOWN_WALK = [
    "................",  # 0
    "................",  # 1  (body dips 1px on the stride)
    ".....######.....",  # 2  cap top
    "....#......#....",  # 3
    "...#........#...",  # 4
    "...#........#...",  # 5
    "..###......###..",  # 6  cap sides
    "..############..",  # 7  brim
    ".#.#........#.#.",  # 8  face + ears
    ".#....#..#....#.",  # 9  eyes
    "..##..#..#..###.",  # 10 face bottom (arm swing)
    "..#.#......##.#.",  # 11 collar
    "..#.##########..",  # 12 shoulders
    "..##..####.##...",  # 13 arms + shirt
    "....#..##.##....",  # 14 planted left shin (outlined) + raised right foot
    ".....###........",  # 15 planted left foot; right foot off the ground
]

UP = [
    "................",  # 0
    ".....######.....",  # 1  cap top
    "....#......#....",  # 2
    "...#........#...",  # 3
    "...#........#...",  # 4
    "..##........##..",  # 5
    "..###......###..",  # 6  cap back
    ".#.##########.#.",  # 7  hair
    ".#..########..#.",  # 8
    ".###..####..##..",  # 9  backpack top
    ".#.###....####..",  # 10 backpack
    "..###.####.#..#.",  # 11 backpack bottom + arm
    "...##......##...",  # 12 arms
] + _LEGS_STAND_UP

UP_WALK = [
    "................",  # 0
    "................",  # 1  (body dips 1px on the stride)
    ".....######.....",  # 2  cap top
    "....#......#....",  # 3
    "...#........#...",  # 4
    "...#........#...",  # 5
    "..##........##..",  # 6
    "..###......###..",  # 7  cap back
    ".#.##########.#.",  # 8  hair
    ".#..########..#.",  # 9
    "..##..####..###.",  # 10 backpack (arm swing)
    "..####....###.#.",  # 11
    ".#..#.####.###..",  # 12
    ".#..#.....###...",  # 13 raised right foot behind (authentic 3px width)
    "....#.####......",  # 14 planted left shin (outlined) + far leg in shadow
    ".....###........",  # 15 planted left foot
]

# Side stride frames bob like the down/up ones: the whole body drops 1px
# (two blank rows on top) and the legs/torso compress a row to keep the
# feet on the ground line. The dipped head reuses _HEAD shifted down.
_HEAD_DIP = ["................"] + _HEAD

# Stride A: the authentic Gen 1 side walk (pokered red.png frame 5, minus
# the chin row this project also drops from the standing frame). Both arms
# swing — front arm reaching forward, rear arm trailing back — and the
# legs are short and chunky: front foot planted, rear toe pushing off.
WALK1 = _HEAD_DIP + [
    "....#....##.#...",  # 10 neck
    ".....######.#...",  # 11 torso
    "...######..##...",  # 12 arm swing: front arm forward, rear arm back
    "..#..#..#..#.#..",  # 13 hands + hips
    "...#..#####..#..",  # 14 legs, weight over the front foot
    "....###....##...",  # 15 front foot planted, rear toe push-off
]

# Stride B: the passing pose Gen 1 never had, after FRLG's second side
# stride (pokefirered red_normal.png frame 7): legs gathered under the
# body mid-swing, one foot planted beneath the hip. Torso and arms reuse
# WALK1's authentic art; the fist bottoms close 1px wider so the flood
# fill can't hollow them out now that no planted foot seals them below.
WALK2 = _HEAD_DIP + [
    "....#....##.#...",  # 10 neck
    ".....######.#...",  # 11 torso
    "...######..##...",  # 12 arm swing: front arm forward, rear arm back
    "..#..#..#..#.#..",  # 13 hands + hips
    "...##.#####.##..",  # 14 legs gathered mid-swing
    ".......###......",  # 15 single foot planted under the body
]


def grid_to_bw(grid):
    """16x16 text grid -> L-mode image (0 black, 255 white)."""
    img = Image.new("L", (16, 16), 255)
    for y, row in enumerate(grid):
        assert len(row) == 16, f"row {y}: expected 16 cols, got {len(row)}"
        for x, ch in enumerate(row):
            if ch == "#":
                img.putpixel((x, y), 0)
    return img


def png_to_bw(path):
    """Existing sprite PNG -> L-mode (transparent pixels count as white)."""
    src = Image.open(path).convert("RGBA")
    img = Image.new("L", src.size, 255)
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = src.getpixel((x, y))
            if a >= 128 and r < 128:
                img.putpixel((x, y), 0)
    return img


def bw_to_sprite(bw):
    """Border flood-fill: outside whites -> transparent, the rest opaque."""
    w, h = bw.size
    outside = [[False] * w for _ in range(h)]
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if bw.getpixel((x, y)) == 255 and not outside[y][x]:
                outside[y][x] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if bw.getpixel((x, y)) == 255 and not outside[y][x]:
                outside[y][x] = True
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h and not outside[ny][nx] \
                    and bw.getpixel((nx, ny)) == 255:
                outside[ny][nx] = True
                q.append((nx, ny))

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            if bw.getpixel((x, y)) == 0:
                out.putpixel((x, y), (0, 0, 0, 255))
            elif not outside[y][x]:
                out.putpixel((x, y), (255, 255, 255, 255))
    return out


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    out_dir = os.path.join(script_dir, "..", "Source", "images", "overworld")
    os.makedirs(out_dir, exist_ok=True)

    # Player frames authored here
    jobs = {
        "player-left.png": grid_to_bw(STANDING),
        "player-left-walk1.png": grid_to_bw(WALK1),
        "player-left-walk2.png": grid_to_bw(WALK2),
        "player-down.png": grid_to_bw(DOWN),
        "player-down-walk.png": grid_to_bw(DOWN_WALK),
        "player-up.png": grid_to_bw(UP),
        "player-up-walk.png": grid_to_bw(UP_WALK),
    }

    # NPC frames: re-emit existing art with proper alpha
    for name in ("oak-down.png", "rival-down.png", "mom-down.png", "daisy-down.png"):
        path = os.path.join(out_dir, name)
        if os.path.exists(path):
            jobs[name] = png_to_bw(path)

    for filename, bw in jobs.items():
        sprite = bw_to_sprite(bw)
        path = os.path.join(out_dir, filename)
        sprite.save(path)
        print(f"Generated {path}")


if __name__ == "__main__":
    main()
