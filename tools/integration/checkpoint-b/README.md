# Checkpoint B map and data packet

This packet starts at accepted local main `2dd9f3cc`, after A acceptance
`c946efdf` / `7bc7cc55` and the accepted early-title work. The first useful packet
is `ce615acf`. Apply its follow-up commit too before packaging. No shared runtime
owner was edited. The rejected registration candidate `33d759ed` / `422fe9c6`
was not used. This is host and compile-only preparation, not B acceptance.

The shared manifest contains 149 source maps: the accepted 108 and 41 of the
42 pinned South records. Route16FlyHouse stays parked for 5.5c. The addition
covers Tower, Routes 12–18 and their ordinary gates/interiors, Fuchsia and Safari,
including the rest houses. There is no count discrepancy. Saffron, Silph and
Dojo are absent. Existing manifest entries, decoded map bytes, grids, terrain,
collision, art and encounter inputs remain unchanged. Blue water rates remain
zero. Trades and guards remain parked.

The existing source-map generator supplies the compact metadata, lazy current-map
runtime projections, shared tile grids and versioned binary cells. The existing
content generator now pins South's four original content inputs and omits the
Fly-house interactions and text in its generated cache. No full registration
cache, second registry or eager runtime content owner is introduced.

Production staging selects the explicit A or B exclusion policy. Unknown,
partial or identity-drifted inventories fail instead of shipping everything.
B excludes Saffron/Silph, the Dojo-only controller, Fly's decoded map, South's
full content/preparation inputs and all `proposed-*` files. The mixed shared field
modules remain available for B; their dormant Fly implementation is gated by the
unapplied root patch. All checksum-pinned raw inputs remain in Git for reproduction.

## Root integration

Review `root-hooks.patch`, then use `git apply --check` and `git apply` from the
root checkout after both packet commits. It adds the existing Tower/Snorlax and
field imports, registers South through `CeruleanContent` and its existing sparse
story transform, registers the two existing field states, and refuses Fly until
Route16FlyHouse is installed. It does not change bootstrap, saves, codecs,
controllers, player, field world or source actors. The patch applies to the base
and compiles when applied only to a private staged production tree.

The patch alone does not install Safari gameplay, field motion/restrictions,
Strength actor leases, fishing observations or the worker B driver. Root must
compose those existing owner packets and qualify their real input lifecycle.
Do not describe retained modules or a successful compile as installed APIs.
Before the full SDK suite, root must regenerate its private source-map extension
fixture for the new manifest; this worker did not edit `Source/dev` fixtures.

Read the worker's `76c372ad:tools/harness/scenarios/midgame/integration-55b.md`
through Git. The host B check below evaluates that exact worker preflight and
accepted-A importer without changing the checked-in drivers. All three accepted
A save pairs pass read-only; no saves were copied or written.

## Reproduction and packages

Load `~/Developer/Pokemon-PlayDate-env/env.sh` first. Use fresh paths outside Git.

```sh
python3 tools/activate_checkpoint_b.py --output "$POKEMON_ENV/evidence/NEW/generated"
python3 tools/generate_source_map_cache.py --output Source/data/sourceMapCache --cells-output Source/data/sourceMapCells --check
python3 tools/generate_content_cache.py --check
python3 -m unittest tools.tests.test_checkpoint_b_inventory tools.tests.test_content_cache tools.tests.test_source_map_pipeline.SourceMapManifestTests tools.tests.test_source_map_pipeline.GeneratedSourceCacheTests tools.tests.test_production_build -q
python3 tools/build.py --stage "$POKEMON_ENV/evidence/NEW/production" --output "$POKEMON_ENV/evidence/NEW/B-data.pdx"
python3 tools/harness/run.py --build-only --output "$POKEMON_ENV/evidence/NEW/harness"
python3 tools/check_checkpoint_b_inventory.py --stage "$POKEMON_ENV/evidence/NEW/production" --bundle "$POKEMON_ENV/evidence/NEW/B-data.pdx" --output "$POKEMON_ENV/evidence/NEW/release-inventory.json"
```

Production packaging must use `tools/build.py`, never direct `pdc Source`.
After root owner integration, rebuild both bundles and rerun release inventory.
Use the three accepted `chain/5.5a/<starter>` pairs with the worker B scenarios;
retain their exact hashes and ancestry. The compile-only `B-data.pdx` is not a
player package and must not replace an accepted build or save directory.

Evidence is outside Git at
`~/Developer/Pokemon-PlayDate-env/evidence/map-55b-activation-20261029-01/`.
The focused host suite has 31 passing tests with no skips. Map/cell and content
regeneration reproduce exactly. Production, full harness and the privately
applied root patch compile with SDK 3.1.2. `release-inventory.json` lists all
149 names and checksums of every generated map, cell and content artifact, and
checks exact staged and compiled inventories and exclusions.

The worker preflight falls from 70 blockers to 12: all 30 missing-map checks,
16 interaction approaches, 11 waypoint checks, three chains and the fixed Safari
script now resolve their map inputs. Three earned capability conditions become
visible: two Cycling Road segments and the Warden's actual boulder mutation.
Four owner imports and five Safari/fishing/field observation/runtime gaps remain.
This does not prove those capabilities or Safari resources. `b-preflight.json`
retains the exact conditions. No Simulator, device, USB, baseline update, push,
or delegation was performed.
