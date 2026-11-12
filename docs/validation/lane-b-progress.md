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
