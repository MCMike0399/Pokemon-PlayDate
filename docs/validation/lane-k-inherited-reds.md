# Catalog memory on main 247d60a9

`MallocPoolSize` stayed `16645684`. Nothing here edits `Source/`.

## Catalog memory

On clean `247d60a9` the no-argument `contracts` command scores `battle-rewards-v1` at 21 passed, 6 failed (heap 13798.8 KiB) and dies in the next suite. `individual-stats-v1` returned 16 passed, 1 failed at 13805.133 KiB, then `pd_readcompressed inflate failed, out of memory`. The progress row stays `returned`. The catalog does not score that suite and does not finish.

The heap climbs in the suites that leave their tables resident: world +251.6 KiB to 13204.4, traversal +280.4 to 13383.2, event-ui +229.8 to 13612.9, pewterProviderContracts +203.5 to 13756.8. party-battle and evolution do release memory. The inflate failure is that cumulative heap, not a bad individual-stats assertion. The fail count inside individual-stats wobbles when the inflate hits mid-suite.

`tools/harness/dev_imports.lua` wraps `Contracts.register` so each suite nils its own module and any `contract_` zone that is not the current zone, then the next checkpoint collects. Five modules stay installed because later suites call them: `SessionContracts`, `PartyBattleContracts`, `KantoServicesContracts`, `CeruleanSceneContracts`, `CeruleanRoutesContracts`. The wrapper does not mention `MallocPoolSize`.

With that overlay the catalog passes the old death. `cerulean-catalog` was running at 12332.5 KiB (42.3 s). `saffron-guards` was running at 12561.9 KiB (77.1 s). The simulator was still alive. The command then stopped in `Harness.publish`: `dev/harness.lua:41: Too many open files`. The process ulimit is 524288, so this is the SDK file table. The catalog still does not finish.

Two wider releases were measured and left out. Nilling `SourceMaps` compact data makes `event-ui` re-verify the whole catalogue; that suite was still running at 12926.2 KiB when the 180 s command timed out. `WorldDeltas.disposeImportedCache`, and a forced collect of the retained runtime maps, free images the frame is still drawing. The simulator native-crashes during a later `writeToFile`.
