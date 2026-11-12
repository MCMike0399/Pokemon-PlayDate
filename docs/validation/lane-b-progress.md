# Lane B progress

## Pod reset

The previous `cursor/lane-b-south-loop` history was only on the old pod.
It was never pushed. This checkout came back detached at
`7a31867a52d8d1da06dd361187a29b3a93e66274`, which is `origin/main`.
The seq 62 Seafoam B2F save (`51e1eba9…`) was under `/tmp` and did not
survive. The seq 61 pair did not survive either.

What did survive is `/opt/cursor/artifacts/lane-b/`: the earlier clips
and the Fuchsia packet-1 saves. Slot A is sequence 59, sha256
`daa9a81c7b1ca2dc6273acc0f409cd119d8235999796299d11c4b54cf3286c07`,
at Fuchsia Poké Center `(3,3)` facing up. That save already has
`EVENT_BEAT_KOGA`, `BADGE_SOUL`, both Snorlax flags, the Gold Teeth
handoff, HM03, and HM04. Safari is not in progress. Those steps are
not replayed.

## Lane A 68ff3b1f

`uploads/lane-a-68ff3b1f.tar_ab45.gz` (sha256
`c1779ca1c4db82093f92e821579be043017598d9e75b9d83f90c28b58531f397`)
holds two bundles. Both `git bundle verify` clean and both require
`7a31867a`, which is in this clone.

- `lane-a-5404c2ca.bundle` sha256
  `74fdb957d0b56ad8ed6ee2d4131027970f11664c8e3c0ce05ccab40529571b99`,
  HEAD `5404c2caacaad0f6c8e21f1902b91c68267425e5`.
- `lane-a-68ff3b1f.bundle` sha256
  `99024a86e889e7defa9441a084c306fcd3076ac550517993394abb07981a9214`,
  HEAD `68ff3b1ff57a74bb7bad2e356332a036fde9ecf1`. It contains
  `5404c2ca`. The manifest has 222 maps.

`cursor/lane-b-south-loop` was created at `68ff3b1f`. That restores
Lane A's coast maps, the water-tile warp fix, the endgame, and the
legendaries. Lane A's own files were not edited except `Source/main.lua`,
which now imports and installs the coast hook beside Copycat.

`git log` and a tree search showed the missing lane B pieces: there
was no `coastStory.lua`, and the Safari runtime on this commit is
Lane A's. The Fuchsia save already records the Safari, Koga, and
Warden results, so those runtime changes were not rebuilt.

## Coast scripts

`Source/game/coastStory.lua` is the af519899 rules for Seafoam holes
and currents, Mansion switch doors, the Secret Key ball, the locked
gym door, and Blaine's six quiz gates. `CoastStoryWorld` runs the
currents, the hole falls, the door, and the default door collision.
The quiz yes/no menu is not attached, so a wrong or right answer is
not taken from the pad yet. The gym gates therefore stay closed.
Articuno's object is described here and in Lane A's late Kanto
scenes. Starting that battle still depends on a source encounter
hook, which this file does not invent.

`tools/tests/test_lane_b_coast_scripts.py` checks the button order,
landings, quiz answers, and door blocks.

## Replay from the Fuchsia save

`docs/validation/coverage-current.md` says actual earned saves stay
outside Git. The new slots are only under `/opt/cursor/artifacts/lane-b/`,
with `SHA256SUMS`.

Real button input from sequence 59 left the center, crossed Fuchsia,
and reached Route 19 `(12,9)`. Pause SAVE wrote sequence 60, sha256
`a5d19db08f2ba3133b72719d70fdff9e770d470cf30c3acb95b03f8f693f452d`
(`route19-seq60-adventure.b.json`). Continue from that file used Surf
on Poliwag and reached the west water at `(0,40)` facing left, still
surfing. Pause SAVE wrote sequence 61, sha256
`681ac2c3d3053f2bc012ea3a39b46a28c994c180f3c9e0bb773394fb6f2cc678`
(`seq61-adventure.a.json`). The frames of that crossing were 1350,
under 60 seconds, so the clip was not kept.

One more left did not enter Route 20. The block was
`connection/blocked-origin`: the bank is foot tile `$14` with collision
1, and both connection checks reject that origin. `CoastStory.surfEdge`
allows a surfing step only when both banks are that water tile.
`CoastStoryWorld` consults it before the original connection function.
Walking onto the same cell is unchanged. No badge or flag was written
by the driver. Safari, Koga, and the Warden were already in the
sequence 59 save and were not replayed.

The branch was pushed to `origin/cursor/lane-b-south-loop`. `main` was
not pushed. No pull request was opened.

## Water edge and Seafoam door

