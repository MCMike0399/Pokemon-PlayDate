# Current whole-game coverage

The live snapshot is the **private Cerulean candidate `b1f0bd8`**, Source
`3fab65f913a2963e136e6f9c51123da9dd9a78822d859a376eca9a67a0cd9320`.
Accepted main game code remains `27443af`, Source
`2673b352e62b8e145b8a7e19b055db47479bc4f4100caf6f2835137ee85fe079`,
through Brock and milestone 5.2. Its acceptance is recorded separately in the
[foundation summary](foundation-acceptance-20261026.json).

Root's three natural Cerulean starter/restart journeys are in progress and are
**not accepted by this refresh**. No milestone 5.3, all-starter, full mechanics,
release, visual or physical-device acceptance is granted here.

## Inventory and independent layers

All **1501 rows** remain: 248 map slots, 425 moves, 111 ability IDs, 151 species,
125 item definitions, 38 indexed native held-item entries, 375 audio sources and
28 systems. Campaign path, regional fidelity and full mechanics remain separate;
`accepted_milestone_rows` remains empty. Inventory counts never mean playability.

The frozen shared manifest declares thirty installed maps, eighteen added since
accepted main. Those eighteen campaign rows now say private, partial and
source-only. This records installation without certifying event reachability or
regional fidelity. The three Mt. Moon rows additionally record the narrow actual
`cave-encounters` boundary successes: non-grass land accepts Blue byte 9 and
rejects byte 10 with the pinned slots and RNG continuation. Blocked/water cells,
zero-rate Centers, unbound fixtures, stale plans, Forest and outdoor non-grass
controls remain covered separately in that eight-case suite. None is a natural
journey or complete map acceptance.

The immutable source inventory still distinguishes 222 ordinary named slots,
22 unused aliases, four copy/alias slots, 223 unique headers/object tables,
805 warps, 201 background declarations, 918 object declarations and 391
trainer-party rows including unused content. Unused declarations do not become
reachable fights. Authored Pallet and its interiors remain protected. Later Kanto,
League, credits, original postgame, audio, naming/options, resources and device
work remain in the goal. Original Blue availability and technical support for
151 species remain distinct; no Mew encounter, held-item loot or link policy is
invented here.

## Actual native evidence and Source identity

The [compact projection](coverage-evidence/cerulean1659-contracts-projection.json)
retains every original contracts test and suite entry, reply metadata and
protocol/request/build/session identity: **1659 passed, 0 failed**, 103 suites
containing 1639 assertions plus twenty original assertions outside named suites.
It is explicitly a projection, not a raw packet. The original raw packet remains at
`~/Developer/Pokemon-PlayDate-env/evidence/m53-cave-and-abilities-sdk-20261026-01/00001-result.json`
(2,597,103 bytes), SHA256
`814d4737855b85625a9055be7e06709e5e3e9dff2cd6fc385bdcd16d79f6234a`.
The raw contracts reply is not quiescent; that fact is preserved.

The [compact provenance and scope summary](coverage-evidence/cerulean1659-summary.json)
pins the raw report and run/build/source manifests. Before changing the snapshot,
maintenance independently compared all 634 original file hashes to live/frozen
Source, checked the Source git trees, reconstructed original staged bytes using
the saved main/pdxinfo and verified the path/NUL/file-byte fingerprint. The
compiled staged tree independently matches
`df59ed9cef12feb02fcb01651461ca6d844b9dab34de597c8504cb2641e9c420`.
Generated harness identity is excluded only as documented by the runner;
its original file hash still matches the source manifest. This is actual executed
Source identity, not a reported count or a new runtime launch.

## Reviewed mechanics scopes

The [live runtime registry](../../tools/references/runtime-move-coverage.json)
retains the original **50** curated move scopes, declared states, capabilities,
definition hashes and exact assertion records. Every original curated assertion
has the identical successful canonical entry in the new raw report.

