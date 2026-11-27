# Lane E stack rehearsal

Rehearsed on a detached worktree of main `247d60a9216307c0e1b15316f2b052ae10d23a6c`. The named scratch branch `cursor/lane-e-stack-rehearsal-3818` points at that commit and was not pushed. `source-capture-formula` was not applied. `MallocPoolSize` stayed `16645684`.

Lane I's two handoffs are on `cursor/lane-i-device-perf` tip `dce824230112a22e4ead2087da9177df5616408f`. The south-door patch is `tools/notes/lane-e-e4-door-lock.patch` from `085d55657c074a7e93aa12a2e3b99f1582a58e51`. The secondary-message patch is filed as `tools/notes/lane-e-effect-message-order.patch`, not `lane-e-secondary-message-order.patch`, from `8443500c61cb1faaf8ddd0cbb29f5dde0de3172f`.

Host discover on clean `247d60a9`: 1458 tests, 6 failed, 50 errors, 11 skipped, 422.8s. The same discover on the stacked tree: 1455 tests, 35 failed, 56 errors, 11 skipped, 114.1s. Simulator cases on the stack died in `pdc` (`No such file: audio/moveSfx`), so they never reached the lock. Shared errors on both trees (the `lua` binary name, `~/Developer/PlaydateSDK`, missing pokered paths) are not new. Per-patch reds below are the checks that flipped on a replay. The full discover was not repeated after every patch.

## Apply order

| # | Patch | Taken from | Apply | New host red |
| --- | --- | --- | --- | --- |
| 1 | lane-e-e4-door-lock | I `dce82423` / `085d5565` | clean | coverage matrix fingerprint |
| 2 | lane-e-nil-player-reentry | H `d1ddaf20` | clean | none beyond the fingerprint |
| 3 | lane-e-gift-menu-input | H `d1ddaf20` | clean | Cerulean projection pin |
| 4 | lane-e-cave-encounter-memory | lane-k `576f8b70` | clean | none beyond the fingerprint |
| 5 | lane-e-counter | I `dce82423` | clean | Vermilion journey pin, runtime SDK pin, Vermilion acquisition pin |
| 6 | lane-e-razor-wind | lane-k | clean | `move_failure_phazing` loses the razorWind gap |
| 7 | lane-e-mist | lane-k | clean | move inverse hash leaves `ad40fd9b`; early-combat unchanged-row pin |
| 8 | lane-e-mimic | lane-k | clean | inverse hash moves again |
| 9 | lane-e-minimize | lane-k | clean | inverse hash lands on `0e662bef` |
| 10 | lane-e-metronome | lane-k | clean | metronome gap key removed |
| 11 | lane-e-dream-eater | lane-k | clean | dreamEater gap key removed |
| 12 | lane-e-sky-attack | lane-k | clean | none beyond the fingerprint |
| 13 | lane-e-conversion | lane-k | clean | none beyond the fingerprint |
| 14 | lane-e-effect-message-order | I `dce82423` / `8443500c` | clean | none beyond the fingerprint |
| 15 | lane-e-viridian-sleepy-retrigger-heap | H `d1ddaf20` | clean | none beyond the fingerprint |
| 16 | lane-e-party-status-type | H `d1ddaf20` | clean | none beyond the fingerprint |
| 17 | lane-e-trainer-wants-to-fight | G `2ba9de33` | clean | none beyond the fingerprint |
| 18 | lane-e-battle-back-pic | G `2ba9de33` | clean | player-back scale looks for `drawScaled(0, 0, scale)` in the back function |
| 19 | lane-e-battle-slide-in | G `2ba9de33` | clean | none beyond the fingerprint |
| 20 | lane-e-trainer-portrait-flat | G `2ba9de33` | clean | none beyond the fingerprint |
| 21 | lane-e-pokemon-accent | G `2ba9de33` | clean | dialog-font probe expects `Which POKEMON` and gets `Which POKéMON` |
| 22 | lane-e-continue-prompt | G `2ba9de33` | clean | none beyond the fingerprint |
| 23 | lane-e-screen-font-grid | G `2ba9de33` | clean | none beyond the fingerprint |
| 24 | lane-e-party-fidelity | G `2ba9de33` | clean | none beyond the fingerprint |
| 25 | lane-e-status-fidelity | G `2ba9de33` | 3-way | none beyond the fingerprint |
| 26 | lane-e-save-fidelity | G `2ba9de33` | clean | none beyond the fingerprint; cave forest goes red (below) |
| 27 | lane-e-trainer-fidelity | G `2ba9de33` | clean | trainer-card test loses `GbFont.drawMoneyLine("¥"` |
| 28 | lane-e-audio-badge-item | F `f3df914b` | 3-way | none in the host discover |
| 29 | lane-e-audio-heal-count | F `f3df914b` | clean | calls `playSequence`, which main does not define |
| 30 | lane-e-audio-pokedex-cry | F `f3df914b` | clean | none |
| 31 | lane-e-audio-source-cries | F `f3df914b` | clean | none |
| 32 | lane-e-audio-movesfx-import | F `f3df914b` | clean | `pdc` fails: `audio/moveSfx` is not on main. Every later simulator test dies there |
| 33 | lane-e-audio-player-faint-cry | F `f3df914b` | 3-way | adapted; see below |

