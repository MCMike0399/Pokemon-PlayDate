#!/usr/bin/env python3
"""Build compact source metadata and a shared grid lookup without Lua or SDK use.

The manifest is the only map inventory and pins the reviewed decoded input bytes.
Generation writes a fresh review directory; --check never repairs its destination.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REVISION = "af519899719f0754965776faac0e836a3b906e6d"
MANIFEST = ROOT / "Source/data/sourceMaps.json"
VOID_KEYS = {"source": "adapter:source:void", "viridian": "adapter:viridian-slice:void", "pewter": "adapter:pewter:void"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def integer(value, low, high):
    return type(value) is int and low <= value <= high


def canonical(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def padding_grid(profile, index):
    return {"id": index, "stable_id": VOID_KEYS[profile], "grid": ["#" * 16] * 16,
            "terrain": {"foot_tile": -1, "land_passable": False, "grass": False,
                        "counter": False, "warp_tile": False, "water_candidate": False,
                        "adapter_padding": True}}


def build(manifest_path=MANIFEST, source_root=ROOT / "Source"):
    manifest_path, source_root = Path(manifest_path), Path(source_root).resolve()
    manifest_bytes = manifest_path.read_bytes()
    manifest = json.loads(manifest_bytes)
    require(manifest.get("schema") == 1 and manifest.get("source_revision") == REVISION,
            "unverified source manifest revision")
    require(isinstance(manifest.get("maps"), dict) and manifest["maps"], "empty source inventory")
    header = {"schema": 1, "source_revision": REVISION,
              "manifest_sha256": hashlib.sha256(manifest_bytes).hexdigest()}
    door_tiles = manifest["door_tiles"]
    require(isinstance(door_tiles, dict) and all(isinstance(name, str) and isinstance(ids, list)
            and all(integer(tile, 0, 255) for tile in ids) for name, ids in door_tiles.items()),
            "invalid shared door tiles")
    compact = dict(header, maps={}, tiles={}, door_tiles=door_tiles)
    atlas = dict(header, tiles={})
    identities, keys = set(), set()
    for name, entry in sorted(manifest["maps"].items()):
        require(entry["profile"] in VOID_KEYS, "unknown binding profile")
        path = (source_root / entry["path"]).resolve()
        require(path.is_relative_to(source_root), "source path escapes input root")
        raw = path.read_bytes()
        require(hashlib.sha256(raw).hexdigest() == entry["source_sha256"], "pinned map checksum differs: " + name)
        definition = json.loads(raw)
        require(definition["schema"] == 1 and definition["source_revision"] == REVISION,
                "unverified decoded map revision: " + name)
        require(definition["name"] == name and definition["id"] == entry["id"], "source identity differs")
        require(entry["id"] not in identities and entry["key"] not in keys, "duplicate source identity")
        identities.add(entry["id"])
        keys.add(entry["key"])
        width, height = definition["dimensions"]["cells"]
        require(integer(width, 1, 4096) and integer(height, 1, 4096), "invalid source dimensions")
        require(entry["width"] == max(width, 13) and entry["height"] == height
                and entry["padding"] == max(0, (13 - width) // 2), "invalid manifest padding")
        grids = copy.deepcopy(definition["grids"])
        for index, grid in enumerate(grids, 1):
            require(grid["id"] == index and isinstance(grid["stable_id"], str), "invalid grid identity")
            require(len(grid["grid"]) == 16 and all(len(row) == 16 and set(row) <= set(".12#")
                    for row in grid["grid"]), "invalid canonical grid")
            require(type(grid["terrain"]["land_passable"]) is bool, "invalid terrain passability")
        require(len(definition["tile_ids"]) == height and len(definition["collision"]) == height,
                "source row count differs")
        if entry["width"] != width:
            grids.append(padding_grid(entry["profile"], len(grids) + 1))
        require(0 < len(grids) <= 255, "compact palette overflow")
        descriptor = {"name": name, "id": entry["id"], "key": entry["key"], "revision": REVISION,
                      "source_sha256": entry["source_sha256"], "source_width": width,
                      "width": entry["width"], "height": height, "padding": entry["padding"],
                      "palette": [grid["stable_id"] for grid in grids], "tile_rows": [], "blocked": {},
                      "source_map_constant": definition["source_map_constant"],
                      "last_outdoor": entry.get("last_outdoor"),
                      "connection_sources": entry.get("connection_sources", {}),
                      "blocked_connections": entry.get("blocked_connections", []),
                      "warps": [], "connections": definition["connections"], "tileset": definition["tileset"]}
        for row, collision in zip(definition["tile_ids"], definition["collision"]):
            require(len(row) == width and len(collision) == width, "source row width differs")
            for tile, solid in zip(row, collision):
                require(integer(tile, 1, len(definition["grids"])), "unknown source tile")
                require(type(solid) is int and solid == int(not grids[tile - 1]["terrain"]["land_passable"]),
                        "source collision differs from terrain")
            padded = [len(grids)] * entry["width"]
            padded[entry["padding"]:entry["padding"] + width] = row
            descriptor["tile_rows"].append("".join(f"{tile:02x}" for tile in padded))
        scripted = set(entry.get("scripted_warps", []))
        require(len(scripted) == len(entry.get("scripted_warps", [])), "duplicate scripted warp")
        blocked = list(entry.get("blocked_events", []))
        available = {item["id"] for item in manifest["maps"].values()}
        for event in definition["events"]["warps"]:
            destination = event["destination"]
            if event["id"] not in scripted and destination["kind"] == "map" and "pokered:" + destination["map"] not in available:
                blocked.append(event["id"])
        require(isinstance(blocked, list) and len(set(blocked)) == len(blocked), "duplicate blocked surface event")
        surfaces, all_events = set(), set()
        for kind, events in definition["events"].items():
            for event in events:
                require(event["id"] not in all_events, "duplicate source event identity")
                all_events.add(event["id"])
                require(integer(event["x"], 0, width - 1) and integer(event["y"], 0, height - 1),
                        "source event outside map")
                if kind in ("warps", "background_events"):
                    surfaces.add(event["id"])
                    if event["id"] in blocked:
                        index = str(event["y"] * entry["width"] + event["x"] + entry["padding"] + 1)
                        require(index not in descriptor["blocked"], "overlapping blocked source surfaces")
                        descriptor["blocked"][index] = event["id"]
                if kind == "warps":
                    warp = copy.deepcopy(event)
                    if entry["padding"] or entry["profile"] == "pewter":
                        warp["source_x"], warp["source_y"] = warp["x"], warp["y"]
                    warp["x"] += entry["padding"]
                    descriptor["warps"].append(warp)
        require(set(blocked) <= surfaces, "unknown blocked surface event")
        require(scripted <= {event["id"] for event in definition["events"]["warps"]}, "unknown scripted warp")
        require(not scripted.intersection(blocked), "scripted warp is also blocked")
        for grid in grids:
            key = grid["stable_id"]
            tile = {"key": key, "grid": grid["grid"], "terrain": grid["terrain"],
                    "collision": int(not grid["terrain"]["land_passable"])}
            require(key not in atlas["tiles"] or atlas["tiles"][key] == tile, "shared source grid differs: " + key)
            atlas["tiles"][key] = tile
            compact["tiles"][key] = {field: value for field, value in tile.items() if field != "grid"}
        compact["maps"][name] = descriptor
    # LAST_MAP is stateful in the source. Infer its ordinary unique OVERWORLD
    # ingress; an ambiguous context requires an explicit manifest override (or
    # ultimately a bespoke runtime script), never a regional Lua name branch.
    for name, descriptor in compact["maps"].items():
        blocked_events = manifest["maps"][name].get("blocked_events", [])
        dynamic = [warp for warp in descriptor["warps"]
                   if warp["destination"]["kind"] == "last_outdoor_map"
                   and warp["id"] not in blocked_events
                   and warp["id"] not in manifest["maps"][name].get("scripted_warps", [])]
        if not dynamic:
            continue
        candidates = set()
        for other_name, other in compact["maps"].items():
            if other["tileset"]["constant"] != "OVERWORLD":
                continue
            for event in dynamic:
                index = event["destination"]["warp_index"]
                if index < 1 or index > len(other["warps"]):
                    continue
                ingress = other["warps"][index - 1]["destination"]
                if ingress.get("map") == descriptor["source_map_constant"]:
                    candidates.add(other_name)
        context = descriptor["last_outdoor"]
        if context is None:
            require(len(candidates) == 1, "LAST_MAP needs explicit manifest context: " + name)
            context = next(iter(candidates))
        require(context in candidates, "LAST_MAP context has no matching source ingress: " + name)
        descriptor["last_outdoor"] = context
    # A warp cannot enter an explicitly closed destination. Project the same
    # return barrier used by SourceMaps.warpSpec into the authoritative surface,
    # so save validation and the live Zone agree on ordinary collision.
    names_by_constant = {d["source_map_constant"]: name for name, d in compact["maps"].items()}
    changed = True
    while changed:
        changed = False
        for descriptor in compact["maps"].values():
            scripted = manifest["maps"][descriptor["name"]].get("scripted_warps", [])
            for warp in descriptor["warps"]:
                if warp["id"] in scripted:
                    continue
                cell = str(warp["y"] * descriptor["width"] + warp["x"] + 1)
                if cell in descriptor["blocked"]:
                    continue
                destination = warp["destination"]
                target_name = (descriptor["last_outdoor"] if destination["kind"] == "last_outdoor_map"
                               else names_by_constant.get(destination["map"]))
                target = compact["maps"].get(target_name)
                if target is None:
                    continue
                arrival = target["warps"][destination["warp_index"] - 1]
                arrival_cell = str(arrival["y"] * target["width"] + arrival["x"] + 1)
                if arrival_cell in target["blocked"]:
                    descriptor["blocked"][cell] = warp["id"]
                    changed = True
    return {"compact.json": canonical(compact), "tile-grids.json": canonical(atlas)}


def check(artifacts, directory):
    directory = Path(directory)
    require(directory.is_dir() and not directory.is_symlink(), "generated directory missing or symlinked")
    require({p.name for p in directory.iterdir()} == set(artifacts), "generated inventory differs")
    for name, expected in artifacts.items():
        path = directory / name
        require(path.is_file() and not path.is_symlink(), "generated artifact missing or symlinked")
        require(path.read_bytes() == expected, "generated artifact drift: " + name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=MANIFEST)
    parser.add_argument("--source-root", type=Path, default=ROOT / "Source")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    artifacts = build(args.manifest, args.source_root)
    if args.check:
        check(artifacts, args.output)
    else:
        require(not args.output.exists(), "fresh generated output directory required")
        args.output.mkdir(parents=True)
        for name, content in artifacts.items():
            (args.output / name).write_bytes(content)
    print("Verified compact source maps:", len(json.loads(artifacts["compact.json"])["maps"]))


if __name__ == "__main__":
    main()
