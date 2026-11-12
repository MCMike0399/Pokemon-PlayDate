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
The ledger commit after it is `7039a6a691b3f812ba7de058c39c50306d79b8a7`.
Its bundle is `/opt/cursor/artifacts/lane-b/lane-b-7039a6a6.bundle`,
sha256 `f673abd6f7aacdf6ee54b2bf765abae27fbd00d2e6151d53a177195474116cd4`.
`main` was not pushed.

## Hourly clip

No clip. The newest earned save is sequence 65 at Seafoam Islands 1F
`(24,8)`, not the lost B2F pair. `FieldTravelState:update` still reads
`self.boulder` as the npc, so the next Strength press crashes before
a boulder moves. The B2F stair assert is a different, older block, and
those saves are not on this pod. A new recording would be the entrance
walk again or a crash under 60 seconds. `4faac7cf` is already an
ancestor. Nothing was rebased.

## Strength crash, reproduced

Continue from sequence 65 lands at `(24,8)`. `FieldTravel.enter`
clears Strength on a real map entry, including Continue, so the menu
has to turn it on again. Sandshrew did. Two steps right reached
`(26,8)`. The first press up armed the boulder (`occupied-next-cell`).
The second press stopped the simulator:

`game/fieldTravelState.lua:185: attempt to perform arithmetic on a nil value (field 'gridX')`

pret/pokered `TryPushingBoulder` moves the sprite in front of the
player, and `SeafoamIslands1F_Script` then runs `CheckBoulderCoords`
on that sprite. `NPCMotion:claimScript` returns an empty token.
`_pose` writes the landing cell onto the npc, and
`updateBoulderPush` releases the token before it returns true.
`FieldTravelState:update` stores the token in `self.boulder` and
subtracts `entry.padding` from `token.gridX`.

The shared file is unchanged. `tools/tests/test_lane_a_boulder_push_grid.py`
fails on that assignment. `tools/notes/lane-a-boulder-push.patch`
remembers `options.npc` and still evaluates `npc.gridX - entry.padding`.
It does not skip the call when the grid is missing. `git apply --check`
accepts it. No new save and no clip: the boulder does not move until
that patch is in the shared file. Sequence 65 was the newest earned
save when that note was written.

The commit that records the reproduction is
`43bd57edf7a9a70a852a3b4d9b2d45709604e5d0`. Its bundle is
`/opt/cursor/artifacts/lane-b/lane-b-43bd57ed.bundle`, range
`7a31867a..HEAD`, sha256
`d89689a586a56c09e83494ce4cada4483f0c6953d287d62ae3e2e4cda0e27c88`.

## East to Route 14 while the boulder waits

Lane A has the boulder handoff. `fieldTravelState.lua` was not edited
and the boulder was not pushed. There is no Fly user, so Pallet is a
walk. Continue from sequence 65, real button input only.

The south mouth at `(4,17)` is an edge door. Standing on it and
walking down left the cave onto Route 20 `(48,6)` facing down. Pause
SAVE wrote sequence 66, sha256
`d316cf43c42a2b7c2b15ef56eacc643892ad569b73be8842add9b68042ff44c9`
(`seq66-adventure.b.json`). Surf from `(61,5)` onto `(62,5)`, east
along the water, and one step right entered Route 19 `(0,40)` still
surfing. Sequence 67, sha256
`95b0e1a20af2a8f0f6a298873f6e321d00adbbf8817ceec5bc255707fd97859d`
(`seq67-adventure.a.json`). North onto the shore and up into Fuchsia
`(23,35)`. Sequence 68, sha256
`5cd0e00b0b72dc5b759ea25dbe54b802ea66f76b98865cd58d86035c2e9f5306`
(`seq68-adventure.b.json`). East through the city onto Route 15
`(0,8)`. Sequence 69, sha256
`95e6fb3adab522476bfa1306524d75a608137abde985c8703801cfe760c23a0b`
(`seq69-adventure.a.json`).

The west gate is a step door at `(7,8)`. Walking through
`Route15Gate1F` and out the east door returned to Route 15 `(14,8)`.
The clip starts at `(15,8)`, on the road east of that gate. It follows
the road to `(59,8)`, steps onto Route 14 `(0,44)`, and the road turns
north. Pause SAVE wrote sequence 70 at Route 14 `(16,38)` facing up,
sha256
`b418bd7ced77237885c85e559a977b7e45338516d86fcd80b9ffe012ed0c2b90`
(`seq70-adventure.b.json`). Wild battles fled. No flag or badge was
set.

The clip is
`/opt/cursor/artifacts/lane-b/20261112T044323Z-route15-route14.mp4`,
400×240 h264, 74.56 seconds, 2236 frames. Sequence 70 is the continue
point. Route 14's east edge is the way on to Route 13. Seafoam stays
where it is until the shared boulder fix is in the tree.

Pallet Town `(5,17)` down and Route 21 `(3,89)` down are the same
foot-`$14` water edge as Route 19. `KantoWorld.connection` still
returns blocked-origin there. The failing test names those two steps,
and `tools/notes/lane-a-surf-edge.patch` is unchanged. `git apply
--check` accepts it. `kantoWorld.lua` was not edited. The coast wrap
already accepts a surfing step on that pair.

The walk is `51fe47c869bd71c43c200f57e694581eb50b42a8`, pushed to
`origin/cursor/lane-b-south-loop`. Bundle
`/opt/cursor/artifacts/lane-b/lane-b-51fe47c8.bundle`, range
`7a31867a..HEAD`, sha256
`ff46c7aca9216178c55092b415f6b5f1e06aee2452dab356619ed09745d3f3e7`.

Continue from sequence 70 walked north on Route 14 to `(19,10)` and
stepped east. That cell and Route 13 `(0,10)` are both open land, so
the ordinary connection accepted the step. `(19,12)` is also open on
Route 14, and Route 13 `(0,12)` is solid, so that row was not used.
Pause SAVE wrote sequence 71 at Route 13 `(0,10)` facing right, sha256
`7e75bc65dd9f078dea2c605212d3b4228f0f3f15630bab6339ee8181fc3bc852`
(`seq71-adventure.a.json`). No second clip: the Route 15 recording
already covers this run. Sequence 71 is the continue point.

## Lane A's surf connection

