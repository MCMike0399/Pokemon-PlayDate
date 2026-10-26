"""Pinned text/input checks only; SDK rendering belongs to native contracts."""
import json
import os
from pathlib import Path
import re
import subprocess
import unittest

from tools import generate_cerulean_content as content
from tools import generate_tutorial_escort as tutorial


class NativeCeruleanTextTests(unittest.TestCase):
    def test_global_boundaries_preserve_unknown_controls_and_line_numbers(self):
        for suffix in (':', '::'):
            source = ('_First::\n\ttext "First"\n\tdone\n'
                      'Other' + suffix + '\n\ttext "Other"\n\tdone\n'
                      '_Second' + suffix + '\n\ttext_unsupported foo\n')
            recipes = content.text_recipes(source)
            self.assertEqual(recipes['_First'], [
                dict(op='text', text='First', source_line=2),
                dict(op='control', source='done', source_line=3)])
            self.assertEqual(recipes['_Second'], [
                dict(op='control', source='text_unsupported foo', source_line=8)])
            self.assertNotIn('Other', recipes)

    def test_tutorial_sleepy_body_stops_before_unprefixed_fisher(self):
        sources = tutorial.inputs()
        text = sources['text/ViridianCity.asm'].decode()
        body = re.search(r'^_ViridianCityOldManSleepyPrivatePropertyText::\n'
                         r'(.*?)(?=^ViridianCityFisherYouCanHaveThisText::)',
                         text, re.M | re.S)[1]
        recipe = tutorial.build()['texts']['_ViridianCityOldManSleepyPrivatePropertyText']['recipe']
        self.assertEqual([r.get('text', r.get('source')) for r in recipe],
                         ['You can\'t go', 'through here!', 'This is private', 'property!', 'done'])
        self.assertEqual(body.strip().splitlines()[-1].strip(), 'done')

    def test_clipboard_is_exact_source_empty_body(self):
        root = Path(os.environ['POKERED_REFERENCE_DIR'])
        source = (root / 'text/MtMoonPokecenter.asm').read_text()
        body = source.split('_MtMoonPokecenterClipboardText::\n', 1)[1]
        self.assertEqual(body.split(), ['text_start', 'done'])
        recipe = content.text_recipes(source)['_MtMoonPokecenterClipboardText']
        self.assertEqual(recipe, [dict(op='control', source='text_start', source_line=47),
                                  dict(op='control', source='done', source_line=48)])

    def test_literal_utf8_and_only_text_artifacts_change(self):
        root = Path(os.environ['POKERED_REFERENCE_DIR'])
        artifacts = content.build(root)
        dialogue = artifacts['dialogue.json']
        self.assertNotIn(b'\\u', dialogue)
        self.assertIn('<PLAYER> got ¥@'.encode(), dialogue)
        for name, raw in artifacts.items():
            if name in ('dialogue.json', 'provenance.json'):
                continue
            original = subprocess.check_output([
                'git', 'show', 'a316baf:Source/data/sourceSlice/' + name], cwd=content.ROOT)
            if name in ('trainers.json', 'scripts.json'):
                self.assertEqual(json.loads(raw), json.loads(original), name)
                self.assertNotIn(b'\\u', raw)
            else:
                self.assertEqual(raw, original, name)
        before = json.loads(subprocess.check_output([
            'git', 'show', 'a316baf:Source/data/tutorialEscort/scenes.json'], cwd=content.ROOT))
        after = tutorial.build()
        before.pop('texts')
        after.pop('texts')
        self.assertEqual(after, before)


if __name__ == '__main__':
    unittest.main()
