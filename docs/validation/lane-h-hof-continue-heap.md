# Hall continue heap

Lane E `232d44525a3135e795a286045dbcee2dbb29a649` (source parent `45d1022790674d67ecb804c9780b1aacf6b7ab78`). SDK 3.1.2. `MallocPoolSize` stayed `16645684`. No `Source/` edit is committed on this branch. The release is `tools/notes/lane-e-hof-continue-release.patch`. Each continue is one fresh Simulator process, `--recent-interval 18000`, so the 12 KiB capture image is not allocated. `LinuxResidentGuard` is not attached.

Hall save `adventure.a.json` sha256 `8e72131fa1b88f59d3192a82a2e2d3da856ccf3b725b6860ccc69dcbc95d1cc1` (3343 bytes). Location `pokered:HALL_OF_FAME`, one Hall team (Blastoise 65). Ordinary save sha256 `b7703d8597442286f36c2e3296ab2ab244545e268bcc6a14374317b61a1dd767` (3260 bytes). Location `pokered:PALLET_TOWN` (5, 6) down, `hallOfFame.teams` empty, same Blastoise. Both fixtures are under `tools/tests/fixtures/`.

## Continue.end

`Continue.end` is the boot-trace heap, before a later full collect. Ready on these boots is 12580 KiB.

| continue | Continue.end KiB | full collect KiB |
| --- | ---: | ---: |
| ordinary Pallet | 13405.8 | 13286.5 |
| Hall, before the release | 13564.1 | 13422.0 |
| Hall, after the release | 13389.0 |  |

The unpatched gap at `Continue.end` is 158.3 KiB (13564.1 − 13405.8). After a full collect the gap is 135.5 KiB. The patched Hall continue marks `Continue.end` at 13389.0 KiB (session `702501c1d64b43a3ab541c29f92601ee`; an earlier patched boot was 13386.1). That is under the ordinary continue. The ordinary path does not take the new collect, because nothing was released.

## What the Hall continue keeps

Title inspect decodes the saved map. For the Hall save that is Hall of Fame, then continue builds Pallet Town and `setupOverworld` already drops the Hall zone. At `Continue.end` the imported cache is only `kanto_pallet_town` on both saves. `KantoScores` on both is the title theme. `EndgameStory.drawCredits` is nil on both. `CreditsPlayer` is the `main.lua` import on both.

Measured by nilling one root and collecting. Hall full-collect baseline 13422.0 KiB. Pallet full-collect baseline 13286.5 KiB.

| leftover | KiB | still held after the patch |
| --- | ---: | --- |
| Hall of Fame runtime definition (`retainedRuntime` `HallOfFame`) | 16.3 | released |
| postgame `story.json` and `play.json` | 19.5 | released; the next script loads them again |
| `postgameStory` module and the event handlers it installed | 99.9 | kept; Mew and Mewtwo call them |
| Hall zone object and its tilemap | 0 | already released before `Continue.end` |
| Hall photo images | 0 | `photoImage` does not run on a fresh continue |
| `creditsDraw` | 0 | not `file.run` on a fresh continue |
| `creditsPlayer` | 0 | present on the ordinary continue too |
| `credits` and `hall_of_fame` scores | 0 | not loaded; the title score is on both |

The 99.9 KiB is what remains after the definition and the JSON cache are dropped (13386.4 − 13286.5). A fresh continue does not keep the ceremony pictures or the credits roll. Those lived in the previous process.

## Walk

Unpatched, four steps east from Pallet (5, 6) land on (9, 6). The heap check is what fails. The earlier signal 11 was the next step north, at about 13857 KiB, with a capture image also in the pool.

With the patch applied on `232d4452`, the same Hall save walks 30 real steps from Pallet onto Route 1. Encounters are off. Session `702501c1d64b43a3ab541c29f92601ee`, outcome ok, no `runtime-error.json`.

| steps | command | result |
| ---: | --- | --- |
| 5 | `move right 5` | Pallet (10, 6) |
| 6 | `move up 6` | Pallet (10, 0) |
| 1 | `move up` | edge door, then Route 1 (10, 35) |
| 4 | `move up 4` | Route 1 (10, 31) |
| 2 | `move left 2` | Route 1 (8, 31) |
| 5 | `move up 5` | Route 1 (8, 26) |
| 7 | `move right 7` | Route 1 (15, 26) |

## Test

`tools/tests/test_lane_e_hof_continue_releases_hall.py`

On unpatched `232d4452` it fails: Hall `Continue.end` 13564.1 KiB is 158.3 KiB above the Pallet continue 13405.8 KiB. After `git apply tools/notes/lane-e-hof-continue-release.patch` the same test passes, and the four east steps finish at Pallet (9, 6).
