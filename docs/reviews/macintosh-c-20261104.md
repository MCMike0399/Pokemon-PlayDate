# Deep review of the Macintosh C updates — 2026-11-04

Reviewed candidate: `03c1bae4f465f17e3c00178681e34370c9695c3e`.
Fixed Macintosh-work base: `1464d1a237d551e4e6909b66fea108eea0befb7a`.
Accepted main before extraction: `ff598ced99b92c5e6a55283875fe6bd9ae6e5bf9`.
The two independent Sol/medium reviews below are preserved separately. Their findings
apply to that fixed candidate, not to an imagined merge or later fixes. Root has
not changed or adopted the candidate's gameplay migration. The full C171 branch
remains unaccepted and separate from main B149.

## Standards review

Standards review only. **Three findings; the save-validation changes should not be extracted into accepted B tooling.** All line numbers below refer to candidate `03c1bae4`.

Reviewed `git diff 1464d1a237d551e4e6909b66fea108eea0befb7a...03c1bae4f465f17e3c00178681e34370c9695c3e` and the corresponding two-dot log: **32 files, 3,960 insertions, 111 deletions**, across:

- `de997823` — Saffron guard visibility.
- `a10f6d33` — actor-save migration, elevator confirmation and helper changes.
- `873c73cf` — persisted elevator-cabin projection.
- `5b9f4c2e`, `0abbde1e`, `03c1bae4` — runtime-gate records.

Main `ff598ced` and candidate share merge-base `170b15765e977ebd0c85cfd6b80d6b55c3782b09`: **9 main-only / 44 candidate-only commits**. This six-commit review does not qualify that entire divergence.

1. **P1 — Hidden saved actors bypass required value validation.**  
   `Source/domain/worldMotion.lua:71–98` puts coordinate, facing, phase and timer validation inside the *visible* branch. A hidden actor record containing only a valid hidden `id` passes `object(value, fields)`, which checks allowed keys rather than required fields, and is then silently dropped. Invalid coordinates or timers likewise escape validation.

   **Documented rule:** `docs/plans/full-game-goal.md:57–64` requires “Fully validate untrusted bytes read from disk,” full validation at load, and strict public/untrusted APIs. `CLAUDE.md`, “Domain owners,” assigns persisted-motion validation to `WorldMotionData`.

   **Fix:** validate each saved actor’s required structure and values before applying an explicitly bounded visibility migration. Separate obsolete visibility/reservation checks from structural validation. Add rejection cases for malformed hidden records. This is a static acceptance-path finding; it does not establish that the retained pilot save is malformed.

2. **P2 — The diagnostic migration exception can conceal changes to surviving actors.**  
   `Source/dev/diagnostics.lua:249–265` removes both actor lists from comparison, then checks only that canonical IDs belonged to the original list and at least one ID disappeared. If one actor disappears while another actor’s pose changes, this predicate still accepts the result. At `:280`, it reports `roundtrip_equal=true` despite detecting unequal payloads. `Source/domain/gameSession.lua:472–475` also removes the complete actor list/count from its retained-field check.

   **Documented rules:** the same strict-validation requirement above; `CLAUDE.md`, “Domain owners,” requires invariants to remain with their owners. `docs/plans/full-game-goal.md`, §2 “Keep these,” requires honest evidence with implementation and acceptance separated.

   **Fix:** obtain a precise migration result from the domain owner; compare every surviving actor by stable ID and complete value, verify the exact permitted removals/count, and report literal equality separately from accepted migration. The current production normalizer copies surviving actors, so this identifies a weakened defensive/evidence boundary, not an observed pose-corruption incident. **Do not independently extract this diagnostic exception into B.**

3. **P2 — Newly added Lua repeats the prohibited dense style.**  
   Examples include `Source/dev/saffronGuardContracts.lua:322`’s inline sort callback and `:324`’s complete loop on one line, plus `Source/dev/contracts.lua:383`’s inline conditional body.

   **Documented rule:** `docs/plans/full-game-goal.md:164`: “Keep new Lua one statement per line”; §2 “Dense code style” requires new code to match the readable original style.

   **Fix:** expand these new callbacks and control-flow bodies. This finding excludes unchanged dense code and merely reindented validation logic.

