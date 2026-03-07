#!/usr/bin/env python3
"""Generate left-facing player sprites for the Playdate Pokemon PoC.

Uses the ACTUAL Pokemon Red/Blue Game Boy sprite data (from pokered decompilation),
converted to 1-bit (only pure black pixels kept, matching the existing game's style).

GB Frame 2 = side standing, GB Frame 5 = side walking.
Gen I only had ONE side walk frame, so walk1 and walk2 are identical.

Right-facing sprites are generated at runtime by flipping left-facing ones.

Requires: Pillow (pip install Pillow)
"""

from PIL import Image
import os

# '#' = black pixel, '.' = transparent pixel
#
# Head (rows 0-9): existing game head (matches GB data, empty row 0 for consistency)
# Standing body (rows 10-15): from GB Frame 2 (compact, legs together)
# Walking body (rows 10-15): from GB Frame 5 (stride, wide stance)
#
# The standing and walking frames have DIFFERENT bodies — this is authentic
# Pokemon Red/Blue behavior where side sprites were completely redrawn per frame.

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

# Standing body: GB Frame 2 rows 9-15 (neck through feet, legs together)
# Row 9 of GB Frame 2 serves as the neck transition
STANDING = _HEAD + [
    "....#....##.#...",  # 9  neck/chest (GB Frame 2 row 9)
    ".....#####..#...",  # 10 torso + trailing arm (GB row 10)
    "......##..#.#...",  # 11 waist + detail (GB row 11)
    "......##..#.#...",  # 12 waist (GB row 12)
    ".....#..####....",  # 13 hips/upper legs (GB row 13)
    ".....#....#.....",  # 14 legs together (GB row 14)
    "......####......",  # 15 feet together (GB row 15)
]

# Walking body: GB Frame 5 rows 9-15 (the stride pose)
# This is what the game originally used as the standing sprite.
_WALK = _HEAD + [
    "...#.......#....",  # 9  chin (GB Frame 5 row 9)
    "....#....##.#...",  # 10 neck (GB row 10)
    ".....######.#...",  # 11 torso + arm (GB row 11)
    "...######..##...",  # 12 wide waist (GB row 12)
    "..#..#..#..#.#..",  # 13 stride legs (GB row 13)
    "...#..#####..#..",  # 14 legs (GB row 14)
    "....###....##...",  # 15 feet apart (GB row 15)
]

# Gen I only had one side walk frame; walk1 and walk2 are identical
WALK1 = _WALK
WALK2 = _WALK


def grid_to_image(grid):
    """Convert a 16x16 text grid to an RGBA PIL Image with transparent background."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch == "#":
                img.putpixel((x, y), (0, 0, 0, 255))
    return img


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    out_dir = os.path.join(script_dir, "..", "Source", "images", "overworld")
    os.makedirs(out_dir, exist_ok=True)

    sprites = {
        "player-left.png": STANDING,
        "player-left-walk1.png": WALK1,
        "player-left-walk2.png": WALK2,
    }

    for filename, grid in sprites.items():
        assert len(grid) == 16, f"{filename}: expected 16 rows, got {len(grid)}"
        for i, row in enumerate(grid):
            assert len(row) == 16, f"{filename} row {i}: expected 16 cols, got {len(row)}"

        img = grid_to_image(grid)
        path = os.path.join(out_dir, filename)
        img.save(path)
        print(f"Generated {path}")


if __name__ == "__main__":
    main()
