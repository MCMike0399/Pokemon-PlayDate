# First native synth packet

Audio was explicitly unparked on 2026-10-28 for this packet. Branch
`t3/kanto-audio-synth` uses the existing tool-created worktree. Exact `3cc674d`
was merged first, then `ef9bff7`, without conflicts. The tracked game Source at
that merge equals `3cc674d`; parser/oracle/renderer code and historical evidence
are preserved. No shared gameplay file, art, session, codec or mechanics was
edited. Follow-up to `4bba9e7` adds Vermilion/Anne and a read-only observer.
`tools/audio/root-hooks.patch` is an **unapplied**, main-only integration patch:
one import plus `KantoAudio.updateGame(game)` after `machine:handleInput()`.
It supersedes the earlier multi-file hook patch. Do not apply both versions or
combine the observer with duplicate explicit hit/menu hooks.

`Source/game/kantoAudio.lua` exposes dot-call functions:

```lua
KantoAudio.updateGame(game) -- once after game input; observes context, then updates audio
KantoAudio.enterMap(zone) -- optional explicit API; zone object or stable ID
KantoAudio.battleStart("wild") -- or "trainer"
KantoAudio.battleEnd()
KantoAudio.playSFX("menu") -- hit, faint, heal
KantoAudio.playCry("bulbasaur") -- species key; nonblocking, true or false/reason
KantoAudio.setLowHP(true) -- effective only inside battle; false stops immediately
KantoAudio.update() -- once per frame, including menus/dialogue
KantoAudio.stop() -- New Game/title/suspend boundary as root chooses
```

Routing is generated from the original pinned map-song table for fifteen supported music tracks: Pallet, Routes1–4, Cities1–2, Vermilion,
S.S. Anne, Pokémon Center/Mart, Gym, Dungeon2–3, wild and trainer battle.
This includes Vermilion City, Fan Club, Pidgey/Trade houses and Route11 gates;
the dock and every Anne deck/room use Anne. Authored Pallet/home IDs retain their
aliases. Unsupported themes still stop music, rather than being relabeled:
All 65 active manifest maps now have their original themes, including the
Old Rod House using Cities2. Centers and Marts share the original Pokémon Center theme; Gym interiors use
the original Gym theme. This does not add Gym Leader battle music. Healing's jingle is available now. Generated routes do not
claim that unused source maps are playable in the game.

`updateGame(game)` reads `game.machine.stack`, session identity, `currentZone`,
the active battle's identity/player/enemy/trainer name, and visible presentation
fields. It never calls a gameplay method, samples RNG, writes game/session/UI
state, installs a listener or wraps a callback. Its own snapshots track:

- Map changes and new sessions; Title entry stops music, effects and alarm.
- Actual battle identity, including party/bag/dialogue overlays; field music
  returns after battle, and trainer fights use the trainer track.
- Observed HP decreases and crossings to zero, with faint taking priority over
  a damage blip. First samples and identity switches establish a baseline.
- The active player's <=20% low-HP threshold, excluding fainted Pokémon, including
  overlays. Healing/switching clears the alarm on the next observed update.
- Entry into the existing `heal-animation` phase (jingle only, no transaction).
- Visible `BattleMenu` and battle main/move menu cursors; `selected` in list/swap/
  browse phases covers party/bag/shop/Pokédex lists. Menu appearance also blips.

This is frame observation, not an event log. Multiple hits in one frame coalesce;
a Pokémon replaced before its zero HP is observed may not emit faint. First
samples after attaching mid-battle deliberately do not invent hits. Confirm/
cancel with no visible menu/phase change cannot be inferred. Explicit API hooks
remain available for those cases, and for suspension. Root/B should add those
only where needed, without putting audio inside battle rules. The bridge preserves
Gen V mechanics and the original151; its game-context behavior is compile-checked,
not yet established by a native checkpoint run.

