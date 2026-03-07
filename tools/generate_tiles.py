#!/usr/bin/env python3
"""
Generate Pokemon Blue-style 16x16 1-bit tile sprites for Playdate.

Simulates the Game Boy's 4 shades using ordered dithering:
  - White (0% black):      Pure white - window glass, highlights
  - Light gray (~12.5%):   Sparse ordered dots - ground, walls, grass
  - Dark gray (~50%):      Checkerboard - roofs, water
  - Black (100%):          Solid black - doors, outlines, tree canopy

All tiles are 16x16 PNGs, scaled 2x at runtime to 32x32.
"""
from PIL import Image
import os
import math

SIZE = 16
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "Source", "images", "tiles")


# ============================================================
# DRAWING PRIMITIVES
# ============================================================

def new_tile(fill=1):
    return Image.new("1", (SIZE, SIZE), fill)


def px(img, x, y, c=0):
    if 0 <= x < SIZE and 0 <= y < SIZE:
        img.putpixel((x, y), c)


def get_px(img, x, y):
    if 0 <= x < SIZE and 0 <= y < SIZE:
        return img.getpixel((x, y))
    return 1


def hline(img, x1, x2, y, c=0):
    for x in range(x1, x2 + 1):
        px(img, x, y, c)


def vline(img, x, y1, y2, c=0):
    for y in range(y1, y2 + 1):
        px(img, x, y, c)


def rect(img, x1, y1, x2, y2, c=0):
    hline(img, x1, x2, y1, c)
    hline(img, x1, x2, y2, c)
    vline(img, x1, y1, y2, c)
    vline(img, x2, y1, y2, c)


def fill_rect(img, x1, y1, x2, y2, c=0):
    for y in range(y1, y2 + 1):
        for x in range(x1, x2 + 1):
            px(img, x, y, c)


# ============================================================
# DITHERING PATTERNS (Game Boy shade simulation)
# ============================================================

def is_light_gray(x, y):
    """~12.5% density staggered dither (2 dots per 4x4 block).
    Matches Lua Shade.LIGHT pattern. Tuned for 16x16 tiles scaled 2x."""
    return (x % 4 == 1 and y % 4 == 0) or (x % 4 == 3 and y % 4 == 2)


def is_dark_gray(x, y):
    """~50% density checkerboard dither.
    Matches Game Boy 'dark gray' shade."""
    return (x + y) % 2 == 0


def fill_light_gray(img):
    """Fill white pixels with light gray dither."""
    for y in range(SIZE):
        for x in range(SIZE):
            if get_px(img, x, y) == 1 and is_light_gray(x, y):
                px(img, x, y, 0)
    return img


def fill_dark_gray(img):
    """Fill white pixels with dark gray (checkerboard)."""
    for y in range(SIZE):
        for x in range(SIZE):
            if get_px(img, x, y) == 1 and is_dark_gray(x, y):
                px(img, x, y, 0)
    return img


def apply_light_gray_region(img, x1, y1, x2, y2):
    """Apply light gray dither to a rectangular region (only on white pixels)."""
    for y in range(y1, y2 + 1):
        for x in range(x1, x2 + 1):
            if get_px(img, x, y) == 1 and is_light_gray(x, y):
                px(img, x, y, 0)


def apply_dark_gray_region(img, x1, y1, x2, y2):
    """Apply dark gray dither to a rectangular region (only on white pixels)."""
    for y in range(y1, y2 + 1):
        for x in range(x1, x2 + 1):
            if get_px(img, x, y) == 1 and is_dark_gray(x, y):
                px(img, x, y, 0)


# ============================================================
# TILE DEFINITIONS
# ============================================================

def make_grass():
    """Light gray ground - the base shade for all outdoor areas.
    In Pokemon Blue, ground is uniform light gray everywhere."""
    img = new_tile(1)
    fill_light_gray(img)
    return img


def make_path():
    """Same as grass - in Pokemon Blue, paths and ground are the same shade.
    Navigation comes from building/tree layout, not path coloring."""
    img = new_tile(1)
    fill_light_gray(img)
    return img


def make_wall():
    """Brick wall: light gray base + black mortar lines.
    In Pokemon Blue, brick areas are the SAME shade as ground,
    with black mortar lines creating the brick pattern."""
    img = new_tile(1)
    fill_light_gray(img)
    # Horizontal mortar lines
    for y in [0, 4, 8, 12]:
        hline(img, 0, 15, y, 0)
    # Staggered vertical mortar
    vline(img, 7, 1, 3, 0)
    vline(img, 3, 5, 7, 0)
    vline(img, 11, 5, 7, 0)
    vline(img, 7, 9, 11, 0)
    vline(img, 3, 13, 15, 0)
    vline(img, 11, 13, 15, 0)
    return img


