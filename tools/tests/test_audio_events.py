"""Event to score mapping against pret/pokered, plus score loop points."""
import os
import unittest
from pathlib import Path

from tools.audio.catalog import Catalog
from tools.audio.events import build
from tools.audio.scores import ASSETS, LabelTrace, ScoreTrace, _sound_loop_targets, checkpoint_maps
from tools.audio.source import Source
from tools.measure_boot_budget import LUA_PEAK_BUDGET_KIB, POOL_BYTES

ROOT = Path(__file__).resolve().parents[2]


def probe():
    import subprocess
    completed = subprocess.run(
        ['lua', 'tools/audio/audio_events_probe.lua', str(ROOT)],
        cwd=ROOT, check=True, capture_output=True, text=True,
    )
    rows = {}
    for line in completed.stdout.splitlines():
        key, value = line.split('\t', 1)
        rows.setdefault(key, []).append(value)
    return {key: values[0] if len(values) == 1 else values for key, values in rows.items()}


class AudioEventTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = os.environ['POKERED_REFERENCE_DIR']
        cls.source = Source(source)
        cls.catalog = Catalog(cls.source)
        cls.data = build(source)
        cls.probe = probe()

    def test_events_file_matches_the_generator(self):
        from tools.audio.events import emit
        payload = emit(self.data)
        self.assertEqual((ROOT / 'Source/audio/events.lua').read_bytes(), payload)

    def test_every_songs_row_and_installed_map_is_routed(self):
        routed = {key.split(':', 1)[1]: value for key, value in self.probe.items() if key.startswith('map:')}
        self.assertEqual(len(routed), len(self.catalog.maps))
        installed = checkpoint_maps()
        self.assertEqual(len(installed), 222)
        self.assertEqual(installed - set(routed), set())
        assets = {asset: name for name, asset in ASSETS.items()}
        for row in self.catalog.maps:
            map_id = 'pokered:' + row['map']
            self.assertEqual(ASSETS[routed[map_id]], row['asset'])
            self.assertEqual(assets[row['asset']], routed[map_id])
        self.assertEqual(routed['pokered:PALLET_TOWN'], 'pallet')
        self.assertEqual(self.probe['alias:pallet'], 'pallet')
        self.assertEqual(self.probe['alias:oaks'], 'oaks_lab')
        self.assertEqual(self.probe['alias:route'], 'route1')

    def test_battle_jingle_and_hp_follow_the_source_rules(self):
        expected = {
            'score:wild': 'wild', 'kind:wild': 'wild', 'victory:wild': 'defeated_wild',
            'score:articuno': 'wild', 'kind:articuno': 'legendary',
            'score:mewtwo': 'wild', 'kind:mewtwo': 'legendary',
            'score:gym-flag': 'gym_leader', 'kind:gym-flag': 'gym', 'victory:gym-flag': 'defeated_gym',
            'score:gym-zero': 'trainer', 'victory:gym-zero': 'defeated_trainer',
            'score:rival3': 'final', 'kind:rival3': 'champion', 'victory:rival3': 'defeated_gym',
            'score:lance': 'gym_leader', 'kind:lance': 'gym',
            'score:brock-nil': 'gym_leader', 'score:brock-zero': 'trainer',
            'score:giovanni-gym': 'gym_leader', 'score:giovanni-hideout': 'trainer',
            'score:giovanni-zero': 'trainer', 'score:youngster': 'trainer',
            'jingle:lass': 'meet_female', 'jingle:rocket': 'meet_evil',
            'jingle:youngster': 'meet_male', 'jingle:rival': 'nil',
            'jingle:brock': 'meet_male', 'jingle:gym': 'nil', 'jingle:empty': 'nil',
            'pixels:9': '9', 'pixels:10': '10', 'pixels:0': '0', 'pixels:1': '1',
            'pixels:shift': '24',
            'low:9': 'true', 'low:10': 'false', 'low:0': 'false',
            'bed:surf': 'surfing', 'bed:bike': 'bicycle', 'bed:walk': 'pallet',
            'menu:first': 'nil', 'menu:pause': 'start_menu', 'menu:title': 'nil',
            'menu:cursor': 'menu', 'menu:battle': 'menu',
        }
        for key, value in expected.items():
            self.assertEqual(self.probe[key], value, key)

    def test_trainer_lists_match_the_asm(self):
        text = self.source.read('data/trainers/encounter_types.asm')

        def listed(label):
            rows = []
            inside = False
            for raw in text.splitlines():
                code = raw.split(';', 1)[0].strip()
                if code.startswith(label):
                    inside = True
                    continue
                if not inside:
                    continue
                if code.startswith('db -1'):
                    break
                rows.append(code.split()[1])
            return rows

        evil = listed('EvilTrainerList')
        female = listed('FemaleTrainerList')
        self.assertEqual(sorted(key.split(':', 1)[1] for key in self.probe if key.startswith('evil:')), sorted(evil))
        self.assertEqual(sorted(key.split(':', 1)[1] for key in self.probe if key.startswith('female:')), sorted(female))
        self.assertIn('OPP_GIOVANNI', evil)
        rivals = sorted(key.split(':', 1)[1] for key in self.probe if key.startswith('rival:'))
        self.assertEqual(rivals, ['OPP_RIVAL1', 'OPP_RIVAL2', 'OPP_RIVAL3'])

    def test_static_legendaries_use_species_cries_and_wild_music(self):
        for name, row in self.data['legendary'].items():
            self.assertLess(row['id'], self.data['opp_offset'])
            self.assertEqual(self.probe['legend:' + name], str(row['id']))
            cited = self.source.read(row['source'].split(':', 1)[0])
            self.assertIn('PlayCry', cited)
            self.assertIn(row['const'], cited)

    def test_cue_citations_are_in_the_pinned_files(self):
        for name, cue in self.data['cues'].items():
            path, line = cue['source'].rsplit(':', 1)
            rows = self.source.read(path).splitlines()
            self.assertIn(cue['token'], rows[int(line) - 1])
            self.assertEqual(self.probe['cue:' + name], cue['score'] + ':' + cue['kind'])
            self.assertIn(cue['score'], ASSETS)

    def test_score_loops_match_source_traces(self):
        import json
        manifest = json.loads((ROOT / 'tools/audio/score-manifest.json').read_text())
        adapted = set(manifest['adapted'])
        approximated = set(manifest['approximations'])
        self.assertEqual(approximated, set())
        for name, row in manifest['scores'].items():
            header = (ROOT / f'Source/audio/score/{name}.lua').read_text().split('notes=', 1)[0]
            self.assertIn(f'ticks={row["ticks"]}', header)
            if row.get('parts'):
                self.assertIn('parts={', header)
                continue
            shown = 'nil' if row['loop'] is None else str(row['loop'])
            self.assertIn(f'loop={shown}', header)
            if name in adapted or name in approximated or name == 'alarm':
                continue
            if row.get('loop_basis') in ('label', 'joint'):
                continue
            asset = row['asset']
            trace = ScoreTrace(self.catalog, self.catalog.headers[asset]['family'])
            trace.load(asset)
            result = trace.run()
            loop = result['repeat']['start_tick'] if result['repeat'] else None
            self.assertNotEqual(result['status'], 'bound', name)
            if row.get('loop_basis') == 'state':
                self.assertIsNotNone(loop, name)
                self.assertEqual(row['ticks'] - row['loop'], result['ticks'] - loop, name)
                self.assertIn(row['loop'], {loop, loop - 1}, name)
                continue
            self.assertEqual(row['ticks'], result['ticks'], name)
            self.assertEqual(row['loop'], loop, name)

    def test_loop_points_match_pokered_loop_labels(self):
        import json
        manifest = json.loads((ROOT / 'tools/audio/score-manifest.json').read_text())
        label_pcs, loop_pcs = _sound_loop_targets(self.catalog)
        for name, row in manifest['scores'].items():
            basis = row.get('loop_basis')
            if basis not in ('label', 'joint', 'parts', 'state'):
                continue
            header = self.catalog.headers[row['asset']]
            scopes = {channel['entry'] for channel in header['channels']}
            trace = LabelTrace(self.catalog, header['family'], scopes, label_pcs, loop_pcs)
            trace.load(row['asset'])
            trace.run(4000)
            labels = trace.label_tick
            self.assertTrue(labels, name)
            if basis == 'label':
                self.assertEqual(set(labels.values()), {row['loop']}, name)
            elif basis == 'joint':
                self.assertEqual(row['loop'], max(labels.values()), name)
            elif basis == 'parts':
                shipped = {part['voice']: part['loop'] for part in row['parts']}
                self.assertEqual(shipped, labels, name)
            else:
                self.assertGreaterEqual(row['loop'], min(labels.values()), name)

    def test_cinnabar_mansion_does_not_seam_at_tick_9315(self):
        import json
        row = json.loads((ROOT / 'tools/audio/score-manifest.json').read_text())['scores']['mansion']
        parts = {part['voice']: part for part in row['parts']}
        self.assertEqual(
            [(voice, parts[voice]['loop'], parts[voice]['ticks'] - parts[voice]['loop'])
             for voice in (1, 2, 3, 4)],
            [(1, 0, 9315), (2, 864, 1728), (3, 0, 3888), (4, 216, 216)],
        )

        def phase(part, tick):
            if tick < part['ticks']:
                return tick
            span = part['ticks'] - part['loop']
            return part['loop'] + (tick - part['loop']) % span

        # Channel 1's label returns here. The other channels stay in their own loops.
        self.assertEqual(phase(parts[1], 9315), 0)
        self.assertEqual(phase(parts[2], 9315), 2403)
        self.assertNotEqual(phase(parts[2], 9315), parts[2]['loop'])
        self.assertEqual(phase(parts[3], 9315), 1539)
        self.assertEqual(phase(parts[4], 9315), 243)

    def test_chirps_keep_the_30fps_gate_adaptation(self):
        import json
        manifest = json.loads((ROOT / 'tools/audio/score-manifest.json').read_text())
        for name in ('menu', 'text', 'start_menu'):
            row = manifest['scores'][name]
            self.assertEqual(row['ticks'], 8)
            self.assertIsNone(row['loop'])
            self.assertEqual(row['notes'], 2)
            asset = ASSETS[name]
            trace = ScoreTrace(self.catalog, self.catalog.headers[asset]['family'])
            trace.load(asset)
            trace.run()
            self.assertLess(min(note[2] for note in trace.notes), 3)


