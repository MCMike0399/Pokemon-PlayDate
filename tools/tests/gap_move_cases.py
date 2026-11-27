"""Shared runner for the eight pokered move-gap hosts."""

import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(os.environ.get("MOVE_GAP_ROOT", Path(__file__).resolve().parents[2]))
HOST = Path(__file__).resolve().parent / "gap_move_host.lua"


def lua_binary():
    override = os.environ.get("LUA")
    if override:
        return override
    for name in ("lua5.4", "lua"):
        found = shutil.which(name)
        if found:
            return found
    raise AssertionError("Lua 5.4 is required to call the battle host")


def run_case(name):
    completed = subprocess.run(
        [lua_binary(), str(HOST), str(ROOT), name],
        check=False, capture_output=True, text=True)
    if completed.returncode != 0:
        raise AssertionError(completed.stderr or completed.stdout)
    rows = {}
    for line in completed.stdout.splitlines():
        if " " not in line:
            continue
        key, value = line.split(" ", 1)
        rows[key] = value
    return rows


def flag(rows, key):
    return rows[key] == "true"


def number(rows, key):
    return int(rows[key])
