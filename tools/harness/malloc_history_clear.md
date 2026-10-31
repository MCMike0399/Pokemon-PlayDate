# Malloc-history helper (Root only; live validation pending)

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

## Census integration

The private census now pauses after startup and each completed case pair. Its
update returns without gameplay until an exact build/row acknowledgement;
watchdog/memory checks remain active. The host runs the pinned helper directly,
records inspect/Clear output, elapsed time and before/after process footprints
in `malloc-clear.jsonl`, and acknowledges only a successful exact Clear result.
The pause stays outside transition intervals. Clear failures/timeouts stop the
owned child without replay. The 1 GiB host, 60 s progress and overall deadlines
remain active. More than two selected cases cannot execute without this support.

After Accessibility is actually available, Root prepares a NEW identified stage:

```sh
python3 tools/device/door_census.py --project "$B" --sdk "$SDK" \
  --earned-save-dir "$EARNED" --output "$FRESH" \
  --history-helper "$HELPER" --history-helper-sha256 "$HELPER_SHA256" \
  --case '<exact inventory ID>' --timeout 120 --execute
```

The first operation is a scoped inspect, retained before the Clear attempt. Actual
labels are not yet verified; absent/nonunique labels must fail closed. Use a
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