The readability cleanup after `bf9995d` expands the two hand-written audio Lua
modules into one statement per line and block control flow. It changes neither
routing nor scheduling behavior and adds no contracts. Field verification against
this checkout found no concrete mismatch: `data/pokemon.lua` owns numeric `hp`
and `maxHP`; `game/battleState.lua` exposes `battle` and `scene`; Battle exposes
`player`, `enemy` and `trainerName`; `lib/statemachine.lua` stores actual state
objects in `stack`; `ui/menu.lua` uses `isActive` and `selectedIndex`;
`battle/battleScene.lua` owns `mainMenu`/`moveMenu`; party/bag/Pokédex lists and
shop browsing use `selected`; `game/eventState.lua` sets `phase` to
`"heal-animation"` for the Center animation. These are source checks, not native
runtime acceptance. HP observations use logical Pokémon HP, not interpolated
presentation gauges, so sound need not coincide with an animation's completion.
Shop quantity changes and non-cursor actions are outside the observer's coverage.

## Reproduction and implementation

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python tools/audio/scores.py --check
# Regenerate only when intentionally changing the compiler:
python tools/audio/scores.py
python -m unittest tools.audio.test_scores -v
python tools/audio/integration_patch.py > tools/audio/root-hooks.patch
git apply --check tools/audio/root-hooks.patch
# Root/B applies only after reviewing/reconciling their live gameplay files:
# git apply tools/audio/root-hooks.patch
```

The generator uses the existing pinned `Catalog`, `Source` and `Trace`, with
pokered `af519899719f0754965776faac0e836a3b906e6d`. The checksum manifest lists
consumed source blobs, compiler/parser hashes and the generated score hash.
Inputs remain in the external pinned reference checkout; no extracted reference
dump or PCM soundtrack is shipped. Eight tiny single-cycle wave assets accompany
the approximately 334 KiB Lua score, which contains Pallet,
Routes1–4, Cities1–2, Vermilion, Anne, Pokémon Center/Mart, Gym, Dungeon2–3,
wild/trainer battle, Pokémon
healed, Press AB, Damage and Faint Thud,
plus the direct source alarm. Each row holds onset, physical voice, gate length,
Hz, amplitude, duty and envelope byte; voice 3 also carries a bank-qualified
wave key. Source tick duration is exactly
70224/4194304 seconds; source delay arithmetic and fractional carry are reused.

`ScoreTrace` intentionally closes the **adapted musical score**, excluding
registers and continuous effect phase from its recurrence key. Persistent
vibrato/slide phase is not part of this instrument model. This is separate from
the unchanged full-register recurrence. The host test expands the short score
through full register recurrence for fourteen music tracks, and through the
unchanged default bound for Routes2, comparing every adapted note row. The default 120000-tick rejection remains. Lavender/Dungeon1
are not selected and their long full vibrato periods remain documented and
bounded; no PCM seam or APU equivalence follows from these musical loops.

Four `playdate.sound.synth` sources share one private sound channel, with master
gain 0.22. Pulse voices map source duty to SDK square pulse width. Voice 3 uses
the source wave RAM cycle through the SDK wavetable oscillator, as detailed
below. Noise maps source noise
rate to SDK noise, with 20..16000 Hz clamp; GB LFSR width/phase is not reproduced.
Source pulse/noise envelopes become SDK ADSR; rising envelopes are an approximate
attack. Pitch slides land immediately at their source target, avoiding the
ultrasonic starting pitch of the heal harmony. Continuous vibrato, hardware
sweep, rotating duty effects between notes, stereo routing and exact APU length/
envelope quirks are omitted. This is an intentionally audible native adaptation.

The audio clock drives gate expiration; SDK `playNote` gets the remaining finite
length and `noteOff` explicitly releases replaced/expired notes. There is no
frame-count drift accumulator. Dispatch happens at the calling frame rate:
30 FPS can coalesce/skip one-tick ornament notes. Press AB is explicitly adapted
to its first and final source pitches with 3- and 5-tick gates (about 50 and
84 ms), totaling 134 ms. Host checks sample 100 evenly spaced phases of a 30 FPS observer
to check that neither gate can disappear entirely between updates. This
changes source timing and is not an APU-accuracy claim. There is no
lookahead queue, sample-accurate onset claim, hardware phase or seamless-loop
claim. After long stalls, whole musical laps are skipped rather than replayed.

There is one current SFX request, with explicit adaptation priority
`faint > hit > menu`; equal priority replaces. SFX steals only its active physical
voices. Alarm steals pulse 1 below SFX; source transitions occur at ticks 0 and
11 of a 31-tick cycle. Its held tones do not leak music between beeps. Heal is a
music overlay; music keeps advancing beneath it. Music also advances beneath
SFX/alarm; a released voice resumes the remaining current note with a new attack.
This is not the original engine's eight-channel numeric-priority arbiter.
No game RNG, callbacks, saved state or ownership transaction is consumed.

## Root-only native listening job

The small probe imports the actual score/engine/facade into a private bundle. It
plays a 54-second sequence: Pallet 0s, menu 6s, Route1 9s, wild18s, hit23s,
faint25s, alarm27..30s, trainer32s, Vermilion41s, heal43s, Anne48s, stop54s.
It uses the existing SDK probe owner lock, exact Simulator process and isolated
Data lifecycle. A result reports API execution, never listening acceptance.
Workers compile only:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python tools/audio/synth_probe.py --output "$POKEMON_ENV/evidence/kanto-synth-build-UNIQUE"
# Root alone, when no other native job owns the Simulator:
python tools/audio/synth_probe.py --execute --runtime-owner root \
  --output "$POKEMON_ENV/evidence/kanto-synth-listen-UNIQUE"
```

