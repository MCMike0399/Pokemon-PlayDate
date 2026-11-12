#!/usr/bin/env python3
"""Small native-synth scores and single-cycle wave assets from the pinned parser."""
from __future__ import annotations
import argparse
from collections import defaultdict
import hashlib
import io
import json
import math
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
    'intro_crash': 'audio3:SFX_Intro_Crash', 'intro_whoosh': 'audio3:SFX_Intro_Whoosh',
    **CHECKPOINT_THEMES,
}
# Press-AB chirps whose source gates are shorter than one 30FPS frame.
CHIRPS = {'menu', 'text', 'start_menu'}
# A joint label loop longer than this becomes one part per channel.
# Cinnabar Mansion's channel periods meet again at tick 1788480.
JOINT_LOOP_LIMIT = 20000
ROOT = Path(__file__).resolve().parents[2]

class ScoreTrace(Trace):
    """Intentional musical recurrence, never advertised as register recurrence.

    Same interpreter/tick arithmetic. A slide or vibrato note keeps the attack
    period plus the counters Audio1_InitPitchSlideVars and the vibrato command
    left in channel RAM. Playback steps those with Audio1_ApplyPitchSlide and
    Audio1_ApplyMusicAffects `.vibrato` (see Source/audio/shape.lua). The shape
    is parallel to the note so a note row stays length 7, or 8 with a wave key.
    """
    def __init__(self, catalog, family):
        self.notes = []
        self.shapes = []
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

    def _shape(self, ch, voice, period):
        """Attack period plus the slide and vibrato counters at note-on.

        Slide fields are what Audio1_InitPitchSlideVars stored: current is the
        frequency before toggle_perfect_pitch, and the written attack period is
        the register after that increment. Vibrato fields are the delay, the
        command extent n, the live rate byte, the note-on low byte, and direction.
        """
        if voice == 4 or period is None:
            return None
        slide = ch.slide
        if slide is None and not ch.vibrato_depth:
            return None
        shape = {'p': period & 2047}
        if slide is not None:
            shape['s'] = [
                slide['current'] & 65535, slide['target'] & 65535,
                slide['step'] & 255, slide['fraction'] & 255,
                1 if slide['decreasing'] else 0,
            ]
        if ch.vibrato_depth:
            shape['v'] = [
                ch.vibrato_delay & 255, ch.vibrato_depth & 15,
                ch.vibrato_rate & 255, ch.frequency_low & 255,
                1 if ch.vibrato_direction else 0,
            ]
        return shape

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
        self.shapes.append(self._shape(ch, voice, None if voice == 4 else period))


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
    shapes = score.get('shapes') or [None] * len(score['notes'])
    first, last = list(score['notes'][0]), list(score['notes'][-1])
    first[0], first[2] = 0, 3
    last[0], last[2] = 3, 5
    return dict(score, ticks=8, notes=[first, last], shapes=[shapes[0], shapes[-1]])


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


def _sound_loop_targets(catalog):
    """PC of each sound_loop 0 target, and PC of the sound_loop 0 command itself."""
    labels = defaultdict(set)
    commands = {}
    for (section, offset), cmd in catalog.commands.items():
        if cmd.op != 'sound_loop' or cmd.args[0] != '0':
            continue
        target = catalog.target(section[0], cmd.args[-1], cmd.scope)
        labels[target].add(cmd.scope)
        commands[(section, offset)] = cmd.scope
    return labels, commands


def _note_window(notes, voice, start, end):
    return [[note[0] - start, *note[1:]] for note in notes
            if note[1] == voice and start <= note[0] < end]


def _lcm(values):
    period = 1
    for value in values:
        period = period // math.gcd(period, value) * value
    return period


class LabelTrace(ScoreTrace):
    """Record the tick where each channel first reaches its infinite-loop label."""

    def __init__(self, catalog, family, scopes, label_pcs, loop_pcs):
        self.scopes = scopes
        self.label_pcs = label_pcs
        self.loop_pcs = loop_pcs
        self.expected = {scope for scope in loop_pcs.values() if scope in scopes}
        self.label_tick = {}
        self.label_scope = {}
        self.jumps = defaultdict(list)
        super().__init__(catalog, family)

    def byte(self, ch):
        scopes = self.label_pcs.get(ch.pc)
        if scopes and self.current_channel not in self.label_tick and scopes & self.scopes:
            self.label_tick[self.current_channel] = self.tick
            self.label_scope[self.current_channel] = next(iter(scopes & self.scopes))
        return super().byte(ch)

    def decode(self, i):
        ch = self.channels[i]
        scope = self.loop_pcs.get(ch.pc)
        if scope in self.scopes:
            self.jumps[i + 1].append(self.tick)
        return super().decode(i)

    def solutions(self):
        """Smallest note-identical period that starts on each channel's loop label."""
        solved = {}
        abandoned = set()
        for voice, label in self.label_tick.items():
            jumps = [jump for jump in self.jumps.get(voice, []) if jump > label][:8]
            period = None
            for end in jumps:
                span = end - label
                if self.tick < label + 2 * span:
                    break
                body = _note_window(self.notes, voice, label, label + span)
                nxt = _note_window(self.notes, voice, label + span, label + 2 * span)
                if body and body == nxt:
                    period = span
                    break
            if period is not None:
                solved[voice] = (label, period)
            elif len(jumps) >= 8 and self.tick >= label + 2 * (jumps[-1] - label):
                abandoned.add(voice)
        return solved, abandoned

    def finished(self, _tick, repeat):
        # A short channel can close before a later channel reaches its label.
        if self.expected - set(self.label_scope.values()):
            return _tick >= 30000 and repeat is not None
        solved, abandoned = self.solutions()
        voices = set(self.label_tick)
        if not voices:
            return repeat is not None
        pending = voices - set(solved) - abandoned
        if pending:
            return False
        if abandoned or len(set(solved.values())) == 1:
            return True
        start = max(label for label, _ in solved.values())
        period = _lcm(span for _, span in solved.values())
        if period > JOINT_LOOP_LIMIT:
            return True
        return self.tick >= start + 2 * period


