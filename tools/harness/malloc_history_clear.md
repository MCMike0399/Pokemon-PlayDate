# Malloc-history helper (Root only; short live qualification)

`malloc_history_clear.swift` is a macOS host utility for the exact SDK 3.1.2
Simulator SHA256 embedded in its source. It writes no preferences/TCC, launches no Simulator and takes no locks.
Explicit show/clear operations activate only the verified Simulator Malloc Log. The user chose to retain 16 MiB and enable Accessibility. Do not execute
AX inspection/Clear until trust is actually verified.
`AXIsProcessTrusted()` never requests permission; false refuses. No System Events,
AppleScript, arbitrary coordinates or permission workaround exists. The exact
SDK3.1.2 Malloc Log broom is not exposed as an AX control. Its bounded fallback
uses normal mouse events only after a fresh AX hit-test confirms the verified
Simulator PID and Malloc Log window, at the visually inspected740×480 layout
point(48,462). Other window dimensions or targets refuse. The cursor is restored
only if the user has not moved it. No pool, checkbox or game input is changed.
The exact window bounds are rechecked after payload verification and immediately
before cursor placement; a move or resize refuses the operation.

Build privately (never add the binary to Git), and retain both identities:

```sh
swiftc -O tools/harness/malloc_history_clear.swift -o "$PRIVATE_DIR/malloc-history-clear"
shasum -a 256 tools/harness/malloc_history_clear.swift "$PRIVATE_DIR/malloc-history-clear"
```

Only the existing runtime owner may launch the helper, directly as its child:
`[helper, "inspect", "show-log" or "clear", output, sha(build.json), sha(run.json)]`.
Use `subprocess.run(..., timeout=9, capture_output=True)` with no shell; verify
Root's pinned helper hash first. Metadata pins must come from the actual new
run, not an old example. The helper checks build/run identity, the entire PDX inventory, SDK executable
hash, live executable/argv/user/parent/start time and all three owner locks.
Darwin's lsof does not expose BSD flock owner PIDs. History-enabled census runs
therefore use POSIX write locks on the same existing lock paths; Darwin makes
these mutually exclusive with the ordinary BSD flock owners in both directions.
The helper opens those paths read-only and uses F_GETLK to require an exclusive
whole-file write lock belonging to its direct parent PID. It never acquires or
changes a lock. Metadata alone is never sufficient. Ordinary sessions retain
the original OwnerLock; the explicit JOURNEY opt-in below uses the same history mode.
It has an eight-second lifetime ceiling. Its application-root AX object has a
200 ms messaging timeout; Apple's API applies that setting only to that object,
not every child reference. The whole-helper alarm remains the outer bound.
Attribute copies alone may retry `CannotComplete` once, with fresh value storage
and an audit message. Other errors refuse immediately. AX actions and mouse
events are never retried, and a returned helper refusal still stops the owner.
Errors include the attribute and traversal scope. Host transport-error checks
do not establish native recovery or explain an intermittent application failure.

`inspect` lists only the verified Simulator menus and Malloc Log controls,
excluding allocation-table rows. It can retain a native capture of that exact
Malloc Log window. `show-log` opens only the unique observed `Show Malloc Log`
menu item, after identity verification. There is no fixed settling wait; Clear
independently verifies the actual window before input.
`clear` prefers the unique exact `Clear Malloc History` AX control. SDK3.1.2's
observed unlabeled broom uses the guarded window-specific fallback above.
A requested click is **not** proof of reclamation: the host retains the control
inspection before/after and actual process footprints. Inspection PNGs are
retained separately with hashes, not overwritten as evidence. Every inspection
uses a unique UUID capture path and capture failure refuses helper success. The
host attaches only the successful path returned by that inspection, never an
existing shared PNG. No command
acknowledgement by itself qualifies a long run or establishes device memory.