The inverse-hash family that goes red at mist, and stays red, is bide, captivate, charge, earned B, protection, self-KO, roost, rain, poison fang, pre-Brock, side, worry seed, and the move-producer contract.

## Three-way merges

`lane-e-status-fidelity` failed at `Source/game/partyState.lua:261` because party-status-type and party-fidelity had already rewritten the stats block. `git apply --3way` left one conflict. The stats branch now calls `PartyState.typeLines(mon)` and then `self:drawStatus(mon)`. The info branch is `self:drawSummary(mon)`.

`lane-e-audio-badge-item` failed at `Source/audio/events.lua:310`. The 3-way wanted to insert `ball_poof` and `ball_toss`, which are on F and not on main. The resolution keeps main's alphabetical cue list and changes only the badge cue to `score="item"`, token `SFX_GET_ITEM_1`. `tools/audio/events.py` applied cleanly.

`lane-e-audio-player-faint-cry` failed at `Source/game/kantoAudio.lua:654`. The 3-way pulled F's faint sequencer (`moveScore`, `sfxFrames`, `pendingThud`, `playSequence`). Those functions are not on main. The resolution keeps main's hit/faint branch and plays `KantoAudio.playCry` immediately when the battle mon has a species. The move-row delay is not implemented. F's string checks pass on that adaptation. It is not the patch E should land raw.

## Device heap

`MallocPoolSize` is `16645684`.

The unmodified stack does not compile. A measurement copy added an empty `Source/audio/moveSfx.lua` and `function playSequence() end` so the full-stack contracts could build. Prefixes before the audio patches did not use that stub.

| Tree | cave-encounters | heap KiB |
| --- | --- | --- |
| through party-status-type (16) | 8 passed, 0 failed | 13067.0 |
| through screen-font-grid (23) | 8 / 0 | 13069.5 |
| plus party-fidelity | 8 / 0 | 13074.6 |
| plus status-fidelity | 8 / 0 | 13083.2 |
| plus save-fidelity | 7 / 1, forest `not enough memory` | 13112.3 |
| plus trainer-fidelity | 7 / 1, same forest case | 13134.1 |
| full stack plus the audio stub | 7 / 1, same forest case | 13147.4 |

`individual-stats-v1` on the stubbed full stack: 17 passed, 0 failed, 13011.1 KiB. `field-travel`: 3 passed, 0 failed, 12874.6 KiB. The no-argument `contracts` command on that full stack returned in 24.0s with `not enough memory` while `battle-rewards-v1` had returned 1 passed and 26 failed (heap 13876.2 KiB). It did not finish the catalog.

The same catalog on clean `247d60a9` scores `battle-rewards-v1` at 21 passed, 6 failed (heap 13798.8 KiB) and dies one suite later: `individual-stats-v1` returned 16 passed, 1 failed, then `pd_readcompressed inflate failed, out of memory` at 13805 KiB. Batch 1 (patches 1–25) scores `battle-rewards-v1` at 1 passed, 26 failed (heap 13836.8 KiB) and dies the same way in `individual-stats-v1` (16 passed, 1 failed, then the inflate error at 13843.9 KiB). `MallocPoolSize` stayed `16645684`.