`origin/cursor/linux-runtime-seams-fcc0` at `89905295` (newer than
`cfb61ea3`, and it contains `28ede555`) is merged. Shared files are
theirs. `fieldTravelState.lua` still reads `self.boulder`, so the
Seafoam return stays on sequence 65 until that fix lands.

`28ede555` skips `blocked-origin` while surfing off a surf surface, and
`PewterWorld.connection` returns the door when the arrival is surf
water. Pallet Town `(5,17)` down arrives on Route 21 `(5,0)`. Both
cells are foot `$14`, collision 1, OVERWORLD, and Pallet's connections
do not target Pallet, so that step reaches the surf arrival. The
previous patch asked for a function named `surfingWaterDoor`. This
branch does not use that name, and the patch no longer applies on top
of `28ede555`.

Route 21 `(3,89)` down is the same pair onto Cinnabar `(3,0)`. It still
fails. Any downward step on a map that has a Pallet connection returns
`nil, false` before the surf arrival. Route 21's north link is Pallet
and its south link is Cinnabar, so `(3,89)` down is dropped, and
`KantoWorld` has no Route 21 adapter after that. The test fails on that
line. `tools/notes/lane-a-surf-edge.patch` only requires
`c.direction == "south"`, so Route 1 south into Pallet still uses the
KantoSlice adapter. `git apply --check` accepts it. `pewterWorld.lua`
was not edited.

Sequence 71 has the Thunder Badge and no HM02. No party member knows
Fly, so the walk to Pallet stays on foot.

The merge and the narrowed patch are
`d6181f5d3a394f447b0d6edb66955d336f0274bf`, pushed to
`origin/cursor/lane-b-south-loop`. Bundle
`/opt/cursor/artifacts/lane-b/lane-b-d6181f5d.bundle`, range
`7a31867a..HEAD`, sha256
`35c1418b750c5863f43f459797b8fe459351bcca31a68bf00ea143d49cc5c23f`.

Continue from sequence 71 walked Route 13 to `(51,0)` and stepped
north. Route 12 `(11,107)` is open land, and the ordinary connection
accepted the step. Pause SAVE wrote sequence 72 at Route 12 `(11,107)`
facing up, sha256
`368d8198e941a95f1f4dd13a5059236a250ca3489eb82ef0ace27df7e5036c93`
(`seq72-adventure.b.json`). The clip is
`/opt/cursor/artifacts/lane-b/20261112T045913Z-route13-route12.mp4`,
400×240 h264, 75.76 seconds, 2272 frames. Sequence 72 is the continue
point. The road north is Lavender.

## Route 12 to Lavender

The hourly continue is sequence 72, not 71. The beaten Route 12 Snorlax
is already hidden, so the road at `(10,62)` is open. Real steps went
north. A fisherman at `(12,40)` facing left started a fight; the first
pass stopped in his dialog, and that walk is the clip
`/opt/cursor/artifacts/lane-b/20261112T050701Z-route12-north.mp4`,
400×240 h264, 89.64 seconds, 2688 frames. The second pass, with no
second clip, won that fight, entered Route 12 Gate 1F at `(5,7)`, left
by the north door onto Route 12 `(10,15)`, and stepped into Lavender
`(9,17)`. Pause SAVE wrote sequence 73, sha256
`a8bb26dc44c5a3726f9b520a611628569eaff4f55b12340659a79e2b9a8d36de`
(`seq73-adventure.a.json`). Sequence 73 is the continue point. The
boulder line is still `self.boulder`. Nobody knows Fly.

## Lavender to the Route 8 gate, then the drink detour

Continue from sequence 73 walked west on the only open row, y=8, onto
Route 8 `(59,8)`, through Route 8 to the east gate, and into Route 8
Gate at `(8,4)`. The guard at live `(5,3)` and `(5,4)` says he is
thirsty and pushes the player back. Pause SAVE wrote sequence 74 at
Route 8 Gate `(6,3)` facing up, sha256
`29c49596b7dafe460ece6e46142dbd27f400307bbc7f0ba0133bace32060a134`
(`seq74-adventure.b.json`). The clip is
`/opt/cursor/artifacts/lane-b/20261112T060500Z-lavender-route8.mp4`,
400×240 h264, 89.56 seconds. No Fly user, and HM02 is still absent.

The same run then left the gate east, crossed the underground path,
and bought Fresh Water on the Celadon Mart roof. Those saves are real
and stay in the artifacts. Sequence 75 is the west-east path `(47,2)`,
sha256 `c00fcc37878a4903d407f4e3d67131b31bc53f82eaf0674fc65abc35ec4a0b55`.
Sequence 76 is Route 7 `(5,14)`, sha256
`c26f0fd210a4461e621126daeb8891a840f8cc23928dbb62189d9f30d9e444ca`.
Sequence 77 is Celadon `(49,10)`, sha256
`66dcb3239396af45336dbe85eff5091121d61570c47ce1f56db0bbd6a0520dbb`.
Sequence 78 is the roof `(10,2)` facing up with one Fresh Water, sha256
`d614b643ea9d21bfa34cec0b950da510dae8de9ed2c3396fa179993b823bc460`.
The detour stops there. It is not the continue point.

## Lane A's boulder sprite, then Seafoam again

`origin/cursor/linux-runtime-seams-fcc0` at `4b26ae4a` (newer than
`8b9da209`, and it contains `2fdd0a72`) is merged. `2fdd0a72` stores
`options.npc` in `self.pushNpc` and `CheckBoulderCoords` reads that
sprite. `fieldTravelState.lua` was not edited on this side of the
merge. The journey harness continued sequence 65 without raising
`MallocPoolSize`. Lane A's note on `4b26ae4a` still says a full boot
stops in content registration with `error: not enough memory`.

The first Strength push from `(26,8)` into the boulder at `(26,7)`
moved that sprite to `(26,6)` and did not crash. Pause SAVE wrote
sequence 66 at Seafoam 1F `(24,5)`, sha256
`40247c426f268f1692b7497f3f180b04523b9ddf9c41879daaca9a677f335b11`
(`seq66-seafoam1f-adventure.b.json`). Publishing it under the old
`seq66-adventure.b.json` name replaced the Route 20 sequence 66 file.
That Route 20 file is not on disk anymore. Its sha256 was
`d316cf43c42a2b7c2b15ef56eacc643892ad569b73be8842add9b68042ff44c9`.
The checksum list no longer points that hash at a missing path. The
later Seafoam save uses a `seafoam` filename so sequence 67's Route 19
file stays `95b0e1a2…`.

