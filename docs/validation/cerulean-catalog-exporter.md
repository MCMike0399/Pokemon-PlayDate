# Cerulean catalog exporter handoff

The implementation starts at exact private integration commit
`e890839f0050563147ad96dc52a74b0393883895` (the 30-map activation on
`cbe8f02`). Main and its 2494-image reviewed baseline are unchanged by this
worker. New art remains **unreviewed** until the root exports and inspects actual
native images and runs protected-preservation comparison.

## Inventory and ownership

`CeruleanCatalogExporter` registers the named `cerulean` exporter with the
existing `VisualCatalog` protocol. It declares **2448 additions**, hence **4942**
images including the protected 2494. Every declaration includes stable filename,
width, height, category and explicit mask flag. Declarations are newly allocated
plain data, derived from immutable installed inputs, never the live provider LRU,
current flags, installed actor images or numeric palette allocation order.

| Family | Source units | Images |
| --- | ---: | ---: |
| New canonical terrain keys, image and mask | 154 | 308 |
| Full opaque source actor strips, mask and three backgrounds | 28 | 140 |
| Source actor frames, production mask and three backgrounds | 124 | 620 |
| Standing/walking/alternate directional poses, mask and backgrounds | 240 | 1200 |
| Terrain, spawn viewport, collision, actors, events/connections | 18 maps | 90 |
| Tutorial full source art, mask and backgrounds | 5 | 25 |
| Tutorial review-strip masked frames and backgrounds | 13 | 65 |

The 240 poses include every available source pose in all four facing directions.
Static actors have standing poses only; fixed clipboard/fossil/Old Amber/ball
images explicitly reuse their fixed down frame. Missing walking art is never
invented. Metadata preserves the original source path, checksum, frame index,
mirror policy and native tick ranges. Full strips are opaque source contact
strips in original frame order; individually masked frames preserve production
transparency. Every source object appears on the actor overlay, including
mutually exclusive scene alternatives. That overlay is an inventory, not a
claim that all those actors are simultaneously visible during play.

Terrain paths use the existing reversible `tile_imported_<UTF-8 hex key>`
convention. New content uses `cerulean-<Map>-<layer>`,
`cerulean-strip-<SPRITE_CONSTANT>`, `cerulean-frame-<SPRITE_CONSTANT>-<index>`,
`cerulean-pose-<SPRITE_CONSTANT>-<pose>-<direction>`, and
`cerulean-tutorial-<name>[-frame-<index>]`. Assets include `__mask`, `__white`,
`__black`, `__texture` where declared. Maps have no synthetic mask/backgrounds.
All map event and connection records retain their stable IDs and source/runtime
coordinates, with current binding diagnostics. The 21 pinned hidden-event targets
also appear with `H` labels, source handler/argument and stable per-map indices;
external hidden-dispatch readiness is explicitly not inferred. Bill's PC remains
the source target (1,4), with runtime padding added only for drawing. This exporter does not execute
scene programs or add imperative trigger-region overlays.

Pewter's compact facade now sees all thirty maps. The legacy exporter therefore
projects only the twelve accepted Viridian/Pewter palettes from shared compact
metadata, without loading regional map geometry. These are the same **145** keys
and metadata as the frozen cache (canonical JSON SHA256
`fb7622c5ef2f96385441c9c437e02e36775d8b7add871ef749aa318fe3e851c0`).
Its ownership predicate claims only those two profiles. The new exporter claims
only source-profile zones, the 154 keys outside that legacy projection, and the
28 `CeruleanContent.key` NPC names. It claims no protected paths or shared legacy
actor art. Pewter's **859** declarations and its two-phase **1718** native-image
qualification remain intact. The comprehensive suite's first total assertion is
extended by exactly the explicit new exporter inventory; no comparator,
quiescence, baseline or qualification changes are included.

## Native rendering and purity

All maps use `SourceMaps.isolated`, which calls the shared production
`createZone` with a private `TileRegistry` and `isolatedCatalog=true`.
`WorldView(zone,{attach=false}):render()` exercises the production tilemap path;
each view is disposed on success or failure. Maps are complete even when never
visited or after eviction because construction does not read/materialize the
live provider. No provider installation, live Zone registration, global palette
allocation, actor installation, flag access, RNG, timer or display-list changes
are part of export. Actor overlays never evaluate visibility predicates or
Story calls. Binding data/resolvers must already be installed by the root.

World poses and actor overlays use the pure production
`CeruleanContent.poseImage` policy without installing NPC images or populating
its walking cache. BLUE standing poses reuse `SpriteFactory.npc.rival[direction]`
exactly; BLUE strides use the pinned strip with greyhair mapping and the legacy
omitted-phase renderer, as explained below. Other new actors retain
`SpriteFactory.makeSprite(grid,{0,0})` and `SpriteFactory.flipped`. Raw strip/frame
exports retain four-shade explicit-zero rendering as provenance. Tiles use `TileFactory.renderGrid` at
explicit zero phase. Tutorial old-man back, Weedle, gambler, asleep gambler and
youngster images use `TutorialDemoArt.image`; registration warms that renderer's
immutable image memoization at bootstrap, outside catalog commands. The writer
only reads those prepared images. Review-strip frames use
`TutorialDemoArt.actorFrame`. No gameplay `TutorialDemo` is instantiated.
The existing `CatalogRuntime.guard` remains the authority for live-state purity
and failed-export restoration.

## Root registration (separate integration edit)

After the root's content/scene bootstrap has installed immutable resolvers and
before any catalog/contracts command, add these development-only lines after
the existing Pewter exporter registration in `tools/harness/dev_imports.lua`:

