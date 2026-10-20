# Rules and lifecycle contracts

The SDK runner imports the production modules, including `lib/rng` before battle/DSL/zone consumers and `dev/contracts` after production modules. `Contracts.run()` returns `{ok, passed, failed, tests}`; each test includes its name, success flag and actual Lua error on failure. The harness `contracts` command must fail when `ok` is false and preserve this report in its structured result.

Run through the runtime owner's private harness session:

```sh
python3 tools/harness/run.py contracts --output /private/tmp/pokemon-contracts-unique-run
```

Use a fresh output directory. The command builds and starts its own identified SDK bundle, waits for the handshake, executes contracts and writes build/runtime/result evidence. Runtime launching, Data directories and Simulator ownership belong to the root integration agent during concurrent work; workers must submit runs to that owner.

## RNG contract

`RulesRNG.seed(integer)` initializes the production rules stream. `RulesRNG.random()` returns a unit float in `[0,1)`; `random(n)` returns `[1,n]`; `random(low,high)` includes both endpoints. Integer interval bounds must lie within `[-1073741823,1073741823]`, with at most 2147483646 possible outcomes. Invalid requests fail before consuming a roll. Seeds normalize into `[1,2147483646]`, with zero mapping to 2147483646. `RulesRNG.new(seed)` creates an independent stream with colon methods.

`RulesRNG.snapshot()` returns detached plain data `{algorithm, seed, state, rolls}`. `restore(snapshot)` validates the algorithm and values before replacing state. The initial production seed is 1; fixture/session setup must explicitly seed the rules stream. The algorithm identifier is `park-miller-16807-v1`. Snapshot restoration resumes the next roll exactly. `rolls` counts generator advances, including rejected samples in integer interval sampling.

The Park-Miller state recurrence uses Schrage decomposition to keep every intermediate within signed 32-bit integers. This matters because the installed Playdate SDK manual explicitly specifies 32-bit numbers. Integer outputs use rejection sampling to avoid interval bias; unit floats use 24 bits and remain below 1 under float32. Known state vectors from seed 1: 16807 after one advance, 282475249 after two, 1043618065 after 10000.

Production battle damage/accuracy/AI/status/run/multi-hit draws, DSL lazy random numbers/chances/status durations, and zone encounter checks/species/levels all use this stream. Cosmetic shake remains on `math.random`. A seed for `math.random` alone no longer seeds gameplay; the fixture, structured `seed` command and legacy seed command must call `RulesRNG.seed`.

## Simulation and rendering

`BattleState:update()` drives battle logic, then the guarded `scene:update()`. The iris advances for twenty simulation frames. Frame twenty still draws the fully open stencil; input becomes available on frame twenty-one, matching the previous draw-driven sequence. Flash and shake clocks advance in scene update, and draw consumes cached visibility/offset values. When input advances a script and starts a hit after update, `BattleScene:handleInput()` synchronizes only the newly started effects through `updateEffects`, preserving their first visible frame. Effects that did not change are not advanced twice.

`BattleScene:draw()` and `drawBattleField()` do not advance iris/flash/shake clocks or consume randomness. Drawing can allocate graphics images and load/cache sprite assets, and applies the cached display offset. Repeated renders without a simulation update preserve rules and presentation state. Battle exit resets the display offset through the existing lifecycle hook.

## State and Signal behavior

Public `change`, `push` and `pop` remain synchronous when called outside an ongoing transition, including from update/draw/input. Lifecycle hooks and `changed` listeners can request further transitions; these requests run in order after the current transition finishes its exit/changed/enter or exit/changed/resume sequence. The outermost transition drains the queue before returning. A queued change/push returns its resolved state; queued pop returns the current top when requested. Nil-containing argument lists are preserved with `table.pack`/`unpack`.

Every successful transition increments a generation counter. If an update/draw callback transitions, the remaining traversal stops even if the same object reenters or remains below a new overlay. Unknown destination states fail before exit. Reusing one registered instance twice on the active stack fails. Same-state `change` remains valid and exits/enters. Empty pop is a no-op. More than 100 chained lifecycle transitions fail with a loop diagnostic; error handling clears pending transitions and releases the transition guard. A throwing lifecycle callback is not transactionally rolled back: callers should treat its error as a failed operation rather than a successful transition.

Overlay policy remains bottom-to-top update/draw, top-only input. Nested machines inherit this policy by explicit forwarding. State owners remain responsible for listener cleanup on exit. Signal removes `once` before invoking it, tolerates nested emit/add/remove, cancels remaining callbacks when listeners are cleared mid-emission, and unwinds its emission bookkeeping when a listener throws.

## Coverage and validation status

Twenty SDK-executed cases cover OOP inheritance and listener isolation; Signal mutation/reentry/clear/error cleanup; lifecycle order and forwarded arguments; overlay and nested input/update policy; same-state reentry; transitions during draw/update; duplicate overlays; lifecycle callback reentry; transition-loop recovery; queued return values; RNG reference vectors/snapshots/validation; Pokémon HP/PP/restoration/XP boundary invariants; Gen V type composition; battle direction/DSL/status immunity; production-round replay with cosmetic draws; read-only actual SDK rendering; twenty-frame iris and effect clocks; and encounter/DSL random replay.

The suite uses production Pokémon, battle coroutine phases, moves, zone selection, DSL and SDK image contexts. It advances coroutine messages directly for bounded rules tests; those cases do not certify physical button timing or the input-driven campaign journey. The render test uses real `BattleScene:draw` and SDK image contexts, with context cleanup even if drawing fails. It restores the production rules snapshot and display offset when the suite finishes. Cosmetic random state is intentionally exercised and is not restorable through Lua's standard random API.

Worker validation: SDK `pdc` compilation of the production source and contract module passed; `git diff --check` passed. Integrated Simulator execution and visual inspection are owned and recorded by the root agent. Do not treat compilation as contract execution or these invariants as a complete Gen V correctness audit. Known battle/data issues listed in the codebase audit remain outside this change.

## Controlled mutation qualification

`tools/rules-tests/mutations.py` copies production source through the harness build staging path and applies each deliberate defect only to that copy. It refreshes the embedded build identity, recompiles with the SDK and records changed-file hashes. Defaults compile without launching any runtime:

```sh
python3 tools/rules-tests/mutations.py --output /private/tmp/pokemon-mutants-build-unique
```

The runtime owner qualifies detection with:

```sh
python3 tools/rules-tests/mutations.py --execute --output /private/tmp/pokemon-mutants-execute-unique
```

Variants: passing `control`, the baseline state machine, baseline Signal implementation, rules routed through cosmetic `math.random`, and a draw-time iris increment. `--variants` selects a subset. Runtime qualification requires the control to pass and specific named assertions to fail for each mutant; a build failure, launch error, absent contract report or unrelated failure cannot count as successful detection. Each run uses the existing SDK-wide runtime lock, isolated UUID Data/bundle ID and owned-process cleanup. `qualification.json` aggregates failures and links actual contract reports. This tool deliberately expects mutant harness executions to return nonzero; its own exit status is zero only when the expected failures were observed.

Integrated execution reported by the root agent: all twenty production contracts passed in the real SDK Simulator, with full result at `/private/tmp/pokemon-harness-contracts-catalog-01/00001-result.json`. Worker inspected that result's report structure. All five mutation variants compiled successfully at `/private/tmp/pokemon-contract-mutants-compile-01/`; runtime mutation qualification remains the root owner's next validation step.
