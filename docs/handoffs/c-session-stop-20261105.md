# Handover — C session stopped 2026-11-05

This session was stopped by the user after the branch was pushed. Do not
continue the campaign from this note unless the user starts it again. The
isolated C line is not accepted, not merged, and not finished.

## Where the work is

- Repository: `https://github.com/MCMike0399/Pokemon-PlayDate.git`
- Branch: `pi/c-actor-validation-fix`
- Pushed tip: `84ac642ed80bdce1a9f60ff380c1ee45241c3abc`
- Remote range now on origin: `28b60105..84ac642e` (11 commits)
- Worktree used for every edit: `/Users/burbujamc/Developer/Pokemon-PlayDate-env/worktrees/c-actor-validation-fix`
- The Cursor/workspace checkout `/Users/burbujamc/Developer/Pokemon-PlayDate` is **main**, not C. At the start of the session it was `cd48c222a2571c84b293615c3c10becbbf6a9db1`. Do not implement C there.
- Do not use `/Users/burbujamc/Developer/Pokemon-PlayDate-env/worktrees/c-host-preparation-1464d1a2`. That worktree is the obsolete `03c1bae4` line.
- Identity that must stay true: HEAD is a descendant of `28b6010501ac924b5e778c59f80263756cac19da` and of `b530f2ff`. It is not a restart from `03c1bae4`.

Environment that was used:

- `source ~/Developer/Pokemon-PlayDate-env/env.sh`
- Playdate SDK 3.1.2 at `~/Developer/PlaydateSDK`
- Simulator SHA256 `ebaeca5c65f3d613f06c8a3d701e90c01f292f13fc66f24a680e4357c5b447cf`
- Pinned pokered `af519899719f0754965776faac0e836a3b906e6d`
- One runtime owner. Lock file `/private/tmp/pokemon-playdate-simulator-501.lock` is `flock`-based. A stale PID file does not block. Do not start a second Simulator.

## What this session changed in Git

Source that **remains** (everything else that was tried was reverted before commit):

1. `Source/dev/diagnostics.lua` exports `HarnessDiagnostics._codecObservation` next to the existing `_actorVisibilityMigration`. `codecObservation` is unchanged. A literal Save/Continue match still skips a second decode. Any other payload is canonicalized from the selected-slot bytes via `SessionCodec.validate` / `decode`, not from a later live `game.session`.
2. `Source/dev/saffronGuardContracts.lua` adds `saffron-unequal-boundary-canonicalizes-selected-slot-bytes`. It encodes a Silph elevator session, sets `EVENT_RESCUED_MR_FUJI` on the live session afterward, and checks that an unequal trusted boundary is canonicalized from the slot bytes. Later play must not become the receipt, and canonicalization must not write the live session.
3. `Source/dev/vermilionJourney.json` updates only the `dev/diagnostics.lua` owner pin to `ac8b1c783ff39324d5cdd3804dcdd24947b6c51fa3578e14ef88bfda1b403349`.
4. `docs/validation/progress.md` records the measurements below. Read the top of that file first. Older dated sections are history.

No gameplay, save-format, battle, map, art, guard, pool, or `SaveBuildPolicy` change was kept.

Commits on top of `28b60105`, oldest first:

| Commit | What it records |
| --- | --- |
| `bd23b2f0` | Selected-slot canonicalization proved in the saffron contract. This is the only kept behavior change. |
| `4a532560` | Silph-entry baseline 468.1 / 467.4 MiB, rejected slim trace, rejected preallocation, cabin import result. |
| `ac6a8266` | Rejected `table.create` preallocation plus dropping the second save-payload decode. |
| `6412ad91` | Cabin pilot 04 stopped at the 1 GiB host ceiling. |
| `17d4c94e` | Silph-entry copy profile. Counters were removed. |
| `bdefc4de` | Rejected per-frame scalar copy cut. |
| `9e6c36e9` | Rejected shared imagetable. |
| `56271128` | Rejected static loading-card redraw skip. |
| `3be1d26c` | Rejected static-load present cut. |
| `daaa141a` | Rejected Save index hold (first peak). |
| `84ac642e` | Second index-hold peak. Both runs missed. |

