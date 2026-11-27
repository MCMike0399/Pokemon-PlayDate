# Inherited reds on main 247d60a9

`MallocPoolSize` stayed `16645684`. Nothing here edits `Source/`. `Source/dev/rewardContracts.lua` is hand-written. No generator emits it, so the four reward expectations were not rewritten by hand and there is no lane-e patch for them.

## battle-rewards-v1

Run alone, `contracts battle-rewards-v1` is 23 passed and 4 failed on clean main and on the batch-2 stack (heap 12885.3 KiB on the stack). The four failures are the same tests.

A host trace of the live script, with pokered `af519899719f0754965776faac0e836a3b906e6d`, puts all four on stale expectations.

1. Level-up EV recompute. After the faint script the squirtle is level 7, `ev.spe` is 4, speed is 12 and matches `calculatedStats().spe`, and the HP deficit is unchanged. The assertion `eq(b.enemy, e1)` fails because the script has already sent out Geodude. Pokered `evos_moves.asm` teaches Squirtle Bubble at level 8 (`db 8, BUBBLE`), not at 7, so there is no learning yield to hold the replacement. `experience.asm` calls `LearnMoveFromLevelUp` only when the new level has a move, then `.nextMon` continues the party.

2. HUD vitals hold. The live message is `CHARMANDER gained\n46 EXP. Points!`. During that page `presentationVitals` stay 6, 18, 20 while the live mon is already level 7 at 20/22. After the grew line the vitals are 7, 20, 22. The test searches `" gained "` with a trailing space. Pokered `_GainedText` is `text " gained"` and then a line break, so the search never matches, the script ends, and the next `advance` is `script-cancelled`.

3. Bench-member hold. The same trailing-space search, `"SQUIRTLE gained "`, ends the script before the hold assertions. The test also expects a level-7 Bubble or Ember prompt. Charmander learns Ember at level 9 (`db 9, EMBER`).

4. Level-up stats box. The box is yielded after the grew line (`levelStats` attack/speed 12/14 on the trace) and cleared on the next advance, which is `PrintStatsBox`, then `WaitForTextScrollButtonPress`, then `LearnMoveFromLevelUp`. The pixel checks pass. `eq(pending, true)` at the learning snapshot fails because Ember is level 9, so `pending` stays false. The missing SPECIAL row is the Gen V split the port already draws.

## Catalog memory

On clean `247d60a9` the no-argument `contracts` command scores `battle-rewards-v1` at 21 passed, 6 failed (heap 13798.8 KiB) and dies in the next suite. `individual-stats-v1` returned 16 passed, 1 failed at 13805.133 KiB, then `pd_readcompressed inflate failed, out of memory`. The progress row stays `returned`. The catalog does not score that suite and does not finish.

The heap climbs in the suites that leave their tables resident: world +251.6 KiB to 13204.4, traversal +280.4 to 13383.2, event-ui +229.8 to 13612.9, pewterProviderContracts +203.5 to 13756.8. party-battle and evolution do release memory. The inflate failure is that cumulative heap, not a bad individual-stats assertion. The fail count inside individual-stats wobbles when the inflate hits mid-suite.

`tools/harness/dev_imports.lua` wraps `Contracts.register` so each suite nils its own module and any `contract_` zone that is not the current zone, then the next checkpoint collects. Five modules stay installed because later suites call them: `SessionContracts`, `PartyBattleContracts`, `KantoServicesContracts`, `CeruleanSceneContracts`, `CeruleanRoutesContracts`. The wrapper does not mention `MallocPoolSize`.

With that overlay the catalog passes the old death. `cerulean-catalog` was running at 12332.5 KiB (42.3 s). `saffron-guards` was running at 12561.9 KiB (77.1 s). The simulator was still alive. The command then stopped in `Harness.publish`: `dev/harness.lua:41: Too many open files`. The process ulimit is 524288, so this is the SDK file table. The catalog still does not finish.

Two wider releases were measured and left out. Nilling `SourceMaps` compact data makes `event-ui` re-verify the whole catalogue; that suite was still running at 12926.2 KiB when the 180 s command timed out. `WorldDeltas.disposeImportedCache`, and a forced collect of the retained runtime maps, free images the frame is still drawing. The simulator native-crashes during a later `writeToFile`.