Run alone, `contracts battle-rewards-v1` is 23 passed, 4 failed on clean main (heap 12817 KiB). The four failures are already on main: the level-up EV recompute (pokemon identity), the HUD vitals hold (`script-cancelled`), the bench-member hold (`script-cancelled`), and the level-up stats box (`expected true, got false`). The same command through `battle-back-pic` is still 23/4. `lane-e-battle-slide-in` is the patch that drops it to 1/26. `Battle:present` yields `silhouetteEnter` before `BattleScene` sets `presentationAttached`, and `RewardContracts.settle` then hits `reward presentation requires its production scene` at `rewardContracts.lua:29`. Heap stays about 12809 KiB, so this red is the missing scene, not the pool. The full-stack catalog died inside that suite because those 26 failures were published on top of the batch-2 heap.

`save-fidelity` is the first patch that puts the forest case back over the edge. The cave-encounter patch alone, on this same pool, was 8/0 at 13046.3 KiB.

## Patch tests

Passed against the stacked source: nil-player reentry, gift menu input, party status type, effect-message order, the eight move hosts, counter last-strike, the wild-win host, the six audio string checks (on the adapted faint and badge text), and `test_lane_d_endgame`. Viridian sleepy retrigger stayed inside 64 KiB (24s, stack through trainer-fidelity).

`test_lane_e_e4_door_lock` fails on the patched tree. The patch does add `return "dont-run"` and the comment `south door stays shut after the win`, but the test slices the first `for _, room in ipairs(data.elite_four)` loop. Main has an earlier loop, so the assertion never sees the comment. I's own `endgameStory.lua` at `dce82423` does not contain that comment either; the comment lives in the patch.

G's "apply this patch onto the live tree" checks fail once the patch is already applied. That includes trainer-wants, back-pic, slide-in, portrait, accent, continue-prompt, the screen-font reapply, and the fidelity sweep's stacked reapply. The screen-font test also asserts the live tree does not define `GbFont.FIT = 12`, which is false after the patch. The frame and source checks that do not re-apply passed.

The cave-encounter test fails on the full stack (7/1). It passes through status-fidelity.

`tools/tests/test_lane_e_wild_win_text.py` KOs a wild Caterpie with Ember and requires outcome `victory`, a faint, EXP, and no `You won the battle!` page. It passes on clean `247d60a9` and on the stack. Restoring that line fails it.

## Batches

Two batches.

Batch 1 is patches 1 through 25 (door lock through status-fidelity), with the one partyState merge above. Cave-encounters stays 8/0 at 13083 KiB. E should expect the host pin reds in the table. They are hashed source bytes moving, not a device crash.

Batch 2 of that first rehearsal was save-fidelity, trainer-fidelity, and the old six audio patches. Save-fidelity rebroke the forest case at 13112 KiB. Those old audio patches do not compile on main. The re-rehearsal below replaces them.

## Batch 2 re-rehearsal

Detached worktree of the same main `247d60a9216307c0e1b15316f2b052ae10d23a6c`. `source-capture-formula` stayed out. `MallocPoolSize` stayed `16645684`. Sources: G `cursor/lane-g-front-end` `39ad4248e1496012f30df4861256a63916446877`, H `cursor/lane-h-postgame` `26d64e4c11327981cb5849bd723d05e77e9beb51`, F `cursor/lane-f-audio` `9dc7883c7e32049722821dbdb40ea8a44d79e303`, I `dce824230112a22e4ead2087da9177df5616408f`, and the cave patch already on this branch. Every patch applied with `git apply` after `git add -A`. No 3-way and no conflict. `pdc` of the stacked `Source` returned 0.

`lane-e-postgame-pickup-continue.patch` is new at H `26d64e4c` and is applied immediately after the updated `lane-e-mewtwo-continue-actor.patch` from that same commit. The pickup header says to apply it after the mewtwo patch. Both touch `Source/game/lateKantoStory.lua`. The mewtwo test at that commit probes the Mewtwo, Zapdos, and `PICKUP:` hide flags and passed on the stacked tree.