The user asked for this branch to be pushed. It was pushed to `origin/pi/c-actor-validation-fix`. Main was not updated. C was not merged.

## Product state

Main, last verified at `cd48c222`, has 149 accepted maps through checkpoint B: "Simulator-accepted and hardware-safe; device latency targets not yet met." The last full main host proof is 1,171 passing tests. That does not certify C.

C has 171 maps and remains unaccepted. Preserve these already-landed fixes. Do not re-implement them:

- Fuji visibility: object 14 only before Fuji rescue and before Silph is cleared. Object 15 only after rescue and before clear.
- Actor migration: every saved actor is structurally and value-validated before a bounded visibility drop. Only a removal proven hidden by a fresh `SourceActors.hidden` survives. Survivors are value-identical. The envelope is `worldMotion.actors`. The list is `worldMotion.actors.actors`. A flat list is not a valid migration. `roundtrip_equal` is literal equality, separate from `migrated_equal` / `migration`.
- One guarded Silph elevator confirm/cancel.
- Persisted-floor cabin projection. Floor 1 is `SILPH_STORY_LIFT_V1_1=true` with floors 2–11 false.
- `b530f2ff` fixed the nested actor-envelope receipt and canonicalization from the selected-slot bytes.
- `28b60105` refreshed the stale Vermilion diagnostics owner pin. The pin moved again in `bd23b2f0` because `diagnostics.lua` changed. Regenerate only that pin if `diagnostics.lua` changes again.

Native `contracts saffron-guards` was run twice after those follow-ups, on the bytes that became `bd23b2f0`. Both SDK 3.1.2 runs were 111/111, 0 failed. The older 110-pass report does not cover these bytes. Evidence, outside Git:

`~/Developer/Pokemon-PlayDate-env/evidence/c-actor-validation-native-saffron-guards-20261105-06`

Command shape:

```bash
python3 tools/harness/run.py --timeout 180 --ready-timeout 90 \
  --output <new directory that must not already exist> \
  "contracts saffron-guards"
```

Inherited full-host failures were not rerun. "Zero new failures" is not a green suite. A new fingerprint does not promote old evidence.

## Allocation baseline

Declared phase: the exact Silph-entry scenario. Continue from the admitted elevator Save, 30 steps, 80 actions, 12 transitions, stop on the existing action bound. A non-zero exit whose error is `parcel journey exceeded semantic action bound` and whose last zone is `pokered:SILPH_CO_1F`, stage `done`, player about `(8, 11)` down, is the probe's expected stop. It is not a crash. A Pallet `pre_oak` ending is not a valid measurement even if the error string matches.

Two consecutive baseline runs, source bytes that match everything after `bd23b2f0` except `docs/validation/progress.md`:

- 468.064 MiB
- 467.392 MiB

Lua heap on that path stays about 7.1–8.7 MiB. The 10% bar for adoption is **both** later runs at or under **421.26 MiB**, same end state, validators still executed. One run is not enough to adopt. A miss is reverted and stays rejected.

Historical numbers that are not this baseline: Continue near 318 MiB, an older Silph-entry probe near 547 MiB, and an unreproduced ~900 MB boot figure. Boot means input-ready title, not first artwork.

Measurement command, after `source ~/Developer/Pokemon-PlayDate-env/env.sh`, from the C worktree:

```bash
export FOOTPRINT_LOG=<evidence path>-footprint.json
python3 <sample_footprint.py> -- \
  python3 tools/harness/run.py \
  --scenario <silph-entry-scenario.json> \
  --output <evidence directory that must not already exist> \
  --timeout 90 --ready-timeout 120
```

`sample_footprint.py` samples `proc_pid_rusage` phys_footprint about every 0.25–0.3 s. Do not set `MallocStackLogging` on an adoption measurement. It inflates the footprint. Output directories for the history helper must be under `/Users/...`, not `/var` or `/private/var` (see cabin pilot below).

