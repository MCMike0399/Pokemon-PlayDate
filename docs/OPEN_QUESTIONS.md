# Open questions

This note is the lane E handoff at `52650bc2`. It records decisions that are still open, the checks that were red on that commit, and the branches and patches that have not been pulled. Nothing in this file changes the game.

## Decisions waiting on Miguel

### (a) The daycare fixture

`Source/dev/sessionFixture.lua` lines 7-11 are Miguel Quintero's commit `df8406b2d` (2026-10-29). For a save version below 4, that builder clears `fieldTravel`, `safari`, and `coins`. It leaves `hallOfFame` and `playTime` in place.

`Source/domain/sessionCodec.lua` does not accept those two fields on an old save. Lines 131-136 say Hall of Fame teams arrived after the private v4 saves, and an older version cannot contain the field:

```lua
local hall = data.hallOfFame
if data.version < 4 then
    assert(hall == nil, "legacy session cannot contain a hall of fame record")
    hall = HallOfFame.empty()
```

Play time has the same rule a few lines later (`sessionCodec.lua:145-147`): a version below 4 cannot contain `playTime`.

The daycare suite on this commit is 18 passed and 2 failed, heap 13037.219 KiB, session `5190734b3448421c9e59350f9ba026dc`. Both failures are that hall-of-fame assertion, at `Source/dev/daycareContracts.lua:383` and `:409`. The fixture was not edited.

Question: may `SessionFixture.forVersion` clear `hallOfFame` and `playTime` for versions below 4?

### (b) Main-merge policy

`main` is still `bf92c4fc`. This branch was not fast-forwarded onto it.

Question: may `main` fast-forward when the only failures were already failing on `main` and nothing new breaks, or only when every check passes?

## Red gates at 52650bc2

These device suites were run one Simulator at a time on `52650bc2`. 109 of 129 passed. The ones that did not:

| suite | result | passed | failed |
| --- | --- | --- | --- |
| persistence | fail | 25 | 1 |
| world | fail | 15 | 1 |
| viridian-slice | fail | 12 | 2 |
| capture-animation | fail | 12 | 1 |
| pewterProviderContracts | fail | 7 | 4 |
| pewterInstallContracts | fail | 0 | 1 |
| brock-field-items | fail | 5 | 3 |
| cerulean-catalog | fail | 101 | 116 |
| comprehensive-catalog | fail | 3 | 4 |
| move-failure | fail | 14 | 1 |
| source-maps | fail | 8 | 15 |
| source-events | timed out while still marked running |  |  |
| cerulean-content | fail | 108 | 1 |
| cerulean-ambient-dialogue | fail | 26 | 2 |
| field-world | fail | 13 | 1 |
| vermilion-gifts | timed out while still marked running; the Simulator died before a score |  |  |
| daycare | fail | 18 | 2 |
| vermilion-catalog | Simulator was killed during startup (exit 143); no child score |  |  |
| npc-trades | fail | 43 | 6 |
| field-travel | fail | 2 | 1 |

The host suite, `python3 -m unittest discover -s tools/tests`, ran 1368 tests in 158.072 seconds: 6 failures, 6 errors, and 11 skipped.

`tools/build.py` exited 1. The first error was `transform dependency changed: domain/party.lua`. The Kanto pin also differs for `game/sourceEvents.lua`, `data/ceruleanContent.lua`, `world/sourceMaps.lua`, and `domain/party.lua`. Neither provenance file was edited by hand.

A harness boot on the same tree did pass the 14000 KiB budget. `title.visible` was sequence 46 at 1089 ms. `initialize.ready` was sequence 377 at 10680 ms. The sampled peak was 12820.637 KiB. `MallocPoolSize` stayed 16645684.

## Unmerged branches

YellowBot did not push `main`. These branches fast-forward `bf92c4fc` and were not pulled.

- F: `cursor/lane-f-audio` at `01d20480`. Its audio edits leave the coverage-matrix source fingerprint stale. That fingerprint has to be regenerated through its generator. `pdc` compile fails in that environment.
- G: `cursor/lane-g-front-end` at `18c11ded`.
- H: `cursor/lane-h-postgame` at `7b1f1925`.
- B: `cursor/lane-b-south-loop` at `c87e503d`. Three commits on that branch change ownership and still need a pokered audit before they are applied: `5c27a3f8` (Route 22 rival start in `Source/game/ceruleanRoutes.lua`), `4e1f7fc6` (release the scripted walk in `Source/game/eventState.lua`), and `4a42e55b` (cave encounter contract). Audit `5c27a3f8` against `scripts/Route22.asm` and `4a42e55b` against `TryDoWildEncounter`.
- I: `cursor/lane-i-device-perf` at `a5e69338`.

## Unapplied patches

These live on lane B and are not applied on this branch, except the battle-message hold, which is already here.

- `tools/notes/lane-e-x-items.patch`, with `tools/tests/test_lane_e_x_items.py`. X Accuracy, X Attack, X Defend, X Speed, and X Special are still `effect = "unsupported"` in `Source/data/items.lua`.
- `tools/notes/lane-e-learn-pages.patch`. `LearningState:showAsk` does not page the trying-to-learn text.
- `tools/notes/lane-e-trainer-lease.patch`. `EventState:startTrainer` does not release a scripted walk before the trainer claim.
- `tools/notes/lane-e-battle-message.patch`. This branch already keeps a finished dialog page up for 10 frames in `Source/ui/dialog.lua` (`pageShown` and `shownFrames`). That behavior is not an open gap here. The patch file is still the lane B copy.

## Stashed edits

Four edits were tried and did not get a passing score, so they were stashed and not committed. The stash is `stash@{0}` on this branch, message "unscored memory follow-ups: atlas collect, source-map scope, cerulean inventory, catalog step gc".

- `Source/world/tileRegistry.lua`: collect after evicting a terrain atlas, before the next atlas inflates.
- `Source/dev/sourceMapContracts.lua`: collect at the start of a map scope, and collect while walking every production zone.
- `Source/dev/ceruleanContentContracts.lua`: build the thirty-map inventory from the shared definition and collect after each map.
- `Source/dev/vermilionCatalogContracts.lua`: step the garbage collector between sampled tiles instead of a full collect on every row.

## Playthrough status

These are the latest pause-saves recorded on the other branches. They are not saves on this branch.

Bulbasaur, from lane B `docs/validation/lane-b-progress.md` at `c87e503d`: sequence 422 is the Pause-Save in the Cerulean Poké Center at `(3, 3)` facing up. `BADGE_EARTH` is set. `EVENT_BEAT_ROUTE22_RIVAL_2ND_BATTLE` is unset, so the second Route 22 rival has not been beaten. Earth is the eighth gym badge. Giovanni's win that set it was saved earlier, at sequence 174.

Charmander, from lane I `docs/validation/lane-i-progress.md` at `a5e69338`: sequence 207 is the Pause-Save in the Cerulean Poké Center at `(3, 3)` facing up. The badges in that save are Boulder, Cascade, Marsh, Rainbow, Soul, and Thunder. That is six badges.
