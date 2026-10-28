# Lavender and Dungeon1 closure diagnosis

On `wip/audio-loop-closure`, merge `3a12392270218d7077b8c57f65460c827e827d64`
first integrated exact audio candidate `36bb332`. Source remains pinned to pokered
`af519899719f0754965776faac0e836a3b906e6d`.

**Both failures are genuine longer register schedules, not a demonstrated parser,
control-flow or closure-signature defect.** Keep the existing 120000-tick limit
and explicit rejection. No production parser, trace, renderer or game code changes
are needed for this result. A shorter score loop is not a register loop.

The original symptom reproduces through unchanged `Trace.run()`: Lavender emits
222469 events and Dungeon1 emits 264642; both return `bound`, last processed tick
119999, with no repeat. The new host regression asserts this rejection explicitly.

The pinned engines' `Audio1_ApplyMusicAffects` / `Audio3_ApplyMusicAffects`,
`PlayNextNote`, `vibrato`, `sound_call`, `sound_loop` and `note_length` explain it:
notes reload vibrato delay, but **do not reset rate or direction**. Each eligible
effect tick advances a rate cycle of `rate + 1`; two cycles restore direction.
For `E` eligible effect ticks per score lap, its phase multiplier is
`2*(rate+1) / gcd(E, 2*(rate+1))`. Fractional note durations and the intervening
`duration - 1` effect updates must be preserved, including rests.

| Track/channel | Score lap (ticks) | Vibrato phase multiplier | Register period (ticks) |
| --- | ---: | ---: | ---: |
| Lavender 1 | 2280 | 9 | 20520 |
| Lavender 2 | 114 | 1 | 114 |
| Lavender 3 | 3648 | 2 | 7296 |
| Lavender 4 / dispatched percussion | 114 | 1 | 114 |
| Dungeon1 1 | 3996 | 5 | 19980 |
| Dungeon1 2 | 3996 | 12 | 47952 |
| Dungeon1 3 | 3996 | 7 | 27972 |
| Dungeon1 4 / dispatched percussion | 3996 | 1 | 3996 |

The independent test walker reads original macro text, with its own command-index
control flow and cumulative integer timing. It uses neither encoded command bytes
nor Trace's delay/decode helpers. Three source laps per channel match the actual
transport's note onset, duration, fractional remainder and source location. The
predicted vibrato phase cycles also match observed source-loop entries. Their
least common multiples predict the complete register-state periods below.

A separate diagnostic ran **unchanged `Trace.run` and its complete snapshot key**,
including all eight channels, shared state and registers. Only event storage was
replaced by ordered SHA-256 block digests to bound artifact memory; no register
write, state field or effect was suppressed. Explicit diagnostic caps were 330000
and 1680000 ticks. It found:

- Lavender: identical full state at ticks **457 and 328777**, period **328320**
  (about 91.6 minutes); fingerprint
  `7798ee35549ba6627a1af5440c3341483a86c4d220fe5e0330655fcfe20275db`.
- Dungeon1: identical full state at ticks **109 and 1678429**, period **1678320**
  (about 7.8 hours); fingerprint
  `39eaf15e074edfd30c86e666896c4d97e64348316c2ca729e6456be8e8a98fe7`.

Isolated RGBDS 1.0.4 also assembled both complete original score files using
original macros/constants: **214 Lavender bytes / 4 transfers** and **826 Dungeon1
bytes / 71 transfers** match the catalog after rebasing local pointer operands.
This independently checks every note/loop/call byte and local transfer, not engine
execution or linked game-ROM addresses. Existing accepted byte fixtures are untouched.

Evidence and runnable proof scripts are under
`~/Developer/Pokemon-PlayDate-env/evidence/audio-loop-closure-20261026/`:
`prove.py`, `*-before.json`, `*-full-state-proof.json`, `source-periods.json`,
`score-bytes/report.json`, `assemble_scores.py` and host test logs. The long proof
reports retain source/tool hashes, caps, event counts and ordered block digests;
they are diagnostic summaries, not renderable IR. Reproduce the bounded regression:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python -m unittest tools.tests.test_audio_loop_closure -v
export PATH="$POKEMON_ENV/toolchains/rgbds/v1.0.4/rgbds:$PATH"
AUDIO_EXPECT_INDEPENDENT=1 python -m unittest tools.tests.test_audio_parser \
  tools.tests.test_audio_oracle tools.tests.test_audio_renderer \
  tools.tests.test_audio_loop_closure -v
```

Validation: **51 parser/oracle/renderer/closure host tests passed, zero skips**,
with isolated RGBDS on PATH. The missing-tools message in the log belongs to the
intentional strict-gate negative test. No SDK-facing interface changed.

No bound was raised in production, state removed from recurrence, score truncated
or seam accepted. Long periods also exceed the renderer's default 180-second
budget; this packet does not change that policy or generate soundtrack PCM.
Actual APU fidelity, listening, playback and SDK/runtime acceptance remain open.
No Simulator, Source Lua, game documentation/ledger/coverage/baselines, frozen
research outputs or accepted oracle fixtures were changed by this diagnosis.
