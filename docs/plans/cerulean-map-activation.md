# Private map promotion from 7eae5e1

This implementation lives on `wip/cerulean-map-activation`, based exactly on
`7eae5e1`. It changes neither main nor production Lua. It is map preparation,
not campaign or Simulator acceptance.

The common `Source/data/sourceMaps.json` and `sourceMapCache` now contain all
30 maps: the accepted four Viridian and eight Pewter maps, plus the 18 already
decoded source-profile maps. The inactive `ceruleanSourceMaps.json` and
`ceruleanMapCache` copies are removed. No second provider is introduced.
`generate_cerulean_content.py --check` checks sourceSlice artifacts and its
installed entry fields; `generate_source_map_cache.py --check --output
Source/data/sourceMapCache` owns the common cache. Only sourceSlice provenance
was regenerated after the regional generator hash changed. Definitions, blocks,
PNG-derived grids, sprites, trainer rosters and independent oracles are unchanged.

The extension witness has 31 identities: the installed 30 plus pinned
ViridianSchoolHouse. Route22 is installed for shipping, but the witness still
decodes its pinned original independently and overrides its key/path/spawn in
private records. It opens the private Viridian west connection for its inverse
and first-arrival checks. It reads decoded maps and the common manifest, never
regional descriptors, compact caches or inventories. Four Viridian/eight Pewter
compatibility checks retain their exact scope; only full-inventory assertions
become 30/31.

## Root composition and next activation changes

The accepted north Viridian -> Route2 and reciprocal south connection remain
open. Do not copy the stale north blocker from the removed candidate manifest.
During private preparation, these declarations remain closed:

- `maps.PewterCity.blocked_connections = ["east:ROUTE_3"]`.
- `maps.ViridianCity.blocked_connections = ["west:ROUTE_22"]`.
- `maps.PewterCity.blocked_events` contains
  `pokered:PEWTER_CITY:warps:1` and `pokered:PEWTER_CITY:warps:2` (museum ingresses).
  Existing unrelated blocked events remain intact. Reciprocal museum returns
  stay guarded by the production importer.

After wiring the relevant scenes/triggers, root removes only those two
connection entries and those two museum warp IDs, regenerates the common cache
and the private sourceMapFixture, and updates the preparation-only closed-gate
SDK witness/host assertions to the newly activated expectations. Root also
composes actual content/scene installation and the harness suite registration;
this worker deliberately changes no dev imports or baseline fixtures.

`SourceActors._withContent` currently clones the installed resolver table.
Once CeruleanContent registers the `source` profile, genericActorContracts cannot
register its private fixture resolver inside that scope. The wiring worker/root
must give that test scope an isolated empty registration table (with restoration
on success/error), or an equivalent explicitly scoped override. This worker did
not edit SourceActors or genericActorContracts. Merely switching inventories or
removing assertions would hide the composition failure.

The SDK contracts now use installed source records. Existing provider/constructor
checks cover all 30 maps; the added Cerulean check creates actual Zones, reads
actual provider surfaces, compares actual SourceActors descriptors (retaining
Viridian's static policy), and requires every blocked spec to appear in actual
Zone diagnostics. These checks use real SDK classes, not host Lua replacements.
They require root's installed content and have not been executed here.

The generated source script index still honestly reserves these 21 object IDs
for explicit planners (registration may resolve them during root composition):

- ROUTE_22: 1, 2 (the second rival remains outside this milestone).
- MT_MOON_B2F: 1, 6, 7.
- MT_MOON_POKECENTER: 4, 6.
- CERULEAN_CITY: 1, 2, 6, 7, 8, 11.
- CERULEAN_GYM: 1; CERULEAN_POKECENTER: 4; BIKE_SHOP: 1.
- ROUTE_24: 1; BILLS_HOUSE: 1, 2, 3; MUSEUM_1F: 1.

Each shorthand means `pokered:<MAP>:objects:<index>`. Every source-profile map
script also remains explicitly diagnosed until its shared owner resolves it.
Installing geometry does not claim scene, guard, sight, reward or motion proof.

## Validation and immutable art proof

With `source ~/Developer/Pokemon-PlayDate-env/env.sh`:

- 59 focused host tests pass, zero skips: test_cerulean_content,
  test_source_map_pipeline, test_source_map_activation, test_generic_actor_inputs,
  test_map_generator and test_viridian_generator.
- Both regional installed-content and shared-cache check commands pass.
- SDK 3.1.2 production and harness builds compile. The harness includes the
  compiled standalone ceruleanContentContracts module; its runtime registration
  is root-owned and unchanged here. No Simulator process was launched.
- The full host suite was not run. Source-bound coverage and uncomposed scene
  bootstrap checks are root integration work, not silently skipped tests.

All 145 previously active tile entries equal the pinned `7eae5e1` tile records,
including grids, terrain and collision. Their canonical tile dictionary SHA-256
is `9745f055fb1b20b5f13d56a8e7203ca280803ee9717e1bbf76c2d1831addc279`.
All 299 common tile records equal the pinned former candidate's tile dictionary;
this promotion creates no new art. The preservation test compares these records
independently of regeneration. Existing original block/PNG and roster checks run
unchanged. No protected art or visual baseline is edited; pixel-catalog runtime
acceptance remains root-owned.

Compile artifacts are under
`~/Developer/Pokemon-PlayDate-env/evidence/cerulean-map-activation-final-compile`
and `cerulean-map-activation-production-stage`, with the production bundle at
`cerulean-map-activation-production.pdx`. Compilation is not runtime acceptance.
