# Tightened private idle soak — root handoff

Compile/host preparation only. No Simulator, USB, device runtime, deployment,
push, delegation or production Source edits occurred. Runtime safety and soak
acceptance remain pending. The original ac0d62d6 packet is superseded for design;
its retained artifacts have not been modified or relabeled.

Final retained stage:
`/Users/burbujamc/Developer/Pokemon-PlayDate-env/evidence/private-soak-tightened-20261029-05`.
Build ID `0d8daab29a7c45d5859fb4761ea78c42`; PDX SHA256
`9e990e5f7af1c613338cdabfdaf169828d964d85bd5c2ba32746f64b4fdf7d2d`.
Compiled from clean main `a790b79f07e0c785c14daa4837f79a1723409a6c`
(the main checkout, explicitly selected via --project), including Save byte reuse,
static loading cadence and production trace buffering. Both source revision and
main ref at preparation are recorded. Source has 65 maps, with no content overlay.
Earlier tightened stages 01–03 used older 9de2195f Source; 04 preceded the final
import-slice counter correction. All are superseded;
03 honestly records that main had advanced. No artifact is automatically current
when main advances again. Rebuild for later changes; never edit old build metadata.

`build.json` retains original and compiled source inventories, exact PDX payload,
compiler/SDK identity, earned slot hashes/provenance and tool hashes. `soak-tools/`
retains the builder, sampler, validators, Simulator driver, lifecycle hooks and
unapplied root patch. Verification refuses changed current or retained tools.
`host-validation.json` records decoded PDZ Lua modules: exactly dev/deviceSmoke
and dev/soakSampler. SDK 3.1.2 compile, Python syntax, four host rejection tests
(including eleven corruption cases), and root patch apply/syntax checks pass.
These tests exercise synthetic host evidence and reservation behavior only.

## Runtime contract

The private overlay calls the ORIGINAL BootTrace.checkGuard on every existing
ordinary-frame/loading check, before and after ordinary game work. Its 5 s slice
crash ceiling and 9 MiB heap ceiling remain unchanged. Count reads additionally
update aggregate observed heap/guard-cost counters; they are safety guards, not
snapshots or sample records. Scalar maximum active slice, segment count and
per-frame overlay cost counters retain no history and perform no frame IO.
Guard since-yield maxima also cover top-level imports before the update wrapper
is installed. Coroutine yield/resume accounting excludes suspension/display waiting while
including game work, guard work, minute sampling and its file/print IO.

Production automatic GC, ordinary step, loading steps, startup full collection
and generational-mode selection remain intact. Only DEVICE_TEST diagnostic full
collections/requestCollect are suppressed. There is no periodic full GC and no
6 MiB post-full-GC live-heap claim. Observed heap excludes native allocations and
is an observed maximum, not a proof of every allocation's peak.

After title arms, trace marks update scalar phase/sequence and retain guards;
they do not write trace rows. Minute snapshots/heap/JSON/file/serial samples stay
once per 60000 active ms, with no catch-up loop. Four explicit phase/completion
markers and the bounded DS1 ready/accepted/done audit are additional boundary IO.
The ready audit is persisted on both platforms so collection can check the same
real DS1 action. No mailbox or external input is accepted. Per-frame idle checks
use existing owners and scalar load/save/error counters, without snapshots.

The default schedule is 60 full active minutes at title, exactly the existing
`DS1 1 press a 1`, its normal release/done plus verified GameSaves load into
settled overworld, then 60 full active minutes there. It writes exactly 124 rows:
60 ordered minute rows per phase and four boundary rows. Movement, extra load,
save, error, missing rows or changed earned bytes fail. Epoch values are strings
to preserve integer precision through SDK JSON. Both active and wall durations
are checked. Hardware ignores Simulator profile files and collection rejects one.

Minute rows carry the preceding sampler duration; complete carries total/max/last.
The validator reconstructs that summary exactly, and reports scalar/guard totals.
Costs are instrumented SDK elapsed ms, not OS CPU or a baseline performance gain.
The final summary publication and timing-hook bookkeeping after the last clock
read are not measured. No overhead result has been measured yet.

## Root's exact short Simulator admission

`simulator.py` verifies only by default. Root may later use --execute-root on the
SAME compiled Soak.pdx: it imports exact retained earned bytes into fresh private
SDK Data and writes a Simulator-only profile once, before launch. Hardware always
uses 60+60. Short mode uses ONE FULL MINUTE per phase, keeping minute cadence;
it is about two minutes plus boot/Continue, with a 240 s host deadline.

