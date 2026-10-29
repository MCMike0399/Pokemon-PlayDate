# Lazy content cache for P0 boot

This worker starts at exact `d8580322b6720e5580a2c631c7c26527f1df4b17`.
It changes only CeruleanContent, SourceEvents, the new Python generator,
its checksum pins and generated runtime artifacts, and associated tests/docs.
There is no bootstrap patch. Existing install, sign installation and named
package registration calls remain the activation boundary. The manifest still
contains the same 65 maps. Checkpoint A and later regions are not activated.

`tools/references/content-cache.json` pins the eleven current decoded inputs.
The generator verifies their bytes and source revision before projecting any
records. Original inputs, art and baselines remain unchanged. Host checks compare
the pins to the exact starting revision as well as reconstructing every field.
Future checkpoint packages add explicit roots and checksums to these pins and
regenerate the cache; their existing registration call selects the new root.
There is no regional branch or map activation in this generator.

The generated catalog selects package indexes. Indexes contain record digests,
item observation IDs, trainer source flags and ordinary-trainer membership.
Each canonical record is a separate content-addressed JSON chunk, shared when
bytes match. There are 1,263 generated files: four indexes/catalog files and
1,259 chunks. Chunk payloads total 421,785 bytes, the largest is 4,155 bytes, and
indexes total 139,353 bytes. These are serialized sizes, not Lua heap measurements.
Generation requires a fresh directory; `--check` never repairs the destination.

CeruleanContent installation retains indexes instead of decoded text, sprite,
event and trainer catalogs. Text/art conflicts are rejected by canonical digest
before publishing a package. SourceEvents keeps stable event membership without
a merged descriptor catalog. It derives item observation IDs from generated
metadata instead of traversing every descriptor at context creation. The existing
Pewter trainer normalization is projected from its unchanged two inputs, so
controller membership capture does not need the full defensive trainer getter.

The shared cache owns at most eight recently used decoded chunks. Eviction drops
only its reference; active descriptors and defensive public copies stay valid.
Public full-catalog getters still return complete detached tables on explicit
request, without making those tables resident in the cache. Existing rendered
sprite image ownership is unchanged. Story-owned resolver callbacks, actor
metadata callbacks, stable IDs, sign content identity and public registration
validation remain in their existing owners. Public trainer registration also
rejects overlapping membership before publishing it.

SDK `_withSources` scopes preserve registrations, lazy indexes, the recent cache,
and CeruleanContent package membership/install guards by reference. Nested scopes
and failed callbacks restore that state. They do not deep-copy lazy indexes or
leave newly decoded chunks retained after returning. No SDK fixture contracts
were added.

## Worker verification and limits

The eight new Python cache tests and 24 existing source-event, Cerulean-content
and actor-placement tests pass (32 total). Additional existing content suites
passed 28 of 29 cases; Vermilion preparation passed 10 of 12; host protocol checks
passed 49 of 54. All eight failures were reproduced from an archive of exact
`d858032`: two strict Vermilion artifact inventory checks, one historical
TileFactory preservation comparison, and five restart protocol checks whose
MailboxProcess double rejects the existing `text` keyword. Those unrelated files
were left unchanged. This is not a passing full host suite.

Logs under `~/Developer/Pokemon-PlayDate-env/evidence/`:

- `p0-content-lazy-worker-host-20261028.log`
- `p0-content-lazy-worker-additional-host-20261028.log`
- `p0-content-lazy-worker-baseline-failures-20261028.log`
- `p0-content-lazy-worker-protocol-20261028.log`

Both SDK 3.1.2 production and private harness builds compile. The final production
build is in `p0-content-lazy-worker-production-final-20261028`; the harness build
is in `p0-content-lazy-worker-sdk-build-20261028`. Neither was executed.
No Simulator, USB, Lupa, stock Lua, fake SDK or host game-Lua execution was used.
No runtime heap, slice timing, pixels, gameplay or hardware acceptance is claimed.
The game remains not yet playable on Playdate hardware.

## Root commands

Run serially from the integrated checkout. Root owns Simulator and USB. The
existing SDK suites exercise event plans, registration scopes, defensive
getters, trainers, actor metadata and the currently installed content. Use a
fresh output directory if any named directory already exists.

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python3 tools/generate_content_cache.py --check
python3 -m unittest tools.tests.test_content_cache tools.tests.test_source_events tools.tests.test_cerulean_content tools.tests.test_source_actor_placement_inputs -v
python3 tools/harness/run.py contracts catalog --output "$HOME/Developer/Pokemon-PlayDate-env/evidence/p0-content-lazy-root-sdk-20261028-01"
python3 tools/visual/compare.py docs/validation/catalog-pewter "$HOME/Developer/Pokemon-PlayDate-env/evidence/p0-content-lazy-root-sdk-20261028-01/frames" --protected-preservation --report "$HOME/Developer/Pokemon-PlayDate-env/evidence/p0-content-lazy-root-sdk-20261028-01/comparison.json"
```

Apply `content-cache-callers.patch` before the root SDK run. It changes two
scene-owned install sites from explicit full trainer catalog reads to per-ID
reads. The public full-catalog getter must remain complete and defensive;
changing its semantics to conceal these eager callers would break that API.
The patch was checked with `git apply --check` but was not applied, because
CeruleanStory and CeruleanRoutes are outside this worker's ownership. Without
it, installation still temporarily materializes all rosters through those
explicit getter calls, although the cache does not retain them. Existing
story-owned JSON loaders are also outside this worker's scope.

Root must also use its existing exact-build P0 title, earned Continue, door,
battle and save smoke in the verified 16 MB pool, then its hardware cycle.
Compare matching before/after boot traces and live/peak heap; a bounded record
cache alone does not establish the 6 MiB/9 MiB or timing gates.
