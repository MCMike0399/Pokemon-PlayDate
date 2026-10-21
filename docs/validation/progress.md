# Full-game execution ledger

Persistent objective: [complete goal](../plans/astra-full-game-goal.md).
Status: **active; campaign unfinished**. Resume from this ledger, then inspect the
owned task handoffs before changing files. Do not repeat the original audit.

## Current checkout / next continuation

**New explicit user decision:** add Gen V abilities, held items and natures for
the original151. This is required full-goal scope, not optional polish. Keep world/
story/art/roster constraints. See fidelity-ledger.md; plan persistence, specimen
generation/evolution, UI/acquisition and battle-event integration before enabling.


Current push checkpoint follows `b114145` (the earlier connected-world push).
Root stopped all three workers to freeze this checkout for the user's request to
push current work to main. No Simulator session remains running. Worker settings
remain the explicitly requested gpt-6.1-sol/medium; runtime exposes status but no
resolved-model field. No physical-device validation has been performed.

Live Source now includes **PC storage and evolution**, merged together with the
previous connected Viridian campaign slice. Root's frozen-source integration
suite passed **381/381 SDK contracts and 7/7 runtime jobs**, including a real
two-process PC deposit→box save→Continue→withdraw and five evolution scenarios.
All live Source files match the tested tree except generated harness overlays.
Durable [PC/evolution evidence](accepted-pc-evolution/acceptance.json) includes the
suite, captures, traces, source hashes and compressed runtime evidence. Root
reviewed actual PC panels and evolution before/after/cancel/stone/new-move scenes.
The five evolution recipes now await complete dialog text and request 120-frame
captures; these host-only refinements need a rerun before claiming longer motion
review. The tested original recipes are preserved inside the evidence archive.

PC preserves owned identity, HP/status/PP and move slots through twelve boxes,
last-member/last-usable guards, explicit release confirmation and guarded box save.
Evolution covers original151 level/stone relationships, cancellation, old/new
species learning order and pending state. Codec4 deliberately accepts older3
records. Trade evolution has an internal hook; no link availability is claimed.

Previous integrated work remains: source-backed Route1/ViridianCity/Mart/Center,
explicit slice save policy, traversal/counters/ledges, parcel/Oak/BLUE/Pokédex151,
shop/healing/checkpoint, capture animation and six early B2W2 move corrections
plus seed/trap/hazards/Toxic dependencies. Dialog generation distinguishes chained
instances. Display names remain ASCII where required by the current font.

Prior independently accepted checkpoints:

- [Early combat](accepted-early-combat/acceptance.json):335/335 SDK,6/6 jobs;
  original915 static artifacts exact. No complete GenV mechanics claim.
- [Natural parcel](accepted-parcel-functional/evidence.json): seed42 initial reset
  only, real starter/BLUE win, wild encounters, parcel/Oak/BLUE/Pokédex, shopping,
  nurse decline/accept and save. Root inspected actual scenes and BLUE motion.
- [Connected world](accepted-connected-world/acceptance.json):337/337 SDK,9/9
  functional jobs; final capture-export proof338/338.42 native protocol cases,
  full-bag retries, quest visibility/checkpoints, real Viridian Save/Continue.
  Restart PIDs97153→97208 preserved exact save hash and scene pixels.
- Reviewed static baseline1635 in `catalog-viridian/` preserves original915.
  Independent35 EventArt and50 capture/jump comparisons pass. Capture export uses
  a clear logical mask and white-canvas materialization to preserve hidden RGB.
- [World profiling](observed-world-profile/evidence.json):6 Simulator cycles,
  four-map install165ms, postGC9179KiB, City views8–12ms/676sprites. Observer growth
  prevents a leak conclusion. No device capacity claim. SDK numeric isSimulator
  reporting was repaired for future samples.

Current checkpoint validation: native production compile and `git diff --check`
pass. Generator host tests:103 run,4 skipped by existing source/cache conditions.
Older broader host/protocol qualification remains documented in the accepted
checkpoints; no newly merged specimen or provider implementation is claimed.

Unmerged worker packets are preserved in
[checkpoint handoffs](../plans/paused-handoffs/README.md), with SHA-256 manifest.
Restore named packets under `/private/tmp`, verify manifests, and apply only
reviewed narrow hunks. Do not overwrite current context/codec/battle/UI with stale
candidate copies. Reference caches are excluded; fetch/check pinned inputs.

