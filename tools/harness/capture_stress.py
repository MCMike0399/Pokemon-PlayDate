#!/usr/bin/env python3
"""Synthetic SDK capture stress; default compiles only, --execute is root-only.

Repeats the unchanged HarnessCapture.write primitive in two fresh processes.
Only the second arm adds explicit full GC before each extra capture. This is
not campaign proof and does not reproduce accumulated request IDs or filenames.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
from types import SimpleNamespace

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.harness import run as harness
from tools.harness.protocol import atomic_json


def scenario(frames):
    return {
        "synthetic_stress": True,
        "commands": [
            {"op": "fixture", "options": {
                "intro": "skip", "opening": False, "seed": 42,
                "zone": "kanto_pewter_city",
                "entry": {"x": 16, "y": 26, "facing": "right"},
                "player_pokemon": {"species": "charmeleon", "level": 16},
            }},
            "press up", f"wait {max(frames + 2, 12)}",
            {"op": "assert", "path": "player.settled", "equals": True},
            {"op": "assert", "path": "player.x", "equals": 16},
            {"op": "assert", "path": "player.y", "equals": 25},
            "shot synthetic-settled",
        ],
        "outputs": ["synthetic-settled.png"],
    }


def overlay_prepare(original, batch, frames, explicit_gc):
    def prepare(project, sdk, output, session):
        metadata = original(project, sdk, output, session)
        source = output / "Source"
        capture = source / "dev/harness_capture.lua"
        capture.rename(source / "dev/harness_capture_base.lua")
        shutil.copyfile(Path(__file__).with_suffix(".lua"), capture)
        (source / "dev/capture_stress_config.lua").write_text(
            "CaptureStressConfig = { batch = %d, frames = %d, explicit_gc = %s }\n"
            % (batch, frames, "true" if explicit_gc else "false")
        )
        # Preserve the base game fingerprint; identify the private overlay in
        # the handshake and record the exact final compiled tree separately.
        metadata["generated_overlays"] += [
            "Source/dev/harness_capture.lua", "Source/dev/harness_capture_base.lua",
            "Source/dev/capture_stress_config.lua",
        ]
        metadata["capture_stress"] = {
            "synthetic_stress": True, "batch": batch, "frames": frames,
            "extra_captures": batch * frames, "explicit_gc": explicit_gc,
            "base_source_sha256": metadata["source_sha256"],
        }
        pdxinfo = source / "pdxinfo"
        generated_pdxinfo = pdxinfo.read_text()
        pdxinfo.write_text(metadata["original_pdxinfo"])
        metadata["source_sha256"] = harness.fingerprint(output)
        metadata["build_id"] = metadata["revision"] + ":" + metadata["source_sha256"]
        pdxinfo.write_text(generated_pdxinfo)
        values = []
        for key in ("protocol", "session_id", "build_id", "output_dir", "bundle_id",
                    "sdk_version", "enabled", "data_dir"):
            value = metadata[key]
            values.append(f"    {key} = " + ("true" if value is True else json.dumps(value)) + ",")
        (source / "dev/harness_build.lua").write_text(
            "HarnessBuild = {\n" + "\n".join(values) + "\n}\n"
        )
        metadata["compiled_source_sha256"] = harness.fingerprint(output, exclude_generated=False)
        atomic_json(output / "stress-source-manifest.json", {
            str(path.relative_to(source)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(source.rglob("*")) if path.is_file()
        })
        with (output / "stress-build.log").open("w") as log:
            subprocess.run([str(sdk / "bin/pdc"), str(source), metadata["bundle"]],
                           stdout=log, stderr=subprocess.STDOUT, check=True)
        atomic_json(output / "build.json", metadata)
        return metadata
    return prepare


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--sdk")
    parser.add_argument("--batch", type=int, default=256, choices=range(1, 1025), metavar="1..1024")
    parser.add_argument("--frames", type=int, default=16, choices=range(1, 65), metavar="1..64")
    parser.add_argument("--execute", action="store_true", help="root Simulator owner only")
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    output.mkdir(parents=True, exist_ok=False)
    input_path = output / "stress-scenario.json"
    atomic_json(input_path, scenario(args.frames))
    original = harness.prepare
    results = []
    try:
        for name, explicit_gc in [("natural-gc", False), ("explicit-gc", True)]:
            harness.prepare = overlay_prepare(original, args.batch, args.frames, explicit_gc)
            result = harness.run(SimpleNamespace(
                sdk=args.sdk, output=str(output / name), scenario=str(input_path),
                commands=[], build_only=not args.execute, qualification=False,
                timeout=45, ready_timeout=20, max_frames=180,
            ))
            row = {"arm": name, "exit_code": result}
            if args.execute and result == 0:
                progress = json.loads((output / name / "runtime-data/capture-stress.json").read_text())
                row["completed_extra_captures"] = progress["captures"]
                if progress["captures"] != args.batch * args.frames:
                    row.update(exit_code=1, error="stress workload incomplete")
            results.append(row)
    finally:
        harness.prepare = original
        atomic_json(output / "stress-summary.json", {
            "synthetic_stress": True, "execution_requested": args.execute,
            "arms": results, "per_request_timeout_seconds": 45,
        })
    return int(any(result["exit_code"] for result in results))


if __name__ == "__main__":
    raise SystemExit(main())
