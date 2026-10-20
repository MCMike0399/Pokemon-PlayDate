#!/usr/bin/env python3
"""Build labeled native 400x240 review pages and nearest-neighbor enlargements.

Derived review pages are not baseline approval. Never rewrites source/catalog assets.
"""
import argparse
import json
from pathlib import Path
import sys

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.visual.paths import contained, image_directory
from PIL import Image, ImageDraw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("catalog", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--scale", type=int, default=3)
    args = parser.parse_args()
    if args.scale < 1:
        parser.error("scale must be a positive integer")
    manifest = json.loads((args.catalog / "catalog.json").read_text())
    images = image_directory(args.catalog, manifest)
    args.output.mkdir(parents=True, exist_ok=True)
    groups = {}
    for item in manifest["images"]:
        if item.get("mask"):
            continue
        groups.setdefault(item["category"], []).append(item)
    for category, items in sorted(groups.items()):
        if category in {"map", "map-viewport", "collision", "events", "contact-sheet"}:
            for item in items:
                with Image.open(contained(images, item["path"])) as im:
                    im.resize((im.width*args.scale, im.height*args.scale), Image.Resampling.NEAREST).save(contained(args.output, item["path"]))
            continue
        # 4x2 cells, each 100x120: never resample isolated production assets.
        for page_index in range(0, len(items), 8):
            page = Image.new("RGB", (400, 240), "white")
            draw = ImageDraw.Draw(page)
            for offset, item in enumerate(items[page_index:page_index+8]):
                x, y = offset % 4 * 100, offset // 4 * 120
                with Image.open(contained(images, item["path"])) as source:
                    source = source.convert("RGBA")
                    if source.width > 100 or source.height > 96:
                        raise ValueError(f"asset exceeds native review cell: {item['path']}")
                    page.paste(source, (x + (100-source.width)//2, y), source)
                label = Path(item["path"]).stem
                draw.text((x, y+96), label[:16], fill="black")
                draw.text((x, y+108), label[16:32], fill="black")
            name = f"{category}_{page_index//8+1:03d}"
            page.save(contained(args.output, f"{name}.png"))
            page.resize((400*args.scale, 240*args.scale), Image.Resampling.NEAREST).save(contained(args.output, f"{name}__{args.scale}x.png"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