def make_water():
    """Dark gray water with wave highlight lines.
    Base is dark gray (checkerboard), with white wave curves carved out."""
    img = new_tile(1)
    fill_dark_gray(img)
    # Carve white wave highlight lines
    for wave in range(4):
        base_y = wave * 4 + 2
        offset = (wave % 2) * 4
        for x in range(16):
            wy = base_y + round(1.0 * math.sin((x + offset) * math.pi / 4))
            px(img, x, wy, 1)  # white highlight
            # Also lighten pixel above for thicker wave line
            px(img, x, wy - 1, 1)
    return img


def make_tree():
    """Dense dark canopy with light gray ground at edges.
    Trees in Pokemon Blue are nearly solid black with sparse leaf texture."""
    img = new_tile(1)
    # Light gray base (ground showing at corners)
    fill_light_gray(img)
    # Dense canopy shape - rounded rectangle
    for y in range(SIZE):
        for x in range(SIZE):
            in_canopy = False
            if y == 0 or y == 15:
                in_canopy = 4 <= x <= 11
            elif y == 1 or y == 14:
                in_canopy = 2 <= x <= 13
            elif 2 <= y <= 13:
                in_canopy = 1 <= x <= 14
            if in_canopy:
                px(img, x, y, 0)
    # Sparse leaf texture (white specks inside canopy)
    specks = [
        (4, 3), (10, 2), (7, 4), (13, 3),
        (3, 6), (8, 5), (12, 7),
        (5, 8), (10, 9), (3, 10),
        (7, 11), (12, 10), (5, 13),
        (9, 12), (11, 4), (6, 7),
    ]
    for sx, sy in specks:
        px(img, sx, sy, 1)
    return img


def make_door():
    """Door: wall brick top with dark door opening below.
    Mortar lines connect to adjacent wall tiles."""
    img = new_tile(1)
    fill_light_gray(img)
    # Top wall portion with mortar
    hline(img, 0, 15, 0, 0)  # mortar connecting to wall above
    vline(img, 3, 1, 3, 0)   # vertical mortar
    vline(img, 11, 1, 3, 0)
    hline(img, 0, 15, 4, 0)  # mortar line
    # Door opening (solid black)
    fill_rect(img, 4, 5, 11, 15, 0)
    return img


def make_fence():
    """Picket fence: white fence on light gray ground base.
    Fence pickets are white (brighter than ground) with black outline."""
    img = new_tile(1)
    fill_light_gray(img)
    # Clear fence area to white (fence is brighter than ground)
    fill_rect(img, 0, 2, 15, 13, 1)
    # Horizontal rails (black)
    hline(img, 0, 15, 3, 0)
    hline(img, 0, 15, 11, 0)
    # Vertical pickets (black outlines)
    for post_x in [1, 5, 9, 13]:
        vline(img, post_x, 2, 13, 0)
    # Re-apply light gray to ground rows (top and bottom)
    for y in [0, 1, 14, 15]:
        for x in range(SIZE):
            if is_light_gray(x, y):
                px(img, x, y, 0)
            else:
                px(img, x, y, 1)
    return img


def make_tallgrass():
    """Tall grass: medium-dark with grass blade V-shapes.
    Denser than ground (~30-35%) with visible blade texture.
    Uses a 4x4 repeating V-blade pattern."""
    img = new_tile(1)
    for y in range(SIZE):
        for x in range(SIZE):
            by = y % 4
            bx = x % 4
            # V-shape blades: tips at top, wider at bottom
            if by == 0 and bx % 2 == 1:      # blade tips
                px(img, x, y, 0)
            elif by == 1 and bx % 2 == 0:     # blade sides
                px(img, x, y, 0)
            elif by == 2 and bx % 2 == 1:     # blade bases
                px(img, x, y, 0)
            # Row 3 (by==3) is blank - gap between blade rows
    return img


def make_roof():
    """Roof middle: dark gray checkerboard with shingle accent lines.
    The checkerboard creates the 'dark gray' shade, and solid black
    lines every 4 rows add a horizontal shingle/ridge effect."""
    img = new_tile(1)
    fill_dark_gray(img)
    # Horizontal shingle ridge lines (solid black)
    for y in [3, 7, 11, 15]:
        hline(img, 0, 15, y, 0)
    return img


def make_sign():
    """Sign: white board with black outline on light gray ground."""
    img = new_tile(1)
    fill_light_gray(img)
    # Sign board (clear to white, then outline)
    fill_rect(img, 3, 1, 12, 6, 1)
    rect(img, 3, 1, 12, 6, 0)
    # Post
    vline(img, 7, 7, 14, 0)
    vline(img, 8, 7, 14, 0)
    return img


def make_flowers():
    """Flowers: small + shapes on light gray ground."""
    img = new_tile(1)
    fill_light_gray(img)
    # Flower positions (small + crosses)
    flowers = [(4, 3), (11, 3), (7, 8), (3, 12), (12, 12)]
    for fx, fy in flowers:
        px(img, fx, fy, 0)      # center
        px(img, fx - 1, fy, 0)  # left
        px(img, fx + 1, fy, 0)  # right
        px(img, fx, fy - 1, 0)  # up
        px(img, fx, fy + 1, 0)  # down
    return img