The next continue pushed the same boulder left onto the hole `(24,6)`.
`EVENT_SEAFOAM1_BOULDER2_DOWN_HOLE` is set. The sprite is still saved
on that cell; `CoastStoryWorld.fall` only sets the flag, and the B1F
landing `(23,7)` does not gain a boulder. Pause SAVE wrote sequence 67
at `(26,6)` facing left, sha256
`c548107cc01ecf4dd1cada4483ea700599afa2f3eae2cbd2041d8817cefe5f03`
(`seq67-seafoam-adventure.a.json`). The Route 19 sequence 67 file was
not touched. Its sha256 is still
`95b0e1a20af2a8f0f6a298873f6e321d00adbbf8817ceec5bc255707fd97859d`.

## Save numbers and the lost Route 20 file

`tools/lane_b_publish.py` refuses to write a save onto a file that
already exists. `tools/tests/test_lane_b_save_publish.py` covers that
refusal. Sequence numbers now continue upward from the Celadon roof
save, sequence 78. The Seafoam hole envelope was rewritten to sequence
79 without changing its payload. The new file is
`seq79-adventure.a.json`, sha256
`4023f4e80cb8e753666484d40f73517cc1d398d5bd031682e6a2d0c498a579a0`.
The old envelope hash was
`c548107cc01ecf4dd1cada4483ea700599afa2f3eae2cbd2041d8817cefe5f03`.

The lost Route 20 sequence 66 file is still gone. Its sha256 was
`d316cf43c42a2b7c2b15ef56eacc643892ad569b73be8842add9b68042ff44c9`.
Replaying from sequence 65, west to the south edge at `(5,17)` and
then down, lands on Route 20 `(48,6)` facing down. The saved bytes
were `e4d91547889ba2781322bc3f90ae8be285abc055f0420424e8baf9ed747b9a9c`,
not the lost hash, so they were not restored and were not labeled
sequence 66. That replay is sequence 81, sha256
`3c07155ed988be4ef1d1169ad9be31e5412c25a32f5977dc69751e98a7e2bb65`
(`seq81-adventure.b.json`). An earlier stop on the door tile itself
is sequence 80, sha256
`71590ede33ceda1f6fa05c39ea99764483443ae2858f3622be94fbf8f93033eb`.
The two cave fights on the way to the door are the likely reason the
bytes differ. Neither clip reached 60 seconds, so both were discarded.

## The 1F hole now hides one boulder and shows the other

`CoastStory.boulderVisibility` follows af519899. The down-hole flag
hides that 1F boulder and shows the matching B1F boulder. The same
pairs continue from B1F through B4F, including the B3F toggle ids that
are not the object order. Continue from sequence 79 shows only the
1F boulder at `(18,10)`. The boulder that had been on `(24,6)` is gone.
Falling through to B1F shows `objects:2` at `(22,6)` and does not show
`objects:1`. Pause SAVE is sequence 82 at B1F `(17,7)` facing left,
sha256 `43b90d6d0ddd173ba473ef0973f5456445f436516b9085b8dc8da0459abf47c1`
(`seq82-adventure.b.json`). The clip is
`/opt/cursor/artifacts/lane-b/20261112T070033Z-route19-replay.mp4`,
400×240 h264, 68.36 seconds, 2050 frames. Sequence 82 is the continue
point. The other 1F boulder was pushed once, to `(18,9)`, and that
pose was not the saved map. Articuno, the west exit, Cinnabar, the
Mansion, the Secret Key, and Blaine are still ahead. The boulder patch
stays until those pass.

## Both 1F boulders are down

Continue from sequence 82 turned Strength back on, took the west
stairs to 1F, and pushed the remaining boulder from `(18,10)` up to
`(18,6)` and left into the hole at `(17,6)`.
`EVENT_SEAFOAM1_BOULDER1_DOWN_HOLE` is set and the 1F sprite is gone.
The fall lands on B1F `(18,7)` facing down. Both B1F boulders are
visible: `objects:1` at `(17,6)` and `objects:2` at `(22,6)`. Pause
SAVE is sequence 83, sha256
`c5a36737fecd6a7f6ce3e6b1a0b2ca5ecc14d717146c239dd4248efd67b4438c`
(`seq83-adventure.a.json`). The clip file is
`20261112T071018Z-route19-replay.mp4`, 400×240 h264, 89.96 seconds,
2698 frames. The `route19-replay` suffix is the encoder's old name.
It shows the 1F push and the B1F landing. The file was not renamed.

## Both B1F boulders are down

Continue from sequence 83 pushed the west B1F boulder right into
`(18,6)`, then the east boulder, reached by the 1F stairs, right into
`(23,6)`. The fall lands on B2F `(22,7)` facing down. Both
`EVENT_SEAFOAM2_BOULDER1_DOWN_HOLE` and
`EVENT_SEAFOAM2_BOULDER2_DOWN_HOLE` are set. Both B2F boulders are
visible: `objects:1` at `(18,6)` and `objects:2` at `(23,6)`. Sequence
84, sha256
`0ba4b33e2a6ed2d54c3c87d716ae39c9489486ea7f58ecc3699be0713382322b`
(`seq84-adventure.b.json`). The clip file is
`20261112T071603Z-route19-replay.mp4`, 89.64 seconds, 2688 frames.
Same mislabel: it shows the B1F holes and the B2F landing. The earlier
`20261112T070033Z-route19-replay.mp4` is the first B1F arrival, 68.36
seconds, 2050 frames. None of the three files were renamed. Clips from
here on use the floor in the name, such as
`<UTC>-seafoam-b2f.mp4`.

The south stairs of the east B2F room sit behind a tile pair the
walker cannot cross (`source-pair-collision`). The north stairs at
`(25,3)` are the open exit. Sequence 84 is the continue point.

## Lane A's title boot

