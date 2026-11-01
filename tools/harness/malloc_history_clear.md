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
the original OwnerLock; only history-enabled census ownership uses this mode.
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
menu item, after identity verification. A bounded500ms settling wait follows.
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
