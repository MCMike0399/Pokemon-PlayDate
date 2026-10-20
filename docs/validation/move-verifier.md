# B2W2 move and learnset verification

The verifier checks the production declarative Lua data against immutable raw PokeAPI CSV inputs. It does not import the generator, execute Lua, rewrite production data, reuse the generator's cache, or regenerate the old per-species reports. Run from the repository root with Python3 and its standard library:

```sh
python3 tools/verify_moves/main.py --fetch --output /private/tmp/pokemon-b2w2-first.json
python3 tools/verify_moves/main.py --output /private/tmp/pokemon-b2w2-offline.json
python3 -m unittest tools.tests.test_move_verifier -v
```

Choose a fresh report path each time. `--fetch` downloads only missing inputs; every cached/downloaded file must match its pinned checksum and CSV schema. Without `--fetch`, a missing cache is an error. `--cache DIRECTORY` selects another directory containing the eleven pinned CSVs. The default is `tools/verify_moves/cache/b2w2/2bf639e5572812a67d2b94903fdcb9d095f5aeb2/`, separate from existing legacy API JSON and generator caches. Corrupt cache files are preserved and reported; they are never silently replaced. Existing legacy report files remain historical observations of the old unordered Black/White verifier.

Exit statuses: `0` means the checked content has no detected discrepancy or dispatch review requirement; `1` means content discrepancies/review gaps were found; `2` means inputs, source/cache/schema or arguments are invalid. Static success does not certify runtime move behavior; the JSON explicitly reports `runtime_semantics_complete: false` and lists moves requiring independent runtime contracts. JSON reports include actual/expected values, complete reference learnsets, per-move scalar comparisons, runtime inventory, immutable source manifest and production input hashes. `--output` is required so this tool cannot silently overwrite historical reports. Optional positional species keys select learnset checks, while scalar checks and semantics inventory still cover the entire local move library.

## Sources and historical values

[sources.json](../../tools/verify_moves/sources.json) pins a full Git commit and SHA256 for each file, with exact column schemas. Learnsets, move identities, metadata, types, classes and effect descriptions use [PokeAPI snapshot `2bf639e`](https://github.com/PokeAPI/pokeapi/tree/2bf639e5572812a67d2b94903fdcb9d095f5aeb2/data/v2/csv). Version-group14 must identify `black-2-white-2`; only level-up method1 and species1–151 enter the reference learnsets. Other generations, tutor and machine entries cannot contaminate them.

The [official PokeAPI schema](https://pokeapi.co/docs/v2#pokemon) defines the learn level and source order separately. Canonical ordering is ascending level, explicit order before missing order, explicit order ascending, then numeric move ID. The last tie-breaker is an explicit reproducibility policy when source order is unavailable, not proof of original cartridge move-slot ordering. Source rows and duplicates are not reduced to unordered name membership. The JSON retains nullable source order and numeric move IDs.

Numeric move fields use separately pinned [pre–Scarlet/Violet move data and changelog at `c9cb78b`](https://github.com/PokeAPI/pokeapi/tree/c9cb78bd0a36b33210e697e6cb1b5065bd9fb24a/data/v2/csv), a snapshot before 2022-09-01. Inspection found the newer move table has5 PP for several healing moves but lacks corresponding GenIX PP changes in its changelog. Blindly resolving that table would falsely flag the production GenV10 PP values. The archived snapshot has10 PP; its own changelog rolls later GenVI–VIII changes backward to B2W2. This is pinned raw-source corroboration, with no hand-written PP override or generator import. The verifier independently walks changes backward from newest to oldest, applying nonempty old values for every change after version-group14. It checks type, category, power, accuracy, PP and priority. Null power/accuracy become the runtime's explicit zero convention. These field checks do not validate every special behavior implied by those values.

The [official move schema](https://pokeapi.co/docs/v2#moves) distinguishes scalar fields, metadata, effects and historical values. The inventory includes source effect descriptions, stat changes and metadata for follow-up mechanics work. These descriptions/metadata are from the newer pinned snapshot and are reference material, not a complete historical GenV implementation oracle.

## Current results

At the source hashes recorded in [content-gaps.json](../../tools/verify_moves/content-gaps.json), the full audit returns exit1:

| Check | Result |
| --- | --- |
| Species missing learn levels/order metadata | 151 of151 |
| Flat name sequences differing from canonical B2W2 order/content | 115 of151 |
| Scalar move field discrepancies | 0 of419 |
| Known missing/different runtime mechanisms | 53 moves |
| Status moves requiring dispatch or intentional failure/no-op review | 80 moves |
| Other moves still requiring independent runtime contracts | 285 moves |
| Explicit intentional no-effect | Splash |

All current species store only a string list. Matching that list as a set is insufficient: a level5 Pokémon currently receives the final four listed moves through `Pokemon:init`. This verifier reports absent level metadata even when every move name happens to match. A future declarative `learnset = {{move="tackle", level=1, order=nil}, ...}` is understood by the reader and compared as an exact ordered sequence. Adding metadata alone does not repair runtime selection/level-up behavior; the runtime must consume it and receive independent tests.

The runtime inventory is conservative. Explicit gaps include charge/recharge, protection, variable/special damage without dispatch, critical-rate modifiers, self-fainting, special moves targeting physical defense, Rest, Transform/Metronome and Heal Pulse's current attacker-targeted effect. Status moves with no effects are review candidates: a deliberate failure in singles or intentional no-op is not automatically a proven mechanics bug. Other existing DSL effects remain unverified and may be wrong;285 unreviewed moves are not claimed supported. The present dispatcher cannot be accepted as complete gameplay merely because419 scalar rows match.

Worker evidence: `/private/tmp/pokemon-moves-final-audit-01.json` contains the final report. A fresh network fetch and subsequent offline full audit produced identical reports before the final terminology refinement;34 deterministic offline fixtures pass. The tests cover wrong levels, order, explicit-order omissions, numeric tie fallback, wrong version/method, unknown move IDs/keys, duplicate rows, malformed Lua data, each scalar field, backward field history, missing GenIX PP history, unimplemented dispatch, fetch/checksum/schema/truncation/cache failures, and distinct CLI exit0/1/2 behavior. Tests need no network or SDK.

## Integration work still required

Add level-aware production learnsets without losing source order or repeated learning events. Update initial moves and level-up learning through production interfaces, including exact-level selection, same-level move ordering, evolution/relearning policy and the intro starter override. Repair any B/W versus B2W2 content differences shown by the ordered reports. Keep the generator's data outputs from erasing new metadata and pin its own inputs independently.

Resolve the mechanics inventory with targeted SDK behavior contracts and primary GenV references before marking individual moves supported. A maintained semantics capability manifest should eventually replace the conservative static categories; it must cite tested production behavior. Validate missing dispatch, PP exhaustion/Struggle, enemy PP, persistent status, fixed damage/type immunity, actual damage for drain/recoil and outcome ordering in the next battle-foundation slice. No production data, generator or runtime mechanics were changed in this verifier task.
