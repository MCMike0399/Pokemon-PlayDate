# Full-game execution ledger

Updated 2026-11-06 UTC. Follow [the goal](../plans/full-game-goal.md).
**Main: 149/222 Simulator-route maps. Device-playable acceptance: 0/222.**
The full Blue campaign, credits and postgame remain unfinished. C's 171-map
preparation is isolated and unaccepted. Nothing is pushed without a user request.
This continuation is `cursor/c-linux-continuation-4fcf`, branched from
`4b93ff24` (`origin/pi/c-actor-validation-fix`). It is not pushed. The handover is
[c-session-stop-20261105.md](../handoffs/c-session-stop-20261105.md).

## Third Squirtle cabin still stopped at 1 GiB — 2026-11-06

One new cabin ran the admitted 5.5c journey on the publication-reuse build
`4a9d1ce3`. It is not a relaunch of `linux-cabin-pilot-20261106-01` or
`linux-cabin-pilot-20261106-02`. The 16 MB pool, the 1 GiB Linux VmHWM stop,
and the other guards stayed on. No preload.

It published both Silph 1F saves, the Saffron City save, and the fourth save
inside the Saffron Pokémon Center. Cabin 02 had died while that fourth save's
dialog was opening, at `(3, 7)` up, tick 1006. This run finished the save.
The guard then stopped the owned Simulator on the next press, still in the
Center: `owned Simulator exceeds 1 GiB Linux VmHWM`. The peak sample was
**1034.7 MiB** (1059540 KiB), session `5e25a0b8f65843d1b2545bb5d4ec59a7`,
one process, 175 samples, 43.97s. The last snapshot is
`pokered:SAFFRON_POKECENTER`, player `(3, 3)` up, tick 1095, pause closed,
last save `published`. `resumed_steps` was still only `saffron-guard-entry`.
The Continue process did not start. Card Key was still absent. Captures were
not finalized. The capped four-save probe had ended at this tile under the
guard (961.320 MiB) because its action bound fired first. The uncapped cabin
took the next command and crossed. This pilot was not launched again. This
is not a Mac phys_footprint result and not hardware acceptance. C progression
has not started. Evidence, outside Git: `linux-cabin-pilot-20261106-03`.

## A verified public readback is reused on the next Save — 2026-11-06

The epoch cache only filled when a byte string was decoded. A public
readback accepts the promoted file and does not decode it, so the next Save
still decoded that newest slot in full. `SaveStore:retainVerifiedPublications()`
is opt-in. The public game store sets it after
`session-public-dependencies-v1`. After the promoted bytes match the
envelope, that exact string and its detached record are remembered. Owner
export never sets the flag. New payloads still checksum, decode the payload
twice, validate, and read back. `SaveBuildPolicy` is unchanged.

The cabin path, extended through the fourth published save and stopped on
the action bound, no preload, pool `MallocPoolSize=16645684`, one process,
`pokered:SAFFRON_POKECENTER`, stage `done`, player `(3, 3)` up, last save
`published`:

| Run | VmHWM | Session |
| --- | --- | --- |
| epoch only | 1031308 KiB (1007.137 MiB) | `b1861dc3d1a04cf49ac727e134717816` |
| publication reuse | 984392 KiB (961.320 MiB) | `0557a2ea05684bb6b0d672c5b39a7aea` |

The cut is 46916 KiB (45.8 MiB) on that path. 984392 KiB is 64184 KiB under
the 1 GiB stop. That finishes the save cabin 02 died inside. It does not
leave another Silph door. The official one-save probe does not inspect the
new file again. Both runs still stop on `parcel journey exceeded semantic
action bound` at `pokered:SILPH_CO_1F`, stage `done`, player `(8, 11)` down,
one process:

| Run | VmHWM | Session |
| --- | --- | --- |
| retain 1 | 484564 KiB (473.207 MiB) | `1043e7cfe3324746aea06d6127005c97` |
| retain 2 | 483396 KiB (472.066 MiB) | `d8b7d75d101e4316a0e051b71804a597` |

The worse run is under the 520.070 MiB gate and 1652 KiB above the epoch
worse run (482912 KiB). Public GameSaves save/Continue passed. Persistence
passed 45; the same bounded-payload case still reports `not enough memory`.
Owner call-count tests passed. This is not Mac phys_footprint and not
hardware acceptance. Evidence, outside Git: `linux-silph-two-save-before`,
`linux-silph-two-save-after`, `linux-silph-entry-retain-1`,
`linux-silph-entry-retain-2`.

## Public slot proof reused on the next Save — 2026-11-06

Cabin 02's VmHWM did not spike and release. Across 166 samples it never fell.
Two Silph 1F saves left the process at 598.9 MiB. The 1 GiB sample was later,
when a fourth save opened inside the Saffron Center, on top of those saves,
the Saffron door, the Saffron save, and the steps between them. One save's
peak is not the guard.

The public game store decoded and normalized a slot again whenever Save
inspected it, even when Continue had just accepted those exact bytes.
`SessionCodec.gameSaveStore` now sets
`session-public-dependencies-v1` on that store only. The first read of a byte
string still checksums, decodes the payload twice, and validates. A later
inspect of those same bytes reuses the detached record. Owner export stays
off. New payloads still take the public envelope and both readbacks.
`SaveBuildPolicy` is unchanged.

Matched Silph-entry runs, no preload, pool `MallocPoolSize=16645684`, one
process, exit 1, `parcel journey exceeded semantic action bound`,
`pokered:SILPH_CO_1F`, stage `done`, player `(8, 11)` down:

| Run | VmHWM | Session |
| --- | --- | --- |
| epoch 1 | 482912 KiB (471.594 MiB) | `bda530d1d83843a4a84d855abdf2ae08` |
| epoch 2 | 481560 KiB (470.273 MiB) | `54a64c0496304f4385bcdca6a4103d90` |

The worse run is under the 520.070 MiB gate and 20044 KiB (19.6 MiB) under
the shared-scene worse run (502956 KiB). That is the whole-probe difference,
not a per-save measurement of the cabin. Subtracting it once from cabin 02's
1049356 KiB still leaves about 1005 MiB, over the 1 GiB stop. Doors and steps
are untouched. No new cabin was launched. This is not Mac phys_footprint and
not hardware acceptance. C has not started. Evidence, outside Git:
`linux-silph-entry-epoch-1`, `linux-silph-entry-epoch-2`.

