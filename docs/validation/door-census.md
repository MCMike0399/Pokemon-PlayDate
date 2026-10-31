# Checkpoint B door and connection census preparation

This is a compile-only preparation for root. It is not runtime evidence or an
acceptance record. No Simulator, GUI, runtime lock, serial, USB, device command,
canonical save, production module or existing ledger was touched during preparation.

The input is exactly `76559ac87b210a2e71c0520a1da3f8059a9e8d9c`, whose existing
checkout is `/Users/burbujamc/.t3/worktrees/Pokemon-PlayDate/t3-2c976160`.
Run the tool from the implementation checkout. Its `--project` is a read-only
production input, not the location from which it obtains the new observer.
The tool imports that input checkout's existing staging/qualification/identity
helpers, privately copies and qualifies its production Source, and then adds
only `dev/doorCensus.lua`, bounded case JSON records, a private bundle ID and a
two-line main import/after-ready hook. It preserves the uninstrumented main.
It refuses another revision, dirty input Source/tooling, another SDK version,
stale pins or existing output.
No checkpoint switching, synchronization commits or checkout setup is involved.

## Inventory and coverage

`inventory.json` is the single inventory, including every input map even if it
has no portals. Raw declarations, stable IDs, source files, source and padded
coordinates, declared destinations, source-owned LAST_MAP context, blocked flags,
scripted flags and candidate approach identities remain visible. The production
stager independently regenerates and byte-checks compact metadata and binary
cells from all pinned source inputs before compilation.

At the exact input the inventory contains:

- 149 manifest maps and 510 source warps, including 169 LAST_MAP declarations,
  15 scripted warps and 12 blocked warp surfaces. These counts overlap.
- 61 directional connection declarations, expanded to all 1,922 boundary cells,
  including solid origins, out-of-range alignments and targets outside the manifest.
- 11 actual authored door declarations and two authored Pallet north seam entries.
  Route 1's declared south boundary cases separately identify their authored target.
- 2,445 case identities, with two requested trials each: 4,890 result rows.

The source warp inventory does not invent resolved coordinates. At runtime the
observer uses `SourceMaps.warpSpec` and `SourceMaps.connection`, with the existing
`KantoSlice.connection` adapter for the authored seam. Scripted destinations are
observed only after the real DoorWarp resolver runs. Unknown targets stay unknown.
Authored door literals are parsed strictly and checked against actual Zone doors;
unsupported syntax fails preparation. Debug teleport presets are not portals.
The authored test map has no declared doors or connections.

Warp cases retain all four source approach candidates, or the actual edge
approach. Each warp case attempts the first static land candidate. Runtime
occupancy, field state and scripts may prevent that approach; alternatives remain
listed, but this version does not pathfind or search around an actor. Connection
cases cover every declared boundary cell rather than selecting one representative.
Solid cells remain explicit gaps. This is portal census coverage, not a claim
that every approach is reachable from the earned location.

## Root commands

Preparation from the implementation checkout requires only the real SDK compiler:

```sh
python3 tools/device/door_census.py \
  --project /Users/burbujamc/.t3/worktrees/Pokemon-PlayDate/t3-2c976160 \
  --sdk /Users/burbujamc/Developer/PlaydateSDK \
  --output /private/tmp/door-census-B-prepare-root-01
```

For a durable preparation, choose a fresh directory under the existing evidence
root instead of `/private/tmp`. The optional earned-save input can also be given
at preparation time; both adventure slot bytes and hashes are retained unchanged.
Without an earned input, later execution reports every traversal as a gap and
never invents party members, badges, items, story flags, actors or field resources.

Only root, after the running physical sequence and title/installer work finish,
may execute this command. `EARNED_B_SLOTS` must point to the actual earned B
slot directory selected by root, containing both `adventure.a.json` and
`adventure.b.json`. It is an input, never a writable runtime directory.

```sh
EARNED_B_SLOTS=/Users/burbujamc/Developer/Pokemon-PlayDate-env/evidence/chain/5.5b/charmander
python3 tools/device/door_census.py \
  --project /Users/burbujamc/.t3/worktrees/Pokemon-PlayDate/t3-2c976160 \
  --sdk /Users/burbujamc/Developer/PlaydateSDK \
  --earned-save-dir "$EARNED_B_SLOTS" \
  --output /Users/burbujamc/Developer/Pokemon-PlayDate-env/evidence/door-census-B-root-01 \
  --timeout 14400 --execute
```

This builds a new identified private probe and then executes it. There is no
implicit reuse of a prepared or old successful run. The exact input is still
required after root's other work; this tool does not silently profile a changed B.
For a bounded first native qualification or rerun, add one or more exact case IDs
from `inventory.json`, for example `--case 'pokered:VIRIDIAN_MART:warps:1'`.
Selection restricts execution records, while the inventory always covers all 149
maps. A selected run never establishes a complete census. Root should first
qualify an ordinary step door, an edge door, a connection, a same-map scripted
warp and a deliberate gap. Those native checks have not been executed here.

## Runtime behavior and measurement

Execution alone acquires the existing global Simulator and device ownership
locks before preparation and calls the existing preflight. This includes the
actual SDK 16 MiB pool setting (`MallocPoolSize=16645684`) and USB reader exclusion.
It uses the exact SDK binary and a unique bundle/Data directory. A private Data
owner lock encloses the run. There is one child process and no parallel runtime.
Only its PID may be terminated; shutdown is confirmed before copying and removing
private Data. Deadlines, production errors and incomplete tails remain failures.

