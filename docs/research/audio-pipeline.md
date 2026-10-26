# Red/Blue audio pipeline research

Research date: 2026-10-26. Base checkout: `dcc991f`. This prepares [goal §5.7 during §5.3](../plans/full-game-goal.md); it is **not implemented or accepted audio**. No Simulator, playback, ROM build, production edits, or device measurements were performed. Local primary sources and the installed SDK were sufficient; no web research was needed.

## Recommendation and feasibility

Use **deterministically generated samples**, rendered offline from the pinned sound-command streams, with SDK sample playback for short cues and streamed music. Keep a lossless register/event intermediate representation (IR) so a native synth backend remains possible. Do not export MIDI and assume it preserves the original sound: the source depends on pulse duty rotation, discrete register vibrato, hardware envelopes/sweep, wave RAM, noise-polynomial settings, and species-specific cry modifiers. The SDK documents square pulse width and wavetables, but does not document a Game Boy noise-polynomial mode, hardware envelope/sweep equivalence, or an arbitrary sample-time Lua register callback. [Commands][macros], [engine][engine2], [SDK synth][sdk-synth].

This recommendation concerns timbre and timing preservation, not an emulator: conversion interprets the audio DSL on the host; the native Lua game loads generated assets and routing metadata, never a ROM. Start with a mixed music reference render and isolated cues. For release playback, preserve channel ownership with four generated music stems, gated against corresponding SFX voices. **Multi-stream synchronization and source-style channel release are feasibility gates, not established SDK guarantees.** The documented Lua fileplayer has no `playAt`; independently starting four streams cannot be called sample-synchronous. Prove alignment and loop behavior before adopting that playback arrangement. A single mixed stream plus arbitrary additive SFX cannot reproduce source channel stealing; treat that as a reference/debug backend, not final fidelity acceptance. [SDK fileplayer][sdk-file], [source channel arbitration][engine2].

Static stems also cannot reproduce every phase/envelope interaction caused by suppressed music register writes while an SFX is active. Gate metadata can preserve voice occupancy and score position, but it is not a proof of bit-exact hardware reconstruction. Accept samples for source identity only after listening and runtime qualification; if exact dynamic hardware output becomes a requirement, this architecture needs a register-driven audio backend.

A useful alternative if four streamed stems prove unreliable is four resident PCM sample synths with sustain regions and a shared SDK sequence, plus pre-rendered SFX. The SDK documents PCM sample synths, sample-frame sustain regions, sequenced instruments and control signals; it does not guarantee identical sustain-region boundary phase or voice-steal behavior. This alternative trades several megabytes of RAM per minute for scheduling on one sequence clock. Test it on a short representative loop before choosing it over streams. Adding native C audio rendering would be a separate architectural decision; it is unnecessary for the first converter packet. [SDK synth][sdk-synth], [SDK sequence][sdk-seq].

## Exact inputs and evidence

