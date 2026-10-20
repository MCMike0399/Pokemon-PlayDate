# Pinned original-map pilot

`tools/generate_kanto_maps.py` decodes **Route 1 and a new Viridian Mart** from
`pret/pokered` revision `af519899719f0754965776faac0e836a3b906e6d`. It emits staged
plain data and terrain previews. It does not import maps into the live game,
translate assembly scripts, draw substitute NPCs, change tuned Pallet/interiors,
or claim playable campaign content. English Blue data selection preserves the
project's separate Gen V/B2W2 mechanics policy.

The reference must be explicit. Use an existing checkout/extracted archive at the
pin recorded in [kanto-source.json](../../tools/references/kanto-source.json).
The generator performs no downloads, invokes no SDK/Simulator, and reads no ROM.
Every consumed source byte is checked against that manifest or the narrowly
scoped additional pins in [map-pilot.json](../../tools/references/map-pilot.json).
A changed or unpinned consumed source fails. Source bytes are cached after hash
verification, so the output never identifies later edited bytes as the originals.

```sh
python3 tools/generate_kanto_maps.py --reference /path/to/pinned/pokered --output /private/tmp/pokemon-map-pilot-review-01
python3 tools/generate_kanto_maps.py --reference /path/to/pinned/pokered --output /private/tmp/pokemon-map-pilot-review-01 --check
KANTO_REFERENCE=/path/to/pinned/pokered python3 -m unittest discover -s tools/tests -p test_map_generator.py -v
```

Generation requires a new output directory. For this pilot, output is restricted
to `/private/tmp/pokemon-map-pilot` or siblings beginning `pokemon-map-pilot`;
Source cannot be selected as an output. `--check` rebuilds all artifacts in
memory and compares their exact bytes/inventory without writing. Missing, extra,
changed or symlinked artifacts fail; it never repairs an accepted output. Python
standard library is sufficient, including for PNG decoding/writing. Without
`KANTO_REFERENCE`, the three explicit real-reference tests skip; the remaining
host contracts still run.

Default output contains seven files:

| Artifact | Meaning |
|---|---|
| `Route1.json`, `ViridianMart.json` | Canonical cell grids, numeric map/collision arrays, source references, terrain/events/connections/encounters and script status |
| `*-reference.png` | Original 16-pixel movement cells, opaque 2-bit grayscale, source shade ordering |
| `*-native.png` | 32-pixel cells, opaque 1-bit fine-dither preview using the current protected Shade patterns |
| `manifest.json` | Source revision and consumed checksums, generator checksum, rendering contract, artifact checksums/lengths and summary counts |

The reference and native previews are separate comparison surfaces. Neither is a
preservation baseline for existing tuned art or a live game screenshot. No
sprites are included: original sprite IDs/movement declarations remain explicit
unmapped data, and must use an existing or separately pinned character mapping.
Terrain has no transparency/alpha mask. PNG input is strictly non-interlaced,
2-bit grayscale; chunk CRCs, filters and dimensions are checked. PNG output uses
metadata-free stored deflate so fixed inputs produce identical bytes without
encoder-version metadata.

## Coordinate contract

One original graphics tile is **8×8 pixels**. A `.bst` block is a row-major **4×4
array of tile IDs**, covering **32×32 original pixels**. Each `.blk` byte selects
one block. Map constants/header dimensions count blocks, while object/sign/warp
coordinates count **16×16 movement cells**. Therefore a source block expands to
**four** current cells, not one: each quadrant combines four 8-pixel tiles into
one canonical 16×16 `.12#` grid, then the current renderer's scale produces one
32×32 Playdate image. One whole original block occupies 64×64 Playdate pixels.

For source movement cell `(x,y)`, block width `Wb`:

```text
layoutOffset = floor(y/2)*Wb + floor(x/2)
blockID = layout[layoutOffset]
quadrant = 2*(y mod 2) + (x mod 2)       # 0 TL, 1 TR, 2 BL, 3 BR
cellTile[r,c] = blockset[16*blockID + (2*floor(quadrant/2)+r)*4 + 2*(quadrant mod 2)+c]
```

The resulting cell tile list is `[top-left,top-right,bottom-left,bottom-right]`.
Static land collision probes the **bottom-left** tile against the source tileset
passable list. It does not classify walkability from an image's darkness.
`collision` is 0 for static land-passable and 1 for blocked. Each grid also
records the numeric foot tile, grass/counter/warp flags, and a source-water tile
candidate. Ledge jump pairs and tile-pair prohibitions remain explicit directed
metadata; a binary collision array does not execute them or NPC collision.

