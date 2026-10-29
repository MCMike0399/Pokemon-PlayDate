# Exact private DeviceSmoke Simulator smoke

This tooling is based on `33f778389ffbd8baac19fefd965da74748577cff`.
Root owns all execution and Source integration. The worker compiled and ran host
checks only. No Simulator, USB, device run or hardware gate has passed here.

The device metrics hook is integrated in Source/dev/deviceSmoke.lua. It changes
no DS1 command or gameplay operation. Only Simulator runs poll the file mailbox;
both platforms record active timing segments. No full harness is staged.
Production builds remain free of dev modules.

Build once in a fresh directory, then verify without launching anything:

```sh
python3 tools/device/build_smoke.py --output /absolute/evidence/private-smoke-build
python3 tools/device/simulator_smoke.py --build-stage /absolute/evidence/private-smoke-build
```

The builder retains the exact production and compiled source manifests, Git
revision, whole-project Source fingerprint, compiler hash, SDK version, bundle
manifest and bundle hash in `build.json`. `source_sha256` uses the existing
Source fingerprint algorithm; `compiled_source_sha256` uses the canonical manifest
hash algorithm, so these two fields intentionally differ. `pdx_sha256` uses the
same canonical manifest algorithm as device-cycle inventory. Every production
asset except private main and pdxinfo remains equal. Only `dev/deviceSmoke.lua`
is added. A builder without the root patch still compiles for serial use, but
its missing transport version makes Simulator execution fail before launch.

Root supplies earned slots through a manifest in the existing device-cycle
format. Both files must be actual earned slots; import checks their exact hashes
and copies their bytes without decoding, fabricating or changing gameplay data.
A manifest has `directory` and `files`, with exactly two `{file, sha256}` rows
for `adventure.a.json` and `adventure.b.json`.

Root supplies a JSON array of DS1 command bodies, such as
`["press a 1", "wait 30", "state"]`. This is only a format example, not a
complete smoke route. Use ordinary buttons to Continue, traverse a real door,
start a battle and save. There are no fixtures, shortcuts or Lua evaluation.
The runner assigns increasing sequence IDs and waits for terminal DS1 responses.
It obtains state until the first ordinary game frame, then runs the supplied
commands. It does not infer how many buttons a particular earned save requires.

Only root may execute:

```sh
python3 tools/device/simulator_smoke.py \
  --build-stage /absolute/evidence/private-smoke-build \
  --output /absolute/evidence/private-smoke-run \
  --earned-save /absolute/evidence/earned-manifest.json \
  --commands /absolute/evidence/smoke-buttons.json \
  --timing-factor 35.11 --execute
```

The factor above is a provisional calibration example, not a measured game
factor. Root must retain its provenance and supply the appropriate measured
factor. The runner checks the SDK's persisted 16 MB pool setting (16645684),
shares the global runtime/device owner locks, uses the exact SDK executable and
retained bundle, and terminates only its own process. It never recompiles.
Existing private Data is refused rather than overwritten. Data remains in the
SDK after execution and is archived in `runtime-data`; root must archive/move it
before another run of this same build. A new compile has a new isolated bundle ID.

The mailbox atomically publishes one ASCII DS1 payload in private Data as
`device-smoke-command.txt`. The module removes it before calling the unchanged
`playdate.serialMessageReceived`. Printed serial responses remain unchanged;
Simulator responses additionally append to `device-smoke-replies.jsonl`. The
hardware path records metrics but performs no mailbox existence checks, reads,
writes or polling. Root can deploy precisely this PDX
without stripping anything or rebuilding it.

The observer wraps the SDK update function, follows initialization/error update
replacements, and brackets explicit coroutine yields. Each row in
`device-smoke-frames.tsv` is one active SDK update segment, with build ID, logical
update ID, segment index, termination kind, elapsed milliseconds, Lua heap and a loading-segment flag.
A yielding update produces multiple rows. The pre-yield timer stops before
suspension; resume resets it after polling. These are SDK elapsed spans, not OS
CPU samples. Only yields in the SDK update coroutine split the timer; nested
battle script coroutine yields preserve the running frame and their return values.
Suspension, mailbox polling and frame-observer writes are excluded.
Other work inside the callback, including GC, DS1 replies and BootTrace IO, is
included. The observer uses the SDK microsecond-accuracy elapsed clock; float precision and observer overhead remain limitations.
Imports precede observer installation and are covered by BootTrace, not frame
rows. A native/internal yield that bypasses Lua coroutine.yield is not observed;
current game cooperative loading uses the explicit bootstrap coroutine.yield.

`simulator-smoke.json` retains exact build metadata, BootTrace phases, every frame
row, title/Continue availability, verified load/save counters and DS1 snapshots.
Raw trace, replies, slots and Simulator log remain available even after failure.
Post-GC title/Continue heap must be at most 6 MiB; observed Lua peak at most
9 MiB. Map-load/battle-start wall spans must be at most 500/factor ms; ordinary gameplay
frames at most 33/factor ms; all slices, including loading, at most 1000/factor ms. Door measurement is
`door.map.begin` to `door.map.end`, excluding the intentional door fade. Phase
spans include suspension and are never presented as active frame time. Heap
sampling cannot establish native allocation peaks or the true between-sample
maximum. Missing observations/measurements, runtime errors and exceeded budgets
fail the command. Title and Continue post-GC samples, an actual door load, battle
start and verified save are all required for a Simulator smoke pass.

Every report sets `device_gate_passed` to false. A Simulator smoke pass is not
hardware acceptance. The separate `device_cycle.py --simulator-smoke` path admits only this exact
one-module private build after recomputing a genuine passed report; production
dev-build rejection remains unchanged. See [device-cycle.md](../device-cycle.md)
for root commands, raw DS1 replay and the unapplied hardware metrics hook.
A failed timing report is rejected before any device write.

Host checks, including compilation and decoded PDZ module inventory:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python3 -m unittest tools.tests.test_device_simulator_smoke -v
```

Phase prediction now separates active work from suspension. New frame rows
include the segment start time aligned to BootTrace. The device estimate is
observed wall time plus active time times (factor minus one), with a two-ms
endpoint allowance. Display/yield waits are not multiplied by a Lua CPU factor.
Both raw wall time and the estimated device phase must stay below 500 ms. Old
rows without start times retain the stricter legacy check and cannot use this
separation. The frozen command list and its hash are recorded for hardware replay.

The optional device metrics hook is now applied. Both platforms record active
segments; hardware polling returns before any mailbox filesystem access. The
segment observer's own writes remain excluded and are test-build overhead.
Battle admission is a transition measured against the separate 500 ms phase
budget, not a normal 33 ms gameplay frame. Loading/yield and slice limits still
apply. Frames after admission remain ordinary gameplay frames.

DS1 reply serialization, console output and reply-file writes are test transport,
so their elapsed time is now paused out of the game timer. Snapshot reads and
all production callbacks remain included. This prevents every command completion
from appearing as a game-frame stall. The metrics file write is also excluded.