Slide-in is the reworked patch from `39ad4248`. It sets `pendingSilhouette` and returns when `presentationAttached` is unset, so a headless settle does not yield. Its own test checks that branch and passed. Status-fidelity from the same commit already contains `PartyState.typeLines` in its hunk context, so it applies cleanly after party-status-type.

Screen-font reapply is a conditional, not a unittest skip. `test_applied_grid_uses_one_font_and_does_not_move_red` runs `forward_check` and applies when that succeeds; otherwise `reverse_check` must succeed because the tree already has the patch. The file has no `unittest.skip`. The word `skip` there is the glyph-rect argument to `glyph_issues`.

| # | Patch | Taken from | Apply | New red on this stack |
| --- | --- | --- | --- | --- |
| 1 | lane-e-e4-door-lock | I `dce82423` | clean | own test still misses the comment in the first elite-four loop |
| 2 | lane-e-nil-player-reentry | H `26d64e4c` | clean | none |
| 3 | lane-e-mewtwo-continue-actor | H `26d64e4c` | clean | none |
| 4 | lane-e-postgame-pickup-continue | H `26d64e4c` | clean | none; mewtwo test covers the pickup flags |
| 5 | lane-e-gift-menu-input | H `26d64e4c` | clean | none |
| 6 | lane-e-cave-encounter-memory | lane-k `576f8b70` | clean | none |
| 7 | lane-e-counter | I `dce82423` | clean | none once `counter_host.lua` is present |
| 8 | lane-e-razor-wind | lane-k | clean | none |
| 9 | lane-e-mist | lane-k | clean | none |
| 10 | lane-e-mimic | lane-k | clean | none |
| 11 | lane-e-minimize | lane-k | clean | none |
| 12 | lane-e-metronome | lane-k | clean | none |
| 13 | lane-e-dream-eater | lane-k | clean | none |
| 14 | lane-e-sky-attack | lane-k | clean | none |
| 15 | lane-e-conversion | lane-k | clean | none |
| 16 | lane-e-effect-message-order | I `dce82423` | clean | none once `effect_message_order_host.lua` is present |
| 17 | lane-e-viridian-sleepy-retrigger-heap | H `26d64e4c` | clean | none |
| 18 | lane-e-party-status-type | H `26d64e4c` | clean | none |
| 19 | lane-e-trainer-wants-to-fight | G `39ad4248` | clean | none |
| 20 | lane-e-battle-back-pic | G `39ad4248` | clean | none |
| 21 | lane-e-trainer-portrait-flat | G `39ad4248` | clean | none |
| 22 | lane-e-pokemon-accent | G `39ad4248` | clean | none; the updated accent test passed |
| 23 | lane-e-continue-prompt | G `39ad4248` | clean | none |
| 24 | lane-e-screen-font-grid | G `39ad4248` | clean | none |
| 25 | lane-e-party-fidelity | G `39ad4248` | clean | none |
| 26 | lane-e-status-fidelity | G `39ad4248` | clean | cave forest goes red (below) |
| 27 | lane-e-battle-slide-in | G `39ad4248` | clean | none; rewards stay 23/4 |
| 28 | lane-e-save-fidelity | G `39ad4248` | clean | none beyond the forest case already red |
| 29 | lane-e-trainer-fidelity | G `39ad4248` | clean | trainer-card test still wants `GbFont.drawMoneyLine("¥"`; the patch writes `trainerFitString("¥"` |
| 30 | lane-e-audio-sequencer | F `9dc7883c` | clean | none |
| 31 | lane-e-audio-movesfx-import | F `9dc7883c` | clean | none |
| 32 | lane-e-audio-heal-count | F `9dc7883c` | clean | none |
| 33 | lane-e-audio-pokedex-cry | F `9dc7883c` | clean | none |
| 34 | lane-e-audio-source-cries | F `9dc7883c` | clean | none |
| 35 | lane-e-audio-badge-item | F `9dc7883c` | clean | none |
| 36 | lane-e-audio-player-faint-cry | F `9dc7883c` | clean | none |