def _boundary_notes(notes, tick):
    return sorted((note[1:] for note in notes if note[0] == tick), key=lambda row: row[0])


def _aligned(notes, shapes):
    if shapes is None:
        shapes = [None] * len(notes)
    if len(shapes) != len(notes):
        raise AudioError(f'shape rows {len(shapes)} do not match {len(notes)} notes')
    return list(notes), list(shapes)


def _clip_pair(notes, shapes, ticks):
    notes, shapes = _aligned(notes, shapes)
    kept_n, kept_s = [], []
    for note, shape in zip(notes, shapes):
        if note[0] < ticks:
            kept_n.append(note)
            kept_s.append(shape)
    return kept_n, kept_s


def resolve_loop(trace, result):
    """Loop where pokered's sound_loop 0 label repeats the same notes.

    Channels that share a label use one window. Channels whose periods only
    meet past JOINT_LOOP_LIMIT keep a part each, so a later channel is not
    restarted on an earlier channel's boundary. A label whose first pass is
    not note-identical falls back to the register repeat.
    """
    missing = trace.expected - set(trace.label_scope.values())
    solved, _abandoned = ({}, set()) if missing else trace.solutions()
    notes, shapes = _aligned(trace.notes, trace.shapes)
    if solved and len(solved) == len(trace.label_tick) and not missing:
        if len(set(solved.values())) == 1:
            label, period = next(iter(solved.values()))
            ticks = label + period
            kept, kept_shapes = _clip_pair(notes, shapes, ticks)
            return dict(ticks=ticks, loop=label, notes=kept, shapes=kept_shapes,
                        loop_basis='label', parts=None)
        start = max(label for label, _period in solved.values())
        period = _lcm(span for _label, span in solved.values())
        if period <= JOINT_LOOP_LIMIT and trace.tick >= start + 2 * period:
            same = all(
                _note_window(notes, voice, start, start + period)
                == _note_window(notes, voice, start + period, start + 2 * period)
                for voice in solved
            )
            if same:
                ticks = start + period
                kept, kept_shapes = _clip_pair(notes, shapes, ticks)
                return dict(ticks=ticks, loop=start, notes=kept, shapes=kept_shapes,
                            loop_basis='joint', parts=None)
        parts = []
        for voice, (label, period) in sorted(solved.items()):
            ticks = label + period
            part_notes, part_shapes = [], []
            for note, shape in zip(notes, shapes):
                if note[1] == voice and note[0] < ticks:
                    part_notes.append(note)
                    part_shapes.append(shape)
            parts.append(dict(
                voice=voice, ticks=ticks, loop=label,
                notes=part_notes, shapes=part_shapes,
            ))
        return dict(ticks=max(part['ticks'] for part in parts), loop=None, notes=[],
                    shapes=[], loop_basis='parts', parts=parts)
    if not result.get('repeat'):
        raise AudioError('music did not reach a loop label or a register repeat')
    start = result['repeat']['start_tick']
    end = result['repeat']['end_tick']
    kept, kept_shapes = _clip_pair(notes, shapes, end)
    if start >= 1 and _boundary_notes(kept, start - 1) == _boundary_notes(notes, end - 1):
        # The register snapshot is one tick after the downbeat. Keep that
        # downbeat inside the window so later laps retrigger it.
        if _boundary_notes(kept, start - 1):
            start -= 1
            end -= 1
            kept, kept_shapes = _clip_pair(kept, kept_shapes, end)
    return dict(ticks=end, loop=start, notes=kept, shapes=kept_shapes,
                loop_basis='state', parts=None)


def _note_count(score):
    if score.get('parts'):
        return sum(len(part['notes']) for part in score['parts'])
    return len(score['notes'])