Each pair loads the copied earned slots through `GameSaves:continueGame`, keeping
the existing session/specimen authority. Source-map positioning is an isolated
fixture through normal `switchZone`, Overworld, provider/cache, WorldView, Player
and NPC owners, outside traversal timing. The second trial preserves actual
first-entry side effects within the pair. It does not promise identical quest
state between trials. The next pair restores the earned session normally.

The actual traversal receives one frame of directional input at the same four
SDK button-query seams used by existing diagnostics, followed by release. It
must complete ordinary collision, movement, Explore checks, DoorWarp and arrival.
The observer wraps DoorWarp entry to read the actual trigger and resolved door;
it never invokes that entry, queues a portal, calls an isolated loader or changes
collision. It requires observed completed stepping or a pending boundary input,
one matching portal entry and exact settled target coordinates. Wrong portals,
occupied approaches, story guards, field modes, actor requirements, arrival
scripts, battles, overlays and timeouts are gaps. It does not dismiss them,
grant resources, finish battles, collect rewards or write saves.

Every emitted row records source/approach/target, actual cache status, input and
completion observations, wall elapsed, total active SDK update time, longest
uninterrupted segment, trace sequence boundaries and Lua heap after a full GC.
The full GC happens at a safe case boundary outside the measured gameplay
interval; its own duration is explicit. A pre-entry GC is also explicit and
outside traversal timing. The census additionally collects at actual loading
suspensions when its 64-bit Simulator Lua heap reaches 8 MiB. Per-row
`observer_gc_count` and `observer_gc_ms` expose this diagnostic overhead for
the whole row (fixture plus traversal). `traversal_observer_gc_count` and
`traversal_observer_gc_ms` separately record collections inside the traversal. It is
excluded from active spans but remains in wall/sub-phase intervals. Production
Source, the 9 MiB hard guard and the native 16 MiB pool are unchanged. This
private collection schedule differs from production and cannot supply hardware
admission or production GC/pacing evidence. Diagnostic forced DEVICE_TEST
collections are not enabled.

`door-census-segments.tsv` cuts active spans at real SDK coroutine yields and
update returns. It records absolute start time, duration, case/trial, trace
sequence and loading status. Suspension, inter-frame waits and diagnostic stream
writes are excluded from active spans. Wall elapsed retains movement/fade/waits
and observer overhead before publication. Production BootTrace I/O remains in
measured production work. Timer resolution and observer cost have not been
independently qualified. A loading flag describes the observed boundary, not a
phase-exclusive CPU attribution.

`result.json` joins each row to the original inventory and existing BootTrace
sub-phases, including definition/art/zone/view/actors and `door.map` marks where
emitted by production. BootTrace phase gaps are wall intervals, not CPU slices.
`warm` means the target Zone was resident in the provider immediately before
input; `cold` means absent. It does not claim cold filesystem, tile, binding or
content caches. Script targets unknown before entry receive an explicit unresolved
cache label. Trial 2 is never assumed warm. `cache_before` records normal capacity
and residency. Cold reruns can select individual cases in fresh processes; setup
or Continue can still warm a target, so the recorded label remains authoritative.

Rows and segment records stream with bounded runtime state. The probe keeps one
case and one result at a time, without retaining screenshots, Zones, players or
hundreds of snapshots. Normal lifecycle and bounded-cache owners release prior
resources; the observer never resets provider internals. Raw BootTrace and
partial rows are preserved if an exception, guard, timeout or child exit stops
the run. The host surfaces missing trials as `not_run` and ranks only validated
measured rows, separately by wall time and longest active span. Nonzero exit
means any requested case was not measured, even when all gaps were enumerated.

The host checks input, qualified production Source, final staged Source, entire
PDX payload, compiler, implementation, observer, inventory, SDK, revision, private
bundle and PID identities using existing manifest/hash tooling. It verifies
copied and canonical earned-slot bytes after execution. `build.json` remains the
compile identity; `run.json` and `result.json` identify subsequent runtime work.
The terminal file is published only after producers stop. No new runtime proof
protocol, campaign driver or production planner is introduced.

Lua heap counts are not native graphics allocations, native headroom or physical
RAM. This census makes no natural-journey, earned-traversal, hardware-latency or
device-acceptance claim. Root must fit per-phase ratios from existing physical
traces and physically measure the worst five candidates later. Do not multiply
wall waits or fade time by a single CPU factor.

## Host and compile validation

```sh
DOOR_CENSUS_PROJECT=/Users/burbujamc/.t3/worktrees/Pokemon-PlayDate/t3-2c976160 \
  python3 -m unittest tools.tests.test_door_census -v
```

The host tests independently compare raw pinned warp identities and coordinates,
complete directional boundary sets, source collision/padding, retained LAST_MAP/
scripted/blocked cases and authored separation. Result checks reject unproved
measured statuses, wrong/duplicate identities, malformed timing and mismatched
platform traces; missing tails remain explicit. They do not emulate SDK execution.

Preparation in this worker passed these host checks and real SDK 3.1.2 compilation.
The retained final preparation directory and hashes are reported in the handoff.
The final compile-only stage explicitly copies the existing earned Charmander B
slots; preparation does not interpret or rewrite their gameplay values.
Runtime qualification, full census results, actual worst candidates, actor/field/
script feasibility, timing overhead, heap plateaus and hardware worst-five
measurements remain unperformed. No accepted evidence or ledger is changed.

The inventory helper and host tests also cover accepted main’s 108-map inputs
with their own exact totals. Runtime census preparation still requires the
explicit pinned 149-map revision; this does not activate B on main.
