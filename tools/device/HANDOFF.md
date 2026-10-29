# Private device serial smoke build

Base: `8840d96404d8a66ce59486db8b39a0eab36f65e0`. No shared game files changed.

`build_smoke.py` calls `tools.build.stage_production`, adds only
`Source/dev/deviceSmoke.lua`, and overlays the private entry point. It injects
`DEVICE_TEST_BUILD=true` and a random build ID before the first import, imports
the module after CoreLibs graphics, and wraps ordinary frames. A unique bundle ID
isolates device Data from production and other test builds. No saves are seeded,
copied, fabricated or installed by this builder. Use an earned save in this
private bundle's Data, through root's separately owned device tooling.

Compile only, to a new directory:

```sh
python3 tools/device/build_smoke.py --output /absolute/private/evidence/directory
```

Outputs: `DeviceSmoke.pdx`, retained `Source`, `build.log`, `build.json` with exact
source manifests, `private-main.patch`, and `root-hooks.patch`. The SDK defaults
to `~/Developer/PlaydateSDK`; `--sdk` and `--project` accept explicit paths.
All original production assets except `main.lua` and `pdxinfo` must remain equal.
No full Simulator harness is added. Existing output directories are refused.

## Root integration

Review `root-hooks.patch`: two added lines in main's normal update branch call
`DeviceSmoke.runFrame(game, updateGame)` only when `DEVICE_TEST_BUILD == true`.
The builder already applies this patch privately; it also accepts the exact hook
if root applies it to main. It fails on missing/ambiguous frame anchors. Keep the
test flag and module import exclusively in private staging. Production staging
strips dev; never add this import to shared main.

Root's new guarded GameBootstrap error path must preserve its BootTrace error
record, then call `DeviceSmoke.fail(message)` when the test flag is true and the
module is loaded. That function prints a terminal error, releases synthetic
input, and installs a persistent `playdate.update` error screen. The module loads
before `game/bootstrap` in private main. Startup exceptions before that import
remain outside its reach. The supplied main patch handles normal frame errors;
it does not add a bootstrap guard. Existing BootTrace/budget decisions stay with
root. Rebase the private overlay anchors if root changes the main update shape.

## Protocol DS1

SDK 3.1.2 `Inside Playdate.html`, sections 7.12 and 7.33, documents
`setAutoLockDisabled(true)` and `serialMessageReceived(message)` for the payload
of serial `msg`. No SDK input-injection API is assumed. Button queries use the
same four-function seam as `Source/dev/autopilot.lua`. Physical buttons are
ignored in this private test build. Auto lock is disabled only after the strict
test-mode guard. The production entry point has no serial callback.

Payloads, ASCII whitespace separated, at most 96 bytes:

```text
DS1 1 state
DS1 2 press a 1
DS1 3 wait 30
DS1 4 release all
```

- IDs: strictly increasing integers 1..16777215 per boot. Recognized envelopes
  consume their ID even on a command/busy error. Retries with the same ID return
  `stale-sequence`; they never replay input. Reset IDs only after a fresh boot.
- `state`: immediate read; permitted during boot, another command, or failure.
- `press <a|b|up|down|left|right> <1..120>`: one just-pressed frame, held for the
  requested total frames, then one release frame before completion.
- `release <button|all>`: release the named synthetic button, one ordinary frame.
- `wait <1..300>`: count completed ordinary frames. No time or state mutation.
- One input/wait command at a time. Another receives `busy`; reads remain allowed.
  Input before the first ordinary game frame receives `not-ready`.

Each response is one printed line: `DS1 ` followed by JSON containing
`build`, `seq`, `status`, `tick`, `value`. Filter other game/BootTrace output.
Input commands emit `accepted`, then exactly one `done` or `error`; `done` follows
the ordinary runtime frame and includes a snapshot. Reads emit only `done`.
Malformed/oversized envelopes use sequence 0. Startup announces sequence 0,
status `ready`, meaning the serial callback is installed, not gameplay ready.
An unassociated runtime/bootstrap failure also uses sequence 0. Stopped builds
accept only reads. No command resets a failed process.