`origin/cursor/linux-runtime-seams-fcc0` is `d87c387c`, the Hall of
Fame tip, so that tip was merged. The hourly bundle
`20261112T070934Z-lane-b-rebase.bundle` was not on this disk. The
merge is `e3d96cb7`. It brings the 16 MiB boot fix `58287e35` and
`4454003f`. The `Source/main.lua` conflict keeps the existing coast
imports and Lane A's `BootTrace.mark("import.regionStories.end")`.
No other shared file was edited. `MallocPoolSize` stays `16645684`.
`test_lane_b_save_publish`, `test_lane_b_coast_scripts`, and
`test_lane_b_searoutes` pass. The sea-routes test read pokered from
`POKERED_REFERENCE_DIR=/tmp/pokered-tip` because the default checkout
is absent. This merge is local only.

## The east B2F boulder drops, and the south row does not

Continue from sequence 84. Strength, then the east boulder at `(23,6)`
pushed left into the hole at `(22,6)`. `EVENT_SEAFOAM3_BOULDER2_DOWN_HOLE`
is set and that sprite is gone. The north stairs reach B3F `(25,3)`.
B3F shows `objects:6` at `(19,6)` and still hides `objects:5`. The east
stair from there is B4F `(26,4)`. Walking B4F did not call a field
move, so the "Seafoam field current controller is not installed" error
did not fire. The west stair returns to B2F `(4,13)`. The row above
that landing refuses the step with `source-pair-collision`, so the
west boulder at `(18,6)` stays put. Pause SAVE is sequence 85 at B2F
`(3,8)` facing up, sha256
`bbb2d5f17f4f1a0bb40dd2fe329f904e34d6abed8ff872196240b8de08697edc`
(`seq85-adventure.a.json`). The clip is
`20261112T073038Z-seafoam-b2f-b4f.mp4`, 400×240 h264, 89.96 seconds,
2698 frames. It shows the B2F push, B3F, and the B4F crossing.

## The west B2F boulder follows the B1F stairs

Sequence 85 can reach the B1F stair at `(13,7)`. That landing is B1F
`(13,6)`. The west stair `(4,2)` returns to B2F `(5,2)`, on the north
side of the pair row. Strength, then the boulder at `(18,6)` pushed
right into `(19,6)`. `EVENT_SEAFOAM3_BOULDER1_DOWN_HOLE` is set. No
B2F boulder sprite remains. Sequence 86 is B2F `(17,6)` facing right,
sha256
`a86290a9c315019013baec71d67dd1993091f7a5bb5bcf139691cf41067d25a0`
(`seq86-adventure.b.json`). The clip is
`20261112T073643Z-seafoam-b2f-b1f.mp4`, 83.44 seconds, 2502 frames.
Both `EVENT_SEAFOAM3` flags are now set. The next step is the hole at
`(19,6)`, which lands on B3F. Articuno, the west exit, Cinnabar, the
Mansion, the Secret Key, and Blaine are still ahead. The boulder patch
stays until those pass. Sequence 86 is the continue point.

## The south-row refusal is the cavern land pair

The B2F steps that stopped on `source-pair-collision` are the land
table, not a port-only wall. `data/tilesets/pair_collision_tile_ids.asm`
line 7 is `db CAVERN, $20, $05`. `home/overworld.asm` checks that table
while walking (`CheckForTilePairCollisions`, the land path near line
1239) and the water table while surfing (line 23 is
`db CAVERN, $14, $05`). The refused B2F steps were foot `$20` into foot
`$05`. Routing around them matches pokered. The port also applies the
water pair while walking; none of these refusals needed that row.

## The B2F hole drops into the left current

Continue from sequence 86. The hole at `(19,6)` is the left boulder.
The landing is B3F `(18,7)`, which is water, so the arrival is surfing.
The scripted current then runs
`scripts/SeafoamIslandsB3F.asm` lines 131–135
(`PAD_DOWN 6`, `PAD_RIGHT 2`, `PAD_DOWN 4`). The observed path is
`(18,8)`, `(18,10)`, `(19,11)`, `(20,12)`, `(20,14)`, `(20,16)`, and it
stops on `(20,17)` facing down, still surfing. Both current rocks are
visible: `objects:5` at `(18,6)` and `objects:6` at `(19,6)`. The four
pushable boulders are still there. Pause SAVE is sequence 87, sha256
`3d1c4a831854663c2f258b16e606ca33a4194262918df406875d281ba733bca4`
(`seq87-adventure.a.json`). The recording was 330 frames and was
discarded. It is not an evidence clip.

## The water stair does not fire while surfing

`(20,17)` is `SeafoamIslandsB3F` warps:6, to B4F `(20,17)`. Sequence 88
stepped off that tile to `(20,15)` and back. The warp did not fire.
`Source/game/overworldState.lua` lines 77–90 return while
`player.fieldStep` is set, and the `getDoorAt` check is at line 96.
Surf steps set `fieldStep`, so a surf landing never takes a door.
Walking cannot enter the water stair. This is the same file for every
map, so it is not patched here. The failing test is
`tools/tests/test_lane_a_surf_door.py` and the fix is
`tools/notes/lane-a-surf-door.patch`. Sequence 88 is the same pose,
sha256
`05f666d4a19955fba2944eeed8108f4c8ee40f3fc6bb6c54c04bd8c16321be12`
(`seq88-adventure.b.json`). Its recording was 342 frames and was
discarded. Sequence 88 is the continue point. The land stair at
`(8,6)` is reachable from this water without the water pair on line 23.
The step onto it stands on `(15,8)` first. That tile is the stairs
current, `scripts/SeafoamIslandsB3F.asm` lines 61–85
(`RLEList_ForcedSurfingStrongCurrentNearSteps`: down 6, right 5, down 3).
It is not a pair collision. The current ends on the same water warp.
Starting Surf while the zone is B4F still raises "Seafoam field current
controller is not installed" in `Source/game/context.lua`. That file
stays as it is. Articuno at `(6,1)` is not on the foot component of the
`(11,7)` landing.

## The stairs current was dropping its warp

Continue from sequence 88. Surfing toward `(8,7)` stalls at `(16,8)`
because the only west step is `(15,8)`, and landing there starts the
stairs current. Pause SAVE is sequence 89, still surfing, sha256
`5c35ab2ed3f81f5e13bbe31840dd7418221815bc1ac417c70871c3c29a856293`
(`seq89-adventure.a.json`). The clip is
`20261112T080139Z-seafoam-b3f.mp4`, 400×240 h264, 89.64 seconds.
`sha256sum -c` from the artifact directory is clean.