## Second Squirtle cabin still stopped at 1 GiB — 2026-11-06

After the shared Silph scene plan, one new cabin ran the same admitted 5.5c
journey. It is not a relaunch of `linux-cabin-pilot-20261106-01`. The 16 MB
pool, the 1 GiB Linux VmHWM stop, and the other guards stayed on. No preload.

It continued from the Silph elevator, saved twice on `pokered:SILPH_CO_1F`,
and published a third save on Saffron City. The last save was `published`.
The guard then stopped the owned Simulator inside the Saffron Pokémon Center:
`owned Simulator exceeds 1 GiB Linux VmHWM`. The peak sample was **1024.8 MiB**
(1049356 KiB), session `ac1ce9bc975f4b8e848b6afd8555b228`, one process. The
last snapshot is `pokered:SAFFRON_POKECENTER`, player `(3, 7)` up, tick 1006,
with a dialog opening and not yet ready. `resumed_steps` was still only
`saffron-guard-entry`. The Continue process did not start. No battle was
recorded. Card Key was still absent.

Pilot 01 had died during that third save, at Saffron City `(4, 22)` left,
tick 810. This run finished the save and reached the Center, then crossed the
same stop. The per-save and per-door climbs are still large enough that the
full journey cannot stay under 1 GiB. This pilot was not launched again.
This is not a Mac phys_footprint result and not hardware acceptance. C
progression has not started. Evidence, outside Git:
`linux-cabin-pilot-20261106-02`.

## Shared Silph scene plans cleared the Linux gate again — 2026-11-06

`SilphStory.scenes()` decoded the pinned scene plan once, then deep-copied
every node on each read. Save validation and map entry ask for that plan once
per actor, including actors that only need to know the plan does not mention
them. The decoded plan is now the shared read source. SaveStore copies, the
second payload decode, validators, readbacks, and SaveBuildPolicy are unchanged.

With the 16 MB pool and no preload, both runs stopped on `parcel journey
exceeded semantic action bound` at `pokered:SILPH_CO_1F`, stage `done`, player
`(8, 11)` down, one process. VmHWM was **491.168 MiB** (502956 KiB) and
**491.086 MiB** (502872 KiB). The worse run is 15.0 percent under the higher
Linux baseline of 577.855 MiB, and both are under the 520.070 MiB bar. It is
also 24.4 MiB under the previous adopted worse run of 515.531 MiB. This is not
a Mac phys_footprint result and not hardware acceptance. Evidence, outside
Git: `linux-silph-entry-scenes-1` and `linux-silph-entry-scenes-2`.

## Save-window records cleared the Linux gate — 2026-11-06

Session normalize rebuilds the item catalog and every Pokémon's six-stat
records while it validates a save. Inventory and the session dependency
projection still check every definition on each construction, and they reuse
one record table per unchanged source identity. A changed or removed
definition rebuilds that projection. Item storage still deep-copies the
catalog once per source, then reuses the detached copy after validation.
Individual stat normalization and calculation build compiler-sized literals.
The defensive primitive copy reuses one cycle set for a root walk and
allocates a fresh set when a copy is already in progress. SaveStore's own
copies, the second payload decode, validators, readbacks, and SaveBuildPolicy
are unchanged.

Reusing only the item-catalog records, without the stat literals or the shared
cycle set, reached the same end state at **555.688 MiB** and missed the bar.
That narrower edit is not what this tree keeps. The combined cut, with the
16 MB pool and no preload, stopped on `parcel journey exceeded semantic action
bound` at `pokered:SILPH_CO_1F`, stage `done`, player `(8, 11)` down, one
process. VmHWM was **515.180 MiB** and **515.531 MiB**. Both are under the
520.070 MiB bar, which is 10 percent under the higher Linux baseline of
577.855 MiB. This is not a Mac phys_footprint result and not hardware
acceptance. Evidence, outside Git: `linux-silph-entry-catalog-1`,
`linux-silph-entry-save-cut-1`, and `linux-silph-entry-save-cut-2`.

One Squirtle cabin pilot then ran the admitted 5.5c journey from that same
save, with the 1 GiB Linux VmHWM stop left on. It continued from the Silph
elevator, saved twice on `pokered:SILPH_CO_1F`, and the guard stopped it at
100 commands: Saffron City, pause menu, player `(4, 22)` left, tick 810.
`resumed_steps` was still only `saffron-guard-entry`. No battle was recorded.
The Continue process did not start. The pilot was not launched again.
Evidence: `linux-cabin-pilot-20261106-01`.

## Linux continuation assessment — 2026-11-06

Clean Linux x86_64 workspace, no prior `env.sh`, SDK, earned saves, or Mac
helper. Official Playdate SDK 3.1.2 is installed at `~/Developer/PlaydateSDK`
(`pdc` reports 3.1.2; `bin/PlaydateSimulator` is the Linux ELF). Pinned pokered
`af519899719f0754965776faac0e836a3b906e6d` checks out. The pinned B2W2 cache
`tools/verify_moves/cache/b2w2/2bf639e5572812a67d2b94903fdcb9d095f5aeb2` verifies.
One interpreter: Python 3.12.3 in `~/Developer/pd-venv` with Pillow 12.0.0.
Disk free is about 245 GiB, above the 31 GiB admission. No
`/dev/cu.usbmodemPD*` node. Swift and `/usr/lib/libproc.dylib` are absent, so
the Mac history helper and `proc_pid_rusage` footprint cannot run. The 1 GiB
stop stays inside `JourneyHistory` and was not replaced or disabled.

The Linux Simulator GUI does start. Its first-run dialog was dismissed, then
Playdate > Malloc Pool > 16 MB was selected in the UI. After quit, the binary
wrote `MallocPoolSize=16645684` to
`~/.config/Playdate Simulator/Playdate Simulator.ini`. That is the file this
platform writes. The runner now uses `bin/PlaydateSimulator` when the macOS app
binary is absent, and reads that ini off Darwin. Darwin still uses the app
bundle and `~/Library/Preferences`. A missing or different pool value still
fails closed. `make test-harness` protocol tests passed 57/57, and the new
platform checks passed 4/4. Commit `ddd8ffc7`. Production `pdc` also compiled
`PokemonPoC.pdx`.

