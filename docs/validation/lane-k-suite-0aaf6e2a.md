# Lane K host suite on 0aaf6e2a

Scored tip: `0aaf6e2ada599d2b4f352cc4db641ffa08a4fff6` (`Record BlueBot's r21 Pallet approval on main 9a33a835`). It contains `main` `9a33a835df5777f600d683b69afe2b212afac480` and the six commits between them: Lane I handoffs (`db8107f0`), learn-page and X-item handoffs (`f301b743`), the `9a33a835` baseline note, the Pallet r21 note, and two coverage nests.

Lane K merge `2230b888425246308a7ebfcd553c093f7b327b93` contains that tip. The discover ran on that merge. `Source/` in the merge is E’s.

Reference: pret/pokered `af519899719f0754965776faac0e836a3b906e6d` at `/tmp/pokemon-host/pokered`.

```sh
POKERED_REFERENCE_DIR=/tmp/pokemon-host/pokered \
KANTO_REFERENCE=/tmp/pokemon-host/pokered \
python3 -m unittest discover -s tools/tests
```

No Playdate SDK, no `PARCEL_BUNDLE_SOURCE`, and no `~/Developer/Pokemon-PlayDate-env`. `MallocPoolSize` was not changed. Log: `/tmp/lane-k-suite-0aaf6e2a.log`. Exit code 1. Runtime 115.929s.

## Counts

| Result | 9a33a835 | 0aaf6e2a |
| --- | ---: | ---: |
| Ran | 1399 | 1415 |
| Passed | 1324 | 1335 |
| Failed | 13 | 14 |
| Errors | 51 | 55 |
| Skipped | 11 | 11 |
| Expected failures | 0 | 0 |
| Unexpected successes | 0 | 0 |

Passed is `ran - failed - errors - skipped`. Sixteen tests were added. Eleven of them passed. Five are new reds.

## Baseline reds still present

All 13 failures and all 51 errors from `docs/validation/lane-k-suite-9a33a835.md` are still in this run. No baseline name cleared.

## New head-only failure

`test_lane_e_battle_review.LaneEBattleReviewTest.test_no_key_item_is_usable_in_battle`

This test passed on `9a33a835`. It now fails because `Source/battle/battle.lua` legal set is

`local legal={heal=true,fullRestore=true,cure=true,revive=true,pp=true,statStage=true}`

and the test still requires the string without `statStage=true`. That field is the X-item handoff in `f301b743`.

## New head-only errors

These four modules are new on this tip. Each dies opening `/tmp/pokered/...`. The checkout for this suite is `/tmp/pokemon-host/pokered`. The same path pin already errors `test_lane_e_pewter_gym_guide` on the baseline. These names are new.

| Test | Missing file |
| --- | --- |
| `test_lane_e_evolution_cancel_hint...test_pokered_cancels_on_b_with_no_hint` | `/tmp/pokered/data/text/text_3.asm` |
| `test_lane_e_exp_points_text...test_pokered_page_is_two_lines_and_the_award_stays` | `/tmp/pokered/data/text/text_2.asm` |
| `test_lane_e_healing_machine_balls...test_pokered_places_one_white_ball_per_party_mon` | `/tmp/pokered/engine/overworld/healing_machine.asm` |
| `test_lane_e_trainer_victory_text...test_gym_leaders_and_a_regular_trainer_match_pokered` | `/tmp/pokered/scripts/PewterGym.asm` |

## FF call

No. `main` `9a33a835` cannot fast-forward to `0aaf6e2a` under no-new-reds. The battle-review failure is a product assertion that passed on main. The four `/tmp/pokered` errors are new names on the same host that scored `9a33a835`.
