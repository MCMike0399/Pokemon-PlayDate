"""Previously qualified terrain formula, unchanged from 5a03fc3 render().

Optional per-quadrant tones (Source/data/terrainToneOverrides.json) replace the
global light/dark stand-ins for one 16x16 quadrant (one 8x8 source tile).
With tones=None the output is byte-identical to the qualified formula.
"""
from tools.generate_kanto_maps import encode_png


def bit(rows, policy, x, y, tones=None):
    shade = rows[y // 2][x // 2]
    if shade == '.':
        return 1
    if shade == '#':
        return 0
    name = 'light' if shade == '1' else 'dark'
    pattern = policy[name] if tones is None else tones[(y // 16) * 2 + x // 16][name]
    if pattern == 'white':
        return 1
    return (pattern[y % 8] >> (7 - x % 8)) & 1


def render(rows, policy, tones=None):
    return encode_png([[bit(rows, policy, x, y, tones) for x in range(32)] for y in range(32)], 1)