- Pewter provider/trainer: `pokemon-pewter-runtime-candidate-03` passes root's
  **360/360 SDK** staged probe;300 isolated catalog images exported and284 exact
  independent pixel checks pass. Actor/event composites still require root visual
  review. LRU2 imported maps, pure save validation and actual install rollback.
  `EventState.observe` currently consumes a trainer receipt: a separate pure
  observation repair was requested but is not accepted or integrated.
- Brock journey: `pokemon-brock-journey`,22 new host tests plus29 compatible
  existing tests pass. Natural driver and supplementary recipes are frozen;
  native journey awaits provider/learning integration. No Brock completion claim.
- Healing: `pokemon-healing-presentation`, latest root staged probe
  `/private/tmp/pokemon-healing-presentation-sdk-02` passes385/385 contracts with
  required14 images exported. Those images await root review and the three owned
  files remain unmerged. Old342 probe's missing-export defect is repaired.
  Original EventArt stays unchanged; source palette-flash refinement remains.
- Midbattle learning: `pokemon-battle-learning-contract-followup`,18 learning
  groups plus2 evolution integration groups compiled, native run pending. Real
  one-shot learning receipts suspend before next enemy; release gate prevents
  accidental held-input choices. Preserve provider trainer-finish ownership.
- Battle medicine: `pokemon-battle-items`, frozen compiled packet with9 groups
  and5 input scenarios/8 required panels. Native proof and merge remain pending.
- GenV specimen traits: `pokemon-specimen-attributes` is unfinished staged work,
  NOT installed. Source proposal is in `pokemon-specimen-attributes-audit`.
  Approved direction: Codec5 migrates3/4 to Hardy/first/none; persistent independent
  nature and first/second/hidden ability slot, species-derived ability identity,
  explicit atomic generation RNG, canonical holdable IDs. Existing IV0/EV0 remains
  an explicit unfinished fidelity issue. Battle effects and item acquisition are
  subsequent required work, not established by data-only generation.
- Catalog aggregation: `pokemon-runtime-catalog` and `pokemon-catalog-registry`
  contain staged work. Comprehensive provider registration was being designed;
  full native/default aggregation and protected1635 comparisons remain pending.

Continue by validating/reviewing these candidates, merging narrow shared-file
hunks and running integrated SDK/journeys with actual image inspection. Finish
Pallet–Brock, then every remaining campaign/postgame milestone. The full campaign
remains unfinished; abilities, held items and natures are required user scope.

## Accepted milestone: harness and protected references

Starting revision `1cb82252e4d591e9819fdd23caa234e02128263c`; tracked tree was clean.
The user's existing untracked `docs/` handoff was preserved. Initial source
inventory: 33 Lua files, six zones, 151 species, 419 moves, 302 battle PNGs.
SDK 3.1.2; Python 3.14.7; visual dependency Pillow 12.0.0.

Root independently reviewed code and actual native images/frame sequences and ran:

- `make -j4 compile`: successful native `.pdx` build.
- Host contracts: protocol/suite, source generation, visual mutation detection,
  and independent B2W2 verifier tests passed (74 at the initial combined run;
  later targeted harness additions also passed).
- Full frozen-source SDK suite **14/14 jobs passed**:
  `/private/tmp/pokemon-harness-qualified-suite-03`.
- Real production SDK contracts **20/20 passed**. Controlled original-state,
  original-Signal, shared-RNG and draw-timer mutants each failed the specifically
  expected assertions; clean control passed. Compile/launch failures do not count.
- All three natural seed-42 starter intros use player inputs, win BLUE, reach
  `done`, and remove BLUE without debug teleport or forced outcome.
- Rival win/loss fixtures, actual grass battle victory/blackout, all interior
  door/stair round trips, overlays, hold/release and active-state resets passed.
- Fifteen real-runtime protocol fault/recovery cases passed, including stale,
  wrong-build/session, invalid commands/assertions, replay, cancellation and
  competing-client/runner rejection.
- Catalog **915/915 image and mask comparisons identical** to reviewed alias-fix
  baseline. All 311 protected original art/map/palette source files are unchanged.

Durable evidence: [accepted-harness](accepted-harness/acceptance.json), its
`suite.json`, and compressed `evidence.tar.gz` (snapshots/traces/captures/build
identities; source staging/compiled bundles excluded). Build/source hash in the
acceptance manifest identifies the tested Lua bytes. Temporary run directories
are conveniences, not the only evidence store.

### Reproduced defects repaired during qualification

- Canonical `nidoranF`, `nidoranM`, `mr` sprite names now resolve via a shared
  explicit JSON alias manifest. Existing 903 artifacts are identical; precisely
  six views and six masks were added. Root inspected each addition.