Own host tests on the stacked tree: 72 run, then the three that had been missing a host script or the `~/Developer/PlaydateSDK` path. Counter, effect-message order, and `test_lane_e_audio_handoff` pass (the handoff compiles the series with `pdc` on a fresh `247d60a9` worktree). Two failures remain, both already known: the e4 door-lock slice, and `test_trainer_card_and_payday_use_yen`. That fidelity assertion is unchanged in `2ba9de33..39ad4248`. Viridian sleepy retrigger on the full stack stayed inside 64 KiB (24.5s).

### Device checks

`contracts cave-encounters` on the full 36 is 7 passed, 1 failed, heap 13137.8 KiB. The failure is the same forest case: `FOREST non-grass and outdoor non-grass reject; ordinary grass retains Blue rate` raises `not enough memory` at `dev/contracts.lua:446`.

The requested batch 1 (patches 1–26, through status-fidelity, with mewtwo and pickup, without slide-in) is already 7/1 at 13111.0 KiB. Prefixes:

| Tree | cave-encounters | heap |
| --- | --- | --- |
| through party-status-type, including mewtwo and pickup | 8 / 0 | 13068.6 KiB |
| through pokemon-accent | 8 / 0 | 13069.6 KiB |
| through party-fidelity | 8 / 0 | 13077.6 KiB |
| through status-fidelity (requested batch 1) | 7 / 1, forest | 13111.0 KiB |
| that tree without mewtwo and pickup | 7 / 1, forest | 13107.8 KiB |
| full 36 | 7 / 1, forest | 13137.8 KiB |

`lane-e-status-fidelity` from `39ad4248` is the first patch that puts the forest case over the edge. It adds `PartyState:drawStatus` and `drawSummary`, and `statusFitTile` builds a 12×12 image per glyph from the GB font sheets. Mewtwo and pickup add about 3 KiB and are still inside an 8/0 prefix. The later slide-in, slimmed save-fidelity, trainer-fidelity, and audio series leave the same forest failure in place and raise the scored heap to 13137.8 KiB.

`contracts battle-rewards-v1` alone on the full stack is 23 passed, 4 failed, heap 12885.3 KiB. The four are the inherited ones: level-up EV identity, HUD `script-cancelled`, bench `script-cancelled`, and the stats-box `expected true, got false`. The reworked slide-in does not revive `reward presentation requires its production scene`.

`contracts individual-stats-v1` is 17 passed, 0 failed, heap 13001.9 KiB. `contracts field-travel` is 3 passed, 0 failed, heap 12865.2 KiB.

### Final split

Batch 1 is patches 1–25 (door lock through party-fidelity). That includes mewtwo-continue-actor and, immediately after it, postgame-pickup-continue. Cave-encounters is 8/0 at 13077.6 KiB.

Batch 2 starts with status-fidelity, then the reworked battle-slide-in, the slimmed save-fidelity, trainer-fidelity, and F's seven audio patches in the order above. Status-fidelity is the forest regression (7/1 at 13111.0 KiB). The rest of batch 2 keeps rewards at 23/4 and leaves individual-stats and field-travel green. The full stack stays 7/1 on the forest case at 13137.8 KiB.

## Regenerated status and trainer cards

Fresh detached worktree of main `247d60a9216307c0e1b15316f2b052ae10d23a6c`. Same 36-patch order as the section above. G's patches were taken again from `cursor/lane-g-front-end` `aa2d86b4730dd4e3db31f107bdb57d8f21df8a98`. Against `39ad4248`, only `lane-e-status-fidelity.patch` and `lane-e-trainer-fidelity.patch` changed. G's stated clean base is `2ba9de33`. H stayed `26d64e4c`. F stayed `9dc7883c`. `MallocPoolSize` stayed `16645684`.

Every patch was checked with plain `git apply --check` (no `--3way`) and then applied. All 36 checks were clean, including every G patch from `aa2d86b4`. On a second tree that stopped at batch 1 (patches 1–25, through party-fidelity), these four also checked clean on their own, before any of them was applied:

| Patch | `git apply --check` on 247d60a9 plus batch 1 |
| --- | --- |
| lane-e-status-fidelity | clean |
| lane-e-battle-slide-in | clean |
| lane-e-save-fidelity | clean |
| lane-e-trainer-fidelity | clean |

