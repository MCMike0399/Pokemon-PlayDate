# Current whole-game coverage

This snapshot describes **private foundation candidate `58495eb`, not an accepted
milestone**. Its independently reconstructed Source SHA256 is
`2673b352e62b8e145b8a7e19b055db47479bc4f4100caf6f2835137ee85fe079`.
Root executed that exact Source in the real SDK: **1274 passed, zero failed**;
all **2494 protected catalog images** were exact, with no additions, and both
native artifact qualifications passed.
[Final candidate summary](coverage-evidence/candidate1274-summary.json).

Main milestone **5.1 is accepted at `9104499`** on Source `44bd25…`, covering all
three starters and supplements. That acceptance belongs to the older Source.
The newer private foundation candidate still needs its own integration journeys
and milestone 5.2 acceptance. Full campaign, regional fidelity, full mechanics
and physical-device acceptance remain unfinished. No new milestone row is promoted.

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

The root accepted the Pallet → Brock gate with real Save/Continue for all three
starters. Foundation integration journeys and acceptance on the newer Source
remain pending before later regions. The goal retains
every later region through League, credits and original postgame, all mechanics,
audio, naming/options, resources and physical-device checks. Original Blue
availability and technical support for 151 species remain distinct. No Mew
encounter, held-item loot or link policy is invented here.

## Live candidate evidence and preserved history

The [compact contracts projection](coverage-evidence/candidate1274-contracts-projection.json)
is **not a raw packet**. It retains the complete native contracts reply unchanged:
all 1274 test entries, all 88 suite records and their metadata, and build/session/
protocol/request identity. Catalog payload and unrelated snapshots/results are
omitted. The original 1,219,334-byte packet remains at
`~/Developer/Pokemon-PlayDate-env/evidence/m52-final-sdk-20261026-03/00001-result.json`,
SHA256 `249649b31f8d41ed4d67a9acba1d608ca6d52bf5136e8b6491cfa0592d16a966`.
Both projection and summary pin that durable raw provenance. The native
qualification records match the exact packet, request, session, original Source
and compiled Source; final capture publication confirms quiescence.

This maintenance branch starts directly at `9ed4d36f0ba0b13734f109435070eaa0486ed506`.
Its Source git tree equals native commit `58495ebbf67c2a49bb53293fc98d99b00bf136e8`.
All 569 original file hashes match the native source manifest. Independent
path/NUL/file-byte hashes of live Source and the reconstructed original staged
Source agree; the complete compiled staged tree also matches its recorded hash.

The [live runtime registry](../../tools/references/runtime-move-coverage.json)
retains all **50 move records byte-for-byte at the parsed record level** from the
1250 candidate, including all owners, assertions, definitions, scopes, states
and capabilities. Every curated named assertion occurs with the same successful
canonical test entry in the 1274 report. **No owner or assertion hash was rebound**
and no record was promoted or downgraded to make a check pass. Only SDK/source
provenance metadata is refreshed.

The earlier five reviewed drift updates (Captivate, Endeavor, Rage Powder,
Sucker Punch and Assurance) remain exactly as established by the 1250 evidence.

Ten unverified records retain their old hashes and remain **stale**: Dig,
Earthquake, Explosion, Fury Cutter, Gyro Ball, Heavy Slam, Magnitude,
Self-Destruct, Smack Down and Helping Hand. The first nine retain declared
`source_gap`; Helping Hand retains `source_only`. Shared dispatch/actor changes
are not rehashed into qualification. Helping Hand has a new named singles test,
but this bounded refresh deliberately leaves its existing record unpromoted.

The original 48 records plus Whirlwind and Roar remain **50** curated records. Whirlwind and Roar
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
that registry, while live Source checks use the candidate registry. The [1250 projection](coverage-evidence/candidate1250-contracts-projection.json)
and [1250 summary](coverage-evidence/candidate1250-summary.json) also remain
byte-exact history. Existing main950, private1059, natural journeys, failures,
511-event exposure and exact
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

Maintenance validation: fresh compile-only build succeeded; matrix validation
passed all 1501 rows; focused checks passed **41 tests**; the full host suite
passed **605 tests, zero failures, zero errors and zero skips**, using the env
and that fresh bundle. Logs are retained under
`~/Developer/Pokemon-PlayDate-env/evidence/foundation-final-coverage-build-20261026-01/`
as `focused-host.log` and `full-host.log`. The earlier 1250-era host failures
remain historical; this run does not rewrite their records. No Simulator,
Source, ledger, baseline or main-branch change was made by this maintenance task.
