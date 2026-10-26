"""Host audio qualification: pinned source closure, byte boundaries and scheduler mutations."""
import os
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from tools.audio.catalog import Catalog, Command
from tools.audio.codec import encode
from tools.audio.convert import canonical
from tools.audio.oracle import qualify_bytes
from tools.audio.source import AudioError, Line, Source, number
from tools.audio.trace import Channel, Trace, delay, frequency


def miniature(commands, family=1):
    section = (family, 'Music')
    data = bytearray()
    positions = []
    nodes = {}
    for op, args in commands:
        offset = len(data)
        positions.append(offset)
        encoded = encode(op, [str(a) for a in args], lambda x: int(x))
        nodes[(section, offset)] = Command(Line('fixture.asm', len(positions), op), op, args, 'Fixture', offset, encoded)
        data.extend(encoded)
    catalog = SimpleNamespace(commands=nodes, sections={section: data}, notes=[0xf82c, 0xf89d, 0xf907, 0xf96b, 0xf9ca, 0xfa23, 0xfa77, 0xfac7, 0xfb12, 0xfb58, 0xfb9b, 0xfbda])
    tracer = Trace(catalog, family)
    tracer.channels[0] = Channel(pc=(section, 0), asset='fixture')
    return tracer, positions


class AudioArithmeticTests(unittest.TestCase):
    def test_delay_boundaries(self):
        self.assertEqual(delay(3, 12, 160, 0), (30, 0))
        self.assertEqual(delay(1, 12, 160, 0), (15, 0))
        self.assertEqual(delay(0, 1, 129, 0), (0, 129))
        self.assertEqual(delay(0, 1, 129, 129), (1, 2))
        self.assertEqual(delay(15, 16, 256, 99), (0, 99))  # 8-bit first product
        self.assertEqual(delay(14, 15, 65535, 255), (0, 30))  # 16-bit accumulator wrap
        self.assertEqual(delay(0, 0, 256, 0), (0, 0))

    def test_expression_is_not_python_execution(self):
        self.assertEqual(number('$10 | %11 << 4'), 48)
        for text in ['__import__("os")', 'x.y', '[1][0]']:
            with self.assertRaises(AudioError): number(text)

    def test_octave_uses_signed_period_shifts(self):
        self.assertEqual(frequency([0xf82c]*12, 0, 7), 0x002c)
        self.assertEqual(frequency([0xf82c]*12, 0, 4), 0x0705)
        with self.assertRaises(AudioError): frequency([0]*12, 12, 0)

    def test_zero_delay_wraps_instead_of_decoding(self):
        t, _ = miniature([('note_type', [0, 1, 0]), ('note', ['C_', 1]), ('sound_ret', [])])
        r = t.run(258)
        self.assertEqual(r['status'], 'ended')
        self.assertEqual(r['ticks'], 257)
        release = [e for e in r['events'] if e['kind'] == 'ownership']
        self.assertEqual(release[-1]['tick'], 256)

    def test_fraction_and_shared_tempo_reset(self):
        t, _ = miniature([('tempo', [129]), ('note_type', [1, 1, 0]), ('note', ['C_', 2]), ('tempo', [256]), ('note', ['C_', 1]), ('sound_ret', [])])
        t.channels[1].fraction = 99
        r = t.run(10)
        notes = [e for e in r['events'] if e['kind'] == 'delay']
        self.assertEqual([(n['counter'], n['fraction']) for n in notes], [(1, 2), (1, 0)])
        self.assertEqual(t.channels[1].fraction, 0)

    def test_finite_loop_count_and_infinite_state_detection(self):
        t, _ = miniature([('note', ['C_', 1]), ('sound_loop', [3, '0']), ('sound_ret', [])])
        r = t.run(20)
        self.assertEqual(r['status'], 'ended')
        self.assertEqual(len([e for e in r['events'] if e['kind'] == 'delay']), 3)
        t, _ = miniature([('note', ['C_', 1]), ('sound_loop', [0, '0'])])
        self.assertEqual(t.run(20)['status'], 'repeat')

    def test_zero_time_cycle_fails_with_location(self):
        t, _ = miniature([('sound_loop', [0, '0'])])
        with self.assertRaisesRegex(AudioError, 'fixture.asm:1: zero-time'):
            t.run(20)

    def test_call_uses_one_return_slot(self):
        # 0:call 4; 3:ret; 4:call 8; 7:ret; 8:note; 9:ret.
        t, _ = miniature([('sound_call', ['4']), ('sound_ret', []), ('sound_call', ['8']), ('sound_ret', []), ('note', ['C_', 1]), ('sound_ret', [])])
        r = t.run(10)
        self.assertEqual(r['status'], 'ended')
        self.assertEqual(t.channels[0].pc, None)
        # Nested call overwrote address 3 with address 7, and the first return clears the slot.
        self.assertEqual(len([e for e in r['events'] if e['kind'] == 'delay']), 1)

    def test_unsupported_byte_is_not_silence(self):
        t, _ = miniature([('unknownmusic0xef', [1])])
        with self.assertRaisesRegex(AudioError, 'fixture.asm:1: unsupported'):
            t.run(5)

    def test_music_score_advances_while_voice_stolen(self):
        t, _ = miniature([('note', ['C_', 1]), ('note', ['D_', 1]), ('sound_ret', [])])
        t.channels[4] = Channel(asset='external-sfx')
        r = t.run(4)
        self.assertEqual(len([e for e in r['events'] if e['kind'] == 'delay']), 2)
        self.assertFalse(any(e['kind'] == 'write' and e['owner'] == 1 and e['register'] != 'ff25' for e in r['events']))

    def test_duty_and_vibrato_register_boundaries(self):
        t, _ = miniature([('duty_cycle_pattern', [0, 1, 2, 3]), ('vibrato', [0, 3, 0]), ('note', ['C_', 4]), ('sound_ret', [])])
        r = t.run(10)
        duty = [e['value']>>6 for e in r['events'] if e['kind'] == 'write' and e['register'] == 'ff11']
        self.assertEqual(duty, [0, 1, 2, 3])
        low = [e['value'] for e in r['events'] if e['kind'] == 'write' and e['register'] == 'ff13']
        self.assertEqual(low, [0xf0, 0xf2, 0xef, 0xf2])

    def test_pitch_slide_fraction_and_source_borrow_bug(self):
        t, _ = miniature([('octave', [4]), ('pitch_slide', [1, 4, 'D_']), ('note', ['C_', 4]), ('sound_ret', [])])
        r = t.run(6)
        low = [e['value'] for e in r['events'] if e['kind'] == 'write' and e['register'] == 'ff13']
        self.assertEqual(low, [5, 12, 19, 26])
        # 0x060b - 0x0416 is 501; the documented source borrow bug adds 512.
        t, _ = miniature([('octave', [2]), ('pitch_slide', [1, 3, 'C_']), ('note', ['C_', 4]), ('sound_ret', [])])
        t.run(1)
        self.assertEqual(t.channels[0].slide['step'], 254)
        self.assertEqual(t.channels[0].slide['fraction'], 1)

    def test_pitch_slide_zero_divisor_fails_closed(self):
        t, _ = miniature([('pitch_slide', [2, 4, 'C_']), ('note', ['C_', 1])])
        with self.assertRaisesRegex(AudioError, 'fixture.asm:2: pitch_slide source division'):
            t.run(3)

    def test_unknown_conditional_fails_with_location(self):
        source = Source.__new__(Source)
        with patch.object(Source, 'read', return_value='IF DEF(_GREEN)\nrest 1\nENDC\n'):
            with self.assertRaisesRegex(AudioError, 'conditional.asm:1: unsupported conditional'):
                list(source.lines('conditional.asm'))

    def test_bound_is_explicit(self):
        t, _ = miniature([('note', ['C_', 16]), ('sound_ret', [])])
        self.assertEqual(t.run(3)['status'], 'bound')


class AudioSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        root = os.environ.get('POKERED_REFERENCE_DIR')
        if not root:
            raise AssertionError('source ~/Developer/Pokemon-PlayDate-env/env.sh; pinned source required, no skips')
        cls.catalog = Catalog(Source(root))

    def test_complete_reference_closure_and_routes(self):
        c = self.catalog
        self.assertEqual(len(c.headers), 362)
        self.assertEqual(len(c.maps), 248)
        self.assertEqual(len(c.moves), 165)
        self.assertIn('sentinel', c.move_sentinel['purpose'])
        self.assertEqual(len(c.cries), 151)
        cries = {x['species']: x for x in c.cries}
        self.assertEqual(cries['rhydon']['internal_id'], 1)
        self.assertEqual(cries['rhydon']['dex_id'], 112)
        self.assertEqual(cries['bulbasaur']['dex_id'], 1)
        self.assertNotEqual(cries['bulbasaur']['internal_id'], 1)
        maps = {x['map']: x['asset'] for x in c.maps}
        self.assertEqual(maps['VIRIDIAN_MART'], 'audio1:Music_Pokecenter')
        self.assertEqual(maps['ROUTE_3'], 'audio1:Music_Routes3')
        self.assertEqual(maps['VIRIDIAN_FOREST'], 'audio3:Music_Dungeon2')

    def test_header_entry_count_and_bank_local_ids(self):
        c = self.catalog
        pallet = c.headers['audio1:Music_PalletTown']
        self.assertEqual([x['header_byte'] for x in pallet['channels']], [128, 1, 2])
        cities = c.headers['audio1:Music_Cities1']
        self.assertEqual([x['header_byte'] for x in cities['channels']], [192, 1, 2, 3])
        for header in c.headers.values():
            self.assertEqual(header['id']*3, header['header_offset'])
            self.assertEqual(header['bank'], {1: 2, 2: 8, 3: 31}[header['family']])

    def test_wrong_variant_rejected(self):
        t = Trace(self.catalog, 1)
        t.load('audio1:Music_PalletTown')
        with self.assertRaisesRegex(AudioError, 'requires its source base asset'):
            t.variant('Music_RivalAlternateStart')

    def test_blue_branch_and_bank_scopes(self):
        c = self.catalog
        section, offset = c.target(3, 'SFX_Save_3_Ch5')
        self.assertEqual(c.sections[section][offset:offset+6].hex(), 'ec0223e40006')
        self.assertEqual(len(c.conditionals), 2)
        self.assertNotEqual(c.target(1, 'Audio1_WavePointers.wave5')[0], c.target(3, 'Audio3_WavePointers.wave5')[0])
        self.assertTrue(all('audio' in ref['target'] for ref in c.references))

    def test_audited_bytes_and_mutation_failure(self):
        c = self.catalog
        report = qualify_bytes(c)
        self.assertEqual(report['macro_cases'], 22)
        section, offset = c.target(2, 'Audio2_WavePointers.wave5')
        original = c.sections[section][offset]
        c.sections[section][offset] ^= 1
        try:
            with self.assertRaisesRegex(AudioError, 'wave5 fixture mismatch'):
                qualify_bytes(c)
        finally:
            c.sections[section][offset] = original

    def test_dirty_consumed_input_rejected(self):
        source = Source(self.catalog.source.root)
        original = Path.read_bytes
        def mutate(path):
            value = original(path)
            return value+b'; mutation\n' if path.name == 'pallettown.asm' else value
        with patch.object(Path, 'read_bytes', mutate):
            with self.assertRaisesRegex(AudioError, 'pallettown.asm:1: consumed source differs'):
                source.read('audio/music/pallettown.asm')

    def test_pallet_source_ticks_and_determinism(self):
        results = []
        for _ in range(2):
            t = Trace(self.catalog, 1)
            t.load('audio1:Music_PalletTown')
            r = t.run(100)
            notes = [e for e in r['events'] if e['kind'] == 'delay' and e['channel'] == 1]
            self.assertEqual([e['tick'] for e in notes[:2]], [0, 30])
            self.assertEqual([e['counter'] for e in notes[:2]], [30, 15])
            results.append(canonical(r))
        self.assertEqual(*results)

    def test_cry_unsigned_modifiers_and_wait(self):
        t = Trace(self.catalog, 2)
        t.load('audio2:SFX_Cry00_2', 255, 192)
        r = t.run(20000)
        self.assertEqual(r['status'], 'ended')
        delays = [e for e in r['events'] if e['kind'] == 'delay']
        self.assertEqual({e['tempo'] for e in delays if e['channel'] in (5, 6)}, {320})
        self.assertEqual({e['tempo'] for e in delays if e['channel'] == 8}, {256})
        self.assertFalse(any(ch.asset for ch in t.channels))

    def test_alarm_off_by_one_and_silence(self):
        t = Trace(self.catalog, 2)
        r = t.run(40, alarm=True)
        tones = [e for e in r['events'] if e['kind'] == 'write' and e['register'] == 'ff13']
        self.assertEqual([(e['tick'], e['value']) for e in tones[:3]], [(0, 0x50), (11, 0xee), (31, 0x50)])
        t.alarm = 255
        t.low_health()
        self.assertEqual(t.registers[0xff14], 128)
        self.assertEqual(t.alarm, 0)

    def test_sfx_restart_preserves_source_fraction_and_note_settings(self):
        t = Trace(self.catalog, 2)
        t.channels[4].fraction = 137
        t.channels[4].octave = 4
        t.channels[4].volume = 32
        t.load('audio2:SFX_Cry00_2')
        self.assertEqual(t.channels[4].fraction, 137)
        self.assertEqual(t.channels[4].octave, 4)
        self.assertEqual(t.channels[4].volume, 32)
        self.assertEqual(t.channels[4].speed, 1)

    def test_scheduled_requests_preserve_unspecified_shared_modifiers(self):
        t = Trace(self.catalog, 1)
        t.load('audio1:SFX_Cry00_1', 255, 192)
        t.run(10, scheduled=[{'tick': 1, 'asset': 'audio1:SFX_Collision_1'}])
        self.assertEqual((t.pitch_modifier, t.tempo_modifier), (255, 192))

    def test_numeric_priority_and_noise_exception(self):
        c = self.catalog
        drums = sorted((h for h in c.headers.values() if h['family'] == 1 and h['label'].startswith('SFX_Noise_')), key=lambda h: h['id'])
        t = Trace(c, 1)
        t.load(drums[0]['key'])
        t.load(drums[1]['key'])
        self.assertEqual(t.channels[7].asset, drums[0]['key'])
        self.assertEqual(t.events[-1]['kind'], 'reject')


if __name__ == '__main__':
    unittest.main()