A fresh harness session on that binary reached the title menu (NEW GAME /
OPTIONS), stage `pre_oak`, Lua heap about 10.9 MiB, ready at about 29 s wall.
Evidence, outside Git:
`~/Developer/Pokemon-PlayDate-env/evidence/linux-title-smoke-20261106-01`.
ALSA reported no playback device. This is not a Silph-entry measurement, not a
device result, and not C acceptance.

The strict importer does not reach the cabin marker. It stops on the missing
accepted-B producer
`~/Developer/Pokemon-PlayDate-env/evidence/m55b-earned-fourteenth-resumed-20261030-01/03-midgame--restart-55b-squirtle/run.json`.
The cabin marker `22047333…`, slots `6a20c09e…` / `00f2d64b…`, and chain
`evidence/chain/5.5b/squirtle` are also absent. No save was fabricated. No
allocation edit was made. Rejected experiments stay rejected. The Mac
Silph-entry gate (both runs ≤ 421.26 MiB) was not run and is not claimed from
Linux RSS. The cabin pilot was not relaunched.

Host discovery on this machine: **1161 tests, 7 failures, 62 errors, 1 skip**
(the Darwin footprint proof). Log:
`~/Developer/Pokemon-PlayDate-env/evidence/linux-host-suite-20261106-01/host-suite.log`.
Failures are the inherited C-versus-B inventory/coverage mismatch, including a
stale coverage Source fingerprint that this session did not regenerate. Errors
are missing external reference trees (ability oracle, field-move pins, NPC-trade
manifest) and `libproc`. This is not a green suite and does not requalify C.

## Trace append handle missed the Linux gate — 2026-11-06

`trace.jsonl` was opened, written, and closed on every command completion and
every 30 journey frames (96 rows, 2.9 MB, prefix-sum about 132 MB if each open
kept the bytes). Holding one append handle for the session, and flushing every
row, never published `ready.json`: `file:flush` on that handle did not return.
Publishing ready before the first append and not flushing per row did finish
the probe. Same end state (`pokered:SILPH_CO_1F`, stage `done`, player
`(8, 11)` down, action-bound error, one process) at **576.305 MiB** VmHWM.
The tail of the trace was 93 rows rather than 96, because the handle was still
open when the simulator was stopped. The change was reverted. It is not an
adoption. Evidence: `linux-silph-entry-trace-handle-3`.

The climb is live glibc heap, not WebKit and not freed-but-retained pages.
`mallinfo2` at the peak reported `uordblks` about 506 MB, `fordblks` about
3 MB, and `hblkhd` about 28 MB. WebKit's mapping stayed about 10.7 MB. Lua
`collectgarbage` never passed **8.84 MiB**. A size histogram of still-live
mallocs was about 4.99 million 24-byte objects (114 MB) and 6.60 million
40-byte objects (252 MB), plus the 16 MB pool and one buffer that grew to
about 27 MB. Sampled backtraces of the surviving 16–128 byte objects are
`strdup` and a 40-byte node inside `PlaydateSimulator`, appending
`%s %s:%i` frames (`nSl`) to a list that only grows. Removing the saved
sampler and memory window rects from the simulator ini, keeping
`MallocPoolSize=16645684`, still peaked at **575.750 MiB**. The cabin pilot
was not relaunched.

## Silph elevator surround — 2026-11-06

The live Silph Co. elevator (`pokered:SILPH_CO_ELEVATOR`, imported 13×4 cells,
128 px tall) sat in the lower middle of the 400×240 screen with a solid white
band above it. Pokered's map is 2×2 blocks with border block `$0f`.
`LoadTileBlockMap` fills the overworld buffer with that border before placing
the room, and the scroll origin stays non-negative, so the surround is black
and the room is in the upper portion of the view. This game's authored
interiors pad with void to at least 13×8 because the camera assumed the map
was at least screen-sized. The elevator's vertical padding is 0. `Camera`
applied `map - screen` after the `>= 0` clamp, and that limit is −112 px, so
the room was bottom-aligned. Pixels the tilemap did not cover stayed the
default white sprite background. The catalog viewport already used
`math.max(0, math.min(map - screen, goal))`, which pins a short map to the
origin. `follow` and `snapTo` now do the same. While the live map is narrower
or shorter than the screen, the sprite background is black and the full
display is marked dirty once on entry; screen-sized maps still use white so
transparent roof wedges are unchanged. Elevator menus, persisted floor, and
tile art are untouched. The static catalog clear color is unchanged.
`test_visual*.py` passed 21/21. Protected-source pin mismatches on
`tilefactory.lua`, `spritefactory.lua`, `player.lua`, `zone.lua`, and
`maps.lua` are the existing C-tree drift; those files were not edited.
A fresh guarded probe captured the elevator with the room in rows 0–127 and
solid black from row 128 through 239, then still stopped on the action bound
at `pokered:SILPH_CO_1F` `(8, 11)` down. That run's VmHWM was 585.238 MiB and
is not an allocation adoption. Evidence:
`linux-silph-elevator-surround-1`.

## Path-only await pair missed the Linux gate — 2026-11-06

The second Silph-entry peek run, same probe and end state as the baselines,
peaked at **572.207 MiB** VmHWM (`linux-silph-entry-peek-2`). With peek-1 at
571.262 MiB, both are above the 520.070 MiB bar (about 1.0 and 1.1 percent
under 577.855). The peek was reverted and is not in the tree. The cabin pilot
was not relaunched.

## Earned bundle and Linux Silph-entry baseline — 2026-11-06

`check_bundle.py` on the supplied bundle: artifact hashes PASS, 188 evidence
files. `--project` against a clean full-history checkout at
`4b93ff24d8fec06021be1f72c5950d6d7ea7c5bd`: three imports succeed, 188 mapped
dependencies, no SDK launch. Squirtle slots are `6a20c09e…` and `00f2d64b…`
with completed step only `saffron-guard-entry`. Bulbasaur and Charmander import
with empty completed steps. Creating `/Users/burbujamc/...` was permission
denied, so the files were not hydrated there and no frozen hash was rewritten.
`POKEMON_EVIDENCE_MIRROR` redirects only that namespace for reads.