State includes gameplay readiness/error, root/overworld phase, zone ID, player
tile/facing/motion, menu options/selection, dialogue page/text, title Continue
availability, battle phase/menus/text/HP, and the pause state's last save result.
`loaded`/`saved` count actual verified GameSaves observer boundaries; reads never
inspect/reload disk or capture a session. The existing observer is preserved.
All navigation, Continue, door transitions, battle selection and saving must use
these input commands and ordinary game owners. There are no fixture, teleport,
flags, money, inventory, RNG, rewards, battle mutation, eval or Lua commands.

## Validation and limits

Final compile: SDK 3.1.2, private build ID `26999521ac6a42a887d3ec165470167f`.
Evidence under `~/Developer/Pokemon-PlayDate-env/evidence/`:
`device-serial-compile-20261028-02` and `device-serial-production-20261028-01`.
Decoded PDZ records contain exactly `dev/deviceSmoke` in the test build and no
dev modules in production. Production Lua bytecode also excludes `DeviceSmoke`,
`DEVICE_TEST_BUILD`, and `serialMessageReceived`. Compressed main PDZ sizes:
672754 bytes test, 668877 production (3877 bytes added).

Existing protocol host checks: **54 passed**. Existing production-build checks:
**4 passed, 1 failed** because the frozen ordered-import fixture omits the
already-present `game/bootstrap`; base `8840d96` reproduces that exact mismatch.
No shared fixture or harness changes were made. Both builds compiled.

No actual serial, Simulator, device, recordings or deployment commands ran.
Protocol logic and input timing are compile-reviewed, not runtime-verified.
This proves neither hardware readiness nor title/Continue/door/battle/save
acceptance. Runtime errors after module load can stay live when root wires its
bootstrap guard. Hard stalls, watchdog termination, allocation failure and SDK
native crashes cannot be recovered by this module. Frame counts are not wall
time deadlines; BootTrace and budget/stall guards remain root-owned. No crank,
button chords, screenshots, save copying or automatic journey driver is supplied.

## Exact-bundle Simulator tooling at base 33f7783

The worker added `simulator_smoke.py` and extended `build_smoke.py` with exact
source, compiler and compiled-bundle identity. Root must apply the deliberately
unapplied `device-smoke-simulator.patch` to its owned dev module, then compile
once and reuse that exact PDX. The mailbox calls the existing DS1 serial callback
only in the Simulator; hardware performs no mailbox polling. The observer splits
active frame timing at coroutine suspension rather than timing the whole task.
[SIMULATOR-SMOKE.md](SIMULATOR-SMOKE.md) gives root commands, earned-slot manifest
format, measurements, failure semantics and limits. Runtime and hardware
acceptance are pending. The existing device-cycle prohibition on dev builds is
unchanged; root owns private hardware deployment integration.

The final focused host run passed 14 checks, including the new 10 smoke checks,
existing device-cycle checks and a real SDK 3.1.2 compile of the patched module
in a disposable Source fixture. The decoded private PDZ retained exactly
`dev/deviceSmoke`. `make test-harness` ran 54 checks with five restart-test
failures. A fresh archive of exact base `33f7783` reproduced all five failures:
its mocked `MailboxProcess` rejects preflight subprocess argument `text`.
No unrelated test or harness changes were made.

A retained compile of the unchanged root-owned module is available at
`~/Developer/Pokemon-PlayDate-env/evidence/device-smoke-worker-33f7783-compile-20261028-01`.
Its build ID is `9ddb257cb78f41a4afed459df6cc64ac`, Source fingerprint is
`ee0c36f5adf9d35bf0022d4822d083a877381c43fb322ed75f46a43bd3d70a3c`,
and bundle hash is
`e5bb2301fad49641b4cfcd8e22427db732365c4d8ca65c7152a3fbbabf6ac72c`.
Verify-only mode accepted those exact retained bytes. This serial-only artifact
has no Simulator transport until root applies the patch and compiles a fresh
bundle; it is not runtime evidence. No Simulator, device or USB execution ran.
