#!/usr/bin/env python3
"""Deterministic English pokered charset/fallback projection; no Lua execution."""
import argparse
import hashlib
import json
import re
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / 'tools/references/source-text'
OUTPUT = ROOT / 'Source/data/sourceText.json'
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'

def build():
    manifest = json.loads((REFERENCE / 'manifest.json').read_text())
    if manifest['revision'] != REVISION:
        raise ValueError('source text revision mismatch')
    for name, digest in manifest['files'].items():
        if hashlib.sha256((REFERENCE / name).read_bytes()).hexdigest() != digest:
            raise ValueError('source text reference checksum mismatch: ' + name)
    english = (REFERENCE / 'constants/charmap.asm').read_text().split('; Japanese kana,')[0]
    rows = re.findall(r'^\s*charmap "([^"]+)",\s*\$([0-9a-f]+)', english, re.M)
    tokens = [s for s, _ in rows if s.startswith('<')]
    literals = [s for s, _ in rows if not s.startswith('<')]
    glyphs = {}
    for char, code in rows:
        if len(char) != 1 or ord(char) < 128:
            continue
        code = int(code, 16)
        if char == '▲':
            path, index = 'gfx/town_map/up_arrow.png', 0
        elif char in '′″':
            path, index = 'gfx/pokedex/pokedex.png', code - 0x60
        elif char in '『№':
            path, index = 'gfx/font/font_battle_extra.png', code - 0x62
        elif code < 0x80:
            path, index = 'gfx/font/font_extra.png', code - 0x60
        else:
            path, index = 'gfx/font/font.png', code - 0x80
        image = Image.open(REFERENCE / path).convert('L')
        x, y = (index % (image.width // 8)) * 8, (index // (image.width // 8)) * 8
        assert y + 8 <= image.height
        grid = [''.join('#' if image.getpixel((x+i, y+j)) < 128 else '.' for i in range(8)) for j in range(8)]
        glyphs[char] = {'rows': grid, 'source': path, 'tile': index}
    return {'schema': 1, 'source_revision': REVISION, 'tokens': tokens, 'literals': literals, 'glyphs': glyphs}

def encoded():
    return json.dumps(build(), ensure_ascii=False, indent=2) + '\n'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    data = encoded()
    if args.check:
        if OUTPUT.read_text() != data:
            raise SystemExit('source text projection drift')
    elif args.output:
        args.output.write_text(data)
    else:
        parser.error('choose --check or --output (explicit candidate destination)')
if __name__ == '__main__':
    main()
