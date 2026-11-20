# Lane K host suite on 2e7863ff

Main and E tip: `2e7863ff29b3c9593511da9112c1c2538f9f234e` (`Nest the coverage snapshot after Brine doubles below half HP`). It contains `9a33a835` and `0aaf6e2a`. `eb76d786` keeps key items out of the battle legal set. `937b9025` lands Brine. Main already fast-forwarded here. RedBot’s host score was 13 failures, 37 errors, 0 head-only names versus `9a33a835`.

This note is the same discover on the lane K host. Lane K merge `7744f7ce2113db1790b58c45d4d3478f1448e026` contains the tip. `Source/` in the merge is E’s.

Reference: pret/pokered `af519899719f0754965776faac0e836a3b906e6d` at `/tmp/pokemon-host/pokered`. There is no `/tmp/pokered`.

```sh
POKERED_REFERENCE_DIR=/tmp/pokemon-host/pokered \
KANTO_REFERENCE=/tmp/pokemon-host/pokered \
python3 -m unittest discover -s tools/tests
```

Log: `/tmp/lane-k-suite-2e7863ff.log`. Exit code 1. Runtime 120.875s. `MallocPoolSize` was not changed.

## Counts on this host

| Result | 9a33a835 | 2e7863ff |
| --- | ---: | ---: |
| Ran | 1399 | 1416 |
| Passed | 1324 | 1337 |
| Failed | 13 | 13 |
| Errors | 51 | 55 |
| Skipped | 11 | 11 |
| Expected failures | 0 | 0 |

The 51→37 error drop is RedBot’s host. It is not this host. The 51 environment errors from `docs/validation/lane-k-suite-9a33a835.md` are all still here.

## Names versus 9a33a835

Every failure name and every error name from that baseline is still present. The battle-review failure from `0aaf6e2a` (`test_no_key_item_is_usable_in_battle`) is gone. Brine’s new test is not in the failure or error list.

Four error names are new on this host, and only because those tests open `/tmp/pokered` instead of `POKERED_REFERENCE_DIR`:

- `test_lane_e_evolution_cancel_hint...test_pokered_cancels_on_b_with_no_hint`
- `test_lane_e_exp_points_text...test_pokered_page_is_two_lines_and_the_award_stays`
- `test_lane_e_healing_machine_balls...test_pokered_places_one_white_ball_per_party_mon`
- `test_lane_e_trainer_victory_text...test_gym_leaders_and_a_regular_trainer_match_pokered`

No new product failure. RedBot’s machine, which has that checkout, reported these four as passing and no head-only names.