The short Silph-entry probe (30 steps, 80 actions, 12 transitions, cabin
marker) stops on `parcel journey exceeded semantic action bound` at
`pokered:SILPH_CO_1F`, stage `done`, player `(8, 11)` down. Linux VmHWM, not
Mac phys_footprint: **577.332 MiB** and **577.855 MiB**. The 10 percent bar for
the higher baseline is **520.070 MiB**. The same path-only await peek, measured
on this probe, reached the same end state at 571.262 MiB, 1.14 percent under.
Reverted. The 1 GiB Linux VmHWM stop did not trip. The cabin pilot was not
relaunched. Evidence:
`linux-silph-entry-baseline-1`, `linux-silph-entry-baseline-2`, and
`linux-silph-entry-peek-1` under
`~/Developer/Pokemon-PlayDate-env/evidence/`.

## Await snapshot peek rejected — 2026-11-06

`await` and `assert` built a full diagnostic snapshot on every waiting frame.
A path-only peek kept command-completion and periodic snapshots unchanged.
This is not the Mac Silph-entry probe and does not use phys_footprint. The
labelled Linux scenario skipped the intro, saved from Red's room, and stopped
on a ready save dialog: `reds_house_2f`, stage `done`, player `(5, 3)` up,
save published. Journey-profile VmHWM baselines were 241.664 MiB and
242.465 MiB. The 10 percent bar for that higher baseline is 218.219 MiB.
The peek run reached the same end state at 240.105 MiB, 0.97 percent under.
Reverted. A non-journey build that snapshots every frame climbed to 4.08 GiB
and is not an adoption measurement. The cabin pilot was not relaunched.
Evidence outside Git:
`linux-save-await-journey-baseline-1`, `linux-save-await-journey-baseline-2`,
and `linux-save-await-journey-peek-1` under
`~/Developer/Pokemon-PlayDate-env/evidence/`.

## Save index hold rejected — 2026-11-05

The Save path decodes the same five sprite indexes on each validator pass.
A counter on one Silph-entry Save saw 2,722 primitive tables and 157 KB of
JSON, so the native jump is not those session copies. Holding each immutable
index for the load, and still reading it through the original check, reached
Silph 1F at (8, 11), stage done, and stopped on the action bound on both
runs. The Save published. Peaks were 461.4 MiB and 477.9 MiB against the
468.1 MiB baseline. Neither clears 10 percent. Reverted. The cabin pilot was
not relaunched. `SaveBuildPolicy` is unchanged. Evidence:
`~/Developer/Pokemon-PlayDate-env/evidence/c-silph-indexhold-1-20261105`
and `c-silph-indexhold-2-20261105`.

## Static-load presents rejected — 2026-11-05

A paused split of the admitted elevator Save put about 41 MiB on slot
inspect, 15 MiB on the new envelope, and 26 MiB on readback. Lua stayed near
8 MiB. Those sections were yielding a full simulator frame about every 30 ms.
The candidate still drew the first static card and still ran the door fade,
then collected without presenting again. The Save itself dropped from roughly
14 yields to zero and finished in 113 ms. The same 30-step run reached Silph
1F at (8, 11), stage done, and stopped on the action bound. Peak footprint
was 476.0 MiB against the 468.1 MiB baseline, about 2 percent higher.
Reverted. The cabin pilot was not relaunched. Evidence:
`~/Developer/Pokemon-PlayDate-env/evidence/c-silph-noyield-1-20261105`.
The split trace is outside Git at
`~/Developer/Pokemon-PlayDate-env/evidence/c-silph-save-split-20261105`.

## Static loading redraw rejected — 2026-11-05

Malloc history on the Silph-entry path still shows the live game cost in Lua
table growth (`luaH_resize` / `luaH_new` through `pd_realloc`). A phase trace
of the admitted elevator Save put the native jump on the Save yields: Lua
stayed at 7.3–8.6 MiB while inspect, envelope, and readback each yielded.
The candidate kept the door-fade callback on every slice and skipped only a
repeat of the default loading card when its label had not changed. The same
30-step run reached Silph 1F at (8, 11), stage done, and stopped on the
action bound. Peak footprint was 466.2 MiB against the 468.1 MiB baseline,
0.4 percent. Reverted. The cabin pilot was not relaunched. Evidence:
`~/Developer/Pokemon-PlayDate-env/evidence/c-silph-loadingskip-1-20261105`.

## Shared imagetable rejected — 2026-11-05

Malloc samples on this path still center on Lua table allocation
(`luaH_resize` / `luaH_new` through `pd_realloc`), not on the rejected
per-frame intro and travel copies. The new candidate kept one imagetable per
tile registry, dropped the previous view's table, and collected before
allocating the next palette so two full palettes would not be live together.
The same 30-step Silph-entry run reached Silph 1F at (8, 11), stage done, and
stopped on the action bound. Peak footprint was 482.9 MiB against the 468.1
MiB baseline, about 3 percent higher. Reverted. The cabin pilot was not
relaunched. Evidence:
`~/Developer/Pokemon-PlayDate-env/evidence/c-silph-imagetable-1-20261105`.

## Per-frame copy cut rejected — 2026-11-05

The Silph-entry trace showed most top-level primitive copies were `getIntro()`
inside every settled-world hook and `fieldTravelData()` on sprite updates.
Movement also deep-copied terrain only to read `foot_tile`. Those reads became
scalar accessors. A surf-image check still named the removed travel table, so
the first measurement never left Pallet Town (247.5 MiB, not comparable). After
that fix, the same 30-step path reached Silph 1F at (8, 11), stage done, and
stopped on the existing action bound. Peak footprint was 459.6 MiB against the
468.1 MiB baseline, 1.8 percent. Under the 10 percent bar, so the accessors
were reverted. The cabin pilot was not relaunched. Evidence:
`~/Developer/Pokemon-PlayDate-env/evidence/c-silph-copycut-2-20261105`.

## Silph-entry copy profile — 2026-11-05

A bounded Silph-entry run of the admitted elevator Save (30 steps, 80 actions,
stop on the existing action bound at Silph 1F) counted the copies that survive
a malloc-log clear. Counters were removed afterward; they are not a behavior
change. The run is outside Git at
`~/Developer/Pokemon-PlayDate-env/evidence/c-silph-alloc-profile-20261105`.

Ninety-nine diagnostic snapshots copied 24,359 primitive tables and 154,412
keys. Pokemon projections ran 675 times. Zone deep-copy ran 472 times, map
descriptors 3 times, and the save payload was decoded 4 times plus 4 mutation
copies. The tile-grid cache was not used (0 loads). Source maps already share
compact terrain, so per-cell terrain duplication is not this path. The earlier
`table.create` preallocation of these primitive copies remains rejected at
9.7/9.1 percent. No new candidate cleared the 10 percent bar, and the unchanged
cabin pilot was not relaunched.

