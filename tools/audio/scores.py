#!/usr/bin/env python3
"""Small native-synth scores and single-cycle wave assets from the pinned parser."""
from __future__ import annotations
import argparse
import base64
from collections import defaultdict
import hashlib
import io
import json
import math
import os
import re
from pathlib import Path
import subprocess
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
    'faint_fall': 'audio2:SFX_Faint_Fall',
    'go_inside': 'audio1:SFX_Go_Inside_1', 'go_outside': 'audio1:SFX_Go_Outside_1',
    'ledge': 'audio1:SFX_Ledge_1', 'cut': 'audio1:SFX_Cut_1',
    'boulder': 'audio1:SFX_Push_Boulder_1',
    'pc_on': 'audio1:SFX_Turn_On_PC_1', 'pc_off': 'audio1:SFX_Turn_Off_PC_1',
    'pc_enter': 'audio1:SFX_Enter_PC_1', 'pc_withdraw': 'audio1:SFX_Withdraw_Deposit_1',
    'healing_machine': 'audio1:SFX_Healing_Machine_1',
    'arrow_tiles': 'audio1:SFX_Arrow_Tiles_1', 'denied': 'audio1:SFX_Denied_1',
    'flute': 'audio1:SFX_Pokeflute', 'tink': 'audio1:SFX_Tink_1',
    'intro_crash': 'audio3:SFX_Intro_Crash', 'intro_whoosh': 'audio3:SFX_Intro_Whoosh',
    # Fight intro, before PrepareTitleScreen. splash.asm and intro.asm.
    'intro_lunge': 'audio3:SFX_Intro_Lunge', 'shooting_star': 'audio3:SFX_Shooting_Star',
    # Overworld warp-pad and escape-rope spins. Not the Teleport move's SFX_BATTLE_33.
    'teleport_exit_1': 'audio1:SFX_Teleport_Exit1_1',
    'teleport_enter_1': 'audio1:SFX_Teleport_Enter1_1',
    'teleport_exit_2': 'audio1:SFX_Teleport_Exit2_1',
    'teleport_enter_2': 'audio1:SFX_Teleport_Enter2_1',
    'ball_poof': 'audio2:SFX_Ball_Poof',
    'ball_toss': 'audio2:SFX_Ball_Toss', 'run': 'audio2:SFX_Run',
    # LeaveMapAnim and EnterMapAnim when BIT_USED_FLY is set.
    'fly': 'audio1:SFX_Fly_1',
    'collision': 'audio1:SFX_Collision_1',
    'anne_horn': 'audio1:SFX_SS_Anne_Horn_1',
    'swap': 'audio1:SFX_Swap_1',
    'heal_hp': 'audio1:SFX_Heal_HP_1',
    'heal_ailment': 'audio1:SFX_Heal_Ailment_1',
    'save': 'audio1:SFX_Save_1',
    'purchase': 'audio1:SFX_Purchase_1',
    'pokedex_rating': 'audio1:SFX_Pokedex_Rating_1',
    'dex_page': 'audio2:SFX_Dex_Page_Added',
    'poisoned': 'audio1:SFX_Poisoned_1',
    'switch': 'audio1:SFX_Switch_1',
    'shrink': 'audio1:SFX_Shrink_1',
    'safari_pa': 'audio1:SFX_Safari_Zone_PA',
    **CHECKPOINT_THEMES,
}
# Press-AB chirps whose source gates are shorter than one 30FPS frame.
CHIRPS = {'menu', 'text', 'start_menu'}
# audio/alternate_tempo.asm plays a normal header, then overwrites channel
# pointers. These are not their own songs.asm rows, so they stay out of ASSETS
# and out of the map-route inverse.
ALT_SCORES = {
    'cities1_oak': (
        'audio1:Music_Cities1',
        {1: 'Music_Cities1_Ch1_AlternateTempo'},
        'Music_Cities1_Ch1_AlternateTempo',
    ),
    'meet_rival_slow': (
        'audio1:Music_MeetRival',
        {1: 'Music_MeetRival_Ch1_AlternateTempo'},
        'Music_MeetRival_Ch1_AlternateTempo',
    ),
    'meet_rival_league': (
        'audio1:Music_MeetRival',
        {
            1: 'Music_MeetRival_Ch1_AlternateStartAndTempo',
            2: 'Music_MeetRival_Ch2_AlternateStart',
            3: 'Music_MeetRival_Ch3_AlternateStart',
        },
        'Music_MeetRival_Ch1_AlternateStartAndTempo',
    ),
    # Music_RivalAlternateStart. Tempo 112 on the alternate start, then the
    # normal MeetRival main loop. Earlier rival exits, not the league one.
    'meet_rival_start': (
        'audio1:Music_MeetRival',
        {
            1: 'Music_MeetRival_Ch1_AlternateStart',
            2: 'Music_MeetRival_Ch2_AlternateStart',
            3: 'Music_MeetRival_Ch3_AlternateStart',
        },
        'Music_MeetRival_Ch1_AlternateStart',
    ),
}
# GetMoveSound copies the move table's pitch and tempo onto SFX_Faint_Fall.
# audio/engine.asm adds the pitch to the frequency low byte and uses
# tempo_modifier+128 as the SFX tempo (trace.wave_frequency / trace.timed).
PITCHED = {
    'faint_fall_agility': ('audio2:SFX_Faint_Fall', 0x20, 0xc0),
    'faint_fall_kinesis': ('audio2:SFX_Faint_Fall', 0x18, 0x20),
    'faint_fall_transform': ('audio2:SFX_Faint_Fall', 0xff, 0xff),
    'faint_fall_dizzy_punch': ('audio2:SFX_Faint_Fall', 0xff, 0x04),
}
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
    if score.get('retarget'):
        summary['retarget'] = score['retarget']
    if score.get('pitch') is not None:
        summary['pitch'] = score['pitch']
        summary['tempo'] = score['tempo']
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


