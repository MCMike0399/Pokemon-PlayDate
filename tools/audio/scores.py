#!/usr/bin/env python3
"""Small native-synth scores and single-cycle wave assets from the pinned parser."""
from __future__ import annotations
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import sys
import struct
import wave
if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.audio.catalog import Catalog
from tools.audio.source import Source, AudioError, REVISION
from tools.audio.trace import Trace, BASES

CHECKPOINT_THEMES = {
    'cities1': 'audio1:Music_Cities1', 'cities2': 'audio1:Music_Cities2',
    'routes2': 'audio1:Music_Routes2', 'routes3': 'audio1:Music_Routes3',
    'routes4': 'audio1:Music_Routes4', 'dungeon2': 'audio3:Music_Dungeon2',
    'dungeon3': 'audio3:Music_Dungeon3',
}
ASSETS = {
    'pallet': 'audio1:Music_PalletTown', 'route1': 'audio1:Music_Routes1',
    'vermilion': 'audio1:Music_Vermilion', 'anne': 'audio1:Music_SSAnne',
    'pokecenter': 'audio1:Music_Pokecenter', 'gym': 'audio1:Music_Gym',
    'wild': 'audio2:Music_WildBattle', 'trainer': 'audio2:Music_TrainerBattle',
    'heal': 'audio1:Music_PkmnHealed', 'menu': 'audio2:SFX_Press_AB_2',
    'hit': 'audio2:SFX_Damage', 'faint': 'audio2:SFX_Faint_Thud',
    **CHECKPOINT_THEMES,
}
ROOT = Path(__file__).resolve().parents[2]

class ScoreTrace(Trace):
    """Intentional musical recurrence, never advertised as register recurrence.

    Same interpreter/tick arithmetic. Effects still execute, but synth notes take
    only note-on pitch/duty/envelope; persistent vibrato/slide phases are omitted.
    """
    def __init__(self, catalog, family):
        self.notes = []
        self.waves = {}
        super().__init__(catalog, family)

    def snapshot(self):
        value = super().snapshot()
        value.pop('registers')
        for ch in value['channels']:
            for key in ('location', 'vibrato_delay', 'vibrato_reload', 'vibrato_depth',
                        'vibrato_rate', 'vibrato_direction', 'frequency_low', 'slide'):
                ch.pop(key)
        return value

    def decode(self, i):
        start = len(self.events)
        super().decode(i)
        writes = self.events[start:]
        base = BASES[i % 4]
        trigger = any(e['kind'] == 'write' and e['register'] == f'{base+4:04x}'
                      and e['value'] & 128 for e in writes)
        ch = self.channels[i]
        if not trigger or not ch.asset or not self.owned(i):
            return
        voice = i % 4 + 1
        reg = self.registers
        envelope = reg.get(base+2, 0)
        if voice == 3:
            volume = (0, 1, .5, .25)[(envelope >> 5) & 3]
        else:
            volume = (envelope >> 4) / 15
        if volume == 0:
            return
        if voice == 4:
            nr = reg.get(base+3, 0)
            divisor = (8, 16, 32, 48, 64, 80, 96, 112)[nr & 7]
            hz = 524288 / divisor / (2 ** (nr >> 4))
        else:
            period = reg.get(base+3, 0) | ((reg.get(base+4, 0) & 7) << 8)
            # Native adaptation lands pitch slides immediately at their target.
            # The heal harmony starts above hearing range before sliding down.
            if ch.slide is not None: period = ch.slide['target'] & 2047
            hz = (65536 if voice == 3 else 131072) / (2048-period)
        # Wave identity travels with the note, including across voice stealing.
        note = [self.tick, voice, ch.delay or 256, round(hz, 4),
                round(volume, 4), (.125, .25, .5, .75)[reg.get(base+1, 0) >> 6], envelope]
        if voice == 3:
            ram = {int(e['register'], 16): e['value'] for e in writes
                   if e['kind'] == 'write' and 0xff30 <= int(e['register'], 16) <= 0xff3f}
            if set(ram) != set(range(0xff30, 0xff40)):
                raise AudioError('wave trigger without a complete wave RAM write')
            data = bytes(ram[address] for address in range(0xff30, 0xff40))
            key = f'audio{self.family}-wave{min(ch.wave, 5)}'
            if key in self.waves and self.waves[key] != data:
                raise AudioError(f'{key}: inconsistent wave RAM')
            self.waves[key] = data
            note.append(key)
        self.notes.append(note)


def wave_asset(data):
    """One 32-sample cycle, high nibble first, with the existing DAC polarity.

    No per-wave normalization: map the full 0..15 range to +32760..-32760.
    The SDK wavetable oscillator, not this file's sample rate, sets note pitch.
    """
    samples = [(15 - 2 * value) * 2184 for byte in data for value in (byte >> 4, byte & 15)]
    output = io.BytesIO()
    with wave.open(output, 'wb') as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(44100)
        stream.writeframes(struct.pack('<32h', *samples))
    return output.getvalue()


def adapt_menu(score):
    # Explicit native adaptation: two source pitches with >=50ms gates, so a
    # 30FPS observer cannot coalesce the whole chirp. No APU timing claim.
    first, last = list(score['notes'][0]), list(score['notes'][-1])
    first[0], first[2] = 0, 3
    last[0], last[2] = 3, 5
    return dict(score, ticks=8, notes=[first, last])


