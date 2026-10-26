"""Host checks inspect immutable source inputs and actual generated data only.

Production Lua/font/layout execution belongs to SourceTextContracts on the SDK.
"""
import importlib.util
import json
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('source_text_generator', ROOT / 'tools/generate_source_text.py')
GEN = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GEN)


class SourceTextDataTests(unittest.TestCase):
    def test_generated_charset_and_glyphs_reproduce_pinned_inputs(self):
        self.assertEqual((ROOT / 'Source/data/sourceText.json').read_text(), GEN.encoded())
        self.assertEqual(GEN.build()['source_revision'], 'af519899719f0754965776faac0e836a3b906e6d')

    def test_projection_covers_entire_english_charmap_and_explicitly_excludes_japanese_aliases(self):
        text = (GEN.REFERENCE / 'constants/charmap.asm').read_text()
        english, japanese = text.split('; Japanese kana,', 1)
        entries = re.findall(r'^\s*charmap "([^"]+)",\s*\$[0-9a-f]+', english, re.M)
        data = GEN.build()
        self.assertEqual(set(data['tokens'] + data['literals']), set(entries))
        self.assertEqual(len(data['tokens']), 43)
        self.assertIn('é', data['literals'])
        self.assertIn('¥', data['literals'])
        self.assertIn('<USER>', data['tokens'])
        self.assertIn('<TARGET>', data['tokens'])
        self.assertIn('charmap "ガ"', japanese)
        self.assertNotIn('ガ', data['glyphs'])

    def test_every_non_ascii_english_literal_has_a_nonempty_eight_by_eight_fallback(self):
        data = GEN.build()
        required = {c for s in data['literals'] for c in s if ord(c) > 127}
        self.assertEqual(set(data['glyphs']), required)
        for char, entry in data['glyphs'].items():
            with self.subTest(char=char):
                self.assertEqual(len(entry['rows']), 8)
                self.assertTrue(all(re.fullmatch('[.#]{8}', row) for row in entry['rows']))
                self.assertIn('#', ''.join(entry['rows']))
                self.assertTrue(entry['source'])

    def test_literal_accent_currency_and_sex_pixels_are_independent_source_vectors(self):
        glyphs = GEN.build()['glyphs']
        self.assertEqual(glyphs['é']['rows'], [
            '..##....', '##......', '..####..', '.#....#.', '.######.', '.#......', '..#####.', '........'])
        self.assertEqual(glyphs['¥']['rows'], [
            '..####..', '..#..#..', '..####..', '..#.....', '.###....', '..#.....', '.###....', '..#.....'])
        self.assertEqual(glyphs['♀']['rows'][-2:], ['...#....', '...#....'])
        self.assertNotEqual(glyphs['♂']['rows'], glyphs['♀']['rows'])

    def test_corrupted_reference_fails_before_generation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest = json.loads((GEN.REFERENCE / 'manifest.json').read_text())
            for name in manifest['files']:
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((GEN.REFERENCE / name).read_bytes())
            (root / 'manifest.json').write_text(json.dumps(manifest))
            (root / 'gfx/font/font.png').write_bytes(b'corrupted')
            with patch.object(GEN, 'REFERENCE', root), self.assertRaisesRegex(ValueError, 'checksum mismatch'):
                GEN.build()

    def test_actual_imported_corpus_uses_known_charset_and_retains_dynamic_controls(self):
        data = GEN.build()
        chars = {c for s in data['literals'] for c in s}
        tokens = set(data['tokens'])
        dynamic = set()
        non_ascii = set()
        for name in ('viridianSlice', 'pewterSlice'):
            source = json.loads((ROOT / f'Source/data/{name}/dialogue.json').read_text())
            for label, record in source['texts'].items():
                for row in record['recipe']:
                    if row['op'] == 'text_ram':
                        dynamic.add('text_ram')
                        self.assertRegex(row['symbol'], r'^\w+$')
                    if row['op'] == 'control' and row['source'].startswith(('text_decimal ', 'text_bcd ')):
                        dynamic.add(row['source'].split()[0])
                    if 'text' not in row:
                        continue
                    text = row['text']
                    self.assertLessEqual(set(re.findall(r'<[^>]+>', text)), tokens, label)
                    literal = re.sub(r'<[^>]+>', '', text)
                    self.assertLessEqual(set(literal), chars, label)
                    non_ascii.update(c for c in literal if ord(c) > 127)
        self.assertEqual(non_ascii, {'¥'})
        self.assertEqual(dynamic, {'text_ram', 'text_decimal', 'text_bcd'})

    def test_semantic_token_implementation_explicitly_accounts_for_all_pinned_tokens(self):
        # Inspect actual production inputs; this does not transpile or run Lua.
        text = (ROOT / 'Source/game/sourceText.lua').read_text()
        named = set(re.findall(r'"(<[^>]+>)"', text))
        for token in GEN.build()['tokens']:
            if token.startswith('<BOLD_'):
                self.assertRegex(token, r'^<BOLD_[A-ILMPSV]>$')
            else:
                self.assertIn(token, named, token)
        self.assertIn('unsupported source token:', text)

    def test_utf8_native_scenario_and_production_files_remain_literal_utf8(self):
        data = (ROOT / 'Source/data/sourceText.json').read_bytes()
        self.assertIn('é'.encode(), data)
        self.assertIn('¥'.encode(), data)
        self.assertNotIn(b'\\u00e9', data)
        scenario = json.loads((ROOT / 'tools/harness/scenarios/source-text.json').read_text())
        self.assertIn('contracts', scenario['commands'])
        contract = (ROOT / 'Source/dev/sourceTextContracts.lua').read_text()
        self.assertIn('image:sample', contract)
        self.assertIn('source-text-typing-', contract)
        self.assertIn('source-text-pages-', contract)


if __name__ == '__main__':
    unittest.main()