# 32-byte little-endian records. Source/audio/engine.lua unpacks the same layout.
# Hz, amplitude, and duty are stored as round(value * 10000) so playback matches
# KantoShape's 4-decimal rounding. A float32 would not.
NOTE_STRUCT = struct.Struct('<HHBBIHHBBHHHHHBBBBBB')
assert NOTE_STRUCT.size == 32
FLAG_SHAPE = 1
FLAG_SLIDE = 2
FLAG_VIBRATO = 4
FLAG_DECREASING = 8
FLAG_DIRECTION = 16
FLAG_WAVE = 32


def _quantize(value, quantized):
    if quantized:
        return int(value)
    return int(math.floor(float(value) * 10000 + 0.5))


def _split_note(note, shape):
    body = list(note)
    if shape is None and body and isinstance(body[-1], dict):
        shape = body.pop()
    wave_name = None
    if body and isinstance(body[-1], str):
        wave_name = body.pop()
    if len(body) != 7:
        raise AudioError(f'note has {len(body)} fields: {note!r}')
    return body, wave_name, shape


def _pack_notes(notes, shapes=None, quantized=False):
    notes, shapes = _aligned(notes, shapes)
    waves = []
    index = {}
    blob = bytearray()
    for note, shape in zip(notes, shapes):
        body, wave_name, shape = _split_note(note, shape)
        tick, voice, gate, hz, amp, duty, env = body
        flags = 0
        wave_index = 0
        if wave_name:
            flags |= FLAG_WAVE
            wave_index = index.get(wave_name)
            if wave_index is None:
                waves.append(wave_name)
                wave_index = len(waves)
                index[wave_name] = wave_index
        period = 0
        slide = (0, 0, 0, 0, 0)
        vibrato = (0, 0, 0, 0, 0)
        if shape:
            flags |= FLAG_SHAPE
            period = int(shape['p'])
            if 's' in shape:
                flags |= FLAG_SLIDE
                slide = tuple(int(item) for item in shape['s'])
                if slide[4]:
                    flags |= FLAG_DECREASING
            if 'v' in shape:
                flags |= FLAG_VIBRATO
                vibrato = tuple(int(item) for item in shape['v'])
                if vibrato[4]:
                    flags |= FLAG_DIRECTION
        blob += NOTE_STRUCT.pack(
            int(tick), int(gate), int(voice), flags,
            _quantize(hz, quantized), _quantize(amp, quantized), _quantize(duty, quantized),
            int(env), wave_index,
            period, slide[0], slide[1], slide[2], slide[3], slide[4],
            vibrato[0], vibrato[1], vibrato[2], vibrato[3], vibrato[4],
        )
    return bytes(blob), waves