- State reentry/lifecycle callbacks and Signal listener mutation now have real
  production contracts and controlled failure evidence.
- Rules RNG is independent of cosmetic drawing. Scene advancement occurs in
  simulation updates; extra draws cannot alter rules or animation clocks.
- Rolling PNG producer/read race was reproduced: gameplay passed but `last.png`
  was partially overwritten during validation. Final `quiesce` stops all writes
  before host verification; immutable final inventory and eight retained frame
  pairs replace the ambiguous rolling file. Strict image checks remain.
- Suite aggregation initially counted a stale reply archive twice. Only numbered
  canonical results now enter aggregation; stale evidence is retained separately.

Historical failing runs remain `/private/tmp/pokemon-harness-full-suite-01` and
`/private/tmp/pokemon-harness-finalization-suite-02`; suite 03 is the clean full
acceptance run. No failing golden image was overwritten to achieve acceptance.

## References and fidelity

- [starting-source.json](starting-source.json), [initial captures](baseline-initial/manifest.json).
- `baseline-catalog/`: original 903 artifacts; `catalog-alias-fix/`: reviewed 915.
- [alias comparison](alias-catalog-comparison.json), [final exact comparison](qualified-catalog-comparison.json).
- `controlled-visual-defects/`: deliberate actual RED pixel and opacity defects
  each fail with exit 1 and exactly the expected changed rectangle.
- [NPC mask comparison](reference-mask-comparison.json): all 16 SDK masks match
  independent transforms of pinned original source inputs. Existing NPC grids
  reproduce exactly; RED remains the intentional hand-tuned exception.
- [Battle-art reproduction](battle-art-provenance.md): root independently checked
  all 302 PNGs against pinned original front/back images and threshold 128,
  with identical pixels/opacity and unchanged protected files. No art rewritten.
  [Root report](accepted-foundations/battle-art-check.json).
- [coordinate check](reference-coordinate-check.json): independent Pillow decoder
  agrees with source block/quadrant examples for Route 1 and Red's house.
- [Kanto inventory](../research/kanto-content-inventory.md), plus machine-readable
  inventory and 1,385 verified source hashes under `tools/references/`.
- [fidelity ledger](fidelity-ledger.md): Blue default, original 151, intentional
  Gen V/B2W2 mechanics and Dark/Steel; original palette/art contracts preserved.

The B2W2 validator now has zero learnset/scalar discrepancies across 151 species
and 424 moves. It still fails explicit unimplemented/review/unverified mechanics.
Those remaining gaps are not waived full-game acceptance criteria.

## Ownership and runtime controls

Root exclusively owns Simulator sessions, SDK test Data, runtime validation and
acceptance. The runner's global lock serializes sessions and terminates only its
owned process. Use [harness.md](harness.md), not legacy shared-mailbox/broad-kill
commands. Normal/device builds do not allocate test fixture map copies.

Four runtime slots total. All three workers were explicitly launched through
`collaboration.spawn_agent` with `fork_turns="none"`,
`model="gpt-6.1-sol"`, `reasoning_effort="medium"`; calls accepted and running
status verified. Runtime listing exposes no second resolved-model/effort field.
Follow-ups reuse those exact workers. Never silently inherit or substitute.

| Worker | Current handoff / allowed scope |
|---|---|
| `harness` | Source-backed Pewter runtime, bounded imported provider, trainer integration. |
| `rules_contracts` | Specimen attributes; frozen midbattle-learning followup. |
| `visual_catalog` | Catalog registration; frozen healing and battle-medicine packets. |

Shared checkout uses disjoint ownership. No worker runs the Simulator. Root must
review diffs, apply only owned staged files, run integrated SDK contracts and
inspect resulting images before accepting implementation.

## Next executable work

See the current continuation section above for the single runtime job and staged
handoffs. Preserve source identity across multi-job suites; accept only after
independent native and visual review. Continue through the complete goal.

| Full-goal milestone | Status |
|---|---|
| Harness and protected references | Accepted with evidence above |
| Domain/data/party/items/save foundations | Native session/save/menus/party/capture commands accepted; capture presentation pending |
| Pallet–Brock coherent campaign | Pending |
| Mt. Moon–Cerulean–S.S. Anne | Pending |
| Connected midgame Kanto | Pending |
| Late gyms–Champion–credits | Pending |
| Postgame/audio/performance/release | Pending |

Physical-device performance has not been validated. The source inventory is not
an implemented campaign, and neither tooling nor these domain candidates complete
the persistent full-game objective.