For actual Simulator output, use the small root-only [ScreenCaptureKit recorder](audio-native-capture.md).
It selects the exact owned PID and disables microphone capture. Root's available
AVFoundation inputs (MacBook Microphone and Microsoft Teams Audio) are not
qualified output loopback devices. No native recording/listening has run here.
The capture guide gives the compile-only result, Screen Recording permission
requirement, two/three-second root preflight commands, optional native window video, expected
PCM16 WAV/MP4 formats and limits. Root alone records the 60–90 second showcase.

Installed SDK 3.1.2 `Inside Playdate.html` was read for synth `playNote` (Hz,
finite seconds, one pending note), `noteOff`, `stop`, `setADSR`, square parameter 1,
`channel.new/addSource/setVolume` and `sound.getCurrentTime`. The compile manifest
pins the local SDK documentation and compiler hashes. SDK compile logs and source
inventories live outside git under environment evidence.

## Verification and outstanding acceptance

- At `bf9995d`, five synth host checks passed: six-track musical loop expansion, finite gates/
  source pitch, source alarm transitions, pinned checkpoint routing and 30 FPS
  menu-gate visibility across sampled frame phases.
- At `4bba9e7`, the existing 51 parser/oracle/renderer/long-closure checks passed, zero skips,
  with pinned RGBDS 1.0.4 on PATH. The intentional missing-tools negative test
  prints its expected qualification failure. Production audio tools unchanged.
- Native import bundle compiled with the actual SDK 3.1.2, compile only.
  Readability-cleanup evidence:
  `~/Developer/Pokemon-PlayDate-env/evidence/kanto-synth-readable-compile-20261028-01/`.
  Generator `--check` still reproduces the unchanged scores and manifest.
- Main-only hook patch passes `git apply --check`; gameplay files remain unchanged.

No Simulator, playback, recording or physical device was run by this worker.
Root must listen for recognizable melody/tempo, mix level, wave/noise character,
menu audibility, audible transitions and resumed voices, alarm cancellation,
healing return, and any 30 FPS jitter before accepting. Main-game lifecycle and
runtime allocation/performance remain root integration checks. The bridge needs root gameplay acceptance. Full soundtrack,
cries, flute, victory tracks and unsupported map themes are later work.


## Center/Mart and Gym follow-up

The worker merged exact `9d2f471` from `wip/play-quality-native` first, then
selected `audio1:Music_Pokecenter` and `audio1:Music_Gym` in the existing score
generator. No parser, synth engine, facade or gameplay behavior changed.
`Source.read` verifies each consumed input against pokered revision
`af519899719f0754965776faac0e836a3b906e6d` before compilation. The manifest
records both source theme checksums, the map-song table checksum, generator
hash and generated Lua checksum. Existing scores are unchanged.

