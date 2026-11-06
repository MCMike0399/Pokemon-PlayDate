Current status: superseded by [source-warp-host.md](source-warp-host.md).
The old map-specific geometry patch is retired; generic shared preparation is
implemented and host-checked. The evidence below remains historical.

# Silph source geometry preparation

Branch: `t3/repair-silph-source-geometry`. C remains inactive. This checkout
merged exact C `e7249cf459a19296e6573040c23c8272a04934ff`, Copycat
`8a4a8e4acc17b52f5adcc5ea01a89212dbd99c42`, and driver
`a7196459e9c8246ab26bfbda86a921785d72ae57`, preserving the newer root owners.
Assembled base before repairs: `729ca6be6cef36abc7a35f8e615ad123e47320cd`.
The frozen B checkout was not edited. No push, delegation, Simulator, device,
USB, live journeys, runtime locks, acceptance or main ledger work was performed.

## Committed source repairs

- `1af97719`: derive each door's tileset from its pinned map header. Only 11F
  uses INTERIOR; floors 2–10 use FACILITY. Previously 11F block `$20` was
  incorrectly decoded from FACILITY (faced foot `$19`, wrong open geometry).
- `e56ca9ad`: use the existing decoder's `extra_blocks` seam to generate two
  callback-only cells under `silphStory/tiles.json`. The existing shared cache
  generator consumes that SHA256-pinned auxiliary record. Base map palettes,
  grid ordinals, rows, collision bytes and decoded source records stay exact.
- `9b173968`: qualify the unused 11F warp in source-derived scene metadata and
  split Giovanni's route at the actual closed door. Open it from `(6,14)`,
  facing up, before entering trigger `(6,13)`. No facing check was weakened.

Added atlas keys:

- `pokered:FACILITY:cell:24-25-24-25`: callback block `$5f`, right quadrants.
- `pokered:INTERIOR:cell:5d-5d-5e-5e`: 11F callback block `$20`, bottom quadrants.

The first fixed door pose `(18,8)` left now sees `$24` after reconciliation.
The corrected 11F pose `(6,14)` up sees `$5e`. All twenty closed projections and
both exact facing checks pass the host batch. The source's normal open blocks
remain `$0e` on floors 2–10 and `$03` on 11F.

## Exact Blue proof

Every one of 63 consumed files is SHA256-checked and byte-compared with Git at
`af519899719f0754965776faac0e836a3b906e6d`; hashes live in the generated
`Source/data/silphStory/provenance.json`. Relevant source:

- `data/maps/headers/SilphCo11F.asm`: INTERIOR.
- `scripts/SilphCo11F.asm`: closed `$20` at block `(3,6)`, triggers `(6,13)` /
  `(7,12)`. `engine/events/card_key.asm`: faced `$18` / `$24`, plus 11F `$5e`.
- `engine/overworld/player_state.asm`: the bottom-left faced-tile probe and
  `IsPlayerStandingOnDoorTileOrWarpTile`.
- `data/maps/objects/SilphCo11F.asm`: President `(7,5)`, fixed Beauty `(10,5)`,
  unused LAST_MAP warp `(5,5)`. These declarations are all retained.
- `data/tilesets/door_tile_ids.asm`: INTERIOR has no door tiles.
  `data/tilesets/warp_tile_ids.asm`: INTERIOR warp feet `$15,$55,$04`.
  The unused cell is land-passable foot `$1f`, not a warp/door tile.
- `home/overworld.asm`, `CheckWarpsNoCollision` / `ExtraWarpCheck`: on INTERIOR,
  a non-door/non-warp cell can trigger only at an outward-facing map edge.
  `(5,5)` is interior, so its declaration never fires in Blue.

Thus the President failure is a real imported-map policy defect: converting
that dormant declaration into a solid barrier closes the source route. Beauty
is correct and stays. Conditional source topology reaches `(6,5)` from `(6,12)`
through `(5,12)` up to `(5,5)`, then right, with Beauty and the source warp
retained. A fixed actual-input route is prepared; no teleport is introduced.

The 9F return-pad preflight origin was also wrong: the actual 5F pad arrives at
`(17,15)`, not `(4,5)`. Existing driver warp reentry already steps off/back on;
only the host assumption needed correction.

## Unapplied root hooks

`geometry-root-hooks.patch` passes `git apply --check` on this checkout. It is
unapplied because shared world owners and the driver are outside this worker's
edit scope. It contains four bounded changes:

1. Driver: walk to `giovanni-door-approach`, use the real Card Key from `(6,14)`
   up, then walk `giovanni-trigger`. Replace the old post-battle door attempt
   with `president-approach`, followed by the existing real President pickup.
2. Shared cache generator: for the exact source-qualified inert event, restore
   its decoded floor collision in compact metadata. Keep the original source
   event, coordinates, LAST_MAP destination and manifest declaration.
3. SourceMaps: classify that exact verified event as `inert`, before resolving
   LAST_MAP. Do not manufacture a destination.
4. SourceBindings: admit the verified inert warp status while creating no live
   transition for it. The source declaration stays enumerated.

Root must review/apply these hooks, regenerate the existing shared cache, and
refresh its private journey/source-map projections. The world hooks have only
patch applicability verification; no SDK execution or behavior acceptance is
claimed. The worker added no SDK cases or journey contracts. If root qualifies
the new inert status, extend one existing source binding SDK behavior case.

The preflight deliberately retains the real President barrier failure. Its
separate source-topology and fixed walking checks are explicitly conditional
on these root owner hooks; they do not grant passability to the live game.

## Verification and remaining conditions

Evidence directory:
`~/Developer/Pokemon-PlayDate-env/evidence/silph-source-geometry-20261030-01/`.

- `geometry-before.json`: original 214 checks / 17 blockers.
- `geometry.json`: corrected 234 checks / six blockers/conditions, expected exit 1.
  Twenty closed door projections, both facing poses, fixed walking legs and
  source topology are included in this single batch.
- `preservation.json`: all 171 compact map descriptors/runtime records, all
  binary cell caches and all 799 existing atlas tiles are byte/value-exact.
  Only the two cells above are added; decoded Saffron inputs are byte-exact.
- Silph generator and shared map/cell cache reproduce exactly with `--check`.
  Python compilation, `git diff --check` and root patch applicability pass.
- Focused Silph/gym/guard/manifest checks: 18 pass. Expanded run: 28 of 29 pass;
  the inherited `SourceMapExtensionTests` fixture fails because the unchanged
  `Source/dev/sourceMapFixture.json` has 109 maps, versus the required 172
  installed-plus-witness maps. This pre-exists the repairs and is root-owned;
  the failing log is retained as `host-tests.log`.
- Seven C boundary host checks and 54 existing host protocol checks pass.
- `compile/build.json`, `compile/build.log`, `C-inactive.pdx`: production compile
  only, SDK 3.1.2. C activation/root hooks are absent; this is not a playable C
  bundle or acceptance evidence.

The six remaining rows are: President shared inert binding; two elevator
arrivals `(20,0)` requiring existing live Silph scripted bindings before map
construction; Route16 east-to-upper-gate and Cut-index conditions; accepted B
import binding. Route16 Cut is already prepared separately in `6dc256f1` and
was not duplicated. B acceptance and actual saves must be bound by root, never
fabricated. Root still owns native actor, door, pad, elevator, rewards,
Save/Continue, source fixture refresh and device/performance acceptance.

The preflight's immutable C source ref is `9b173968` (the repaired Source tree);
its local route and driver hashes are recorded independently. After applying
root hooks, update that ref only to the reviewed integrated commit.
