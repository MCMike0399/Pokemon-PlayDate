# Root-only device cycle

This worker packet performs no runtime or hardware acceptance. Root owns the
PDX, BootTrace, test-only auto-lock/error hooks, Simulator and all device runs.
This extension starts at exact main `309194ee0b35f329426d21f8c19b9c0442780d11`.
No production source is modified. No USB reader is started at import or startup.

Build a retained **production** stage with the existing builder, then root runs:

```sh
python3 tools/device_cycle.py --execute-root \
  --pdx /absolute/candidate.pdx --build-stage /absolute/retained-build \
  --simulator-gate /absolute/root-measured-gate.json \
  --output /absolute/evidence/fresh-cycle --run-seconds 30
```

Use `tools/build.py --output /absolute/candidate.pdx --stage /absolute/retained-build`
for the existing compile-only build. The cycle checks its retained `Production.pdx`
against the candidate, hashes every source/payload file and records both manifests.
`pdx_sha256` is SHA256 of the payload hash dictionary encoded with Python
`json.dumps(files, sort_keys=True, separators=(',', ':')).encode()`;
`source_sha256` uses the existing builder's fingerprint. Root's gate must identify
both exact hashes, `malloc_pool_mb: 16`, and numeric `measurements` and `limits`
objects containing `heap_live_bytes`, `heap_peak_bytes`, `map_load_ms`,
`battle_start_ms`, `frame_ms`, and `slice_ms`. All measurements must pass the
supplied limits. Root supplies the actual measurements and approved budgets;
the CLI does not change Simulator settings or measure runtime itself.
The locally installed SDK documents the pool menu in *Inside Playdate*,
“Profiling malloc calls in the Simulator”. Do not fabricate a gate from compile
success or reuse one for another payload.

Each invocation runs exactly one bounded cycle. It takes the existing global
runtime lock and the device lock, requests `datadisk`, waits up to 300 seconds,
archives the currently installed PDX's complete hash inventory plus available
logs/identity and complete Data, using its own pdxinfo bundle ID, copies changed payloads, removes only obsolete PDX payload files,
verifies **every** installed hash, ejects, and sends `run /Games/<name>.pdx`
immediately after serial returns. It waits the requested interval while checking
serial presence, enters data disk and archives logs again. It leaves that disk
mounted. The only pdutil actions used are `datadisk` and `run`; no recovery,
firmware, erase, reset or process-kill commands exist here.

Logs checked are root and `System/Logs` `errorlog.txt`/`crashlog.txt`, and
`Data/<bundleID>/boot-trace.tsv`. Missing logs are explicitly recorded. Before and
after logs retain their hashes, so old files cannot be mistaken for fresh output.
`device-cycle-identity.json` in application Data identifies the candidate; the
actual installed PDX inventory is always authoritative. All phases, command
outputs and failures go to `phases.jsonl`; `outcome.json` never asserts boot
acceptance. A missing serial port after run, or a subsequent command timeout or
failure, stops the invocation with **device needs one A press**. The CLI does
not retry another candidate. Root must stop its outer device loop on this failure
and may continue Simulator-only work. No routine unlock/replug prompt is issued.

Application Data stays untouched except the explicitly named identity file.
`--clear-boot-trace` explicitly archives then removes only `boot-trace.tsv`.
Default behavior preserves saves and prior trace. For an explicitly requested
earned/seed save, pass `--earned-save /absolute/save-manifest.json`:

```json
{
  "directory": "/absolute/earned-slots",
  "files": [
    {"file": "adventure.a.json", "sha256": "<actual SHA256>"},
    {"file": "adventure.b.json", "sha256": "<actual SHA256>"}
  ]
}
```

Both imported hashes are checked before deployment and after each copy. Existing
slots are copied and hash-verified into the fresh evidence directory before either
is overwritten. Missing prior slots are recorded. No other Data is deleted or
replaced. Root must supply earned provenance; this tool checks transfer integrity,
not gameplay eligibility or Lua save-codec acceptance.

