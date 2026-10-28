# Milestone 5.5 map/content candidates

Worker base: exact accepted `63267b0` (merge was already up to date). No active
manifest/cache, bootstrap, world/domain/session/codec, UI, battle, audio, protected
art, baselines or ledger edits. No Simulator, push or delegation.

## First useful packet: east

43 maps in `Source/data/midgameEast/`: Routes9/10, Rock Tunnel both floors and
Center, Lavender and its Center/Mart/Cubone/Fuji/name-rater interiors; Routes7/8,
both Saffron gates and all three east–west Underground Path maps; Celadon City,
Center/Gym/Diner/Hotel/Chief House, all five Mansion maps, all seven Department
Store maps, Game Corner/Prize Room and all five Rocket Hideout maps.

131 ordinary object descriptors and 48 signs are prepared. Ordinary trainers,
pickups, stock-backed shops and healing use existing SourceEvents descriptors.
44 object/sign IDs remain reserved, exhaustively listed in `reservations.json`.
`contexts.json` exposes each source map ID, runtime key, padding, connections,
warps and actor IDs/pointers/source and runtime coordinates. Decoded maps retain
all Blue encounter slots and original music identifiers. Trainer rosters include
reserved actors and the full rival/Giovanni classes for scene owners.

Root's restored `a30d996` packages retain ownership of
`pokered:ROUTE_7_GATE:objects:1` and `pokered:ROUTE_8_GATE:objects:1`.
They are reserved here; activate the existing SaffronGuards entries at root.
The source coordinates are respectively `(3,1)` and `(2,1)`, plus the manifest's
horizontal padding for runtime placement. Do not install duplicate guard events.

The packet does not implement Rock Tunnel darkness/Flash, source Cut blockers,
Erika, Eevee, Fuji/Flute, Game Corner coins/prizes/slots/poster, Rocket Hideout
spinners/Lift Key/elevator/Giovanni, Department Store elevator/vending/gift choices,
name rating, cries, link services, conditional dialogue or hidden-item dispatch.
Their source scripts and stable-ID reservations are explicit; map decoding is not
campaign activation. The Hideout's initial closed poster/door and script-only
mutations require root/scene composition before traversal is accepted.

## Root installation

Register through the already-installed immutable source resolver, after its
ordinary content setup and before entering new maps:

```lua
CeruleanContent.registerPackage("midgameEast", "data/midgameEast/")
```

Only root promotes the final shared manifest. Merge `manifest-entries.json.maps`
into `Source/data/sourceMaps.json.maps`, preserving all existing entries and any
root-owned activation/blocker/LAST_MAP policy. `proposed-source-maps.json` is a
mechanical candidate against this worker's accepted base, not a replacement for a
newer integrated root manifest. Regenerate the active cache with the existing
`tools/generate_source_map_cache.py` after composing the final inventory. The
`proposed-compact.json` and `proposed-tile-grids.json` files are review inputs only.
Adding targets changes missing-target blockers on older maps; root must review
those connections together with story/field gates before activation.

## Reproduce without extracted source in Git

All 311 consumed east inputs are pinned to Blue pokered
`af519899719f0754965776faac0e836a3b906e6d` by SHA256 in
`tools/references/midgame-east.json`. Raw ASM/PNG/block inputs stay outside Git.
`materialize_midgame_content.py` follows root's
`materialize_pokered_packages.py` pattern: `git show REV:path`, checksum validation,
then external cache. It adds atomic publication and read-only inventory checking.
`Source/data/*/scripts.json` contains hashes, pointer indices and hidden-event
coordinates, not extracted ASM bodies. Use the materialized scripts for story work.

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python tools/materialize_midgame_content.py --packet east --pokered "$POKERED_REFERENCE_DIR"
python tools/materialize_midgame_content.py --packet east --check
python tools/generate_midgame_content.py --packet east \
  --reference "$POKEMON_ENV/references/midgame-east" --check
```

For regeneration choose a fresh `--output` directory; generation never repairs an
existing output. Terrain uses the existing decoder and approved global imported
shade mapping; additive NPC strips use the existing source-strip resolver. No
protected RED/NPC regeneration or per-tile whitening.

Preparation checks: existing map generator/pipeline/source-event/Cerulean host
suites **51 passed, zero skips**. SDK3.1.2 production compilation passed at
`~/Developer/Pokemon-PlayDate-env/evidence/m55-maps-east-compile/Pokemon.pdx`.
Compile-only success establishes no native behavior, pixel or milestone acceptance.
