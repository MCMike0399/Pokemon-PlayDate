# Authored sprite and map startup candidate

Prepared from exact main `6428bf33957fcca2acb20a156b0989958865e144` with
GPT-6.1 Sol at medium effort. Owns only `Source/world/spritefactory.lua`,
`Source/data/maps.lua`, this handoff and the adjacent integration patch.

`SpriteFactory.initialize()` renders the original RED/Oak/BLUE/Mom/Daisy
images once. It checks the existing cooperative budget after each RED frame
set and each NPC direction. Rendering helpers, mask code, phase arguments,
frame construction order and fallback/flip expressions are unchanged.
`AuthoredMaps.initialize()` constructs/registers the six original authored
Zones in their original order, checks the budget after each Zone, then sets
`currentZone` to Pallet. Constants and helpers remain available at import.
Successful repeated calls do nothing. Root must serialize startup; these are
not reentrant or retry-after-error APIs.

Player captures `SpriteFactory.playerStand`, `playerWalk1` and `playerWalk2`
at `world/player.lua:15–17` during import. All three are now empty import-time
tables filled in place; their captured identities survive. `SpriteFactory.npc`
also retains its import-time identity. The only assembly publication change is
copying the three finished RED sets into those tables instead of replacing
them. NPC constructors and source bindings read images later. Inspected
production callers contain no import-time capture of individual images or
Zone objects that blocks this packet. `world/zone` still owns the original
`zoneRegistry` and `zoneList` tables; neither is replaced here.

Root must apply `p0-authored-startup-main.patch` before executing this candidate.
`Source/main.lua` itself is unchanged. The patch calls `SpriteFactory.initialize()`
then `AuthoredMaps.initialize()`, each bracketed by BootTrace marks and followed
by an unconditional checkpoint. The exact insertion point is inside
`initialize`, after refresh-rate/RNG setup and immediately before
`CeruleanContent.registerPackage.begin` (base line 382). This precedes every
content install, `GameContext`, state creation and map/player creation. A
candidate without these root calls is incomplete and must not be run.

Evidence is retained at:
`/Users/burbujamc/Developer/Pokemon-PlayDate-env/evidence/p0-authored-startup-worker-20261029-01`.

The standalone `equivalence.py` there compares against the exact base using
Git, without executing Lua. It removes only function wrapping/indentation and
new yield calls from moved bodies. For sprites it additionally reverses the
three explicit `copyFrames` publications and restores the NPC-table declaration
to its original location. The result is byte-for-byte equal, which also proves
token/string/data equivalence. This publication adaptation is required by
Player's captured references. `equivalence.json` records matching SHA-256 values:

- Complete six-Zone body, including cells, NPC closures, warp coordinates and
  default-zone assignment: `cb080e96f5783deea333b052e5bf66d1ef83a688058de145ebaea75b159b3a14`.
- Ordered sprite body after publication normalization:
  `21e6eebf916bed4ecff28b586e044f299710b540610fc5209cf5736554ed17ed`.
- Exact unchanged sprite prefix (helpers, masks and grid imports):
  `276b2db65b9459dba2d10f74960eb0f8b421b7f6d58192d34b11e719993cf22f`.

Validation: SDK 3.1.2 production and full harness compile-only succeeded
(`production-stage/build.json`, `harness-build/build.json`). All 54 existing
protocol checks passed. The existing production-build, sprite-generator,
source-map-pipeline, Vermilion-preparation and parcel-journey modules ran 55
checks: 53 passed, zero skips, one failure and one error. The two rejections
are the whole-file preservation assertions
`SourceMapManifestTests.test_original_map_inputs_authored_pallet_and_renderers_are_unchanged`
(`maps.lua` differs) and
`VermilionPreparationTests.test_preexisting_input_art_and_old_manifest_entries_are_unchanged`
(`spritefactory.lua` differs). Baselines/tests were not edited. Full logs are
`host-targeted.log` and `host-protocol.log`. `git diff --check`, integration-patch
`git apply --check`, and the body-equivalence proof passed. No new tests or
Simulator contracts were added.

No Simulator or USB execution, deployment, push, delegation or hardware
acceptance occurred. No measured speed/heap/pixel claim is made. The supplied
exact trace reports 6 ms spritefactory import and 8 ms maps import; this packet
moves their allocation work into cooperative startup, rather than removing it.
Each Zone and each RED frame set remains an indivisible unit within this scope.
Root must integrate the calls, run protected-pixel comparison and the exact
runtime smoke under the unchanged 16 MB pool, measure startup slices/heap, and
perform hardware acceptance separately. The game is not yet playable on
Playdate hardware.
