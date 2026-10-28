#!/usr/bin/env python3
"""Offline schema-1 register IR -> canonical 44100 Hz stereo PCM16 reference WAVs.

No source checkout, ROM, network, playback, optional packages or SDK required.
This is an explicitly phased digital model, not a hardware-fidelity claim.
"""
from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import hashlib
import json
from pathlib import Path
import struct
import sys
import wave

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.audio.source import AudioError

RATE = 44100
CLOCK = 4194304
TICK = 70224
DUTIES = ((0,0,0,0,0,0,0,1), (1,0,0,0,0,0,0,1),
          (1,0,0,0,0,1,1,1), (0,1,1,1,1,1,1,0))
BASES = (0xff10, 0xff15, 0xff1a, 0xff1f)
LIMITATIONS = [
    'No independent APU execution oracle or listening acceptance.',
    'All writes within a source tick are instantaneous in recorded order; CPU instruction timing is absent from IR.',
    'Initial DIV-APU phase is fixed: first length step at cycle 8192; physical boot/entry phase is unknown.',
    'Pulse trigger reload rounds to whole dot periods; low-two-divider-bit trigger quirk is not modeled.',
    'Wave trigger access-window corruption and model-specific DAC fades are not modeled.',
    'Digital pre-HPF mix only: no analog high-pass, speaker response, VIN, dither or normalization.',
    'Box-integrated sample intervals are deterministic but not a bandlimited reconstruction.',
    'Score recurrence does not establish PCM recurrence; no loopable asset acceptance.',
    'SDK scheduling, phase continuity and dynamic channel stealing feasibility remain pending.',
]


def canonical(value):
    return json.dumps(value, sort_keys=True, indent=2)+'\n'


def sample_index(tick):
    """Floor of absolute rational time, never a per-tick rounded increment."""
    return tick * TICK * RATE // CLOCK


