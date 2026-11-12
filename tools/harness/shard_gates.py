#!/usr/bin/env python3
"""Run each contract suite and each catalog exporter in its own Simulator.

The 16 MiB pool resets because every shard is a new process. This does not
raise MallocPoolSize, lower a budget, or mark a failure as expected.
"""
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2]
EXPORTERS = ("pewter", "cerulean", "vermilion", "midgame")
REGISTER = re.compile(r'Contracts\.register\("([^"]+)"')


def suite_names():
    text = (PROJECT / "tools/harness/dev_imports.lua").read_text()
    names = REGISTER.findall(text)
    if len(names) != len(set(names)):
        raise SystemExit("duplicate contract suite registration")
    return names


def run_shard(kind, name, output, deadline):
    # run.py creates --output itself and refuses an existing directory.
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        raise SystemExit(f"shard output already exists: {output}")
    if kind == "contracts":
        command = ["contracts", name]
        timeout, ready, frames = "120", "90", "1800"
    else:
        command = ["catalog", name]
        timeout, ready, frames = "600", "180", "18000"
    argv = [
        sys.executable, str(PROJECT / "tools/harness/run.py"),
        "--output", str(output),
        "--timeout", timeout,
        "--ready-timeout", ready,
        "--max-frames", frames,
        *command,
    ]
    env = os.environ.copy()
    env["PLAYDATE_SDK_PATH"] = env.get("PLAYDATE_SDK_PATH") or str(Path.home() / "Developer/PlaydateSDK")
    env["PATH"] = str(Path(env["PLAYDATE_SDK_PATH"]) / "bin") + os.pathsep + env.get("PATH", "")
    env["DISPLAY"] = env.get("DISPLAY") or ":99"
    env["PYTHONPATH"] = str(PROJECT) + os.pathsep + env.get("PYTHONPATH", "")
    log = output.parent / (output.name + ".log")
    started = time.time()
    if deadline is not None and started >= deadline:
        return {"kind": kind, "name": name, "ok": False, "error": "deadline before launch", "output": str(output)}
    with log.open("w") as handle:
        process = subprocess.Popen(argv, cwd=PROJECT, stdout=handle, stderr=subprocess.STDOUT, env=env)
        try:
            code = process.wait(timeout=int(timeout) + int(ready) + 60)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            code = -9
    tail = log.read_text(errors="replace")[-2000:]
    row = {
        "kind": kind, "name": name, "returncode": code, "ok": code == 0,
        "seconds": round(time.time() - started, 1), "output": str(output), "tail": tail,
    }
    if code == 0 and kind == "catalog":
        catalog = output / "catalog.json"
        if not catalog.is_file():
            row["ok"] = False
            row["error"] = "catalog.json missing"
        else:
            data = json.loads(catalog.read_text())
            images = data.get("images") or []
            row["images"] = len(images)
            row["missing"] = len(data.get("missing") or [])
            if not images or row["missing"]:
                row["ok"] = False
                row["error"] = "empty catalog or missing assets"
    return row


def png_hashes(root):
    frames = root / "frames"
    hashes = {}
    if not frames.is_dir():
        return hashes
    for path in sorted(frames.glob("*.png")):
        hashes[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
    return hashes


def compare_catalogs(head_root, main_root):
    report = []
    for name in EXPORTERS:
        head = png_hashes(head_root / f"catalog-{name}")
        main = png_hashes(main_root / f"catalog-{name}")
        only_head = sorted(set(head) - set(main))
        only_main = sorted(set(main) - set(head))
        changed = sorted(path for path in set(head) & set(main) if head[path] != main[path])
        report.append({
            "name": name,
            "ok": not only_head and not only_main and not changed and bool(head),
            "head_images": len(head),
            "main_images": len(main),
            "only_head": only_head[:20],
            "only_main": only_main[:20],
            "changed": changed[:20],
            "only_head_count": len(only_head),
            "only_main_count": len(only_main),
            "changed_count": len(changed),
        })
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--deadline-epoch", type=float, default=None)
    parser.add_argument("--skip-contracts", action="store_true")
    parser.add_argument("--skip-catalog", action="store_true")
    parser.add_argument("--compare", type=Path, help="other shard root to compare catalog PNGs against")
    args = parser.parse_args()
    if args.compare:
        print(json.dumps(compare_catalogs(args.output, args.compare), indent=2))
        return 0
    args.output.mkdir(parents=True, exist_ok=True)
    rows = []
    plan = []
    if not args.skip_catalog:
        plan += [("catalog", name) for name in EXPORTERS]
    if not args.skip_contracts:
        plan += [("contracts", name) for name in suite_names()]
    for index, (kind, name) in enumerate(plan, 1):
        if args.deadline_epoch is not None and time.time() >= args.deadline_epoch:
            rows.append({"kind": kind, "name": name, "ok": False, "error": "not started before deadline"})
            continue
        print(f"[{index}/{len(plan)}] {kind} {name}", flush=True)
        row = run_shard(kind, name, args.output / f"{kind}-{name}", args.deadline_epoch)
        rows.append(row)
        print(f"{kind} {name}: {'PASS' if row.get('ok') else 'FAIL'} {row.get('seconds', '')}", flush=True)
        (args.output / "shards.json").write_text(json.dumps(rows, indent=2))
    failed = [row for row in rows if not row.get("ok")]
    print(f"done {len(rows) - len(failed)}/{len(rows)} green, {len(failed)} red", flush=True)
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
