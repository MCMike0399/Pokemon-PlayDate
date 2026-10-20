#!/usr/bin/env python3
"""Trace/protect all 302 battle PNGs; generate candidates only outside Source.

Pinned inputs can be read from an extracted reference tree or the verified
immutable source archive. No network access and no baseline/pin rewrite mode.
"""
import argparse
from collections import Counter
import hashlib
import io
import json
from pathlib import Path
import re
import tarfile
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "tools/references/battle-art.json"
REVISION = "af519899719f0754965776faac0e836a3b906e6d"
PALETTE = {0, 85, 170, 255}
GEOMETRIES = ("native", "crop-black", "crop-center-native", "crop-bottom-native",
              "pad-56-center", "pad-56-bottom", "nearest-2x", "nearest-3x")


def sha(data):
    return hashlib.sha256(data).hexdigest()


class References:
    def __init__(self, manifest, root=None, archive=None):
        if (root is None) == (archive is None):
            raise ValueError("provide exactly one reference root or archive")
        self.root = Path(root).resolve() if root else None
        self.archive = None
        self.prefix = "pokered-" + manifest["revision"] + "/"
        if archive:
            if sha(Path(archive).read_bytes()) != manifest["archive_sha256"]:
                raise ValueError("immutable reference archive checksum mismatch")
            self.archive = tarfile.open(archive, "r:gz")

    def close(self):
        if self.archive:
            self.archive.close()

    def read(self, path):
        relative = Path(path)
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError("reference path escapes root")
        if self.archive:
            member = self.archive.getmember(self.prefix + path)
            if not member.isfile() or member.size > 100000:
                raise ValueError("invalid reference archive member")
            return self.archive.extractfile(member).read()
        full = (self.root / relative).resolve()
        if not full.is_relative_to(self.root):
            raise ValueError("reference symlink escapes root")
        return full.read_bytes()


def load_manifest(path=MANIFEST):
    manifest = json.loads(Path(path).read_text())
    if manifest.get("schema") != 1 or manifest.get("revision") != REVISION:
        raise ValueError("unknown battle art reference schema/revision")
    assets = manifest.get("assets", [])
    if len(assets) != 302 or len({a["asset"] for a in assets}) != 302:
        raise ValueError("battle manifest must cover exactly 302 unique assets")
    if len({a["species"] for a in assets}) != 151:
        raise ValueError("battle manifest must cover all 151 canonical species")
    pins = {entry["path"]: entry for entry in manifest.get("inputs", [])}
    if len(pins) != 455 or len(pins) != len(manifest["inputs"]):
        raise ValueError("expected 455 unique immutable reference pins")
    if manifest.get("default_transform", {}).get("threshold") != 128 or manifest["default_transform"].get("geometry") != "identity":
        raise ValueError("protected transformation policy changed")
    for asset in assets:
        if asset["reference"] not in pins or asset["reference_sha256"] != pins[asset["reference"]]["sha256"]:
            raise ValueError("asset reference pin disagrees with input inventory")
        if asset.get("alternate_reference") and asset["alternate_reference"] not in pins:
            raise ValueError("alternate source pin missing")
        if asset["view"] not in ("front", "back") or not re.fullmatch(r"[a-z0-9-]+-(front|back)\.png", asset["asset"]):
            raise ValueError("invalid battle asset name/view")
    return manifest


def verify_inputs(manifest, references):
    loaded = {}
    for entry in manifest["inputs"]:
        data = references.read(entry["path"])
        if sha(data) != entry["sha256"]:
            raise ValueError("pinned reference checksum mismatch: " + entry["path"])
        if entry.get("kind") == "image":
            with Image.open(io.BytesIO(data)) as image:
                validate_reference(image, entry)
                loaded[entry["path"]] = image.copy()
    return loaded


def validate_reference(image, entry):
    if image.format not in (None, "PNG") or image.mode != "L" or list(image.size) != entry["size"]:
        raise ValueError("unexpected reference format/mode/dimensions")
    if image.width != image.height or image.width not in (32, 40, 48, 56):
        raise ValueError("unexpected reference native canvas")
    if set(image.getdata()) != PALETTE:
        raise ValueError("reference must contain exactly four pinned grayscale shades")


