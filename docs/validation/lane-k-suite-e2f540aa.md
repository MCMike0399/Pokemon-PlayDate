# Host suite at e2f540aa

Main is `e2f540aa` (nest after `9b79d0e0` “Cap wild learnsets at pokered moves and close two battle stalls”). Lane K already had that tip at `67470c1c`. Reference is pret/pokered `af519899719f0754965776faac0e836a3b906e6d` at `/tmp/pokemon-host/pokered`. `POKERED` is unset. No Playdate SDK.

```
POKERED_REFERENCE_DIR=/tmp/pokemon-host/pokered \
KANTO_REFERENCE=/tmp/pokemon-host/pokered \
python3 -m unittest discover -s tools/tests
```

Log: `/tmp/lane-k-suite-e2f540aa.log`. Runtime 114.384s. Exit 1.

| | ran | pass | fail | error | skip |
|---|---:|---:|---:|---:|---:|
| e142281e | 1421 | 1355 | 7 | 48 | 11 |
| e2f540aa | 1425 | 1360 | 6 | 48 | 11 |

Four tests were added and all passed: `test_mt_moon_exit_reaches_cerulean_without_opening_the_cliff`, `test_pursuit_switch_clears_the_party_selection`, `test_room_entry_clears_unbeaten_trainer_bit`, and `test_trainer_sendout_drops_ids_above_165`. No new fail names. No new error names. Skip count is unchanged.

`test_preexisting_input_art_and_old_manifest_entries_are_unchanged` passes. `ed1f1b92` keeps `TileFactory.image` inside the reviewed cache section, and the test subtracts that function before the `309194ee` hash.

Still red:

- `test_lane_g_front_end` `test_title_mons_do_not_cover_the_copyright` (this host; reads `POKERED` or `/tmp/pokered`)
- `test_region_registrations` staged-owner and staging-race drift (stale SDK provenance `content-transforms-149`)
- `test_source_map_pipeline` original map inputs / authored Pallet freeze
- `test_substitute_art` living art freeze and mechanics producer schema

The 48 errors are the same missing-SDK, `~/Developer/Pokemon-PlayDate-env`, and `/tmp/pokered` names as `e142281e`.

## Gym battle-flow

Host probe against pret/pokered `af519899` gym parties Misty, Lt. Surge, Erika, Koga, Sabrina, Blaine, and Viridian Giovanni. Player was Wartortle, with a Pidgey bench where a switch is required, and Wartortle alone for whiteout. Each leader: forced switch after a faint, shift YES, shift NO, and solo whiteout (`defeat`, not a forced-switch lock). Misty Revive and Full Restore close the bag selection. The learn-prompt NO path was already clean on this tip.

No gym party learns Pursuit or Whirlwind. Koga's Koffing and Weezing learn Haze, Selfdestruct, and Explosion. Blaine's Arcanine learns Roar. Switching into each of those returns with the party selection closed. No stall and no assert, so no `tools/notes/lane-e-*.patch`.

Lane J `732df393` is still in the Cerulean Mart, buying Potions for Misty. There is no gym-fight attempt, so no Misty assist.
