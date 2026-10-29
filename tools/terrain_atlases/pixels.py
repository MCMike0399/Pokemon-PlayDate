"""Previously qualified terrain formula, unchanged from 5a03fc3 render()."""
from tools.generate_kanto_maps import encode_png


def render(rows, policy):
    pixels = []
    for y in range(32):
        line = []
        for x in range(32):
            shade = rows[y // 2][x // 2]
            if shade == '.':
                value = 1
            elif shade == '#':
                value = 0
            else:
                pattern = policy['light' if shade == '1' else 'dark']
                value = (pattern[y % 8] >> (7 - x % 8)) & 1
            line.append(value)
        pixels.append(line)
    return encode_png(pixels, 1)