The parsed East/South/Saffron transform exports are unchanged. The Kanto export differs only in `build_id`. Checked qualification dependency hashes, generated-source receipt hashes and the Swift-source receipt hash match candidate bytes. Protected sprite/shade/tile-factory files are untouched in this range. External producer reports remain unverified here.

For a B-only extraction, the **named-contract hunks and both suite-aware qualifier changes** are separable from C gameplay, subject to root qualification. Preserve no-argument aggregate behavior; named runs still execute the existing common tests before the selected registered suite. The **Swift helper changes require their matching acknowledgement consumer and native qualification**: accepted main lacks the candidate’s `JourneyHistory` implementation, so the `restarting.py` hunk cannot be treated as a standalone main patch. Neither extraction requires `WorldMotionData`; the actor-canonicalization diagnostics do.

No tests, SDK, GUI, device operations, edits, commits or pushes were performed. The approximately 800 MB diagnosis remains evidence-scoped; it authorizes neither bypassing `HarnessBuild` validation nor raising guards. No wholesale C merge or gameplay acceptance is recommended. Spec axis was intentionally not assessed.

## Spec review

Spec axis: **changes required before gameplay adoption.** Standards axis was outside this assignment. No edits, tests, runtime, SDK, GUI, commits or pushes performed.

Exact range reviewed: `1464d1a237d551e4e6909b66fea108eea0befb7a...03c1bae4f465f17e3c00178681e34370c9695c3e`: six commits (`de997823`, `a10f6d33`, `873c73cf`, `5b9f4c2e`, `0abbde1e`, `03c1bae4`), 32 files, +3960/−111. Full diff captured read-only: 679,444 bytes, SHA256 `70aadcf6fb6cab0db6969dc4caa8928a5bfcfd9a85e2a7e0dccabaffae10e59a`.

Against main `ff598ced`, merge-base is `170b15765e977ebd0c85cfd6b80d6b55c3782b09`; divergence is **9 main-only / 44 candidate-only commits**. C171 remains separate from accepted B149. A wholesale merge is unsupported.

1. **P2 — Hidden actor migration accepts malformed records.**  
   Candidate `Source/domain/worldMotion.lua:67–98`: `object(value, fields)` rejects unknown keys but does not require fields or validate their values. All coordinate, facing, timer and phase checks now occur only in the visible branch. A hidden known actor represented solely as `{id=<known-hidden-id>}`, or carrying invalid coordinates/timers, is silently dropped and accepted. Unknown IDs and duplicates still reject, but the claimed malformed-entry rejection does not hold.  
   **Fix:** validate required fields, types, ranges and intrinsic motion consistency before visibility pruning; separate checks that require a current reservation/surface. Add malformed-hidden cases alongside the valid historical-save migration.

2. **P2 — Custom actor validators can discard arbitrary actor data.**  
   Candidate `Source/domain/gameSession.lua:466–475`: removing `actors` and `count` from both retention-check inputs exempts the entire collection. A callback returning the same envelope with `actors={}`, `count=0` passes this boundary even when actors remain visible. A callback can also remove fields from retained actors. The previous recursive retention check rejected those deletions.  
   **Fix:** permit only independently proven hidden-ID removals; require retained actor records unchanged, no additions, and count matching the resulting list. Revalidate with fresh candidate world/location/flags. Cover rejection without owner mutation.

3. **P2 — Migration diagnostics can report unequal actor records as equal.**  
   Candidate `Source/dev/diagnostics.lua:244–281`: `actorVisibilityMigration` compares surviving IDs, but removes all actor values from its equality check. If one actor disappears and a surviving actor changes, it can return `roundtrip_equal=true` with a visibility-migration label. This compounds finding 2 and weakens Save/Continue evidence.  
   **Fix:** require exact equality for each retained actor and independently establish every dropped actor’s hidden status. Preserve raw selected-slot payload and sequence separately from canonical decoded state; normalization must still reject loading a different fallback slot.

The Fuji conditions correctly compose source objects 14/15 with Silph completion. Generator pins include the rescue script, and both qualification provenance dependency maps match candidate Source hashes. East/South/Saffron exports are structurally unchanged; Kanto export differs only in `build_id`. External producer reports and staged-build identity remain root’s validation responsibility.

The elevator’s single guarded callback fixes the serial invalidation shape. Cabin projection matches the persisted-floor resolver. The added native regression covers floor 2, one exit and cancellation; it does not independently establish all eleven floors, both exits, persisted-cabin restart behavior or rollback.