The Center score has 315 note rows, a loop start at tick 1 and a recorded end at
tick 1729. The Gym score has 343 rows, a loop start at tick 208 and an end at
tick 1864. The existing host loop check now compares both against full-register
recurrence, including all adapted onsets, gates, pitches, duties and envelopes.
Routing checks cover Viridian, Pewter, Cerulean and Vermilion Centers/Marts,
the Mt. Moon Center, and Pewter/Cerulean/Vermilion Gyms. Every generated route
also has to match the bank-qualified asset in the pinned map-song table.
The generator retains all source routes for selected songs, including unused
and later source IDs. It adds no maps, events or later campaign content.

Worker verification on 2026-10-28 passed generator reproduction, all five synth
host checks, all 63 existing parser/oracle/renderer/probe host checks with zero
skips, and production `make compile` using SDK 3.1.2. The expected missing-tools
negative test printed its qualification failure; the suite passed. A comparison
against the merged base confirmed all 11 prior scores, all prior routes and all
consumed input hashes are unchanged. No Simulator or listening ran here.

Root can repeat the host checks and compile with:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python tools/audio/scores.py --check
python -m unittest tools.audio.test_scores -v
python -m unittest discover -s tools/tests -p 'test_audio_*.py' -v
make compile
```

For root-only listening, use the existing harness with a supplementary fixture
scenario. This is an audio witness, not a campaign journey or a new Simulator
contract. The waits span the first loop boundary of each added theme. Use a
fresh evidence directory for each invocation.

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python - <<'PYROOT'
import json
import os
from pathlib import Path
path = Path(os.environ['POKEMON_ENV']) / 'evidence/center-gym-listen-20261028.json'
commands = []
for zone, frames in (
    ('kanto_vermilion_pokecenter', 1020),
    ('kanto_vermilion_mart', 180),
    ('kanto_vermilion_gym', 1140),
):
    commands.extend([
        {'op': 'fixture', 'options': {'zone': zone, 'intro': 'skip'}},
        'wait ' + str(frames),
        'snapshot',
    ])
path.write_text(json.dumps({'commands': commands}, indent=2) + '\n')
print(path)
PYROOT
python tools/harness/run.py \
  --scenario "$POKEMON_ENV/evidence/center-gym-listen-20261028.json" \
  --timeout 120 --max-frames 2700 \
  --output "$POKEMON_ENV/evidence/center-gym-listen-UNIQUE"
```

Listen for recognizable Center/Mart and Gym melodies, level balance and audible
loop boundaries. The fixture resets sessions, so it does not prove natural
Center/Mart transitions, healing return or battle return; root should check
those during ordinary play. The existing 54-second synth probe predates these
two themes and does not exercise them. All documented noise, effect,
voice-resume and 30 FPS scheduling limitations above still apply. No APU
fidelity, seamless looping, native listening or physical-device acceptance is
claimed by this follow-up.


## Source wave RAM follow-up

Voice 3 now carries the actual 16 bytes written by the existing `Trace` to
`ff30` through `ff3f` at each audible note trigger. Missing writes or inconsistent
bytes for the same bank-local wave fail generation. The generator expands high
nibble then low nibble into one 32-sample cycle. It maps each four-bit value `v`
to `(15 - 2*v) * 2184`, matching the existing renderer's DAC polarity without
per-wave normalization or mean subtraction. Each asset is a 108-byte PCM16 mono
WAV containing 64 bytes of sample data. These are oscillator tables, not rendered
notes or a recorded soundtrack.

Wave keys retain both source family and wave pointer, for example
`audio1-wave1` and `audio2-wave1`. The six currently consumed keys remain separate
even when bytes match across banks. The schema 2 score manifest records each
wave's original RAM hex, asset path, cycle length and SHA-256. Source checksums
remain pinned through the unchanged parser. `scores.py --check` checks every
asset byte as well as the Lua and manifest. Generated voice-3 rows append the
wave key as field eight; other voices retain their seven-field rows.

Installed SDK 3.1.2 documents Lua `synth:setWavetable(sample, samplesize, xsize)`
with uncompressed PCM16 mono data and a power-of-two cell size. The engine loads
and retains the sample for each key, requires PCM16 mono, then configures one
32-sample cell at position zero. `playNote` still receives source cycle frequency
`65536 / (2048 - period)` in Hz. The asset's 44100 Hz container rate does not set
the musical note. All selected wave notes lie between 97.9611 and 585.1429 Hz,
within the existing pitch clamp.

