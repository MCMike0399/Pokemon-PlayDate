# B2W2 growth and experience foundation

Status: integrated and independently accepted by root. All 142 SDK contracts
and nine native regression jobs passed; all 915 protected artifacts are identical.
Root inspected the level-6 rival victory and actual Ember-learning screen.
[Durable evidence](accepted-growth/acceptance.json).
The historical staging handoff is `/private/tmp/pokemon-growth-foundation/Source`.
The selective patch is `/private/tmp/pokemon-growth-foundation/growth-foundation.patch`;
`manifest.json` beside it records original and candidate SHA-256 per file.
Do not copy staged `main.lua`: it is an isolated compile entry.

## Evidence and data

Immutable URLs and SHA-256 values are recorded in
[the growth source manifest](../../tools/references/growth-sources.json).
The generator independently joins [PokeAPI species growth assignments and experience CSVs](https://github.com/PokeAPI/pokeapi/tree/2bf639e5572812a67d2b94903fdcb9d095f5aeb2/data/v2/csv)
with [PKHeX's extracted B2W2 personal records](https://github.com/kwsch/PKHeX/blob/d2fea14b563f4b16fef7788b9699b20d5b3f410f/PKHeX.Core/Resources/byte/personal/personal_b2w2)
and [independently maintained threshold arrays](https://github.com/kwsch/PKHeX/blob/d2fea14b563f4b16fef7788b9699b20d5b3f410f/PKHeX.Core/PKM/Util/Experience.cs).
The pinned [B2W2 personal record layout](https://github.com/kwsch/PKHeX/blob/d2fea14b563f4b16fef7788b9699b20d5b3f410f/PKHeX.Core/PersonalInfo/Info/PersonalInfo5B2W2.cs)
specifies 76-byte records, growth byte at 0x15 and little-endian base EXP at 0x22.
Every one of 600 threshold values and all151 growth assignments must agree.
The original151 contain medium-fast80, medium-slow40, slow26 and fast5;
erratic/fluctuating remain generated and checked as complete six-family tables.

Twenty current yield fields reflect later generations. Candidate corrections:

| Species | Before | B2W2 |
|---|---:|---:|
| Butterfree / Beedrill | 178 | 173 |
| Pidgeot | 216 | 211 |
| Arbok | 157 | 153 |
| Pikachu | 112 | 105 |
| Raichu | 218 | 214 |
| Nidoqueen / Nidoking | 227 | 223 |
| Clefable | 217 | 213 |
| Wigglytuff | 196 | 191 |
| Vileplume | 221 | 216 |
| Dugtrio | 149 | 142 |
| Poliwrath | 230 | 225 |
| Alakazam | 225 | 221 |
| Victreebel | 221 | 216 |
| Golem | 223 | 218 |
| Farfetch'd | 132 | 123 |
| Dodrio | 165 | 161 |
| Electrode | 172 | 168 |
| Exeggutor | 186 | 182 |

All other species block bytes, including stats, types and complete learnsets,
were compared after masking only baseExp numbers and match live Source.
`GrowthData.species` provides the authoritative growth byte and Gen V yield;
the existing baseExp fields remain a checked compatibility projection.
The legacy broad species generator still obtains later-generation values;
its future regeneration must consume this pinned projection or fail this audit.

## Formula and numeric behavior

The [contemporary Gen V research synopsis by poccil](https://www.smogon.com/forums/threads/b-w-research-thread.79340/)
provides the scaled formula and operation order. The preserved text snapshot
hash and retrieval URL are in the manifest; no full thread is redistributed.
For the currently supported one conscious participant, original trainer and
no item/Pass Power/Exp. Share modifiers:

```
X = 2 * defeated_level + 10
Y = defeated_level + recipient_level + 10
Z = floor(base_EXP * defeated_level / 5)
if trainer: Z = floor(3 * Z / 2)
Q(n) = nearest_integer(sqrt(n) * 4096), half up
P(n) = floor(Q(n) * n * n / 4096)
award = floor(P(X) * Z / P(Y)) + 1
```

This is Gen V scaled XP; the old claim that B2W2 reverted to flat XP is false.
Round the base step before the trainer multiplier. Do not substitute the later
continuous ratio power formula or Ruby/Python float exponentiation at runtime.
The generator uses integer square roots; an independent 60-digit Decimal oracle
checks all210 coefficients and produces the58 literal SDK vectors. Some
modern implementations apply the trainer floor in a different order; they are
not used as the exact Gen V oracle here.

The SDK uses int32/float32. Even valid base yields/levels can overflow a direct
signed product; `Growth` uses bitwise long multiplication/division with bounded
integer intermediates instead. All XP inputs normalize through `math.tointeger`.
No RNG draws are added. Award is limited to100000 (unreachable for the supported
unboosted original151 domain). Level100/fainted recipients receive zero, and
the amount is clipped to the recipient's species maximum before any addition.

Fidelity decision approved by root: calculate the mathematically correct award,
without reproducing the cartridge unsigned32 numerator overflow glitch at
extreme encounters. This is an explicit arithmetic deviation, not a claim to
emulate every cartridge bug. Multi-participant sharing, traded OT, Lucky Egg,
Pass Powers, held items and switch participation remain unsupported; do not
silently assume those bonuses are implemented.

| Base EXP | Enemy level | Recipient level | Trainer | Award |
|---:|---:|---:|:---:|---:|
| 64 | 5 | 5 | no | 65 |
| 64 | 5 | 5 | yes | 97 |
| 62 | 6 | 5 | yes | 125 |
| 63 | 7 | 20 | yes | 45 |
| 64 | 50 | 5 | no | 2385 |
| 64 | 5 | 50 | no | 4 |
| 395 | 100 | 1 | yes | 58340 |
| 395 | 99 | 99 | yes | 11732 |

## Public seam and integration

`data/pokemon` imports `data/growthData` then `domain/growth`.
`Pokemon:xpForLevel(level)` returns its own species threshold for1..100.
Deprecated `xpForLevel(level, species)` requires explicit species; calling it
without species fails instead of silently treating every species as medium-fast.
At level100, `xpToNext` equals the maximum XP and the existing XP gauge renders
full. The staged BattleScene change only replaces its two threshold calls.

`gainXP(amount)` preserves the boolean first return and existing pending move
queue behavior. Its structured second return also includes `gained`, `totalXP`
and `capped` (gained<requested, including ineligible fainted grants). No player
move replacement happens automatically. The maximum is applied before addition,
so nativeMAX grants cannot wrap. Fainted grants are zero and cannot resurrect
through level-up stat growth. `calcExpGain(defeated, trainerBoolean)` requires
an explicit battle type and returns the amount eligible to be accepted.
Battle passes trainer presence, awards once, and suppresses zero-award narration.

Staged narrow caller migrations cover fixtures and existing SDK test modules.
Root must import `dev/growthContracts` after the existing production imports and
merge `GrowthContracts.run()` into the contract command. Its report shape is
`{ok,passed,failed,tests}` with 14 named cases and actual expected/observed details.
No fixture schema extension is required. Existing `player_pokemon`, `grant_xp`
and first-rival journey fixtures should use the species-aware threshold seam.

Root approved an explicit unreleased-record boundary: nested PokemonCodec is2,
codec1 rejects `unsupported-pokemon-record-version`. No XP migration is guessed.
Generic SaveStore envelope1 and aggregate session schema1 stay unchanged, since
these foundations have not shipped real aggregate player saves. Codec2 checks
species lower/upper thresholds and strict level100 maximum.

## Verification and balance

Executed here:

```
python3 -m unittest tools.tests.test_growth_generator
python3 tools/generate_growth_data.py --cache /private/tmp/pokemon-growth-references --output /private/tmp/pokemon-growth-foundation/Source/data/growthData.lua --check
~/Developer/PlaydateSDK/bin/pdc /private/tmp/pokemon-growth-foundation/Source /private/tmp/pokemon-growth-foundation/compile-only.pdx
```

13 host tests pass; real SDK compiler succeeds. Tests use offline fixture data,
exercise independent curve formulas/Q12 coefficients, source mismatch, missing
species/levels, duplicate levels, schema/cache/fetch errors and non-writing drift
failure. A fresh reproducible generation uses the same command without `--check`
and adds `--fetch` into a new cache. No unpinned fallback is accepted.
The 14-case SDK module is authored/compiled, not executed by this worker. Root
alone runs Simulator and must verify all prior contracts plus these cases and
native first-rival captures before acceptance.

All starters use medium-slow: Lv5 starts135, Lv6 threshold179, Lv7 threshold236.
The three first-rival trainer victories are now:

| Player / rival | Award | Final XP | Final level |
|---|---:|---:|---:|
| Charmander / Squirtle | 95 | 230 | 6 |
| Squirtle / Bulbasaur | 97 | 232 | 6 |
| Bulbasaur / Charmander | 94 | 229 | 6 |

The initial fight's stats/moves are unchanged. After winning, the player now
levels to6 and remains4..7XP from level7; no level7 move is queued yet. The old
flat award generally left the player at5. Native narration, XP bar, learning
handoff and subsequent encounter balance therefore require root regression.
This work does not complete campaign balance or the game. Existing simplified
stats have no IV/EV/nature model; abilities, evolution flow and reward sharing
remain separate future scope.

The root-owned overlay entry point preserves the current live entry/bridge code:

```
python3 /private/tmp/pokemon-growth-foundation/validate_staged.py --project /Users/burbujamc/Developer/Pokemon-PlayDate --output /private/tmp/pokemon-growth-runtime-01 --execute
```

Without `--execute` it only builds; that mode passed at
`/private/tmp/pokemon-growth-compile-03`. The helper overlays only the 12
manifest-listed files, guards original/candidate hashes, inserts the growth
contract import/registration into current main, and recomputes source manifest,
build identity, generated config and compiled-source fingerprints. It does not
copy the isolated staged main or overwrite other newly integrated modules.

Learning ID exhaustion is transactional: gainXP first plans the target level and
all distinct new choices, validates their move definitions and checks that the
next counter remains representable after allocation. A valid nativeMAX counter
permits XP/levels requiring no new choice; attempts needing any choice reject
`move-choice-id-exhausted` before XP, stats, moves, PP or pending choices change.
The codec counter ceiling is unchanged. A nativeMAX-minus-one counter can
allocate exactly one choice and then remains atMAX. The new SDK case covers
both boundaries with an existing real pending Ember choice preserved.