def _score_summary(score):
    summary = {
        'asset': score['asset'],
        'ticks': score['ticks'],
        'loop': score['loop'],
        'notes': _note_count(score),
        'adapted': bool(score.get('adapted')),
    }
    if score.get('loop_basis'):
        summary['loop_basis'] = score['loop_basis']
    if score.get('parts'):
        summary['parts'] = [
            {'voice': part['voice'], 'loop': part['loop'], 'ticks': part['ticks'],
             'notes': len(part['notes'])}
            for part in score['parts']
        ]
    return summary


def _lua_shape(shape):
    """Trailing table stepped by Source/audio/shape.lua. Absent when unused."""
    if not shape:
        return None
    parts = [f'p={shape["p"]}']
    if 's' in shape:
        current, target, step, fraction, decreasing = shape['s']
        parts.append(f's={{{current},{target},{step},{fraction},{decreasing}}}')
    if 'v' in shape:
        delay, depth, rate, low, direction = shape['v']
        parts.append(f'v={{{delay},{depth},{rate},{low},{direction}}}')
    return '{' + ','.join(parts) + '}'


def _note_literals(notes, shapes):
    notes, shapes = _aligned(notes, shapes)
    lines = []
    for note, shape in zip(notes, shapes):
        body = ','.join(json.dumps(x) for x in note)
        rendered = _lua_shape(shape)
        if rendered:
            body += ',' + rendered
        lines.append('{' + body + '},')
    return lines


def emit_score(name, score):
    lines = [
        '-- Generated by tools/audio/scores.py; do not hand edit.',
        f'-- {score["asset"]}',
        '-- notes: tick, voice, gate ticks, Hz, amplitude, duty, envelope, optional wave key',
        '-- shape, when present: {p=attack period, s={current,target,step,fraction,decreasing}, v={delay,depth,rate,low,direction}}',
        '-- s is Audio1_InitPitchSlideVars; v is the Audio1 vibrato counters at note-on',
    ]
    if score.get('adapted'):
        lines.append('-- adapted: gates lengthened so a 30FPS observer cannot drop the chirp')
    if score.get('loop_basis') == 'parts':
        lines.append('-- each channel loops at its own pokered sound_loop 0 label')
    lines.append('KantoScores = KantoScores or {}')
    if score.get('parts'):
        lines.append(f'KantoScores.{name} = {{ticks={score["ticks"]}, parts={{')
        for part in score['parts']:
            lines.append(f'{{ticks={part["ticks"]}, loop={part["loop"]}, notes={{')
            lines.extend(_note_literals(part['notes'], part.get('shapes')))
            lines.append('}},')
        lines.append('}}')
    else:
        loop = 'nil' if score['loop'] is None else str(score['loop'])
        lines.append(f'KantoScores.{name} = {{ticks={score["ticks"]}, loop={loop}, notes={{')
        lines.extend(_note_literals(score['notes'], score.get('shapes')))
        lines.append('}}')
    lines.append('')
    return '\n'.join(lines).encode()


def _trace_score(catalog, asset, label_pcs, loop_pcs):
    header = catalog.headers[asset]
    scopes = {channel['entry'] for channel in header['channels']}
    if header['kind'] == 'music':
        trace = LabelTrace(catalog, header['family'], scopes, label_pcs, loop_pcs)
        trace.load(asset)
        result = trace.run(max_ticks=40000, on_tick=trace.finished)
        if result['status'] == 'ended':
            return trace, dict(asset=asset, ticks=result['ticks'], loop=None,
                               notes=trace.notes, shapes=trace.shapes,
                               loop_basis=None, parts=None)
        if result['status'] == 'bound' and not trace.label_tick:
            raise AudioError(f'{asset}: adapted score did not close within default bound')
        try:
            resolved = resolve_loop(trace, result)
        except AudioError as exc:
            raise AudioError(f'{asset}: {exc}') from exc
        if resolved['loop_basis'] == 'state' and result['status'] == 'bound':
            raise AudioError(f'{asset}: register repeat was not reached')
        return trace, dict(asset=asset, **resolved)
    trace = ScoreTrace(catalog, header['family'])
    trace.load(asset)
    result = trace.run()
    if result['status'] == 'bound':
        raise AudioError(f'{asset}: adapted score did not close within default bound')
    return trace, dict(asset=asset, ticks=result['ticks'],
                       loop=result['repeat']['start_tick'] if result['repeat'] else None,
                       notes=trace.notes, shapes=trace.shapes,
                       loop_basis=None, parts=None)


def generate(source):
    catalog = Catalog(Source(source))
    label_pcs, loop_pcs = _sound_loop_targets(catalog)
    scores = {}
    waves = {}
    for name, asset in ASSETS.items():
        trace, score = _trace_score(catalog, asset, label_pcs, loop_pcs)
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
                'total_notes': sum(_note_count(score) for score in scores.values()),
                'waveforms': {key: {'ram_hex': data.hex(), 'samples': 32,
                                   'path': f'Source/audio/waves/{key}.wav',
                                   'sha256': hashlib.sha256(wave_assets[f'Source/audio/waves/{key}.wav']).hexdigest()}
                              for key, data in sorted(waves.items())},
                'scores': {name: _score_summary(score) for name, score in scores.items()}}
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
