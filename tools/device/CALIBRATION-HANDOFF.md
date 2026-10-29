# P0 calibration preparation — root handoff

Prepared in the supplied isolated worktree at main `91d3769`. Ownership is only
`Source/dev/calibration.lua`, `tools/device/calibrate.py` and this handoff.
Production entry point, bootstrap, BootTrace, data and existing tools are untouched.

Compile-only packet (SDK 3.1.2):
`~/Developer/Pokemon-PlayDate-env/evidence/p0-calibration-prep-20261028-04/`
contains `Calibration.pdx`, `build.json`, exact source and compiler/bundle SHA-256
manifests, retained staging and compiler log. Python syntax and SDK Lua compilation
were checked. No Simulator, USB, serial or device execution occurred. No measured
factor exists. This is not gameplay acceptance; the P0 game gate remains unverified.

Rebuild, outside any Git checkout, using the existing `tools.build` SDK builder:

```sh
python3 tools/device/calibrate.py build --output /absolute/new/outside-git-directory
```

Root must run the **same compiled PDX**, without rebuilding between platforms.
Copy each platform's `calibration.json` and `boot-trace.tsv` from its private app
Data into separate evidence directories. The bundle has a unique calibration-only
ID. BootTrace is copied unchanged; the private main imports graphics, BootTrace
and calibration only. No world/content/contracts or gameplay code is staged.

The two phases each execute 8192 blocks × 8 work units, starting checksum 1.
Compute uses 16 integer recurrences per work unit; allocation creates one eight-cell
table per work unit and retains no corpus. Values remain below 65521. Each block
checks the local high-resolution clock; a work update stops at 2 ms or 32 blocks.
One tiny block can overshoot the target. Scheduling, GC, rendering and small file
flushes are not hard real-time bounded; compile-only work cannot verify a callback
latency ceiling. No full GC, large native operation or large allocation is added.

`active_work_ms` sums timed work-update spans, including block timer checks and
incidental GC/preemption. `inter_frame_ms` sums exit-to-next-entry gaps during work;
drawing and phase trace/report I/O are excluded from the active-work spans.
`max_work_slice_ms` and `max_block_ms` expose overshoot. SDK `getElapsedTime()` is
documented in seconds with microsecond accuracy; `getCurrentTimeMilliseconds()`
used by BootTrace has millisecond units. Both clocks pause while the app is inactive.
They are **not OS process CPU clocks**. Float precision degrades with uptime; the
high-resolution timer resets once before this short run, never inside timed blocks.
See SDK 3.1.2 [clock documentation](https://sdk.play.date/3.1.2/Inside%20Playdate.html#f-getElapsedTime).

Compact `CAL1` JSON lines report ready/phase/complete/error/status. Only exact
`msg CAL1 ping` and `msg CAL1 status` are accepted; both return read-only status.
No eval, input injection, reset or game mutation is installed. Update remains live
on complete/error with a visible heartbeat/error screen. Test-only auto-lock stays
disabled until app exit; it cannot prevent a manual lock, cable loss, OS failure,
watchdog kill or exhausted battery. `pcall` catches Lua errors, not those failures.
Reports flush/close at phase boundaries and completion/error; BootTrace closes each
line. A failed import gets a best-effort error JSON and persistent live screen.

Compare downloaded records (no serial/device operations):

```sh
python3 tools/device/calibrate.py compare --build /packet/build.json \
  --simulator /simulator/calibration.json --device /device/calibration.json
```

The parser rejects build/source/SDK/platform/work/checksum mismatches and incomplete
records. It reports each measured device/Simulator active-work factor. A conservative
factor includes endpoint uncertainty (at least 1 microsecond per endpoint per work update,
increased using a conservative float32 precision bound at the recorded timer age)
and a safety multiplier of at least 2; no factor is emitted if uncertainty exceeds
10% of a measurement. The maximum phase factor gives provisional Simulator active
work allowances corresponding to 33/500/1000 ms on device, never a gameplay pass.
These are synthetic guidance, not measured map/battle budgets or a worst-case bound.
Missing evidence produces `unmeasured`, with no invented factor or zero-filled
map/battle fields. Repeated real-device measurements and root's game BootTrace still
own all P0 acceptance decisions.
