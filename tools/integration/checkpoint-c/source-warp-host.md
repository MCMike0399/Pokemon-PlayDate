# Source warp host preparation, 2026-11-02

C remains inactive and unaccepted. Implementation follows exact research
`46793da1a4da52feeb45b2bb2434ca50fd556715`. Separate synchronization merge
`cb7625072e5bca707b642d3c4fa3c48b5899a424` joins main
`bbb42aaadc41a0db3904eb83d27d83270cd704d4` and isolated C
`8203e1192ad77a559305ebccd9c0d4f74e777c40`, without conflicts. Only this
worktree was edited. The owned implementation commit can be cherry-picked
alone onto Root's existing C branch after equivalent main synchronization.

## Implementation

The existing compact generator consumes checksum-pinned Blue door/warp lists,
tileset constants, ExtraWarpCheck, player-state and door routines. Dependencies
and exact hashes are in `../../references/source-warps/manifest.json` and
[source-warp-validation.json](source-warp-validation.json). Existing vendored
files are reused; only three small missing ASM files were added. Every consumed
reference was byte-compared with Blue `af519899719f0754965776faac0e836a3b906e6d`.

Classification is standing tile, otherwise function2, otherwise original map
edge, otherwise non-triggering. Function2 is deliberately unevaluated: its
front-tile, direction and Bow behavior are preserved. All five map overrides
are retained, including SS_ANNE_3F's function1 override over SHIP.

B149: 510 declarations = 220 standing + 82 function2 + 208 edge + zero inert.
C171: 637 declarations = 325 standing + 82 function2 + 228 edge + two inert.
The 63 interior-coordinate B declarations without standing tiles remain live
classification candidates: 44 OVERWORLD, 12 SHIP, six FACILITY, one SHIP_PORT.

The only inert IDs are `pokered:SILPH_CO_11F:warps:3` at source (5,5),
INTERIOR foot $1f, and `pokered:SILPH_CO_1F:warps:5` at (16,10), FACILITY
foot $01. Compact metadata retains source coordinates, cell key, tileset,
foot and `function1_interior` proof. SourceMaps uses that private lookup before
target resolution, verifies the enumerated declaration and returns inert status.
SourceBindings accounts for that warp ID but emits no door; inert on objects,
signs, connections or other non-warp bindings is rejected. Unknown/missing/
duplicate checks remain. Bound status cannot disguise a scripted or inert warp.
No source event, destination or LAST_MAP context was rewritten or invented.

The reviewed manifest correction removes only 11F warp3 from blocked_events.
Explicit blocked/scripted sets must be disjoint from non-triggering metadata.
Inert declarations are excluded before unavailable-target blocking, LAST_MAP
inference and barrier propagation. There is no late collision deletion or
Silph-scene dependency in the shared classification generator.

The C manifest preparation reuses the existing checksum-pinned elevator rows:
11 floor entrance IDs plus both cabin exits. Existing 15 scripted IDs remain;
there are now 28. Floors 3 and 5 retain byte2 -> event3 -> (20,0). Runtime
resolver registration, elevator selection and durable location validation are
unchanged. Registration does not override saved collision.

## Preservation and generated changes

All 171 raw map records, source events/order/coordinates/destinations, grids,
source collision and binary cell payloads are exact before/after. Binary headers
and runtime projection headers receive the new whole-manifest hash. All 149 B
manifest entries and binding inputs are exact; every B descriptor is exact apart
from its empty non_triggering_warps dictionary. The earlier C Route16 cell208
opening is retained; this task makes no additional B collision change.

Exactly 14 compact blockers disappear, with no added blockers:

- 11F cell96 (inert floor) and cell14 (elevator).
- Floors 1–5 cell21, floors 6–9 cell19, floor10 cell13 (elevator).
- Cabin cells45 and46 (scripted exits).

1F inert warp5 had no blocker; its ordinary door is now omitted. President,
Beauty, floor art and the original unused declarations remain untouched.

Shared map/cell caches and the existing private source-map extension fixture
were refreshed. The fixture staging now copies its already-required pinned
callback tile input. No driver or journey contracts were added or changed.

The existing terrain atlas pipeline had not been refreshed for C and rejected
source tileset constants containing digits. Its identifier check now accepts
those constants. Regeneration produces 23 tables / 795 frames / 666 unique
images (previously 18 tables / 626 frames). All 629 previously indexed stable
keys have identical grids and native-size pixels after frame-index remapping.
All 801 shared canonical grids are exact. Added frames derive entirely from
existing decoded inputs; no art was authored. Native compiled atlas and capacity
qualification are still required, especially for the enlarged C inventory.
Existing content-cache bytes and all canonical B acceptance/hash authority,
producer exports, chain saves, schemas and protected authored art are unchanged.

## Host checks and limits

The focused run covers source classification/preservation, manifest/cache
regeneration, source-map extension, Silph/gym source projections and shipped
map mutation rejection. The final exact count is recorded in
[source-warp-validation.json](source-warp-validation.json). C inventory audit
passes and preserves prior B record checksums. Map/cell, terrain atlas, Silph
and Copycat generators reproduce. Both combined activation and separate C-only
patches apply-check; the Copycat alternative composes after the C-only patch.

A broader 26-check run (nine eligibility, seven C boundary, ten content-cache)
had 24 passes and two inherited content-cache failures: the B-only round-trip
expectation excludes the already-present Fly text, and the B-only pin test seeks
Saffron inputs in old commit d858032. Those tests and all content-cache inputs
are byte-identical to the synchronized baseline. They were not relaxed.

Existing qualification pins/exports remain unchanged. Declaration generation
rejects `transform dependency changed: data/sourceMaps.json`; no replacement
SDK export or qualification was fabricated. One existing SourceMapContracts
case was extended for the actual two inert surfaces, accounted IDs/no doors,
invalid binding rejection, durable location checks and scripted floor3/floor5/
cabin semantics. It was neither compiled nor executed.

No SDK/compiler, Simulator, runtime, GUI, USB/device, global locks, delegation,
push, whole suite, journey replay or whole-game acceptance was performed.

## Minimal Root integration

1. Synchronize Root's one existing C branch with exact main bbb42aaa (or a
   newer main retaining it), then cherry-pick only the owned implementation
   commit supplied in the handoff. Do not cherry-pick the sync merge.
2. Do not apply the retired geometry-root-hooks.patch. Generic geometry is
   already implemented. Runtime imports/activation remain UNAPPLIED. Use either
   activation-root-hooks.patch, or C-only root-hooks.patch followed by Copycat's
   root-hooks.patch. Keep SilphStoryWorld imported before MidgameStoryWarps.install.
3. Obtain genuine current SDK transform exports and refresh the existing
   declaration/Kanto qualifications through the normal pipeline. Existing pins
   must continue rejecting stale composition until that happens. Refresh Root's
   private C journey projections through existing tools; no journey was run here.
4. Compile and execute the extended existing SDK case, then qualify actual
   President access, ordinary 1F floor traversal, warp pads, every elevator
   entrance/selection/arrival (especially floors3/5), stale/invalid saved collision
   rejection and Save/Continue. Retain the three earned B ancestry boundaries.
5. Existing native visuals, capacity/memory, performance, hardware and campaign
   gates still precede C activation/acceptance. This host packet grants none.
