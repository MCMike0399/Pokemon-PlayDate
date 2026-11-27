# Hall of Fame photo

Lane E `232d44525a3135e795a286045dbcee2dbb29a649`. SDK 3.1.2. `MallocPoolSize` stayed `16645684`. No `Source/` edit. `origin/main` is still `ea32b553`. `origin/cursor/lane-e-integration` has since moved to `79fbcba5`; this pass used the requested `232d4452`.

The reviewed clip `artifacts/lane-e/hall-photo.mp4` (sha256 `3c2e6483a6a4280cda8e1655e5113081a4e7f551ffc4e2495e1b5cbfd00da209`, 2276 bytes) is 3.000 seconds, 24 frames, 400x240, 8 fps, and every pixel is 255. `artifacts/lane-e/failure.png` is a full black 400x240 frame. That white hold is the photo preamble: `EndgameStory.drawPhoto` fills the screen white and returns while `stage == "preamble"`, and `visual.json` holds that stage for 100 frames (3.33 seconds at 30 fps).

## Verdict

The photo draws on `232d4452`. The party card, Red's card, and the credits handoff are on screen. No draw patch.

`tools/notes/lane-e-hof-continue-release.patch` and K's `tools/notes/lane-e-switchzone-release-before-build.patch` (`cursor/lane-k-qa` `f5b76b6f`) were not applied. The champion room warped to the Hall of Fame and the ceremony finished on the unmodified tree.

## Input

Session `hofphoto180713`. Journey harness profile, so the dev contract suites were not in the pool. The same Source, on the full harness, died earlier in session `hofphoto180454` at `RED defeated BLUE!` with `harness_capture.lua:22: malloc(12018) failed`. That was the capture image, before the Hall.

The fixture entered `kanto_champions_room` at `(6, 6)` with Mewtwo level 100 (Psychic, Ice Beam, Thunderbolt, Flamethrower) and the skipped intro's Squirtle starter. From there the champion script ran on button A: the rival intro, six sends (Pidgeot, Alakazam, Rhydon, Gyarados, Arcanine, Venusaur), Psychic selected from the fight menu, `RED defeated BLUE!`, Oak's walk, the warp to `kanto_hall_of_fame` `(5, 6)`, Oak's Hall text, the photo, and the credits.

## Clip

`artifacts/lane-h/hall-photo-232d4452.mp4`

sha256 `59c35b1250f0e2a8ff8df500a09d6300d7e23b1a94639d47fdd1d74aedddf8ab` (33769 bytes). 400x240, 144 frames, 6 fps, 24.000 seconds. The frames are the harness `record` buffers, played at 6 fps. Three 48-frame records, in order: the party card, Red's card, then the credits. The waits between those records are not in the file.

| still | sha256 | what is on screen |
| --- | --- | --- |
| `artifacts/lane-h/hall-party-mewtwo.png` | `8697103014d0b8b2781afbb4cc32da7d4441e7590c1b44d3d55fc5978e35009e` | MEWTWO, LEVEL 100, TYPE1/ PSYCHIC, the front pic, HALL OF FAME. 4953 black pixels. |
| `artifacts/lane-h/hall-player-red.png` | `9f62a77b3c0f3ce265f2eaded17c3705abc74be9d820bbb21c6ae8e3b155b399` | RED, PLAY TIME 0:01, MONEY ¥9435, the Red pic, POKéDEX Rating. 4581 black pixels. |
| `artifacts/lane-h/hall-credits-staff.png` | `aa03e706c4e46c9140348a69f35463bf20d642cd38515e22074005678e1fac5d` | POKéMON / BLUE VERSION STAFF, the first credits card after the photo. 32728 black pixels. |
| `artifacts/lane-h/hall-credits-director.png` | `c8f7e35510541629a191c3cded913c05e87db7e91a7756ee4bf84d76aab878fb` | DIRECTOR / SATOSHI TAJIRI, later in the same credits record. 32559 black pixels. |

The party record's first frame is the mon card before the HALL OF FAME banner. The banner is on frame 48. The credits record opens on BLUE VERSION STAFF and later shows the director line. None of these frames is a solid white or solid black field.