def make_shore():
    """Shore: transition from light gray land to dark gray water.
    Wavy edge line separates the two zones."""
    img = new_tile(1)
    for y in range(SIZE):
        for x in range(SIZE):
            # Wavy edge around y=7-8
            edge_y = 7 + round(1.5 * math.sin(x * math.pi / 4))
            if y < edge_y:
                # Land (light gray)
                if is_light_gray(x, y):
                    px(img, x, y, 0)
            elif y == edge_y:
                # Shore edge line (black)
                px(img, x, y, 0)
            else:
                # Water (dark gray)
                if is_dark_gray(x, y):
                    px(img, x, y, 0)
    return img


def make_labwall():
    """Lab wall: light gray base + mortar (wider bricks than regular wall)."""
    img = new_tile(1)
    fill_light_gray(img)
    # Horizontal mortar
    for y in [0, 5, 10, 15]:
        hline(img, 0, 15, y, 0)
    # Staggered vertical mortar (wider bricks)
    vline(img, 8, 1, 4, 0)
    vline(img, 4, 6, 9, 0)
    vline(img, 12, 6, 9, 0)
    vline(img, 8, 11, 14, 0)
    return img


def make_mailbox():
    """Mailbox: white box with black outline on light gray ground + post."""
    img = new_tile(1)
    fill_light_gray(img)
    # Mailbox body (clear to white, then outline)
    fill_rect(img, 4, 3, 11, 8, 1)
    rect(img, 4, 3, 11, 8, 0)
    # Flag
    fill_rect(img, 12, 4, 14, 6, 1)
    rect(img, 12, 4, 14, 6, 0)
    # Post
    vline(img, 7, 9, 14, 0)
    vline(img, 8, 9, 14, 0)
    return img


# ============================================================
# BUILDING TILES (peaked roof edges, windowed walls)
# ============================================================

def make_roof_left():
    """Left peaked roof edge: / diagonal with dark gray roof inside,
    light gray ground outside."""
    img = new_tile(1)
    for y in range(SIZE):
        edge_x = 15 - y  # / diagonal from (15,0) to (0,15)
        for x in range(SIZE):
            if x > edge_x:
                # Inside roof: dark gray + shingle lines
                if is_dark_gray(x, y):
                    px(img, x, y, 0)
                if y % 4 == 3:  # shingle accent
                    px(img, x, y, 0)
            elif x == edge_x:
                # Diagonal edge line (black)
                px(img, x, y, 0)
            else:
                # Outside roof: light gray (ground)
                if is_light_gray(x, y):
                    px(img, x, y, 0)
    return img


def make_roof_right():
    """Right peaked roof edge: \\ diagonal with dark gray roof inside,
    light gray ground outside."""
    img = new_tile(1)
    for y in range(SIZE):
        edge_x = y  # \ diagonal from (0,0) to (15,15)
        for x in range(SIZE):
            if x < edge_x:
                # Inside roof: dark gray + shingle lines
                if is_dark_gray(x, y):
                    px(img, x, y, 0)
                if y % 4 == 3:  # shingle accent
                    px(img, x, y, 0)
            elif x == edge_x:
                # Diagonal edge line (black)
                px(img, x, y, 0)
            else:
                # Outside roof: light gray (ground)
                if is_light_gray(x, y):
                    px(img, x, y, 0)
    return img


def make_wall_window():
    """Brick wall with mullioned window. Light gray brick base,
    white window glass, black frame + mullion cross."""
    img = make_wall()  # Start with wall (has light gray + mortar)
    # Window dimensions (centered)
    wx, wy = 5, 4
    ww, wh = 6, 8
    # Clear area for window glass (pure white)
    fill_rect(img, wx, wy, wx + ww - 1, wy + wh - 1, 1)
    # Window frame (black)
    rect(img, wx, wy, wx + ww - 1, wy + wh - 1, 0)
    # Mullion cross (black)
    hline(img, wx + 1, wx + ww - 2, wy + wh // 2, 0)
    vline(img, wx + ww // 2, wy + 1, wy + wh - 2, 0)
    return img


# ============================================================
# GENERATE ALL TILES
# ============================================================

TILES = [
    ("grass", make_grass),
    ("path", make_path),
    ("wall", make_wall),
    ("water", make_water),
    ("tree", make_tree),
    ("door", make_door),
    ("fence", make_fence),
    ("tallgrass", make_tallgrass),
    ("roof", make_roof),
    ("sign", make_sign),
    ("flowers", make_flowers),
    ("shore", make_shore),
    ("labwall", make_labwall),
    ("mailbox", make_mailbox),
    ("roofleft", make_roof_left),
    ("roofright", make_roof_right),
    ("wallwindow", make_wall_window),
]

if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, fn in TILES:
        img = fn()
        path = os.path.join(OUT_DIR, f"{name}.png")
        img.save(path)
        print(f"  {name}.png ({img.size[0]}x{img.size[1]})")
    print(f"\nGenerated {len(TILES)} tiles in {OUT_DIR}")
