"""Independent macro timing/effect arithmetic for the two honest closure limits."""
import math
import os
import unittest

from tools.audio.catalog import Catalog
from tools.audio.source import Source, number, parts
from tools.audio.trace import Trace


CASES = (
    ('Lavender', 1, 152, (2280, 114, 3648, 114), (9, 1, 2, 1), 328320),
    ('Dungeon1', 3, 144, (3996, 3996, 3996, 3996), (5, 12, 7, 1), 1678320),
)


def source_schedule(source, name, channel, tempo):
    """Walk original macros, not encoded bytes or Trace's delay/control helpers.

    These two fixed-tempo scores have one return slot, one finite-loop counter,
    and positive delays. Fail if they acquire unsupported scheduling semantics.
    The engine decrements delay once per intervening tick, then vibrato delay,
    then its rate counter. Notes reload vibrato delay but not rate/direction.
    """
    labels = {}
    commands = []
    scope = ''
    for line in source.lines(f'audio/music/{name.lower()}.asm'):
        if line.text.endswith(':'):
            label = line.text.rstrip(':')
            if not label.startswith('.'):
                scope = label
            labels[scope + label if label.startswith('.') else label] = len(commands)
        else:
            commands.append((scope, line))
    pc = labels[f'Music_{name}_Ch{channel}']
    returned = None
    counter = 1
    speed = 1
    vibrato_delay = 0
    rate = None
    units = 0
    effect_ticks = 0
    timed = []
    laps = []
    for _ in range(10000):
        scope, line = commands[pc]
        pc += 1
        op, args = parts(line)
        if op in ('note_type', 'drum_speed'):
            speed = number(args[0])
        elif op == 'tempo':
            assert units == 0 and number(args[0]) == tempo
        elif op == 'vibrato':
            vibrato_delay, _, rate = map(number, args)
        elif op in ('note', 'rest', 'drum_note'):
            start = units * tempo // 256
            units += number(args[-1]) * speed
            end, fraction = divmod(units * tempo, 256)
            duration = end - start
            assert 0 < duration < 256
            timed.append({'tick': start, 'counter': duration,
                          'fraction': fraction, 'source': line.location})
            if rate is not None:
                effect_ticks += max(0, duration - 1 - vibrato_delay)
        elif op == 'sound_call':
            returned = pc
            pc = labels[scope + args[0] if args[0].startswith('.') else args[0]]
        elif op == 'sound_ret':
            assert returned is not None
            pc, returned = returned, None
        elif op == 'sound_loop':
            count = number(args[0])
            target = labels[scope + args[1] if args[1].startswith('.') else args[1]]
            if not count:
                laps.append((units * tempo // 256, effect_ticks))
                if len(laps) == 3:
                    break
                pc = target
            elif counter == count:
                counter = 1
            else:
                counter += 1
                pc = target
        elif op not in ('volume', 'duty_cycle', 'toggle_perfect_pitch',
                        'octave', 'stereo_panning'):
            raise AssertionError(f'unsupported diagnostic macro: {line.location}: {op}')
    else:
        raise AssertionError('independent source walk exceeded command budget')
    period = laps[1][0] - laps[0][0]
    effects = laps[1][1] - laps[0][1]
    assert laps[2][0] - laps[1][0] == period
    assert laps[2][1] - laps[1][1] == effects
    # One direction toggle every rate+1 eligible effect ticks; two toggles close.
    effect_period = 2 * (rate + 1) if rate is not None else 1
    multiplier = effect_period // math.gcd(effects, effect_period)
    return timed, period, multiplier


class LoopProbe(Trace):
    """Observe source loop entries; leave events and full recurrence key intact."""
    def __init__(self, catalog, family, name):
        super().__init__(catalog, family)
        self.loop_targets = {catalog.target(family, f'Music_{name}_Ch{i}.mainloop'): i
                             for i in range(1, 5)}
        self.phases = {i: [] for i in range(1, 5)}

    def jump(self, channel, offset):
        super().jump(channel, offset)
        index = self.loop_targets.get(channel.pc)
        if index:
            self.phases[index].append((channel.vibrato_rate, channel.vibrato_direction))


class AudioLoopClosureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        root = os.environ.get('POKERED_REFERENCE_DIR')
        if not root:
            raise AssertionError('pinned POKERED_REFERENCE_DIR required; no skips')
        cls.catalog = Catalog(Source(root))
        cls.traces = {}
        for name, family, *_ in CASES:
            tracer = LoopProbe(cls.catalog, family, name)
            tracer.load(f'audio{family}:Music_{name}')
            cls.traces[name] = (tracer, tracer.run())

    def test_default_resource_limit_remains_an_explicit_rejection(self):
        for name, *_ in CASES:
            with self.subTest(track=name):
                _, result = self.traces[name]
                self.assertEqual(result['status'], 'bound')
                self.assertEqual(result['ticks'], 119999)
                self.assertIsNone(result['repeat'])

    def test_independent_source_onsets_match_transport(self):
        for name, _, tempo, periods, multipliers, combined in CASES:
            tracer, result = self.traces[name]
            for channel in range(1, 5):
                with self.subTest(track=name, channel=channel):
                    expected, period, multiplier = source_schedule(
                        self.catalog.source, name, channel, tempo)
                    actual = [{key: event[key] for key in expected[0]}
                              for event in result['events']
                              if event['kind'] == 'delay' and event['channel'] == channel]
                    self.assertEqual(actual[:len(expected)], expected)
                    self.assertEqual(period, periods[channel - 1])
                    self.assertEqual(multiplier, multipliers[channel - 1])
            self.assertEqual(math.lcm(*(p * m for p, m in zip(periods, multipliers))), combined)

    def test_vibrato_phase_carries_across_score_loops(self):
        for name, _, _, _, multipliers, _ in CASES:
            tracer, _ = self.traces[name]
            for channel, multiplier in enumerate(multipliers, 1):
                if channel == 4:
                    continue  # Music noise dispatches instruments, not vibrato.
                with self.subTest(track=name, channel=channel):
                    phases = tracer.phases[channel]
                    self.assertGreater(len(phases), multiplier)
                    self.assertEqual(len(set(phases[:multiplier])), multiplier)
                    self.assertEqual(phases[multiplier], phases[0])


if __name__ == '__main__':
    unittest.main()
