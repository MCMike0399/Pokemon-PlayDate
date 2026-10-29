"""Proportional host checks for the synth adaptation; no runtime/audio claims."""
import os
import io
import struct
import unittest
import wave
from tools.audio.catalog import Catalog
from tools.audio.scores import ASSETS, CHECKPOINT_THEMES, ScoreTrace, adapt_menu, checkpoint_maps, map_routes, wave_asset
from tools.audio.source import Source
from tools.audio.trace import Trace

class FullTrace(ScoreTrace):
    snapshot = Trace.snapshot

class ScoreTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog=Catalog(Source(os.environ['POKERED_REFERENCE_DIR']))

    def test_musical_laps_preserve_native_note_onsets(self):
        # Full-register recurrence remains the existing oracle. Compare all note
        # gates, Hz, duties and envelopes through its longer effect-phase cycle.
        for name in ('pallet','route1','wild','trainer','vermilion','anne','pokecenter','gym', *CHECKPOINT_THEMES):
            with self.subTest(name=name):
                asset=ASSETS[name]
                small=ScoreTrace(self.catalog,self.catalog.headers[asset]['family']);small.load(asset)
                a=small.run()
                full=FullTrace(self.catalog,self.catalog.headers[asset]['family']);full.load(asset)
                b=full.run()
                self.assertEqual(a['status'],'repeat')
                # Routes2's full effect-phase state does not close at the
                # default bound. Its adapted notes still match that entire run.
                self.assertEqual(b['status'], 'bound' if name == 'routes2' else 'repeat')
                start,end=a['repeat']['start_tick'],a['ticks']
                expanded=list(small.notes)
                lap=1
                while end+lap*(end-start)<b['ticks']+(end-start):
                    expanded += [[n[0]+lap*(end-start),*n[1:]] for n in small.notes if n[0]>=start]
                    lap+=1
                end_tick = b['ticks'] + (1 if b['status'] == 'bound' else 0)
                self.assertEqual([n for n in expanded if n[0]<end_tick],full.notes)

    def test_checkpoint_routes_use_original_map_songs(self):
        routes=map_routes(self.catalog)
        self.assertEqual(routes['pokered:VERMILION_CITY'],'vermilion')
        self.assertEqual(routes['pokered:POKEMON_FAN_CLUB'],'vermilion')
        self.assertEqual(routes['pokered:VERMILION_DOCK'],'anne')
        for row in self.catalog.maps:
            if row['map'].startswith('SS_ANNE_'):
                self.assertEqual(routes['pokered:'+row['map']],'anne')
        for town in ('VIRIDIAN', 'PEWTER', 'CERULEAN', 'VERMILION'):
            for interior in ('POKECENTER', 'MART'):
                self.assertEqual(routes[f'pokered:{town}_{interior}'], 'pokecenter')
        self.assertEqual(routes['pokered:MT_MOON_POKECENTER'], 'pokecenter')
        for town in ('PEWTER', 'CERULEAN', 'VERMILION'):
            self.assertEqual(routes[f'pokered:{town}_GYM'], 'gym')
        self.assertEqual(routes['pokered:VERMILION_OLD_ROD_HOUSE'], 'cities2')
        self.assertEqual(routes['pokered:CERULEAN_CITY'], 'cities2')
        self.assertEqual(routes['pokered:VIRIDIAN_CITY'], 'cities1')
        self.assertEqual(routes['pokered:PEWTER_CITY'], 'cities1')
        self.assertEqual(routes['pokered:ROUTE_5'], 'routes3')
        self.assertEqual(routes['pokered:ROUTE_6'], 'routes3')
        self.assertEqual(routes['pokered:MT_MOON_1F'], 'dungeon3')
        self.assertEqual(checkpoint_maps() - routes.keys(), set())

        # Every generated route must preserve the pinned table's bank-qualified
        # asset. Map names alone cannot infer the original song.
        source_routes = {'pokered:' + row['map']: row['asset'] for row in self.catalog.maps}
        for map_id, name in routes.items():
            self.assertEqual(ASSETS[name], source_routes[map_id])
        for map_id, asset in source_routes.items():
            selected = asset in ASSETS.values()
            if asset in CHECKPOINT_THEMES.values():
                selected = selected and map_id in checkpoint_maps()
            self.assertEqual(map_id in routes, selected)

    def test_wave_notes_keep_bank_local_ram_and_source_pitch(self):
        for asset in ASSETS.values():
            family = self.catalog.headers[asset]['family']
            trace = ScoreTrace(self.catalog, family)
            trace.load(asset)
            trace.run()
            for note in trace.notes:
                if note[1] != 3:
                    self.assertEqual(len(note), 7)
                    continue
                key = note[7]
                self.assertTrue(key.startswith(f'audio{family}-wave'))
                index = int(key.rsplit('wave', 1)[1])
                section, offset = self.catalog.target(family, f'Audio{family}_WavePointers.wave{index}')
                self.assertEqual(trace.waves[key], self.catalog.sections[section][offset:offset+16])
                # Wave period is a 32-sample cycle, not the pulse divisor or
                # the asset's 44100 Hz / 32 file playback frequency.
                period = 2048 - 65536 / note[3]
                self.assertAlmostEqual(period, round(period), places=2)
                self.assertAlmostEqual(note[3], 65536 / (2048 - round(period)), places=3)

    def test_wave_asset_is_one_pcm16_cycle_without_normalization(self):
        data = bytes.fromhex('0123456789abcdeffedcba9876543210')
        payload = wave_asset(data)
        self.assertEqual(payload, wave_asset(data))
        self.assertEqual(len(payload), 108)
        with wave.open(io.BytesIO(payload), 'rb') as stream:
            self.assertEqual((stream.getnchannels(), stream.getsampwidth(), stream.getnframes()), (1, 2, 32))
            self.assertEqual(stream.getframerate(), 44100)
            samples = struct.unpack('<32h', stream.readframes(32))
        expected = tuple((15 - 2 * value) * 2184 for value in (*range(16), *range(15, -1, -1)))
        self.assertEqual(samples, expected)

    def test_menu_chirp_cannot_disappear_between_30fps_frames(self):
        trace=ScoreTrace(self.catalog,2);trace.load(ASSETS['menu']);trace.run()
        score=adapt_menu(dict(notes=trace.notes,ticks=trace.tick,loop=None))
        self.assertEqual([n[3] for n in score['notes']],[trace.notes[0][3],trace.notes[-1][3]])
        self.assertEqual(score['ticks'],8)
        seconds=70224/4194304
        for phase in range(100):
            frames=[phase/3000+frame/30 for frame in range(5)]
            for note in score['notes']:
                self.assertTrue(any(note[0]*seconds<=t<(note[0]+note[2])*seconds for t in frames))

    def test_alarm_transition_ticks_match_existing_source_interpreter(self):
        trace=Trace(self.catalog,2)
        trace.run(63,alarm=True)
        triggers=[e['tick'] for e in trace.events if e['kind']=='write'
                  and e['register']=='ff14' and e['owner']=='low-health']
        self.assertEqual(triggers,[0,11,31])  # Full-state repeat stops the run here.

    def test_finite_sfx_have_bounded_gates_and_source_pitch(self):
        for name in ('heal','menu','hit','faint'):
            with self.subTest(name=name):
                asset=ASSETS[name]
                trace=ScoreTrace(self.catalog,self.catalog.headers[asset]['family']);trace.load(asset)
                result=trace.run()
                self.assertEqual(result['status'],'ended')
                self.assertTrue(trace.notes)
                self.assertTrue(all(0<n[2]<=256 and 0<n[4]<=1 for n in trace.notes))
                self.assertTrue(all(n[0]+n[2]<=result['ticks'] for n in trace.notes))
        asset=ASSETS['menu']
        trace=ScoreTrace(self.catalog,2);trace.load(asset);trace.run()
        self.assertAlmostEqual(trace.notes[0][3],131072/(2048-0x7c0),places=3)

if __name__=='__main__': unittest.main()