The current row already says `forced_warp`. `CoastStoryWorld` was
queueing the buttons and then forgetting the flag, so the ride stopped
on the warp the way sequence 87 did. A surf step still cannot take a
door on its own. The last button of a forced current now puts that
landing door on `pendingEdgeDoor`, which the explore loop already
handles before the field-step return. The manual surf onto the warp is
still the shared gap in `tools/notes/lane-a-surf-door.patch`. Sequence
89 is the continue point. The next step is one tile left, onto the
current.

## The stairs current reaches B4F

Sequence 90 stepped onto `(15,8)`. The ride matches the reversed RLE
and stops on `(20,17)`. `getDoorAt` misses that tile: a last-row
interior warp is stored with `edge = "down"` in `sourceBindings.lua`,
and `getDoorAt` skips edge doors. The forced warp now reads the door
list, including that edge. Sequence 90, sha256
`c9f40e86b3f514f14ee55a6a2483926b3e2f72afcbd61512cd8a165e66739a34`
(`seq90-adventure.b.json`), is still that B3F tile. Its recording was
374 frames and was discarded.

The next ride warped. B4F's exit current, which is not a forced warp,
carried the landing from `(20,17)` to `(20,15)`, still surfing. The
path toward Articuno then stepped onto land and dismounted at `(23,5)`.
Every surf step from water `$14` onto land `$05` is
`pair_collision_tile_ids.asm` line 23, `db CAVERN, $14, $05`. The
southeast pool has no other shore onto Articuno's floor. The step that
is not that pair is `(7,4)` `$14` onto `(7,3)` `$15`, and `(7,4)` is in
the pool under the B3F holes, not this one. Sequence 91 is B4F `(23,5)`
facing up, on foot, sha256
`569b3482e709568acae73e5b981410b818d6b1e8f4a10352f3216c7ecacc5062`
(`seq91-adventure.a.json`). Its recording was 1258 frames and was
discarded. Sequence 91 is the continue point. The next step is the B3F
boulder into the hole at `(3,16)`, then that hole, then the `(7,3)`
shore.

## One B3F boulder has moved

Continue from sequence 91, on foot, through the land stair `(11,7)` to
B3F `(8,6)`. Strength, then the boulder at `(5,14)` pushed left to
`(4,14)`. The next stand was still listed as blocked, so the other
pushes waited. Sequence 92 is B3F `(6,14)` facing left, sha256
`7d1acaca99faadff12628d1b59d351b946e3d3d9b8ebb6bef82a837ef568548d`
(`seq92-adventure.b.json`). The clip is
`20261112T082220Z-seafoam-b4f-seafoam-b3f.mp4`, 400×240 h264, 86.36
seconds. It shows the B4F stair and the B3F push. Sequence 92 is the
continue point.

## Articuno is one tile south, facing up

Sequence 93 finished the left hole. From `(3,14)` the boulder at
`(3,15)` pushed down into `(3,16)`. That sets
`EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE` only, so the B4F hole current does
not run. Sequence 93, sha256
`146006eb98526a39af4f338a44b5ecd03a725fe2dabfc9fedcce87da00c6086c`
(`seq93-adventure.a.json`), is B3F `(3,14)` facing down. Its recording
was 746 frames and was discarded.

The next step down lands on the hole and falls to B4F `(4,14)`,
surfing, in the pool that reaches `(7,4)`. The step from `(7,4)` `$14`
onto `(7,3)` `$15` is not line 23. From `(7,3)` the walk is up, then
left, to `(6,2)`. One press up turns to face Articuno at `(6,1)`.
Sequence 94 is that pose, sha256
`c97b4c0e58ae581b3f402e960a1086ce719f48a7555a4208476e2b290831d6e9`
(`seq94-adventure.b.json`). The clip is
`20261112T082801Z-seafoam-b3f-seafoam-b4f-articuno.mp4`, 400×240 h264,
70.64 seconds. `sha256sum -c` is clean. Sequence 94 is the continue
point. The west exit, Cinnabar, the Mansion, the Secret Key, and
Blaine are still ahead. The boulder patch stays.

## Surf on B4F raises the current-controller error

Articuno's floor is 19 land tiles and has no stair. The only step off
it is south from `(7,3)` onto water. Continue from sequence 94, walk
the floor, stand on `(7,3)` facing down, and choose Surf on Poliwag.
The confirm raises exactly:

`Seafoam field current controller is not installed`

That is `Source/game/context.lua` line 218. `context.lua` was not
patched. The simulator stopped on that error, so no new save was
written. One step left from `(8,2)` failed once, both feet `$05`,
which is not a row in `pair_collision_tile_ids.asm`. The next walk
crossed that tile, so it was a stall after a flee. The clip is
`20261112T083315Z-seafoam-b4f-surf-attempt.mp4`, 400×240 h264, 73.40
seconds. Sequence 94 remains the continue point. The west exit needs
a way off this floor that does not board Surf here.

## The B4F deny is one stair, and the port never asks

`engine/overworld/field_move_messages.asm` `IsSurfingAllowed` (lines
21–50) refuses Surf on B4F only at `(7, 11)`, and only while
`EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE` and
`EVENT_SEAFOAM4_BOULDER2_DOWN_HOLE` are not both set.
`CheckBothEventsSet` sets Z when both are set, and that path returns
with Surf still allowed. B3F is not in that function. Its forced Surf
is `CheckForceBikeOrSurf` at `(18, 7)` and `(19, 7)`, already handled
by `CoastStory.current`. `CoastStory.currentTooFast` is that B4F
predicate. `GameContext:fieldTravelRestrictions` still errors for
every B4F coordinate, so it cannot call the predicate. That file is
shared. The failing test is `tools/tests/test_lane_a_seafoam_current.py`
and the wiring is `tools/notes/lane-a-seafoam-current.patch`.

## Articuno was fought and the party blacked out