The existing OwnerLock runtime/device locks, exact SDK executable, real 16 MB
MallocPoolSize preflight and USB ownership checks are reused. Only the owned PID
is terminated. All raw SDK Data, console, identity and file inventories are
retained. Validation checks exact source/PDX/tool/earned hashes, all phase and
console/file markers, DS1 accepted/done, verified load, errors, minute timing,
overhead summary and monotonic aggregate counters. Admission recomputes from raw
files and requires <=150 ms maximum active slice and <=9 MiB observed heap.
It never substitutes a performance gate or old DeviceSmoke report. Short mode
always records hardware_soak_accepted=false. It cannot satisfy 120-minute rows.
No Simulator process has been launched by this implementation agent.

Example ROOT-ONLY later command, not executed here:

```sh
python3 tools/device/soak/simulator.py \
  --build-stage /absolute/retained-stage \
  --sdk /Users/burbujamc/Developer/PlaydateSDK \
  --output /absolute/new-proof-output --execute-root
```

## Unapplied root-owned launch/collect patch

Review `device-cycle-root.patch`; it is intentionally UNAPPLIED. Shared
`tools/device_cycle.py` remains untouched. The patch adds only a soak gate branch,
launch/collect flags and narrow lifecycle calls, reusing existing validation,
backups, verified copies, ownership preflight, archive, disk/eject/run and locks.
It is not a framework and does not weaken the normal smoke/calibration gates.
Root must integrate these hooks before any hardware launch. Do not route this
packet through another existing gate or fabricate a short proof.

Under the existing runtime THEN device lock, every patched Cycle consults a
persistent reservation at `str(device_lock_path()) + '.soak.json'` BEFORE any
device command. Launch reserves a random attempt tied to exact manifest/build
and evidence directory, starting in `launching`. Fresh private device Data is
required. Normal existing backup/install/copy verification/import/eject/run follows.
After pdutil exits, launch confirms serial presence and no reader ownership,
records `running`, exact serial port and volume, then RETURNS out of both locks.
No host serial descriptor is ever opened by these soak hooks. The app writes its
samples independently; no two-hour owner process or reader is needed. A successful
launch means the run request completed, not that title or the soak passed.

The reservation, unlike flock, persists across process exit. It blocks all other
patched device Cycle candidates (including calibration), so releasing device and
Simulator locks cannot overwrite an active soak. Ordinary Simulator journeys do
not consult it and retain their usual USB preflight and locks. Root must route
ALL physical installs through this owner while reserved; independent legacy
make deploy/manual USB tools cannot be fenced by a Python ownership convention.

Collection takes both existing locks again, matches the exact launch attempt and
manifest, serial and volume, then records `collecting` BEFORE its single owned
Data Disk entry. It never reruns the app. It archives all Data/logs, compares the
entire installed PDX inventory, installed identity, earned bytes, unchanged
error/crash logs, and all 124 hardware rows. Only complete acceptance clears the
reservation. Missing USB, changed ownership/identity, command uncertainty, Lua
errors or incomplete rows keep it reserved and fail closed. No timeout expiry,
retry, reset, automatic cleanup, recovery or forced takeover exists. Root must
inspect failed/uncertain reservations before another hardware attempt. Hard
crash/disappeared USB retains the existing stop rule: device needs one A press;
stop the device queue. Healthy unattended operation needs no A/unlock/replug.

ROOT-ONLY after applying/reviewing the patch and obtaining the exact short proof:

```sh
python3 tools/device_cycle.py --execute-root \
  --pdx /absolute/retained-stage/Soak.pdx --build-stage /absolute/retained-stage \
  --soak-proof /absolute/proof/simulator-soak-proof.json --soak-launch \
  --earned-save /absolute/retained-stage/earned-save.json --output /absolute/new-launch

# Later, after 120 active minutes PLUS boot/Continue/time margin; do not collect early.
python3 tools/device_cycle.py --execute-root \
  --pdx /absolute/retained-stage/Soak.pdx --build-stage /absolute/retained-stage \
  --soak-proof /absolute/proof/simulator-soak-proof.json --soak-collect /absolute/new-launch \
  --earned-save /absolute/retained-stage/earned-save.json --output /absolute/new-collection
```

Host checks, safe to repeat without runtime:

```sh
python3 -m unittest tools.device.soak.test_evidence -v
python3 -m py_compile tools/device/soak/*.py
git apply --check tools/device/soak/device-cycle-root.patch
python3 tools/device/soak/simulator.py --build-stage /absolute/retained-stage
```

To rebuild, use prepare.py with --project selecting the intended main checkout,
--earned-save selecting the original accepted earned-input.json (or this stage's
verified earned-save.json), --sdk, and a fresh --output. Keep the output stage and
proof immutable. Runtime and hardware acceptance are entirely pending.
