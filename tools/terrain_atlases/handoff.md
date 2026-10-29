# Flat terrain atlas packet

Prepared from exact main `4957e67109657942e055b575ce74d94bd6c9738b`.
`Source/world/tileRegistry.lua` is untouched. Apply
`tools/terrain_atlases/tileRegistry-hook.patch` alongside the other worker's
registry changes; its three hunks affect only rendering, not duplicate validation.
No main import or additional world/data owner is needed.

The new `Source/terrainAtlases/` contains 15 flat SDK matrix PNGs and per-tileset
identity metadata, plus provenance. They pack 483 frames covering 486 source keys
from the 433 unchanged, checksum-verified PNGs at `5a03fc3`. No renderer was added.
Every assembled pixel matches the current source grid and approved 31.25/68.75
Bayer bytes at phase zero. Pallet, sprites, battle and UI are excluded. Three
adapter void keys retain runtime rendering. Field replacements are covered.

The unapplied hook lazily opens one JSON descriptor and one PDT per tileset miss,
with no per-tile exists/open calls. Its two-slot recent cache includes failed
loads and evicts before loading. Exact full policy equality, source key and all
256 shade cells authorize each frame; dimensions and index bounds are checked.
Cached frames are copied before return. Missing/failed loads, unknown sets,
changed identities, preview/custom renderers and public calls without a source
key retain the original runtime fallback. No tileset grids/images load at startup.
The existing registry image cache and rollback still own their normal images.

Verification: 43 existing source-map/map-generator/field-data/production-build
host checks passed, zero skips. The hook was applied only in a private production
stage and compiled using actual SDK 3.1.2. All 15 PDTs were checked for exact
inventory, dimensions, frame counts, compressed payload lengths and unchanged
metadata; zero per-image PDIs were emitted there. Combined PDT size is 23,516
bytes. Route2 uses `overworld.pdt` (110 frames, 4,154 compressed bytes), although
its measured load needs only 48 new tiles. Cold decode cost, native memory,
copy cost and eviction behavior remain unmeasured.

Recheck after sourcing `~/Developer/Pokemon-PlayDate-env/env.sh`:

```sh
python tools/generate_terrain_atlases.py --check
python tools/generate_terrain_atlases.py --check --compiled-bundle /path/to/TerrainAtlases.pdx
```

Regeneration uses `--output /fresh/directory`; it requires Pillow and the current source grids/policy. Root removed the runtime
generation dependency on the unmerged historical Git object. The qualified
`render()` formula is copied unchanged into `tools/terrain_atlases/pixels.py`.
All atlas PNGs and descriptors remained byte-identical; provenance alone changed. This packet
covers the current 65-map source inventory, not the frozen 108-map branch.

Retained compile-only evidence:
`~/Developer/Pokemon-PlayDate-env/evidence/p0-flat-terrain-atlases-20261029-01/`.
See `verification.json`, `host-checks.log`, `build.log`, `production-stage/Source`
and `TerrainAtlases.pdx`. Root owns all Simulator execution, pixel/isolation and
fallback runtime checks, USB, heap/timing comparison and hardware acceptance.
No Simulator/USB run, baseline change, push or delegation occurred. The historical
deep-path runtime stays excluded. No speed improvement is claimed.