The scenario JSON used here was a scratch file and may be gone when the session scratch is deleted. Reconstruct it exactly:

```json
{
  "initial_save": {
    "milestone": "5.5b",
    "resume": {
      "path": "/Users/burbujamc/Developer/Pokemon-PlayDate-env/evidence/checkpoint-c-saffron-fuji-pilot-20261104-12/01-midgame--restart-55c-squirtle/processes/0001/partial-save.json",
      "sha256": "2204733359f2332c9dd844742cd4d15f457692b880df268e4802ccb15917931b"
    },
    "starter": "squirtle"
  },
  "processes": [
    {
      "journey": {
        "content_scope": "critical",
        "evolution_policy": "accept",
        "max_actions": 80,
        "max_blackouts": 1,
        "max_encounters": 256,
        "max_steps": 30,
        "max_transitions": 12,
        "name": "midgame-natural",
        "packet": "5.5c",
        "starter": "squirtle"
      }
    },
    {
      "journey": {
        "content_scope": "critical",
        "evolution_policy": "accept",
        "max_actions": 120000,
        "max_blackouts": 1,
        "max_encounters": 256,
        "max_steps": 20000,
        "max_transitions": 512,
        "name": "midgame-continue",
        "packet": "5.5c",
        "starter": "squirtle"
      },
      "restart": true
    }
  ]
}
```

The second process never starts on this probe. The run stops in the first process on the action bound.

## Rejected allocation experiments

Do not restore these. Each was reverted with `git checkout` of the source. Only the ledger commit remains.

| Experiment | Result vs 468.064 MiB | Evidence directory under `~/Developer/Pokemon-PlayDate-env/evidence/` |
| --- | --- | --- |
| Slim journey trace, full command snapshots kept | 482.5 and 483.2 MiB, worse | scratch `alloc/after-silph-entry-*.json` from the session that measured it; ledger `4a532560` |
| `table.create` preallocation of `Party._primitive` / `SaveStore.copy`, plus dropping the second payload `json.decode` in `_decodeUncached` | 422.548 and 425.392 MiB, 9.7% and 9.1% | session scratch `alloc/prealloc-silph-*.json` |
| Per-frame scalar reads (`introStage`, `fieldTravelMode`, `fieldTravelStrength`, `Zone:footTile`) | First run invalid: 247.5 MiB, still in Pallet `pre_oak` at `(7,1)` because `elseif travel.mode` was left after `travel` was renamed to `mode`. Fixed run: 459.6 MiB, 1.8% | `c-silph-copycut-1-20261105` (invalid), `c-silph-copycut-2-20261105` (valid miss) |
| One imagetable per registry, drop the previous view, `collectgarbage("collect")` before the next palette | 482.9 MiB, about 3% higher | `c-silph-imagetable-1-20261105` |
| Skip a repeat draw of the default loading card when its label is unchanged. Door fade still drawn every slice | 466.2 MiB, 0.4% | `c-silph-loadingskip-1-20261105` |
| After the first static loading card, `yieldIfDue` collects but does not present. Door fade unchanged. Save yields after capture dropped from about 14 to 0. Save CPU about 113 ms | 476.0 MiB, about 2% higher | `c-silph-noyield-1-20261105` |
| Hold each immutable content-field index for one `SourceMaps._withRuntimeDefinitions` load. Checks unchanged | 461.4 and 477.9 MiB | `c-silph-indexhold-1-20261105`, `c-silph-indexhold-2-20261105` |

Also still rejected from earlier work, not remeasured this session: packed terrain, atlas enablement, door tier.

Older rejected ideas that must not be retried as if they were new: another history-clearing infrastructure project, the exhaustive door census, and relaunching cabin pilot 04 unchanged.

## What the profiles actually showed

### Malloc history (diagnostic only)

Taken with stack logging, so the footprint is inflated and must not be compared to the 468.1 MiB baseline. File, if the session scratch still exists: `.../implementer/alloc/malloc-history-late.txt` (about 259 MB). An earlier history at process start is useless (footprint about 8 MB).

