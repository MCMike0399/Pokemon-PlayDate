"""Use real pdc outputs to qualify the production/harness compile boundary."""
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import tempfile
import unittest
import zlib

from tools.tests.host_fixtures import installed_map_names
from tools import build
from tools.harness import run, startup_probe
from tools.harness.build import overlay_imports

PROJECT = Path(__file__).resolve().parents[2]
# Use checkpoint A's existing frozen import contract without rewriting main's baseline.
BASELINE = json.loads(subprocess.check_output([
    'git', '-C', str(PROJECT), 'show',
    '93d480b77f3d231c7c806cf57f71c5e064fba3f0:tools/tests/fixtures/dev-import-gate.json',
]))


def pdz_modules(path):
    """Read SDK 3.1.2 compressed PDZ records, validating each Lua payload."""
    data = path.read_bytes()
    if data[:16] != b'Playdate PDZ\0\0\0\0':
        raise AssertionError('unexpected PDZ format')
    offset, modules = 16, []
    while offset < len(data):
        word = struct.unpack_from('<I', data, offset)[0]
        if word & 255 != 0x81:
            raise AssertionError('unexpected PDZ record flags')
        end = data.index(0, offset + 4)
        modules.append(data[offset + 4:end].decode())
        start = (end + 4) & ~3
        size = word >> 8
        lua = zlib.decompress(data[start + 4:start + size])
        if len(lua) != struct.unpack_from('<I', data, start)[0] or not lua.startswith(b'\x1bLua'):
            raise AssertionError('invalid compiled Lua payload')
        offset = start + size
    if offset != len(data):
        raise AssertionError('truncated PDZ')
    return modules


class ProductionBuildTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix='pokemon-build-test-')
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.root = Path(cls.temporary.name)
        cls.sdk = run.sdk_path()
        cls.production = cls.root / 'production'
        cls.production.mkdir()
        cls.bundle = cls.root / 'Game.pdx'
        # A stale development artifact from a previous build must disappear.
        (cls.bundle / 'dev').mkdir(parents=True)
        (cls.bundle / 'dev/stale.pdz').write_bytes(b'stale')
        build.compile_production(PROJECT, cls.sdk, cls.bundle, cls.production)
        cls.harness = cls.root / 'harness'
        cls.harness.mkdir()
        cls.metadata = run.prepare(PROJECT, cls.sdk, cls.harness, 'compile-only-test')

    def test_production_compiled_inventory_excludes_all_dev_modules(self):
        self.assertFalse((self.production / 'Source/dev').exists())
        modules = pdz_modules(self.bundle / 'main.pdz')
        self.assertFalse(any(name.startswith('dev/') for name in modules))
        self.assertFalse((self.bundle / 'dev').exists())
        for name in ('game/titleState', 'game/itemPCState', 'domain/fieldEncounters', 'main'):
            self.assertIn(name, modules)

    def test_harness_compiled_inventory_keeps_every_original_dev_import(self):
        modules = pdz_modules(self.harness / 'Harness.pdx/main.pdz')
        expected = [name for name in BASELINE['imports'] if name.startswith('dev/')]
        # Explicitly reviewed helpers imported by the catalog and event suites.
        transitive = {'dev/catalogRuntime', 'dev/sourceEventBaseline', 'dev/importedToneReference',
                      'dev/sessionFixture'}
        self.assertTrue(transitive <= set(modules))
        self.assertEqual([name for name in modules if name.startswith('dev/') and name not in transitive],
                         ['dev/harness_build'] + [name for name in expected if name not in {'dev/harness_build', 'game/bootstrap'} and name not in transitive])
        staged = (self.harness / 'Source/main.lua').read_text()
        package = staged.index('CeruleanContent.registerPackage("vermilion",')
        exporter = staged.index('VermilionCatalogExporter.register()')
        context = staged.index('game = GameContext(')
        self.assertLess(package, exporter)
        self.assertLess(exporter, context)
        imports = re.findall(r'^[ \t]*import "([^"]+)"$', staged, re.M)
        # 80a9419 introduced the loading bootstrap; 91d3769 moved it before
        # the SDK imports and added boot tracing. Retain the frozen inventory
        # and permit only these two reviewed additions in their required order.
        self.assertEqual(imports, ['dev/harness_build', 'game/bootTrace', 'game/bootstrap']
                         + [name for name in BASELINE['imports'] if name not in {'dev/harness_build', 'game/bootstrap'}])
        self.assertEqual([line.strip() for line in staged.splitlines() if line.lstrip().startswith('Contracts.register(')
                          or line.lstrip().startswith('PewterCatalogExporter.register(')
                          or line.lstrip().startswith('CeruleanCatalogExporter.register(')
                          or line.lstrip().startswith('VermilionCatalogExporter.register(')], BASELINE['registrations'])

    def test_staging_preserves_every_non_entry_source_asset(self):
        policy = BASELINE['checkpoint_a']
        self.assertEqual(build.production_exclusions(PROJECT), policy['exclude'])
        active = json.loads((PROJECT / 'Source/data/sourceMaps.json').read_bytes())
        self.assertEqual(set(active['maps']), installed_map_names())
        for name in policy['exclude']:
            self.assertFalse((self.production / 'Source' / name).exists(), name)
        for name in policy['retain_shared_dependencies']:
            self.assertEqual((PROJECT / 'Source' / name).read_bytes(),
                             (self.production / 'Source' / name).read_bytes(), name)
        proposals = {'proposed-source-maps.json', 'proposed-compact.json', 'proposed-tile-grids.json'}
        for original in (PROJECT / 'Source').rglob('*'):
            if not original.is_file():
                continue
            relative = original.relative_to(PROJECT / 'Source')
            name = relative.as_posix()
            excluded = relative.parts[0] == 'dev' or relative.name in proposals or any(
                name == entry.rstrip('/') or entry.endswith('/') and name.startswith(entry)
                for entry in policy['exclude'])
            if excluded:
                self.assertFalse((self.production / 'Source' / relative).exists(), name)
            else:
                self.assertEqual(original.read_bytes(), (self.production / 'Source' / relative).read_bytes())
            if str(relative) not in ('main.lua', 'pdxinfo', 'dev/harness_build.lua'):
                self.assertEqual(original.read_bytes(), (self.harness / 'Source' / relative).read_bytes())
        self.assertEqual(self.metadata['compiled_source_sha256'], run.fingerprint(self.harness, exclude_generated=False))
        manifest = json.loads((self.harness / 'source-manifest.json').read_text())
        self.assertEqual(manifest['main.lua'], hashlib.sha256((PROJECT / 'Source/main.lua').read_bytes()).hexdigest())

    def test_startup_baseline_retains_dev_and_identifies_the_original_source(self):
        output = self.root / 'legacy-startup-probe'
        metadata = startup_probe.prepare(PROJECT, self.sdk, output, 'legacy-probe-test', 'legacy-production')
        self.assertTrue((output / 'Source/dev').is_dir())
        self.assertTrue((Path(metadata['bundle']) / 'dev').is_dir())
        self.assertEqual(metadata['source_sha256'], run.fingerprint(PROJECT))
        self.assertEqual(metadata['compiled_source_sha256'], run.fingerprint(output, exclude_generated=False))
        self.assertEqual(metadata['probe_mode'], 'legacy-production')
        self.assertIn('local startupProbeBegin', (output / 'Source/main.lua').read_text())

    def test_overlay_rejects_missing_or_duplicate_slots(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary)
            (source / 'main.lua').write_text('no reviewed import slots\n')
            with self.assertRaisesRegex(ValueError, 'missing or duplicate'):
                overlay_imports(source)


if __name__ == '__main__':
    unittest.main()
