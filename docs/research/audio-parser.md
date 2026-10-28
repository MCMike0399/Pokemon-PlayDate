# Host audio parser and register trace

Prepared on `wip/audio-parser`, after merging exact research commit
`9a1cf8751470dd6c57c9ca118d53b96368ebe5d0` onto base `dcc991f`.
This is host preparation, not audio acceptance. No Source edits, Simulator,
playback, game ROM build, package installation or push occurred.

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python tools/audio/convert.py inspect --output "$POKEMON_ENV/evidence/audio-inspect"
python tools/audio/convert.py check --against "$POKEMON_ENV/evidence/audio-inspect" --output "$POKEMON_ENV/evidence/audio-check"
python tools/audio/convert.py trace --asset audio2:SFX_Cry00_2 --pitch 255 --length 192 --output "$POKEMON_ENV/evidence/audio-cry"
python tools/audio/convert.py check --fixtures --output "$POKEMON_ENV/evidence/audio-fixtures"
python -m unittest discover -s tools/tests -p 'test_audio_*.py' -v
```

`inspect` verifies the pinned pokered revision and every consumed file against
its git blob, then records SHA-256 values and tool hashes. It resolves Blue
conditionals, bank-qualified labels, local scopes, variable channel headers,
all calls/loops/wave pointers, 248 source map routes, 151 species cries by
internal index and Pokédex ID, and 165 move routes. The extra trailing move-table
row is identified separately as a sentinel. There are 362 headers, 2,319 resolved
references and 402 consumed source files. Unsupported source forms fail with
filename/line. Header IDs are bank-local; pointer values are isolated data-section
offsets, not claimed linked ROM addresses. Cross-section data pointers fail.

`trace` begins from the engine's stop-all reset. One shared source-tick transport
advances eight software channels over four voices, with source numeric SFX
priority, percussion dispatch, stolen-music progression and release events.
It records register writes, exact 8/16-bit delay arithmetic, shared tempo and
fraction resets, duty rotation, discrete vibrato, pitch-slide arithmetic including
the borrow bug, wave RAM, cry modifiers/return holds, and low-HP tones. Calls have
one overwriteable return slot. Finite loops use the source's single counter.
Bounded recurrence includes channel PCs, return slots, counters, effects, shared
state and registers. It excludes oscillator state and proves no PCM seam.

Variants are selected with `--variant Music_RivalAlternateStart`,
`Music_RivalAlternateTempo`, `Music_Cities1AlternateTempo`, or
`Music_PokeFluteInBattle` on the corresponding base asset. The last uses
`audio2:SFX_Caught_Mon` before overwriting the three flute entry pointers.
`--events <json>` accepts a list of `{ "tick": 10, "asset": "audio1:SFX_Collision_1" }`
SFX requests; modifiers are optional. `--alarm` selects the Audio2 direct alarm.
Unknown commands, zero-time cycles and nonclosing tick bounds fail; bounds retain
`trace.json`. `check --fixtures` retains all traces and reports bounds as exit 2.

Validation: **27 host tests, zero skips**, including dirty-source and wave-byte
mutations, fractional/overflow/zero-delay boundaries, shared reset, call/return,
loops, pitch-slide boundaries, arbitration, variants and alarm timing. All 21
macro forms actually encountered in Blue streams are exercised across 24 fixtures.
Pallet, Routes3, Cities1/drums, Lavender/Tower wave5, battle tracks, rival variants,
cry00 variants and both flute paths are included. Lavender and the added Dungeon1
fixture do not close within 120,000 ticks; every other fixture ends or repeats.
This is a reported limit, not a successful seam check.

RGBDS is absent. The fallback checks 22 explicitly audited macro byte cases, four header cases and
all three bank-relative wave5 prefixes. It is **not independent execution**.
When `rgbasm` and `rgblink` are available, the same command assembles the original
pinned macros and source prefixes into isolated objects and compares emitted bytes;
it records tool versions. That optional path was not executed here. Independent
engine/register execution is also not established. Renderer work still needs those
qualifications and a hardware timing reference. `unknownmusic0xef` is absent from
these streams and fails in tracing. Fade/mute lifecycle, mid-trace music replacement,
game script conditions, runtime routing, oscillators and PCM remain future work.

The small [qualification summary](../../tools/references/audio/qualification.json)
records counts, outcomes and evidence hashes. Complete closure/opcode/pin reports
and large traces are under
`~/Developer/Pokemon-PlayDate-env/evidence/audio-parser/review-qualification/`.
The deterministic inspect/check and standalone cry CLI outputs are sibling
`review-inspect`, `review-check` and `review-cry-cli` directories.