For a B-safe extract:

- Named-suite dispatch plus catalog/field qualifiers appears separable. No-argument aggregate execution retains existing cases; named execution also runs the shared core cases. Qualify typed and string requests on accepted B.
- Swift robustness changes require the paired `restarting.py` acknowledgement change. Existing lock/start-time/build checks, exact-layout refusal, 8-second alarm, 9-second parent timeout and call/Clear caps remain. Native qualification is still required.
- Actor migration, migration diagnostics and C cabin planning are **not independent B tooling**. Exclude them from that extract pending fixes and reviews.

The roughly 800 MB deep-path attribution remains a diagnosis with limited measurement scope. It provides no authority to bypass `HarnessBuild`, change qualified-data policy or raise guards. No C acceptance, hardware safety, latency, credits or postgame acceptance follows from this review.

## Root disposition and independently checked evidence

Do not merge C171 wholesale. The candidate's source-backed Fuji transition and
elevator fix are useful progress, but three validation/evidence defects remain:
required malformed-hidden-actor checks; bounded custom-validator retention; and
truthful literal-versus-migrated codec observations. Fix these together on C,
retain every original failure and Save, then obtain fresh owner qualification and
native regressions. The source fix's own tests do not disprove these findings.
New dense Lua should be expanded in that same corrective pass. No C guard,
policy, schema or acceptance level is waived by this review.

Only these independent hunks are selected for main: `Contracts.run(only)` and
its error detail helper, the command argument wiring, and suite-aware catalog/
field evidence classifiers. Root expands the new Lua conditional, rejects an
unknown suite before common tests can mutate RNG, and refuses malformed extra
arguments in the host classifier. No-argument aggregate behavior is retained.
This selection changes development tooling only; production B data/runtime,
Save/Continue owners, art and qualification pins stay unchanged. The Swift and
`JourneyHistory` acknowledgement changes are not extracted: accepted main has no
matching JourneyHistory implementation, so that hunk is not an independent port.

Root verified on Macintosh that the retained native-14 build/result hashes and
export-04 build/outcome hashes match their committed references. The staged
`gameSession`, `worldMotion`, `silphStory`, `silphStoryController` and Saffron test
bytes match the reviewed candidate. Its native report has **106 total passes**:
20 common cases plus **86 saffron-guards cases**, zero failures. These counts are
not 106 independent Saffron cases. The parsed transform values and provenance
claims retain their stated limited scope; no journey/hardware acceptance follows.

The genuine latest frontier is pilot-12's stopped elevator Save, marker SHA256
`2204733359f2332c9dd844742cd4d15f457692b880df268e4802ccb15917931b`,
zone `pokered:SILPH_CO_ELEVATOR`, `(7,1,right)`, persisted floor1. Both slot hashes
match the committed pointer. Only `saffron-guard-entry` is complete. The original
failed pilot verdicts remain failed; the next session must not replay from the
older Saffron record16 unless an explicit recovery reason requires that choice.

Root main-port validation: 32 targeted host checks pass. A guarded full-contract
B probe failed the 1GiB host ceiling (1,078,019,752 sampled bytes), retained as a
failure; it is not a direct comparison with the C journey profile. A separate
bounded API-only SDK probe after qualified production boot passes 21 selected
and 22 aggregate checks, including the original 20 common cases on each call.
It proves registered-suite selection, preserved default order and unknown-suite
rejection/RNG preservation. Its dispatch sentinels are API test fixtures, not
campaign coverage. Sampled host peak165,725,168bytes; owned exit confirmed.
This is not a full harness/journey pass and is not permission to use a qualified
shortcut for earned journeys. The full main host result is recorded separately
when complete; pending acceptance gates remain explicit.

The deep-load footprint attribution remains a diagnosis, with an observation
that the C unqualified harness path reaches the host ceiling. Reducing redundant
copies/allocations while retaining full validation is already within the goal;
it does not require another user decision. Raising guards, changing the pool,
bypassing the harness trust fence or skipping validators would require an explicit
policy decision. Do not present those as the only two implementation choices.

Summary: Standards **3 findings** (worst P1); Spec **3 findings** (worst P2).
Overlapping findings remain separate above. Gameplay findings are unresolved on
C and excluded from main; the main-safe port is independently qualified in its
narrow scope.