Sequence 94 stands on B4F `(6, 2)` facing object 3. Pressing A shows
`Gyaoo!` and starts the static encounter: Articuno, level 50, 150 HP,
no trainer name. `SourceEncounters` treats it like Moltres. A win,
catch, or run sets `EVENT_BEAT_ARTICUNO` and the sprite hides. A loss
does not. Venusaur's Double-Edge brought it to 53 HP. Reflect was up,
Petal Dance locked Venusaur, and Ice Beam knocked it out. The other
five fainted in turn. The battle ended `defeat` with Articuno at 49
HP. Money fell from 7808 to 3904. The party was healed at the Fuchsia
checkpoint `(19, 28)`. `EVENT_BEAT_ARTICUNO` is still clear, and the
bird is not on that map. Sequence 95 is that checkpoint, sha256
`23cfd552d5ea417bed486d8865028321b44b5cf6dd29fd99329b6b6f52f380a6`
(`seq95-adventure.a.json`). The clip is
`20261112T085538Z-seafoam-b4f-articuno-battle.mp4`, 400×240 h264,
89.92 seconds. `origin/cursor/linux-runtime-seams-fcc0` at `0c6ecb0a`
still errors in `fieldTravelRestrictions` for all of B4F, so the
current patch is not merged and the west exit was not attempted.
Sequence 95 is the continue point.

## Articuno is beaten and the party is outside Seafoam

`origin/main` `93d58071` is merged. `GameContext:fieldTravelRestrictions`
calls `CoastStory.currentTooFast`. The full coast module was kept.
The two unapplied Lane A patches are still the surf-door handoff and
the Route 21 surf edge. This VM's suite is not the 1291 result: the
ability oracle is absent, and those two patch tests still fail.

From the Fuchsia blackout the mart sold 2 Ultra Balls, 1 Full Heal,
and 1 Super Potion. Money left was 204. The return fell the open holes.
B4F `(7, 11)` is land, so a surf step onto it dismounts, and Surf
cannot be boarded there while one B4F boulder is still up. The south
pool does not join Articuno's pool. The open B3F hole `(6, 16)` lands
surfing at `(5, 14)`.

The second fight blacked out. Sequence 106 is Fuchsia `(19, 28)`,
sha256 `9c9474431bde8e80d225a0e89a6709c6faabea4f596e10a5341174e66456b26f`
(`seq106-adventure.b.json`). Money is 102. Both Ultra Balls were used.
That loss stays.

The next fight used Razor Leaf and Super Potions and did not lock
Petal Dance. Articuno reached 0 HP. `EVENT_BEAT_ARTICUNO` is set.
Sequence 111 is B4F `(6, 2)` facing up, sha256
`e4c875f2ecdb43ea26c8ba7f6198018c2f4d30a0236f3c0cb498abdbae3896b3`
(`seq111-adventure.a.json`). The clip is
`20261112T100754Z-seafoam-b4f-articuno-seafoam-islands-b4f.mp4`,
400×240 h264, 89.92 seconds.

From that save the party surfed off `(7, 3)`, landed on the stair
`(7, 11)`, and climbed B3F `(5, 12)`, B2F `(13, 7)`, B1F `(7, 5)`, and
the 1F south door. Sequence 112 is Route 20 `(48, 6)` facing down,
sha256 `7d2e1a21777db6d733a2b4f260480ed03fb4073a29c4b332da690c85af1aca51`
(`seq112-adventure.b.json`). The clip is
`20261112T101508Z-seafoam-b4f-articuno-seafoam-islands-b4f-seafoam-islands-b3f-seafoam-i.mp4`,
400×240 h264, 89.44 seconds. It shows the climb. Sequence 112 is the
continue point.

Route 20's west channel, the water that reaches x=0 and Cinnabar, does
not touch the Seafoam shore. Column x=43 is rock (`$3A`) from y=2
through y=13, and the island land has no shore onto the water west of
that column. The east channel, minimum x=62, is the Route 19 side.
Cinnabar, the Mansion, the Secret Key, and Blaine are still ahead.

## The east Seafoam door opens the Cinnabar channel

The `(48, 5)` pocket is the wrong exit. `SeafoamIslands1F.asm` sends
`(4, 17)` and `(5, 17)` to Route 20 warp 1, and `(26, 17)` and
`(27, 17)` to warp 2 at `(58, 9)`. Decoding `maps/Route20.blk` with
`gfx/blocksets/overworld.bst` matches the port: land at `(56–61, 10–11)`,
water `$14` from `(56–61, 12)`, and rows y=14–16 open west to x=0.
Column 62, y=2–9, is foot `$32`. `FieldTravel.surfSurface` already
treats `$32` and `$48` as surf on every tileset except `SHIP_PORT`.
No overworld water pair mentions `$32`. That column is the Fuchsia
side of the route, not the Cinnabar channel, and the port's collision
there matches pokered. No lane A patch.

`CheckBothEventsSet` sets Z when both flags are set, and the B3F and
B4F scripts return before they queue buttons. The coast module had
that test backwards, so `(15, 8)` still swept the party after both
SEAFOAM3 boulders were down. The current now runs only while the pair
is open. With both down, `(15, 8)` is ordinary water. The one legal
west shore is `(15, 7)` foot `$15`; the east dismount is `(23, 9)`.

From sequence 112 the party stepped back into the west door, climbed
B1F `(13, 7)`, B2F `(5, 13)`, and B3F `(15, 7)`, surfed to `(23, 10)`,
and stepped onto `(23, 9)`. B2F `(25, 14)`, B1F `(25, 11)`, and 1F
`(23, 15)` lead to the east door. Sequence 113 is Route 20 `(58, 10)`
facing down, sha256
`9a470a6468ee3172169f2549b44349a1c246eab2a42b37b651eda8089b480b98`
(`seq113-adventure.b.json`). Surf from `(58, 11)` onto `(58, 12)`,
then west along y=16, avoiding the swimmer sight on that channel.
Stepping off x=0 landed on Cinnabar `(19, 16)` still surfing. Three
steps north dismounted on `(19, 13)`. Sequence 114 is that tile,
facing up, on foot, sha256
`fbe14d4fb095617a32dcfe250b575e23f394d5fc22a1e8c3427139879af8c7fc`
(`seq114-adventure.a.json`). The clip is
`20261112T104902Z-route20-east-door-cinnabar-channel.mp4`, 400×240
h264, 89.96 seconds, 2698 frames, the LCD working image. The recorder
filled on B3F `(20, 10)`, so the file shows the surf across B3F and
not the outdoor channel. Sequence 114 is the continue point. The
Mansion, the Secret Key, and Blaine are next.