Source environment:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
git -C "$POKERED_REFERENCE_DIR" rev-parse HEAD
cat "$PLAYDATE_SDK_PATH/VERSION.txt"
python tools/audio_research/probe.py --source "$POKERED_REFERENCE_DIR"
```

Observed values: pokered **`af519899719f0754965776faac0e836a3b906e6d`**, clean source checkout at `~/Developer/Pokemon-PlayDate-env/pokered`; Playdate SDK **3.1.2** at `~/Developer/PlaydateSDK`. The project remains English Blue world/audio identity with Gen V battle mechanics. Existing [Kanto inventory](kanto-content-inventory.md) and `tools/references/kanto-{source,inventory}.json` identify the same source, 46 music files and 323 bank-specific SFX files. These are file counts, not unique audible assets: fanfares occur in SFX files, banks repeat material, headers expose multiple entry points, and unused content is present.

| Primary input | Exact local path relative to its root | Purpose |
|---|---|---|
| pokered | `audio.asm`, `layout.link` | Include order, engine families and ROM banks: Audio1 `$02`, Audio2 `$08`, Audio3 `$1f` |
| pokered | `macros/scripts/audio.asm`, `constants/{audio,music}_constants.asm` | Actual command bytes, argument encoding, channel IDs, sound-ID expressions |
| pokered | `audio/headers/{musicheaders,sfxheaders}{1,2,3}.asm` | Channel lists and entry pointers; headers are variable channel counts, with three bytes per channel entry |
| pokered | `audio/engine_{1,2,3}.asm`, `ram/wram.asm` | Execution, initialization, fractional delay, priority, effect state; do not assume the three copies are identical |
| pokered | `audio/{notes,wave_samples}.asm`, `constants/hardware.inc` | Period table, actual wave data, register bit fields and envelope/sweep units |
| pokered | `audio/music/*.asm`, `audio/sfx/*.asm` | Tracks, one-shots, fanfares, percussion and base cries |
| pokered | `data/pokemon/cries.asm`, `constants/pokemon_constants.asm` | Internal species index → base cry/pitch/length; not Pokédex order |
| pokered | `data/moves/sfx.asm` | Gen I move cue ID + frequency/tempo modifiers |
| pokered | `data/maps/songs.asm`, `home/{audio,overworld,vblank,pokemon}.asm` | Map pair lookup, bank changes, default music, source tick, cry lookup |
| pokered | `audio/{play_battle_music,alternate_tempo,low_health_alarm,poke_flute}.asm` | Battle selection, entry variants, alarm and flute exceptions |
| pokered | `engine/{battle/core,battle/end_of_battle,items/item_effects}.asm`, `home/palettes.asm` | Alarm lifecycle/threshold, flute game behavior, battle return |
| SDK | `Inside Playdate.html`, Sound §7.28 | Installed Lua API contract, including synth, sample/fileplayer, sequence, track, signals and audio clock |
| SDK | `C_API/pd_api/pd_api_sound.h` | Distinguishes C-only callbacks from available Lua capabilities; not permission to introduce C |

Installed-document SHA-256 values:

- `Inside Playdate.html`: `68f0243517f9ee3f9a46a2b212e0329c3f08288aeed8a70cbbdb9ba44291d484`.
- `C_API/pd_api/pd_api_sound.h`: `7946ea4d6079d85920a228d07f34c5e4c3ab7bc3b1727373cf5808c95c424cf7`.
- Source `macros/scripts/audio.asm`: `97ad54fdcda5fc9390ee94a524e7f4824b3d74d6e69818be1e9f3581195a919b`.

The SDK links below are locators for API names; **the installed, hashed 3.1.2 document was read**, not a potentially newer online edition. Source links all pin the exact git revision. The probe result includes hashes for the files it actually reads, not a complete conversion provenance manifest.

## Commands and timing that must survive conversion

There are eight software channels, not eight oscillators. Music channels 1–4 and SFX channels 5–8 share four hardware voices: pulse 1, pulse 2, wave, noise. A music channel continues advancing note counters when its corresponding SFX channel owns the hardware, suppressing writes; it does not simply pause its score. Effects can also be suppressed while stolen. `wMuteAudioAndPauseMusic` is a separate explicit pause/mute path. Source update order is significant: channel 1 through 8, with the alarm called before Audio2 updates in VBlank. [Engine update][engine2], [channel constants][aconst], [VBlank][vblank].

| Command | Source semantics and required mapping |
|---|---|
| `channel_count`, `channel` | Count minus one is encoded in the first header byte, combined with channel minus one; each entry has a little-endian pointer. Resolve the whole channel list before decoding data. |
| `note pitch,length`; `rest length` | Length encodes `length-1` in the low nibble; pitch occupies the high nibble. A rest has opcode `$c0`. Music pitch uses `audio/notes.asm` and the engine's signed shifts/octave calculation, not equal-tempered MIDI rounding. |
| `note_type speed,volume,fade`; `drum_speed speed` | Speed controls delay scaling. Pulse volume/fade becomes the envelope register. On wave channels, the second byte instead selects discrete output level from bits 4–5 and wave instrument from its low nibble. Music noise uses speed with no following envelope argument. |
| `tempo value` | Big-endian 16-bit parameter; **smaller is faster**, not BPM. Music and SFX have separate shared tempo words. Changing tempo clears fractional delay state for all four channels in that group. |
| `octave n`; `toggle_perfect_pitch` | Octave is stored as `8-n`. Perfect pitch increments the period register, not a semitone; preserve the source's noted carry behavior rather than silently fixing it. |
| `square_note length,volume,fade,frequency` | `$20|length`, envelope byte, little-endian period word. The raw length argument is incremented by the common delay decoder; zero is one unit, not zero duration. Preserve register writes/trigger/length bits separately from software delay. |
| `noise_note length,volume,fade,polynomial` | Same command family, but only one frequency byte on noise. Its width/divisor/shift controls the hardware LFSR; it is not a MIDI pitch. |
| `drum_note instrument,length` | Music noise dispatches a bank-local SFX noise-instrument stream on channel 8. Do not flatten it as an independent extra noise voice. |
| `duty_cycle 0..3`; `duty_cycle_pattern a,b,c,d` | 12.5%, 25%, 50%, 75%. Pattern is packed into one byte; engine rotates it by two bits during effect updates and writes the top pair. Initial pattern application and note-boundary behavior come from the engine, not a free-running SDK LFO. |
| `pitch_sweep length,change` | Raw pulse hardware sweep register. Sign-magnitude direction and pace in 128 Hz hardware units; not linear Hz interpolation. |
| `vibrato delay,depth,rate` | Initial delay reloads at note onset. Engine splits extent above/below, alternates direction, changes the low frequency byte with saturation, and counts source ticks. A generic sinusoidal LFO changes its identity. |
| `pitch_slide length,octave,pitch` | Engine computes fixed-point register deltas and target termination. It also has a documented borrow bug; transcribe arithmetic and qualify fixtures before proposing any correction. |
| `volume left,right`; `stereo_panning leftMask,rightMask` | Global hardware master level and four-bit output-enable masks. These are distinct from an individual voice's envelope and from SDK channel volume. Preserve stereo before any speaker downmix; reserve mixer headroom. |
| `execute_music` | Switches an SFX channel to music command interpretation, including note/tempo semantics. Used by fanfares and flute. Never decode `$2x` without channel/mode context. |
| `sound_call`, `sound_ret` | One saved return address/flag per channel, not a general recursive stack. A top-level return ends that channel; cry return behavior additionally holds other channels while channel 5 remains active. |
| `sound_loop count,target` | Counter starts at 1; a nonzero count is the total source repetition count. Zero jumps forever. Preserve the one channel-local loop counter and resolve local labels against their enclosing global scope. |
| `unknownmusic0xef` | Present in macros/engine, marked apparently unused. Fail if encountered by the initial converter until semantics are explicitly implemented; never skip unknown bytes. |

These are source-derived requirements, not a claim that a renderer exists. [Macro encoding][macros], [Audio2 engine][engine2], [Audio1 engine][engine1], [hardware bit fields][hardware].

For ordinary representable values, the note-delay calculation is:

```text
units = ((encodedLength + 1) * speed) & 255
accumulator = (previousFraction + units * tempoQ8) & 65535
fraction = accumulator & 255
delayCounter = accumulator >> 8
```

Implement the actual 8/16-bit arithmetic, including overflow, rather than only this normal-case summary. A zero counter is not an immediate event: subsequent decrement wraps to 255. `tempo` resets fractions; loop jumps do not. At each source update a counter of 1 decodes the next timed command; otherwise it decrements and applies effects. Pallet's opening channel-1 note at tempo 160, speed 12, length 4 gives 30 source ticks; its next length-2 note gives 15. Other combinations retain fractional carry. [Audio2 `note_length`, `MultiplyAdd`, `ApplyMusicAffects`][engine2].

The original engine is driven from VBlank. Proposed renderer clock: rational DMG frame cadence `4,194,304 / 70,224 ≈ 59.72750057 Hz`, independent of the game's 30 FPS. Keep source tick and output-sample indices as integers, using rational remainder accumulation; do not round every tick to an integer sample count. At 44,100 Hz, sample time for tick `t` is derived from `t * 70,224 * 44,100 / 4,194,304`, with a documented rounding rule. Envelope/sweep/noise oscillator timing needs a finer hardware clock than the score tick. **The pinned source proves VBlank dispatch and register units, not a complete hardware APU timing specification.** Pin a primary hardware timing specification and qualify the proposed clock/formulas before accepting a waveform renderer. This research did not measure timing against hardware. [VBlank dispatch][vblank], [hardware envelope/sweep fields][hardware].

For the renderer design, pulse period values would map to `131072/(2048-period)` Hz and wave period values to `65536/(2048-period)` Hz; use the engine-calculated 11-bit value, not a MIDI tuning table. Noise needs the NR43 shift/divisor and 7/15-bit width, a deterministic LFSR seed/trigger rule, and hardware envelope pacing, not SDK white noise. The pinned register definitions identify the fields and 64 Hz envelope/128 Hz sweep units, but do not fully specify the oscillator/LFSR algorithm, zero-pace quirks, length-counter phase or analog filtering. Treat these formulas and renderer details as a proposed hardware model to qualify against the primary timing reference in packet 2. The sample output should retain raw register-derived amplitude steps; an SDK synth approximation would use square parameter values `0.125, 0.25, 0.5, 0.75`, explicit 32-point PCM wavetables for waves 0–5, control signals for discrete envelope/vibrato changes, and rendered noise variants. Wave output levels are mute, full, half and quarter from NR32; the music channel’s `note_type` low nibble chooses the wave rather than an envelope fade. [Hardware fields][hardware], [wave definitions][waves], [SDK synth][sdk-synth].

A loop label alone is insufficient for a seamless sample. Find repeat state including PC/return slot, loop counter, tempo/fractions, active note/effects, shared state, oscillator/LFSR phase, and rendering filter state. All tracks must close together; intros may lead into loops of different lengths. A bounded search should report a nonclosing state instead of truncating to an arbitrary bar. Decide a deterministic audio seam policy if exact oscillator recurrence is impractically long, record it in generated metadata, and audition it later. Do not promise every song has a small exact PCM period.

## Bank and reference resolution: one proven hazard

Use stable `(engineFamily, globalLabel, localLabel, entryVariant)` references in IR. Music numeric IDs are address-derived expressions: `music_const` uses `(label - SFX_Headers_1)/3`, while runtime dispatch also depends on the audio bank. A number alone is not a global asset ID. Preserve raw expression, resolved entry and family. Repeated SFX files should be deduplicated only after comparing decoded semantics, wave inputs and engine behavior. `layout.link` groups audio into banks `$02`, `$08`, `$1f`; `audio.asm` establishes exact local include order. [Constants][mconst], [layout][layout], [assembly][assembly].

`wave_samples.asm` defines waves 0–4 explicitly, but `.wave5` emits **no bytes**: it reads the following sound-effect data. References 5–8 alias that label. Therefore the waveform differs by engine family. A converter that copies only the five declared nibble rows, uses a triangle for channel 3, or invents a universal sixth wave will change Lavender/Pokémon Tower. [Wave source][waves], [assembly include order][assembly].

The silent [probe](../../tools/audio_research/probe.py) encodes only the prefix macros needed to collect the next 16 bytes after `.wave5`. It uses the real include order, little-endian `dw`, and command encoding. [Recorded result](../../tools/audio_research/probe-result.json):

| Engine / ROM bank | Emitted 16-byte prefix | Equals explanatory nibble comment? |
|---|---|---|
| Audio1 / `$02` | `21e23328e122ffea1014dc10e3415173` | Yes |
| Audio2 / `$08` | `ec022091c0072081d0072091c0072ca1` | **No** |
| Audio3 / `$1f` | `21e23328e122ff22f72422f73424f744` | Yes |

The Audio2 comment gives period-word bytes in the opposite order from the macro's `dw` encoding; **executable data wins over the comment**. The result is a host macro-translation proof, not an assembled RGBDS comparison (`rgbasm` was not installed on PATH), not an APU render, and not listening acceptance. Audio2 wave5 is described as unused; retain its correct resolution anyway. The future converter must either assemble an isolated audio object with a pinned RGBDS toolchain as an independent byte oracle, or equivalently qualify its complete macro encoder against such an oracle. No full game ROM is necessary.

The probe also reports five cry parameter examples. It intentionally is not a general parser: unsupported prefix macros fail. It does not flatten loops, create PCM, or modify production data.

## Cries, alarm and flute

**Cries.** Import `CryData` through internal Pokémon constants, then bind the original 151 stable species IDs. Entries contain base cry index, unsigned pitch byte and unsigned length byte. There are 38 named bases (`00`–`25`) plus an unused cry; 151 species are not 151 unrelated recordings. `GetCryData` converts the base index back to a header offset `CRY_SFX_START + 3*base`, and cry headers select software channels 5, 6 and 8. [Cry table][cries], [lookup][pokemon], [headers][sfx2].

For cries, pulse/SFX tempo is **`lengthByte + 0x80` as a 9-bit value**, not `lengthByte/128` and not a global playback-rate multiplier. Channel 8 noise delay instead uses `$0100`. Pitch adds the unsigned modifier to the low frequency byte, carrying into the high byte; on noise this touches the polynomial/control bytes, not a musical interval. Do not interpret `$ff` as minus one. In Audio2 the same modifiers also apply to the classified battle-SFX range. Example: Clefairy uses base `$19`, pitch `$cc`, pulse tempo 129, noise tempo 256; Onix uses base `$17`, pitch `$ff`, pulse tempo 320, noise tempo 256. Render each `(family,base,pitch,length)` variant from commands; SDK `setRate` changes pitch and length together and cannot substitute. Cry return logic can keep secondary channels alive until channel 5 finishes and restores saved master volume; use the full engine trace to determine cue completion. [Engine modifiers and cry return][engine2], [probe results](../../tools/audio_research/probe-result.json).

**Low HP.** The source enables the alarm for a live player's red HP bar unless victory has disabled it; fainting/recovery and battle exit clear it. The source threshold is red **rendered bar length below 10 pixels**, through `GetHealthBarColor`, rather than an assumed universal percentage. Define the Playdate logical threshold from the source HP-bar rounding, independently of this game's drawn bar size. `Music_DoLowHealthAlarm` uses pulse 1, overwrites other sounds, starts a high tone at timer 0, sets timer 30, changes to low at timer 20, then counts to the next cycle; reproduce branch ordering/off-by-one from a trace instead of converting the comment to a guessed millisecond cadence. Tone data: high `$a0,$e2,$8750`, low `$b0,$e2,$86ee`; sweep is zeroed. It also reserves channel 5 using `CRY_SFX_END`, with `$ff` a distinct disable instruction. Render the repeating alarm on the independent clock; stop/release ownership explicitly on switch, heal, faint, victory and exit. [Alarm][alarm], [battle lifecycle][battle], [HP color][palettes], [battle end][battleend].

**Flute.** Keep three paths separate: the field `SFX_Pokeflute` uses channel 3 in family 1; the in-battle helper begins `SFX_CAUGHT_MON` and overwrites channel 5/6/7 pointers with flute channels (including `pokeflute_ch7.asm`); the item/script logic decides sleep recovery and Snorlax encounters. In battle the source skips the flute music if nobody was asleep or the low-HP alarm is active. Out of battle, item use tests Route 12/16 position/event flags and sets the Snorlax fight event; sound completion must not itself award those flags. Import these audio paths without changing the project's Gen V rules or item transactions. [Flute helper][flute], [field flute score][flutescore], [item behavior][items].

## SDK 3.1.2 backend choices

| Backend | Supported API evidence | Consequence |
|---|---|---|
| Native synth | `synth.new(kWaveSquare)`, `setParameter(1,pulseWidth)`, `setADSR`, frequency/amplitude modulation, `setWavetable` | Small assets; pulse widths and explicit 32-point waveforms are feasible. SDK ADSR is continuous and generic noise has no documented LFSR width/divisor identity. Hardware sweep/envelope and register vibrato need additional event/control synthesis. No exact mapping is established. |
| Sample synth + sequence | `synth.new(sample,sustainStart,sustainEnd)` requires PCM; sustain points are sample frames. `sequence:setTempo` means **steps per second**; `track:addNote` lengths are steps; `setLoops` loops endlessly for count 0 | Can put converted timelines on one native audio scheduler rather than Lua frame timers. Full-song PCM stems cost RAM. A four-track loop must be generated on one shared time grid and have a qualified seam. |
| Short sample cues | `sampleplayer.new`, `playAt(absoluteDeviceSeconds,...)`, `setPlayRange(start,end)` | Low playback overhead, resident data. Only **one queued event per player**; a later `playAt` overwrites it. Use a bounded voice pool; never enqueue an entire song on one player. Lua sample play-range units are sample frames, unlike fileplayer loop seconds. |
| Streamed music | `fileplayer.new(path,bufferSeconds)`, `setLoopRange(startSeconds,endSeconds)`, `play(0)`, `setOffset`, `setVolume(...,fadeSeconds)` | Handles intro + native loop without Lua callback restarts. Buffer size trades RAM for underrun resistance/seek latency. Check `didUnderrun`, `setStopOnUnderrun`, load/play errors. No documented scheduled start or atomic multi-file start. |

Sources: [sampleplayer][sdk-sample], [fileplayer][sdk-file], [synth][sdk-synth], [sequence][sdk-seq], [track][sdk-track]. The SDK's sound sample rate is fixed at **44,100 Hz**. `playdate.sound.getCurrentTime()` measures the audio device's own clock. Sequences and players progress independently of the 30 FPS render loop. A game update may submit routing changes or inspect status; it must not tick notes, envelopes or alarm rhythm. [Sound/clock][sdk-sound].

Use 44,100 Hz signed 16-bit PCM as canonical converter output, with fixed gain/filter/resampler settings and WAV metadata. Production IMA ADPCM is a later derived artifact with a pinned encoder version/settings and decoded comparison; the SDK recommends it over MP3 for decode cost/size. `pdc` can compile supported audio inputs; verify output loop points after compilation, including ADPCM block rounding. A sample used in a synth must be PCM, so do not decompress every music sample at startup: SDK documentation says ADPCM decompression expands memory by 4× without improving fidelity. [Preparing files and sample memory][sdk-sound].

## Deterministic conversion contract

Proposed future CLI (not implemented by the probe):

```sh
python tools/audio/convert.py inspect --source "$POKERED_REFERENCE_DIR" --revision af519899719f0754965776faac0e836a3b906e6d --output <dir>
python tools/audio/convert.py trace --source "$POKERED_REFERENCE_DIR" --asset audio1:Music_PalletTown --max-ticks 120000 --output <dir>
python tools/audio/convert.py render --ir <dir>/audio-ir.json --sample-rate 44100 --format pcm16 --output <new-dir>
python tools/audio/convert.py check --source "$POKERED_REFERENCE_DIR" --against <generated-dir>
```

`inspect` validates revision plus per-input SHA-256 (HEAD alone does not exclude local edits), resolves Blue conditionals/includes/constants, and emits complete headers, bank-qualified references, map routes, 151 cries, move cues and variant entry points. `trace` executes source semantics with bounded steps/calls/loop search, emitting timestamped register writes and ownership changes. `render` is a pure IR-to-WAV transformation with no network, current time, gameplay RNG or nondeterministic dither. `check` regenerates in a fresh directory, compares canonical hashes, checks reference closure, duration/seam bounds, and reports unsupported constructs with file/line. Fail closed on an unresolved label, command, bank or nonclosing search; never replace it with silence.

Versioned IR records must contain:

- Source revision, all consumed file hashes, tool/schema versions, Blue build defines, macro-encoding and engine-family versions; later SDK/compiler/encoder pins in the pack output.
- Stable asset and variant IDs, raw header ID expression/bank/channel declarations, source file/line ranges, entry PC and resolved local/global references.
- Rational source tick time, sample indices, raw tempo/speed/fraction/period/envelope/duty/noise/panning writes, trigger bits, voice owners and terminal state. Keep stateful commands, not just final MIDI pitches.
- Intro boundaries, candidate loop boundaries and repeat-state fingerprints, exact sample counts, render policy and seam diagnostics; one shared transport for stems.
- Cry species → base/pitch/length mapping; Gen I move tuple; map ID → symbolic track/family; semantic cue aliases and explicit routing exceptions.

Do not auto-map later-generation moves to arbitrary Gen I effects. Preserve source tuples for shared moves; a separate reviewed alias table may reuse a suitable source cue for Gen V-only moves available to the 151. Conversion must enumerate unmapped moves for the implementation owner, not manufacture a successful no-op. Asset manifests generated by this future tool are separate from the campaign manifest/coverage/ledger; none are changed by this research.

## Map, battle and runtime ownership interface

Import music into the single source-map metadata pipeline during §5.3 now, rather than attach hand-written per-zone `if` blocks later. Use `data/maps/songs.asm` indexed by **source map ID**, with bank-qualified symbolic resolution. Authored Pallet needs a narrow source-map adapter for Pallet, both Red floors, Blue's house and Oak's lab. Do not guess music by tileset: Viridian Mart explicitly uses Pokécenter music, and the Forest uses Dungeon2. Route 3/4 use Routes3; Route 24/25 use Routes2. [Map assignments][songs].

Proposed deep module `AudioDirector` owned by `GameContext`, injected with catalog/backend/clock. It owns all players, routing, priorities, cancellation tokens and transient transport; `GameSession` does not persist player objects or sound phase. New isolated contexts get a silent/injected backend and cannot seize the live mixer. Suggested public interface:

```lua
AudioDirector.new({ catalog = catalog, backend = backend, clock = audioClock })
audio:enterMap(sourceMapID, traversalMode) -- same resolved music key continues
audio:beginBattle({ kind = kind, opponent = sourceTrainerID, gymLeader = flag })
audio:finishBattle(outcome)              -- victory cue or restoration policy
audio:playCue(stableCueID, options)      -- returns cancellable completion token
audio:playCry(speciesID, options)
audio:setLowHealth({ alive = alive, red = red, enabled = enabled })
audio:pushMusicOverride(owner, trackKey, variant)
audio:popMusicOverride(owner)
audio:suspend(reason)
audio:resume(reason)
audio:dispose()
audio:snapshot()                        -- semantic/debug state, no save payload
```

The backend owns audio-clock scheduling; the director owns intent. Ordinary dialog/menu overlays leave music playing. Context/session replacement, title/new game, quit/sleep, battle cancellation and Continue invalidate old completion tokens. Callbacks enqueue completion for the current owner; stale callbacks cannot restore a prior map or advance a new battle. SFX completion is a presentation wait with bounded timeout/error handling, never an authority for inventory, damage or quest flags. Muted audio (`getSystemVolume()==0`) must not trap an unfinishable wait; logical cue duration can still determine normal presentation pacing. [SDK volume guidance][sdk-sound], [existing context ownership](../../Source/game/context.lua).

Reproduce source default-music policy: walking uses map pair, bike/surf override it; avoid restarting if the resolved music identity already matches. Bank changes participate in that comparison. Script overrides need explicit priority/lifetime and alternate entry keys for rival starts/tempos and Cities1 Hall-of-Fame tempo. `UpdateMusic6Times` is a source map-transition quirk: represent or deliberately qualify it, never blindly run six extra audio ticks per 30 FPS game frame. [Default music][homeaudio], [alternate entries][alternate].

Battle selection comes from `PlayBattleMusic`: gym leader flag first, ordinary trainer, Champion (`RIVAL3`) final battle, Lance gym-leader theme, otherwise wild. Victory themes, encounter themes, evolution, heal fanfare, capture/level-up, title and credits are distinct routes; model them explicitly before wiring events. Gen V battle mechanics do not change those R/B identities. Restore the **current** default traversal/map after a battle, not an obsolete captured string. [Battle selection][battlemusic], [headers][music2], [battle end][battleend].

Arbitration must implement bank-local numeric SFX priority and noise-instrument exceptions from `PlaySound`, not a generic “newest sound wins” rule. Four hardware voice leases pair music and SFX. On release, source music resumes its continuing score on the next appropriate note/effect write, not at the start of its track. The low-HP alarm has its own direct pulse-1 override. Pre-rendered stems need event metadata to reproduce these gate intervals. Frame-level ducking alone can be off by up to one game frame; sample-time gates require a qualified sequence/control-signal backend or a documented acceptance decision. This is the key runtime risk remaining after offline rendering. [Priority and restoration][engine2].

## Resource envelope and bounded next packets

These are arithmetic budgets and proposed targets, **not measured device results**:

- Mono PCM16 at 44.1 kHz: 88,200 bytes/second; stereo doubles it. Four one-minute mono stems require **21,168,000 bytes (~20.2 MiB)** before Lua/native allocations. Do not preload the soundtrack. One two-second mono cue is 176,400 bytes.
- IMA ADPCM is approximately 4 bits/sample plus block overhead: one mono minute ~1.32 MB; four ~5.29 MB on disk. Decoded buffers/allocator overhead are separate from compressed file size. Two stereo stem containers contain the same number of samples but cannot independently gate their two component voices through ordinary left/right volume if stereo panning must remain fully general.
- Begin streaming experiments at 0.5 seconds per mono stem (~176,400 bytes total decoded PCM equivalent for four), then measure actual native allocation and underruns. This is a starting point, not the SDK default or an assurance of buffer layout.
- Bound loaded cues with a byte-counted cache and bounded voice pool; retain UI cues and current cry, evict inactive assets on route/battle changes. Use reusable sample allocations if measurements show fragmentation. No per-frame sample creation, large IR decoding, waveform generation or audio-domain use of RulesRNG/world RNG. [SDK memory and buffers][sdk-file], [sample allocation][sdk-sound].
- Audio must leave the game within its 33.33 ms render budget, with zero sustained underruns under worst-case battles/transitions/GC. Set an initial measured audio-work target below 10% of device CPU and an incremental resident-audio budget below 2 MiB for the streaming design; revise from actual profiling. Neither target is a discovered hardware limit. Longest-loop disk size, startup cost, cue cache, native player memory and battery cost remain unmeasured.

Implementation packets, in order:

1. **Next packet: host parser and trace, no runtime hooks.** Own only new `tools/audio/*`, focused host tests and a small research fixture directory. Start from this research commit, pin the source revision/hashes, implement all actually encountered macro forms/header references, and import map/cry/move tables. First fixtures: Pallet, Routes3, Cities1 (drums), Lavender/Tower wave5, wild/trainer/gym/final music, rival alternate entries, `cry00` with multiple modifiers, low-HP trace, both flute paths. Acceptance: all references resolve; exact opcode coverage report; fractional delay/tempo-reset/finite-loop/call-return traces; 151 species mapped without Pokédex-index confusion; independent isolated RGBDS byte comparison including bank-relative wave5. No PCM claims yet. A clean failure on unsupported semantics is acceptable in a staged first commit, but it must list remaining constructs before renderer work.
2. **Offline renderer.** Pin primary APU timing reference and implement four voice generators plus envelope/sweep/noise/register timing. Produce PCM mixes and stems, loop/state reports and source hashes. Compare independently computed short waveform/register fixtures; quantify source tick/sample drift and loop seam discontinuity. Render representative short cues without installing them in Source. Do not declare fidelity based on hashes alone: root must later listen to these against a source-backed reference.
3. **Backend feasibility spike owned by root.** A minimal isolated SDK test app, not campaign wiring: compare four file streams against one sequence driving four sample synths. Check simultaneous onset, at least 100 loops, 30 FPS and stalled-frame behavior, per-voice steal/release, seek/loop rounding, gain/panning, all errors and underruns. Measure physical device CPU and memory. Choose the playback backend from results; this research does not authorize launching a second Simulator owner.
4. **Runtime director and §5.3 metadata seam.** Add the map music key through the common map importer/adapter, then director/backend injection and exact lifecycle cancellation. Initial real path: Red's bedroom → Pallet → Route1 → Center → battle → return; confirm same-track transitions continue, battle identities, cry variant, overlay behavior and disposal. Keep root-owned `main.lua`/shared files out of a worker's edits unless explicitly assigned.
5. **Campaign cues and release acceptance.** Complete source event routing, shared/new move aliases, flute and low HP, then full music inventory, streaming/cache bounds, repeated transitions and long-session/device profiling. Root performs listening, speaker/headphone comparisons and natural gameplay acceptance. Record intentional deviations only when agreed during implementation; do not preemptively mark source fidelity or §5.7 complete.

No baseline, coverage, ledger, campaign manifest or production `Source/` file is changed by this packet. The only experiment is the silent prefix/cry-parameter probe, whose checked-in result is reproducible and explicitly limited.

[macros]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/macros/scripts/audio.asm
[engine1]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/audio/engine_1.asm
[engine2]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/audio/engine_2.asm
[aconst]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/constants/audio_constants.asm
[mconst]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/constants/music_constants.asm
[hardware]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/constants/hardware.inc
[vblank]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/home/vblank.asm
[assembly]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/audio.asm
[layout]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/layout.link
[waves]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/audio/wave_samples.asm
[cries]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/pokemon/cries.asm
[pokemon]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/home/pokemon.asm
[sfx2]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/audio/headers/sfxheaders2.asm
[alarm]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/audio/low_health_alarm.asm
[battle]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/engine/battle/core.asm
[palettes]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/home/palettes.asm
[battleend]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/engine/battle/end_of_battle.asm
[flute]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/audio/poke_flute.asm
[flutescore]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/audio/sfx/pokeflute.asm
[items]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/engine/items/item_effects.asm
[songs]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/maps/songs.asm
[homeaudio]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/home/audio.asm
[alternate]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/audio/alternate_tempo.asm
[battlemusic]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/audio/play_battle_music.asm
[music2]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/audio/headers/musicheaders2.asm
[sdk-sound]: https://sdk.play.date/inside-playdate/#M-sound
[sdk-synth]: https://sdk.play.date/inside-playdate/#C-sound.synth
[sdk-file]: https://sdk.play.date/inside-playdate/#C-sound.fileplayer
[sdk-sample]: https://sdk.play.date/inside-playdate/#C-sound.sampleplayer
[sdk-seq]: https://sdk.play.date/inside-playdate/#C-sound.sequence
[sdk-track]: https://sdk.play.date/inside-playdate/#C-sound.track
