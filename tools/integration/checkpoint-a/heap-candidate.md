# Private checkpoint A heap candidate

This branch merges frozen checkpoint A `93d480b77f3d231c7c806cf57f71c5e064fba3f0`
into exact main `432d5ab42cb4cd417d880117d06f3c0ca60d62e6`. This prepares
compilation only. Root owns heap measurement, journeys, hardware and acceptance.
Checkpoint 5.5a remains frozen. Neither main nor the frozen integration branch is
moved by this preparation.

The shared manifest is byte identical to checkpoint A: 108 maps, comprising the
accepted 65 unchanged entries and exactly 43 East entries. Celadon, Hideout,
Erika and Scope retain their installed descriptors and controllers. South,
Saffron, Tower, Silph, Snorlax, Dojo, travel controllers, trades, guards, Safari
and audio are not installed. A's production exclusions remain unchanged.
Required shared v4 domain/schema dependencies remain available without installing
their future content.

Main's current-map geometry, two-slot provider, packed immutable rows, lazy
learnsets and content chunks, public defensive boundaries, cooperative startup,
5 second device guard, 24 ms device loading slices, absence of SDK wall sprites
and portable safe save publication remain. Protected grids, battle art, visual
baselines, main's frozen import baseline, goal, progress, ledger, accepted
summaries and milestone times are unchanged. Earned chain saves were only copied
by the compile-only heap-probe preparer; their source files were not edited.

The 15 conflicts were resolved as follows.

- `ceruleanContent.lua` and `sourceEvents.lua` retain main's digest indexes and
  bounded record cache. A's existing transform runs against detached read-through
  records and returns a sparse overlay. Existing bespoke trainer records are
  included through generated membership metadata; untouched events and trainers
  stay lazy. A's Hideout pickup guards, story trainers, Erika rewards, source
  flags and item observations remain represented. No gameplay policy is added.
- `sessionCodec.lua` keeps A's version 4 fields and legacy/early-v4 migrations,
  including coins, Safari provenance and travel state. Main's cooperative
  checkpoints remain; the saved healing checkpoint uses a distinct local name
  so it cannot shadow the yielding helper.
- `fieldWorld.lua` retains A's qualified source door arrivals and traversal/session
  behavior while using main's per-map field-data lookup.
- `main.lua` keeps main's guarded cooperative lifecycle and adds A's exact imports,
  installed package transform and controller chain. Content installation stays
  inside initialization. Trades and guards have no installer call.
- `overworldState.lua` keeps A's scripted elevator resolution and main's door trace.
- `sourceActors.lua` retains A's boulder classification alongside main's private
  actor surfaces. `sourceMaps.lua` combines A's scripted warp registry and door
  arrival policy with main's packed/runtime geometry and defensive APIs.
- `generate_source_map_cache.py` combines A's closed-destination barrier projection
  with main's lazy runtime projections and binary cell generator.
- `sourceMapContracts.lua` retains A's existing elevator/arrival checks, uses the
  actual installed inventory and main's two-slot capacity. No contracts were added.
- Both journey JSON conflicts were regenerated under `Source/dev`. Vermilion
  provenance was regenerated with the existing scoped preparation helper.
- Goal and progress use exact main versions.

The shared cache was regenerated and checked: 110 JSON map artifacts (108 runtime
projections and the two shared indexes), plus 108 binary cell artifacts whose
headers pin the current shared manifest and decoded map. The lazy content cache
has 1887 artifacts for base content and the installed source, Vermilion and East
packages. Its existing checks prove canonical record round trips and checksum
pins. The source-map development fixture and journey hashes were regenerated.
No journey data was placed in production data.

Existing checks passed: 92 relevant host checks, 5 real SDK compiled-artifact
checks, and 54 protocol checks. The existing content-pin check now references the
frozen A input for East and the exact A manifest. The artifact check reads A's
already-frozen import contract directly from its Git object while leaving main's
checked-in baseline unchanged. No new test or contract was authored. Production,
harness and guarded earned-save heap probe all compile with SDK 3.1.2. No
Simulator, host Lua or device execution was performed.

Retained compile evidence is outside Git:
`~/Developer/Pokemon-PlayDate-env/evidence/p0-checkpoint-a-heap-candidate-20261029-01/`.
The `final` subdirectory contains production and harness bundles compiled after
the merge commit. Host logs are in the parent directory. The earlier
`heap-compile-only` bundle is preparation evidence, not a measured heap result.

Root's exact heap-test command, run from this checkout, is:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python3 tools/harness/startup_probe.py \
  --project /Users/burbujamc/.t3/worktrees/Pokemon-PlayDate/t3-2b1c0ba0 \
  --mode production --checkpoint --device-test \
  --save-dir "$POKEMON_ENV/evidence/chain/5.4/bulbasaur" \
  --output "$POKEMON_ENV/evidence/p0-checkpoint-a-root-heap-20261029-01" \
  --timeout 120 --execute
```

The output directory must be fresh. The existing Simulator preflight requires
the 16 MB pool. This is the existing supplemental earned-save probe: inspect
its post-GC heap and map/battle measurements and compare with the same observer
on the 65-map base. It does not replace Root's natural journeys or establish
hardware playability. No heap reduction, same-budget result or unfreezing is
claimed by compilation.

The staged whitespace check reports only inherited blank context lines in A's
existing patch artifacts. Those frozen patch bytes were preserved. Changed
implementation files have no whitespace errors.
