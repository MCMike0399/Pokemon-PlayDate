#!/usr/bin/env python3
"""Validate canonical species-to-battle-asset lookup using the production manifest."""
import argparse
import hashlib
import json
from pathlib import Path
import re

REPO = Path(__file__).resolve().parents[2]


def inspect(source, *, aliases_override=None):
    text = (source / "data/pokemon.lua").read_text()
    # This is a content inventory parser, not a Lua interpreter. Anchor records
    # to the production table's actual species/name/dex schema and fail closed.
    species = re.findall(r'^    ([A-Za-z][A-Za-z0-9_]*) = \{\s*name = "[^"]+", dex = (\d+),', text, re.M)
    dexes = [int(dex) for _, dex in species]
    errors = []
    if len(species) != 151 or sorted(dexes) != list(range(1, 152)):
        errors.append({"reason": "species schema or roster changed", "count": len(species)})
    manifest_path = source / "data/pokemon-art.json"
    if aliases_override is not None:
        aliases = aliases_override
    elif manifest_path.is_file():
        manifest = json.loads(manifest_path.read_text())
        if manifest.get("schema") != 1 or not isinstance(manifest.get("aliases"), dict):
            raise ValueError("invalid production art manifest")
        aliases = manifest["aliases"]
    else:
        aliases = {}
    names = {name for name, _ in species}
    for key, value in aliases.items():
        if key not in names or not isinstance(value, str) or not re.fullmatch(r"[a-z0-9-]+", value):
            errors.append({"reason": "invalid asset alias", "key": key})
    expected = {f"{aliases.get(name, name)}-{view}.png" for name, _ in species for view in ("front", "back")}
    folder = source / "images/pokemon"
    existing = {path.name for path in folder.glob("*.png")}
    for missing in sorted(expected - existing):
        errors.append({"reason": "canonical asset lookup missing", "path": "images/pokemon/" + missing})
    return {"schema": 1, "species": len(species), "expected_assets": len(expected),
            "existing_assets": len(existing), "errors": errors,
            "unreferenced_assets": sorted(existing - expected), "ok": not errors}


def source_files(source):
    paths = [source / "lib/shade.lua", source / "world/tilefactory.lua",
             source / "world/spritefactory.lua", source / "world/player.lua",
             source / "world/zone.lua", source / "data/maps.lua"]
    return paths + sorted((source / "world/sprites").glob("*.lua")) + sorted((source / "images/pokemon").glob("*.png"))


def check_pins(source, pinfile):
    pins = json.loads(pinfile.read_text())
    errors = []
    for item in pins["files"]:
        path = source / item["path"]
        actual = hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None
        if actual != item["sha256"]:
            errors.append({"path": item["path"], "expected": item["sha256"], "actual": actual})
    return {"ok": not errors, "baseline_revision": pins["revision"], "failures": errors}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=REPO / "Source")
    parser.add_argument("--report", type=Path)
    parser.add_argument("--pins", type=Path, help="also check protected source hashes; reports any deliberate migrations")
    args = parser.parse_args()
    result = inspect(args.source)
    if args.pins:
        result["source_preservation"] = check_pins(args.source, args.pins)
        result["ok"] &= result["source_preservation"]["ok"]
    rendered = json.dumps(result, indent=2)
    if args.report:
        args.report.write_text(rendered + "\n")
    print(rendered)
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