def signed_div(n, d):
    return (1 if n >= 0 else -1) * (abs(n)//d)


@dataclass
class Voice:
    active: bool = False
    dac: bool = False
    length: int = 0
    length_enabled: bool = False
    frequency: int = 0
    duty: int = 0
    position: int = 0
    buffer: int = 0
    first: bool = True
    volume: int = 0
    envelope: int = 0
    env_timer: int = 0
    env_running: bool = False
    deadline: int | None = None
    lfsr: int = 0
    sweep_shadow: int = 0
    sweep_timer: int = 0
    sweep_enabled: bool = False
    sweep_negated: bool = False


class APU:
    """Integer event scheduler. Time units are 1/(CLOCK*RATE) seconds."""
    def __init__(self):
        self.time = 0
        self.frame_deadline = 8192*RATE
        self.frame_step = 0
        self.power = False
        self.registers = {}
        self.ram = [0]*32
        self.voices = [Voice() for _ in range(4)]

    def period(self, i):
        v = self.voices[i]
        if i < 3:
            return (2048-v.frequency)*(2 if i == 2 else 4)*RATE
        nr43 = self.registers.get(0xff22, 0)
        if nr43 >> 4 >= 14:
            return None
        divisor = nr43 & 7
        return (8 if divisor == 0 else divisor*16)*(1 << (nr43>>4))*RATE

    def sweep_calculate(self):
        v = self.voices[0]
        control = self.registers.get(0xff10, 0)
        delta = v.sweep_shadow >> (control & 7)
        if control & 8:
            v.sweep_negated = True
            return v.sweep_shadow-delta
        return v.sweep_shadow+delta

    def trigger(self, i):
        v = self.voices[i]
        v.active = v.dac
        if v.length == 0:
            v.length = 256 if i == 2 else 64
            if v.length_enabled and self.frame_step % 2:
                v.length -= 1
        period = self.period(i)
        v.deadline = self.time+period if period else None
        if i == 2:
            v.position = 0  # Buffer is intentionally retained until next fetch.
        else:
            v.volume = v.envelope >> 4
            v.env_timer = (v.envelope & 7) or 8
            if self.frame_step == 7:
                v.env_timer += 1
            v.env_running = True
            if i == 3:
                v.lfsr = 0
        if i == 0:
            nr10 = self.registers.get(0xff10, 0)
            v.sweep_shadow = v.frequency
            v.sweep_timer = (nr10>>4 & 7) or 8
            v.sweep_enabled = bool(nr10 & 0x77)
            v.sweep_negated = False
            if nr10 & 7 and self.sweep_calculate() > 2047:
                v.active = False

    def write(self, address, value):
        if type(value) is not int or not 0 <= value <= 255:
            raise AudioError('register value must be an unsigned byte')
        if 0xff30 <= address <= 0xff3f:
            if self.voices[2].active:
                raise AudioError('unsupported active wave RAM write')
            n = (address-0xff30)*2
            self.ram[n:n+2] = [value>>4, value & 15]
            return
        if not 0xff10 <= address <= 0xff26:
            raise AudioError(f'unsupported register {address:04x}')
        if address in (0xff15, 0xff1f):
            return  # Unused hardware addresses.
        if address == 0xff26:
            if not value & 128:
                self.power = False
                self.registers.clear()
                self.voices = [Voice() for _ in range(4)]
            else:
                self.power = True
            return
        if not self.power:
            raise AudioError('unsupported register write while APU powered off')
        if address == 0xff24 and value & 0x88:
            raise AudioError('unsupported external VIN input')
        self.registers[address] = value
        if address >= 0xff24:
            return
        i = next(n for n, base in reversed(list(enumerate(BASES))) if address >= base)
        offset = address-BASES[i]
        v = self.voices[i]
        if offset == 0:
            if i == 2:
                v.dac = bool(value & 128)
                if not v.dac:
                    v.active = False
                    v.deadline = None
            elif i == 0 and v.sweep_negated and not value & 8:
                v.active = False
        elif offset == 1:
            v.length = (256-value) if i == 2 else 64-(value & 63)
            v.duty = value >> 6
        elif offset == 2:
            if i != 2:
                v.envelope = value
                v.dac = bool(value & 0xf8)
                if not v.dac: v.active = False
        elif offset == 3:
            if i < 3: v.frequency = (v.frequency & 0x700) | value
        elif offset == 4:
            if i < 3: v.frequency = (v.frequency & 255) | ((value & 7)<<8)
            enabled = bool(value & 64)
            if enabled and not v.length_enabled and self.frame_step % 2 and v.length:
                v.length -= 1
                if not v.length: v.active = False
            v.length_enabled = enabled
            if value & 128: self.trigger(i)

    def frame(self):
        step = self.frame_step
        if self.power:
            for i, v in enumerate(self.voices):
                if step % 2 == 0 and v.length_enabled and v.length:
                    v.length -= 1
                    if not v.length: v.active = False
                if step == 7 and i != 2:
                    v.env_timer -= 1
                    if v.env_timer <= 0:
                        v.env_timer = (v.envelope & 7) or 8
                        if v.env_running and v.envelope & 7:
                            volume = v.volume+(1 if v.envelope & 8 else -1)
                            if 0 <= volume <= 15: v.volume = volume
                            else: v.env_running = False
            if step in (2, 6):
                v = self.voices[0]
                v.sweep_timer -= 1
                nr10 = self.registers.get(0xff10, 0)
                if v.sweep_timer <= 0:
                    v.sweep_timer = (nr10>>4 & 7) or 8
                    if v.sweep_enabled and nr10 & 0x70:
                        frequency = self.sweep_calculate()
                        if frequency > 2047:
                            v.active = False
                        elif nr10 & 7:
                            v.frequency = v.sweep_shadow = frequency
                            self.registers[0xff13] = frequency & 255
                            self.registers[0xff14] = (self.registers.get(0xff14, 0) & 0xf8) | (frequency>>8)
                            if self.sweep_calculate() > 2047: v.active = False
        self.frame_step = (step+1) % 8
        self.frame_deadline += 8192*RATE

    def oscillator(self, i):
        v = self.voices[i]
        if i < 2:
            v.position = (v.position+1) % 8
            v.first = False
        elif i == 2:
            if v.active:
                v.position = (v.position+1) % 32
                v.buffer = self.ram[v.position]
        else:
            bit = 1 ^ (v.lfsr & 1) ^ ((v.lfsr>>1) & 1)
            v.lfsr = (v.lfsr>>1) | (bit<<14)
            if self.registers.get(0xff22, 0) & 8:
                v.lfsr = (v.lfsr & ~(1<<6)) | (bit<<6)
        period = self.period(i)
        v.deadline = self.time+period if period else None

    def levels(self):
        pan = self.registers.get(0xff25, 0)
        gain = self.registers.get(0xff24, 0)
        output = []
        for i, v in enumerate(self.voices):
            digital = 0
            if v.active:
                if i < 2:
                    digital = v.volume*DUTIES[v.duty][v.position] if not v.first else 0
                elif i == 2:
                    level = self.registers.get(0xff1c, 0)>>5 & 3
                    digital = v.buffer>>(level-1) if level else 0
                else:
                    digital = v.volume*(v.lfsr & 1)
            analog = 15-2*digital if v.dac and self.power else 0
            output.extend((analog*((gain>>4 & 7)+1) if pan & (16<<i) else 0,
                           analog*((gain & 7)+1) if pan & (1<<i) else 0))
        return output

    def integrate(self, target):
        """Exact zero-order-hold area to target, split at every hardware edge."""
        if target < self.time: raise AudioError('time reversal')
        areas = [0]*8
        while self.time < target:
            edge = min([target, self.frame_deadline] + [v.deadline for v in self.voices if v.deadline is not None])
            width = edge-self.time
            for n, level in enumerate(self.levels()): areas[n] += level*width
            self.time = edge
            if edge == self.frame_deadline: self.frame()
            for i, v in enumerate(self.voices):
                if edge == v.deadline: self.oscillator(i)
        return areas

    def snapshot(self):
        voices = [asdict(v) for v in self.voices]
        for v in voices:
            if v['deadline'] is not None: v['deadline'] -= self.time
        return {'voices': voices, 'registers': self.registers.copy(), 'ram': self.ram[:],
                'frame_step': self.frame_step, 'frame_remaining': self.frame_deadline-self.time,
                'power': self.power}


def validate(ir):
    if ir.get('schema') != 1: raise AudioError('unsupported IR schema')
    if ir.get('clock') != {'tick_numerator': TICK, 'tick_denominator': CLOCK, 'unit': 'seconds'}:
        raise AudioError('unsupported source clock; expected exact hardware frame ratio')
    if ir.get('status') not in ('repeat', 'ended'):
        raise AudioError(f"nonclosing trace status {ir.get('status')!r}; bound is not a loop")
    ticks = ir.get('ticks')
    if type(ticks) is not int or ticks <= 0: raise AudioError('invalid terminal tick')
    repeat = ir.get('repeat')
    if ir['status'] == 'repeat':
        if not isinstance(repeat, dict): raise AudioError('missing repeat boundaries')
        start, end = repeat.get('start_tick'), repeat.get('end_tick')
        if type(start) is not int or type(end) is not int or not 0 <= start < end == ticks:
            raise AudioError('invalid repeat boundaries')
    previous = 0
    for e in ir.get('events', []):
        tick = e.get('tick')
        if type(tick) is not int or not previous <= tick < ticks:
            raise AudioError('invalid/out-of-order event tick')
        previous = tick
        if e.get('kind') not in ('write', 'ownership', 'reject', 'delay', 'tempo', 'entry'):
            raise AudioError(f"unsupported event kind {e.get('kind')!r}")
        if e['kind'] == 'write':
            try: address = int(e['register'], 16)
            except (KeyError, TypeError, ValueError) as exc: raise AudioError('invalid register') from exc
            if not (0xff10 <= address <= 0xff26 or 0xff30 <= address <= 0xff3f):
                raise AudioError('unsupported register')
            if type(e.get('value')) is not int or not 0 <= e['value'] <= 255:
                raise AudioError('register value must be an unsigned byte')
        if e['kind'] == 'ownership':
            if e.get('voice') not in (1,2,3,4) or type(e.get('channel')) is not int or not 1 <= e['channel'] <= 8:
                raise AudioError('invalid ownership voice/channel')
            if (e['channel']-1)%4+1 != e['voice']: raise AudioError('ownership voice/channel mismatch')
    if not any(e['kind'] == 'write' for e in ir.get('events', [])):
        raise AudioError('trace contains no register writes')


def voice_leases(events, ticks):
    """Logical leases from trace ownership; not reconstructed oscillator gates."""
    slots = [None]*8
    current = [None]*4
    starts = [0]*4
    rows = [[] for _ in range(4)]

    def interval(i, end):
        if end <= starts[i]: return
        rows[i].append({'start_tick': starts[i], 'end_tick': end,
                        'start_sample_floor': sample_index(starts[i]),
                        'end_sample_floor': sample_index(end),
                        'owner': current[i],
                        'music_suppressed': bool(current[i] and current[i]['channel'] > 4)})

    for event in events:
        if event['tick'] >= ticks: break
        if event['kind'] != 'ownership': continue
        i = event['voice']-1
        slots[event['channel']-1] = event.get('asset')
        channel = i+5 if slots[i+4] else i+1
        asset = slots[channel-1]
        owner = {'channel': channel, 'asset': asset} if asset else None
        if owner != current[i]:
            interval(i, event['tick'])
            starts[i] = event['tick']
            current[i] = owner
    for i in range(4): interval(i, ticks)
    return {str(i+1): row for i,row in enumerate(rows)}


def render(ir, output, *, preview_ticks=None, max_samples=RATE*180):
    """Render one bounded score span or an explicit short preview, never infer a loop.

    Output directory must not exist. Failure leaves no successful render report.
    """
    validate(ir)
    ticks = ir['ticks'] if preview_ticks is None else preview_ticks
    if type(ticks) is not int or not 0 < ticks <= ir['ticks']:
        raise AudioError('preview_ticks must be within closed trace')
    count = sample_index(ticks)
    if count > max_samples or count == 0: raise AudioError('render sample budget exceeded or empty')
    output = Path(output)
    if output.exists(): raise AudioError('output directory must be new')
    apu = APU()
    events = ir['events']
    event_index = 0
    chunks = [bytearray() for _ in range(5)]
    repeat = ir.get('repeat')
    boundary = repeat['start_tick']*TICK*RATE if repeat else None
    start_state = None
    ownership = []
    # Sample intervals and hardware events share an exact integer superclock.
    for sample in range(count):
        end = (sample+1)*CLOCK
        areas = [0]*8
        while True:
            event_time = events[event_index]['tick']*TICK*RATE if event_index < len(events) else ticks*TICK*RATE
            point = min(end, event_time, boundary if boundary is not None else end)
            partial = apu.integrate(point)
            areas = [a+b for a,b in zip(areas, partial)]
            if boundary is not None and point == boundary:
                start_state = apu.snapshot()
                boundary = None
            if point == event_time and point <= end and event_index < len(events):
                # Same tick writes preserve trace order, with no invented CPU delays.
                tick = events[event_index]['tick']
                batch = []
                while event_index < len(events) and events[event_index]['tick'] == tick:
                    batch.append(events[event_index]); event_index += 1
                for e in batch:
                    if e['kind'] == 'write':
                        address = int(e['register'], 16)
                        # Active envelope changes without a same-tick trigger are model-specific.
                        if address in (0xff12,0xff17,0xff21):
                            i = (0xff12,0xff17,0xff21).index(address)
                            i = (0,1,3)[i]
                            if apu.voices[i].active and e['value'] & 0xf8 and not any(
                                x['kind']=='write' and x['register']==f'{BASES[i]+4:04x}' and x['value'] & 128 for x in batch):
                                raise AudioError('unsupported active envelope write without same-tick trigger')
                        apu.write(address, e['value'])
                    elif e['kind'] in ('ownership', 'reject'):
                        ownership.append({**e, 'sample_floor': sample_index(tick),
                                          'sample_remainder': tick*TICK*RATE % CLOCK})
                continue
            if point == end: break
        stems = []
        for i in range(4):
            pair = tuple(signed_div(areas[i*2+n]*32760, CLOCK*480) for n in (0,1))
            stems.append(pair)
            chunks[i+1].extend(struct.pack('<hh', *pair))
        mix = tuple(signed_div(sum(areas[i*2+n] for i in range(4))*32760, CLOCK*480) for n in (0,1))
        chunks[0].extend(struct.pack('<hh', *mix))
    # Include the fractional final-sample tail when comparing hardware states.
    apu.integrate(ticks*TICK*RATE)
    end_state = apu.snapshot()
    complete = ticks == ir['ticks']
    loop = None
    if repeat:
        start = repeat['start_tick']; stop = repeat['end_tick']
        a, b = sample_index(start), sample_index(stop)
        loop = {'score_start_tick': start, 'score_end_tick': stop, 'intro_samples': a,
                'start_sample_floor': a, 'end_sample_floor': b, 'loop_samples': b-a,
                'start_sample_remainder': start*TICK*RATE % CLOCK,
                'end_sample_remainder': stop*TICK*RATE % CLOCK,
                'state_comparison_complete': complete,
                'hardware_state_equal': start_state == end_state if complete else None,
                'sample_grid_closes': (stop-start)*TICK*RATE % CLOCK == 0,
                'seamless': False, 'status': 'candidate_only_pending_phase_and_listening',
                'start_hardware_state_sha256': hashlib.sha256(canonical(start_state).encode()).hexdigest() if start_state else None,
                'end_hardware_state_sha256': hashlib.sha256(canonical(end_state).encode()).hexdigest() if complete else None}
        if complete and a < count:
            loop['mix_boundary_delta_pcm16'] = [struct.unpack_from('<h', chunks[0], a*4+n*2)[0]-struct.unpack_from('<h', chunks[0], (count-1)*4+n*2)[0] for n in (0,1)]
    report = {'schema': 1, 'status': 'reference_render', 'rate': RATE, 'format': 'PCM16LE',
              'channels': 2, 'samples': count, 'rendered_ticks': ticks, 'trace_ticks': ir['ticks'],
              'preview': not complete, 'clock': ir['clock'], 'duration_remainder': ticks*TICK*RATE % CLOCK,
              'sample_rounding': 'floor absolute endpoint; each sample integrates its full exact interval',
              'mixer': 'negative-slope DAC; NR51 stereo; NR50 (field+1)/8; four-voice headroom; truncation toward zero',
              'max_stem_sum_rounding_error_pcm16': 3, 'loop': loop, 'ownership': ownership,
              'voice_leases': voice_leases(events, ticks),
              'limitations': LIMITATIONS, 'provenance': {k: ir[k] for k in ('asset','variant','revision','consumed_sha256','tool_sha256','byte_oracle') if k in ir},
              'ir_sha256': hashlib.sha256(canonical(ir).encode()).hexdigest(),
              'renderer_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'hardware_pins_sha256': hashlib.sha256((Path(__file__).resolve().parents[1]/'references/audio/hardware-pins.json').read_bytes()).hexdigest(),
              'files': {}}
    output.mkdir(parents=True)
    for name, data in zip(('mix','pulse1','pulse2','wave','noise'), chunks):
        path = output/(name+'.wav')
        with wave.open(str(path), 'wb') as wav:
            wav.setnchannels(2); wav.setsampwidth(2); wav.setframerate(RATE); wav.writeframes(data)
        report['files'][path.name] = {'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'bytes': path.stat().st_size}
    (output/'render.json').write_text(canonical(report))
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ir', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--preview-ticks', type=int)
    args = parser.parse_args(argv)
    try:
        report = render(json.loads(args.ir.read_text()), args.output, preview_ticks=args.preview_ticks)
        print(f"render: {report['samples']} frames; {args.output}")
        return 0
    except (AudioError, OSError, ValueError, KeyError, TypeError) as exc:
        print(f'audio render: {exc}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
