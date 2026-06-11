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
# are redrawn so the standing pose is symmetric and the walk pose has ONE
# clearly lifted foot. The runtime X-flips the walk frame on alternate steps
# (Gen 1's trick), so the lifted foot must read unambiguously left or right.
#
# Walk frames are drawn 1px lower than standing (Gen 1 body bob). Leg pose
# follows the authentic pokered frames (gfx/sprites/red.png frames 3/4):
# the silhouette stays NARROW — one leg planted near center, the other leg
# raised BEHIND the body with only a small heel hint beside the hip. No
# lateral kick (a kicked-out foot reads as a frog hop at this scale).

# Stout GB-style standing legs (authentic r15 is '###..###' — straight
# down, small gap, no flare; thin stilts read as insect legs)
_DOWN_LEGS_STAND = [
    "...####..####...",  # 13 thighs
    "....###..###....",  # 14 shins
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
] + _DOWN_LEGS_STAND

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
    "....#####..##...",  # 14 planted left thigh+knee; raised right heel
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
] + _DOWN_LEGS_STAND

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
    ".#..#......##...",  # 13 (right marks read as the raised heel behind)
    "....######......",  # 14 planted left leg; raised leg hidden behind body
    ".....###........",  # 15 planted left foot
]

# Side stride legs use thin 1px outlines like the standing pose — solid 2px
# legs read as oversized at this scale.

# Stride A: near leg forward (authentic GB Frame 5 torso)
WALK1 = _HEAD + [
    "...#.......#....",  # 9  chin
    "....#....##.#...",  # 10 neck
    ".....######.#...",  # 11 torso + arm
    "...######..##...",  # 12 wide waist + rear arm
    "....#...##......",  # 13 front thigh, rear thigh
    "...#......#.....",  # 14 front shin, rear shin
    "...##.....##....",  # 15 feet apart
]

# Stride B: far leg forward (slight variation -> visible alternation)
WALK2 = _HEAD + [
    "...#.......#....",  # 9  chin
    "....#....##.#...",  # 10 neck
    ".....######.#...",  # 11 torso + arm
    "....#####..##...",  # 12 waist + rear arm
    ".....#..##......",  # 13 thighs scissored
    "....#.....#.....",  # 14 front shin, rear shin
    "....##....##....",  # 15 feet apart
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
    for name in ("oak-down.png", "rival-down.png"):
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
