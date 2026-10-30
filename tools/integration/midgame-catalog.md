# Root-only midgame native catalog

`Source/dev/midgameCatalogExporter.lua` adds the three packages to the existing
VisualCatalog protocol. It does not replace a renderer, baseline or inventory.
Map membership derives only from active `SourceMaps.names()` entries whose paths
are `data/midgameEast/<name>.json`, `data/midgameSouth/<name>.json`, or
`data/midgameSaffron/<name>.json`. Uninstalled maps are not silently activated.

## Exact addition inventory

Against accepted `63267b0` plus the three complete packets:

| Native outputs | Input count | PNG count |
| --- | ---: | ---: |
| Terrain, spawn viewport, collision, actor and event views | 106 maps | 530 |
| New imported tiles and explicit masks | 309 tiles | 618 |
| New opaque source strips, masks and three backgrounds | 15 strips | 75 |
| New source frames, masks and three backgrounds | 57 frames | 285 |
| New stand/walk/alternate directional poses, masks and backgrounds | 108 poses | 540 |
| **Total additions** | | **2,048** |

The 38 reused actor families keep their existing Cerulean/Vermilion paths and
are referenced in metadata, never duplicated. New families are BALDING_GUY,
GIOVANNI, GRANNY, MR_FUJI, POKEDEX, SILPH_PRESIDENT, SILPH_WORKER_F,
SILPH_WORKER_M, BIKER, BOULDER, CHANNELER, KOGA, SAFARI_ZONE_WORKER, SNORLAX,
and WARDEN (all `SPRITE_` constants). Shared grids are deduplicated by stable
TileRegistry key across all three packages and earlier exporters.

The prior 6,678-image inventory remains intact, yielding 8,726 declared images
with these additions, before any independent root-owned asset additions.
Counts are source-derived declarations; native PNG publication remains pending.

## Registration and execution

First root activates its final shared manifest/cache and installs the three
CeruleanContent packages as described in `midgame-content.md`. Then apply the
unapplied harness-only registration patch:

```sh
git apply --check tools/integration/midgame-catalog-root.patch
git apply tools/integration/midgame-catalog-root.patch
```

The patch adds exactly these two lines at the existing exporter import and
content-ready registration sites in `tools/harness/dev_imports.lua`:

```lua
import "dev/midgameCatalogExporter"
-- after the existing Vermilion registration, at content-ready:
MidgameCatalogExporter.register()
```

No `Source/main.lua` edit or new contract registration is required. Root alone
runs the existing catalog command against the fully integrated build:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python tools/harness/run.py catalog --output "$POKEMON_ENV/evidence/m55-native-catalog-UNIQUE"
```

Use the existing protected-preservation comparison and review helpers. Never
regenerate a baseline to accept these additions. Root's actual output must agree
with the runtime inventory and be visually inspected before acceptance.

`shared.mapImages` builds isolated WorldViews, disposes them, and exports terrain,
400x240 spawn viewports, actual collision (including explicit blockers), actor
placement and annotated warps/connections/hidden-event coordinates. Every source
actor is drawn; visibility predicates are never evaluated. This is the initial
source/catalog view, not proof of live scripted states, darkness or progression.
New tiles use `TileRegistry.renderImportedGrid`. Source strips/frames use existing
explicit-zero helpers; world poses use `CeruleanContent.poseImage`, preserving
protected BLUE's canonical standing images and greyhair/legacy phase policy.
No provider materialization, actor installation, zone switch or RNG advance.

VisualCatalog's existing declared-output checks reject missing, extra, duplicate,
wrong-dimension/category/mask paths. Its CatalogRuntime guard observes/restores
supported live state around inventory and writing. Existing exporters retain
ownership of earlier maps/tiles/actors. This exporter claims only new map IDs,
new tile keys and the 15 new source NPC keys. No new behavior/fixture/driver
contracts or tests were added.

## Installed-package production cleanup

`generate_midgame_content.py` now detects a fully installed packet from the shared
manifest. Installed generation omits `proposed-source-maps.json`,
`proposed-compact.json` and `proposed-tile-grids.json`, including their artifact
hashes in generated provenance. Root activation metadata is preserved; immutable
entry identity/geometry/checksums are verified. Partial packet installation fails
explicitly. Uninstalled preparation still produces the review proposals.

After root removes the nine proposal files on activation, refresh **only** the
three provenance files through fresh installed-mode generation, then check them:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
export MIDGAME_INSTALLED_REVIEW="$POKEMON_ENV/evidence/m55-installed-generation-UNIQUE"
mkdir "$MIDGAME_INSTALLED_REVIEW"
for packet in east south saffron; do
  case "$packet" in
    east) package=midgameEast ;;
    south) package=midgameSouth ;;
    saffron) package=midgameSaffron ;;
  esac
  python tools/generate_midgame_content.py --packet "$packet" \
    --reference "$POKEMON_ENV/references/midgame-$packet" \
    --output "$MIDGAME_INSTALLED_REVIEW/$packet"
  cp "$MIDGAME_INSTALLED_REVIEW/$packet/provenance.json" "Source/data/$package/provenance.json"
  python tools/generate_midgame_content.py --packet "$packet" \
    --reference "$POKEMON_ENV/references/midgame-$packet" --check
done
```

This moves no runtime content and rewrites no baseline. Root's subsequent
production compilation excludes Source/dev and ships no proposal copies.

## Worker checks and limits

- 41 existing catalog/input/preservation/qualification host tests passed.
- Independent data enumeration verified the 2,048 exact new path/dimension/
  category/mask declarations, disjoint from every prior protected/exporter path.
- All three installed generation outputs passed existing `verify`, omitted exactly
  three proposal files each and their provenance entries, and retained identical
  runtime content bytes. All three uninstalled `--check` invocations pass.
- SDK3.1.2 harness compilation passed, including a private copy of the root
  registration overlay. The actual compressed main PDZ contains the new exporter.

Evidence is outside Git under environment `evidence/m55-catalog-data/`,
`evidence/m55-catalog-compile-01/` and
`evidence/m55-catalog-registered-compile-01/`. The first contains host-derived
`inventory.json`, not exported native images. No Simulator was executed, no PNG
publication/pixel-purity/gameplay acceptance is claimed, and no push/delegation
occurred. The checked-in registration patch remains unapplied.