def unpack_notes(blob, waves):
    """Inverse of _pack_notes. Notes match the tables the synth builds."""
    if len(blob) % NOTE_STRUCT.size != 0:
        raise AudioError(f'packed score length {len(blob)} is not a multiple of 32')
    notes = []
    for offset in range(0, len(blob), NOTE_STRUCT.size):
        (tick, gate, voice, flags, hz, amp, duty, env, wave_index, period,
         s1, s2, s3, s4, s5, v1, v2, v3, v4, v5) = NOTE_STRUCT.unpack_from(blob, offset)
        note = [tick, voice, gate, hz / 10000, amp / 10000, duty / 10000, env]
        if flags & FLAG_WAVE:
            note.append(waves[wave_index - 1])
        if flags & FLAG_SHAPE:
            shape = {'p': period}
            if flags & FLAG_SLIDE:
                shape['s'] = [s1, s2, s3, s4, s5]
            if flags & FLAG_VIBRATO:
                shape['v'] = [v1, v2, v3, v4, v5]
            note.append(shape)
        notes.append(note)
    return notes


def _lua_b64(blob):
    # Lua long strings drop one leading newline. Base64 has no brackets.
    text = base64.b64encode(blob).decode('ascii')
    lines = [text[index:index + 76] for index in range(0, len(text), 76)]
    return '[[\n' + '\n'.join(lines) + '\n]]'


def _lua_waves(waves):
    if not waves:
        return ''
    return ',waves={' + ','.join(json.dumps(name) for name in waves) + '}'


def _lua_packed_fields(score, quantized, name, chunks):
    blob, waves = _pack_notes(score['notes'], score.get('shapes'), quantized)
    at = sum(len(chunk) for chunk in chunks)
    chunks.append(blob)
    loop = score.get('loop')
    loop_text = 'nil' if loop is None else str(int(loop))
    # The record bytes live in a sibling file. A base64 or integer-table
    # constant stays on the Lua heap after the pdz is collected.
    return (
        f'{{ticks={int(score["ticks"])},loop={loop_text},count={len(blob) // 32}'
        f'{_lua_waves(waves)},bin="audio/score/{name}.bin",at={at},bytes={len(blob)}}}'
    )


def score_blobs(text):
    """Packed records and wave lists, in source order."""
    blobs = []
    cache = {}
    for match in re.finditer(
        r'bin="(audio/score/[^"]+\.bin)",at=(\d+),bytes=(\d+)',
        text,
    ):
        relative, at, size = match.group(1), int(match.group(2)), int(match.group(3))
        window = text[max(0, match.start() - 800):match.start()]
        wave_match = re.search(r'waves=\{([^}]*)\}\s*,\s*$', window)
        waves = re.findall(r'"([^"]+)"', wave_match.group(1)) if wave_match else []
        if relative not in cache:
            cache[relative] = (ROOT / 'Source' / relative).read_bytes()
        blobs.append((waves, cache[relative][at:at + size]))
    return blobs


