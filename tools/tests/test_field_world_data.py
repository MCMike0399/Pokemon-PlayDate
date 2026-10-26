"""Primary pins and returned boundary schema only; no Lua/SDK emulation."""
import ast
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from tools.harness.protocol import ProtocolError

ROOT = Path(__file__).resolve().parents[2]
PACKET = ROOT / 'docs/implementation/field-world-owner'
PRIMARY = ROOT / 'tools/references/field-moves'


class FieldWorldDataTests(unittest.TestCase):
    def test_consumed_primary_sources_remain_pinned(self):
        pins = json.loads((PRIMARY / 'pins.json').read_text())
        self.assertEqual(pins['source_revision'], 'af519899719f0754965776faac0e836a3b906e6d')
        for name in ('home/overworld.asm', 'home/fade.asm', 'engine/menus/save.asm',
                     'ram/wram.asm', 'engine/events/black_out.asm', 'engine/menus/start_sub_menus.asm'):
            raw = (PRIMARY / 'pokered' / name).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(), pins['pokered'][name])
        overworld = (PRIMARY / 'pokered/home/overworld.asm').read_text()
        self.assertIn('LoadTileBlockMap::', overworld)
        self.assertIn('cp ROCK_TUNNEL_1F\n\tjr nz, .notRockTunnel\n\tld a, $06\n\tld [wMapPalOffset], a', overworld)
        self.assertIn('HandleFlyWarpOrDungeonWarp::', overworld)
        self.assertIn('cp LAST_MAP', overworld)
        ram = (PRIMARY / 'pokered/ram/wram.asm').read_text()
        self.assertLess(ram.index('wMainDataStart'), ram.index('wMapPalOffset::'))
        self.assertLess(ram.index('wMapPalOffset::'), ram.index('wMainDataEnd'))

    def test_new_owner_schema_is_explicit_and_bounded(self):
        schema = json.loads((PACKET / 'field-world.schema.json').read_text())
        self.assertFalse(schema['additionalProperties'])
        self.assertEqual(set(schema['required']), {'version', 'mapPalOffset'})
        self.assertEqual(schema['properties']['version'], {'const': 1})
        self.assertEqual(schema['properties']['mapPalOffset'], {'type': 'integer', 'enum': [0, 6]})

    def boundary_validator(self):
        # Apply the returned patch to a private copy, leaving the active driver
        # alone. Only its Python envelope-schema function is evaluated.
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / 'tools/harness/cerulean_journey.py'
            target.parent.mkdir(parents=True)
            target.write_bytes((ROOT / 'tools/harness/cerulean_journey.py').read_bytes())
            subprocess.run(['git', 'apply', str(PACKET / 'host-boundary.patch')], cwd=tmp, check=True)
            tree = ast.parse(target.read_text())
        nodes = [n for n in tree.body if
                 (isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'CODEC_FIELDS' for t in n.targets))
                 or (isinstance(n, ast.FunctionDef) and n.name == 'validate_boundary_payload')]
        namespace = {'ProtocolError': ProtocolError}
        exec(compile(ast.Module(body=nodes, type_ignores=[]), '<returned-schema-patch>', 'exec'), namespace)
        return namespace

    def test_returned_host_patch_accepts_both_envelopes_and_rejects_invalid_field_data(self):
        ns = self.boundary_validator()
        check = ns['validate_boundary_payload']
        old = {key: {} for key in ns['CODEC_FIELDS']}
        old.update(version=1, pokemonEncoding='decimal-counters-v1')
        check(old)
        current = dict(old, version=2, fieldWorld={'version': 1, 'mapPalOffset': 6})
        check(current)
        for field in (None, {}, {'version': 1, 'mapPalOffset': True},
                      {'version': 2, 'mapPalOffset': 0}, {'version': 1, 'mapPalOffset': 7},
                      {'version': 1, 'mapPalOffset': 0, 'epoch': 1}):
            with self.subTest(field=field), self.assertRaises(ProtocolError):
                check(dict(current, fieldWorld=field))
        for invalid in (dict(old, fieldWorld=current['fieldWorld']), dict(old, version=2),
                        dict(current, version=3)):
            with self.assertRaises(ProtocolError):
                check(invalid)


if __name__ == '__main__':
    unittest.main()
