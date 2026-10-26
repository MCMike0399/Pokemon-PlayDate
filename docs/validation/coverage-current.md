# Current whole-game coverage

This snapshot describes **private foundation candidate `9cc65c4`, not accepted main**.
Its independently reconstructed Source SHA256 is
`4f26ba79522681d67dca319311b0ad6285b195785a0f63900ae4c0e6406930ae`.
Root executed that exact Source in the real SDK: **1250 passed, zero failed**;
all **2494 protected catalog images** were exact, and both native artifact
qualifications passed. [Candidate summary](coverage-evidence/candidate1250-summary.json).
Main remains on Source `44bd25…`, waiting for Charmander and the current
all-starter milestone gate. Full campaign, regional fidelity, full mechanics and
physical-device acceptance remain unfinished. No milestone row is promoted.

[Current data](coverage-current.json) follows [the schema](coverage.schema.json)
and [the full-game goal](../plans/full-game-goal.md). Source declarations and
component tests do not establish playable campaign completion.

Three acceptance layers stay independent:

| Layer | Required acceptance | Insufficient evidence |
|---|---|---|
| `campaign_path` | Connected progression, required transactions, safe returns and real save/restart for the milestone | Inventory counts, fixture teleports or declarations |
| `regional_fidelity` | Independent review of source controls, geometry, NPCs, text, items, encounters, puzzles, art and audio | A playable critical path or protected pixels alone |
| `full_mechanics` | Reviewed rule portions with exact owner/assertion and actual SDK/native evidence, plus remaining original-151 requirements | Generated fields, nonempty effects or an aggregate contract count |

Rows retain owners, acceptance dependencies, separate due milestones for all
three layers, immutable source selectors, implementation/verification states,
evidence IDs and limitations. `integrated` identifies a production portion;
`sdk_scoped` identifies bounded component evidence. Neither means full mechanics
or main acceptance. Scheduling never waives a newly exposed rules gap.

## Inventory and scheduling

All **1501 rows** remain: 248 map slots, 425 moves, 111 ability IDs, 151 species,
125 item definitions, 38 indexed native held-item entries, 375 audio sources and
28 systems. These are inventory sizes, not implemented or playable totals.
The immutable inventory distinguishes 222 ordinary named map slots, 22 unused
aliases, four copy/alias slots, 223 unique headers/object tables, 805 warps,
201 background declarations, 918 object declarations and 391 trainer-party rows
including unused content. Unused declarations do not become reachable fights.

The candidate converges existing source-map/event paths; it does not add the
remaining Kanto campaign. Authored Pallet and its interiors remain protected.
Source-script declarations still need executable reachability review. Route 22,
Mt. Moon and later regions are not installed or accepted by this refresh.

Finish the root-owned Pallet → Brock gate, including Charmander and real
Save/Continue, before accepting foundations or later regions. The goal retains
every later region through League, credits and original postgame, all mechanics,
audio, naming/options, resources and physical-device checks. Original Blue
availability and technical support for 151 species remain distinct. No Mew
encounter, held-item loot or link policy is invented here.

## Live candidate evidence and preserved history

The [compact contracts projection](coverage-evidence/candidate1250-contracts-projection.json)
is **not a raw packet**. It retains the complete native contracts reply unchanged:
all 1250 test entries, all 86 suite records and their metadata, and build/session/
protocol/request identity. Catalog payload and unrelated snapshots/results are
omitted. The original 1,215,286-byte packet remains at
`~/Developer/Pokemon-PlayDate-env/evidence/m52-private-sdk-20261026-05/00001-result.json`,
SHA256 `63890cf75a394d62342dd25a9fb7da39b62b45ce9c2b0bcd37b3aae1ab1e3231`.
Both projection and summary explicitly pin that durable raw provenance. No new
archive, screenshot or baseline is committed.

The [live runtime registry](../../tools/references/runtime-move-coverage.json)
retains all 48 original scopes, states, capabilities and definition hashes.
Its exact named tests were rerun successfully in the native 1250 report.
Only five supported records needed reviewed drift updates:

- Captivate, Endeavor, Rage Powder and Sucker Punch: `canAttempt` adds a
  Roar-only Soundproof guard before their unchanged attempt rules.
- Assurance: the literal damage assertion now passes the actual queued actor;
  HP, damage, PP and RNG expectations are unchanged.

Ten unverified records retain their old hashes and remain **stale**: Dig,
Earthquake, Explosion, Fury Cutter, Gyro Ball, Heavy Slam, Magnitude,
Self-Destruct, Smack Down and Helping Hand. The first nine retain declared
`source_gap`; Helping Hand retains `source_only`. Shared dispatch/actor changes
are not rehashed into qualification. Helping Hand has a new named singles test,
but this bounded refresh deliberately leaves its existing record unpromoted.

Two additional records bring the curated registry to **50**. Whirlwind and Roar
have narrow runtime evidence for real wild escape/level failure, trainer reserve
replacement, PP/RNG and actor cancellation; Roar includes its Soundproof guard.
The native `whirlwind` suite has 27 cases and `move-failure` has six: **33 scoped
cases total**, including loud-failure controls, not 33 phazing-only cases or
exhaustive mechanics certification. Their campaign and regional layers remain
unpromoted. Unknown interactions and remaining mechanics still require proof.

The [1091 registry](../../tools/references/runtime-move-coverage-current1091.json)
is preserved byte-for-byte as static history alongside its unchanged
[result](coverage-evidence/current1091-result.json) and
[summary](coverage-evidence/current1091-summary.json). Historical assertions use
that registry, while live Source checks use the candidate registry. Existing
main950, private1059, natural journeys, failures, 511-event exposure and exact
34-row promotion erratum remain unchanged and source-specific. The historical
419-move detector is not today's mechanics truth.

## Validation

The runtime validator binds claims to named production bodies/fragments, exact
meaningful assertion bodies, complete canonical test entries and byte-pinned
SDK evidence. Source/build identity, Boolean success, report completeness and
suite/test totals must agree. Projections additionally require matching explicit
raw provenance; they never impersonate a raw packet. Definition hashes remain
drift guards. Changed unreviewed owners/assertions become stale. Existing
integrity and mutation tests remain required.

```
source ~/Developer/Pokemon-PlayDate-env/env.sh
python tools/check_coverage_matrix.py --project "$PWD" --matrix docs/validation/coverage-current.json
python -m unittest tools.tests.test_candidate1250_refresh tools.tests.test_current1091_refresh tools.tests.test_runtime_sdk_evidence tools.tests.test_runtime_move_coverage tools.tests.test_coverage_matrix -v
```

Run the full host suite with verified reference caches and a fresh compile-only
bundle as described in [host-tests.md](host-tests.md), with zero skips. The full
move verifier still reports known gaps and unreviewed rules;
`runtime_semantics_complete` remains false. This maintenance task launches no
Simulator, edits no Source or ledger, and grants no root acceptance. Simulator
artifact and heap evidence does not establish physical-device behavior.

Maintenance validation on this branch: fresh compile-only build succeeded;
matrix validation passed all 1501 rows; the final identity/provenance/history
checks passed 26 tests. The full host run executed 591 tests: 589 passed,
two errors, **zero skips**. Both errors are capture-policy staging fixtures
(`test_default_preserves_runtime_source_path` and
`test_overlay_identity_and_original_bytes`): their synthetic main file lacks the
candidate's required `imports-1` harness slot. They were reproduced separately
and remain unchanged, outside this evidence maintenance scope. The full log is
at `~/Developer/Pokemon-PlayDate-env/evidence/foundation-coverage-build-20261026-01/full-host.log`.
The move verifier reports 151 species, 425 moves, zero scalar/learnset failures,
39 scoped runtime rows, ten stale records, 100 requiring review and 285
unreviewed; full runtime semantics remains false.