def emit_score(name, score):
    lines = [
        '-- Generated by tools/audio/scores.py; do not hand edit.',
        f'-- {score["asset"]}',
        '-- packed: 32-byte records in the sibling .bin. tick, voice, gate, Hz, amplitude, duty, envelope, optional wave',
        '-- shape, when present: {p=attack period, s={current,target,step,fraction,decreasing}, v={delay,depth,rate,low,direction}}',
        '-- s is Audio1_InitPitchSlideVars; v is the Audio1 vibrato counters at note-on',
    ]
    if score.get('retarget'):
        lines.append('-- channel entry ' + score['retarget'])
    if score.get('pitch') is not None:
        lines.append(
            f'-- pitch modifier {score["pitch"]} tempo modifier {score["tempo"]}'
        )
        lines.append('-- GetMoveSound writes wFrequencyModifier and wTempoModifier')
    if score.get('adapted'):
        lines.append('-- adapted: gates lengthened so a 30FPS observer cannot drop the chirp')
    if score.get('loop_basis') == 'parts':
        lines.append('-- each channel loops at its own pokered sound_loop 0 label')
    lines.append('KantoScores = KantoScores or {}')
    quantized = bool(score.get('quantized'))
    chunks = []
    if score.get('parts'):
        lines.append(f'KantoScores.{name} = {{ticks={score["ticks"]}, parts={{')
        for part in score['parts']:
            part = dict(part, quantized=quantized)
            lines.append(_lua_packed_fields(part, quantized, name, chunks) + ',')
        lines.append('}}')
    else:
        lines.append(f'KantoScores.{name} = {_lua_packed_fields(score, quantized, name, chunks)}')
    lines.append('')
    emit_score.bins = {f'Source/audio/score/{name}.bin': b''.join(chunks)}
    return '\n'.join(lines).encode()


def _camel(name):
    parts = name.lower().split('_')
    return parts[0] + ''.join(part.capitalize() for part in parts[1:])


# Pokered's move constant is one token. The battle table splits a few of them.
_MOVE_KEY_ALIASES = {
    'psychicm': 'psychic',
    'hijumpkick': 'highJumpKick',
}


def _port_move_keys():
    text = (ROOT / 'Source/battle/moves.lua').read_text()
    keys = re.findall(r'\n    ([A-Za-z][A-Za-z0-9]*) = function\(\)', text)
    return {key.lower(): key for key in keys}


def _move_key(name, port_keys):
    camel = _camel(name)
    if camel.lower() in port_keys:
        return port_keys[camel.lower()]
    return _MOVE_KEY_ALIASES.get(camel.lower(), camel)


# GetMoveSound replaces wFrequencyModifier and wTempoModifier with the row.
# The four faint-fall rows already have their own scores.
_FAINT_FALL_REUSE = {
    ('SFX_FAINT_FALL', 0x20, 0xc0): 'faint_fall_agility',
    ('SFX_FAINT_FALL', 0x18, 0x20): 'faint_fall_kinesis',
    ('SFX_FAINT_FALL', 0xff, 0xff): 'faint_fall_transform',
    ('SFX_FAINT_FALL', 0xff, 0x04): 'faint_fall_dizzy_punch',
}