At a mid-walk sample the dominant **game** allocator is `addAlloc` ← `pd_realloc` ← `luaM_malloc_` / `luaM_realloc_`. Largest Lua sites:

- `luaH_resize` via `luaH_newkey` / `luaV_finishset`: on the order of 143–162 MiB and millions of calls
- `luaH_new`: on the order of 65 MiB and about 1.7M calls
- `luaS_newlstr`: about 32.5 MiB
- `luaS_createlngstrobj`: about 8.3 MiB
- C `decode_value` / `lua_createtable`: only about 8.8 MiB

Stacks do not carry Lua source lines. `debug.sethook` is not callable in Playdate Lua (`field 'sethook' is not callable`). A file-scope hook also blew the ready timeout. Do not retry hooks. Cheap counters or `BootTrace.mark` are the tools that work. Do not count during boot or ready will time out.

Startup wx/SDL/mmap regions are the boot floor (on the order of 100 MiB plus), not the Silph delta.

### vmmap across the climb

`~/Developer/Pokemon-PlayDate-env/evidence/c-silph-vmmap-20261105` has `summary-360.txt` and `summary-450.txt`. `vmmap` itself is slow, so the "360" capture was already at physical footprint 431.8 MiB and the "450" capture was 452.5 MiB, 1.8 s later. The growth in that slice is almost all **Malloc Small** dirty: 389.4 MiB → 408.6 MiB. Malloc Large moved 16.8 → 18.2 MiB. CG Image stayed 1392K. IOSurface stayed 4880K. The climb is small host allocations, not tile bitmaps or IOSurface.

Lua `collectgarbage("count")` stays near 8 MiB while phys_footprint climbs and does not give the pages back. The malloc zone high water is the measurement. Freeing Lua objects does not by itself lower the peak.

### Copy profile

`~/Developer/Pokemon-PlayDate-env/evidence/c-silph-alloc-profile-20261105`, counters removed afterward.

Whole Silph-entry run: 99 diagnostic snapshots, 24,359 primitive tables, 154,412 keys, 675 Pokemon projections, 472 zone deep-copies, 3 map descriptors, 4 save payload decodes plus 4 mutation copies, tile-grid cache 0 loads / 0 hits. Source maps already set `options.compactTerrain = true`. Imported FACILITY and LOBBY tiles are not in `TileRegistry` `ATLAS_TILESETS`, so Silph and the elevator software-render.

`Party._primitive` is the shared deep copy (`GameSession._copy` calls it). The 3.7M `luaH_newkey` calls in the stack-logged history are about 20× the 154k primitive keys, so most hash inserts are other Lua assignments, not `_primitive`. `debug.sethook` cannot attribute them here.

Top-level primitive samples during the walk were dominated by `sourceEvents.lua` `settledWorld` → `getIntro()`, plus `Story.get` from `Story.check`, `player.lua` `movementImage` → `fieldTravelData`, and `flags()` inside snapshots. Cutting those per-frame copies only moved the peak 8.5 MiB.

### Save-phase split

The admitted elevator Save's publish, with Lua at 7.3–8.6 MiB, splits about:

- Slot inspect: +41 MiB, longest wall section, several yields
- New envelope: +15 MiB
- Readback: +26 MiB

Yields are about every 30 ms because `GameBootstrap` uses an 8 ms simulator slice (`sliceBudget` and `staticSliceBudget` are both 8 on the simulator, 24 / 120 on device) and `coroutine.yield` waits for the next frame. A paused split that busy-waited 450 ms between those three phases is at `c-silph-save-split-20261105`. The pauses themselves were flat. The rises were in the work sections.

A counter wrapped only around `SaveStore:save` (not the earlier `captureSession`) saw:

- Inspect: 1,003 primitive tables, 71 top-level primitive calls, 6 `json.decode`, 116,800 decode bytes, 6 `json.decodeFile`
- Envelope cumulative: 1,576 tables, 108 calls, 8 decodes, 157,033 bytes, 11 files
- Readback cumulative: 2,722 tables, 182 calls, still 8 decodes / 157,033 bytes, 21 files