def validate_target(image, asset):
    if image.format != "PNG" or image.mode != "1" or list(image.size) != asset["size"]:
        raise ValueError("protected target mode/dimensions changed: " + asset["asset"])
    if set(image.convert("RGBA").getchannel("A").getdata()) != {255}:
        raise ValueError("protected battle art must remain opaque")


def threshold(image):
    # Native dimensions, opaque canvas. No crop, scale, padding or dither.
    return image.point(lambda value: 255 if value >= 128 else 0, "1")


def binary_variants(image):
    # Complete enumeration of four-shade binary mappings, including inverse
    # and degenerate maps. Input validation guarantees all four shades exist.
    for bits in range(16):
        mapping = {shade: 255 if bits & (1 << index) else 0 for index, shade in enumerate(sorted(PALETTE))}
        yield "palette-" + "".join("1" if mapping[shade] else "0" for shade in sorted(PALETTE)), image.point([mapping.get(value, 0) for value in range(256)], "1")
    yield "floyd-steinberg", image.convert("1", dither=Image.Dither.FLOYDSTEINBERG)
    for matrix in (((0, 2), (3, 1)), ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))):
        side = len(matrix)
        for oy in range(side):
            for ox in range(side):
                out = Image.new("1", image.size)
                out.putdata([255 if image.getpixel((x, y)) * (side*side) >= (matrix[(y+oy)%side][(x+ox)%side] + 0.5)*255 else 0
                             for y in range(image.height) for x in range(image.width)])
                yield f"bayer-{side}-phase-{ox}-{oy}", out


