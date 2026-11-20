# Lane K failure triage on 2e7863ff

E tip at the start of this pass: `3ddb966765346a899188860b116161de27c03ffd` (records the `2e7863ff` host suite). `Source/` matches `2e7863ff29b3c9593511da9112c1c2538f9f234e`. The thirteen names are the `9a33a835` / `2e7863ff` host failures. Reference: pret/pokered `af519899719f0754965776faac0e836a3b906e6d`.

No `MallocPoolSize` change. This VM has no Playdate SDK, so device contracts were not re-run.

## Priority: npc-trades and pewterProviderContracts

| Item | Class | What this host shows | Patch |
| --- | --- | --- | --- |
| `test_npc_trades` (four tests) | environment | `FileNotFoundError` for `~/Developer/Pokemon-PlayDate-env/references/npc-trades/manifest.json`. The generator never reaches the trade rows. | none |
| device `npc-trades` “full party all 240 PC slots, source append order and survivor active identity” | known device red, not re-scored | `Party:_prepareExchange` removes the outgoing member, keeps the others in order, appends the incoming mon, and keeps the same active object when it is alive. That is the order `Source/dev/npcTradeContracts.lua` asserts. The ledger on older `main` `bf92c4fc` already failed this one name. | none |
| device `pewterProviderContracts` | known device red, not re-scored | Not part of the host discover. The ledger recorded `expected 1, got 0`, then `not enough memory`, on that old main and on the tip being compared. | none |
| `test_lane_e_pewter_gym_guide` | environment | Opens `/tmp/pokered`, not `POKERED_REFERENCE_DIR`. | none |

## The 13 host failures

| # | Test | Class | Why |
| --- | --- | --- | --- |
| 1 | `test_capture_followup` owned flag / field draw | fixture | The owned-before-recruit string checks pass. The Lua probe’s `battle` is `{}`. `BattleScene:draw` calls `syncMessage`, which indexes `battle.machine`. Production scenes have a machine. |
| 2 | `test_cerulean_observations` projection bytes | fixture | Generated projection does not match the committed snapshot. Not a missing Cerulean rule in this pass. |
| 3 | `test_door_census` authored portals | fixture | Census only reads `doors = { }` inside `registerZone`. Pallet’s 11 doors are the door argument of the local `zone()` helper in `Source/data/maps.lua`. The count is two connections and no doors. The doors are still in that helper. |
| 4 | `test_door_census` pin corruption | fixture | The mutation `to = inventedDestination()` sits in that same helper, which the parser skips, so no `ValueError` is raised. `to = "reds_house"` is still in `maps.lua`. |
| 5 | `test_lane_g_front_end` title copyright | environment | Looks for `engine/movie/title.asm` under `POKERED` or `/tmp/pokered`. This host’s checkout is `/tmp/pokemon-host/pokered`. |
| 6 | `test_region_registrations` staged-owner drift | fixture | `tools/references/content-transforms-149/provenance.json` still pins `world/sourceMaps.lua`. The live file no longer matches, so `build` raises `transform dependency changed: world/sourceMaps.lua` before the copied-owner check. Refreshing that pin needs the SDK export those hashes belong to. |
| 7 | `test_region_registrations` `main.lua` relative | fixture | Same stale pin. The test adds `import "game/silphStory"` and expects `owner imports changed`. The dependency check fires first. |
| 8 | `test_source_map_pipeline` authored Pallet / `maps.lua` | fixture | Byte freeze of `Source/data/maps.lua`. Oak’s lab actor and the padded houses are in that file on purpose. |
| 9 | `test_substitute_art` tilefactory freeze | fixture | `Source/world/tilefactory.lua` bytes differ from the living-art freeze. |
| 10 | `test_substitute_art` mechanics producer | fixture | `Source/dev/battlePresentationContracts.lua` differs where the landed shift question replaced the old announcement. |
| 11 | `test_vermilion_acquisition` machine projection | fixture | Generated collection does not match the pin. |
| 12 | `test_vermilion_journey` generation pins | fixture | Same collection mismatch. |
| 13 | `test_vermilion_preparation` manifest sha | fixture | sha256 `537c712d…` != `1a688c48…`, the same pair as on `6e4bc90f`. |

None of the thirteen is a product bug in battle, capture, or map runtime. Two fixtures have a small patch. The byte freezes and projection pins are left alone: updating them to the current blobs would bless the drift.

## Patches for E

Both apply with `git apply --check` on this tip. They were applied here only long enough to run the tests, then taken back out. The live tree still fails those three tests.

| Patch | Tests when applied |
| --- | --- |
| `tools/notes/lane-e-capture-origin-stub.patch` | `test_owned_flag_is_read_before_recruit_and_the_field_draws_at_the_origin` passed |
| `tools/notes/lane-e-door-census-zone-doors.patch` | `InventoryTests` 7 passed, including the two failures above |

The census patch reads the `zone("…")` door argument with the same literal rules. Pallet still has 11 authored doors, which is what the test expects. `inventedDestination()` still raises `unsupported authored door fields`.
