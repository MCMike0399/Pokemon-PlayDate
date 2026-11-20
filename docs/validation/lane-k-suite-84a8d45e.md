# Host suite at 84a8d45e

Main is `84a8d45e` (nest after `2904e985` “Announce a failed Confuse Ray when the target is already confused”). Lane K merged it at `cfea0643`. No force push. Reference is pret/pokered `af519899719f0754965776faac0e836a3b906e6d` at `/tmp/pokemon-host/pokered`. No Playdate SDK.

```
POKERED_REFERENCE_DIR=/tmp/pokemon-host/pokered \
KANTO_REFERENCE=/tmp/pokemon-host/pokered \
python3 -m unittest discover -s tools/tests
```

Log: `/tmp/lane-k-suite-84a8d45e.log`. Runtime 110.816s. Exit 1.

| | ran | fail | error | skip |
|---|---:|---:|---:|---:|
| e2f540aa | 1425 | 6 | 48 | 11 |
| 84a8d45e | 1430 | 6 | 48 | 11 |

The five added tests passed: `test_nugget_bridge_bill_and_the_rival_return`, `test_back_door_reaches_vermilion_center`, `test_center_and_mart_step_onto_misty_door`, `test_direct_confuse_announces_and_keeps_the_counter`, and `test_already_confused_target_keeps_its_counter`. No new fail names. No new error names.

`test_mechanics_producer_schema_rng_and_existing_case_names_are_unchanged` was already red. Its diff now includes the Confuse Ray guard in `Source/battle/dsl.lua`. That is the main fix, not a new test name.

Still red:

- `test_lane_g_front_end` `test_title_mons_do_not_cover_the_copyright`
- `test_region_registrations` staged-owner and staging-race
- `test_source_map_pipeline` original map inputs / authored Pallet freeze
- `test_substitute_art` living art freeze and mechanics producer schema

The 48 errors are the same missing-SDK, `~/Developer/Pokemon-PlayDate-env`, and `/tmp/pokered` names.

## Confuse Ray

`tools/tests/lane_k_confuse_ray_host.lua` runs Confuse Ray and Supersonic against a Slowpoke whose confusion counter is 2. Each move prints `But it failed!` once, and the counter is still 2 on that line. The host does not reapply confusion. `test_lane_e_confuse_ray.py` still checks the source guard.
