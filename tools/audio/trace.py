"""Bounded score-tick register interpreter. No oscillator, PCM, or playback backend."""
from dataclasses import asdict, dataclass
import hashlib
import json

from .source import AudioError

BASES = (0xff10, 0xff15, 0xff1a, 0xff1f)


def delay(encoded_length, speed, tempo, fraction):
    units = (((encoded_length & 15) + 1) * speed) & 255
    accumulator = (fraction + units * tempo) & 65535
    return accumulator >> 8, accumulator & 255


def frequency(table, pitch, octave):
    if not 0 <= pitch < 12 or not 0 <= octave <= 7:
        raise AudioError('pitch/octave outside source note table')
    value = table[pitch]
    for _ in range(7-octave):
        value = ((value >> 1) | (value & 0x8000)) & 65535
    return (((value >> 8) + 8) & 255) << 8 | (value & 255)


@dataclass
class Channel:
    pc: tuple | None = None
    location: str = ''
    asset: str = ''
    sound_id: int = 0
    delay: int = 1
    fraction: int = 0
    speed: int = 1
    octave: int = 0
    volume: int = 0
    wave: int = 0
    duty: int = 0
    pattern: int | None = None
    returned: tuple | None = None
    execute: bool = False
    perfect: bool = False
    vibrato_delay: int = 0
    vibrato_reload: int = 0
    vibrato_depth: int = 0
    vibrato_rate: int = 0
    vibrato_direction: bool = False
    frequency_low: int = 0
    slide: dict | None = None
    loop: int = 1
    pitch: int = 0
    length: int = 128
    modified: bool = False
    cry: bool = False