```lua
import "dev/ceruleanCatalogExporter"
CeruleanCatalogExporter.register()
import "dev/ceruleanCatalogContracts"
Contracts.register("cerulean-catalog", CeruleanCatalogContracts.run)
```

The worker does not change that file or any production imports. Registration
requires the production tutorial art modules already imported by
`game/tutorialEscort`. Never register an exporter during another export.
The new SDK suite runs 22 groups: inventory, actor coverage, each of eighteen
private maps, actual named-writer pixels/purity, and explicit failure paths.
It checks every new tile and unflipped source-frame pixel against independent
literal dither bits and mask connectivity, all emitted pose images/masks,
tutorial source pixels/masks, and map cell/collision samples. During export it
replaces actor installation, walking-cache access, live materialization, RNG,
timer creation, Story reads and actor visibility predicates with failures.
It restores those temporary test probes even if export fails. The existing
comprehensive suite continues writing its original before/after 859-image pair.

Run the identified harness catalog and contracts on the composed root revision.
Retain evidence under `~/Developer/Pokemon-PlayDate-env/evidence/`. Require
producer quiescence and all declared PNGs, then use the existing comparator in
protected-preservation mode against `docs/validation/catalog-pewter`. Review all
new source families and native map/actor overlays; preserve the baseline.
The host helper `tools.tests.test_cerulean_catalog_inputs.inventory()` independently
returns path/dimension/category/mask declarations for the 2448 additions if the
root wants to check the completed manifest against source inputs.

## Worker verification and limits

Host checks under the project environment passed: the five new independent
pinned-input/Pillow groups plus seven existing comprehensive-catalog groups and thirteen existing native-publication
qualification host groups (25 total).
They check exact PNG pixels for all 28 actor strips, all source terrain
quadrants, all five tutorial source images, explicit dimensions/counts, absence
of overlap with all 2494 protected names, and the frozen legacy metadata digest.
Existing tests still require all 1718 legacy qualification paths and strict
RGBA/mask comparison. These host checks do not execute or translate Lua.

A real SDK compile-only harness build passed at
`~/Developer/Pokemon-PlayDate-env/evidence/cerulean-visual-exporter-compile-20261026-01`.
The final compile with the separate registration snippet is at
`~/Developer/Pokemon-PlayDate-env/evidence/cerulean-visual-exporter-compile-20261026-03`. No Simulator, SDK Data, push, delegation, baseline rewrite or native visual
acceptance was performed by this worker. Native SDK contracts and protected
pixel equality remain root-owned pending checks.

## BLUE canonical-family preservation repair

The preservation fix starts at exact private commit
`368dbf303121639141c262b2c570dc8868a16233` on
`wip/canonical-blue-poses`. Root's `m53-private-catalog-20261026-01` inspection
found that the unreviewed BLUE standing additions differed from protected
`npc_rival_*` images by 189/244/187/187 RGBA pixels (down/up/left/right).
The protected originals were unchanged, but a second appearance for regional
BLUE violates full-game goal §1.

Production installation now stores the exact existing canonical rival image
objects for all four standing directions, including their existing masks.
Neither the protected grids nor their factories are edited. Additive BLUE walk
frames still come from the checksum-pinned `gfx/sprites/blue.png` strip
(`2134b4c3540a600f9e121b271d61e80da5b05b2ec6ff94b103a5c839bf523999`).
The world-pose helper maps white/light grey to `.`, dark grey to `2`, and black
to `#` before constructing the mask. This is BLUE's existing `greyhair` family.
It deliberately omits the renderer phase argument: the protected family uses
that legacy path, and SDK 3.1.2 established that omitted phase and explicit zero
produce different pixels. Extending that existing family is the reason for this
narrow exception; other new actors and terrain keep explicit zero phase.

`poseImage` renders world poses without installing actors or touching the live
walking cache. Runtime `stepImage` and the exporter share this policy. The
unchanged eight-tick cadence is standing on 1/4/5/8, walk on 2/3, alternate on
6/7; vertical alternate frames mirror the walk frame, while side strides retain
it (right mirrors left). Standing images are reused rather than regenerated or
retuned. Pose metadata records `greyhair`, `legacy-omitted`, canonical reuse and
native tick ranges. Actor overlays also draw the production standing policy.
All 2448 paths, dimensions, categories and mask flags remain unchanged. Raw
source-strip/frame exports and their independent four-shade Pillow checks are
unchanged. Only unreviewed BLUE logical world-pose expectations change.

Six scoped host groups pass, including a new independent pinned-input witness
that relates BLUE's source checksum, greyhair standing grids and masks to the
protected rival family, and checks additive walk grids/transparency. No Lua is
executed or translated by host checks. The existing `cerulean-catalog` SDK suite
now adds three groups for canonical object/image/mask preservation, greyhair
legacy strides, explicit-zero rendering of other actors, and installed runtime
agreement across every direction and tick. The named writer still forbids
installation, `stepImage`, live materialization, Story reads, RNG and timers;
its live-state guard covers palette/provider/model changes. Existing native
registration at `tools/harness/dev_imports.lua:153` already includes this suite;
no new import lines are needed.

Compile-only real SDK verification passed at
`~/Developer/Pokemon-PlayDate-env/evidence/canonical-blue-poses-compile-20261026-02`.
Native execution and pixel acceptance remain pending with the root. Run the
registered `cerulean-catalog` contracts, publish a fresh complete catalog, compare
all 2494 protected images, compare BLUE world stands with `npc_rival_*`, and
inspect the additive strides in motion. This worker ran no Simulator, changed
no existing PNG/baseline or primary source data, and performed no push.