def checkpoint_maps():
    manifest = json.loads((ROOT/'Source/data/sourceMaps.json').read_text())
    return {row['id'] for row in manifest['maps'].values()}


def map_routes(catalog):
    music = {asset: name for name, asset in ASSETS.items()}
    active = checkpoint_maps()
    # Preserve prior routes; newly selected themes serve only the active maps.
    return {'pokered:'+row['map']: music[row['asset']]
            for row in catalog.maps if row['asset'] in music
            and (music[row['asset']] not in CHECKPOINT_THEMES or 'pokered:'+row['map'] in active)}


def generate(source):
    catalog = Catalog(Source(source))
    scores = {}
    waves = {}
    for name, asset in ASSETS.items():
        trace = ScoreTrace(catalog, catalog.headers[asset]['family'])
        trace.load(asset)
        result = trace.run()  # unchanged default bound; rejects rather than truncates
        if result['status'] == 'bound':
            raise AudioError(f'{asset}: adapted score did not close within default bound')
        scores[name] = dict(asset=asset, ticks=result['ticks'],
                            loop=result['repeat']['start_tick'] if result['repeat'] else None,
                            notes=trace.notes)
        waves.update(trace.waves)
    scores['menu'] = adapt_menu(scores['menu'])
    routes = map_routes(catalog)
    active = checkpoint_maps()
    source_songs = {'pokered:'+row['map']: row['asset'] for row in catalog.maps}
    unavailable = {map_id: source_songs.get(map_id, 'no source song')
                   for map_id in sorted(active - routes.keys())}
    # Direct source alarm's two pulse pitches, 30+1 tick cadence; explicit adaptation.
    catalog.source.read('audio/low_health_alarm.asm')
    scores['alarm'] = dict(asset='audio2:low-health', ticks=31, loop=0, notes=[
        [0, 1, 11, round(131072/(2048-0x750), 4), .9333, .5, 0xe2],
        [11, 1, 20, round(131072/(2048-0x6ee), 4), .9333, .5, 0xe2]])
    lines = ['-- Generated by tools/audio/scores.py; do not hand edit.',
             '-- notes: tick, voice, gate ticks, Hz, amplitude, duty, envelope, optional wave key',
             'KantoScores = {']
    for name, score in scores.items():
        lines.append(f'  {name} = {{ticks={score["ticks"]}, loop={score["loop"] if score["loop"] is not None else "nil"}, notes={{')
        lines += ['    {' + ','.join(json.dumps(x) for x in n) + '},' for n in score['notes']]
        lines.append('  }},')
    lines.append('}')
    lines.append('KantoMusicMaps = {')
    lines += [f'  ["{key}"] = "{value}",' for key,value in sorted(routes.items())]
    lines.append('}')
    lines.append('KantoWaveforms = {')
    lines += [f'  ["{key}"] = "audio/waves/{key}",' for key in sorted(waves)]
    lines.append('}\n')
    payload = '\n'.join(lines)
    wave_assets = {f'Source/audio/waves/{key}.wav': wave_asset(data)
                   for key, data in sorted(waves.items())}
    tools = {p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in (
        'tools/audio/scores.py', 'tools/audio/source.py', 'tools/audio/catalog.py', 'tools/audio/trace.py')}
    manifest = {'schema': 2, 'revision': REVISION, 'target': 'Playdate synth adaptation',
                'inputs_sha256': dict(sorted(catalog.source.hashes.items())), 'tools_sha256': tools,
                'menu_adaptation': 'two source pitches, gates 3+5 ticks; native 30FPS chirp',
                'map_routes': routes,
                'checkpoint': {
                    'manifest_sha256': hashlib.sha256((ROOT/'Source/data/sourceMaps.json').read_bytes()).hexdigest(),
                    'maps': len(active), 'routed_maps': len(active & routes.keys()),
                    'unavailable': unavailable,
                },
                'score_sha256': hashlib.sha256(payload.encode()).hexdigest(),
                'total_notes': sum(len(score['notes']) for score in scores.values()),
                'waveforms': {key: {'ram_hex': data.hex(), 'samples': 32,
                                   'path': f'Source/audio/waves/{key}.wav',
                                   'sha256': hashlib.sha256(wave_assets[f'Source/audio/waves/{key}.wav']).hexdigest()}
                              for key, data in sorted(waves.items())},
                'scores': {k: {x: v[x] for x in ('asset', 'ticks', 'loop')} | {'notes': len(v['notes'])}
                           for k, v in scores.items()}}
    return {'Source/audio/scores.lua': payload.encode(),
            'tools/audio/score-manifest.json': (json.dumps(manifest, indent=2, sort_keys=True)+'\n').encode(),
            **wave_assets}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', default=os.environ.get('POKERED_REFERENCE_DIR'))
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if not args.source: parser.error('--source or POKERED_REFERENCE_DIR required')
    payloads = generate(args.source)
    for path, data in payloads.items():
        target = ROOT/path
        if args.check:
            if not target.exists() or target.read_bytes() != data:
                raise AudioError(f'{path} differs; regenerate')
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    print('native synth scores: ' + ('reproducible' if args.check else 'generated'))

if __name__ == '__main__': main()
