# First native synth packet

Audio was explicitly unparked on 2026-10-28 for this packet. Branch
`t3/kanto-audio-synth` uses the existing tool-created worktree. Exact `3cc674d`
was merged first, then `ef9bff7`, without conflicts. The tracked game Source at
that merge equals `3cc674d`; parser/oracle/renderer code and historical evidence
are preserved. No shared gameplay file, art, session, codec or mechanics was
edited. `tools/audio/root-hooks.patch` is an **unapplied** integration patch for
root/B, against this merged Source. Do not mistake it for active game audio.

`Source/game/kantoAudio.lua` exposes dot-call functions:

```lua
KantoAudio.enterMap(zone) -- zone object or stable ID; repeated score stays running
KantoAudio.battleStart("wild") -- or "trainer"
KantoAudio.battleEnd()
KantoAudio.playSFX("menu") -- hit, faint, heal
KantoAudio.setLowHP(true) -- effective only inside battle; false stops immediately
KantoAudio.update() -- once per frame, including menus/dialogue
KantoAudio.stop() -- New Game/title/suspend boundary as root chooses
```

Map coverage is deliberately Pallet and its home interiors, plus imported
`pokered:ROUTE_1`. Unknown maps stop the music, rather than borrowing an unrelated
track. The root patch uses the Gen I <=20% low-HP threshold for the active battler
and guards against fainted Pokémon. It keeps the Gen V battle rules and original
151 untouched. Healing triggers when the real Center animation begins; it does
not change the healing transaction or wait for audio before committing it.
The generic menu patch covers `BattleMenu`; other menu widgets need root's own
calls. Root should also call `stop()` at Title/New Game and suspend if required.

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
dump or PCM is shipped. The approximately 100 KB Lua score contains Pallet,
Routes1, wild/trainer battle, Pokémon healed, Press AB, Damage and Faint Thud,
plus the direct source alarm. Each row holds onset, physical voice, gate length,
Hz, amplitude, duty and envelope byte. Source tick duration is exactly
70224/4194304 seconds; source delay arithmetic and fractional carry are reused.

`ScoreTrace` intentionally closes the **adapted musical score**, excluding
registers and continuous effect phase from its recurrence key. Persistent
vibrato/slide phase is not part of this instrument model. This is separate from
the unchanged full-register recurrence. The host test expands the short score
through the full register period for all four music tracks and compares every
adapted note row. The default 120000-tick rejection remains. Lavender/Dungeon1
are not selected and their long full vibrato periods remain documented and
bounded; no PCM seam or APU equivalence follows from these musical loops.

Four `playdate.sound.synth` sources share one private sound channel, with master
gain 0.22. Pulse voices map source duty to SDK square pulse width. Wave maps to
SDK triangle (source wave RAM timbre is not reproduced). Noise maps source noise
rate to SDK noise, with 20..16000 Hz clamp; GB LFSR width/phase is not reproduced.
Source pulse/noise envelopes become SDK ADSR; rising envelopes are an approximate
attack. Pitch slides land immediately at their source target, avoiding the
ultrasonic starting pitch of the heal harmony. Continuous vibrato, hardware
sweep, rotating duty effects between notes, stereo routing and exact APU length/
envelope quirks are omitted. This is an intentionally audible native adaptation.

The audio clock drives gate expiration; SDK `playNote` gets the remaining finite
length and `noteOff` explicitly releases replaced/expired notes. There is no
frame-count drift accumulator. Dispatch happens at the calling frame rate:
30 FPS can coalesce/skip one-tick ornament notes (notably Press AB). There is no
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
faint25s, alarm27..30s, trainer32s, field41s, heal43s, Pallet48s, stop54s.
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

Root can record actual Simulator output through an **existing output-loopback
input**. The following lists inputs; use the loopback input's actual index,
not a microphone, for a direct output recording. No driver installation or audio
routing changes are part of this packet. Without loopback, an external recorder
or explicitly labeled speaker/mic listening capture remains possible.

```sh
ffmpeg -hide_banner -f avfoundation -list_devices true -i ""
# In a separate terminal, replace INDEX with the verified loopback audio index:
ffmpeg -hide_banner -f avfoundation -i ":INDEX" -t 65 \
  -ac 2 -ar 44100 -c:a pcm_s16le "$POKEMON_ENV/evidence/kanto-synth-listen-UNIQUE.wav"
# Start the root-only job above while recording, then inspect/listen to the WAV.
ffprobe -v error -show_streams "$POKEMON_ENV/evidence/kanto-synth-listen-UNIQUE.wav"
```

Installed SDK 3.1.2 `Inside Playdate.html` was read for synth `playNote` (Hz,
finite seconds, one pending note), `noteOff`, `stop`, `setADSR`, square parameter 1,
`channel.new/addSource/setVolume` and `sound.getCurrentTime`. The compile manifest
pins the local SDK documentation and compiler hashes. SDK compile logs and source
inventories live outside git under environment evidence.

## Verification and outstanding acceptance

- Three synth host checks: musical loop expansion, finite gates/source pitch,
  and source alarm transition ticks; passed.
- Existing 51 parser/oracle/renderer/long-closure checks passed, zero skips,
  with pinned RGBDS 1.0.4 on PATH. The intentional missing-tools negative test
  prints its expected qualification failure. Production audio tools unchanged.
- Native import bundle compiled with the actual SDK 3.1.2, compile only.
  Evidence: `~/Developer/Pokemon-PlayDate-env/evidence/kanto-synth-compile-20261028-03/`.
- Hook patch passes `git apply --check`; shared gameplay hooks remain unapplied.

No Simulator, playback, recording or physical device was run by this worker.
Root must listen for recognizable melody/tempo, mix level, wave/noise character,
menu audibility, audible transitions and resumed voices, alarm cancellation,
healing return, and any 30 FPS jitter before accepting. Main-game lifecycle and
runtime allocation/performance remain root integration checks. Full soundtrack,
cries, flute, victory tracks and remaining maps are later work.
