"""Host renderer and the observer paths that do not need another lane."""
import math
import re
import struct
import subprocess
import unittest
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ENGINE = ROOT / 'tools/audio/host_engine.lua'


def observe(kind):
    proc = subprocess.run(
        ['lua', str(ENGINE), 'observe', kind],
        check=True, capture_output=True, text=True,
    )
    calls = []
    for line in proc.stdout.splitlines():
        if line.startswith('call\t'):
            _, name, arg = line.split('\t', 2)
            calls.append((name, arg))
    return calls


def clip(kind):
    from tools.audio.host_render import schedule, synthesize, peak_of
    notes = schedule(kind)
    pcm, _count = synthesize(notes)
    return notes, peak_of(pcm)


def _score_parts(text):
    """Part tables, ignoring a trailing shape table inside a note."""
    parts = {}
    for match in re.finditer(r'\{ticks=(\d+), loop=(\d+), notes=\{', text):
        ticks, loop = int(match.group(1)), int(match.group(2))
        depth = 1
        index = match.end()
        while depth:
            if text[index] == '{':
                depth += 1
            elif text[index] == '}':
                depth -= 1
            index += 1
        body = text[match.end():index - 1]
        rows = []
        cursor = 0
        while True:
            start = body.find('{', cursor)
            if start < 0:
                break
            depth = 0
            end = start
            while end < len(body):
                if body[end] == '{':
                    depth += 1
                elif body[end] == '}':
                    depth -= 1
                    if depth == 0:
                        break
                end += 1
            literal = body[start + 1:end]
            nested = literal.find('{')
            head = literal if nested < 0 else literal[:nested]
            values = []
            for item in head.split(','):
                item = item.strip()
                if not item:
                    continue
                if item.startswith('"'):
                    values.append(item.strip('"'))
                elif '.' in item:
                    values.append(float(item))
                else:
                    values.append(int(item))
            if values and isinstance(values[0], int):
                rows.append(values)
            cursor = end + 1
        parts[rows[0][1]] = {'ticks': ticks, 'loop': loop, 'notes': rows}
    return parts