The selected note owns its wave key. When a jingle or SFX releases voice 3, the
existing arbiter resumes the current music note and restores that note's table
before playing it. No layer priority, clock, note gate, map routing or gameplay
hook changed. The existing isolated synth probe now copies the wave asset
directory too. It remains a root-only playback job; the commands above still
apply.

Verification on 2026-10-28 passed all seven synth host checks, including exact
bank-local table bytes, nibble order, PCM format, unchanged source pitch and
expanded musical loops with waveform identities. A comparison with the prior
commit confirmed every original field of all 3926 note rows, all routes, all
score lengths/loops/counts and all consumed source hashes are unchanged.
Production `make compile` and the existing isolated synth-probe compilation
passed with SDK 3.1.2. Each compiled `.pda` contains all 32 signed samples exactly,
with the uncompressed mono16 format tag. Compile-only probe evidence is at
`~/Developer/Pokemon-PlayDate-env/evidence/kanto-wave-build-20261028-01/`.

Compilation does not execute the Lua wavetable calls. Root must still verify
runtime loading, recognizable timbre, pitch, mix level and voice restoration,
using the existing probe and ordinary game listening. The SDK controls oscillator
interpolation, resampling and phase; preserving source table samples does not
reproduce GB sample-hold timing, first-sample behavior, wave RAM access quirks,
DAC filtering or oscillator continuity. Source wave volume still uses the
existing gain approximation rather than exact four-bit right-shift quantization.
Vibrato/slide, envelope, noise and frame-scheduling limits above remain. No
Simulator, playback, recording or device run occurred in this follow-up, and
no APU-fidelity claim is made.


## Music for the active 65-map manifest

This follow-up selects the seven missing original themes used by
`Source/data/sourceMaps.json`, whose SHA-256 is
`47e295dd5e39d2894e39e6dccbd13b148525a9712478202a424201c4220294b4`.
The score manifest records this hash and the 65/65 routed-map count. No map,
world event, main hook, UI, domain owner or baseline was edited. Existing
routes remain intact. Newly selected songs receive routes only for active
manifest IDs, so adding Cities1 does not add music routes for future regions.
The exact pinned source map-song table still determines every association.

| Added theme | Main uses in the active manifest | Notes | Loop start / recorded end, in ticks |
| --- | --- | ---: | ---: |
| Cities1 | Viridian, Pewter, museum, Day Care, gates and Underground entrances | 610 | 1 / 3457 |
| Cities2 | Cerulean, its houses and bike shop, Bill, Old Rod House | 306 | 223 / 1999 |
| Routes2 | Routes24 and 25 | 265 | 1 / 1141 |
| Routes3 | Routes3, 4, 5, 6 and 22 | 373 | 292 / 1624 |
| Routes4 | Route11 | 483 | 223 / 1999 |
| Dungeon2 | Viridian Forest and Diglett's Cave entrances/interior | 744 | 1 / 6049 |
| Dungeon3 | All three Mt. Moon floors | 1090 | 4972 / 9955 |

The names above are original song labels, not deductions from route numbers.
For example, Routes5/6 use Routes3 and the north/south Underground interior
continues to use Routes1. The new packet adds 33 routes and 3871 note rows.
All previous score blocks, route values, wave metadata and consumed pokered
input hashes match the previous commit exactly. Bank3 adds `audio3-wave0` and
`audio3-wave3`; the original six wave assets are unchanged.

All seven adapted scores repeat within the existing 120000-tick bound.
Full-register traces repeat within that bound for six of them. Routes2's full
register/effect-phase trace remains bounded at 120000 processed ticks, with no
recurrence established. Its 1140-tick adapted musical lap matches every note
through that entire bounded trace, including wave identity. This is musical
recurrence for the current synth model; it is not full-register closure, a PCM
seam or APU fidelity. No parser bound, recurrence key or synth engine changed.
Generation still rejects a selected adapted stream if it reaches the default
bound instead of ending or repeating.