The original helper's compile-only assumptions were corrected in live runs:
`lsof -b` could not resolve the lock path, BSD lock owners were unreported, the
log window was closed, and its broom has no AX element. Process-targeted mouse
events did not clear the log and remain rejected. The successful short run is
`history-clear-qualification-20261101-18`: two actual portal trials complete;
records reset to zero and sampled host footprint falls by about120/143MiB at
its two Clear boundaries. These profiler counts are not live-game heap counts.
Six-case qualification20 reports all12 trials (10measured/two geometry gaps),
no runtime failure,13Clear boundaries and811MiB sampled host peak. Paired
clearing19 hit1GiB; pause now follows EVERY trial. Independent review remains
required before long use. Long-run boundedness is not established by this pilot.

## Census integration

The private census now pauses after startup and every completed trial. Its
update returns without gameplay until an exact build/row acknowledgement;
watchdog/memory checks remain active. The host runs the pinned helper directly,
records inspect/Clear output, elapsed time and before/after process footprints
in `malloc-clear.jsonl`, and acknowledges only a successful exact Clear result.
The pause stays outside transition intervals. Clear failures/timeouts stop the
owned child without replay. The 1 GiB host, 60 s progress and overall deadlines
remain active. More than two selected cases cannot execute without this support.

The private census observer collects at its existing cooperative loading
checkpoints as well as suspensions once Lua heap reaches8MiB. It checks the
unchanged hard guard before collection; an observed9MiB violation is never
collected away. Explicit `observer-boundary` segments exclude that diagnostic
collection from active elapsed time while wall time and GC counters retain it.
If the collected live baseline remains above8MiB, another full collection waits
for64KiB of new allocation; the9MiB hard check still runs at every checkpoint.
This avoids repeatedly collecting an unchanged live working set. Segment TSV
uses six decimal places so hundreds of short boundaries do not lose totals;
the host's existing validation tolerance is unchanged. Original producer failure
is retained independently if later evidence parsing also fails.
Unexpected setup exceptions and production safe errors terminate the census;
they cannot become ordinary gaps followed by more work in damaged state.
Fresh source entry chooses an approach outside visible actor source homes using
the existing SourceActors descriptor and WorldMotionData visibility policy.
It does not hide/move actors or alter flags/collision. Unexpected setup failures
still stop; a lack of unoccupied approaches remains an explicit coverage gap.
RockTunnelB1F setup first enters1F through the normal field owner. No field
offset, story flag, collision or resource is fabricated. Cache residency remains
the actual pre-input state; first trials are not automatically called cold.

After Accessibility is actually available, Root prepares a NEW identified stage:

```sh
python3 tools/device/door_census.py --project "$B" --sdk "$SDK" \
  --earned-save-dir "$EARNED" --output "$FRESH" \
  --history-helper "$HELPER" --history-helper-sha256 "$HELPER_SHA256" \
  --case '<exact inventory ID>' --timeout 120 --execute
```

The startup sequence is inspect → exactShowMallocLog → inspect → Clear → inspect.
Later trial pauses use Clear → inspect. Native captures and controller overhead
are retained separately from transition intervals. The actual native broom and surrounding controls have been inspected.
Missing/ambiguous controls, a changed layout or foreign hit-test must fail closed. Use a
bounded qualification before a long run. An accepted AXPress is not a measured
memory-reclamation result. No pool setting, gameplay command, source data,
canonical save or device admission policy changes. This hook has only host
checks and SDK compile-only validation so far.