def move_sfx_plan(catalog):
    """Move name, score name, and the traces still to render.

    data/moves/sfx.asm is one row per move. Rows that share a sound and the
    same two modifier bytes share one score.
    """
    labels = {}
    for line in catalog.source.read('constants/music_constants.asm').splitlines():
        code = line.split(';', 1)[0]
        match = re.search(r'music_const\s+(SFX_[A-Z0-9_]+),\s+([A-Za-z0-9_]+)', code)
        if match:
            labels[match.group(1)] = match.group(2)
    by_label = {}
    for key, header in catalog.headers.items():
        by_label.setdefault(header['label'], []).append(key)
    mapping = []
    traces = {}
    port_keys = _port_move_keys()
    for line in catalog.source.read('data/moves/sfx.asm').splitlines():
        match = re.search(
            r'db\s+(SFX_[A-Z0-9_]+),\s+\$([0-9a-fA-F]+),\s+\$([0-9a-fA-F]+)\s*;\s*([A-Z0-9_]+)',
            line,
        )
        if not match:
            continue
        const, pitch_text, tempo_text, move = match.groups()
        pitch, tempo = int(pitch_text, 16), int(tempo_text, 16)
        key = _move_key(move, port_keys)
        reused = _FAINT_FALL_REUSE.get((const, pitch, tempo))
        if reused:
            mapping.append((key, reused))
            continue
        label = labels.get(const)
        hits = by_label.get(label or '', [])
        if label is None or len(hits) != 1:
            raise AudioError(f'{const} has no single header for {move}')
        score_name = 'move_' + key
        # A later move with the same bytes reuses the first score name.
        for existing, (asset, existing_pitch, existing_tempo) in traces.items():
            if (asset, existing_pitch, existing_tempo) == (hits[0], pitch, tempo):
                score_name = existing
                break
        if score_name not in traces:
            traces[score_name] = (hits[0], pitch, tempo)
        mapping.append((key, score_name))
    if len(mapping) != 165:
        raise AudioError(f'move sound table has {len(mapping)} rows, expected 165')
    return mapping, traces


def emit_move_sfx(mapping):
    # The imported module stays empty. pdc keeps an imported file in the main
    # chunk, so the table itself is a file.run target and can be dropped.
    lines = [
        '-- Generated by tools/audio/scores.py; do not hand edit.',
        '-- data/moves/sfx.asm via GetMoveSound. Loaded the first time a move plays.',
        'KantoMoveSfx = {',
    ]
    for key, score in mapping:
        lines.append(f'    {key} = "{score}",')
    lines.append('}')
    lines.append('')
    return '\n'.join(lines).encode()


def emit_move_sfx_stub():
    return '\n'.join([
        '-- Generated by tools/audio/scores.py; do not hand edit.',
        '-- The move table is audio/moveSfxData.lua so importing this file stays empty.',
        '',
    ]).encode()


def _trace_retarget(catalog, asset, entries, label_pcs, loop_pcs, cited):
    """Trace a header after alternate_tempo.asm overwrites channel pointers."""
    header = catalog.headers[asset]
    saved = header['channels']
    header['channels'] = [dict(channel) for channel in saved]
    for channel in header['channels']:
        if channel['channel'] in entries:
            channel['entry'] = entries[channel['channel']]
    try:
        _trace, score = _trace_score(catalog, asset, label_pcs, loop_pcs)
    finally:
        header['channels'] = saved
    score['retarget'] = cited
    return score


def _trace_score(catalog, asset, label_pcs, loop_pcs, pitch=None, tempo=None):
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
    if pitch is None:
        trace.load(asset)
    else:
        trace.load(asset, pitch, tempo)
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
    for name, (asset, entries, cited) in ALT_SCORES.items():
        scores[name] = _trace_retarget(catalog, asset, entries, label_pcs, loop_pcs, cited)
    for name, (asset, pitch, tempo) in PITCHED.items():
        trace, score = _trace_score(catalog, asset, label_pcs, loop_pcs, pitch, tempo)
        score['pitch'] = pitch
        score['tempo'] = tempo
        scores[name] = score
        waves.update(trace.waves)
    move_mapping, move_traces = move_sfx_plan(catalog)
    for name, (asset, pitch, tempo) in move_traces.items():
        trace, score = _trace_score(catalog, asset, label_pcs, loop_pcs, pitch, tempo)
        score['pitch'] = pitch
        score['tempo'] = tempo
        scores[name] = score
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
        files.update(emit_score.bins)
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
    files['Source/audio/moveSfx.lua'] = emit_move_sfx_stub()
    files['Source/audio/moveSfxData.lua'] = emit_move_sfx(move_mapping)
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
        if path.endswith('.lua') or path.endswith('.bin'):
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