def geometry(image, policy):
    if policy == "native":
        return image
    if policy.startswith("nearest-"):
        factor = int(policy.removeprefix("nearest-").removesuffix("x"))
        return image.resize((image.width*factor, image.height*factor), Image.Resampling.NEAREST)
    if policy.startswith("crop"):
        bbox = ImageChops.invert(image.convert("L")).getbbox()
        cropped = image.crop(bbox) if bbox else Image.new("1", (1, 1), 1)
        if policy == "crop-black":
            return cropped
        canvas = Image.new("1", image.size, 1)
        y = (canvas.height-cropped.height)//2 if policy == "crop-center-native" else canvas.height-cropped.height
        canvas.paste(cropped, ((canvas.width-cropped.width)//2, y))
        return canvas
    if policy in ("pad-56-center", "pad-56-bottom"):
        canvas = Image.new("1", (56, 56), 1)
        y = (56-image.height)//2 if policy == "pad-56-center" else 56-image.height
        canvas.paste(image, ((56-image.width)//2, y))
        return canvas
    raise ValueError("unknown geometry policy")


def decoded_delta(expected, actual):
    if expected.size != actual.size:
        return {"equal": False, "reason": "dimensions", "expected_size": list(expected.size), "actual_size": list(actual.size),
                "changed_pixels": None, "bbox": None}
    a, b = expected.convert("RGBA"), actual.convert("RGBA")
    rgb = ImageChops.difference(a.convert("RGB"), b.convert("RGB"))
    red, green, blue = rgb.split()
    pixel_mask = ImageChops.lighter(ImageChops.lighter(red, green), blue).point(lambda p: 255 if p else 0)
    mask = ImageChops.difference(a.getchannel("A"), b.getchannel("A")).point(lambda p: 255 if p else 0)
    union = ImageChops.lighter(pixel_mask, mask)
    count = union.histogram()[255]
    return {"equal": count == 0, "changed_pixels": count, "bbox": list(union.getbbox()) if count else None,
            "mask_pixels": mask.histogram()[255]}


def safe_output(path, source=None):
    output = Path(path).resolve()
    if output.is_relative_to((ROOT / "Source").resolve()) or source and output.is_relative_to(Path(source).resolve()):
        raise ValueError("candidate output must be outside all production Source")
    return output


def trace(manifest, references, target_root, search=False, output=None):
    images = verify_inputs(manifest, references)
    source = Path(target_root)
    aliases_raw = (source / "data/pokemon-art.json").read_bytes()
    if sha(aliases_raw) != manifest["runtime_aliases_sha256"]:
        raise ValueError("production canonical alias manifest changed; review mapping deliberately")
    aliases = json.loads(aliases_raw)["aliases"]
    results, matrix = [], Counter()
    candidates = {}
    for asset in manifest["assets"]:
        expected_name = aliases.get(asset["species"], asset["species"]) + "-" + asset["view"] + ".png"
        if expected_name != asset["asset"]:
            raise ValueError("runtime alias mapping disagrees with pinned asset inventory")
        target_path = source / "images/pokemon" / asset["asset"]
        target_bytes = target_path.read_bytes()
        with Image.open(io.BytesIO(target_bytes)) as target:
            validate_target(target, asset)
            target = target.copy()
        candidate = threshold(images[asset["reference"]])
        delta = decoded_delta(target, candidate)
        record = {"species": asset["species"], "view": asset["view"], "asset": asset["asset"],
                  "reference": asset["reference"], "reference_sha256": asset["reference_sha256"],
                  "protected_bytes_unchanged": sha(target_bytes) == asset["sha256"], "direct": delta}
        if search:
            exact = []
            variants = [asset["reference"]] + ([asset["alternate_reference"]] if asset.get("alternate_reference") else [])
            for reference in variants:
                for palette, binary in binary_variants(images[reference]):
                    for policy in GEOMETRIES:
                        actual = geometry(binary, policy)
                        comparison = decoded_delta(target, actual)
                        profile = f"{Path(reference).parent.name}/{palette}/{policy}"
                        if comparison["equal"]:
                            exact.append(profile)
                            matrix[(profile, "exact")] += 1
                        elif comparison.get("reason") == "dimensions":
                            matrix[(profile, "dimensions")] += 1
                        else:
                            matrix[(profile, "pixels")] += 1
            record["exact_search_profiles"] = exact
            if asset.get("alternate_reference"):
                record["alternate_direct"] = decoded_delta(target, threshold(images[asset["alternate_reference"]]))
        results.append(record)
        candidates[asset["asset"]] = candidate
    # Validate the complete inventory and all inputs before publishing candidates.
    if output:
        output = safe_output(output, source)
        output.mkdir(parents=True, exist_ok=False)
        for name, candidate in candidates.items():
            candidate.save(output / name)
    return {"schema": 1, "revision": manifest["revision"], "assets": len(results),
            "exact": sum(r["direct"]["equal"] for r in results),
            "protected_files_unchanged": sum(r["protected_bytes_unchanged"] for r in results),
            "ok": all(r["direct"]["equal"] and r["protected_bytes_unchanged"] for r in results),
            "transformation": "native opaque threshold128: 0/85 black,170/255 white", "results": results,
            "search": [{"profile": profile, "outcome": outcome, "count": count} for (profile, outcome), count in sorted(matrix.items())]}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    inputs = parser.add_mutually_exclusive_group(required=True)
    inputs.add_argument("--reference-root", type=Path)
    inputs.add_argument("--archive", type=Path)
    parser.add_argument("--source", type=Path, default=ROOT / "Source")
    parser.add_argument("--check", action="store_true", help="read-only preservation/reproduction check")
    parser.add_argument("--search", action="store_true", help="measure all palette/dither/geometry/reference profiles")
    parser.add_argument("--output", type=Path, help="explicit NEW candidate directory, outside Source")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args(argv)
    reader = None
    try:
        if args.check and args.output:
            raise ValueError("--check cannot write candidates")
        report_path = safe_output(args.report, args.source) if args.report else None
        if args.output:
            safe_output(args.output, args.source)
        manifest = load_manifest()
        reader = References(manifest, args.reference_root, args.archive)
        report = trace(manifest, reader, args.source, args.search, args.output)
        if report_path:
            report_path.write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({key: report[key] for key in ("ok", "assets", "exact", "protected_files_unchanged", "revision")}, indent=2))
        return 0 if report["ok"] else 1
    except (OSError, ValueError, KeyError, tarfile.TarError) as error:
        print(json.dumps({"ok": False, "error": str(error)}))
        return 1
    finally:
        if reader:
            reader.close()


if __name__ == "__main__":
    raise SystemExit(main())
