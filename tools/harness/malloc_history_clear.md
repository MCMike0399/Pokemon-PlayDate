# Prepared malloc-history helper (Root only; integration UNAPPLIED)

`malloc_history_clear.swift` is a macOS host utility for the exact SDK 3.1.2
Simulator SHA256 embedded in its source. It writes no preferences/TCC, activates
no window, launches no Simulator and takes no locks. The user chose to retain 16 MiB and enable Accessibility. Do not execute
AX inspection/Clear until trust is actually verified.
`AXIsProcessTrusted()` never requests permission; false refuses. No System Events,
AppleScript, input injection, generic UI action or permission workaround exists.

Build privately (never add the binary to Git), and retain both identities:

```sh
swiftc -O tools/harness/malloc_history_clear.swift -o "$PRIVATE_DIR/malloc-history-clear"
shasum -a 256 tools/harness/malloc_history_clear.swift "$PRIVATE_DIR/malloc-history-clear"
```

Only the existing runtime owner may launch the helper, directly as its child:
`[helper, "inspect" or "clear", output, sha(build.json), sha(run.json)]`.
Use `subprocess.run(..., timeout=9, capture_output=True)` with no shell; verify
Root's pinned helper hash first. Metadata pins must come from the actual new
run, not an old example. The helper checks build/run identity, the entire PDX
file inventory, SDK executable hash, live executable/argv/user/parent/start time,
and the global Simulator, global device and private Data locks. Lock JSON alone is insufficient:
read-only `lsof` must report that direct parent holding each full write lock.
No lock is acquired or modified. Unsupported lock reporting refuses safely.
It has an eight-second lifetime ceiling and 200 ms AX messaging timeout.

`inspect` prints menu roles/titles/descriptions and window titles for only that
verified PID; it descends into only the menu bar and exact `Malloc Log` windows.
It never opens the log. `clear` presses only one enabled exact-title
`Clear Malloc History` menu item, or button within exact `Malloc Log`. Multiple
matches, another label, absent/hidden control, inaccessible tree or AX error
refuses. There is no fallback to a generic `Clear` button or menu navigation.
Root must inspect the real tree first; binary strings do not verify AX labels.
An accepted AXPress is not confirmation of history reclamation. Root must retain
before/after host footprints separately; neither this helper nor its tests prove
memory improvement, device admission or timing validity.

## Minimal Root integration guidance (not applied)

Existing `finish()` in `Source/dev/doorCensus.lua` closes measurement before GC
and row publication. After **trial two**, flush the row/segments, retain the
existing trial/case advance, and enter a private `clear_wait` phase instead of
starting the next pair. Publish a tiny atomic pause marker containing build ID
and completed pair index. At the very top of the private update, return while
waiting; do not invoke the gameplay callback or begin an active segment. Resume
only on an exact matching ack, consume that ack once, then run normal `nextCase`.
This pause/ack is necessary: host observation of a streamed row alone cannot
prevent the next measured interval from starting before AXPress completes.

In the existing host guard loop, handle only the fresh matching pause marker:
check unchanged guards and child liveness, invoke the pinned helper directly,
retain argv/pins/stdout/stderr/return code plus monotonic start/end/elapsed in a
separate `malloc-clear.jsonl`, then ack only on success. Failure follows existing
owned-child cleanup; never continue silently. Keep the 1 GiB footprint ceiling,
60 s no-row deadline and overall timeout active during the bounded pause. Do not
reset progress time for Clear. Do not subtract overhead from completed rows or
attribute it to traversal/GC. Require a new pause index for every ack.

This is a small private observer/host change Root must apply and compile later;
no gameplay input command, new acceptance protocol or production hook is needed.
Preserve pair seed restoration, trial-two effects, copied/earned slot hashes,
actual warm/cold/unresolved cache labels, all Lua guards, `MallocPoolSize=16645684`
and existing hardware gates. This helper does not implement the pending
profiler-off alternative. Qualify a bounded run before any long census.

SDK local `Inside Playdate.html`, “Profiling malloc calls in the Simulator”,
describes the pool/log. Panic explains retained history and Clear freeing it in
[2022 support](https://devforum.play.date/t/giant-memory-leak/7971), and retained
allocations again in [2024 support](https://devforum.play.date/t/simulator-memory-leak-on-mac/16384).
These support the proposed control, not a current-SDK causal result.

Host rejection checks: `python3 tools/harness/malloc_history_clear_host_checks.py HELPER RETAINED_CENSUS_RUN`.