_DUMP_LUA = r'''
local root = os.getenv("SCORE_DIR")
local function q(n)
  return math.floor(n * 10000 + 0.5)
end
local function jstr(s)
  return '"' .. s:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
end
local function enc(v)
  local kind = type(v)
  if kind == "number" then
    if math.type(v) == "integer" then return string.format("%d", v) end
    return string.format("%.17g", v)
  elseif kind == "string" then
    return jstr(v)
  elseif kind == "table" then
    if v.p ~= nil then
      local parts = {string.format('"p":%d', v.p)}
      if v.s then parts[#parts + 1] = '"s":' .. enc(v.s) end
      if v.v then parts[#parts + 1] = '"v":' .. enc(v.v) end
      return "{" .. table.concat(parts, ",") .. "}"
    end
    local parts = {}
    for i = 1, #v do parts[i] = enc(v[i]) end
    return "[" .. table.concat(parts, ",") .. "]"
  end
  error("cannot encode " .. kind)
end
local function note_row(note)
  local count = #note
  local shape
  if type(note[count]) == "table" then
    shape = note[count]
    count = count - 1
  end
  local wave
  if type(note[count]) == "string" then
    wave = note[count]
    count = count - 1
  end
  if count ~= 7 then
    error("note fields " .. count)
  end
  local row = {
    note[1], note[2], note[3], q(note[4]), q(note[5]), q(note[6]), note[7],
  }
  if wave then row[#row + 1] = wave end
  if shape then row[#row + 1] = shape end
  return enc(row)
end
local function dump_score(score)
  local bits = {string.format('"ticks":%d', score.ticks)}
  if score.loop == nil then
    bits[#bits + 1] = '"loop":null'
  else
    bits[#bits + 1] = string.format('"loop":%d', score.loop)
  end
  if score.parts then
    local parts = {}
    for _, part in ipairs(score.parts) do
      local notes = {}
      for _, note in ipairs(part.notes) do notes[#notes + 1] = note_row(note) end
      parts[#parts + 1] = string.format(
        '{"ticks":%d,"loop":%s,"notes":[%s]}',
        part.ticks, part.loop == nil and "null" or string.format("%d", part.loop),
        table.concat(notes, ","))
    end
    bits[#bits + 1] = '"parts":[' .. table.concat(parts, ",") .. ']'
  else
    local notes = {}
    for _, note in ipairs(score.notes) do notes[#notes + 1] = note_row(note) end
    bits[#bits + 1] = '"notes":[' .. table.concat(notes, ",") .. ']'
  end
  return "{" .. table.concat(bits, ",") .. "}"
end
local names = {}
local pipe = io.popen('find "' .. root .. '" -name "*.lua" -print')
for path in pipe:lines() do names[#names + 1] = path end
pipe:close()
table.sort(names)
io.write("{")
for index, path in ipairs(names) do
  KantoScores = nil
  dofile(path)
  local name, score
  for key, value in pairs(KantoScores) do
    name, score = key, value
  end
  if index > 1 then io.write(",") end
  io.write(jstr(name) .. ":" .. dump_score(score))
end
io.write("}")
'''


def _header_meta(text):
    lines = text.splitlines()
    meta = {'asset': lines[1][3:]}
    for line in lines:
        if line.startswith('-- channel entry '):
            meta['retarget'] = line[len('-- channel entry '):]
        match = re.match(r'-- pitch modifier (\d+) tempo modifier (\d+)', line)
        if match:
            meta['pitch'] = int(match.group(1))
            meta['tempo'] = int(match.group(2))
        if line.startswith('-- adapted:'):
            meta['adapted'] = True
        if line.startswith('-- each channel loops'):
            meta['loop_basis'] = 'parts'
        if line.startswith('KantoScores.'):
            break
    return meta