## Cabin pilot stopped at 1 GiB — 2026-11-05

The admitted Squirtle elevator Save (marker
`2204733359f2332c9dd844742cd4d15f457692b880df268e4802ccb15917931b`) was resumed
with the existing guarded runner and history helper. A launch whose output path
lived under `/var` never played: Python records the bundle as `/private/var/...`
and the helper compares Swift's `/var/...` path, so it refused the journey pin.
The same bytes under `/Users/.../evidence/c-cabin-pilot-20261105-03` passed
that pin, cleared once at startup, and reached Silph 1F at (8, 1). The next
pre-Save clear refused because the Malloc Log window was gone. That run is not
a 1 GiB result.

`evidence/c-cabin-pilot-20261105-04` kept the window open. Ten clears
succeeded, including drops from 351 MiB to 140 MiB and from 708 MiB to 418
MiB. Later clears stopped releasing memory and left a floor near 378 MiB. The
player saved through Saffron and Silph 1F, entered Silph 5F, and won the
Scientist at `SILPH_CO_5F:objects:3` (payout 1,300). The following 5F battle
at (9, 16) crossed the 1 GiB host stop before another clear:
`owned Simulator exceeds 1 GiB host footprint`. Six hundred thirty-eight
command results were recorded. The only completed step is still
`saffron-guard-entry`. Card Key, the rival, Giovanni, Lapras, Sabrina, the
Dojo, and Fly did not finish, and the Continue process did not start. This
pilot is not relaunched unchanged. `SaveBuildPolicy`, the 1 GiB stop, and the
16 MiB pool are unchanged. No Playdate port is present on Macintosh. C is not
merged.

## Silph-entry allocation and cabin import — 2026-11-05

The same bounded Silph-entry probe (cabin marker, 30 steps, 80 actions, stop
on the existing action bound at `SILPH_CO_ELEVATOR` then `SILPH_CO_1F`) peaked
at 468.1 MiB and 467.4 MiB on two consecutive runs. Lua heap stayed near 7.5
MiB. A journey-trace slim that still kept full command-result snapshots reached
the same floor and raised the peak to 482.5 MiB and 483.2 MiB. Preallocating
deep copies with `table.create` and dropping the second save-payload JSON
decode reached the same floor at 422.5 MiB and 425.4 MiB, 9.7% and 9.1% under
the 468.1 MiB baseline. Both are under the 10% bar, so both were reverted and
stay rejected with packed terrain, atlas enablement and door tier. The 1 GiB repeated-request/Save ceiling is unchanged.
`SaveBuildPolicy` still disables owner exports whenever `HarnessBuild` exists;
changing that, the guard or the pool needs an explicit decision. The later
cabin pilot is recorded above; it is not a reason to rerun this allocation miss.

The strict importer accepts the pilot12 cabin marker
`2204733359f2332c9dd844742cd4d15f457692b880df268e4802ccb15917931b`, slots
`6a20c09e…` and `00f2d64b…`, the stopped producer (failed-exited, code -9),
eight-step accepted-B ancestry, location `SILPH_CO_ELEVATOR` (7, 1, right),
persisted floor 1, and completed step only `saffron-guard-entry`. It rejects
the newer Silph 1F marker `80617002…` because later Saves overwrote the archived
slots. No Playdate port is present on Macintosh (`/dev/cu.usbmodemPD*` absent).
C is not merged. Earned journeys, restarts, visuals, hardware and latency stay
open.

## Selected-slot receipt rechecked — 2026-11-05

Native `contracts saffron-guards` was run twice on the isolated C tip after
`b530f2ff` and the Vermilion pin `28b60105`. The suite now also canonicalizes
an unequal trusted boundary from the selected-slot bytes, so later play cannot
become that receipt. Both runs passed 111/111 with zero failures, including
all eleven elevator floors, both cabin exits, persisted-floor projection and
unknown-floor rollback. The earlier 110-pass report does not cover these
bytes. C is still unaccepted: allocation, earned journeys, restarts, visuals,
hardware and latency remain open. Both runs are outside Git at
`~/Developer/Pokemon-PlayDate-env/evidence/c-actor-validation-native-saffron-guards-20261105-06`.
Inherited full-host failures were not relabeled.

## C actor-validation correction — 2026-11-05

The reviewed Macintosh C migration had three defects: hidden saved actor
records skipped structural/value validation, the session retention boundary
could accept arbitrary actor deletion, and the diagnostic could report unequal
actor payloads as equal. They are corrected on the isolated C branch
`pi/c-actor-validation-fix` (correction `6fe0357c`, merged reviewed main
`8306f79b` as `2f5bba22`). Every known saved actor is now fully validated before
a bounded visibility drop; only a removal independently proven hidden by a fresh
source descriptor/flags survives, with survivors value-identical; literal
equality and the proven migration are separate, and raw selected-slot payload/
sequence stay distinct from the canonical state. The preserved Fuji visibility
and elevator fixes are unchanged.

Review of that correction found two receipt holes. The host checker read
`worldMotion.actors` as the actor list, but SessionCodec stores the
envelope there and the list at `worldMotion.actors.actors`, so every
genuine migration was rejected. It now compares that envelope and rejects
a flat list, a zone or revision change, a survivor edit, a bad count, and
an extra field. The dev Save/Continue observation also treated a later
`game.session` encode as the canonical form of the selected slot. A
literal match still skips the second decode. Any other payload is
canonicalized from those bytes, so later play cannot become the receipt.
Host receipt tests cover the nested migration. Native `saffron-guards`
was not re-run. C remains unaccepted and is not merged to main.

That receipt change left the Vermilion owner projection pinning the previous
`dev/diagnostics.lua` bytes, so `validate_projection` rejected this tree. The
projection was regenerated. Only that source pin changed, to
`37d98254f8f991958cf9aec7b03568bb37fe6710781477ede6b98a5195500a30`. Historical
validation manifests stay as recorded. This refresh is not C acceptance, and
native `saffron-guards` was not re-run for it.