Macro arguments are already unpadded source coordinates. The original object
macro's encoded +4 offset is for its surrounding buffer, not content padding.
Warp macro arguments are X,Y even though encoded bytes store Y,X; destination
warp numbers are externally 1-based. `LAST_MAP` remains
`{kind:"last_outdoor_map",warp_index:2,resolved:false}` for Mart exits. The
pipeline refuses invalid source event coordinates, unknown named destinations
and nonpositive warp indices. A dynamic last-map destination is intentionally
unresolved rather than guessed to be a fixed map.

Primary implementation: [map/object macros](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/macros/scripts/maps.asm),
[block expansion/collision](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/home/overworld.asm),
[foot probe](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/engine/overworld/player_state.asm),
and the complete [coordinate research](../research/kanto-content-inventory.md).

## Data interface and expected counts

Map JSON contains:

- `dimensions`: block, cell, original pixel and Playdate pixel dimensions.
- `grids`: a dictionary array with numeric 1-based local IDs, stable source IDs,
  four numeric source tile IDs, 16 canonical rows, canonical-shade checksum,
  opacity and foot-derived terrain metadata. Deduplication uses all four source
  tile IDs, preserving source identity even if two graphics happen to look alike.
- `tile_ids` and `collision`: rectangular row-major numeric arrays.
- `source_refs`: per-cell compact triples `[layoutOffset,blockID,quadrant]`;
  X/Y are supplied by the array position. The field order is declared in JSON.
- `events`: stable IDs plus original coordinates, indices and fields for warps,
  background events and NPCs. Sprite mappings and dynamic destinations are
  explicitly unresolved.
- `connections`: original direction/target/offset in **block units** and the
  macro's `-2*offset` movement-cell entry adjustment. Traversal is not executed.
- `encounters`: selected Blue source pointer, separate grass/water rate bytes,
  all ten ordered level/species slots for a nonempty table, and exact integer
  weights `[51,51,39,25,25,25,13,13,11,3]/256`. A rate byte is not relabeled as a
  percentage or silently substituted for current encounter rules.
- `script`: source path/checksum and referenced event/script-state symbols with
  an explicit unimplemented status. Route 1's sample Potion and Mart's
  parcel-before-shop state machine are not implemented by these references.

| Map | Blocks | Cells | Distinct cell grids | Static passable cells | Grass cells | Warps/background/NPCs | Native preview |
|---|---|---|---:|---:|---:|---|---|
| Route 1 | 10×18 | 20×36 | 15 | 553 | 104 | 0/1/2 | 640×1152 |
| Viridian Mart | 4×4 | 8×8 | 16 | 33 | 0 | 2/0/3 | 256×256 |

Generation consumes 26 pinned source files. These counts are declaration/terrain
facts, not proof that every passable cell is reachable or a story action works.
Route 1's sign `(9,27)` selects layout byte 134, block `$08`, bottom-right
quadrant `[46,47,56,57]` hex; its foot `$56` is blocked. The decoded shade raster
hash is `f31adf65be1d1ec73c573d4aebaf0fda4270dbd58b6b286604a8af982b45a249`,
matching the independently reviewed earlier coordinate example. Original NPC
positions `(5,24)/(15,13)` and Mart `(0,5)/(5,5)/(3,3)` remain unchanged.

A known malformed-length source case is deliberately rejected:

```sh
python3 tools/generate_kanto_maps.py --reference /path/to/pinned/pokered --output /private/tmp/pokemon-map-pilot-invalid --maps UndergroundPathNorthSouth
# exit 1: layout dimensions mismatch: 92 bytes vs 4x24; no padding exception
```

No map file is written for that failed request. This is an explicitly permitted
diagnostic selection; other nonpilot maps are rejected. The importer never
silently pads the known short Underground layout or consumes adjacent data.

## Suggested runtime seam — not implemented

Keep a deep `MapSource.decode(mapId,referencePin) -> MapDefinition` module separate
from rendering/state mutation. The current generator establishes that plain-data
contract. A later `Zone.fromMapDefinition(definition,tileRegistry,eventResolver)`
adapter can allocate atlas indices, install explicit collision/terrain and bind
stable events. That is a proposed interface for review, not existing runtime code.

The required small extensions are concrete:

1. A tile registry accepts canonical grids through the existing
   `TileFactory.renderGrid`. Allocate imported image indices independently of
   current authored CODES/NUM_TILE_TYPES. Local map IDs cannot be passed directly
   as current factory IDs 1..37: that would invoke unrelated grass/roof behavior.
2. A numeric Zone construction path accepts validated `tiles`, `width`, `height`
   and **explicit collision/terrain**. It must not rerun the current CODES/SOLID,
   roof-composite or grass-scatter transforms on imported palette indices.
3. Actor/event resolution owns NPC image mappings, directed ledges, counter
   interaction, dynamic `LAST_MAP` exit handling, original flags and script
   transactions. Imported visual IDs are not gameplay semantics. Existing
   authored Pallet/interiors remain their own adapter with unchanged bytes.
4. Small-room presentation uses explicit `contentOrigin` padding applied equally
   to tiles, collision, objects, signs, warps and script coordinates. Suggested
   Mart framing is 2 cells left, 3 right, and 1 bottom void row: 13×9 displayed
   cells, with source origin `(2,0)`. Its exit source `(3,7)/(4,7)` becomes
   `(5,7)/(6,7)`, with room for the preserved edge-exit arrow below. This framing
   is a review candidate; generated source data/previews remain unpadded.

The authored Pallet north gap is X=9,10 at Y=0. The central Route 1 south corridor
is source X=10,11 at Y=35; its X=9 foot tile `$3a` is blocked. Original Route 1's
south connection offset is 0, which would preserve source X. A deliberate adapter
seam is therefore needed for the customized Pallet: **north +1 cell**
`Pallet(9,0)→Route1(10,35)`, `Pallet(10,0)→Route1(11,35)`; inverse **south −1**.
Do not shift or regenerate either entire map. Record this as an intentional
connection adaptation and check arrivals/facing/story gates in the Simulator.
Existing pre-Oak grass triggers must still intercept the first departure; the
new seam must not bypass the starter/rival sequence.

The native renderer reproduces the protected 8-row LIGHT/DARK byte patterns at
output-pixel resolution, with 2× cell-shape scaling and phase `(0,0)`. LIGHT stays
12.5% black; DARK stays 50%. Tests compare the pattern bytes to current
[Shade](../../Source/lib/shade.lua); actual SDK pixel equivalence is a separate
root-owned acceptance check using
[TileFactory.renderGrid](../../Source/world/tilefactory.lua) and the installed
SDK 3.1.2 `graphics.setPattern`/`image.new` semantics. Changing pattern density to
smooth a generated preview is not permitted.

Root-owned SDK3.1.2 probes found that omitted `setPattern(pattern)` phase and
explicit `setPattern(pattern,0,0)` produce different LIGHT/DARK pixels. Whole
fills, split rectangles and actual TileFactory uniform grids reproduce this;
the deeper SDK cause is unproven. Explicit zero matches these preview byte
vectors. A staged runtime adapter therefore requests explicit zero only for
imported registry grids, preserving the original renderer path for authored
art. The previews remained unchanged. Root's fresh SDK comparison passed with
zero changed pixels for Route1 (640×1152) and ViridianMart (256×256), including
opacity. See [accepted terrain evidence](accepted-world-foundation/acceptance.json).

## Verification and limits

Fifteen tests passed with the explicit reference, covering all five PNG filters,
CRC/alpha/format rejection, quadrant order/bounds, missing tile references, hash
tampering and frozen source reads, Blue selection, exact dither densities,
production pattern bytes, invalid grids, event bounds/dynamic exits, check-only
mutation/inventory rejection, real map counts/sign checksum, known layout-length
failure and byte-identical complete regeneration. Generated terrain previews
were visually inspected; they show the Route 1 layout and Mart room, without
actors. This does not replace root comparison through the actual SDK renderer.

The runtime terrain/mutation adapter is integrated: all 128 then-current SDK
contracts and seven integration jobs passed, including all natural starter
intros, reset and doors. All 915 protected catalog artifacts remain identical.
Root inspected both pilot rasters and native intro/battle captures.

Remaining gameplay acceptance: review the proposed Pallet offset and Mart
padding; bind original actors, encounters and events; validate actual
ledge/counter/door/camera/parcel journeys.
NPC art must receive pinned per-character mappings; it is not substituted by
existing sprites merely to fill a preview. Assembly script execution, full Kanto
import, animation playback, shops, inventory gifts, encounters and traversal are
not claimed by this staged data pilot.
