#!/usr/bin/env python3
"""Exact decoded pixel AND alpha comparison; no baseline-writing operation."""
import argparse
import json
from pathlib import Path
import sys

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.visual.paths import contained, image_directory
from PIL import Image, ImageChops


def compare_image(expected, actual, diff_path=None):
    with Image.open(expected) as image:
        before = image.convert("RGBA")
    with Image.open(actual) as image:
        after = image.convert("RGBA")
    result = {"expected": str(expected), "actual": str(actual), "equal": False}
    if before.size != after.size:
        return result | {"reason": "dimensions", "expected_size": before.size, "actual_size": after.size}
    pixel_diff = ImageChops.difference(before.convert("RGB"), after.convert("RGB"))
    # Count changed pixels, not changed channels. Test alpha separately: converting
    # to RGB or compositing on white alone would hide transparency regressions.
    rgb = pixel_diff.convert("RGB")
    pixel_mask = Image.new("L", before.size)
    pixel_mask.putdata([255 if any(p) else 0 for p in rgb.getdata()])
    alpha_diff = ImageChops.difference(before.getchannel("A"), after.getchannel("A"))
    alpha_mask = alpha_diff.point(lambda p: 255 if p else 0)
    union = ImageChops.lighter(pixel_mask, alpha_mask)
    pixel_count = sum(p != 0 for p in pixel_mask.getdata())
    alpha_count = sum(p != 0 for p in alpha_mask.getdata())
    changed = sum(p != 0 for p in union.getdata())
    result |= {"equal": changed == 0, "changed_pixels": changed, "rgb_pixels": pixel_count,
               "alpha_pixels": alpha_count, "bbox": union.getbbox(),
               "rgb_bbox": pixel_mask.getbbox(), "alpha_bbox": alpha_mask.getbbox()}
    if diff_path and changed:
        Path(diff_path).parent.mkdir(parents=True, exist_ok=True)
        overlay = before.convert("RGB")
        overlay.paste((255, 0, 255), mask=union)
        overlay.save(diff_path)
        result["diff"] = str(diff_path)
    return result


def compare_catalog(expected, actual, diff_dir=None, *, protected_preservation=False):
    expected, actual = Path(expected), Path(actual)
    before = json.loads((expected / "catalog.json").read_text())
    after = json.loads((actual / "catalog.json").read_text())
    expected_images, actual_images = image_directory(expected, before), image_directory(actual, after)
    def paths(manifest, root):
        values = [item["path"] for item in manifest["images"]]
        if not values or len(values) != len(set(values)):
            raise ValueError("empty or duplicate image inventory")
        for path in values:
            contained(root, path)
        return set(values)
    a, b = paths(before, expected_images), paths(after, actual_images)
    before_entries = {item["path"]: item for item in before["images"]}
    after_entries = {item["path"]: item for item in after["images"]}
    results = []
    for path in sorted(a | b):
        if path not in a or path not in b:
            results.append({"path": path, "equal": False, "reason": "inventory", "expected": path in a, "actual": path in b})
        elif not contained(expected_images, path).is_file() or not contained(actual_images, path).is_file():
            results.append({"path": path, "equal": False, "reason": "missing file"})
        elif protected_preservation and any(before_entries[path].get(field) != after_entries[path].get(field)
                                               for field in ("mask", "category", "width", "height") if field in before_entries[path]):
            results.append({"path": path, "equal": False, "reason": "protected metadata"})
        else:
            diff_path = Path(diff_dir) / path if diff_dir else None
            results.append({"path": path} | compare_image(contained(expected_images, path), contained(actual_images, path), diff_path))
    missing_equal = before.get("missing", []) == after.get("missing", [])
    report = {"equal": all(r["equal"] for r in results) and missing_equal,
              "missing_inventory_equal": missing_equal, "checked": len(results),
              "failures": [r for r in results if not r["equal"]]}
    if protected_preservation:
        added = sorted(b - a)
        failures = [r for r in results if r["path"] in a and not r["equal"]]
        added_failures = []
        for path in added:
            try:
                filename = contained(actual_images, path)
                with Image.open(filename) as image:
                    if image.format != "PNG":
                        raise ValueError("added artifact must be PNG")
                    size = image.size
                    image.verify()
                item = after_entries[path]
                for axis, field in enumerate(("width", "height")):
                    if field in item and item[field] != size[axis]:
                        raise ValueError("added artifact dimensions disagree with manifest")
            except (OSError, ValueError) as error:
                added_failures.append({"path": path, "equal": False, "reason": "invalid unreviewed file", "error": str(error)})
        protected_equal = not failures and missing_equal
        report.update(mode="protected-preservation", protected_equal=protected_equal,
                      protected_checked=len(a), added_unreviewed=added,
                      added_files_valid=not added_failures, failures=failures + added_failures,
                      comparison_ok=protected_equal and not added_failures,
                      review_complete=not added and protected_equal)
        # Additions are never promoted to reviewed equality by this mode.
        report["equal"] = protected_equal and not added
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("expected", type=Path)
    parser.add_argument("actual", type=Path)
    parser.add_argument("--diff-dir", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--protected-preservation", action="store_true", help="check protected subset; added files remain explicitly unreviewed")
    args = parser.parse_args()
    try:
        if args.expected.is_dir() and args.actual.is_dir():
            report = compare_catalog(args.expected, args.actual, args.diff_dir, protected_preservation=args.protected_preservation)
        else:
            if args.protected_preservation:
                raise ValueError("protected preservation requires two catalog directories")
            report = compare_image(args.expected, args.actual, args.diff_dir / "diff.png" if args.diff_dir else None)
    except (OSError, ValueError, KeyError) as error:
        report = {"equal": False, "error": str(error)}
    rendered = json.dumps(report, indent=2)
    if args.report:
        args.report.write_text(rendered + "\n")
    print(rendered)
    return 0 if report.get("comparison_ok", report["equal"]) else 1


if __name__ == "__main__":
    raise SystemExit(main())