class Trace:
    def __init__(self, catalog, family):
        self.catalog = catalog
        self.family = family
        self.channels = [Channel() for _ in range(8)]
        self.tempo = [256, 256]
        self.registers = {}
        self.events = []
        self.tick = 0
        self.panning = 255
        self.saved_volume = 0
        self.pitch_modifier = 0
        self.tempo_modifier = 128
        self.alarm = 0
        self.disable_noise = 0
        self.last_location = 'audio/engine_%s.asm:1' % family
        self.executed = set()
        self.current_channel = None
        # Begin from the engine's stop-all reset, not unspecified hardware register values.
        for address, value in ((0xff26, 128), (0xff1a, 128), (0xff25, 0),
                               (0xff1c, 0), (0xff10, 8), (0xff12, 0),
                               (0xff17, 0), (0xff21, 0), (0xff14, 64),
                               (0xff19, 64), (0xff23, 64), (0xff24, 119)):
            self.write(address, value, 'engine-reset')

    def event(self, kind, **values):
        self.events.append({'tick': self.tick, 'kind': kind, **values})

    def write(self, address, value, owner=None):
        value &= 255
        self.registers[address] = value
        self.event('write', register=f'{address:04x}', value=value,
                   owner=owner or self.current_channel, source=self.last_location)

    def owned(self, index):
        return index >= 4 or not self.channels[index+4].asset

    def load(self, key, pitch=None, length=None):
        header = self.catalog.headers.get(key)
        if header is None or header['family'] != self.family:
            raise AudioError(f'unknown or cross-bank asset {key}')
        pitch = self.pitch_modifier if pitch is None else pitch
        length = self.tempo_modifier if length is None else length
        if not 0 <= pitch <= 255 or not 0 <= length <= 255:
            raise AudioError('pitch and length modifiers must be unsigned bytes')
        self.pitch_modifier, self.tempo_modifier = pitch, length
        self.last_location = header['source']
        if header['kind'] == 'music':
            if self.tick:
                raise AudioError(f'{self.last_location}: mid-trace music replacement is outside this packet')
            self.tempo[0] = 256
            for i in range(4): self.channels[i] = Channel()
            for addr, value in ((0xff24, 0), (0xff10, 8), (0xff25, 0), (0xff1a, 0), (0xff1a, 128), (0xff24, 119)):
                self.write(addr, value, 'music-init')
        # Source installs in reverse header order; rejection can leave a partial installation.
        for entry in reversed(header['channels']):
            i = entry['channel']-1
            old = self.channels[i]
            if header['kind'] == 'sfx' and old.asset:
                new_id = header['id']
                if i == 7 and new_id < 20:
                    self.event('reject', channel=i+1, asset=key, reason='busy noise instrument')
                    return
                if not (i == 7 and old.sound_id <= 19) and new_id > old.sound_id:
                    self.event('reject', channel=i+1, asset=key, reason='numeric priority')
                    return
            label = header['label']
            cry = label.startswith('SFX_Cry') and 'Unused' not in label
            # Audio2 tests the OR of channels 5 and 8 against the battle-SFX interval.
            battle_start = self.catalog.headers['audio2:SFX_Peck']['id']
            battle_end = self.catalog.headers['audio2:SFX_Trainer_Appeared']['id']+1
            modified = cry or (self.family == 2 and battle_start <= header['id'] < battle_end)
            ch = Channel(pc=self.catalog.target(self.family, entry['entry']), asset=key,
                         sound_id=header['id'], pitch=pitch, length=length, modified=modified, cry=cry,
                         fraction=old.fraction, octave=old.octave, volume=old.volume, wave=old.wave)
            self.channels[i] = ch
            self.event('ownership', voice=i%4+1, channel=i+1, asset=key, replaced=old.asset or None)
            if i == 4: self.write(0xff10, 8, i+1)
        if cry:
            if not self.saved_volume:
                self.saved_volume = self.registers.get(0xff24, 0)
                self.write(0xff24, 119, 'cry-init')
            self.channels[6] = Channel(asset=key, sound_id=header['id'], cry=True)

    def variant(self, name):
        labels = self.catalog.variants.get(name)
        if labels is None:
            raise AudioError(f'unknown variant {name}')
        required = {'Music_RivalAlternateStart': 'audio1:Music_MeetRival',
                    'Music_RivalAlternateTempo': 'audio1:Music_MeetRival',
                    'Music_Cities1AlternateTempo': 'audio1:Music_Cities1',
                    'Music_PokeFluteInBattle': 'audio2:SFX_Caught_Mon'}
        if name not in required or not any(c.asset == required[name] for c in self.channels):
            raise AudioError(f'variant {name} requires its source base asset')
        for label in labels:
            if '_Ch' not in label:
                raise AudioError(f'unsupported variant pointer {label}')
            i = int(label.split('_Ch')[1][0])-1
            self.channels[i].pc = self.catalog.target(self.family, label)
            self.event('entry', channel=i+1, label=label)

    def byte(self, ch):
        section, offset = ch.pc
        data = self.catalog.sections[section]
        if not 0 <= offset < len(data):
            raise AudioError(f'{self.last_location}: command pointer outside section')
        cmd = self.catalog.commands.get((section, offset))
        if cmd:
            self.last_location = cmd.line.location
            ch.location = cmd.line.location
        ch.pc = (section, offset+1)
        return data[offset]

    def jump(self, ch, offset):
        target = (ch.pc[0], offset)
        if target not in self.catalog.commands:
            raise AudioError(f'{self.last_location}: control transfer outside command boundary {offset}')
        ch.pc = target

    def word(self, ch):
        low = self.byte(ch)
        return low | self.byte(ch)<<8

    def output(self, i):
        mask = 0x11 << (i%4)
        value = self.registers.get(0xff25, 0) | mask
        if i == 7 or i < 4 and self.owned(i):
            value = (value & ~mask) | (self.panning & mask)
        self.write(0xff25, value)

    def wave_frequency(self, i, value):
        ch = self.channels[i]
        base = BASES[i%4]
        if i%4 == 2:
            section, offset = self.catalog.target(self.family, f'Audio{self.family}_WavePointers.wave{min(ch.wave, 5)}')
            wave = self.catalog.sections[section][offset:offset+16]
            if len(wave) != 16:
                raise AudioError(f'{self.last_location}: incomplete bank-local wave')
            self.write(0xff1a, 0)
            for n, byte in enumerate(wave): self.write(0xff30+n, byte)
            self.write(0xff1a, 128)
        high = ((value >> 8) | 0x80) & 0xc7
        low = value & 255
        self.write(base+3, low)
        self.write(base+4, high)
        if i >= 4 and self.modified():
            low += self.pitch_modifier
            high = (high+(low>>8)) & 255
            self.write(base+3, low)
            self.write(base+4, high)

    def sound_length(self, i):
        ch = self.channels[i]
        value = ch.delay if i%4 == 2 else (ch.delay & 63) | ch.duty
        self.write(BASES[i%4]+1, value)

    def modified(self):
        primary = self.channels[4]
        if primary.asset and primary.cry:
            return True
        if self.family != 2:
            return False
        low = self.catalog.headers['audio2:SFX_Peck']['id']
        high = self.catalog.headers['audio2:SFX_Trainer_Appeared']['id']+1
        combined = (primary.sound_id if primary.asset else 0) | (self.channels[7].sound_id if self.channels[7].asset else 0)
        return low <= combined < high

    def timed(self, i, opcode):
        ch = self.channels[i]
        if i < 4:
            tempo = self.tempo[0]
        elif i == 7:
            tempo = 256
        else:
            # SetSfxTempo overwrites execute_music tempo too, on every timed command.
            tempo = self.tempo_modifier+128 if self.modified() else 256
            self.tempo[1] = tempo
        ch.delay, ch.fraction = delay(opcode, ch.speed, tempo, ch.fraction)
        self.event('delay', channel=i+1, counter=ch.delay, fraction=ch.fraction,
                   tempo=tempo, speed=ch.speed, opcode=opcode, source=self.last_location)

    def stop(self, i):
        ch = self.channels[i]
        base = BASES[i%4]
        if i == 6:
            self.write(0xff1a, 0)
            self.write(0xff1a, 128)
        if i < 3:
            mask = 0x11 << i
            self.write(0xff25, self.registers.get(0xff25, 0) & ~mask)
        primary = self.channels[4]
        if primary.asset and primary.cry:
            if i != 4:
                # Source rewinds the ret opcode and keeps retrying at delay=1.
                if ch.pc is not None: ch.pc = (ch.pc[0], ch.pc[1]-1)
                return
            self.write(0xff24, self.saved_volume)
            self.saved_volume = 0
        self.event('ownership', voice=i%4+1, channel=i+1, asset=None,
                   resumes=self.channels[i-4].asset if i >= 4 else None)
        ch.asset = ''
        ch.pc = None

    def decode(self, i):
        ch = self.channels[i]
        ch.vibrato_delay = ch.vibrato_reload
        ch.slide = None
        seen = set()
        slide_target = None
        while True:
            state = (ch.pc, ch.returned, ch.loop, ch.speed, tuple(self.tempo), ch.fraction,
                     ch.execute, ch.octave, ch.volume, ch.duty, ch.pattern, ch.perfect)
            if state in seen:
                raise AudioError(f'{self.last_location}: zero-time control cycle')
            seen.add(state)
            if len(seen) > 10000:
                raise AudioError(f'{self.last_location}: command budget exceeded')
            pos = ch.pc
            cmd = self.catalog.commands.get(pos)
            if cmd:
                self.executed.add(cmd.op)
            opcode = self.byte(ch)
            if opcode == 0xff:
                if ch.returned is not None:
                    ch.pc, ch.returned = ch.returned, None
                    continue
                self.stop(i)
                return
            if opcode == 0xfd:
                target = self.word(ch)
                ch.returned = ch.pc  # One slot, intentionally overwrites an earlier call.
                self.jump(ch, target)
                continue
            if opcode == 0xfe:
                count = self.byte(ch)
                target = self.word(ch)
                if count and ch.loop == count:
                    ch.loop = 1
                else:
                    if count: ch.loop = (ch.loop+1) & 255
                    self.jump(ch, target)
                continue
            if opcode & 0xf0 == 0xd0:
                ch.speed = opcode & 15
                if i != 3:
                    value = self.byte(ch)
                    if i%4 == 2:
                        ch.wave = value & 15
                        ch.volume = (value & 0x30)<<1
                        if ch.wave > 8:
                            raise AudioError(f'{self.last_location}: invalid wave pointer')
                    else: ch.volume = value
                continue
            if opcode == 0xe8:
                ch.perfect = not ch.perfect
                continue
            if opcode == 0xea:
                ch.vibrato_reload = ch.vibrato_delay = self.byte(ch)
                value = self.byte(ch)
                ch.vibrato_depth = value >> 4
                ch.vibrato_rate = (value & 15)*17
                continue
            if opcode == 0xeb:
                modifier = self.byte(ch)
                target = self.byte(ch)
                slide_target = (modifier, frequency(self.catalog.notes, target & 15, target >> 4))
                opcode = self.byte(ch)
                # pitch_slide jumps directly into note_length, bypassing command decoding.
                break
            if opcode == 0xec:
                ch.duty = (self.byte(ch) << 6) & 0xc0
                continue
            if opcode == 0xed:
                value = self.byte(ch)<<8 | self.byte(ch)
                group = i//4
                self.tempo[group] = value
                for other in self.channels[group*4:group*4+4]: other.fraction = 0
                self.event('tempo', group=group, value=value, source=self.last_location)
                continue
            if opcode == 0xee:
                self.panning = self.byte(ch)
                continue
            if opcode == 0xef:
                raise AudioError(f'{self.last_location}: unsupported trace semantics: unknownmusic0xef')
            if opcode == 0xfc:
                ch.pattern = self.byte(ch)
                ch.duty = ch.pattern & 0xc0
                continue
            if opcode == 0xf0:
                self.write(0xff24, self.byte(ch))
                continue
            if opcode == 0xf8:
                ch.execute = True
                continue
            if opcode & 0xf0 == 0xe0:
                ch.octave = opcode & 15
                continue
            if opcode & 0xf0 == 0x20 and i >= 3 and not ch.execute:
                self.timed(i, opcode)
                base = BASES[i%4]
                self.write(base+1, ch.duty | ch.delay)
                self.write(base+2, self.byte(ch))
                value = self.byte(ch)
                if i != 7: value |= self.byte(ch)<<8
                self.sound_length(i)
                self.output(i)
                self.wave_frequency(i, value)
                return
            if opcode == 0x10 and i >= 4 and not ch.execute:
                self.write(0xff10, self.byte(ch))
                continue
            break
        if i == 3 and opcode < 0xc0:
            instrument = self.byte(ch) if opcode & 0xf0 == 0xb0 else opcode>>4
            candidates = [h for h in self.catalog.headers.values()
                          if h['family'] == self.family and h['kind'] == 'sfx' and h['id'] == instrument]
            if len(candidates) != 1:
                raise AudioError(f'{self.last_location}: unresolved drum instrument {instrument}')
            if not self.disable_noise:
                location = self.last_location
                self.load(candidates[0]['key'])
                self.last_location = location
            self.current_channel = i+1
        self.timed(i, opcode)
        if i == 3 or (i >= 4 and not ch.execute):
            return
        if opcode & 0xf0 == 0xc0:
            if self.owned(i):
                if i%4 == 2:
                    self.write(0xff25, self.registers.get(0xff25, 0) & ~(0x11<<(i%4)))
                else:
                    self.write(BASES[i%4]+2, 8)
                    self.write(BASES[i%4]+4, 128)
            return
        if opcode >> 4 >= 12:
            raise AudioError(f'{self.last_location}: unsupported timed opcode {opcode:02x}')
        value = frequency(self.catalog.notes, opcode>>4, ch.octave)
        if slide_target is not None:
            modifier, target = slide_target
            divisor = ch.delay-modifier
            if divisor < 0: divisor = 1
            if divisor == 0:
                raise AudioError(f'{self.last_location}: pitch_slide source division does not terminate')
            delta = abs(value-target)
            decreasing = value >= target
            if not decreasing and (target & 255) < (value & 255):
                delta = (delta+512) & 65535  # Preserve the source borrow bug.
            quotient, remainder = divmod(delta, divisor)
            ch.slide = dict(current=value, target=target, decreasing=decreasing,
                            step=(quotient+1)&255, fraction=remainder, current_fraction=remainder)
        if not self.owned(i): return
        self.write(BASES[i%4]+2, ch.volume)
        self.sound_length(i)
        self.output(i)
        # The preceding WRAM pointer ADD leaves carry clear; INC e never sets it.
        # Preserve the source's missing carry into the high frequency byte.
        if ch.perfect:
            value = (value & 0xff00) | ((value+1) & 255)
        ch.frequency_low = value & 255
        self.wave_frequency(i, value)
        return

    def effects(self, i):
        ch = self.channels[i]
        if not self.owned(i): return
        if ch.pattern is not None:
            ch.pattern = ((ch.pattern<<2) | (ch.pattern>>6)) & 255
            addr = BASES[i%4]+1
            self.write(addr, (self.registers.get(addr, 0) & 63) | (ch.pattern & 0xc0))
        if (i == 3 or i >= 4) and not ch.execute: return
        if ch.slide is not None:
            slide = ch.slide
            if slide['decreasing']:
                slide['fraction'] *= 2
                borrow = slide['fraction'] > 255
                slide['fraction'] &= 255
                current = (slide['current']-slide['step']-borrow)&65535
                reached = current < slide['target']
            else:
                frac = slide['current_fraction']+slide['fraction']
                slide['current_fraction'] = frac & 255
                current = (slide['current']+slide['step']+(frac>>8))&65535
                reached = current > slide['target']
            if reached:
                ch.slide = None
            else:
                slide['current'] = current
                self.write(BASES[i%4]+3, current & 255)
                self.write(BASES[i%4]+4, current>>8)
            return
        if ch.vibrato_delay:
            ch.vibrato_delay -= 1
            return
        if not ch.vibrato_depth: return
        if ch.vibrato_rate & 15:
            ch.vibrato_rate = (ch.vibrato_rate-1) & 255
            return
        ch.vibrato_rate |= ((ch.vibrato_rate<<4) | (ch.vibrato_rate>>4)) & 255
        low = ch.frequency_low
        if ch.vibrato_direction:
            low = max(0, low-ch.vibrato_depth//2)
        else:
            low = min(255, low+(ch.vibrato_depth+1)//2)
        ch.vibrato_direction = not ch.vibrato_direction
        self.write(BASES[i%4]+3, low)

    def low_health(self):
        if self.alarm == 255:
            tone = (0, 0, 0, 0, 128)
            self.alarm = 0
            self.channels[4].asset = ''
            self.event('ownership', voice=1, channel=5, asset=None, resumes=self.channels[0].asset or None)
        elif not self.alarm & 128: return
        elif self.alarm & 127 == 0:
            tone = (0, 0xa0, 0xe2, 0x50, 0x87)
            self.alarm = 128 | 30
        else:
            tone = (0, 0xb0, 0xe2, 0xee, 0x86) if self.alarm & 127 == 20 else None
            # This ID sentinel prevents ordinary pulse-1/music writes until cleared.
            if self.channels[4].asset != 'low-health':
                self.event('ownership', voice=1, channel=5, asset='low-health',
                           replaced=self.channels[4].asset or None)
            self.channels[4].asset = 'low-health'
            self.channels[4].sound_id = self.catalog.headers['audio2:SFX_Cry25_2']['id']+3
            self.channels[4].cry = False
            self.alarm = 128 | ((self.alarm & 127)-1)
        if tone:
            self.last_location = 'audio/low_health_alarm.asm:1'
            for offset, value in enumerate(tone): self.write(0xff10+offset, value, 'low-health')

    def snapshot(self):
        return {'channels': [asdict(c) for c in self.channels], 'tempo': self.tempo,
                'registers': self.registers, 'panning': self.panning,
                'saved_volume': self.saved_volume, 'pitch_modifier': self.pitch_modifier,
                'tempo_modifier': self.tempo_modifier, 'alarm': self.alarm, 'disable_noise': self.disable_noise}

    def run(self, max_ticks=120000, scheduled=(), alarm=False):
        if max_ticks <= 0:
            raise AudioError('max_ticks must be positive')
        if alarm and self.family != 2:
            raise AudioError('low-health alarm belongs to audio2')
        if alarm: self.alarm = 128
        pending = sorted(scheduled, key=lambda x: x['tick'])
        seen = {}
        status = 'bound'
        repeat = None
        for tick in range(max_ticks):
            self.tick = tick
            while pending and pending[0]['tick'] == tick:
                item = pending.pop(0)
                self.load(item['asset'], item.get('pitch'), item.get('length'))
            if pending and pending[0]['tick'] < tick:
                raise AudioError('negative/out-of-order scheduled tick')
            state = json.dumps(self.snapshot(), sort_keys=True, separators=(',', ':'))
            fingerprint = hashlib.sha256(state.encode()).hexdigest()
            if not pending and fingerprint in seen:
                status = 'repeat'
                repeat = {'start_tick': seen[fingerprint], 'end_tick': tick, 'sha256': fingerprint}
                break
            seen[fingerprint] = tick
            if not pending and not any(c.asset for c in self.channels) and not self.alarm:
                status = 'ended'
                break
            if self.alarm: self.low_health()
            for i, ch in enumerate(self.channels):
                self.current_channel = i+1
                self.last_location = ch.location or f'audio/engine_{self.family}.asm:1'
                if not ch.asset: continue
                if ch.pc is None:
                    if ch.cry: self.stop(i)
                    continue
                if ch.delay == 1:
                    if self.family == 2 and i == 4 and self.alarm & 128:
                        continue
                    self.decode(i)
                else:
                    ch.delay = (ch.delay-1) & 255
                    self.effects(i)
        return {'schema': 1, 'family': self.family, 'status': status, 'ticks': self.tick,
                'clock': {'tick_numerator': 70224, 'tick_denominator': 4194304, 'unit': 'seconds'},
                'repeat': repeat, 'events': self.events, 'terminal': self.snapshot(),
                'executed_macros': sorted(self.executed),
                'limitation': 'Score/register state only. No oscillator state, PCM, or seamless audio claim.'}
