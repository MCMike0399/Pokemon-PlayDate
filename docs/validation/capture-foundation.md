# Gen V capture rules

Root integrated the capture rules and legacy yield-generator repair after all
194 native SDK contracts passed, including sixteen capture groups.
[Durable evidence](accepted-session-items-capture/acceptance.json).
The historical staging handoff is `/private/tmp/pokemon-capture-foundation`.
These rules return decisions only; ball consumption, capacity, recruitment,
animation and battle termination remain gameplay integration work.

## Evidence and formula

[Capture source pins](../../tools/references/capture-sources.json) include the
immutable [B2W2 personal table](https://github.com/kwsch/PKHeX/blob/d2fea14b563f4b16fef7788b9699b20d5b3f410f/PKHeX.Core/Resources/byte/personal/personal_b2w2),
[record layout](https://github.com/kwsch/PKHeX/blob/d2fea14b563f4b16fef7788b9699b20d5b3f410f/PKHeX.Core/PersonalInfo/Info/PersonalInfo5B2W2.cs)
and independently maintained [PokeAPI species data](https://github.com/PokeAPI/pokeapi/blob/2bf639e5572812a67d2b94903fdcb9d095f5aeb2/data/v2/csv/pokemon_species.csv).
All151 catch rates must agree between the byte at dex*76+8 and CSV capture_rate.
Examples: starters45, Pikachu190, Chansey30, Snorlax25, legendary birds/Mewtwo3.
No zero/missing-rate fallback is accepted.

The primary research is [Dragonfree's Gen V analysis, crediting poccil and magical](https://www.dragonflycave.com/mechanics/gen-v-capturing/),
checked against the author's [Q12 calculator implementation](https://www.dragonflycave.com/gen5capture-worker.js?v=1).
Snapshot checksums/last-modified information are recorded separately from
immutable build inputs; these public research URLs are not Git revision pins.
Downloaded snapshots remain under `/private/tmp/pokemon-capture-references`.
No complete third-party page/script is redistributed.

For ordinary terrain and no Capture Power: ball bonuses are1/1.5/2 for
Poke/Great/Ultra; sleep/freeze multiply by2.5, poison/burn/paralysis by1.5.
The HP factor is `(3M-2H)/(3M)`. The modified rate X keeps twelve fractional bits;
its HP division rounds down, status multiplication rounds to nearest Q12.
At X>=255 capture succeeds automatically; Master Ball bypasses the formula.
Otherwise the shake threshold is
`floor(roundQ12(65536 / roundQ12(sqrt(roundQ12(sqrt(roundQ12(255/X)))))))`.
The critical threshold is
`floor(roundQ12(roundQ12(min(X,255)*P)/6))`, with P=0 for caught0..30,
0.5 for31..150,1 at151. Critical compares0..255 strictly below that threshold;
shake checks compare0..65535 strictly below their threshold. Normal capture
needs three successful checks; critical needs one. Failed normal captures display
0/1/3 shakes, never2; failed critical captures display one. These are Gen V rules,
not the four-check rule or later exponent used by other generations.

## Integer implementation and replay seam

Runtime performs no floating point roots/powers. It uses native integer quotient/
remainder multiplication and binary square-root comparison, with exact rounding
from the remainder. It avoids products exceeding signed int32; HP supports the
positive16-bit range, original151 catch rates have minimum3, and all tested
coefficient/root operations remain bounded. The largest intermediate square is
never formed. A continuous fourth-root calculation is not interchangeable:
for rate255 at full HP, Q12 threshold49802 differs from a continuous approximation.

The independent host oracle uses Fraction and80-digit Decimal, rather than the
runtime's division/search algorithm. All64 literal parameter vectors were also
executed against the downloaded primary calculator and agreed. The25 seeded
attempt vectors use independent unbounded Park-Miller recurrence/modulo arithmetic.
Their large integer states are Lua literals in SDK tests; they are not decoded
through SDK numeric JSON. [The reference vectors](../../tools/references/capture-vectors.json)
remain host-readable evidence, with strict threshold-minus-one/threshold cases.

`Capture.parameters(enemyContext, ballId, caughtCount)` returns a detached pure
preview or `nil, reason`. `Capture.attempt(enemyContext, ballId, caughtCount, rng)`
returns the final result or `nil, reason`. The explicit context is:

```
{pokemon=actualPokemon, wild=true, terrain="ordinary", capturePower=100}
```

Only pokemon/wild are required. Absent/false wild rejects. Explicit unsupported
terrain, Capture Power, Safari/doubles or unknown context flags reject rather
than silently using the ordinary formula. Targets must be real production
Pokémon from the original151 with valid Gen V types, level, positive bounded HP
and coherent major status/sleep counters. Fainted targets reject. Only
`pokeBall`, `greatBall`, `ultraBall`, `masterBall` are accepted. `caughtCount` is the
number of distinct owned species from the authoritative dex,0..151, not party
size or number of caught individuals. Higher unused Gen V completion tiers are
not exposed for this roster.

`rng` is a production `RulesRNG.new(...)` stream or the active `RulesRNG` facade.
An attempt validates context first, trials on a cloned rules stream, then commits
only the completed result. Even counter exhaustion after the critical roll leaves
the caller RNG unchanged. It never changes the enemy or returns a recruited copy.
Preview mutation has no authority over a later attempt.

The project's documented draw cadence is one critical draw even at threshold0,
then up to three/one shake draws stopping on first failure. Master and natural
guarantees make no random calls. RulesRNG interval rejection can consume more
recurrence rolls than random calls; both counts are reported. This preserves
project replay behavior without claiming to clone the cartridge's PRNG/call stack.
Cosmetic math.random cadence cannot affect the result.

Results include:

- `caught`, `critical`, `guaranteed`, optional `guarantee` (`master-ball` or
  `modified-rate`), `ballId`, `catchRate`.
- `modifiedRate4096`, `shakeThreshold`, `criticalThreshold`, optional
  `criticalRoll`, `shakeRolls`.
- `checks`, `successfulChecks`, `displayShakes`, `rngRolls`, `randomCalls`.

Checks and displayed shakes intentionally differ. Normal failure on check3 has
two successful checks and three displayed shakes. Successful normal capture
uses three checks/displays three shakes; critical uses one. Guaranteed captures
report zero checks and three displayed shakes, with no synthetic random values.
For Master Ball, modifiedRate4096 is a saturation sentinel, not a calculated rate.

Failures include `invalid-capture-context`, `unsupported-capture-context`,
`not-wild-target`, `invalid-pokemon`, `invalid-target-hp`,
`invalid-target-status`, `unsupported-ball`, `invalid-caught-count`,
`invalid-rng`, `rng-exhausted`. Invalid inputs do not advance RNG; unexpected
production RNG defects surface with their original details. Battle constructs
wild context from its trainer flag. Party/storage capacity and ball stock must be
validated before calling attempt; consumption/recruitment must not be added here.

## Generation, tests and root execution

```
python3 tools/generate_capture_data.py --cache /private/tmp/pokemon-capture-references --output /private/tmp/pokemon-capture-foundation/Source/data/captureData.lua --check
python3 -m unittest tools.tests.test_capture_generator
GEN5_GENERATOR=/private/tmp/pokemon-capture-foundation/tools/generate_gen5_data.py python3 -m unittest tools.tests.test_gen5_yield_projection
```

A fresh catch-data build uses a new cache with `--fetch`, omitting `--check` for
the initial explicit output. Immutable file hashes are mandatory.15 offline
capture tests and3 staged legacy-yield tests passed. Cache corruption is retained
for diagnosis; missing/schema/layout/incomplete/conflicting data and drift fail.
The separate test oracle introduces no runtime dependency.

16 production SDK cases are authored/compiled: all151 rate coverage, explicit
wildness, rejected unsupported contexts/balls/counts/targets, Master/natural
guarantees, exhausted RNG rollback, float-integer normalization, enemy identity
and field preservation, cosmetic replay independence, global/stream equivalence,
64 Q12 vectors and25 seeded results including strict boundaries. They return the
standard `{ok,passed,failed,tests}` report with expected/observed detail.

The source manifest and selective patch are
`/private/tmp/pokemon-capture-foundation/foundation-manifest.json` and
`capture-foundation.patch`. The root-owned helper overlays only the three new
Source files onto current Source, adds imports/contract registration to current
main, refreshes all fingerprints/config, and compiles. It verifies but does not
inject the staged host generator repair into runtime Source.

```
python3 /private/tmp/pokemon-capture-foundation/validate_staged.py --project /Users/burbujamc/Developer/Pokemon-PlayDate --output /private/tmp/pokemon-capture-runtime-01 --execute
```

Without `--execute`, this only compiles. That mode passed at
`/private/tmp/pokemon-capture-compile-02`. Root alone owns actual SDK execution;
no Simulator was launched by this worker. SDK acceptance remains pending.

## Narrow legacy yield repair

The patch also updates staged `tools/generate_gen5_data.py`: full species
regeneration now calls the existing growth generator's checked immutable
projection, indexed by National Dex. It no longer reads current PokeAPI
base_experience or fetches that unnecessary CSV. `--growth-cache` identifies the
pinned growth inputs; `--fetch` permits their immutable retrieval. Validation
happens before full generation writes. Missing projection entries fail rather
than restoring later-generation values or silently substituting0. Moves-only
behavior is unchanged. Three tests prove the projection dependency, replacement
of Pikachu112 with105 while preserving all other source bytes, and failure
before species output when a yield is missing. The legacy Showdown species
stat/type source remains unpinned and uninvoked; that separate provenance gap is
not hidden by this repair.

## Remaining capture and Safari work

This is a rules foundation, not a playable capture feature. No item throw command,
turn consumption, failed-catch enemy response, animation, money, capacity policy,
recruitment/dex/party/storage/save transaction or capture outcome/XP policy is
implemented here. Original-roster species do not need type-based ball bonuses
for these four balls. Other ball types, thick grass/doubles, Entralink powers and
special encounter flags need explicit future rules before being accepted.

Safari Ball is deliberately unsupported. The later Kanto Safari feature needs
its own admission/resource/steps state, bait/rock catch-and-flee effects, escape
checks, Safari-only ball accounting, capture storage and exit transaction.
The project must settle how the original Blue Safari interaction model combines
with the Gen V rules policy; it must not silently route Safari through an
ordinary Great Ball multiplier or consume ordinary bag balls. No Safari mechanic
is claimed complete by this slice.
