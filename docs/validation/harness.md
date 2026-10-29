# SDK Simulator harness (protocol 1)

Run from the repository root with Python 3 and Playdate SDK 3.1.2:

```sh
make test-harness
make harness-smoke
python3 tools/harness/run.py --qualification --output /private/tmp/pokemon-qualification-unique
python3 tools/harness/run.py 'dismiss' 'gamestate' 'shot opening-dismissed'
python3 tools/harness/run.py --scenario tools/harness/smoke.json --output /private/tmp/pokemon-smoke-unique
```

`PLAYDATE_SDK_PATH` or `--sdk` selects the installed SDK; the default is
`~/Developer/PlaydateSDK`. `--output` must be a new directory. Without it,
artifacts go to `tools/shots/runs/<UUID>`. Nonvisual functional journeys and protocol checks do not require Pillow. Visual
catalog invariance contracts, the explicit NPC motion Continue PNG pose proof,
and `tools/autopilot.py --strip` require Pillow from
`tools/requirements-dev.txt`; the runner checks visual contract dependencies
before launching the Simulator. Each invocation builds and launches a fresh
session. Put multiple requests in a scenario to retain one runtime between
requests; separate CLI invocations intentionally start independently.

The runner copies Source into the evidence directory, generates a harness-only
configuration, assigns a UUID bundle ID, compiles using that SDK's `pdc`, then
launches the exact `Playdate Simulator.app/Contents/MacOS/Playdate Simulator`
binary with the absolute bundle path. It never uses `open` or broad `pkill`.
The process PID, SDK version, revision, source-content hash of the staged source (including untracked Source files),
dirty status, bundle path and session ID are recorded. The source hash is computed after copying Source, so concurrent edits to the
live checkout cannot misidentify the compiled staging tree. The generated
configuration is excluded from that base hash; original pdxinfo, per-file source
manifest, generated overlay names, and a second hash of the exact final compiled
source tree are recorded. The ready handshake must identify the same compiled build/session. Production builds have
`HarnessBuild.enabled=false` and do not intercept input or poll mailboxes.

Scenario sets containing only journeys use the `journey` harness profile. It
keeps input, snapshots, captures and reset support, but does not import or compile
contract suites or catalog exporters. The existing Day Care contract source is
kept for the journey dependency hash, but is not imported or executed. Driver
JSON data remains available. Full snapshots and trace rows are written on command
completion and every 30 frames; heartbeats, every gameplay frame, input handling,
named captures and recordings keep their original cadence. Transitions wait for
the next trace row. Contract/catalog command builds retain the full overlay and
per-frame trace. `build.json` records the profile and excluded development files;
the original source manifest remains intact and the compiled hash covers the
actual reduced staging tree. This keeps journey tooling from consuming the
16 MB pool needed by the game. It does not change production Source or rules.

Simulator Data uses `SDK/Disk/Data/com.poc.pokemon.harness.<UUID>` because the
installed Lua file API is sandboxed by bundle ID. This isolates saves from the
normal game's bundle. Before staging a runtime job, the host acquires a global per-user Simulator
`flock` under `/private/tmp`, shared across repositories and SDK installations.
It also locks the private Data directory for the full runtime lifetime.
`Client` acquires that private owner lock itself or requires a live matching
`OwnerLock` token from its caller; two clients cannot overwrite the same session.
Use Client as a context manager or call close() when it owns its lock. It terminates only its `Popen` child and archives then removes
only that UUID directory on exit. The evidence directory and staged source are
retained. `--build-only` compiles without launching or creating SDK Data.

For long-run diagnosis, `--recent-interval N` optionally reduces only recurring
recent PNG exports (integer 1..2147483647). The default is 1 and preserves the
original runtime path. For N > 1, the runner copies `tools/harness/capture_policy.lua`
to private `Source/dev`, then appends its import after every original main
definition. Repository Source remains untouched. `source-manifest.json` and the
base hash describe the original staged copy before overlays; `original-main.lua`
retains its exact main bytes for reconstruction. `build.json` declares generated
overlay paths and `capture_policy`; the compiled hash includes the exact overlay,
configuration and appended main. Staging never rereads live Source after copying.