Fresh actual SDK 3.1.2 export refreshed both dependency pin maps (only
`domain/gameSession.lua` changed); production compiles. Native
`contracts saffron-guards` passes 110/110, now covering malformed hidden records,
custom-validator deletion/addition/mutation, stale flags, all eleven elevator
floors, both exits and unknown-floor rollback. The post-merge host suite runs
1,157 tests with 40 pre-existing C projection/pin/environment failures and **0
new** versus unmodified `03c1bae4`; regenerating the Cerulean and Vermilion
projections fixed two of the former 42. Main remains B149 and C remains
unaccepted.

Two genuine cabin pilots from the frozen pilot12 marker still trip the unchanged
1 GiB host ceiling during repeated route requests/Saves; both failures are
retained. Bounded probes put Continue near 318 MiB and Silph 1F entry near
547 MiB, so the earlier ~900 MB boot figure is not reproduced. Lua heap stays
near 8 MiB while native `Malloc Small` grows. A trusted-boundary observation
change removed a repeated SaveStore deep validation at the dev boundary and
reduced the measured Saffron-walk peak 701→611 MiB (12.8%) with the owner deep
path unchanged. The harness still selects the deep Save path because
`SaveBuildPolicy` disables owner exports whenever `HarnessBuild` exists; changing
that, the guard or the pool needs an explicit user decision. No more pilot
retries were made. The failed pilot's Silph 1F marker is preserved but rejected
by the strict importer because later transit saves overwrote its archived slots.
[Exact correction evidence and scope](../../tools/integration/checkpoint-c/actor-validation-correction-20261105.json).

## Macintosh work reviewed and safe subset integrated — 2026-11-04

The user explicitly requested reviewing the Macintosh session and pushing what
is safe to main. The fetched C branch is `origin/pi/checkpoint-c-host-preparation`
at `03c1bae4`, six commits beyond the previous C tip `1464d1a2`. At review it was
44 commits ahead of the merge-base; main `ff598ced` was 9 ahead. C171 is not accepted
and is not merged wholesale. Source-backed Fuji visibility, elevator confirmation
and cabin projection are useful progress, but both independent reviews found
validation defects in the actor compatibility migration and diagnostic equality
exception. Those remain isolated and require correction/native qualification.
[Separate Standards and Spec findings](../reviews/macintosh-c-20261104.md).

Main component `598f64d2` ports only bounded named-contract dispatch and suite-aware
catalog/field evidence classification. Default aggregate order/common cases remain;
unknown suite rejection occurs before RNG-mutating tests. Production B runtime,
data, art, save owners and qualification pins are unchanged; main stays 149 maps.
The helper/acknowledgement hunk is not independently portable because main has no
matching JourneyHistory owner, so it remains on C. The coverage review preserves
all 1,512 rows/facets/proof hashes and prior snapshot history; only current Source
identification advances for the two development Lua changes.

Fresh validation: **1,171/1,171 full host tests pass**, no errors/skips; 32 targeted
checks and 4 coverage checks pass. A guarded thin API probe passes 21 selected and
22 aggregate cases (the 20 original common cases execute twice plus dispatch
sentinels), including unknown-suite/RNG preservation. This is not a full harness
or C journey pass. The ordinary full-contract B probe exceeded 1 GiB and remains
a retained failure; it is a different profile from the B/C journey comparison.
[Exact component scope](main-named-contracts-20261104.json),
[final host result](main-named-contracts-host-20261104.json).

The latest genuine C frontier is pilot12's stopped Silph elevator Save at (7,1,right),
floor 1, marker 22047333..., only saffron-guard-entry complete. It is on Macintosh;
the new prompt/scenario binds those exact slots and ancestry instead of older
record16. No DiveMac Playdate USB port was present at review; hardware work needs
the device reconnected. Source/host work continues independently. No guard, pool,
trust fence or acceptance threshold changes.
[Current continuation prompt](../handoffs/continuation-after-macintosh-review-20261104.md).

The earlier takeover details below remain historical and are superseded above
where the branch tip, frontier, local setup or next action has advanced.

## Macintosh takeover — 2026-11-04

The user requested pushing current accepted main and a complete handover to
Macintosh. Accepted game/validation tip `75eca5d9` and the reviewed cold-archive
allowlist commit `96b53554` were fast-forward pushed. This handover adds no game
Source changes and does not adopt C or the selected-slot/Telekinesis candidates.
[Takeover prompt and exact frontier](../handoffs/macintosh-20261104.md).

Main remains B149 accepted with the existing label. Isolated C is at `1464d1a2`.
Its last Squirtle attempt completed a genuine Saffron guard-entry Save, then
failed at the unchanged64-Clear cap while routing around a source-confirmed
Saffron actor-visibility bug. No complete C journey or new hardware result is
claimed. Reviewer steer8's30-door production-GC route remains unexecuted.
The November4 process audit found no live SDK/journey/device/archive operation.

Both requested superseded Brock failure roots are now archived, fully rehearsed
and locally released; exact receipts and restoration references are in the
handover. Their logical total is8.46GiB, not an isolated free-space delta.
Actual DiveMac free space at the audit was about95GiB. No current earned input
or positive acceptance proof was discarded. Macintosh receives a private all-ref
bundle and dirty-work snapshots separately; raw external evidence stays on
DiveMac/Pi until exact-path hydration is required. The outgoing agent starts no
new campaign during the ownership transfer. All prior scope/latency limits below
continue to apply.

The user then requested an independent handover challenge. One Sol/medium advisor
found two P2 portability gaps and one P3 persistence clarification, no standards
findings. Root supplied the missing pinned reference/cache/environment setup,
an exact188-file frozen seed-dependency closure, and a new scenario bound to
latest C record16. An isolated recovery drill on Macintosh recovers all selected
branch tips and passes the unchanged strict importer for all three starters,
including Squirtle's exact Saffron slots. Goal/task state is explicitly not
transferred; the prompt supplies a fresh local goal instruction. No gameplay
Source changed or runtime started. Runtime/desktop/hardware and C acceptance
remain separate pending gates.
[Review findings, resolutions and actual drill](../handoffs/macintosh-readiness-review-20261104.json).

## What a player can do

Checkpoint B is accepted and merged: Tower/Fuji/Flute, both Snorlax routes,
Bicycle/Cycling Road, rods/fishing, Fuchsia/Koga, Safari, Surf and Strength.
**Simulator-accepted and hardware-safe; device latency targets not yet met.**
All three genuine A→B routes and two-process restarts passed in their retained
source scope. Later fixes have targeted proofs, not a new whole-route replay.
[Acceptance and original hashes](midgame-b-acceptance-20261102.json).

