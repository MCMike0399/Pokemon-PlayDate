"""Host renderer and the observer paths that do not need another lane."""
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
        parts = {}
        for ticks, loop, body in re.findall(r'\{ticks=(\d+), loop=(\d+), notes=\{(.*?)\}\}', text, re.S):
            rows = []
            for row in re.findall(r'\{([^{}]+)\}', body):
                values = []
                for item in row.split(','):
                    item = item.strip()
                    if item.startswith('"'):
                        values.append(item.strip('"'))
                    elif '.' in item:
                        values.append(float(item))
                    else:
                        values.append(int(item))
                rows.append(values)
            parts[rows[0][1]] = {'ticks': int(ticks), 'loop': int(loop), 'notes': rows}

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

        # Channel 1 is back at its label. Channels 2 and 3 are on a different
        # pitch than the note at their own loop point.
        self.assertEqual(seam[1]['hz'], hz_at(parts[1], phase(parts[1], 9315)))
        self.assertEqual(phase(parts[1], 9315), 0)
        for voice, expected in ((2, 2403), (3, 1539), (4, 243)):
            part = parts[voice]
            self.assertEqual(phase(part, 9315), expected)
            self.assertEqual(seam[voice]['hz'], hz_at(part, expected))
        self.assertNotEqual(seam[2]['hz'], hz_at(parts[2], parts[2]['loop']))
        self.assertNotEqual(seam[3]['hz'], hz_at(parts[3], parts[3]['loop']))

    def test_trainer_clip_plays_the_jingle_and_then_the_bed(self):
        notes, peak = clip('trainer')
        self.assertGreater(peak, 1000)
        self.assertGreater(notes[-1]['t'], 3.5)


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
