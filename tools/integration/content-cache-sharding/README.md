# Immutable content path packet

Base: exact `00ce443a32f183599ab073d5944905fdd8c19c0e`, synchronized separately
in the attached isolated T3 worktree `t3/shard-content-cache`. No B prefix.
Logical implementation commits, in order:

- `4565404d`: digest-prefix paths, generated moves, direct-consumer/fixture updates.
- `e07b7bd3`: cooperative check after each staged object definition.

`contentCache/chunks/<digest[:2]>/<digest>.json` changes paths only.
`regionDeclarations/chunks` remains flat. Its generator's original-roster
existence check now addresses the sharded content cache; transformed output
paths and namespaces remain unchanged. The existing eight-record retention,
ShippedDataPolicy, validation, publication and rollback boundaries are unchanged.
The new budget check follows each objectDefinition call into the local staging
array; prepare still validates the complete result before returning any NPCs.

The generator retains its explicit fresh-output-directory policy. Generation
was into `/private/tmp/shard-content-candidate-20261101`; all record and index
bytes were compared before replacing only the verified old generated tree.
There is no in-place overwrite mode. `--check` rejects extra flat duplicates
without repairing them. Content qualification also rejects those duplicates.

Run the independent host-only proof from any directory:

```sh
python3 tools/integration/content-cache-sharding/prove.py
```

`proof.json` records the result against a Git archive of the exact base:
2,546 unique records, 796,612 bytes, exactly one file per digest, zero flat
records, 256 directories, maximum 22 records per directory. Every old/new
record byte and SHA256 matches; all 32 index/catalog files are byte-identical.
The canonical per-digest SHA256 manifest hashes to
`28854a2e8b56aebfcf355341e80589591b888c10ff69eee5d3c881b3f5f8cd51`.
All other Source files except sourceEvents.lua/sourceBindings.lua are unchanged,
including inputs, protected art/maps/story/rosters, session/RNG/moves and pins.

Verification on SDK 3.1.2, compile/host only:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python3 tools/generate_content_cache.py --check
python3 -m unittest tools.tests.test_content_cache tools.tests.test_shipped_map_qualification tools.tests.test_source_events tools.tests.test_cerulean_content tools.tests.test_source_actor_placement_inputs -v
python3 -m unittest tools.tests.test_region_registrations tools.tests.test_production_build -v
```

- Generator: all 2,578 artifacts match; focused suite: **41/41 passed**.
  Log `/private/tmp/shard-final-focused-host.log`.
- Before edits, cache/qualification/region suites: **23/23 passed**.
  Baseline production-build suite compiled production and harness, **4/5 passed**;
  harness import inventory is stale (additional hmBattleContracts and
  stageResetContracts). Log `/private/tmp/shard-baseline-build.log`.
- Candidate expanded host run: **47/50 passed, 3 errors**, all region-generation
  success cases fail closed with `Kanto transform dependency changed:
  game/sourceEvents.lua`. Log `/private/tmp/shard-candidate-host.log`.
- Candidate normal production-build suite is blocked at setUpClass by that
  same stale dependency before compilation; zero tests run.
  Log `/private/tmp/shard-candidate-build.log`. This is a new required refresh,
  separate from the baseline stale inventory failure; neither check was weakened.
- Private export-hook harness **compiled**, not executed:
  `/private/tmp/shard-sdk312-export-compile-20261101/Harness.pdx`.
  Command: `python3 tools/integration/kanto-first-entry/export.py --output /private/tmp/shard-sdk312-export-compile-20261101`.
- Private unqualified production-shaped bundle **compiled**:
  `/private/tmp/shard-sdk312-unqualified-20261101/Unqualified.pdx`.
  Staged with existing production exclusions and no dev files, using real pdc;
  all three qualification literals remain false. Compiled bundle has exactly
  2,546 sharded JSON chunks and no flat duplicates. This is not a qualified
  release. Stage and build.log are beside it.
- `git diff --check` passes. No runtime, Simulator, device, USB, AX, OpenClaw,
  global lock, Pi, push, delegation or host game-Lua execution was used.

Root refresh and native follow-up:

The existing Kanto export/collect hook is documented in
`docs/validation/kanto-first-entry.md`. SourceEvents changed and the cache path
manifest changed, so the prior qualified producer cannot authorize this tree.
Root must preserve/move its old `tools/integration/kanto-first-entry/qualified`
packet to retained evidence before collection: collect requires that destination
not exist. From Root's final integrated checkout, using a fresh output directory:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python3 tools/integration/kanto-first-entry/export.py --output "$POKEMON_ENV/evidence/content-shards-kanto-sdk-UNIQUE" --execute
python3 tools/integration/kanto-first-entry/export.py --output "$POKEMON_ENV/evidence/content-shards-kanto-sdk-UNIQUE" --collect
python3 tools/build.py --stage "$POKEMON_ENV/evidence/content-shards-production-UNIQUE" --output "$POKEMON_ENV/evidence/content-shards-production-UNIQUE.pdx"
python3 -m unittest tools.tests.test_region_registrations tools.tests.test_production_build -v
python3 tools/harness/run.py contracts --output "$POKEMON_ENV/evidence/content-shards-contracts-UNIQUE"
```

These runtime commands were not executed by this worker. No producer export,
provenance or pin was refreshed or retagged. East/South dependencies are unchanged;
no new East/South export is needed for this packet alone. The existing Kanto
collector is the refresh command, not a manual provenance rewrite.
No main/harness import changes are needed. Existing native suites include
source-maps, source-events, generic-actors, source-map-activation,
cerulean-content/story/scenes/routes, and kanto-scenes. Root should check direct
lookups, trainer membership, fixture-scope/cache isolation, actor reconciliation
and failed-prepare publication through these suites, then use its exact current
16 MiB safety and physical Route17 measurement route with guards unchanged.

The supplied hardware evidence attributes 7,158/7,367 ms to openBundle across
60 reads; this packet structurally reduces directory fanout. Buffering remains
rejected. Cooperative checks alone do not resolve the later repeated lookup gap
between overworld.view.end and actors.begin. No CPU/flash explanation, speedup,
heap result, checkpoint/campaign/B acceptance or budget relaxation is claimed.
Root retains only a measured >=10% phase gain, then performs one combined
performance review. Roll back both implementation commits together to restore
the original paths/loader and checkpoint cadence.

## Root upgrade correction — 2026-11-01

The first unversioned shard installation retained the old FAT directory's
1,167,360-byte allocation and did not achieve the required phase gain. A separate
clean-directory experiment reduced that directory to 28,672 bytes and Root
measured 223 ms in file opens, versus 7,158 ms before. With the matched
production-profile Save policy, Fuchsia entry was 6,348 ms versus 14,858 ms.
These experiments do not establish normal-upgrade acceptance.

The current generated root is therefore `chunks-v2/<prefix>/<digest>.json`.
This creates a fresh directory during an ordinary in-place update. All 2,546
record bytes and 32 index files remain identical to the exact original base.
The host proof above now checks that versioned path and the same original
per-digest manifest. Fresh SDK Kanto export/qualification has been collected;
its decoded values are unchanged except build identity. Normal in-place
hardware measurement from the retained failed installation is still pending.
Do not claim release or performance acceptance before that run and review.
