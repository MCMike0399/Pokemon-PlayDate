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
# Every songs.asm label, plus battle, travel, fanfare, and the SFX the
# observer can reach. Families match the header file that defines the label.
ASSETS = {
    'pallet': 'audio1:Music_PalletTown', 'route1': 'audio1:Music_Routes1',
    'vermilion': 'audio1:Music_Vermilion', 'anne': 'audio1:Music_SSAnne',
    'pokecenter': 'audio1:Music_Pokecenter', 'gym': 'audio1:Music_Gym',
    'lavender': 'audio1:Music_Lavender', 'celadon': 'audio1:Music_Celadon',
    'cinnabar': 'audio1:Music_Cinnabar', 'indigo': 'audio1:Music_IndigoPlateau',
    'safari': 'audio1:Music_SafariZone',
    'oaks_lab': 'audio3:Music_OaksLab', 'dungeon1': 'audio3:Music_Dungeon1',
    'tower': 'audio3:Music_PokemonTower', 'silph': 'audio3:Music_SilphCo',
    'game_corner': 'audio3:Music_GameCorner', 'mansion': 'audio3:Music_CinnabarMansion',
    'wild': 'audio2:Music_WildBattle', 'trainer': 'audio2:Music_TrainerBattle',
    'gym_leader': 'audio2:Music_GymLeaderBattle', 'final': 'audio2:Music_FinalBattle',
    'defeated_wild': 'audio2:Music_DefeatedWildMon',
    'defeated_trainer': 'audio2:Music_DefeatedTrainer',
    'defeated_gym': 'audio2:Music_DefeatedGymLeader',
    'meet_male': 'audio3:Music_MeetMaleTrainer',
    'meet_female': 'audio3:Music_MeetFemaleTrainer',
    'meet_evil': 'audio3:Music_MeetEvilTrainer',
    'meet_rival': 'audio1:Music_MeetRival', 'meet_oak': 'audio1:Music_MeetProfOak',
    'heal': 'audio1:Music_PkmnHealed',
    'title': 'audio3:Music_TitleScreen', 'credits': 'audio3:Music_Credits',
    'hall_of_fame': 'audio3:Music_HallOfFame',
    'surfing': 'audio3:Music_Surfing', 'bicycle': 'audio3:Music_BikeRiding',
    'item': 'audio1:SFX_Get_Item1_1', 'item2': 'audio1:SFX_Get_Item2_1',
    'key_item': 'audio1:SFX_Get_Key_Item_1', 'level_up': 'audio2:SFX_Level_Up',
    'caught': 'audio2:SFX_Caught_Mon',
    'menu': 'audio2:SFX_Press_AB_2', 'text': 'audio1:SFX_Press_AB_1',
    'start_menu': 'audio1:SFX_Start_Menu_1',
    'hit': 'audio2:SFX_Damage', 'faint': 'audio2:SFX_Faint_Thud',
    'go_inside': 'audio1:SFX_Go_Inside_1', 'go_outside': 'audio1:SFX_Go_Outside_1',
    'ledge': 'audio1:SFX_Ledge_1', 'cut': 'audio1:SFX_Cut_1',
    'boulder': 'audio1:SFX_Push_Boulder_1',
    'pc_on': 'audio1:SFX_Turn_On_PC_1', 'pc_off': 'audio1:SFX_Turn_Off_PC_1',
    'pc_enter': 'audio1:SFX_Enter_PC_1', 'pc_withdraw': 'audio1:SFX_Withdraw_Deposit_1',
    'healing_machine': 'audio1:SFX_Healing_Machine_1',
    'arrow_tiles': 'audio1:SFX_Arrow_Tiles_1', 'denied': 'audio1:SFX_Denied_1',
    'flute': 'audio1:SFX_Pokeflute', 'tink': 'audio1:SFX_Tink_1',
    **CHECKPOINT_THEMES,
}
# Press-AB chirps whose source gates are shorter than one 30FPS frame.
CHIRPS = {'menu', 'text', 'start_menu'}
# Channel periods 9315, 1728, 3888, 648. The joint loop is tick 1788480,
# which is too large to ship. Loop on channel 1's period and record the seam.
MANSION_LOOP_TICKS = 9315
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
    """Every songs.asm row, including maps the port has not installed yet."""
    music = {asset: name for name, asset in ASSETS.items()}
    routes = {}
    for row in catalog.maps:
        name = music.get(row['asset'])
        if name is None:
            raise AudioError(f'unrouted map song {row["asset"]}')
        routes['pokered:' + row['map']] = name
    return routes


def maybe_adapt(name, score):
    """Lengthen a chirp whose source gates would fall between 30FPS frames.

    Menu always uses the existing two-pitch adaptation. Other chirps use it
    only when a source gate is shorter than three ticks.
    """
    short = bool(score['notes']) and min(note[2] for note in score['notes']) < 3
    if name in CHIRPS and (name == 'menu' or short):
        adapted = adapt_menu(score)
        adapted['adapted'] = True
        return adapted
    return score