## The Secret Key, then the gym quiz

Sequence 115 is Mansion 1F `(5, 27)` facing up, sha256
`54161af74d513bad957bdc89fd9fbfba91077dd953132be369867bd87f5ffb98`
(`seq115-adventure.b.json`). The facility gates are half-blocks:
`$2d` walls its south row, `$5f` its east column, `$54` its north
row. With the switch off, 1F reaches the 2F stair and 2F reaches
`(6, 1)`. 3F does not reach a hole until the switch is on. The hole
at `(16, 14)` lands on 1F `(16, 14)`, and that tile reaches the B1F
stair only while the switch is on. B1F then needs the south statue
off and the north statue on before `(5, 12)` can face the key at
`(5, 13)`.

That walk is what the pad did. Wild battles on 2F, 3F, and B1F were
fled. The 3F statue went on, the B1F south statue went off, and the
north statue went on. A on `(5, 13)` granted `secretKey` quantity 1
and `PICKUP:pokered:POKEMON_MANSION_B1F:objects:8`. Sequence 116 is
B1F `(5, 12)` facing down, sha256
`4f6fd08ff627fab3a0f42cecbad28ec64d8d9c21c0433ef39a4a4c7b4304dc59`
(`seq116-adventure.b.json`). The clip is
`20261112T115154Z-mansion-basement-secret-key.mp4`, 400×240 h264,
89.36 seconds, 2680 LCD frames. Recording started at the north
statue, so the file includes the walk to the key. The budget filled
on the way back, at B1F `(22, 6)`.

The southeast exits `(26, 27)` and `(27, 27)` are bottom-row warps,
so they are edge doors: standing on the tile does not leave, and a
down press does. Sequence 117 is that press not yet taken, 1F
`(26, 27)` facing down, sha256
`5a8a9ee629f2b0c7249a33b2ce6c0906ffa815c4c5c55d56450f0ebe8eca796e`
(`seq117-adventure.a.json`). The down press from 117 resolved
`LAST_MAP` warp 1 and advanced through the door to Cinnabar
`(6, 4)` facing down. `CoastStory.scriptFlags` clears
`EVENT_MANSION_SWITCH_ON` on that arrival. Sequence 118 is that
tile, key still held, sha256
`011dfd4d702cb2b785ca9babb6eb5d242bb95251658131d8cd0ea94c5d4248af`
(`seq118-adventure.b.json`).

The gym door at `(18, 3)` opened with the key and landed on
`(16, 17)`. The six questions were answered YES, NO, NO, NO, YES, NO.
All six `EVENT_CINNABAR_GYM_GATE*_UNLOCKED` flags are set. The clip
is `20261112T120040Z-cinnabar-gym-quiz.mp4`, 400×240 h264, 89.76
seconds, 2692 LCD frames. It starts outside the gym and the budget
fills at `(10, 7)`, so questions 3 through 6 are after the file.
Sequence 119 is the gym at `(3, 4)` facing up, sha256
`0863638d7d6fbebb904ae7e93a7f23efc3fcc9e3ec59e91b5f238dbacab234b3`
(`seq119-adventure.a.json`). Venusaur is still level 47 with 93 HP,
and the other five are unstatused.

A on Blaine sets `lastTraversalBlock` to
`unimplemented-source-event` /
`pokered:CINNABAR_GYM:objects:1`. `scripts.json` already lists that
object as `CinnabarGymBlaineText`, "scripted trainer/reward; story
worker". No battle started, and `BADGE_VOLCANO` is unset. The badge
was not written by hand. Sequence 119 is the continue point.

## Sequence 119's delay is a STAY actor marked random

Sequence 119 does not load once the gym objects are registered.
`WorldMotionData.normalize` rejects phase `delay` unless `spec.random`
is set, and a trainer is not random. All nine saved actors are still
on the `object_event` tiles from `data/maps/objects/CinnabarGym.asm`,
facing down. Blaine is `(3, 3)`. None of them left the tile.

`SourceActors.describeSource` sets `random` for every object that is
not a boulder, trainer, or item. The gym was saved before those
trainers were registered, so the STAY objects were random.
`NPCMotion:tick` writes a wander delay for a random actor that is not
taking a WALK step. STAY is that branch. pokered `CanWalkOntoTile`
rejects STAY (`$FF`) before a step, so the sprite never updates
`MAPX`/`MAPY`. `EVENT_2A7` is set in `home/overworld.asm` after a
Cinnabar Gym battle and cleared at the start of
`CinnabarGymSetMapAndTiles`. Nothing in af519899 reads it, and this
save was taken before any gym battle.

Lane A rejected the first
`tools/notes/lane-a-cinnabar-trainer-delay.patch`, which rewrote a
saved delay to static inside `normalize` and kept the saved cell.
That would leave a STAY object off its tile if it had wandered.
The replacement patch changes only the random bit: WALK is the only
random mover. `normalize` still rejects a stationary delay. The
loadable continue was sequence 118.

## The Volcano Badge

Sequence 118 was reloaded. The Max Potion on Mansion 3F and the Full
Restore on B1F were both picked up. The quiz was answered YES, NO,
NO, NO, YES, NO. The center healed Venusaur from 93 to 147. Pause
SAVE on the island door `(11, 12)` facing down wrote sequence 120,
sha256
`96e37257cb6d39b2ed7279484358e8d81c1bcaa0b0cad148630e90b5faf25c1d`
(`seq120-adventure.b.json`). Both potions were still in the bag, and
the six gate flags were set.