B game code merged as `af9a8938`. Current main adds the reviewed catalogue-query
memory fix `9ba63d68`; historical B acceptance and package retain their original
build identities. The production code matches the measured memory candidate;
only a generated development-fixture dependency hash changed afterward.
Substitute is integrated as`056fe922`:299native executions, six rendering cases,
a native component motion clip and physicalgame smoke pass in their stated scope.
[Substitute proof and limits](substitute-component-adoption-20261102.json).
The six canonical B slot byte strings are unchanged. [Chain identities](chain-saves.json).

The B merge passed 1,152 host tests and 57 protocol tests. After the memory merge,
1,152 host tests ran: 1,149 passed and three stale metadata checks failed. The
projection changed only its reviewed terrain-owner hash; all 64 targeted
metadata checks then passed. Protocol checks pass 57/57 and literal production
`make compile` passes with SDK 3.1.2. No second full-suite run is claimed.

Current main after Save inspection reuse and metadata reconciliation passes the
full **1,169/1,169 host suite**. The earlier six failures were projection digests,
accepted-code preservation pins and the current Source coverage snapshot; their
failed run is retained. Semantic projections, protected assets and all original
coverage proof hashes remain unchanged. No new campaign or hardware acceptance
is inferred. [Exact host result](main-host-after-save-20261102.json).

B acceptance took 73.075 elapsed hours from the first 149-map packet: about
13.466 added maps/day, including tooling, latency work and waits.

## Visual and package evidence

The native 400×240 silent showcase is 86.161 seconds at original speed, with
four explicit cuts: walking, a complete three-Pokémon Fisherman victory,
Snorlax's wake/encounter/removal, and Koga's dialogue/intro/first turn. Koga is
an excerpt, not a new full-victory claim. Root inspected native/decoded samples
and source sequences; all 1,420 decoded frames and timestamps are preserved.
[Showcase](b149-showcase-final-20261102.json).

The historical accepted package contains a production PDX, three earned save
pairs, clip, one-line instructions and known limits. It predates the memory fix
and was not physically timed as an exact normal-production package. User play
feedback is unavailable now and does not block work. The current production PDX
is at `evidence/main-terrain-query-production-20261102-01/PokemonBlue.pdx` outside Git.

The 2,494 protected images retain their accepted pixels/alpha/masks. Existing
41-map spawn views and 82 overlays remain historical visual proof. No full
mechanics fidelity is inferred from green routes or unchanged art.

## Current memory fix and physical observation

`SourceMaps.terrain` returns detached metadata. Field travel stops retaining a
whole catalogue; Vermilion membership uses `hasTile`. Primitive validation and
rollback remain. The fixture lookup follows active record scopes deliberately.
Actual SDK exports preserve transformed values and prior provenance. Nine
selected native cases pass: query isolation, Surf, Fly, rollback, Save/Continue
and Vermilion scene transactions. Combined review has no actionable findings.
[Adoption, exact reports and limitations](terrain-query-memory-adoption-20261102.json).

The accepted baseline reaches the 9 MiB Simulator guard at `Save.publish.end`
on the earned Surf/save route. It was not admitted to hardware. The candidate
completes the same route, including the actual surfing save at Fuchsia `(31,21)`
with 15 Surf PP and a natural Old Rod battle. Safety: 50.176 ms maximum slice,
8.53 MiB sampled Lua peak, 16 MiB pool, no runtime error. The strict Simulator
live-heap budget still fails; this is measurement admission only.

Physical build `ef35f457052b46dcbf9fffa8be447e6c`: no new logs, sampled Lua peak
**6.12 MiB**, post-GC samples **4.64–5.04 MiB**. Keeper inventory was verified and
run acknowledged; its screen was not directly observed. No paired device saving
is claimed because the baseline cannot safely run this route.

| Phase | Device wall | Target | Scope/result |
| --- | ---: | ---: | --- |
| App start → title accepts A | 13.191 s | ≤10 s | Fails; includes 0.876 s diagnostic GC |
| Maximum boot slice | 1.451 s | ≤1 s | Fails |
| Continue | 3.279 s | ≤4 s | Passes this run |
| Save in Center | 1.820 s | ≤2 s | Passes this run |
| Save while Surfing | 3.317 s | ≤2 s | Fails; no paired regression established |
| Fuchsia entry | 4.478 s | ≤1.5 s | Fails |
| Good Rod house / Fuchsia return | 1.664 / 2.435 s | ≤1.5 s | Fail |
| Fishing battle start | 22 ms | ≤1 s | Passes this run |
| Cave walking p95 | Unmeasured | ≤50 ms | Open |

This profile retains default diagnostic full collections and normal soft GC.
Shipped-equivalent timing is unmeasured; do not silently subtract GC. Lua counts
exclude native/transient allocations. The route covers Fuchsia and its rod house,
not all heavy B maps or C's working margin.

The earlier physical long traversal passed 110 doors, 30 maps and 20 wild battles
over 87.44 minutes: 136 post-GC samples, maximum 5.151 MiB, raw peak 6.341 MiB,
no new logs. It is scoped historical resource proof, not current latency.
[Traversal](b149-physical-long-traversal-20261101.json). Idle soak and native image
point probes retain their separate scope.

## Next work and open gates

1. Current physical memory samples now cover Game Corner and Hideout B1F–B4F,
   about 5 MiB collected live with 6.13 MiB sampled peak. Safari Center, East,
   North and West now measure 5.03–5.08 MiB post-GC with the same 6.13 MiB peak;
   seven natural encounters use ordinary RUN. Tower 1F–7F now measures
   4.77–4.84 MiB post-GC, with 6.11 MiB sampled peak and six actual encounters.
   Tower uses the genuine earlier post-Fuji Save, not a fabricated late-B save.
   [Tower samples](tower-memory-20261102.json).
   [Safari samples and retained failures](safari-memory-20261102.json). The current fishing-battle point probe holds eight requested 256 KiB
   native images on hardware, then releases them; allocation plus two collections
   takes 1.243 s. This diagnostic-GC route is not the full C margin.
   [Native point probe](native-headroom-current149-20261102.json).
   Spinner query merge `1860b3c0` reduces ordinary B3 active p95 from 148 to
   39 ms in one hardware comparison; 61 native checks and 24 merged host checks
   pass, with no review findings. Three roughly two-second hitches remain.
   [Scoped adoption](spinner-query-adoption-20261102.json). Audio remains held.
   [Heavy-map samples and hitch scope](heavy-b-memory-20261102.json).