Simulator initial launches and restarts now check `lsof` for both `cu` and `tty`
Playdate aliases. A free attached device is permitted. Occupied ports fail within
a three-second ownership check and report exact lsof PID/command/path output;
inability to inspect ownership fails with its concrete error. No reader is killed.
Simulator runs and device cycles share
`/private/tmp/pokemon-playdate-device-<uid>.lock`, in addition to the unchanged
runtime/private locks. A root-owned serial reader must use that same device lock and **close its file
descriptor before** pdutil or data disk work. The cycle retains its owner locks
through collection, and releases them on exit before Simulator work. The
calibration and DeviceSmoke paths close their readers in a finally block.

The calibration path verified raw nonblocking serial transport without termios
changes. The private DeviceSmoke path uses that same open/read/write transport;
production still has no serial input module. No reader starts at import time.

Host-only validation:

```sh
python3 -m unittest tools.tests.test_device_cycle -v
python3 -m py_compile tools/device_cycle.py tools/harness/run.py tools/harness/restarting.py
```

## Calibration and USB keeper

The minimal calibration app has a separate admission path. Pass its exact
`--calibration-build` manifest and completed `--calibration-preflight` Simulator
record instead of a game gate. Only the four-file, calibration-ID bundle is
admitted; it cannot import earned saves and never counts as a passed game gate.
Use `--inspect-previous-game PokemonPoC.pdx` to collect the failed game's exact
installed inventory and logs before installing this separate app. Installed
`main.pdz` and `pdxinfo` are retained alongside the hashes.

The cycle reads tagged serial output and sends only `msg CAL1 ping`; it records
print/callback verification and always closes the port before pdutil or Simulator
work. Missing serial stops the attempt. `--leave-running` ejects the collected
data disk and promptly launches the verified app again to prevent launcher lock.
Only macOS `._*` and `.DS_Store` metadata are excluded from payload inventories;
every actual payload file is hash-verified.

## Exact DeviceSmoke admission and replay

`--simulator-smoke /absolute/run/simulator-smoke.json` is a separate admission
path. Production and calibration admission are unchanged. Only the exact retained
`DeviceSmoke.pdx`, with `dev/deviceSmoke.lua` as its sole dev source, is admitted.
The production source manifest must differ only in main/pdxinfo plus that one
module. Source and bundle inventories/hashes, bundle ID, compiler and SDK identity
must match the retained build. No rebuild or stripping occurs during the cycle.

A report must say `simulator-smoke-passed`, identify this exact build and the
persisted 16645684-byte pool, and retain run.json, runtime-data, responses.json
and earned-save.json. The cycle recomputes measurements/limits/failures with the
existing Simulator parser and recomputes observations from the raw reply archive.
It compares these with the report, rejects incomplete/error transcripts and
requires the same earned slot hashes. A failed report stays rejected before
ownership locks, datadisk, or any device write. Changing status or measurements
alone cannot turn failing raw evidence into admission. Timing-factor provenance
remains root's responsibility; the cycle never supplies a new factor or budget.
The current game proof still fails frame/slice/map estimates and is inadmissible.

`commands` must be a nonempty frozen list of at most 10000 whitelisted DS1 bodies;
`commands_sha256` is the shared `tree_hash(commands)`. Both must match run.json.
Only `state`, `press <button> 1..120`, `wait 1..300`, and
`release <button|all>` are permitted, using a/b/up/down/left/right. The cycle
first sends completed `state` probes until `ready: true`; the module's sequence-0
ready announcement alone is insufficient. It then sends the exact frozen route
once and a final state probe, using strictly increasing sequence IDs. A single
absolute `--run-seconds` deadline bounds readiness and the whole route. Choose
that duration to cover the measured route; it is not a performance budget.
A partial/blocked write, missing completion, wrong build/sequence or error stops
replay. No input is retransmitted. Serial prints are retained in serial.raw;
BOOTTRACE and DS1 records are parsed, with responses and serial trace retained
also on failure. The descriptor closes before collection invokes pdutil.

