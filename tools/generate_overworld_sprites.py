#!/usr/bin/env python3
"""Generate preserved NPC grids from checksum-verified, immutable pokered strips.

Default is preview only. --check compares grid bodies and derived masks without
writing. --write requires explicit intent; --output-dir redirects Lua output.
RED is an intentional hand-tuned exception and is never accepted by this tool.
"""
import argparse
from collections import deque
import hashlib
import io
import json
from pathlib import Path
import re
import sys
import urllib.request
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "tools/references/overworld-sprites.json"
INPUT = ROOT / "tools/references/overworld-sprites"
OUTPUT = ROOT / "Source/world/sprites"
CHARS = {"blue": "rival", "oak": "oak", "mom": "mom", "daisy": "daisy"}
FACINGS = ("down", "up", "left")
MAPS = {
    "faithful": {255: ".", 170: "1", 85: "2", 0: "#"},
    "bw": {255: ".", 170: ".", 85: "#", 0: "#"},
    "greyhair": {255: ".", 170: ".", 85: "2", 0: "#"},
    "outline": {255: ".", 170: ".", 85: ".", 0: "#"},
    "heavy": {255: ".", 170: "#", 85: "#", 0: "#"},
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def load_manifest(path=MANIFEST):
    manifest = json.loads(Path(path).read_text())
    if manifest.get("schema") != 1 or not re.fullmatch(r"[0-9a-f]{40}", manifest.get("commit", "")):
        raise ValueError("invalid pinned source manifest")
    if manifest.get("repository") != "https://github.com/pret/pokered":
        raise ValueError("unexpected sprite source repository")
    entries = manifest.get("characters", {})
    if set(entries) != set(CHARS.values()):
        raise ValueError("manifest must name exactly rival, oak, mom, daisy; RED excluded")
    for source, key in CHARS.items():
        entry = entries[key]
        if entry.get("source") != source + ".png" or entry.get("mapping") not in MAPS:
            raise ValueError(f"invalid source/mapping for {key}")
        if entry.get("size") != [16, 48 if key == "mom" else 96] or entry.get("mode") != "L" or entry.get("palette") != [255, 170, 85, 0]:
            raise ValueError(f"unexpected strip dimensions/mode/palette contract for {key}")
        if entry.get("frames") != {"down": 0, "up": 1, "left": 2}:
            raise ValueError(f"unexpected standing-frame order for {key}")
        if entry.get("mapping") != ("outline" if key == "oak" else "greyhair"):
            raise ValueError(f"manifest changes protected default palette for {key}")
        if not re.fullmatch(r"[0-9a-f]{64}", entry.get("sha256", "")):
            raise ValueError(f"invalid checksum for {key}")
    return manifest


def validate_image(image, entry):
    if image.size != tuple(entry["size"]) or image.width != 16 or image.height < 48 or image.height % 16:
        raise ValueError(f"invalid strip dimensions: {image.size}; expected {entry['size']}")
    if image.mode != entry["mode"]:
        raise ValueError(f"invalid strip mode: {image.mode}; expected {entry['mode']}")
    rgba = image.convert("RGBA")
    colors = set(rgba.getdata())
    expected = {(shade, shade, shade, 255) for shade in entry["palette"]}
    if colors != expected:
        raise ValueError("strip must contain exactly the four pinned opaque grayscale shades")


def load_source(data, entry):
    if digest(data) != entry["sha256"]:
        raise ValueError(f"source checksum mismatch: {entry['source']}")
    with Image.open(io.BytesIO(data)) as image:
        if image.format != "PNG":
            raise ValueError("source must be PNG")
        image.load()
        validate_image(image, entry)
        return image.convert("L")


def frame_to_grid(image, frame, mapping):
    if not isinstance(frame, int) or frame < 0 or (frame + 1) * 16 > image.height:
        raise ValueError("frame index outside source strip")
    image = image.convert("L")
    return ["".join(mapping[image.getpixel((x, frame*16+y))] for x in range(16)) for y in range(16)]


def mask_bytes(grid):
    """Native 32x32 opacity bytes (255 opaque), matching border flood-fill.

    Whiteness alone does not determine opacity: enclosed '.' cells are body.
    The production Lua renderer and exported SDK masks remain the runtime oracle.
    """
    validate_grid(grid)
    outside = set()
    queue = deque()
    def seed(x, y):
        if 0 <= x < 16 and 0 <= y < 16 and (x, y) not in outside and grid[y][x] == ".":
            outside.add((x, y))
            queue.append((x, y))
    for x in range(16):
        seed(x, 0)
        seed(x, 15)
    for y in range(16):
        seed(0, y)
        seed(15, y)
    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            seed(nx, ny)
    return bytes(0 if (x//2, y//2) in outside else 255 for y in range(32) for x in range(32))


def validate_grid(grid):
    if len(grid) != 16 or any(not re.fullmatch(r"[.#12]{16}", row) for row in grid):
        raise ValueError("sprite frame requires 16 rows of 16 . # 1 2 cells")


def parse_grids(text, key):
    # Narrow declarative-format parser, not a Lua transpiler/interpreter.
    text = re.sub(r"--[^\n]*", "", text)
    match = re.fullmatch(r"\s*SpriteFactory\.grids\." + re.escape(key) + r"\s*=\s*\{(.*)\}\s*", text, re.S)
    if not match:
        raise ValueError(f"unexpected sprite declaration for {key}")
    body = match.group(1)
    frames = {}
    pattern = re.compile(r"\s*(\w+)\s*=\s*\{([^{}]*)\}\s*,?", re.S)
    position = 0
    for part in pattern.finditer(body):
        if body[position:part.start()].strip():
            raise ValueError("unparsed sprite data")
        name, rows = part.groups()
        if name not in FACINGS or name in frames:
            raise ValueError(f"unknown or duplicate frame: {name}")
        cells = re.findall(r'"([^"\n]*)"', rows)
        if re.sub(r'"[^"\n]*"|[\s,]', "", rows):
            raise ValueError("unparsed sprite grid row")
        validate_grid(cells)
        frames[name] = cells
        position = part.end()
    if body[position:].strip() or set(frames) != set(FACINGS):
        raise ValueError("expected exactly down/up/left frames")
    return frames


def compare_frames(expected, actual):
    errors = []
    for facing in FACINGS:
        a, b = expected[facing], actual[facing]
        cells = [(x, y) for y in range(16) for x in range(16) if a[y][x] != b[y][x]]
        masks = sum(a != b for a, b in zip(mask_bytes(a), mask_bytes(b)))
        if cells:
            errors.append({"facing": facing, "changed_grid_cells": len(cells),
                           "grid_bbox": [min(x for x,y in cells), min(y for x,y in cells),
                                         max(x for x,y in cells)+1, max(y for x,y in cells)+1],
                           "changed_mask_pixels": masks})
    return errors


def fmt(key, frames, mapping, commit):
    header = (f"-- {key}: generated from pret/pokered {commit}\n"
              f"-- tools/generate_overworld_sprites.py --only {key} --map {mapping}\n"
              "-- Source checksum and frame policy: tools/references/overworld-sprites.json\n"
              "-- Do not hand-edit; RED is excluded from this generator.\n")
    body = []
    for facing in FACINGS:
        body.append("    " + facing + " = {\n" + "\n".join('        "' + row + '",' for row in frames[facing]) + "\n    },")
    return header + "SpriteFactory.grids." + key + " = {\n" + "\n".join(body) + "\n}\n"


def generate(manifest, inputs, selected, override=None):
    result = {}
    for key in selected:
        entry = manifest["characters"][key]
        image = load_source((inputs / entry["source"]).read_bytes(), entry)
        mapping = override or entry["mapping"]
        frames = {facing: frame_to_grid(image, entry["frames"][facing], MAPS[mapping]) for facing in FACINGS}
        result[key] = {"mapping": mapping, "frames": frames,
                       "lua": fmt(key, frames, mapping, manifest["commit"]),
                       "masks": {facing: digest(mask_bytes(grid)) for facing, grid in frames.items()}}
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--map", choices=MAPS, help="intentional palette override; defaults preserve each character")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--write", action="store_true", help="write Lua outputs; never writes RED")
    mode.add_argument("--check", action="store_true", help="compare target grids and derived masks; never write")
    parser.add_argument("--only", help="comma-list from rival,oak,mom,daisy; unknown/empty keys fail")
    parser.add_argument("--output-dir", type=Path, default=OUTPUT, help="target Lua directory for --write/--check")
    parser.add_argument("--input-dir", type=Path, default=INPUT, help="directory of checksum-verified source strips")
    parser.add_argument("--report", type=Path, help="write JSON check/generation report")
    parser.add_argument("--fetch", action="store_true", help="restore pinned source strips from immutable URLs")
    args = parser.parse_args(argv)
    try:
        manifest = load_manifest()
        selected = args.only.split(",") if args.only is not None else list(CHARS.values())
        if not selected or len(selected) != len(set(selected)) or any(key not in CHARS.values() for key in selected):
            raise ValueError("--only must contain unique known NPC keys; RED is never generated")
        if args.fetch:
            if args.check:
                raise ValueError("--check is read-only; --fetch must be a separate invocation")
            downloads = {}
            for key in selected:
                entry = manifest["characters"][key]
                url = f"https://raw.githubusercontent.com/pret/pokered/{manifest['commit']}/gfx/sprites/{entry['source']}"
                data = urllib.request.urlopen(url, timeout=30).read()
                load_source(data, entry)
                downloads[entry["source"]] = data
            args.input_dir.mkdir(parents=True, exist_ok=True)
            for name, data in downloads.items():
                (args.input_dir / name).write_bytes(data)
        generated = generate(manifest, args.input_dir, selected, args.map)
        report = {"ok": True, "commit": manifest["commit"], "characters": {}, "mode": "check" if args.check else "write" if args.write else "preview"}
        # Validate every selected input before any output mutation.
        if args.write:
            args.output_dir.mkdir(parents=True, exist_ok=True)
        for key, item in generated.items():
            record = {"mapping": item["mapping"], "mask_sha256": item["masks"]}
            if args.check:
                actual = parse_grids((args.output_dir / (key + ".lua")).read_text(), key)
                record["differences"] = compare_frames(item["frames"], actual)
                report["ok"] &= not record["differences"]
            elif args.write:
                (args.output_dir / (key + ".lua")).write_text(item["lua"])
            else:
                print(item["lua"])
            report["characters"][key] = record
        if args.report:
            args.report.write_text(json.dumps(report, indent=2) + "\n")
        if args.check or args.write:
            print(json.dumps(report, indent=2))
        return 0 if report["ok"] else 1
    except (OSError, ValueError, KeyError) as error:
        report = {"ok": False, "error": str(error)}
        if args.report:
            args.report.write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps(report), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