So readback does not decode the payload string again. It does run `_validateRecord`, which copies and calls `SessionCodec.validate` again. The 21 decoded files were only:

- `data/contentCache/package-{1..5}-sprites-sprites.json`, four times each (about 2.5–3.6 KB each)
- `data/sourceMapCache/runtime-SilphCoElevator.json` once (4,836 bytes)

Sum of file bytes times decode count is about 65 KB. Holding those indexes for the load did not move the 468 MiB peak by 10%. The native jump is not those files and not the 2,722 session-copy tables.

`SaveStore.copy` is a separate function from `Party._primitive`. The counter above did not include it. `_inspect` copies a valid record after decode ("a validator may retain its argument"). `_validateRecord` copies `record.data` and validates again. Do not remove those copies casually. The comment in `saveStore.lua` says the copy is required.

Cabin save payload itself is small: about 18.7 KB, 162 tables / 1,027 keys. Party 50 tables, storage 38, quest flags 109 keys, trainer flags 130 keys, world 28 tables / 101 keys. The world zones in the elevator slot are `oaks_lab` (2 tiles), `pokered:ROCKET_HIDEOUT_B1F` (2), `pokered:VERMILION_DOCK` (16). Location `pokered:SILPH_CO_ELEVATOR` `(7, 1, right)`. After the in-probe Save, slot B in the evidence runs is Silph 1F `(8, 1, left)`. That in-probe Save is not a resume input.

`SaveBuildPolicy.ownerExports()` returns false whenever `HarnessBuild` exists, so harness Saves take the deep public path: inspect both slots, envelope encode/decode/validate, readback `_validateRecord`. Do not flip that, the 1 GiB stop, the 16 MiB pool (`MallocPoolSize=16645684`), or validation policy without an explicit user decision. The 1 GiB stop lives only in `JourneyHistory.check` when the history helper is enabled (`owned Simulator exceeds 1 GiB host footprint`). Without the helper, `run.py` will not stop at 1 GiB.

### Footprint shape of a valid Silph-entry run

Wall-clock samples from the 468.064 MiB baseline, rounded:

- About 6–8 s: climb through boot to roughly 280 MiB
- About 8.9 s: Continue, about 312–327 MiB
- About 11.5 s: a small dip (342 → 312 on that run) then a slow climb
- About 15.4 s: about 337 MiB, just before the Save
- 15.4 → 16.9 s: about 337 → 449 MiB during Save, the save dialog, screenshots, and `observe saved`
- 16.9 → 20.5 s: about 449 → 468 MiB while walking south on Silph 1F from `(8, 1)` to `(8, 11)`

The Save confirm is the `press a` that leaves the pause menu's YES/NO and pushes "RED saved the game!". On the profiled run that command ended near game time 12.1 s. Commands immediately after are `await dialog.ready` (this builds a **full** `HarnessDiagnostics.snapshot` every frame until the line is revealed), two `shot` commands, another `press a`, and `observe saved`. `observe saved` calls `codecObservation`, which encodes the live session once when the slot already matches.

`Harness.afterFrame` writes a full snapshot every 30 frames and on command completion. `finish()` also calls `collectgarbage("collect")` on every journey request when `journey_profile` is set. There are about 53 requests in this probe. Do not drop that snapshot cadence. `docs/validation/harness.md` requires full snapshots and trace rows on command completion and every 30 frames.

`debug.sethook` cannot be used. `Playdate` Lua also has no useful allocation hook that this session found.

## Cabin frontier

Only this resume input is valid:

- `docs/handoffs/resume-55c-squirtle-silph-cabin-20261104.json`
- Marker SHA256 `2204733359f2332c9dd844742cd4d15f457692b880df268e4802ccb15917931b`
- Slots `6a20c09e07b1a8e0f1bb40a0d1532aef077c961b4af91b757103a78dbca556b8` and `00f2d64bb333b19225bacec688d657bc9e2385ac175c881b8673b78ffcce927a`
- Stopped producer: `failed-exited`, return code -9
- Eight-step accepted-B ancestry
- Location `SILPH_CO_ELEVATOR` `(7, 1, right)`, persisted floor 1
- Completed step only `saffron-guard-entry`

