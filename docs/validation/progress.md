# Full-game execution ledger

Persistent objective: [complete goal](../plans/astra-full-game-goal.md).
Status: **active; campaign unfinished**. Resume from this ledger, then inspect the
owned task handoffs before changing files. Do not repeat the original audit.

## Current checkout / next continuation

Harness checkpoint: `b53566d`. Foundation checkpoint: `75b7d05`, with durable
[acceptance evidence](accepted-foundations/acceptance.json).
**Do not reapply the old learnset, party or save patches.**

- All 151 ordered B2W2 learnsets (2,184 events), real level initialization and
  move choices are live. Charm/Psywave/Storm Throw are implemented; Struggle is
  now a generated runtime-only fallback (423 move records total).
- Party/Storage/Inventory models are integrated and SDK-tested, but the live
  GameContext still owns one `playerPokemon`; full session/party/menu/capture
  integration is outstanding.
- Move-learning overlay is wired after battle return. Seven-job UI/intro suite
  passed at `/private/tmp/pokemon-learning-integration-suite-01` (55 SDK cases,
  14 native captures inspected, exact clean-screen return). A real XP-awarding
  battle also passed `/private/tmp/pokemon-battle-learning-02`. The first probe
  exposed/fixed a host one-based array-path lookup bug; game learning was correct.
- Combat PP/Struggle/status/faint ordering and terminal observer cleanup are
  implemented. All 27 new SDK cases passed. Native three-job combat suite is
  passed at `/private/tmp/pokemon-combat-journeys-01`; root inspected eight native
  display captures covering exhausted/partial PP, poison, escape, simultaneous
  faint victory and blackout restoration.
- Pokémon codec and two-slot SaveStore are live primitives, **not** aggregate
  game save/Continue. Real SDK JSON decoding rounded numeric 2147483647 to float
  2147483648. Decimal text now preserves full counter bounds. Raw numeric RNG
  snapshots are in-memory only; `toData`/`restoreData` are the persistence seam.
- Latest root SDK execution: **112/112 passed**, including 16 persistence and
  14 RNG serialization cases, at `/private/tmp/pokemon-persistence-rng-contracts-02`.
  All 915 protected visual artifacts compare exactly. The earlier red sequence
  probe and diagnostic remain under `/private/tmp/pokemon-save-*probe-01` and
  `/private/tmp/pokemon-combat-save-contracts-01`.
- World adapter is still staged only: `/private/tmp/pokemon-world-foundation/`
  has a nine-file patch, manifest, README and `validate_staged.py`. It overlays
  only owned files onto current source and qualifies 12 SDK cases + pilot PNGs.
  Root executed `/private/tmp/pokemon-world-contracts-01`: all 124 aggregate
  contracts passed. **Visual acceptance failed:** Route1 has 148,176 differing
  pixels and Mart 11,533 against independent previews. Root inspected both pairs;
  native shade patterns differ. Diagnose before integration, without modifying
  protected rendering or blessing a replacement golden. Player/Story/reset
  integration hooks are in README.

Root retains sole Simulator ownership. Current worker Source is frozen pending
root native/world tests. Follow-ups must explicitly release owned files.
Next: resolve pilot render differences, qualify/integrate world adapter, then compose
persistent session state/Save/Continue and actual party/inventory/capture UI.
The complete campaign/postgame goal remains active.

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
and 423 moves. It still fails explicit unimplemented/review/unverified mechanics.
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
| `harness` | Lossless integer protocol host changes live; runtime patch staged. Next diagnose pilot preview/native mismatch. World adapter remains staged. |
| `rules_contracts` | Prior foundations integrated and validated; now growth/XP research and staged implementation at `/private/tmp/pokemon-growth-foundation`. No live Source edits. |
| `visual_catalog` | Prior party/save foundations integrated; now tracing all 302 battle PNGs against pinned originals. No Source art edits. |

Shared checkout uses disjoint ownership. No worker runs the Simulator. Root must
review diffs, apply only owned staged files, run integrated SDK contracts and
inspect resulting images before accepting implementation.

## Next executable work

1. Accepted foundations are committed at `75b7d05`; keep subsequent changes
   separate until integrated checks and visual review pass.
2. Integrate/qualify lossless harness integer wire transport with real SDK large
   positive/negative seed and assertion cases.
3. Diagnose pilot preview/native discrepancy; validate world adapter and integrate
   only its nine owned files plus root Story/Player/reset seams. Rerun catalog and
   natural intros. Never reapply historical learnset/party/save patches.
4. Compose authoritative GameSession, aggregate codec, Save/Continue and actual
   party/storage/inventory UI. Primitives and codec alone are not gameplay.
5. Integrate independently sourced growth/XP and remaining special move behavior;
   connect capture, switching, multi-member battles, healing and checkpoint rules.
6. Bind Route 1 and Viridian gameplay, padding/camera, NPCs, parcel/shop quests and
   exact connections; preserve authored Pallet and validate natural play/save.
7. Continue connected campaign milestones through Champion/credits/postgame.

| Full-goal milestone | Status |
|---|---|
| Harness and protected references | Accepted with evidence above |
| Domain/data/party/items/save foundations | Integrated primitives/learning/combat; session and gameplay integration pending |
| Pallet–Brock coherent campaign | Pending |
| Mt. Moon–Cerulean–S.S. Anne | Pending |
| Connected midgame Kanto | Pending |
| Late gyms–Champion–credits | Pending |
| Postgame/audio/performance/release | Pending |

Physical-device performance has not been validated. The source inventory is not
an implemented campaign, and neither tooling nor these domain candidates complete
the persistent full-game objective.
