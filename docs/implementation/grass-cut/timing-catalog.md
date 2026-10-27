# Grass clock and catalog follow-up

Merged exact root `61891d7e64192f151e7d6c7d1e1dd66bbbd82d10` first
(merge `eebe720`). The merged tree was identical to that root commit.
This follow-up supersedes the original packet's 32-native-update timing note.

**Clock:** pinned `engine/overworld/cut2.asm:AnimCut` runs two pairs of eight
`AnimCutGrass_UpdateOAMEntries` steps. Each step calls `DelayFrame` exactly once.
Pinned `home/vblank.asm:DelayFrame` sets `hVBlankOccurred`, halts and waits for the
next VBlank to clear it. Its verified SHA-256 is in the compile report and focused
host test. Thus there are 32 source positions/single-VBlank intervals. Following
the existing ship's nominal 60 Hz source / 30 Hz production clock, grass now
presents **16 native updates**, sampling the second position in each pair:
zero-based native update `n` -> zero-based source frame `2n+1`, positions 2..32.
This keeps the final source position. Pair sampling aliases the source palette
alternation to `$e4`; both original palettes remain separately cataloged. No new
palette alternation or averaged pixels are invented. Tree/actor and Flash remain
on their existing 8/3 timing contracts.

The last native interval completes the existing guarded one-shot transaction.
Cancellation on the final presented sample still has no terrain effect. No
request, party, session, mutation/reset owner or input guard was changed.

**Production art seam:** `prepareGrassPresentation` prepares original leaf
palettes and ground before use (gameplay enter or catalog bootstrap).
`drawGrassPresentation` only draws those prepared images at a bounded source
sample. It has no token/game/session and performs no art-cache initialization.
Gameplay and the catalog use this same renderer. The catalog uses the existing
isolated `CeruleanCatalogExporter.render` helper and prepares images exclusively
at bootstrap; writer only publishes prepared grass images. The old private tree
record now supplies its required defensive `effect` input, preserving its original
render path, pixels and metadata rather than touching a live action.

**34 added images; 1,736 total Vermilion images; 1,450 unchanged shared references:**

- `vermilion-grass-leaf-palette-{228,128}`: two 16x16 assets, each with standalone
  mask and white/black/texture composites: 10 images.
- `vermilion-grass-source-frame-{0,7,8,15,16,23,24,31}`: eight 128x96 source samples,
  covering both ends of all four sweeps and both palettes.
- `vermilion-grass-native-update-{0..15}`: sixteen 128x96 actual native samples.

These are prepared declarations, not executed PNG exports. The crop places the
aligned 2x2 ground replacement at output `(32,16)` and the facing target there;
all leaf travel fits. New `grass` metadata states source/native clocks, indexing,
positions and sampling. Existing map/actor/tree/ship paths and metadata remain
unchanged. All shared actor declarations still equal the Cerulean declarations.
The original 1,702-image declaration retains fingerprint `ed4c3443…aeda645`;
the 1,736-image declaration is `e4c7d734…0bb5065` (full values in the report).

**Checks:** generator `--check` and 18 focused host checks pass, zero skips:
`test_field_move_data`, `test_grass_cut_data`, `test_vermilion_catalog_inputs`.
Host work checks primary pins, grids and declaration invariants only, with no
Lua execution/emulation. SDK 3.1.2 production and registered harness builds compile.
Retained stages: `~/Developer/Pokemon-PlayDate-env/preparation/grass-clock-catalog-61891d7/`.
`timing-catalog-compile-only.json` records exact Source/stage fingerprints and
byte-identical admission, input, close, completion/guard, tree and leaf-renderer
regions against the merged root. All other production Source files are unchanged.
Only the four authorized Source paths differ from root; no shared imports,
GameSession/codec, maps/cache, protected/Cerulean files, baselines or ledger changed.

There are now 15 prepared grass SDK cases. The catalog native suite independently
checks leaf pixels/masks, closed-form source sweep/flip/palette presentation pixels,
native sample metadata and exact declarations. Writer probes forbid grass
preparation/drawing and field intent operations. A real-action draw probe forbids
art rendering/terrain reads after preparation and checks its token/frame/session.
Existing tree and prior catalog native pixel checks are retained.

**Root integration:** cherry-pick the follow-up commit onto `61891d7` or its
descendant. No shared wiring/cache patch is needed: root already registers both
suites/exporter. Run native contracts and catalog, inspect all added images and
motion, and keep earlier protected comparisons exact. No runtime, Simulator,
pixel inspection, push or delegation occurred; no native/campaign acceptance is
claimed. Source-clock fidelity uses the project's nominal 60-to-30 conversion,
not a measurement of real device refresh or wall-clock performance.