The seam commit is `e8fd776878bcb5c8b6e38d9dd28a01cfbcc5f648`, pushed
to `origin/cursor/lane-b-south-loop`. Bundle
`/opt/cursor/artifacts/lane-b/lane-b-e8fd7768.bundle`, range
`7a31867a..HEAD`, sha256
`7a980f288ffa66bd9a3d82f2cc3e7459615733e10e6f437bbaf6102bd828903a`.

Continue from sequence 61, still surfing, stepped left and arrived on
Route 20 `(99,4)` facing left. Pause SAVE wrote sequence 62, sha256
`1a15d73dbd03db283d03409a4a37e40f2fea1d33808b56d981bf7661ae1a8c12`.

The next continue surfed west along the south water. Column x=62 is
foot `$32`, which the surf rules already allow, and the step onto the
island dismounted. A wild battle on the way was run from. The player
reached the west Seafoam door, entered `SEAFOAM_ISLANDS_1F` at
`(4,17)` facing up, and the same stretch of inputs then stepped back
out. Pause SAVE wrote sequence 63, sha256
`55d1658d62b8f55ea4e99fdd9150f0fe8a38ea274ab878d3a495cc50d64d8063`,
at Route 20 `(48,6)` facing down, walking. One more up from that tile
entered the cave again. Pause SAVE wrote sequence 64, sha256
`f4cfcca443ed266d0d105891d3f9f6761d29a1965b812c9ad654278ea5a44bf1`,
at Seafoam Islands 1F `(4,17)` facing up.

The LCD clip is
`/opt/cursor/artifacts/lane-b/20261112T035203Z-route20-seafoam.mp4`,
400×240, 68.32 seconds, 2048 frames. It is the Route 20 surf and the
first entrance. No second clip of that entrance was kept.

Safari, Koga, and the Warden were already true in sequence 59 and
were not replayed. `BADGE_VOLCANO` is still unset.

The ledger commit `fc87b010df9dbce78333925c7769542a91864760` was
bundled after that push. `/opt/cursor/artifacts/lane-b/lane-b-fc87b010.bundle`,
range `7a31867a..HEAD`, sha256
`36aa696ac483d68f929d39c076f6564bd54b8557978745fe9e94fe5781f7964e`.

## Seafoam 1F Strength

Continue from sequence 64 stepped off the door and turned Strength on
with Sandshrew. A wild battle on the way was run from. Pause SAVE
wrote sequence 65, sha256
`d0bf0c504264fd782d83b8b355bc673331c571da1384f35608bcdb9b2c511ffd`
(`seq65-adventure.a.json`), at Seafoam Islands 1F `(24,8)` facing
right, walking, with Strength still on. The boulder at `(26,7)` had
not moved. The frames of that walk were under 60 seconds, so the clip
was not kept.

The next continue stood on `(26,8)` and pressed into that boulder.
The first press armed the push. The second press started it, and the
simulator then stopped:

`game/fieldTravelState.lua:185: attempt to perform arithmetic on a nil value (field 'gridX')`

`self.boulder` is the script token from `NPCMotion:claimScript`, an
empty table. The landing cell is the npc passed to `openPush`. That
file is shared, so it is not edited here. The failing test is
`tools/tests/test_lane_a_boulder_push_grid.py` and the fix is
`tools/notes/lane-a-boulder-push.patch`. `git apply --check` accepts
the patch. No boulder flag was set.

The same handoff covers the water edge. `e8fd7768` answers it from
the coast hook, and Lane A has been asked to adopt it in
`KantoWorld.connection`. The failing test is
`tools/tests/test_lane_a_surf_edge_connection.py` and the fix is
`tools/notes/lane-a-surf-edge.patch`. Both shared files are unchanged.

Blaine's quiz is the coast script. `CoastStory.quizLines` is the
af519899 question text. Pressing A on a question, facing up, opens
that text and then a YES/NO menu owned by this lane. The menu widget
is the existing `BattleMenu`; `menu.lua` is not edited. YES is the
first item. A right answer sets that gate's flag and rewrites the
gate collision. A wrong answer says "Sorry! Bad call!" and starts
`pokered:CINNABAR_GYM:objects:` plus the opponent index only when that
source event is already registered. The gym, the Mansion, and the
Volcano Badge are still ahead, because the cave push cannot finish
until the shared grid fix lands. No clip of the crash was kept.

That handoff is `6b1d3445f6b6251a4aeb4aa4224233b28bc7937b`, pushed to
`origin/cursor/lane-b-south-loop`. Bundle
`/opt/cursor/artifacts/lane-b/lane-b-6b1d3445.bundle`, range
`7a31867a..HEAD`, sha256
`47234e13798ccd23b406c8f8886a675d8b92eeff796c3d1316ae91de5a94df51`.
`main` was not pushed.