2. Substitute is adopted. The composed host suite ran1,169tests with four
   metadata/art-reference failures;110targeted branch checks and120merged checks
   pass after correction.57protocol checks and productioncompile pass. Current
   shared-owner evidence is rebound only where unchanged assertions reran;
   HelpingHand/Dig stay stale, and no full-mechanics completion is inferred.
3. C's isolated candidate is now wired and SDK-qualified at `5ae77a61` in
   `t3/checkpoint-c-host-preparation`. Main stays 149 maps; candidate has 171.
   Source-derived metadata handles two inert Silph declarations and 13 scripted
   elevator IDs without changing B's 510 classifications. Actual thin SDK export
   preserves Kanto/East/South values and produces Saffron's 30 transformed events
   and 45 trainers; sampled host peak is 194 MiB. Qualified production compile
   passes. Native floor/elevator checks, earned journeys and C's own hardware,
   memory, latency and visual gates remain open. The guarded full-harness export
   stopped at 1 GiB and was replaced, not continued. B memory no longer blocks C
   activation, per reviewer steer 7. Existing earned boundaries remain strict.
   [C ancestry proof](checkpoint-c-restored-ancestry-20261102.json).
4. Controlled four-Save measurement separates ordinal from the earlier mixed
   comparison: Center #1/#2 take 1.947/2.867 s; Fuchsia Surf #1/#2 take
   2.288/3.529 s. Inspection rises 361→1,334 ms and 375→1,600 ms; writes/readbacks
   are nearly flat. Whole-phase marks are private, not a production change.
   Cross-map still combines map, travel and mode; no isolated Surf effect claimed.
   [Actual attribution](save-four-point-attribution-20261102.json).
   A SAVE-only inspection-proof candidate now measures repeated Center Save
   2.867→2.020 s and repeated Surf Save 3.529→2.426 s, 29.5/31.3% faster.
   First Saves are 2.5/3.5% slower. Public loads retain deep validation; 23
   selected native persistence cases pass. Both exact safety routes admit device
   measurement; hardware peak is about 6.14 MiB with unchanged system logs.
   Adopted as `1ffd6fa7` after one combined review with zero findings. All 47
   selected merged host/build checks and production compilation pass; the three
   changed Source files equal the measured candidate. Surf still misses 2 s.
   [Measured candidate and scope](save-inspection-reuse-measured-20261102.json).
5. Matched hardware observations now cover all three canonical B saves, with
   identical code/SDK/compiler and only private build identity differing:
   selected envelopes 21,533/22,650/24,316 bytes; title preparation
   4.589/4.687/4.981 s; input-ready boot 13.325/13.548/13.774 s;
   Continue 3.293/3.360/3.463 s. Store inspection takes 2.419/2.482/2.635 s.
   Default title diagnostic GC is 0.876/0.899/0.968 s; shipped-equivalent timing
   remains unmeasured. Party, PC and flags vary together, so PC causality is not
   isolated. All three exceed boot/slice targets; Continue meets 4 s.
   [Three-save phases and exact proof](boot-three-earned-saves-20261102.json).
   Fix structural door/boot/cave costs. Deferred `import()` splitting is closed:
   SDK 3.1.2 prohibits imports outside PDZ loading; no candidate was created. Do not
   restart the census. The user explicitly allows the existing guarded history
   helper for ordinary C journeys. Its archive-fence correction passes host
   checks, but native qualification remains open: opening the profiler window
   itself can cross the unchanged 1 GiB host guard before Clear. A reviewed
   ready-title pause now proves actual Clear and 67 ordinary requests through
   Route 15, but stops at the unchanged 64-Clear limit: the cleared UI footprint
   exceeds the 512 MiB trigger. Closing the window did not release headroom and
   is rejected. The user approved changing only the soft Clear trigger to
   736 MiB; 36 focused host checks pass and a fresh single-Squirtle pilot is
   running. The 1 GiB hard stop, 16 MiB pool, 64-Clear/131-call caps and other
   limits remain unchanged. No complete C journey is inferred from the earlier
   short qualification.

Compact SMC1 terrain-row consumption is also rejected after native correctness
passes but no whole-phase hardware gain: Fuchsia 4.451→4.507 s, memory unchanged.
Four map cases, one WorldView rollback and nine activation cases pass; no review
or adoption follows. [Measured rejection](packed-terrain-rejected-20261102.json).

The six-set atlas enablement candidate is rejected after matched hardware.
Game Corner load was 3.889→3.933 s; B3 load 1.886→1.907 s, with three >1 s
frames still present. Tower's best floor improvement was 3.0%. Native pixels
passed all 727 keys/20 tables, but no target met the 10% performance rule.
No review, adoption or additional proof work is requested for this candidate.
[Measured rejection](atlas-enable-rejected-20261102.json).

The door-tier candidate remains rejected: primary cold-entry gains were only
3.1% Fuchsia, 8.4% Route17 and 7.8% GameCorner, with Save 11.3% slower. Its
qualified native modes passed 14/14 each, but no further cycle/review is requested.
[Rejected measurement](door-tier-rejected-20261102.json).

The 499-step Safari expiry fixture currently exceeds the 1 GiB host allocation
history limit; no fresh pass is claimed. Its original accepted proof remains.
Other targeted tests ran in fresh processes with their assertions intact. User
resolved desktop dialogs and opened Screen Sharing; native startup works again.
Paired DiveMac-node desktop observation is verified; gateway status alone is not
node availability. No unrelated applications were killed.

## Operating decisions

User disk policy: **30 GiB reserve / 31 GiB new-runtime admission**. Local
maintenance runs at 30→50 GiB. Keep the SDK 3.1.2 pool at 16 MiB, host limit at
1 GiB, Lua guards at 6/8/9 MiB, and ordered ownership locks. All runtime/USB
readers are closed after both measured routes; verified keeper is restored.
Storage is background, exception-only. No current/earned input is discarded.
[Verified census retention](capacity-census04-retention-20261102.json),
[earlier recovery](capacity-census-retention-complete-20261102.json).

Coverage retains all 1,512 rows, facets and historical proof hashes. The current
snapshot was reviewed separately; no fidelity or acceptance level was promoted.
[Previous ledger/history](progress-history-before-b-acceptance-20261102.md).
