"""Pinned derivation and actual pdc import precedence; no Lua execution."""
import hashlib
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import unittest
import zlib

from tools import build, generate_timer_runtime as generator
from tools.harness.run import sdk_path

PROJECT = Path(__file__).resolve().parents[2]


def payloads(path):
    data = path.read_bytes()
    if data[:16] != b'Playdate PDZ\0\0\0\0':
        raise AssertionError('unexpected PDZ header')
    offset, modules = 16, {}
    while offset < len(data):
        word = struct.unpack_from('<I', data, offset)[0]
        if word & 255 != 0x81:
            raise AssertionError('unexpected PDZ flags')
        end = data.index(0, offset + 4)
        name = data[offset + 4:end].decode()
        start = (end + 4) & ~3
        size = word >> 8
        lua = zlib.decompress(data[start + 4:start + size])
        if len(lua) != struct.unpack_from('<I', data, start)[0] or not lua.startswith(b'\x1bLua'):
            raise AssertionError('invalid Lua payload')
        if name in modules:
            raise AssertionError('duplicate module: ' + name)
        modules[name] = lua
        offset = start + size
    if offset != len(data):
        raise AssertionError('truncated PDZ')
    return modules


class TimerRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.sdk = sdk_path()
        self.temporary = tempfile.TemporaryDirectory(prefix='pokemon-timer-check-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def test_installed_candidate_has_only_the_exact_queue_clear_change(self):
        generator.generate(self.sdk, PROJECT / 'Source/CoreLibs', check=True)
        for name in ('timer.lua', 'frameTimer.lua'):
            original = (self.sdk / 'CoreLibs' / name).read_bytes()
            candidate = (PROJECT / 'Source/CoreLibs' / name).read_bytes()
            self.assertEqual(candidate.count(generator.NEW), 1)
            self.assertEqual(candidate.replace(generator.NEW, generator.OLD, 1), original)
            # The one initial queue allocation remains; only per-update reset changes.
            self.assertEqual(candidate.count(b'local timersToRemove = {}'), 1)
        self.assertEqual((PROJECT / 'Source/CoreLibs/SDK_LICENSE.md').read_bytes(),
                         (self.sdk / 'SDK_LICENSE.md').read_bytes())

    def test_generation_is_reproducible_and_check_does_not_repair(self):
        output = self.root / 'generated'
        expected = generator.generate(self.sdk, output)
        self.assertEqual(generator.generate(self.sdk, output, check=True), expected)
        (output / 'timer.lua').write_bytes(b'mutated')
        with self.assertRaisesRegex(ValueError, 'generated timer runtime differs'):
            generator.generate(self.sdk, output, check=True)
        self.assertEqual((output / 'timer.lua').read_bytes(), b'mutated')

    def test_unpinned_sdk_fails_before_any_output_and_sdk_cannot_be_destination(self):
        fixture = self.root / 'sdk'
        (fixture / 'CoreLibs').mkdir(parents=True)
        (fixture / 'VERSION.txt').write_text('3.1.2\n')
        for name in generator.INPUT_SHA256:
            shutil.copyfile(self.sdk / name, fixture / name)
        with (fixture / 'CoreLibs/frameTimer.lua').open('ab') as stream:
            stream.write(b'\n')
        output = self.root / 'generated'
        with self.assertRaisesRegex(ValueError, 'pinned SDK checksum differs'):
            generator.generate(fixture, output)
        self.assertFalse(output.exists())
        with self.assertRaisesRegex(ValueError, 'outside the installed SDK'):
            generator.generate(self.sdk, self.sdk / 'CoreLibs')
        (fixture / 'VERSION.txt').write_text('3.1.3\n')
        with self.assertRaisesRegex(ValueError, 'requires SDK 3.1.2'):
            generator.generate(fixture, output)

    def test_production_pdz_imports_application_overrides(self):
        stage = self.root / 'production'
        stage.mkdir()
        bundle = self.root / 'Game.pdx'
        build.compile_production(PROJECT, self.sdk, bundle, stage)
        actual = payloads(bundle / 'main.pdz')
        # Compile original/candidate at the SAME path to avoid debug-source-path
        # differences. The control explicitly imports the files outside CoreLibs,
        # so it cannot silently resolve those imports from the SDK.
        control = self.root / 'control'
        control.mkdir()
        (control / 'main.lua').write_text('import "timer"\nimport "frameTimer"\n')
        compiled = []
        for source in (self.sdk / 'CoreLibs', PROJECT / 'Source/CoreLibs'):
            for name in ('timer.lua', 'frameTimer.lua'):
                shutil.copyfile(source / name, control / name)
            output = self.root / ('Control' + str(len(compiled)) + '.pdx')
            subprocess.run([str(self.sdk / 'bin/pdc'), str(control), str(output)],
                           check=True, capture_output=True)
            compiled.append(payloads(output / 'main.pdz'))
        for name in ('timer', 'frameTimer'):
            # pdc uses the import name as the debug source name. Normalize only
            # this known metadata prefix, retaining all bytecode and line tables.
            embedded = actual['CoreLibs/' + name]
            candidate = compiled[1][name]
            original = compiled[0][name]
            self.assertNotEqual(original, candidate)
            short = ('@' + name + '.lua').encode()
            full = ('@CoreLibs/' + name + '.lua').encode()
            short_field = bytes([0x80 | (len(short) + 1)]) + short
            full_field = bytes([0x80 | (len(full) + 1)]) + full
            self.assertEqual(candidate.count(short_field), 1)
            self.assertEqual(embedded, candidate.replace(short_field, full_field, 1))
            self.assertNotEqual(embedded, original.replace(short_field, full_field, 1))
        for name, digest in generator.INPUT_SHA256.items():
            self.assertEqual(hashlib.sha256((self.sdk / name).read_bytes()).hexdigest(), digest)


if __name__ == '__main__':
    unittest.main()
