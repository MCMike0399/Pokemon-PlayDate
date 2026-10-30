# Additive Blue bicycle/fishing art

First useful runtime/data commit: `0b99fb5`. These assets never replace protected
RED/NPC images, register a sprite family, move actors, consume RNG or own elapsed
time. Original source inputs stay outside Git, pinned by SHA256 at pokered
`af519899719f0754965776faac0e836a3b906e6d` in
`tools/references/field-gear-art.json` (18 exact inputs).

Root applies the small, unapplied import/catalog patch:

```sh
git apply --check tools/integration/field-gear-art-root.patch
git apply tools/integration/field-gear-art-root.patch
```

It imports `world/fieldGearArt` after SpriteFactory and extends the EXISTING
MidgameCatalogExporter inventory/writer/registration. No new exporter, movement
owner or contract is introduced. Root may put the single import in its current
bootstrap if the surrounding main imports have changed. All returned images are
borrowed immutable art; use `setImage`/`draw`, never mutate their pixels/masks.

```lua
FieldGearArt.prepare() -- after PewterSprites exists; optional bootstrap warm
FieldGearArt.bicycle(facing, "stand") -- or walk / alternate; native32x32
FieldGearArt.fishing(facing)          -- native32x32
FieldGearArt.rod(facing)              -- detached {image16x16,x,y}
FieldGearArt.fishingFrame(tick, response, facing)
FieldGearArt.fishingSourceFrame(sourceFrame, response, facing)
```

Facings are `down/up/left/right`. The controller chooses bicycle poses using its
existing movement cadence; art never advances that cadence. Right mirrors left;
down/up alternate mirrors the original walking frame. Side alternate is shared
with side walk. Fishing uses the ORIGINAL RED source standing top8rows and the
original direction-specific fishing lower8rows, exactly reproducing VRAM writes
to tiles2/6/10. It does not derive/tune a new protected RED grid.

`tick` is zero-based30Hz; its sample is source frame `2*tick+1`, matching the
existing source animation sampling policy. `response` is exact source
`wRodResponse`:0 no nibble,1 bite,2 nothing here. The returned detached record has
`phase`, `sourceFrame`, `playerOffsetY`, optional `character`, `rod`, `exclamation`
and `textLabel`. Coordinates are native pixels relative to the32x32 player graphic
top-left. `rod.y` already includes the temporary shake offset.

- Ticks0..4: precast; no character override, so keep existing protected RED.
- Ticks5..54: source fishing pose/rod,100source-frame cast wait.
- Bite ticks55..69: ten source XOR1 shakes, three source frames each; native
  player/rod offsets are+2/0pixels, sampled without changing actor/grid position.
- Bite ticks70..99: existing `PewterSprites.exclamation()` at(0,-32); hide the
  up-facing rod only. The source60-frame bubble plus one refresh frame is retained
  in metadata and source-frame queries; frame200 is skipped by30Hz sampling.
- No-nibble/nothing text begins tick55; bite text begins tick100. `textLabel` is
  `_NoNibbleText`, `_ItsABiteText` or `_NothingHereText`. Source PrintText is
  input-driven: root owns acknowledgement, restoration and battle admission.

Original rod offsets from the player's graphic top-left are down(8,30),
up(8,-16), left(-16,8), right(32,8). They derive from `FishingRodOAM`, `dbsprite`,
hardware offsets8/16 and source standing playerX64/Y60. Right flips source tileFE;
down/up share tileFD. TileFF is loaded by source but unused by that OAM table,
retained as data/provenance rather than emitted as a redundant catalog image.

Characters use the existing SpriteFactory border-connected masks. Rod overlays
use original OBJ index0 transparency everywhere. Every new image renders through
legacy TileFactory character shades (LIGHT12.5%, DARK50%), explicit phase(0,0),
never the imported-terrain renderer. The existing exclamation data/image is reused
and checksum-checked, not regenerated or added to the inventory twice.

## Catalog additions and checks

29 new native assets ->145PNG outputs through the existing sink's mask and three
background composites:10distinct bicycle poses,4fishing poses,3rod orientations
and12directional cast/shake/bubble placement samples. The64x96 samples expose
original offsets/clipping/up-facing rod hiding. Their synthetic image origin is
only a contact-sheet layout, not a gameplay fixture or claimed journey frame.
Existing midgame2048 ->2193images; total8726 ->8871before other root-owned art.
No prior path, baseline or protected inventory is replaced.

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python tools/generate_field_gear_art.py --reference "$POKERED_REFERENCE_DIR" --check
# Regeneration requires an explicit fresh candidate path:
python tools/generate_field_gear_art.py --reference "$POKERED_REFERENCE_DIR" --output /path/to/fresh-fieldGearArt.json
```

29existing sprite/visual checks passed, zero skips. Independent Pillow checks
verified all six bicycle source frames, three constructed fishing frames, nine
established character-mask hashes, three source rod tiles/OBJ masks, four exact
OAM offsets and the reused emote checksum. Generator output reproduces exactly.
SDK3.1.2 compilation passed, including the returned root import/catalog patch in
a private staged tree; the actual main PDZ contains world/fieldGearArt.

Evidence is outside Git at environment `evidence/m55-field-gear-art-data/`,
`evidence/m55-field-gear-art-first-compile-01/` and
`evidence/m55-field-gear-art-catalog-compile-01/`. No native catalog/clip was run,
no asset acceptance is claimed and no new tests/contracts/baselines were added.
Root alone runs Simulator, reviews native pixels/motion and hooks FieldGearState.
No push or delegation.
