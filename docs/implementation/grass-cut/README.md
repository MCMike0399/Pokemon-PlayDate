# Grass Cut completion for private 5.4

Current follow-up: [grass clock and catalog](timing-catalog.md), based on root
`61891d7`, supersedes the original timing/catalog notes below.

Exact parent: `095598fe59b56a4db9c943dbf6b057f33d89b48e` (65 source maps,
field/scene readability cleanup). Branch: `wip/cut-grass`.
This packet is implemented and compile-checked, **not native/campaign accepted**.

## Primary rule and exact footprint

All inputs come from clean pokered `af519899719f0754965776faac0e836a3b906e6d`.
The added files match that checkout and are checksum-pinned alongside the existing
field inputs. At this revision there is no symbol named `CutDownGrass`:
`engine/overworld/cut.asm:UsedCut` accepts OVERWORLD facing foot tile `$52`, then
calls `ReplaceTreeTileBlock`, the same block-address routine used for trees.
It computes the block containing the facing cell from direction and X/Y block
alignment. `CutTreeBlockSwaps` includes `$0b -> $0a`.

The actual OVERWORLD block bytes are sixteen `$52` grass tiles for `$0b` and
sixteen `$2c` ground tiles for `$0a`. Thus one aligned **32x32 source-pixel block**
changes: **2x2 movement cells**, each 16x16 source pixels (64x64 Playdate pixels).
The facing cell can be any of the four quadrants. The player may stand inside
that block; the footprint is not centered on the player. No 3x3 expansion, generic
`terrain.grass` sweep, single-cell substitution or synthesized tile is used.
Unknown grass blocks fail generation for review rather than acquiring a recipe.

There are 255 exact grass block sites across the ten installed grass-bearing
OVERWORLD maps; Route6 has 45. Four additional imported-map primary inputs
(Route1/22/3/4) cover the remaining installed OVERWORLD inventory. All fourteen
installed OVERWORLD maps have source identity/dimension guards; the existing GYM
entry retains its tree-only rule. Authored Pallet has no source recipe.

`InitCutAnimOAM` loads `MoveAnimationTiles1 tile 6`, identified independently by
`engine/battle/animations.asm` as `gfx/battle/move_anim_1`. The generated leaf is
the exact 8x8 source tile. Four leaves retain original X/Y flips, color-zero
transparency and palettes `$e4`/`$80`. `cut2.asm:AnimCut` supplies four eight-frame
sweeps: X adjustments `+1,+2,-2,-1`, top/bottom OAM pair swaps after each sweep,
and a two-pixel drop after each sixteen-frame pair. Generated presentation frames
record these positions; rendering uses explicit dither phase `(0,0)`. The final
post-frame drop is not presented separately, matching the lack of another source
DelayFrame. Terrain art comes from existing exact source grids.

The original `SFX_CUT` call is recorded with its file/symbol provenance. There is
no substitute sound; playback remains with the audio owner.

## Owners, guards and lifetime

`FieldMoves` retains opaque requests and all original party/session/position/
roster/member-record/world/actor guards. Cascade and the actual owned known move
are required. A fainted user and zero PP are legal; field use consumes no PP or
RNG. The grass subtype alone permits the player's occupancy within its changed
block. NPC reservations, source events, native doors, unresolved bindings and
changed source quadrants reject the whole request. Tree occupancy and replacement
recipes are retained.

`FieldMoveState` selects the grass leaf effect and commits after its 32 native
logical presentation frames. As with the existing tree effect, this intentionally
commits later than pokered, permitting cancellation without terrain side effects.
Native frame timing/visual alignment still need root review; compile-only does
not establish wall-clock timing fidelity. Tree and Flash frame counts stay 8/3.
A bounded defensive effect snapshot avoids copying the full map inventory during
each effect draw/update; callers still receive defensive public data.

Publication still uses `game:commitFieldTerrain` -> `FieldMoveWorld.commit` ->
`WorldDeltas.apply` plus atomic session `captureTraversal`. No direct tile,
collision, session-data or player-position assignment was added to production.
`FieldMoves.reloadWorld` now recognizes complete exact grass replacements as well
as tree replacements. Existing `FieldWorld` departure/reload and detached Continue
projection already call this API, so **no FieldWorld, session or codec edit is
needed**. Grass restores under the retained player location, with ordinary
passable collision and the existing Player grass overlay/step lifecycle. Menu and
battle returns keep the cut surface. Partial/foreign replacements and unrelated
deltas remain intact. No new save field, persistent flag or second ledger exists.

## Integration and checks

Cherry-pick this bounded branch onto the exact parent (or compose only its owned
paths). All grass/ground keys, metadata and grid pixels already exist identically
in the parent's shared cache: **no cache publication or renderer patch is needed**.
No maps/cache, protected art/baselines, GameSession/codecs, battle data, main,
shared dev imports, ledger or coverage files were edited.

The only returned shared patch is `root-integration.patch`: two harness registration
lines for `GrassCutContracts`. It is unapplied and passes `git apply --check` on
the parent. Root should update any explicit ordered-import baseline at integration.
Alternatively add `tools/grass-cut/sdk_imports.lua` to a private harness overlay.
The final private compile stage includes that registration; its source fingerprint
and paths are recorded in `compile-only.json`.

Executed, with the normal environment loaded:

```sh
python tools/generate_field_moves.py --check
python -m unittest tools.tests.test_field_move_data tools.tests.test_grass_cut_data tools.tests.test_field_world_data -v
git apply --check docs/implementation/grass-cut/root-integration.patch
```

Result: **17 host tests passed, zero skips**. These check primary pins/dispatch,
source block and leaf grids, bounded map inventory, deterministic generation,
exact existing shared-cache art/terrain, original tree pairs, source effect
snapshots/cue provenance and existing field-world schema boundaries. They execute
no Lua emulation, transpilation or SDK stand-in.

Production and the privately registered harness stage both compile with real
**SDK 3.1.2**. Retained artifacts:
`~/Developer/Pokemon-PlayDate-env/preparation/grass-cut-095598f/final-production`
and `.../final-sdk/GrassCut.pdx`. No runtime or Simulator was launched.

`Source/dev/grassCutContracts.lua` prepares **14 actual-SDK contracts** using real
Zone/provider/world/session/party, state, Player and disk save owners. Coverage:
all four facing quadrants; standing inside the cut block; no adjacent-block
mutation; badge/known-owned-move checks; fainted/zero-PP and zero rules/world RNG
change; 32 presentation frames/one-shot commit; confirmation and interrupted-effect
cancellation; stale member records and actual NPC occupancy; source NPC surfaces,
map edge and real Underground Path warp refusal; injected native-view rejection;
session rejection *after native application*; menu/no-entry battle lifecycle and
an actual BattleState terminal return; actual reload restoring grass/overlay under
Player and step-off; public save/decode/Continue; unrelated delta preservation and
partial-block refusal. Fixtures restore the real runtime/provider/view/sprites.
These contracts are compiled but **have not been executed**.

Root retains native contracts, motion/visual/source-phase inspection, protected
catalog comparison, campaign journeys, process restart acceptance, performance/
memory observation and device testing. No push or delegation occurred. Existing
native/campaign acceptance and the frozen Cerulean worktree remain root-owned.