SDK local `Inside Playdate.html`, “Profiling malloc calls in the Simulator”,
describes the pool/log. Panic explains retained history and Clear freeing it in
[2022 support](https://devforum.play.date/t/giant-memory-leak/7971), and retained
allocations again in [2024 support](https://devforum.play.date/t/simulator-memory-leak-on-mac/16384).
These support the proposed control, not a current-SDK causal result.

Host rejection checks: `python3 tools/harness/malloc_history_clear_host_checks.py HELPER RETAINED_CENSUS_RUN`.

## Opted-in ordinary JOURNEY owner (host preparation only)

The existing root runner now accepts `--history-helper ABSOLUTE_PATH` and
`--history-helper-sha256 SHA256` together, only for its existing process-journey
scenarios. No default owner changes lock mode. Opted-in sessions use whole-file
POSIX write locks on the same Simulator, device and private Data paths; metadata
and kernel-owner proof are both still required. Census invocation/validation is
retained separately and is not a way to admit a journey.

The explicit helper identity is:

```
HELPER OPERATION OUTPUT BUILD_JSON_SHA256 PROCESS_JSON_SHA256 JOURNEY processes/NNNN/process.json
```

Only the actual root runner launches this command as a direct child. It pins the
new stage's actual `build.json`, PDX inventory and current generation's
`process.json`; these bind build/session, harness bundle ID, executable hash,
PID, direct parent and native start seconds/microseconds. The verifier also
checks the latest generation in actual `run.json`, its live executable/argv,
all three kernel fences, and the actual matching unacknowledged pause/result.
Do not manually invoke the helper from a different shell or fake census fields.

The private staging hook freezes before the next game update after a successful
request ends in settled overworld exploration, with no jumping, pending edge
door, held input or recording. The root `main.lua` bytes are untouched. Pauses
are nonterminal: only an exact build/session/request/tick acknowledgement from
the owner releases them. Updates, timers, movement and rules RNG do not execute
while paused. Save UI, battle, warp and incomplete movement boundaries cannot
Clear. These restrictions can still stop a journey at the hard guard if a safe
boundary is not reached soon enough; there is no automatic replay or shortcut.
Native command/frame timing ends before the pause; helper overhead stays in the
separate `processes/NNNN/malloc-clear.jsonl`, with wall time retained. Journey
results are not production latency measurements.

The first safe pause performs inspect/show/Clear/inspect. Later safe
pauses Clear/inspect when host footprint is at least512MiB. Limits are64 Clears
and131 helper calls per generation; existing scenario validation bounds process
generations. Each helper still has its original8s alarm and9s host ceiling.
During helpers, the owner checks footprint, disk, progress and the original
command deadline every50ms. The1GiB hard stop,31/30GiB disk admission/reserve,
60s progress check and4h generation wall ceiling remain active during pauses.
No game Lua guard or16MiB pool change is introduced. Helper pin changes,
refusals, deadlines, capture failures or invalid acknowledgements poison this
owner, skip further finalization commands and stop its owned Simulator child.
No failed Clear is retried. Native captures use their unique helper paths and
are bound by SHA256 in the audit. A Clear reply alone proves no reclamation.

Compile-only handoff commands (Root selects a durable private directory):

```sh
swiftc -O tools/harness/malloc_history_clear.swift -o "$PRIVATE_DIR/malloc-history-clear"
shasum -a 256 tools/harness/malloc_history_clear.swift "$PRIVATE_DIR/malloc-history-clear"
python3 -m unittest tools.tests.test_journey_history
```

Root's eventual existing journey invocation adds only these pins:

```sh
python3 tools/harness/run.py \
  --scenario tools/harness/scenarios/midgame/restart-55c-bulbasaur.json \
  --output "$FRESH_OUTPUT" \
  --history-helper "$PRIVATE_DIR/malloc-history-clear" \
  --history-helper-sha256 "$HELPER_SHA256"
```

Use the existing Root admission/guard wrapper too, unchanged. First independently
inspect the native controls and qualify one Clear plus a short ordinary C
segment under this actual owner. Only then run all three existing earned
journeys (substitute `charmander`/`squirtle` scenario filenames). The implementation
worker ran no SDK compile, Simulator, native AX, device, USB or global locks.
Swift compile and host checks do not establish native pause behavior, correct
current broom layout, reclamation, complete journeys or acceptance. No census
was resumed. Root must record actual before/after footprint and native control
captures in the new evidence, rather than reuse census qualification.

### Generation fence correction

Generation archival excludes the live root `owner.lock` file. POSIX record locks
are released when the owning process closes any descriptor for that inode, so
copying that file would silently release the private fence. Owner metadata stays
in the live descriptor and existing process evidence; archival never reopens the
fence. A two-generation subprocess test verifies a competing POSIX writer is
refused after each archive and succeeds only after the owner exits. This fixes
the review finding; actual native Clear qualification remains pending.

### First-open journey memory qualification

The first journey pilot stopped at the unchanged 1 GiB host limit: initial
inspection used about 392 MB; showing Malloc Log raised usage to 880 MB; its
pre-Clear inspection crossed 1 GiB. No Clear ran. The next candidate removes
that pre-Clear inspection and uses the existing verified-window broom path
directly for JOURNEY Clear, without traversing the populated log's AX children.
The exact SDK binary, native window, 740×480 layout, current PID/locks and point
hit-test remain mandatory immediately before input. Inspection/capture follows
Clear. Census behavior is unchanged and remains stopped. This is a candidate
until actual native reclamation and a short journey segment pass; no host guard,
pool, timing or game-state check is relaxed.

### Ready-title boundary candidate

Three ordinary C pilots remain failed, with their true outcomes retained. The
latest removed the fixed 500 ms Show wait, but Clear still met a busy AX window
while the native log grew from about 395 MB to 1.056 GB. None qualifies a Clear.
The next candidate makes the first pause at the already-prepared title menu,
before Continue constructs the saved map. Lua, host and helper independently
require root/stack exactly `title`, phase `menu`, an active menu and no player.
Preparing, confirmation, options and in-world titles with a player refuse. The
same no-held-input/no-recording request barrier applies; the later settled
exploration rule is unchanged. No save inspection or Continue validator is
skipped, and no gameplay input is injected by the helper. Native identity,
three kernel fences, window/layout/hit-test, deadlines and memory guards stay
mandatory. Actual native Clear and a short segment remain pending fresh review.

### Cleared log closure candidate (host preparation, 2026-11-02)

Base `df38d73f1e3eb3c613939d1c17f334922a15a7c9` now has Root's actual initial
Clear and short ordinary-walking qualification (pilot05: 67 requests, through
Route15(14,9), native post-Clear capture with zero items). It stopped at the
unchanged 64-Clear bound / 130 calls: retained log UI footprint stayed above
the 512 MiB trigger. See Root's
`E/journey-history-clear-short-qualification-20261102-05.json`. This is not a
complete C journey and does not qualify this closure candidate.

JOURNEY alone now uses `inspect-close` for each post-Clear inspection. In the
same bounded helper invocation it retains the unique native PNG first, checks
capture success and complete PNG framing, then resolves that captured window's
AXCloseButton. It requires the same unique AX object and native window ID,
matching native/AX bounds at exactly 740×480, button role/subrole/enabled state,
button window/owner, and fresh full runtime/parent/payload/three-fence identity
before its single AXPress. No close coordinates or generic window action exist.
Absent/ambiguous/changed controls refuse. It polls actual AX and native window
absence for at most 600 ms within the existing 8-second helper lifetime; it
never retries the action. Unconfirmed closure refuses and poisons the owner.
Capture files survive even a later close failure.

Successful output is the inspection listing followed by `inspection capture`
and `inspection closure` records binding PID/window ID/frame. Closure explicitly
reports `verified-window-AXCloseButton`, `ax_absent=true`, `native_absent=true`.
The host verifies the retained PNG and hash and exact matching, ordered closure
evidence before permitting the next request acknowledgement. Audit stdout and
before/after host footprints remain in the existing `malloc-clear.jsonl`.
Initial ready-title order is inspect → show-log → Clear → inspect-close; later
actual Clears use show-log → Clear → inspect-close. Below-trigger pauses never
reopen the log. Reopening adds a helper call to each later Clear; the existing
131-call ceiling can therefore stop a generation before 64 Clears. Both caps
remain unchanged, as do defaults, 512 MiB trigger, 1 GiB hard host limit, pool,
disk/Lua/progress/watchdog limits and honest elapsed wall deadlines. Census
behavior is unchanged and stopped. No Source changes are part of this candidate.

Root must use a freshly compiled and SHA256-pinned helper with its existing
admission/guard wrapper and the existing `run.py --history-helper ...
--history-helper-sha256 ...` command above. First measure actual post-close host
footprint and inspect the retained native capture and closure evidence. Neither
host tests nor Swift compilation establish that closing releases any memory;
all runtime/SDK/AX/GUI/device qualification belongs exclusively to Root.
