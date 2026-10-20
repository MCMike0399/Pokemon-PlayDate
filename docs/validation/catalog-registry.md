# Registry-aware catalog extension (staged)

The Lua candidate is staged at `/private/tmp/pokemon-catalog-registry/Source/dev/catalog.lua`; live Source is unchanged. `catalog-registry.patch` and `bridge-manifest.json` record the two owned Source files (catalog plus its contract suite). The host comparator/inventory/tests are in the working checkout. Root owns integration and all Simulator execution.

## Protected images and additions

The 37 base tiles, their contact sheet, existing player/NPC frames, battle images and authored map filenames retain their old rendering paths and names. The original reviewed 915-image baseline is not edited or regenerated. Exact preservation still requires root's native comparison; compilation and host tests cannot establish runtime pixel equality.

Each registered zone now resolves its cells through that zone's TileRegistry. Imported grid images render locally at pattern phase `{0,0}`; the catalog never calls the registry's cache-populating `renderImported`. Duplicate stable keys with conflicting definitions fail instead of sharing a misleading image. Base rendering still uses the original 37-image TileFactory output.

New filenames use reversible hexadecimal UTF-8 stable keys, independent of numeric allocation order:

- `tile_imported_<hex stable tile key>.png` and `__mask.png`;
- `map_imported_<hex stable zone ID>.png`, `__viewport`, `__collision`, and `__events`;
- installed NPC names retain `npc_<runtime key>_<actual facing>` plus mask and white/black/texture composites;
- `npc_source_<hex original character key>_frame_<original frame index>` covers every source frame, including walking frames, with the same mask/background variants.

Keys over 100 UTF-8 bytes, unsafe runtime NPC names, oversized filenames and conflicting tile identities are rejected. Fixed asleep NPC art exports only its authored down facing; no other directions are invented. Metadata records tile stable keys/terrain/collision, source NPC revision/frame/standing mapping/fixed policy, map registry keys, source event IDs/status/coordinates, and binding issues. Imported event overlays use `W`, `O`, `B` for warp/object/background, followed by `+` bound or `?` unresolved; detailed records preserve overlapping events. Original authored event overlays keep their existing drawing path.

The independent expected inventory in `tools/visual/inventory.py` derives from the four current pinned slice definitions and sprite JSON, recording input SHA256 values. With all four maps registered and SliceSprites installed at production boot, expected additions are:

| Group | Count | PNG artifacts |
| --- | ---: | ---: |
| Imported stable tiles | 102 | 204 |
| Source NPC frames | 46 | 230 |
| Installed NPC facings | 37 | 185 |
| Imported maps | 4 | 16 |
| Total | | **635** |

The resulting expected total is 1550 images when starting from the original 915-image catalog and no other registered content. Other added registries can legitimately add more artifacts, all still unreviewed. Expected four-map coverage must not be inferred from modules merely being imported: maps must be registered and sprites installed. The source files remain pinned to pokered `af519899719f0754965776faac0e836a3b906e6d`; provenance and exact source comparisons of these new assets remain a separate root review.

## Explicit preservation comparison

Default comparison remains strict: any extra/missing/changed image fails and returns nonzero. The opt-in command checks the protected subset while listing every addition:

```sh
python tools/visual/compare.py ORIGINAL_REVIEWED RUN_ROOT --protected-preservation --report /private/tmp/protected-report.json
python tools/visual/inventory.py --source Source --catalog RUN_ROOT --report /private/tmp/slice-inventory-report.json
```

Use the project's Pillow environment for these commands. In preservation mode, exit zero requires `protected_equal: true` and every added PNG present, decodable and matching declared dimensions. Missing/changed protected pixels, alpha, standalone mask bitmap, inventory, mask/category/dimension metadata or known-missing records fail. Added paths are containment checked, including symlink escapes. Missing or corrupt additions also fail.

With additions, full `equal` and `review_complete` remain false, and `added_unreviewed` lists every path. Exit zero means only protected preservation plus valid files; it does not approve the new art or establish a reviewed extended baseline. No baseline writing exists in either command. Root separately inspects source comparisons and native composites/maps before freezing an extended reviewed catalog, preserving the original baseline.

## Worker verification and root recipe

Compile against current Source passed at `/private/tmp/pokemon-catalog-registry-compile-01`. The staged helper overlays only the manifest-owned files and privately imports/registers `CatalogContracts`. Three SDK groups test bounded stable names, allocation-order independence using actual TileRegistry instances, and complete source-frame mask/background inventory. Native execution remains pending root:

```sh
python3 /private/tmp/pokemon-catalog-registry/validate_staged.py --project "$PWD" --output /private/tmp/pokemon-catalog-registry-runtime-01 --execute
```

Root should run this after production boot registers all four slice maps and installs their sprites, then run both host commands above against the generated run root, inspect maps/NPC composites at native resolution, and independently source-compare additions. Host tests cover strict default failure on additions, protected-mask mutation/deletion/relabel, malformed additions, declared dimensions, portable paths/symlink containment, and the independent 635-path inventory. No worker Simulator or Data access occurred.