class AudioBootTests(unittest.TestCase):
    def test_pool_budget_is_unchanged(self):
        self.assertEqual(POOL_BYTES, 16645684)
        self.assertEqual(LUA_PEAK_BUDGET_KIB, 14000)

    def test_scores_load_on_first_play(self):
        audio = (ROOT / 'Source/game/kantoAudio.lua').read_text()
        engine = (ROOT / 'Source/audio/engine.lua').read_text()
        stub = (ROOT / 'Source/audio/scores.lua').read_text()
        self.assertNotIn('import "audio/scores"', audio)
        self.assertNotIn('import "audio/cries"', engine.split('function KantoSynth.cry', 1)[0])
        self.assertIn('import "audio/cries"', engine.split('function KantoSynth.cry', 1)[1])
        self.assertIn('import("audio/score/"', engine)
        self.assertNotIn('notes=', stub)
        self.assertNotIn('KantoMusicMaps', stub)
        for banned in ('fieldTravelData', 'RulesRNG', ':members(', 'getSnapshot', 'fieldTravelMode'):
            self.assertNotIn(banned, audio)

    def test_sfx_priorities_cover_every_sfx_cue(self):
        import re
        engine = (ROOT / 'Source/audio/engine.lua').read_text()
        block = engine.split('local priorities', 1)[1].split('}', 1)[0]
        names = set(re.findall(r'\n\s+([A-Za-z0-9_]+) =', block))
        cues = build(os.environ['POKERED_REFERENCE_DIR'])['cues']
        for name, cue in cues.items():
            if cue['kind'] == 'sfx':
                self.assertIn(cue['score'], names, name)


if __name__ == '__main__':
    unittest.main()