class HostRendererTests(unittest.TestCase):
    def test_route_render_is_audible_pcm(self):
        import tempfile
        from tools.audio.host_render import synthesize, write_wav
        notes, peak = clip('route1')
        self.assertGreater(peak, 1000)
        self.assertTrue(any(note['kind'] == 'square' for note in notes))
        pcm, _count = synthesize(notes)
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'route1.wav'
            write_wav(path, pcm)
            with wave.open(str(path), 'rb') as stream:
                self.assertEqual(
                    (stream.getnchannels(), stream.getsampwidth(), stream.getframerate()),
                    (1, 2, 44100),
                )
                frames = stream.readframes(stream.getnframes())
        samples = struct.unpack('<' + 'h' * (len(frames) // 2), frames)
        self.assertGreater(max(abs(sample) for sample in samples), 1000)

    def test_mansion_seam_is_not_a_joint_restart(self):
        import re
        from tools.audio.host_render import mansion_seam
        notes, peak = clip('mansion')
        self.assertGreater(peak, 1000)
        seam = mansion_seam(notes)
        self.assertEqual(set(seam), {1, 2, 3, 4})
        text = (ROOT / 'Source/audio/score/mansion.lua').read_text()
        parts = _score_parts(text)

        def phase(part, tick):
            if tick < part['ticks']:
                return tick
            span = part['ticks'] - part['loop']
            return part['loop'] + (tick - part['loop']) % span

        def hz_at(part, stamp):
            chosen = None
            for note in part['notes']:
                if note[0] <= stamp and (chosen is None or note[0] >= chosen[0]):
                    chosen = note
            self.assertIsNotNone(chosen)
            self.assertGreater(chosen[0] + chosen[2], stamp)
            return max(20, min(16000, chosen[3]))

        # Channel 1 is back at its label, on that note's attack (vibrato and
        # slides have not stepped yet). Channels 2 and 3 are not on the note
        # at their own loop point. Mid-phrase pitch includes vibrato, so it
        # is not compared to the stored attack.
        self.assertEqual(seam[1]['hz'], hz_at(parts[1], phase(parts[1], 9315)))
        self.assertEqual(phase(parts[1], 9315), 0)
        self.assertAlmostEqual(seam[1]['hz'], 1310.72, places=2)
        for voice, expected in ((2, 2403), (3, 1539), (4, 243)):
            part = parts[voice]
            self.assertEqual(phase(part, 9315), expected)
        self.assertNotEqual(seam[2]['hz'], hz_at(parts[2], parts[2]['loop']))
        self.assertNotEqual(seam[3]['hz'], hz_at(parts[3], parts[3]['loop']))

    def test_trainer_clip_plays_the_jingle_and_then_the_bed(self):
        notes, peak = clip('trainer')
        self.assertGreater(peak, 1000)
        self.assertGreater(notes[-1]['t'], 3.5)
        # ticksFor(3.5) is 209 source ticks, 3.4992 s. The jingle is still
        # playing just before that. BlueBot's 3.478 s bed is a template-match
        # offset of about 22 ms, not this cut, so the scheduler stays put.
        tick = 70224 / 4194304
        cut = math.floor(3.5 / tick + 0.5) * tick
        bed = min(
            note['t'] for note in notes
            if note['voice'] == 2 and abs(note['hz'] - 879.6779) < 0.01 and note['t'] > 3
        )
        self.assertAlmostEqual(bed, cut, delta=0.0001)

    def test_pitch_slide_steps_through_the_intermediate_periods(self):
        # Audio1_ApplyPitchSlide on the heal ch1 slide: current 2039, target
        # 1915, step 9, fraction 12, decreasing. Tick 0 is the perfect-pitch
        # register 2040. The old score held the target, 985.5038 Hz.
        proc = subprocess.run(
            ['lua', str(ENGINE), 'shape'],
            check=True, capture_output=True, text=True,
        )
        direct = {}
        engine = {}
        adsr = None
        gains = {}
        for line in proc.stdout.splitlines():
            fields = line.split('\t')
            if fields[0] == 'direct' and fields[1] == 'slide':
                direct[int(fields[2])] = (int(fields[3]), float(fields[4]))
            elif fields[0] == 'direct' and fields[1] == 'vibrato':
                direct[('vib', int(fields[2]))] = (int(fields[3]), float(fields[4]))
            elif fields[0] == 'direct' and fields[1] == 'adsr':
                adsr = tuple(float(value) for value in fields[2:])
            elif fields[0] == 'direct' and fields[1] == 'gain':
                gains[float(fields[2])] = float(fields[3])
            elif fields[0] == 'engine':
                engine.setdefault(fields[1], {})[int(fields[2])] = (
                    float(fields[3]), tuple(float(value) for value in fields[4:])
                )
        self.assertEqual(
            [direct[elapsed][0] for elapsed in (0, 1, 5, 13)],
            [2040, 2030, 1993, 1920],
        )
        self.assertEqual(direct[0][1], 16000)
        self.assertAlmostEqual(direct[1][1], 7281.7778, places=4)
        self.assertNotAlmostEqual(direct[1][1], 985.5038, places=1)
        for elapsed in (0, 1, 5, 13):
            played, played_adsr = engine['probe_slide'][elapsed]
            self.assertAlmostEqual(played, direct[elapsed][1], places=4)
            # envelope 129 is volume 8, pace 1: decay 8/64 s.
            self.assertEqual(played_adsr, (0.0, 8 / 64, 0.0, 0.002))
        # note_type 12, 12, 1 is byte 193: decay 12/64 s, no attack.
        self.assertEqual(adsr, (0.0, 12 / 64, 0.0, 0.002))
        self.assertAlmostEqual(gains[0.0], 1.0, places=4)
        self.assertAlmostEqual(gains[6 / 64], 0.5, places=4)
        self.assertAlmostEqual(gains[12 / 64], 0.0, places=4)
        # Extent 4 toggles +2 then -2 around the note-on low byte. Both the
        # direct curve and a real KantoSynth.update land on those periods.
        self.assertEqual(
            [direct[('vib', elapsed)][0] for elapsed in (0, 1, 2)],
            [100, 102, 98],
        )
        for elapsed in (0, 1, 2):
            played, played_adsr = engine['probe_vib'][elapsed]
            self.assertAlmostEqual(played, direct[('vib', elapsed)][1], places=4)
            self.assertEqual(played_adsr, (0.0, 0.0, 1.0, 0.002))
        env_hz, env_adsr = engine['probe_env'][0]
        self.assertAlmostEqual(env_hz, 440.0, places=4)
        self.assertEqual(env_adsr, (0.0, 12 / 64, 0.0, 0.002))
        host = ENGINE.read_text()
        engine_src = (ROOT / 'Source/audio/engine.lua').read_text()
        self.assertIn('KantoShape.gain', host)
        self.assertNotIn('pace', host)
        self.assertIn('KantoShape.adsr', engine_src)
        self.assertIn('KantoShape.hz', engine_src)
        self.assertNotIn('envelopeTime', engine_src)

    def test_heal_score_stores_the_glide_instead_of_the_target(self):
        text = (ROOT / 'Source/audio/score/heal.lua').read_text()
        self.assertIn('s={2039,1915,9,12,1}', text)
        self.assertNotRegex(text, r'\{13,1,14,985\.5038,')


class ObserverGapTests(unittest.TestCase):
    def test_title_clock_plays_crash_whoosh_music_and_the_attract_cry(self):
        calls = observe('title')
        self.assertIn(('sfx', 'intro_crash'), calls)
        self.assertIn(('sfx', 'intro_whoosh'), calls)
        self.assertLess(calls.index(('sfx', 'intro_crash')), calls.index(('sfx', 'intro_whoosh')))
        self.assertLess(calls.index(('sfx', 'intro_whoosh')), calls.index(('music', 'title')))
        self.assertLess(calls.index(('music', 'title')), calls.index(('cry', 'squirtle')))

    def test_leaving_the_title_cries_the_shown_species(self):
        calls = observe('leave-title')
        self.assertIn(('cry', 'squirtle'), calls)

    def test_cancelled_evolution_cries_the_old_species(self):
        calls = observe('cancel-evolution')
        self.assertIn(('cry', 'pidgey'), calls)
        cancel = len(calls) - 1 - calls[::-1].index(('cry', 'pidgey'))
        self.assertEqual(calls[cancel - 1], ('music', 'nil'))
        self.assertIn(('music', 'safari'), calls)

    def test_completed_evolution_stops_the_bed_then_cries_the_new_species(self):
        calls = observe('complete-evolution')
        done = calls.index(('cry', 'pidgeotto'))
        self.assertEqual(calls[done - 1], ('music', 'nil'))

    def test_receipt_label_plays_its_fanfare_once(self):
        calls = observe('receipt')
        self.assertEqual([call for call in calls if call[0] == 'jingle'], [('jingle', 'item')])

    def test_oak_dialog_in_pallet_plays_meet_oak(self):
        story = (ROOT / 'Source/game/story.lua').read_text()
        audio = (ROOT / 'Source/game/kantoAudio.lua').read_text()
        line = 'OAK: Hey! Wait! Don\'t go out!'
        self.assertIn(line, story)
        self.assertIn(line, audio)
        calls = observe('meet-oak')
        self.assertEqual([call for call in calls if call == ('jingle', 'meet_oak')], [('jingle', 'meet_oak')])


if __name__ == '__main__':
    unittest.main()
