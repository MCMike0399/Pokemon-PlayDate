# Host suite at ff64287c

Main and `origin/cursor/lane-e-integration` are `ff64287c` (nest after `603aac90` “Hold the battle queue on the confirm press”). Lane K merge is the commit that adds this note. Reference is pret/pokered `af519899719f0754965776faac0e836a3b906e6d` at `/tmp/pokemon-host/pokered`. `POKERED` is unset. No Playdate SDK.

```
POKERED_REFERENCE_DIR=/tmp/pokemon-host/pokered \
KANTO_REFERENCE=/tmp/pokemon-host/pokered \
python3 -m unittest discover -s tools/tests
```

Log: `/tmp/lane-k-suite-ff64287c.log`. Runtime 121.674s. Exit 1.

| | ran | pass | fail | error | skip |
|---|---:|---:|---:|---:|---:|
| 4ce45f5a | 1420 | 1351 | 10 | 48 | 11 |
| ff64287c | 1420 | 1352 | 9 | 48 | 11 |

`603aac90` applies `tools/notes/lane-e-message-queue-confirm.patch` in `Source/battle/battleScene.lua`. The A that finishes a page no longer calls `battle:handleInput`. `test_confirm_does_not_install_the_next_say` passes. Error names are unchanged. No new fail names.

The three Cerulean/Vermilion projection fails cleared by `200fe950` stay gone. Vermilion preparation freeze stays.

Still red:

- `test_lane_g_front_end` `test_title_mons_do_not_cover_the_copyright` (this host; reads `POKERED` or `/tmp/pokered`)
- `test_region_registrations` staged-owner and staging-race drift (stale SDK provenance `content-transforms-149`)
- `test_source_map_pipeline` original map inputs / authored Pallet freeze
- `test_substitute_art` living art freeze and mechanics producer schema
- `test_vermilion_preparation` preexisting input art and old manifest entries
- `test_lane_k_learn_name` `test_opened_box_names_the_move` (E left the name on page 2; sketch not applied)
- `test_lane_k_shift_slots` `test_fainted_lead_still_asks_before_the_next_foe` (diagnosed only; `finishRound` still requires a living lead)

The 48 errors are the same missing-SDK, `~/Developer/Pokemon-PlayDate-env`, and `/tmp/pokered` names as `4ce45f5a`.

Lane I `5071a6cb` and lane B `456610d5` are not on this tip. No new clips to pick up. Lane J is still `5c68af04` on Route 4, short of Cerulean, and the agent is still running, so no Misty assist.