The overlay samples completed ticks divisible by N using the existing eight-pair
ring. Manifest publication forces the current completed tick if it was not already
sampled. There are no duplicate sampled ticks, relabeled phases or synthesized
offsets. Named shots, recordings and catalogs retain their original paths and
cadence. Gameplay updates, input, HP and RNG are unchanged; this is neither a
campaign shortcut nor a confirmed fix for the unconfirmed long-run timeout cause.
An uncaught `Harness.afterFrame` exception in this optional overlay publishes an
identity-matched primitive error/tick report, stops future updates and rethrows.
It does not call snapshot code, manufacture captures or claim quiescence. Failed
publication is logged; ordinary host failure/unfinalized handling still applies.

Only the root runtime owner runs the native SDK witness (workers may build only):

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python tools/harness/run.py --recent-interval 60 --scenario tools/harness/scenarios/capture-policy.json --output "$POKEMON_ENV/evidence/capture-policy-sdk-UNIQUE"
python tools/harness/run.py --recent-interval 60 --scenario tools/harness/scenarios/brock/brock-natural-charmander.json --output "$POKEMON_ENV/evidence/charmander-policy-UNIQUE"
```

Run the witness at default 1 too for compatibility. Inspect `captures.json`:
eight distinct increasing recent ticks, all completed; every nonfinal tick is
divisible by 60 for the optional arm, and the last tick equals `capture_tick`.
The four recording frames must remain consecutive completed ticks, and both named
shots and all raw/presentation PNG pairs must exist. Compare phase and display
offset metadata against the corresponding `trace.jsonl` snapshot; inspect the
native PNGs. These are root-owned real-SDK checks, not assertions established by
host staging tests. An afterFrame fault witness requires a separately declared
staged fault injection; the normal witness does not claim error-path coverage.
`suite.py --recent-interval N` forwards the policy to ordinary jobs and records it
in the plan/summary. N > 1 with a selected mutation job is rejected because its
separate source-identity builder does not support this overlay.

## Scenarios and timing

A scenario contains `commands`, or `requests` (an array of command arrays), plus
optional `outputs` listing required PNG filenames in the frames directory:

```json
{
  "commands": [
    {"op":"assert","path":"zone","equals":"reds_house_2f"},
    "dismiss",
    "move right 4",
    "move up 1",
    {"op":"await","path":"zone","equals":"reds_house","frames":90},
    "shot downstairs"
  ],
  "outputs":["downstairs.png"]
}
```

Actions execute once per game update before production update/input/draw.
Each command completes only after that frame's update/input/draw and timers.
Snapshots refer to that completed frame; `shot` and recordings use SDK
`graphics.getWorkingImage()` after drawing, not the previous displayed frame.
Ticks are monotonic simulation updates at the game's 30 FPS target, not wall
clock time. `await` observes pre-update state and reports a post-update snapshot.
A completed move can initiate a door transition; await `zone`, `overworld`
`explore`, and `player.settled` when arrival settlement matters.

All old useful actions remain: move/face/warp, wait, shot/dumpimg, record,
encounters, press/mash/dismiss, battle, intro, gamestate/state/pokemon, seed,
debug, and atlas. `atlas` now uses the full visual catalog. Additional actions:

- `hold <button>` and `release <button>` control continuous synthetic input.
  `press` lasts one frame; physical button query functions are isolated for the
  entire harness session, including just-released and aggregate button state.
- `snapshot` returns a structured observation in the command result.
- `quiesce` is terminal for a session and must be the last settled command. The
  host sends it automatically after the scenario. Its acknowledgement follows
  all final frame captures and atomic `captures-final.json` publication. Future
  Simulator updates perform no game, input, timer, heartbeat or artifact writes.
  A quiescent Client rejects further actions; start a new run instead.
- `assert` and bounded `await` use a dotted snapshot `path` and scalar `equals`.
  Paths include `root`, `stack`, `zone`, `overworld`, `story.stage`,
  `story.starter`, `player.x/y/facing/settled`, `dialog.ready`,
  `battle.phase/introPhase/inMoveSelect`, `battle.menu.active/selected`,
  `battle.moveMenu.active/selected`, `pokemon.hp/status/pp.<move>`, and enemy
  equivalents under `battle.enemy`.
- `fixture` accepts `options` with seed, intro (`skip` or `reset`), optional
  zone/entry, and opening=false. It exits the old stack top-down without
  resuming old states, removes timers/sprites, restores initial zone
  tiles/collision/NPC definitions, resets story/trainer flags/Pokémon/position,
  resets controls/recordings, then enters a fresh world. `intro reset/skip`
  use this same safe reset. Fixture setup is explicitly distinct from a
  natural player journey. Reset captures the boot definitions once; future
  persistent systems must extend this owner rather than add partial resets.
- A supplementary fixture `{ "op":"fixture", "options":{"adjust_battle":
  {"player_hp":1,"enemy_hp":1}} }` adjusts HP on an existing battle without
  selecting an outcome or replacing its phase/coroutine. Values must be within
  1..maxHP. This deliberately labeled shortcut is for supplementary win/loss
  checks and must not be included in a natural campaign acceptance journey.
- `contracts` executes the SDK production-module contract suite and fails if
  any case fails. Its report is included in that command's result.
- `catalog` calls `VisualCatalog.write(outputDir)`, verifies every returned
  image exists, and writes the manifest as `catalog.json`. Missing-art entries
  are explicit in that manifest, not silently replaced by successful captures.

Unexpected movement collision/interruption fails the scenario. A deliberate
collision is `{ "op":"move", "args":["up",1], "expect":"blocked" }`.
Other allowed outcomes are `ok`, `interrupted`, and `edge-door`. `expect` is an
assertion, not permission to ignore unrelated errors. Names used for output
files are restricted to letters/digits/underscore/hyphen.

## Ownership and protocol

Requests and replies are JSON objects with `protocol`, `build_id`, `session_id`
and unique request `id`. Host publishes `request.json`; runtime publishes
`result.json` with status, numbered per-command results and final snapshot.
Both publish via temporary file plus rename. `ready.json`, `heartbeat.json`,
`runtime-error.json`, `rejected.json` and `trace.jsonl` aid diagnosis. A wrong
protocol/build/session is rejected. Old result IDs are archived and never count
as success. Incomplete/malformed results, invalid commands, assertions, missing
outputs and runtime errors fail with a nonzero host exit.

Command values support the full signed-int32 span without the SDK JSON decoder's
float32 rounding. The host recursively tags Python integers with
`abs(value) >= 16777216` as a reserved singleton object, for example
`{"__harness_int32_v1":"2147483647"}`. The runtime decodes it through
`DecimalInteger` before normalizing or executing any command. Untagged numeric
values at that boundary, overflow, malformed/duplicate/unknown reserved tags,
extra tag fields and nonfinite values fail closed with
`error_code="invalid-integer-wire"`. Caller-supplied reserved tag keys are
rejected by the host. Booleans, normal strings and small finite floats retain
their types; fixture seeds require Python integers and never coerce floats.
Text `seed -2147483648` also remains exact. Numbered request evidence records the
actual tagged wire packet; `scenario.json` retains the original input.
Terminal result `rng_data` carries exact decimal RNG diagnostics; legacy numeric
snapshot fields may still round during JSON serialization. All 34 host tests and
26 root-owned native SDK integer cases passed, including malformed multi-command
packets leaving the prior seed unchanged and subsequent request recovery.

`--timeout` bounds each request in wall seconds; `--max-frames` bounds runtime
execution (default 1800, maximum 18000). On host timeout it atomically publishes
`cancel.json` for that exact request and waits up to two seconds for a matching
cancelled response. Cancellation and runtime frame timeout stop queued input
and recording and perform whole-session reset before acknowledgement; the old
snapshot is retained as `interrupted_snapshot`. If cancellation cannot be
confirmed, the runner terminates its owned runtime before returning failure.
A new request must never be sent after an unconfirmed timeout or a malformed,
incomplete, or wrong-identity response while a request is pending. Client.send
blocks reuse in that state. Client.recover() first confirms the pending request
terminated (requesting cancellation when needed), then confirms a fresh runtime
fixture reset before allowing further actions. Failed recovery requires closing
the client and terminating the owned runtime. The runner always terminates its
owned PID on any scenario failure.

`--qualification` runs deliberate faults against its real SDK runtime:
malformed and wrong build/session handshakes, malformed/wrong-session/replayed
requests, invalid commands/assertions, stale/wrong-build replies, host timeout
while recording/holding movement, cancellation reset/recovery, runtime frame
timeout, and competing actual runner/client rejection. It writes
`qualification.json` with one result per case and retains each request/result.
The competing runner is required to fail before it stages a source tree or
launches a process. This mode is a fault test, not a player journey.

The host protocol tests use temporary directories and a small mailbox peer;
they do not replace real SDK runtime validation. Run them with `make
test-harness`. Real qualification must additionally exercise wrong identities,
invalid commands, host timeout/cancellation plus recovery, fixture reset during
battle/movement/dialog/recording, natural intro and starter/rival outcomes.
The smoke file demonstrates opening dialog, natural stairs and a reset; it
does not claim full campaign coverage or hardware validation.

## Evidence

Each run retains build.json, run.json (including PID), staged Source and PDX,
build/Simulator logs, original scenario, numbered request/result JSON,
outcome.json, PNGs, catalog manifest when requested, and archived runtime Data
with heartbeat/error/complete frame trace and timestamped root/overworld/battle
transition events. A bounded eight-frame ring retains recent completed frames
with their exact ticks under `frames/recent/`. Failure results contain semantic
snapshots and `failure.png` when command execution fails. Timeout snapshots
include the state being interrupted. Inspect native-resolution captures as well
as semantic results; a JSON success cannot certify appearance.

The SDK references used are installed `Inside Playdate.html`: JSON encode/decode,
file.rename, Simulator.writeToFile, graphics.getWorkingImage, timer.allTimers,
frameTimer.allTimers and the button query APIs. No stock-Lua source rewriting,
regex transpilation, or fake Playdate execution is involved.

## Deeper serial suite

One command runs smoke, production SDK contracts plus full catalog, protocol fault
qualification, and every named journey scenario currently in
`tools/harness/scenarios`. Optional `--mutations` adds the isolated real-SDK
contract mutation qualifier:

```sh
python3 tools/harness/suite.py --output /private/tmp/pokemon-suite-fresh
python3 tools/harness/suite.py --mutations --output /private/tmp/pokemon-suite-with-mutants-fresh
python3 tools/harness/suite.py --list
```

Nested scenario directories are discovered recursively. Top-level case names stay
unchanged; nested cases use `--` between path components, e.g.
`brock--source-trainer-1`, `brock--tm-full-retry`, `brock--blackout`,
`brock--failed-sight`, `brock--brock-natural` and `brock--brock-restart`.
All ten Brock cases appear in `--list`; duplicate flattened names fail explicitly.
Plan-only reports prove selection/copying, never runtime acceptance.

Select cases explicitly to rerun a bounded subset. Selection order is preserved;
there is no implicit reuse or skipping of previous successes:

```sh
python3 tools/harness/suite.py --only qualification interior-roundtrips overlays-inputs wild-return wild-blackout-fixture --output /private/tmp/pokemon-suite-remaining-fresh
python3 tools/harness/suite.py --only smoke contracts-catalog --output /private/tmp/pokemon-suite-short-fresh
python3 tools/harness/suite.py --plan-only --only qualification interior-roundtrips --output /private/tmp/pokemon-suite-plan-fresh
```

Every suite output directory must be new. Scenarios are copied into its immutable
`inputs` directory before execution. A separate suite lock prevents competing
suites, and child run.py jobs independently acquire the shared global Simulator
lock. The parent never holds the child runtime lock. Jobs execute serially and
each stages a fresh identified Source/PDX and UUID Data session. Freeze Source
while running: suite success requires equal revision, base staged content hash
and SDK version across all ordinary jobs. The final compiled staging hash is
verified against each retained source tree. Deliberate mutation variants have
separately recorded hashes and are excluded from base-source equality.

The default policy aborts after the first failed case and records every remaining
case as `not_run`. `--continue-on-failure` explicitly runs the remaining requested
cases and still returns a nonzero final exit if any fail. No successful old
result can satisfy a requested new case. `--job-timeout` bounds each whole job
(default 240 wall seconds); ordinary requests also retain their shorter runtime
bounds. On deadline the suite first interrupts the child Python runner so its
owned-process cleanup runs, then uses only that child job's process group if
cleanup does not finish. It never broadly kills Simulator processes.

`suite.json` records completeness, per-case status/errors, source consistency,
revision/content/compiled fingerprints, SDK versions, build/session IDs, PIDs,
and exact evidence directories. Adjacent `*-host` directories contain each
child's full argv/stdout/stderr. `suite-plan.json` records requested cases and
scenario checksums. `--plan-only` launches nothing and explicitly records that
no runtime validation was performed. CLI exit 0 for a real suite requires every
requested case to pass; a plan is never represented as validated evidence.

## Raw and presentation captures

SDK `graphics.getWorkingImage()` and `getDisplayImage()` omit
`display.setOffset`. The original `<name>.png` is therefore a **raw working
buffer**, even when a battle shake is visible on the Simulator. Each scene
capture and recording frame also exports `<name>-display.png`, reconstructing
the visible offset by shifting the raw buffer onto the current graphics
background color. Clipping/exposed pixels follow the SDK's documented offset
behavior. These companion images do not modify the raw frame or production
rendering. Catalog asset images remain their own raw asset renders.

After the terminal producer-quiescence acknowledgement, the host consumes the
atomic `captures-final.json` manifest and writes `captures.json`. This inventory
lists only retained explicit captures (latest version for each name) and the
final bounded eight-frame ring, with exact tick, phase, offset, background color
and `offset-on-background-v1` transform. Archived `captures.jsonl` contains only
explicit capture events; reuse of an explicit name is historical activity, not a
claim that an overwritten old image still exists. Recent frames are not appended
to that event log: their tick-named PNG pairs live in private Data/recent and the
oldest pair is deleted once the ring exceeds eight. The host copies only final
retained pairs into `frames/recent` after the producer stops. Normal images are tagged `completed`; a cancellation capture made
before this update draws is tagged `previous-completed-frame`; an exception
mid-update is tagged `partial-error`. The latter is diagnostic and must not be
claimed as a completed visible frame. The host verifies both PNGs and their
400×240 dimensions before success.

Snapshots include `display.offsetX/offsetY/scale/inverted/mosaicX/mosaicY`,
background color, frame tick/phase, battle iris/intro timing, cached shake X/Y,
shake timer/intensity, and flash timer/visibility. Reconstruction currently
supports the display offset used by this game. Capturing unsupported scale,
inversion or mosaic fails explicitly. Review attack/shake motion using the
`-display.png` sequence and its matching per-frame diagnostics. Existing strip
creation intentionally selects only numbered raw frames; presentation sequences
can be assembled separately for display-motion review.

The producer barrier fixes a reproduced race in the first integrated suite:
normal gameplay had passed, but the host read a rolling PNG while a later frame
was rewriting it. Validation remains strict. The new deterministic host test
pauses a producer with a truncated PNG and proves verification cannot run until
quiescence completes its final image/manifest. A missing barrier acknowledgement,
missing/incomplete final inventory, invalid PNG, wrong dimensions or oversized
recent ring fails. Terminating the Simulator before reading is not used as a
publication barrier because termination can interrupt an image write.

Failed scenarios also attempt confirmed quiescence while their Data ownership
lock remains held. A poisoned Client first confirms cancellation/fixture
recovery. Original error results/snapshots remain in evidence. If the producer
cannot confirm quiescence or artifacts remain invalid, `artifact-finalization.json`
records that limitation and the host terminates its owned PID; it does not claim
those artifacts were finalized. The final quiesce action is an additional
numbered request/result, including for contract and mutation scenarios.


When the staged Source contains `dev/comprehensiveCatalogContracts.lua`, a
`contracts` request also requires the named `catalog-invariance-v1` host
qualification. Contracts report executed stable suite IDs; the runner never
infers qualification from English test descriptions. Before launch it prepares
only the two owned `frames/catalog-invariance-before` and `-after` directories.
After producer quiescence it copies the two native manifests, verifies all859
source-derived entries in each phase (1718 actual PNGs), dimensions, standalone
masks and exact decoded RGBA including hidden RGB. Missing, corrupt, stale or
changed artifacts fail the invocation. `catalog-invariance-qualification.json`
records build/session/request/process identity and the result. Restart evidence
is archived per process before the next boot clears only those owned transient
manifests; saves are untouched. More than one comprehensive export suite in one
process fails explicitly rather than reusing overwritten artifacts.