The total is **7797 note rows across 20 scores**, including fifteen music themes
and the existing five effect/alarm scores. Generated Lua is 341544 bytes.
The eight wave WAVs total 864 bytes, with 512 bytes of actual PCM cycle data.
With SDK 3.1.2's default compression, compiling the score module separately
produces a 95201-byte `main.pdz`; all eight production wave `.pda` files are
80 bytes each. Thus **compiled score data plus wave assets is 95841 bytes
(93.6 KiB)**, excluding synth engine/facade code, package metadata and other
game resources. The separately compiled engine module is 2944 bytes. These
file sizes do not measure loaded Lua table memory or runtime performance.
Production combines Lua modules in its own `main.pdz`, so its compression
layout is different from the isolated score measurement.

Worker verification passed generator reproduction, the seven existing synth
host checks expanded to all fifteen music tracks, and production SDK compilation.
The existing loop-closure checks also retain their bound-rejection behavior.
The generated packet has **no unavailable map themes among the active 65 maps**.
This does not add encounter/victory cues, cries, flute or a full soundtrack.
All synth limitations and root-owned loading/listening acceptance remain open.
No Simulator, playback, device run, push, delegation or new contract occurred.

Root can reproduce the host checks and byte-size measurement without playback:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python tools/audio/scores.py --check
python -m unittest tools.audio.test_scores -v
python -m unittest tools.tests.test_audio_loop_closure -v
make compile
"$PLAYDATE_SDK_PATH/bin/pdc" -m Source/audio/scores.lua \
  "$POKEMON_ENV/evidence/audio65-score-data-UNIQUE.pdx"
