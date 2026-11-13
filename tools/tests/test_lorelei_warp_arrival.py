"""Bruno's return lands on Lorelei's solid north exit, which pokered allows.

LoadDestinationWarpPosition copies the warp coordinates with no collision test.
CollisionCheckOnLand tests the next tile. Gym block $24 is solid on top and
passable underneath. Sealing every neighbor still fails closed.
"""
import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def lua(value):
    if value is None:
        return 'nil'
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, int) and not isinstance(value, bool):
        return str(value)
    if isinstance(value, str):
        escaped = value.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')
        return '"' + escaped + '"'
    if isinstance(value, list):
        return '{' + ','.join(lua(item) for item in value) + '}'
    if isinstance(value, dict):
        parts = []
        for key, item in value.items():
            parts.append('[' + lua(key) + ']=' + lua(item))
        return '{' + ','.join(parts) + '}'
    raise TypeError(type(value))


PROBE = r'''
dofile("Source/world/sourceMaps.lua")
SourceMaps._withRecords(RECORDS, function()
    local bruno = SourceMaps.descriptor("BrunosRoom")
    for _, index in ipairs({1, 2}) do
        local event = bruno.warps[index]
        local spec = SourceMaps.warpSpec("BrunosRoom", event)
        assert(spec.status == "bound" and spec.arrival_advance == 0, "lorelei return")
        assert(spec.target_name == "LoreleisRoom", spec.target_name)
        local arrival = SourceMaps.descriptor("LoreleisRoom").warps[event.destination.warp_index]
        assert(spec.toX == arrival.x and spec.toY == arrival.y, "arrival stays on the source warp")
        assert(SourceMaps.cell("LoreleisRoom", spec.toX, spec.toY).collision == 1, "exit top stays solid")
        assert(SourceMaps.cell("LoreleisRoom", spec.toX, spec.toY + 1).collision == 0, "south cell is passable")
    end
    local d = SourceMaps._sharedCompact().maps.LoreleisRoom
    local arrival = d.warps[3]
    local function block(x, y)
        if x >= 0 and y >= 0 and x < d.width and y < d.height then
            d.blocked[tostring(y * d.width + x + 1)] = "probe"
        end
    end
    block(arrival.x, arrival.y + 1)
    block(arrival.x, arrival.y - 1)
    block(arrival.x - 1, arrival.y)
    block(arrival.x + 1, arrival.y)
    assert(not pcall(function()
        SourceMaps.warpSpec("BrunosRoom", bruno.warps[1])
    end), "sealed exit must still fail closed")
end)
print("OK")
'''


class LoreleiWarpArrivalTests(unittest.TestCase):
    def test_return_stands_on_the_solid_exit_and_a_sealed_exit_fails(self):
        compact = json.loads((ROOT / 'Source/data/sourceMapCache/compact.json').read_text())
        manifest = json.loads((ROOT / 'Source/data/sourceMaps.json').read_text())
        names = ('BrunosRoom', 'LoreleisRoom')
        tiles = {}
        maps = {}
        for name in names:
            descriptor = compact['maps'][name]
            maps[name] = descriptor
            for key in descriptor['palette']:
                tiles[key] = compact['tiles'][key]
        records = {
            'data/sourceMaps.json': {
                'schema': 1,
                'source_revision': compact['source_revision'],
                'door_tiles': compact['door_tiles'],
                'maps': {name: manifest['maps'][name] for name in names},
            },
            'data/sourceMapCache/compact.json': {
                'schema': 1,
                'source_revision': compact['source_revision'],
                'manifest_sha256': compact['manifest_sha256'],
                'door_tiles': compact['door_tiles'],
                'tiles': tiles,
                'maps': maps,
            },
        }
        script = 'local RECORDS = ' + lua(records) + '\n' + PROBE
        result = subprocess.run(['lua5.4', '-e', script], cwd=ROOT, text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('OK', result.stdout)