def _same_note(packed, original):
    if packed[0] != original[0] or packed[1] != original[1] or packed[2] != original[2]:
        return False
    if packed[6] != original[6]:
        return False
    for index in (3, 4, 5):
        if int(math.floor(packed[index] * 10000 + 0.5)) != original[index]:
            return False
    packed_extra = packed[7:]
    original_extra = original[7:]
    if len(packed_extra) != len(original_extra):
        return False
    for left, right in zip(packed_extra, original_extra):
        if left != right:
            return False
    return True


def repack_shipped(root=None):
    """Rewrite Source/audio/score through emit_score from the notes already shipped.

    The tracer is unchanged. Packing the current tables keeps playback, and
    emit_score is the only writer.
    """
    folder = Path(root or ROOT) / 'Source/audio/score'
    dump = subprocess.run(
        ['lua', '-e', _DUMP_LUA],
        check=True, capture_output=True,
        env=dict(os.environ, SCORE_DIR=str(folder)),
    )
    if dump.stderr:
        sys.stderr.buffer.write(dump.stderr)
    shipped = json.loads(dump.stdout)
    mismatches = []
    pending = []
    for path in sorted(folder.glob('*.lua')):
        name = path.stem
        payload = shipped[name]
        meta = _header_meta(path.read_text())
        meta['quantized'] = True
        meta['ticks'] = payload['ticks']
        meta['loop'] = payload['loop']
        if payload.get('parts'):
            meta['parts'] = payload['parts']
        else:
            meta['notes'] = payload['notes']
        encoded = emit_score(name, meta)
        text = encoded.decode()
        blobs = score_blobs(text)
        originals = payload['parts'] if payload.get('parts') else [payload]
        if len(blobs) != len(originals):
            mismatches.append(f'{name}: packed {len(blobs)} sections, dumped {len(originals)}')
            continue
        file_bad = False
        for (waves, blob), section in zip(blobs, originals):
            unpacked = unpack_notes(blob, waves)
            notes = section['notes']
            if len(unpacked) != len(notes):
                mismatches.append(f'{name}: {len(unpacked)} notes, expected {len(notes)}')
                file_bad = True
                break
            for index, (got, want) in enumerate(zip(unpacked, notes)):
                if not _same_note(got, want):
                    mismatches.append(f'{name} note {index}: {got!r} != {want!r}')
                    file_bad = True
                    break
            if file_bad:
                break
        if not file_bad:
            pending.append((path, encoded, dict(emit_score.bins)))
    if mismatches:
        raise AudioError('packed scores do not round-trip: ' + '; '.join(mismatches[:8]))
    for path, encoded, bins in pending:
        path.write_bytes(encoded)
        for relative, blob in bins.items():
            (score_root / relative).write_bytes(blob)
    digest = hashlib.sha256()
    score_root = Path(root or ROOT)
    lua_paths = [
        'Source/audio/scores.lua',
        'Source/audio/moveSfx.lua',
        'Source/audio/moveSfxData.lua',
        'Source/audio/routes.lua',
        *sorted(
            path.relative_to(score_root).as_posix()
            for path in folder.glob('*.lua')
        ),
        *sorted(
            path.relative_to(score_root).as_posix()
            for path in folder.glob('*.bin')
        ),
    ]
    for relative in sorted(lua_paths):
        digest.update(relative.encode())
        digest.update((score_root / relative).read_bytes())
    manifest_path = score_root / 'tools/audio/score-manifest.json'
    manifest = json.loads(manifest_path.read_text())
    manifest['score_sha256'] = digest.hexdigest()
    manifest['tools_sha256']['tools/audio/scores.py'] = hashlib.sha256(
        (score_root / 'tools/audio/scores.py').read_bytes()
    ).hexdigest()
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
    print(f'repacked {len(shipped)} scores')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', default=os.environ.get('POKERED_REFERENCE_DIR'))
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--repack', action='store_true',
                        help='pack the shipped note tables through emit_score')
    args = parser.parse_args()
    if args.repack:
        if args.check or args.source:
            parser.error('--repack does not take --check or --source')
        repack_shipped()
        return
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