The regenerated status card is a standalone `statusScreen` pdz. `PartyState` runs it while STATS or SUMMARY is open and drops the module when that page closes. The trainer card is the same pattern: `PauseState` runs `trainerScreen` only while the card is open. The yen line lives in `Source/game/trainerScreen.lua` as `trainerFitString("¥" .. session:inventory():money(), 8, 4)`, next to `trainerFitString("MONEY/", 2, 4)`. `test_trainer_card_and_payday_use_yen` reads that file when it is present and otherwise applies the regenerated patch. Payday stays `picked up\n¥` in `battle.lua`.

### Device checks on the full stack

| Suite | passed | failed | heap |
| --- | --- | --- | --- |
| cave-encounters | 8 | 0 | 13082.5 KiB |
| individual-stats-v1 | 17 | 0 | 12972.1 KiB |
| battle-rewards-v1 | 23 | 4 | 12854.2 KiB |
| field-travel | 3 | 0 | 12832.7 KiB |

Cave-encounters is 8/0 on the full stack. The `39ad4248` status card was the forest edge (7/1 at 13111.0 KiB, full stack 13137.8 KiB). Loading the status and trainer cards only while those screens are open brings the full stack, including F's seven, back under that edge at 13082.5 KiB. The four battle-rewards failures are the same inherited expectations (level-up EV identity, HUD `script-cancelled`, bench `script-cancelled`, stats-box `expected true, got false`). Individual-stats and field-travel stayed green.

Batch 1 is still patches 1–25. Batch 2 is still status-fidelity, battle-slide-in, save-fidelity, trainer-fidelity, then F's seven at `9dc7883c`. With the regenerated cards, batch 2 no longer turns the forest case red.

## Queue left on main 1ec2e285

`git ls-remote origin refs/heads/main` is `1ec2e28515fba778de4229147c052978b6284961`. That commit is `d86dd999` plus `846a3840` (blackout pages), `4bc49bb1` (Center cable-club lines), and `4bee9267` (EXP.ALL bench award), each followed by a coverage snapshot. Batch 2 is already in as `2c0daa81`. Cable-club is already in as `4bc49bb1`. G's four `lane-e-reward-*` patches are dropped. `063aed84` already corrected those four expectations, and `contracts battle-rewards-v1` on `47ab3408` (that fix, before the link patch) was 27 passed, 0 failed, heap 12849.1 KiB.

What is still outside main is `cursor/lane-g-link-cable` `c97499e9`: `lane-e-link-cable-celadon-4f` and `lane-e-mart-list-fidelity`. Checked with plain `git apply --check` (no `--3way`) on a fresh `1ec2e285`. `MallocPoolSize` stayed `16645684`.

| Patch | `git apply --check` on 1ec2e285 | Own test |
| --- | --- | --- |
| lane-e-link-cable-celadon-4f | clean, applied | `test_link_cable` 3/3 |
| lane-e-mart-list-fidelity | fails at `Source/game/gbFont.lua:46` | not applied |

The mart hunk expects `function GbFont.drawChar` immediately after `tileImage`. Main already has the screen-font block there (`GbFont.FIT = 12` and `fitImage`). The patch would insert a second `GbFont.FIT = 10`. Checked alone, `martList.lua`, `shopState.lua`, and `docs/validation/fidelity-ledger.md` are clean. The patch needs to be regenerated against the FIT 12 block. It was not applied with `--3way`.

### Device checks

Clean `1ec2e285`, then the same tree plus the link-cable patch:

| Suite | clean 1ec2e285 | plus link-cable |
| --- | --- | --- |
| cave-encounters | 8 / 0, 13090.7 KiB | 7 / 1, 13116.9 KiB |
| individual-stats-v1 | not rerun | 17 / 0, 12981.1 KiB |
| battle-rewards-v1 | not rerun | 27 / 0, 12862.8 KiB |
| field-travel | 3 / 0, 12845.2 KiB | 2 / 1, 12837.9 KiB |

The link patch's own tests pass, and battle-rewards stays 27/0. It is the change that puts cave-encounters back over the forest edge (`FOREST non-grass and outdoor non-grass reject; ordinary grass retains Blue rate`, `not enough memory`) and makes field-travel's expired Surf inflate fail (`pd_readcompressed inflate failed, out of memory`). Clean main is 8/0 and 3/0 on those two.