If USB remains present after a smoke failure, the cycle collects the exact
attempt before returning failure. If USB disappears after launch, the cycle
records **device needs one A press** and stops all hardware attempts immediately;
it does not retry, remount or wait for a routine unlock. Root must stop its outer
hardware loop too. There are no recovery, firmware, reset or erase actions.

Before replacing a PDX, `before` contains the actual installed binary inventory,
main.pdz/pdxinfo, full installed Data and candidate Data when their IDs differ.
`after` contains the exact new payload identity and full Data/logs/trace. This
preserves prior save slots and trace even when private build IDs change. Stale
frame metrics, external BootTrace identity or pending mailbox commands in the
candidate Data are refused, without deleting them. Save backup/import hash checks
and errorlog/crashlog comparisons remain mandatory. `--leave-running` relaunches
only after collection and crash-log checks; it never replays DS1 inputs.

`outcome.json` describes cycle/collection success, always with boot acceptance
false. `device-smoke.json` records actual hardware observations and, when present,
physical timing/heap measurements against the unchanged 6/9 MiB, 500 ms map/battle,
33 ms ordinary-frame and 1000 ms slice limits. Missing metrics/observations are
explicit failures; no Simulator estimates substitute for device measurements.
Root must inspect this report and the archived crash/error comparison before any
hardware acceptance. Native memory and between-sample peaks remain unmeasured.

### Unapplied Source metrics hook and exact root commands

The checked-in Source observer returns early on hardware, so it does not yet
provide hardware frame metrics. `tools/device/device-smoke-metrics.patch` is
**unapplied**: it lets the existing observer write active-segment timing/heap rows
on hardware while keeping all mailbox IO Simulator-only. It adds no command or
fixture. Root must review it, apply it, compile a fresh one-module build and obtain
a new Simulator smoke pass for that exact build. Its measurement overhead and
hardware behavior have not been accepted. Without it, collection is possible but
missing frame metrics prevent hardware acceptance. Source remains untouched in
this worker commit.

Root commands (replace the absolute evidence paths with the retained new build,
its genuine passed run, and its earned-save manifest):

```sh
# Review/apply only as root, before compiling a new candidate.
git apply --check tools/device/device-smoke-metrics.patch
git apply tools/device/device-smoke-metrics.patch

# Compile only. Then run the existing documented Simulator smoke as root.
python3 tools/device/build_smoke.py --output /absolute/evidence/new-smoke-build

# Local-only verification; this performs no Simulator/USB operations.
python3 tools/device_cycle.py --execute-root --validate-only \
  --build-stage /absolute/evidence/new-smoke-build \
  --pdx /absolute/evidence/new-smoke-build/DeviceSmoke.pdx \
  --simulator-smoke /absolute/evidence/new-passed-run/simulator-smoke.json \
  --earned-save /absolute/evidence/earned-save.json \
  --output /absolute/evidence/new-admission

# Only after the genuine exact-build Simulator pass. One bounded hardware attempt.
python3 tools/device_cycle.py --execute-root \
  --build-stage /absolute/evidence/new-smoke-build \
  --pdx /absolute/evidence/new-smoke-build/DeviceSmoke.pdx \
  --simulator-smoke /absolute/evidence/new-passed-run/simulator-smoke.json \
  --earned-save /absolute/evidence/earned-save.json \
  --inspect-previous-game PokemonPoC.pdx \
  --output /absolute/evidence/new-device-attempt --run-seconds 180 --leave-running
```

Use a new output directory for every command. The worker executed neither the
Simulator smoke nor the hardware command. The current failing proof is not an
input for the hardware command. No routine human setup is needed; launcher,
unlocked device and USB were already supplied by the user.
