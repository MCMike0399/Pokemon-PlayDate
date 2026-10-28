"""Pinned assembly/data checks only. Controller/RNG checks run in the real SDK."""
import copy
import os
from pathlib import Path
import re
import unittest

from tools import generate_cerulean_content as generator


class CeruleanAmbientDialogueTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.reference = Path(os.environ['POKERED_REFERENCE_DIR'])
        cls.script = (cls.reference / 'scripts/CeruleanCity.asm').read_text()

    def body(self, pointer):
        return re.search(rf'^{pointer}:\n(.*?)(?=^\w+:)', self.script, re.M | re.S)[1]

    def test_all_256_source_bytes_follow_actual_carry_control_flow_and_text_targets(self):
        objects = (self.reference / 'data/maps/objects/CeruleanCity.asm').read_text()
        rows = re.findall(r'^\s*object_event\s+(.+)$', objects, re.M)
        for index, pointer, thresholds, suffixes in (
            (7, 'CeruleanCityCooltrainerF1Text', [180, 100],
             ['SlowbroUseSonicboomText', 'SlowbroPunchText', 'SlowbroWithdrawText']),
            (8, 'CeruleanCitySlowbroText', [180, 120, 60],
             ['TookASnoozeText', 'IsLoafingAroundText', 'TurnedAwayText', 'IgnoredOrdersText']),
        ):
            with self.subTest(index=index):
                constant = rows[index - 1].split(',')[5].strip()
                self.assertRegex(self.script, rf'dw_const {pointer},\s+{constant}\b')
                body = self.body(pointer)
                self.assertEqual(re.findall(r'ldh a, \[(\w+)\]', body), ['hRandomAdd'])
                self.assertEqual([int(n) for n in re.findall(r'\bcp (\d+)', body)], thresholds)
                local_targets = re.findall(r'ld hl, \.(\w+)', body)
                self.assertEqual(local_targets, suffixes)
                actual_labels = dict(re.findall(r'^\.(\w+):\n\s*text_far (_\w+)\n\s*text_end', body, re.M))
                self.assertEqual(set(actual_labels), set(suffixes))
                self.assertEqual(re.findall(r'jr c, (\.\w+)', body),
                                 ['.notFirstText', '.notSecondText', '.notThirdText'][:len(thresholds)])
                d = generator.source_byte_dialog(body, pointer)
                choices = d['steps'][0]['choices']
                for byte in range(256):
                    branch = next((i for i, threshold in enumerate(thresholds) if byte >= threshold), len(thresholds))
                    selected = [c for c in choices if c['min'] <= byte <= c['max']]
                    self.assertEqual(len(selected), 1)
                    self.assertEqual(selected[0]['labels'], [actual_labels[suffixes[branch]]])
                self.assertEqual(d['steps'][0]['source']['cry_cues'], [])
                self.assertEqual(d['steps'][0]['source']['byte'], 'hRandomAdd')

    def test_decoder_rejects_side_effects_new_sound_commands_and_broken_partitions(self):
        pointer = 'CeruleanCitySlowbroText'
        body = self.body(pointer)
        for mutated in (body.replace('cp 120', 'cp 200'),
                        body.replace('ldh a, [hRandomAdd]', 'call Random'),
                        body.replace('call PrintText', 'call PlayCry\n\tcall PrintText', 1),
                        body.replace('text_end', 'sound_cry_nidorina\n\ttext_end', 1),
                        body.replace('jr c, .notSecondText', 'jr nc, .notSecondText')):
            with self.subTest(body=mutated), self.assertRaises(ValueError):
                generator.source_byte_dialog(mutated, pointer)

    def test_installed_descriptors_match_pin_and_leave_guards_and_other_gaps_intact(self):
        import json
        data = json.loads((generator.OUTPUT / 'events.json').read_bytes())['events']
        scripts = json.loads((generator.OUTPUT / 'scripts.json').read_bytes())
        gaps = {g['id'] for g in scripts['gaps']}
        for index, pointer in ((7, 'CeruleanCityCooltrainerF1Text'), (8, 'CeruleanCitySlowbroText')):
            event_id = f'pokered:CERULEAN_CITY:objects:{index}'
            expected = dict(content='cerulean', **generator.source_byte_dialog(self.body(pointer), pointer))
            self.assertEqual(data[event_id], expected)
            self.assertNotIn(event_id, gaps)
            detached = copy.deepcopy(expected)
            detached['steps'][0]['choices'][0]['labels'][0] = '_Changed'
            self.assertNotEqual(detached, data[event_id])
        for index in (6, 11):
            self.assertEqual(data[f'pokered:CERULEAN_CITY:objects:{index}']['steps'],
                             [{'op': 'dialog', 'labels': ['_CeruleanCityGuardText']}])
        self.assertIn('pokered:CERULEAN_POKECENTER:objects:4', gaps)


if __name__ == '__main__':
    unittest.main()
