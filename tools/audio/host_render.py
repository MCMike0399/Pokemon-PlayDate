#!/usr/bin/env python3
"""Render Kanto scores to WAV with the game's own channel logic.

host_engine.lua loads Source/audio/engine.lua under a stubbed playdate.sound
and steps the same tick clock, parts, jingle-over-bed, and SFX priority the
game uses. This module turns that note schedule into PCM. It is a host
render, not a Simulator capture. Square, noise, and wavetable oscillators
here are host stand-ins for the Playdate synth. Amplitude and pitch
already include the shared envelope, slide, and vibrato curve, so this
module only oscillates. A 0.2 ms ramp sits on a note attack and on a
note that is not continued by the next segment.
"""
from __future__ import annotations

import argparse
import hashlib
import math
import struct
import subprocess
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ENGINE = Path(__file__).resolve().parent / 'host_engine.lua'
TICK = 70224 / 4194304
RATE = 44100
MASTER = 0.22

CLIPS = ('title', 'route1', 'trainer', 'heal', 'champion', 'mansion')


def schedule(kind):
    proc = subprocess.run(
        ['lua', str(ENGINE), 'clip', kind],
        check=True, capture_output=True, text=True,
    )
    notes = []
    for line in proc.stdout.splitlines():
        if not line.startswith('note\t'):
            continue
        parts = line.split('\t')
        _, t, voice, hz, amp, dur, kind_name, duty, wave_path = parts[:9]
        notes.append({
            't': float(t),
            'voice': int(voice),
            'hz': float(hz),
            'amp': float(amp),
            'dur': float(dur),
            'kind': kind_name,
            'duty': float(duty),
            'wave': None if wave_path == '-' else wave_path,
            'hold': len(parts) > 9 and parts[9] == '1',
            'amp1': float(parts[10]) if len(parts) > 10 else float(amp),
        })
    return notes


def _pcm_cycle(path):
    wav_path = ROOT / 'Source' / f'{path}.wav'
    with wave.open(str(wav_path), 'rb') as stream:
        frames = stream.readframes(stream.getnframes())
        samples = struct.unpack('<' + 'h' * (len(frames) // 2), frames)
    peak = max(abs(sample) for sample in samples) or 1
    return tuple(sample / peak for sample in samples)


def synthesize(notes, rate=RATE):
    if not notes:
        raise SystemExit('host schedule produced no notes')
    end = max(note['t'] + note['dur'] for note in notes)
    count = max(1, int(math.ceil(end * rate)))
    mix = [0.0] * count
    cycles = {}
    ramp = max(1, int(rate * 0.0002))
    by_voice = {}
    for note in notes:
        by_voice.setdefault(note['voice'], []).append(note)
    for group in by_voice.values():
        group.sort(key=lambda item: item['t'])
        for index, note in enumerate(group):
            nxt = group[index + 1] if index + 1 < len(group) else None
            note['continues'] = bool(
                nxt and nxt.get('hold')
                and abs((note['t'] + note['dur']) - nxt['t']) < 1e-6
            )
    state = {}
    ordered = sorted(notes, key=lambda item: (item['voice'], item['t']))
    for note in ordered:
        if note['dur'] <= 0 or note['hz'] <= 0:
            continue
        if note['amp'] <= 0 and note.get('amp1', 0) <= 0:
            continue
        start = int(round(note['t'] * rate))
        stop = int(round((note['t'] + note['dur']) * rate))
        if start >= count:
            continue
        stop = min(count, max(start + 1, stop))
        length = stop - start
        kind = note['kind']
        prev = state.get(note['voice'])
        contiguous = bool(note.get('hold') and prev and prev['end'] == start)
        if contiguous:
            phase = prev['phase']
            held = prev['held']
            hold = prev['hold_n']
            noise = prev['noise']
        else:
            phase = 0.0
            held = 0.0
            hold = 0
            noise = 1
        cycle = None
        if kind == 'wave':
            cycle = cycles.get(note['wave'])
            if cycle is None:
                cycle = _pcm_cycle(note['wave'])
                cycles[note['wave']] = cycle
        amp0 = note['amp']
        amp1 = note.get('amp1', amp0)
        for index in range(length):
            if kind == 'noise':
                if hold <= 0:
                    noise = (noise * 1103515245 + 12345) & 0x7fffffff
                    held = (noise / 0x3fffffff) - 1
                    hold = max(1, int(rate / note['hz']))
                hold -= 1
                sample = held
            elif kind == 'wave':
                phase = (phase + note['hz'] / rate) % 1
                sample = cycle[int(phase * len(cycle)) % len(cycle)]
            else:
                phase = (phase + note['hz'] / rate) % 1
                sample = 1.0 if phase < note['duty'] else -1.0
            if not contiguous and index < ramp:
                edge = (index + 1) / ramp
            elif index >= length - ramp and not note.get('continues'):
                edge = max(0.0, (length - index) / ramp)
            else:
                edge = 1.0
            level = amp0 if length == 1 else amp0 + (amp1 - amp0) * (index / (length - 1))
            mix[start + index] += sample * level * MASTER * edge
        state[note['voice']] = {
            'end': stop, 'phase': phase, 'held': held, 'hold_n': hold, 'noise': noise,
        }
    peak = max(abs(sample) for sample in mix) or 1
    # Leave headroom. The master gain already matches the engine's 0.22.
    scale = 32767 if peak <= 1 else 32767 / peak
    return struct.pack('<' + 'h' * count, *(
        max(-32767, min(32767, int(sample * scale))) for sample in mix
    )), count


def write_wav(path, pcm, rate=RATE):
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(rate)
        stream.writeframes(pcm)


def peak_of(pcm):
    samples = struct.unpack('<' + 'h' * (len(pcm) // 2), pcm)
    return max(abs(sample) for sample in samples)


def mansion_seam(notes):
    """Pitches sounding at tick 9315, one per voice, from the host schedule."""
    instant = 9315 * TICK
    chosen = {}
    for note in notes:
        if note['t'] <= instant and note['t'] + max(note['dur'], 0) > instant:
            chosen[note['voice']] = note
    return chosen


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    out = args.out
    out.mkdir(parents=True, exist_ok=True)
    sums = []
    for kind in CLIPS:
        notes = schedule(kind)
        if kind == 'mansion':
            seam = mansion_seam(notes)
            if len(seam) < 4:
                raise SystemExit(f'mansion seam is missing voices: {sorted(seam)}')
            # The engine clock is already at tick 9000. Shift so the file
            # starts there; tick 9315 is 315 ticks in.
            origin = 9000 * TICK
            notes = [{**note, 't': note['t'] - origin} for note in notes]
        pcm, _count = synthesize(notes)
        if peak_of(pcm) < 1000:
            raise SystemExit(f'{kind} render is silent')
        path = out / f'{kind}.wav'
        write_wav(path, pcm)
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        sums.append(f'{digest}  {path.name}')
        print(f'{path.name} {digest} peak {peak_of(pcm)}')
    (out / 'SHA256SUMS').write_text('\n'.join(sums) + '\n')
    print(out / 'SHA256SUMS')


if __name__ == '__main__':
    main()