The strict importer accepts that marker and rejects the newer Silph 1F marker SHA256 `80617002fe871e1c1a98c52b312e41cb5baa563c2c5c0f87ca20bdc1e0a40eb3` because later Saves overwrote its archived slots. Do not pick a checkpoint because it is newer. Do not rewrite frozen proof. Importer: `tools.harness.restarting.import_chain_save` / `import_midgame_partial`.

Cabin pilots this session:

1. Scratch output under `/var` never played. Python `Path.resolve()` records `/private/var/.../Harness.pdx`. The Swift helper compares `URL.resolvingSymlinksInPath().path`, which is `/var/...`. The helper refused: `not the pinned SDK journey build/process`. SDK, simulator, and data dir matched. Do not weaken the helper. Put journey output under `/Users/.../evidence/...`.
2. `evidence/c-cabin-pilot-20261105-03`. Pin passed. Startup clear succeeded. Reached Silph 1F `(8, 1)`. The next pre-Save clear waited about 2.4 s and refused `one Malloc Log window required` (zero AX windows). Not a 1 GiB result. The Malloc Log window existed after startup inspect and then vanished. Do not "fix" this by skipping the helper.
3. `evidence/c-cabin-pilot-20261105-04`. This is the real result. Outcome `ok: false`, error `owned Simulator exceeds 1 GiB host footprint`, session `4ecdf2f6cddd41078a40f1c218cd0254`, game revision of that run `ac6a8266` (later commits are ledger only). Ten clears succeeded, including 351→140 MiB and 708→418 MiB. Later clears stopped releasing and left a floor near 378–449 MiB. Last clear left about 378 MiB. 638 command results. Player reached Silph 5F, won Scientist `pokered:SILPH_CO_5F:objects:3` (source-trainer-0, payout 1300, player_hp 134). Next battle at `(9, 16)` facing down, tick 3601, crossed 1 GiB before another clear. `resumed_steps` still only `saffron-guard-entry`. The Continue process did not start. **Do not relaunch this pilot unchanged.**

History helper notes, if the scratch binary is gone and must be rebuilt: `tools/harness/malloc_history_clear.swift`. Second clear operations are `['clear','inspect']` and require the Malloc Log window to stay open (`waitForMallocLogWindow` 2 s, `logs.count == 1`). The helper binary used for the successful pin had SHA256 `46c2bd90cd883ea3af9d7e2928f6a8dc6ae9cb545d8774a3668b3c43dfb2fa8f` in the session scratch. Rebuild from the Swift source rather than copying a scratch binary.

Critical 5.5c from the cabin save, not started or not finished:

- `route_c_guard` (`saffron-guard-entry`) is already complete on the admitted save
- `route_c_silph`: Card Key, warp pads, rival, Giovanni, Lapras
- `route_c_sabrina`
- `route_c_dojo`
- `route_c_fly`

`optional_c_copycat` is optional scope in the journey packet. The product goal still names Copycat. It is not in the short Silph-entry scenario. Each starter must start from its own earned Save. `journey-summary.json` must show completion by zone, item, flag, and battle outcome. A 1 GiB stop, a fixture substituted for a natural run, or a restart that does not load the earned slot is a failure.

The cabin pilot must not be resumed until an allocation change clears the 10% bar on two runs. No such change exists. The user then stopped the session, so the pilot was not relaunched.

## Guards and ownership that were not changed

- 31 GiB runtime admission / 30 GiB disk reserve
- 16 MiB Simulator pool
- 1 GiB host hard stop
- 736 MiB Clear trigger
- 64 Clears / 131 helper calls per generation
- 6 / 8 / 9 MiB Lua limits, slice deadlines, ownership fences
- `SaveBuildPolicy` mode stays `"production"`. Owner exports stay off when `HarnessBuild` exists.