Blaine's party is Growlithe 42, Ponyta 40, Rapidash 42, Arcanine 47.
Double Edge was the only attack. Growlithe was in range of one more
hit, so no potion was spent on it. Max Potion was used before
Ponyta, Full Restore before Rapidash, and one Revive after Venusaur
fainted to Arcanine. Petal Dance and Razor Leaf were not selected.
The shift prompt was declined. The result is `BADGE_VOLCANO`,
`EVENT_BEAT_BLAINE`, `EVENT_GOT_TM38`, and `tm38` quantity 1. Money
went from 102 to 4755, which is the class base 99 times Arcanine's
level. Venusaur is level 48. Sequence 124 is the gym at `(3, 4)`
facing up, sha256
`4723cff52b015a27c4bc03d1010e3602d427508db56a6f2a1a8569c6e4d08813`
(`seq124-adventure.b.json`). It loaded. The eight trainers are
`static` on their `object_event` tiles. The guide is object 9,
`(16, 13)`, STAY, and it is the one actor in `delay`. That is the
same `SourceActors` bit: a STAY object that is not a trainer is
still marked random, so `NPCMotion` stores a wander delay. The
patch covers the guide too. Applying it will reject sequence 124.

The approach clip is
`20261112T141018Z-cinnabar-gym-blaine.mp4`, 400×240 h264, 89.64
seconds, 2688 LCD frames. Recording started at the island door and
the budget filled at gym `(5, 11)`, before A on Blaine.

Sequence 122 is the pre-fight island payload republished as the
other slot of that victory write. It has no badge. It is not the
continue.

## After the badge

Sequence 124 was continued by real input. Down from `(16, 17)`
returned to the island, and the center healed the party. Venusaur
is 150/150. Sequence 125 is the center at `(3, 3)` facing up,
sha256
`9b45b239b77e95954895bd6a309973ff9bfc2fcd0de222a29b0e56af3490d0cf`
(`seq125-adventure.b.json`). The badge, the beat flag, and TM38
are still set. The exit clip is
`20261112T141909Z-cinnabar-after-blaine.mp4`, 400×240 h264, 89.56
seconds, 2686 frames. It starts in front of Blaine and the budget
fills on the island at `(18, 9)`.

`data/maps/objects/CinnabarPokecenter.asm` gives the nurse, the
gentleman, and the link receptionist STAY. Those three are in
`delay` on sequence 125. The cooltrainer is WALK and is `ready`.
Sequence 125 loads on the current code. The same patch will reject
the three STAY delays. `normalize` was not relaxed, and the save
was not rewritten.

## Main's rejection

`origin/main` at `bf92c4fc` is merged. Its ledger row rejects the
`normalize` rewrite, which keeps a saved cell and clears the timer.
That file is no longer the patch on this branch. The patch now
changes only the random bit in `SourceActors`. The lane B tests
pass, with the STAY-random case still an expected failure.

## Toward Viridian Gym

`EndgameStory.badgeValue` is 95. The set bits are Boulder, Cascade,
Thunder, Rainbow, Soul, and Volcano. `BADGE_MARSH` is unset, and
`EVENT_VIRIDIAN_GYM_OPEN` is unset. `viridian_gym.required_mask` is
127, so `EndgameStory.gymDoor` stays locked until the Marsh Badge
is on the save. Cinnabar's north connection is Route 21, then
Pallet and Route 1. Giovanni's battle is not started.

## Back through Seafoam to Fuchsia

Sequence 125 left the Cinnabar Center by real input, boarded at
`(19, 13)`, and stepped east onto Route 20 `(0, 16)` still surfing.
Pause SAVE wrote sequence 126 there, sha256
`99953f44b97952f22505555acb8e0a1e985bf054ddd9beb068f6e794470135b8`
(`seq126-adventure.b.json`). The west Seafoam door is not on that
channel. The open water reaches the east beach at `(61, 12)`.

From that beach the east door `(58, 9)` returns to Seafoam 1F
`(26, 17)`. The same boulder path that opened the door, run
backwards, comes out the west door at Route 20 `(48, 6)`. The
island land there reaches `(61, 4)`, and surfing east stops on
the map edge `(99, 4)`. Sequence 127 is that edge, sha256
`275c66d659b01cf8ab6e9e1b290262fe79413c912d64f47269ee05601fc36a53`
(`seq127-adventure.b.json`). The clip is
`20261112T144033Z-seafoam-return-to-fuchsia.mp4`, 400×240 h264,
89.64 seconds, 2688 frames. It starts on the Cinnabar channel and
the budget fills on Seafoam B3F.

One more step east is Route 19 `(0, 40)`. Surfing north, landing
at `(4, 9)`, and walking the shore column reaches Fuchsia
`(23, 35)` facing up. Sequence 128 is that city tile, sha256
`3596d9104a49252c66b51f3753496aaa99e871046db27f7a9e8e01fc14cc7b8e`
(`seq128-adventure.b.json`). The bag still has no Fresh Water,
Soda Pop, or Lemonade. `BADGE_MARSH` is still unset. The continue
was sequence 128.

## The circle at the end of the Seafoam clip

`20261112T144033Z-seafoam-return-to-fuchsia.mp4` is fully lit through
the ladders. The black circle is the last few seconds, on B3F at
the wild battle the log records at `(23, 8)`. That drawing is
`IrisOutSubstate` in `overworldState.lua`, the same circle the
battle transition has always used. `fieldMoves.json` `dark_maps`
lists only Rock Tunnel 1F and B1F. `zCoast` and `coastStory*` set
no Seafoam darkness flag, so there is nothing for this lane to
clear. Seafoam stays fully lit once the iris finishes and the
battle starts.

Clips from here start when the pictured event starts. The name is
the event, not the walk that preceded it. Sabrina, Giovanni, each
Elite Four member, the Champion, and the Hall of Fame have to be
inside the recorded minute. The Cinnabar Gym collision grid keeps
its interior `#` walls. The open cells are the quiz corridors.
Nothing in that grid is a hole through a wall, and the review
frames did not show one, so no collision test was added.

## The Route 18 gate

Sequence 129 is the east door of Route 18 Gate, runtime `(9, 4)`
facing left, sha256
`ff09532cc7ade206b53255da25c6cc5c21fd2c000c23f5ea856a95174a3318d8`
(`seq129-adventure.b.json`). The gate JSON is unpadded. Runtime x
is source x plus 2, so `(9, 4)` is source `(7, 4)`. Stepping left
through the open row leaves on Route 18 `(32, 8)`, the cycling-road
side of the building. Sequence 130 is that tile, sha256
`c2962321266d0abc320677f66a2367641ac04acd7f8abc7a0437133cf28df8ff`
(`seq130-adventure.b.json`). The continue is sequence 130.