```

The retained compile-only data measurement is
`~/Developer/Pokemon-PlayDate-env/evidence/audio65-score-data-20261028-01.pdx/`.
The earlier listening probe still exercises its original sequence; the seven
new themes need root listening in the active maps. This packet neither runs
nor accepts the independent milestone journeys.


## Original 151 cry data and API

`KantoAudio.playCry(species)` now accepts every current game species key, including
`nidoranF`, `nidoranM`, `mr` and `farfetchd`. It also accepts the source table's
`nidoran_f`, `nidoran_m` and `mr_mime` keys. An unknown species returns
`false, "unknown cry species"` without starting a sound. A valid request returns
`true`, replaces any earlier cry and plays asynchronously. The caller must keep
calling the existing audio update. This API does not implement the original
blocking `WaitForSoundToFinish`, hold a gameplay coroutine or write game state.

The new `tools/audio/cries.py` uses the unchanged checksum-verifying `Source`,
`Catalog` and `Trace`, pinned to pokered
`af519899719f0754965776faac0e836a3b906e6d`. It reads the existing cry table and
its internal-index/dex mapping, resolves every bank-qualified cry header, and
uses source pitch and length as unsigned bytes. Shared base programs come from
bounded, neutral-parameter Trace execution, including expansion of the one
finite cry loop. Unsupported commands or streams that do not end within the
unchanged default bound fail generation. No new bytecode interpreter or PCM
cry recording is shipped.

There are **151 species parameter rows, 38 base cries, 114 bank-qualified
headers and 38 shared programs containing 595 rows**. Each row keeps original
length units, envelope byte, unmodified period/noise byte and note-on duty.
Identical programs share storage across banks, while header identities remain
separate. `Source/audio/crydata.lua` is 23375 bytes; its isolated SDK-compiled
`main.pdz` is 10433 bytes. No new WAV or wave RAM assets are needed. Expanding
all species in one bank would duplicate 2368 note rows; instead, the runtime
builds only the requested transient score and releases it with the cry layer.
The generated manifest records original table parameters, program/header
mappings, every consumed source checksum, generator/parser hashes and the Lua
payload checksum. Existing music, SFX, map routes and wave assets are unchanged.

The adapter applies length using per-voice fractional accumulators, source
8/16-bit wrapping and the zero-counter 256-tick gate. Noise length is not scaled.
Pitch adds to the source register period, with 11-bit pulse or 8-bit noise
wrapping. Secondary notes that start after pulse 1 returns stop receiving cry
modifiers, exactly as in Trace. The existing source return holds are preserved:
pulse 2 and noise can wait for pulse 1, and voice 3 stays muted until the source
releases its dummy wave channel. All **453 species/bank combinations** match
Trace in every adapted note's onset, duration, Hz, gain, note-on duty and envelope,
score end tick and four voice-release ticks. These comparisons start from the
existing interpreter's engine-reset state; inherited fractions or phase from
an earlier source SFX are not modeled by the independent synth layers.

The runtime chooses the family of the current jingle or music: audio1 for most
maps, audio2 for battles and audio3 for the active Forest/cave themes. Without
music it explicitly defaults to audio1. During the cry, its source-owned voices
sit above the existing SFX/alarm/music layers, including silent owned intervals.
Other layers continue advancing and resume their current remaining notes after
release, with a new SDK attack. Existing SFX priorities are unchanged in the
absence of a cry. Incoming effects may be hidden by cry ownership; this is an
explicit foreground-layer adaptation, not the original numeric SFX arbiter.
Title/session stop clears cries along with all other audio. No observer hook or
automatic cry trigger was added to the game.

The installed SDK 3.1.2 documents `synth:playNote` pitch in Hz without a stated
frequency bound. Cry notes pass their computed Hz directly rather than using
the existing music/SFX 20..16000 clamp. In audio2, 28 pulse onsets and 146 noise
onsets across 52 species fall outside that old clamp. Pulse requests can reach
131072 Hz. The SDK's treatment of ultrasonic and very slow noise rates remains
unexecuted and unaccepted here; no aliasing or spectral equivalence is claimed.
An SDK note rejection still raises the existing explicit engine assertion,
rather than substituting a pitch. Root must check these cases before acceptance.

The synth model retains its audible limitations. Pulse duty is sampled at note
onset; the source's continuing duty-pattern rotation is not played. Noise uses
the generic SDK noise oscillator, not the GB 7/15-bit LFSR or its phase. Envelopes
use the existing approximate SDK ADSR. First-sample phase, DAC/filter behavior,
source arbitration and frame-accurate dispatch are not reproduced. Zero-volume
source rows remain timing/ownership intervals. Passing all 151 parameter rows
establishes availability in this adaptation, not faithful APU cries or native
listening acceptance. There are no unsupported parser commands in the consumed
cry programs; SDK runtime behavior remains root-owned verification.

`tools/audio/cry-hooks.patch` is a tiny **unapplied** patch for root's presentation
owner. It proposes cries at wild iris completion and sendout completion. It
passes `git apply --check` against this worker's current battle scene. It neither
edits that file nor covers Pokédex/party preview, faint cries, field events or
cry/message pacing. Root must reconcile it with their live presentation work;
rapid requests intentionally replace the earlier cry, so root must choose any
required waits. Apply no duplicate observer or battle-rule hook.

Worker validation passed the three cry host checks, all seven existing synth
checks, both generator reproduction checks, production SDK compilation and the
existing isolated synth-probe compilation. The host checks cover every current
game species key and all 453 source combinations, shared program storage,
voice-release ownership and source checksum reproduction. The original score
Lua/manifest and wave assets remain byte-identical. Compilation does not execute
the new Lua expansion, synth loading or Hz requests. No Simulator, playback,
recording, physical-device run, push, delegation or new Simulator contract ran.

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python tools/audio/cries.py --check
python tools/audio/scores.py --check
python -m unittest tools.audio.test_cries tools.audio.test_scores -v
make compile
git apply --check tools/audio/cry-hooks.patch
python tools/audio/synth_probe.py \
  --output "$POKEMON_ENV/evidence/kanto-cries-build-UNIQUE"
```

Compile-only evidence is
`~/Developer/Pokemon-PlayDate-env/evidence/kanto-cries-build-20261028-01/`.
The data-size measurement is
`~/Developer/Pokemon-PlayDate-env/evidence/cry-data-size-20261028-02.pdx/`.
The old probe sequence has no cry requests yet. Root can insert explicit
`KantoAudio.playCry` calls into its staged listening sequence, keeping that
change private, or integrate the reviewed hook patch into root's gameplay
checkout before ordinary listening. Suggested witnesses include Bulbasaur,
Pikachu and Jynx; `nidoranF`, `nidoranM` and `mr`; and ultrasonic-parameter cases
such as Ditto, Farfetch'd and Zapdos. Include music return, source wave muting,
alarm/SFX interaction, repeated requests, unknown species and title stop. These
are pending listening cases, not newly accepted tests or campaign journeys.