Nine changed owner selections were personally reviewed against accepted Source
`27443af`: `canAttempt`, `performMove`, `resolveTurn`, `accuracyBypassesCheck`,
the critical-stage and Protect dispatch fragments, `ModifyStat:apply`,
`worrySeed` and `DirectDamage:apply`. Only those selections were rebound in
verified records. The summary identifies each affected move, old/new body hash,
named actual successes, supplemental branch witnesses and review limitations.
Soundproof, No Guard, Shell Armor, absorption ordering, Clear Body, Flash Fire
cleanup and fixed-damage Stench witnesses supplement existing bounded assertions;
they do not turn the aggregate report into broad move certification.

Ten unverified records retain their **old hashes and stale status**: Dig,
Earthquake, Explosion, Fury Cutter, Gyro Ball, Heavy Slam, Magnitude,
Self-Destruct, Smack Down and Helping Hand. The first nine still declare
`source_gap`; Helping Hand still declares `source_only`. Its newer singles
assertion does not promote the old record. Critical-family proof remains
metadata/shared arithmetic, not an actual attack by each family member;
Razor Wind and Sky Attack charge behavior remain unverified. Whirlwind/Roar
retain their narrow wild/trainer/PP/RNG/actor scopes and the existing 27-case
`whirlwind` and six-case `move-failure` suite distinction, including failure
controls. Unknown interactions remain open.

Twenty-five battle ability rows now record **partial, SDK-scoped** evidence tied
to selected literal named assertions in the summary: Inner Focus, Dry Skin,
Intimidate, Forewarn, Vital Spirit, Water Veil, No Guard, Shell Armor, Skill Link,
Sniper, Soundproof, Effect Spore, Cute Charm, Synchronize, Stench, Anger Point,
Natural Cure, Magic Guard, Technician, Flash Fire, Clear Body, Liquid Ooze,
Water Absorb, Swift Swim and Levitate. The seven ordinary hooks span OrdinaryAbilities and
the existing battle owners. No ability gets exhaustive mechanics or acquisition
acceptance. Dry Skin sun behavior and broad combinations remain unverified.

Physical-lead field evidence remains a separate scope: Synchronize nature gates,
Cute Charm sex/fallback gates, and rate doubling for Illuminate/Arena Trap/No Guard.
Illuminate and Arena Trap receive only that partial rate evidence. Rate-down
arithmetic covers Stench/White Smoke/Quick Feet, but the actual encounter witness
uses Stench; White Smoke/Quick Feet actual encounter paths remain unverified.
Magnet Pull slots and Pressure/Hustle/Vital Spirit level callbacks still fail by
name as deferred acquisition gaps. Hidden acquisition and additional held-item
loot are not authorized or certified.

## Preserved history and validation

The [1274 registry](../../tools/references/runtime-move-coverage-candidate1274.json),
[1274 projection](coverage-evidence/candidate1274-contracts-projection.json) and
[1274 summary](coverage-evidence/candidate1274-summary.json) remain byte-exact
history. Earlier 1250, 1091, main950 and private1059 evidence, natural journeys,
failures, 511-event exposure and the exact 34-row promotion erratum remain
unchanged and source-specific. The historical 419-move detector is not today's
mechanics truth. Historical tests target their historical registry; live checks
continue to reject unreviewed owner/assertion drift and forged SDK provenance.

Use the pinned caches from the environment script; do not fetch changing inputs.

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python tools/check_coverage_matrix.py --project "$PWD" --matrix docs/validation/coverage-current.json
python -m unittest tools.tests.test_cerulean1659_refresh tools.tests.test_candidate1250_refresh tools.tests.test_current1091_refresh tools.tests.test_runtime_sdk_evidence tools.tests.test_runtime_move_coverage tools.tests.test_coverage_matrix -v
```

Maintenance validation and logs are retained under
`~/Developer/Pokemon-PlayDate-env/evidence/cerulean-current-coverage-build-20261026-01/`.
A fresh compile-only bundle succeeded; matrix validation retained all 1501 rows.
The focused suite passed **47 tests**. The full host suite passed **716 tests**,
with zero failures, errors or skips, using that fresh bundle and verified pinned
cache. Logs are `focused-host.log` and `full-host.log`. Source-map cache, move
support and Cerulean journey generator checks also passed. The full move verifier
retains explicit gaps and `runtime_semantics_complete=false`.
Maintenance launched no runtime/Simulator and changed no Source, ledger, goal,
baseline, protected assets or main branch.