Device: no `/dev/cu.usbmodemPD*` on this Macintosh during the session. Last assignment was DiveMac. Hardware and latency stay open. Simulator timing is not a device pass. Boot means input-ready title. Device targets, still unmet: boot to title ≤10 s with no slice >1 s; Continue ≤4 s; Save ≤2 s; door ≤1.5 s; battle start ≤1 s; cave walking p95 ≤50 ms; map load about ≤1.5 s with the fade; typical walking ≥25 fps; no new crash log.

C merges only after earned-route, actual-process restart, native visual, physical-hardware, memory, and latency gates pass. None of those gates passed this session.

## Unfinished

- No allocation candidate cleared 10%. The 1 GiB repeated-request/Save ceiling is unchanged.
- Cabin journeys and the Continue process restart were not finished. Silph 5F was the furthest honest play (pilot 04), then the host stop.
- Three-starter C journeys were not started. Copycat was not started.
- Visual, hardware, memory, and latency gates are open. No device was connected.
- C is not merged.
- Late Kanto, League, credits, Continue-at-home, Cerulean Cave, one-shot Mewtwo, and League rematch records were not started.
- Full C host suite inherited failures were not rerun and were not relabeled.
- `docs/validation/progress.md` still says "Nothing is pushed without a user request." That is the rule. The user did request the push of `84ac642e`.

## If the user restarts the campaign

1. Work only in the C worktree above. `git fetch` and confirm HEAD is `84ac642e` or a descendant. Do not restart from `03c1bae4` or from main.
2. Read `docs/validation/progress.md` from the top, then this file, then `docs/plans/full-game-goal.md`. The ledger outranks older handovers.
3. Do not redo the saffron contract, the Fuji/elevator/cabin fixes, or any rejected experiment in the table above.
4. Next technical gap is still native allocation on the Silph-entry / repeated Save path. vmmap says the dirty growth is Malloc Small. Counted session copies and sprite-index re-decodes are too small to explain the Save jump. A new candidate has to cut something else, keep every validator, and beat 421.26 MiB on two valid Silph-entry runs before anyone relaunches cabin pilot 04.
5. Do not change `SaveBuildPolicy`, the 1 GiB stop, or the 16 MiB pool unless the user explicitly decides that.
6. Journey output goes under `/Users/.../evidence/...`. One Simulator. Re-detect `/dev/cu.usbmodemPD*` before any hardware claim.
7. Commit locally. Push only when the user asks. Do not merge C on Simulator evidence alone.

## Known traps

- `installSession` rolls back on rebuild failure. If `previous.player` is nil, the player can remain at save coordinates while session/zone revert to a fresh Pallet `pre_oak` session. The invalid 247.5 MiB copy-cut run looked like that. Disk `adventure.a.json` was still the elevator save. Boot trace showed the elevator map built and Continue ended, but no `overworld.actors.begin`, because `Player:updateSprite` threw on a nil travel table between `overworld.view.end` and `overworld.actors.begin`.
- `getCurrentZoneKey()` falls back to `zoneList[1]` (pallet_town) when `currentZone` is not in the registry.
- `WorldView:render` and contracts draw the full tilemap. A future viewport tilemap must not break that. This session did not change it. vmmap says the climb is not CG Image / IOSurface, so a tilemap-size cut is a weak bet.
- `worldContracts.lua` calls `TileFactory.generateAll()` twice for different registries and compares pixels, not object identity. A cache must stay per registry. The shared-imagetable attempt already failed.
- `terrainAt` must keep returning a fresh detached copy. Tests mutate it.
- Playdate `debug.sethook` is nil. Do not leave instrumentation in `Source/dev/harness.lua`. The 30-frame snapshot contract stays.
- Helper path check is string equality after each side's own symlink resolution. `/var` and `/private/var` differ.
- Non-zero harness exit on the Silph-entry action bound is success for the allocation probe only when the last snapshot is Silph 1F, stage done.
