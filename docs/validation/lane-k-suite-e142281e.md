# Host suite at e142281e

Main and `origin/cursor/lane-e-integration` are `e142281e` (nest after `8ac1bebd` “Let a fainted lead see its bench before the shift question”). Parent product commit is `6704ab56`, which asks the shift question after ChooseNextMon and keeps the learn-box name on the next page. Lane K merge of this tip is `a265adfc`. Reference is pret/pokered `af519899719f0754965776faac0e836a3b906e6d` at `/tmp/pokemon-host/pokered`. `POKERED` is unset. No Playdate SDK.

```
POKERED_REFERENCE_DIR=/tmp/pokemon-host/pokered \
KANTO_REFERENCE=/tmp/pokemon-host/pokered \
python3 -m unittest discover -s tools/tests
```

Log: `/tmp/lane-k-suite-e142281e.log`. Runtime 113.150s. Exit 1.

| | ran | pass | fail | error | skip |
|---|---:|---:|---:|---:|---:|
| ff64287c | 1420 | 1352 | 9 | 48 | 11 |
| e142281e | 1421 | 1355 | 7 | 48 | 11 |

The extra test is `test_question_follows_the_player_replacement`, added on lane K after the `ff64287c` discover. Both shift tests pass:

- `test_lane_k_shift_slots` `test_fainted_lead_still_asks_before_the_next_foe`
- `test_lane_k_shift_slots` `test_question_follows_the_player_replacement`

`6704ab56` returns `forcedSwitch` while the foe is still fainted, then `finishRound` prints the YES/NO after that replacement. `8ac1bebd` makes `eligibleForcedReplacements` return the living bench for a fainted lead. Whirlwind still fails on a fainted target.

`test_name_is_on_the_following_page_before_yes_no` passes. The opened page stays `CHARIZARD is` / `trying to learn`, and `FLARE BLITZ` is the next page before YES/NO. `test_lane_e_learn_pages` `test_live_box_reaches_every_page_before_yes_no` passes. `tools/notes/lane-e-learn-box-name.patch` stays unapplied. The old fail name `test_opened_box_names_the_move` is the renamed test, not a deleted assertion that E turned green by putting the name on page 1.

No new fail or error names. The three Cerulean/Vermilion projection fails cleared by `200fe950` stay gone. `3cf06230` regenerated `Source/dev/vermilionJourney.json` and did not clear the Vermilion preparation freeze.

Still red:

- `test_lane_g_front_end` `test_title_mons_do_not_cover_the_copyright` (this host; reads `POKERED` or `/tmp/pokered`)
- `test_region_registrations` staged-owner and staging-race drift (stale SDK provenance `content-transforms-149`)
- `test_source_map_pipeline` original map inputs / authored Pallet freeze
- `test_substitute_art` living art freeze and mechanics producer schema
- `test_vermilion_preparation` preexisting input art and old manifest entries

The 48 errors are the same missing-SDK, `~/Developer/Pokemon-PlayDate-env`, and `/tmp/pokered` names as `ff64287c`.
