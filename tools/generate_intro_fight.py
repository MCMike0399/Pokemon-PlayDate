#!/usr/bin/env python3
"""Compose Blue's intro fight from the pinned four-shade sheets.

pret/pokered af519899 engine/movie/intro.asm. Gengar is gfx/intro/gengar.png
read in columns, then tools/gfx --remove-duplicates --preserve=0x19,0x76.
IntroCopyTiles places gengar_1/2/3.tilemap at hlcoord 13, 7, 7 by 7.
Jigglypuff's PNGs are already the pictures (the --columns flag only orders
the 2bpp). rBGP, rOBP0 and rOBP1 are ldpal SHADE_BLACK, SHADE_DARK,
SHADE_LIGHT, SHADE_WHITE (0xE4). SET_PAL_NIDORINO_INTRO is SGB-only.
Tile 0 is the cleared field (color 0, white). Tile 1 is the solid bar
(color 3, black). Shades are the approved phase-(0, 0) Bayer patterns.
"""
import hashlib
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Source/images/title/intro"
COL, ROW = 20, 13
# Same bytes as Source/lib/shade.lua. 1 is white, 0 is black, MSB first.
LIGHT = (0x55, 0xBB, 0x55, 0xFF, 0x55, 0xBB, 0x55, 0xFF)
DARK = (0x00, 0xAA, 0x44, 0xAA, 0x00, 0xAA, 0x44, 0xAA)
GRAY = {255: 0, 170: 1, 85: 2, 0: 3}
PRESERVE = (0x19, 0x76)
GENGAR_ORIGIN = (13 * COL, 7 * ROW)
JIGGLY_ORIGIN = (9 * COL, 9 * ROW)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def colors(image):
    if image.mode != "L" or set(image.get_flattened_data()) - set(GRAY):
        raise ValueError("intro sheet must be the four DMG grays")
    return [GRAY[value] for value in image.get_flattened_data()]


def tile_bytes(tile):
    raw = bytearray()
    for y in range(8):
        low = high = 0
        for x in range(8):
            color = tile[y * 8 + x]
            bit = 7 - x
            low |= (color & 1) << bit
            high |= ((color >> 1) & 1) << bit
        raw.append(low)
        raw.append(high)
    return bytes(raw)


def column_tiles(image):
    width, height = image.width // 8, image.height // 8
    if image.width % 8 or image.height % 8:
        raise ValueError("intro sheet is not an 8px tile grid")
    pixels = colors(image)
    tiles = []
    stride = image.width
    for column in range(width):
        for row in range(height):
            tile = []
            for y in range(8):
                start = (row * 8 + y) * stride + column * 8
                tile.extend(pixels[start:start + 8])
            tiles.append(tile)
    return tiles


def dedup(tiles, preserved=PRESERVE):
    """tools/gfx.c remove_duplicates, including the preserve shift."""
    raw = bytearray(b"".join(tile_bytes(tile) for tile in tiles))
    preserved = list(preserved)
    tile_size = 16

    def kept(index):
        return index in preserved

    def shift(removed):
        for index, value in enumerate(preserved):
            if value >= removed:
                preserved[index] = value - 1

    def exists(offset, count):
        tile = raw[offset:offset + tile_size]
        for index in range(count):
            if raw[index * tile_size:(index + 1) * tile_size] == tile:
                return True
        return False

    count = 0
    i = j = d = 0
    size = len(raw)
    while i < size and j < size:
        while j < size and exists(j, count):
            index = j // tile_size - d
            if kept(index):
                break
            shift(index)
            j += tile_size
            d += 1
        if j >= size:
            break
        if j > i:
            raw[i:i + tile_size] = raw[j:j + tile_size]
        count += 1
        i += tile_size
        j += tile_size
    bank = []
    for index in range(count):
        chunk = bytes(raw[index * tile_size:(index + 1) * tile_size])
        tile = []
        for row in range(8):
            low, high = chunk[row * 2], chunk[row * 2 + 1]
            for bit in range(7, -1, -1):
                tile.append(((high >> bit) & 1) << 1 | ((low >> bit) & 1))
        bank.append(tile)
    return bank


def tilemap(path):
    raw = Path(path).read_bytes()
    if len(raw) != 49:
        raise ValueError("gengar tilemap is 7 by 7")
    return list(raw)


def compose(bank, mapping):
    picture = []
    for index in mapping:
        if index >= len(bank):
            raise ValueError("tilemap index is outside the deduped bank")
        picture.append(bank[index])
    return picture


def shade_bit(pattern, x, y):
    byte = pattern[y % 8]
    return (byte >> (7 - (x % 8))) & 1


def paint(tiles, columns, origin, scale_box):
    """Nearest-scale each tile into the 20 by 13 cell and dither."""
    rows = len(tiles) // columns
    width, height = columns * COL, rows * ROW
    image = Image.new("1", (width, height), 1)
    pixels = image.load()
    ox, oy = origin
    box_w, box_h = scale_box
    for index, tile in enumerate(tiles):
        col, row = index % columns, index // columns
        for y in range(box_h):
            sy = y * 8 // box_h
            for x in range(box_w):
                sx = x * 8 // box_w
                color = tile[sy * 8 + sx]
                px, py = col * box_w + x, row * box_h + y
                if color == 0:
                    bit = 1
                elif color == 3:
                    bit = 0
                else:
                    bit = shade_bit(LIGHT if color == 1 else DARK, ox + px, oy + py)
                pixels[px, py] = bit
    return image


def gengar_frames(reference):
    root = Path(reference)
    sheet = Image.open(root / "gfx/intro/gengar.png").convert("L")
    bank = dedup(column_tiles(sheet))
    if tile_bytes(bank[0]) != bytes(16) or set(bank[1]) != {3}:
        raise ValueError("tile 0 must be the blank field and tile 1 the black bar")
    frames = {}
    for name in ("gengar_1", "gengar_2", "gengar_3"):
        frames[name] = paint(compose(bank, tilemap(root / "gfx/intro" / (name + ".tilemap"))),
                             7, GENGAR_ORIGIN, (COL, ROW))
    return frames


def jiggly_frames(reference):
    root = Path(reference)
    frames = {}
    sources = {
        "fight_jiggly_1": "blue_jigglypuff_1",
        "fight_jiggly_2": "blue_jigglypuff_2",
        "fight_jiggly_3": "blue_jigglypuff_3",
    }
    for name, source in sources.items():
        image = Image.open(root / "gfx/intro" / (source + ".png")).convert("L")
        if image.size != (48, 48):
            raise ValueError("jigglypuff sheet is the 6 by 6 picture")
        # The PNG is the picture. --columns orders the 2bpp, not the pixels.
        tiles = []
        pixels = colors(image)
        for row in range(6):
            for col in range(6):
                tile = []
                for y in range(8):
                    start = (row * 8 + y) * 48 + col * 8
                    tile.extend(pixels[start:start + 8])
                tiles.append(tile)
        frames[name] = paint(tiles, 6, JIGGLY_ORIGIN, (COL, ROW))
    return frames


def build(reference, output=OUT):
    frames = {}
    frames.update(gengar_frames(reference))
    frames.update(jiggly_frames(reference))
    output.mkdir(parents=True, exist_ok=True)
    written = {}
    for name, image in frames.items():
        target = output / (name + ".png")
        image.save(target)
        written[name] = sha(target.read_bytes())
    return written


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference-root", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, default=OUT)
    args = parser.parse_args()
    for name, digest in build(args.reference_root, args.output_dir).items():
        print(f"{name} {digest}")


if __name__ == "__main__":
    main()