def emit_score(name, score):
    loop = 'nil' if score['loop'] is None else str(score['loop'])
    lines = [
        '-- Generated by tools/audio/scores.py; do not hand edit.',
        f'-- {score["asset"]}',
        '-- notes: tick, voice, gate ticks, Hz, amplitude, duty, envelope, optional wave key',
    ]
    if score.get('adapted'):
        lines.append('-- adapted: gates lengthened so a 30FPS observer cannot drop the chirp')
    if score.get('approximation'):
        lines.append('-- adapted: ' + score['approximation'])
    lines.append('KantoScores = KantoScores or {}')
    lines.append(f'KantoScores.{name} = {{ticks={score["ticks"]}, loop={loop}, notes={{')
    lines.extend('{' + ','.join(json.dumps(x) for x in note) + '},' for note in score['notes'])
    lines.append('}}')
    lines.append('')
    return '\n'.join(lines).encode()


def generate(source):
    catalog = Catalog(Source(source))
    scores = {}
    waves = {}
    for name, asset in ASSETS.items():
        trace = ScoreTrace(catalog, catalog.headers[asset]['family'])
        trace.load(asset)
        if asset == 'audio3:Music_CinnabarMansion':
            trace.run(MANSION_LOOP_TICKS + 1)
            notes = [note for note in trace.notes if note[0] < MANSION_LOOP_TICKS]
            score = dict(
                asset=asset, ticks=MANSION_LOOP_TICKS, loop=0, notes=notes,
                approximation='joint channel loop is tick 1788480; shipped loop is channel 1 period 9315',
            )
        else:
            result = trace.run()  # unchanged default bound; rejects rather than truncates
            if result['status'] == 'bound':
                raise AudioError(f'{asset}: adapted score did not close within default bound')
            score = dict(asset=asset, ticks=result['ticks'],
                         loop=result['repeat']['start_tick'] if result['repeat'] else None,
                         notes=trace.notes)
        scores[name] = maybe_adapt(name, score)
        waves.update(trace.waves)
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
    files = {}
    for name, score in scores.items():
        files[f'Source/audio/score/{name}.lua'] = emit_score(name, score)
    stub = '\n'.join([
        '-- Generated by tools/audio/scores.py; do not hand edit.',
        '-- Note rows load from audio/score/<name>.lua the first time that score plays.',
        '-- Score names include arrow_tiles and denied.',
        'KantoScores = KantoScores or {}',
        '',
    ]).encode()
    route_lines = [
        '-- Generated by tools/audio/scores.py; do not hand edit.',
        'KantoWaveforms = {',
        *[f'  ["{key}"] = "audio/waves/{key}",' for key in sorted(waves)],
        '}',
        '',
    ]
    files['Source/audio/scores.lua'] = stub
    files['Source/audio/routes.lua'] = '\n'.join(route_lines).encode()
    wave_assets = {f'Source/audio/waves/{key}.wav': wave_asset(data)
                   for key, data in sorted(waves.items())}
    files.update(wave_assets)
    tools = {p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in (
        'tools/audio/scores.py', 'tools/audio/source.py', 'tools/audio/catalog.py', 'tools/audio/trace.py')}
    adapted = {name: 'two source pitches, gates 3+5 ticks; native 30FPS chirp'
               for name, score in scores.items() if score.get('adapted')}
    approximations = {name: score['approximation'] for name, score in scores.items()
                      if score.get('approximation')}
    digest = hashlib.sha256()
    for path in sorted(files):
        if path.endswith('.lua'):
            digest.update(path.encode())
            digest.update(files[path])
    manifest = {'schema': 3, 'revision': REVISION, 'target': 'Playdate synth adaptation',
                'inputs_sha256': dict(sorted(catalog.source.hashes.items())), 'tools_sha256': tools,
                'menu_adaptation': adapted.get('menu', ''),
                'adapted': adapted,
                'approximations': approximations,
                'lazy_scores': True,
                'map_routes': routes,
                'checkpoint': {
                    'manifest_sha256': hashlib.sha256((ROOT/'Source/data/sourceMaps.json').read_bytes()).hexdigest(),
                    'maps': len(active), 'routed_maps': len(active & routes.keys()),
                    'unavailable': unavailable,
                },
                'score_sha256': digest.hexdigest(),
                'total_notes': sum(len(score['notes']) for score in scores.values()),
                'waveforms': {key: {'ram_hex': data.hex(), 'samples': 32,
                                   'path': f'Source/audio/waves/{key}.wav',
                                   'sha256': hashlib.sha256(wave_assets[f'Source/audio/waves/{key}.wav']).hexdigest()}
                              for key, data in sorted(waves.items())},
                'scores': {k: {x: v[x] for x in ('asset', 'ticks', 'loop')} | {'notes': len(v['notes']),
                           'adapted': bool(v.get('adapted'))}
                           for k, v in scores.items()}}
    files['tools/audio/score-manifest.json'] = (json.dumps(manifest, indent=2, sort_keys=True)+'\n').encode()
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', default=os.environ.get('POKERED_REFERENCE_DIR'))
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if not args.source: parser.error('--source or POKERED_REFERENCE_DIR required')
    payloads = generate(args.source)
    owned_dirs = ('Source/audio/score', 'Source/audio/waves')
    extras = []
    for directory in owned_dirs:
        folder = ROOT/directory
        if not folder.exists():
            continue
        for path in folder.iterdir():
            if not path.is_file():
                continue
            relative = path.relative_to(ROOT).as_posix()
            if relative not in payloads:
                extras.append(relative)
    if extras:
        if args.check:
            raise AudioError('stale score files: ' + ', '.join(sorted(extras)))
        for relative in extras:
            (ROOT/relative).unlink()
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
