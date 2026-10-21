# Full-game execution ledger

Persistent objective: [complete goal](../plans/astra-full-game-goal.md).
Status: **paused at the user’s request; campaign unfinished**. Resume from this ledger, then inspect the
owned task handoffs before changing files. Do not repeat the original audit.

## Current checkout / next continuation

**New explicit user decision:** add Gen V abilities, held items and natures for
the original151. This is required full-goal scope, not optional polish. Keep world/
story/art/roster constraints. See fidelity-ledger.md; plan persistence, specimen
generation/evolution, UI/acquisition and battle-event integration before enabling.


This pushed checkpoint follows6036974 (session/gameplay/source pipelines),
b53566d,75b7d05,a4e2f03. The later integrated Source described below is included.
Do not reapply old foundation/session/party/traversal/Event patches.

All three workers were interrupted on pause. No Simulator session remains active.
Full-game goal status is PAUSED; resume only when requested. Workers were explicitly
configured gpt-6.1-sol/medium; runtime exposed status but no resolved-model field.
No physical-device validation has been performed.

Live Source: four connected source maps Route1/City/Mart/Center, explicit slice
save policy, KantoWorld traversal/counters/16-update ledges, guarded EventState
parcel/Oak/BLUE/healing/checkpoint, ShopState, Pokédex151, capture throw/absorb/
shake/breakout, six early B2W2 move corrections + seed/trap/hazards/Toxic dependencies.
Pokémon names ASCII defaults preserve saved nicknames. Codec3 supports additive
badPoison; counter is battle-local. POKE item display spelling preserves sourceName.
DialogState generation identifies chained dialogue instances; host checks instance
plus line, keeping true stalled-dialog rejection. Full campaign remains incomplete.

Root accepted early combat: **335/335 contracts,6/6 jobs**, source-consistent
`/private/tmp/pokemon-early-combat-integrated-01`; all5 move native recipes passed,
root reviewed primary code/changes/native images. Original915 exact. Durable
[accepted-early-combat](accepted-early-combat/acceptance.json). Many other exposed
moves/abilities/items/weather still require implementation; no full GenV claim.

**Natural parcel04 PASS**: initial seed42 reset only, actual starter/BLUE win,
3 natural wild encounters/runs, Route1→Mart parcel→Oak/BLUE/Pokédex→Mart purchase→
healing decline/accept→save. No subsequent position/inventory/HP/outcome fixtures.
Root inspected Mart, shop, native BLUE arrival/departure40-frame sequences, healing
and saved scenes. Durable [accepted-parcel-functional](accepted-parcel-functional/evidence.json).
Earlier natural01/02/03 failures were host assumptions: empty quest[] mapping,
command-phase menu not yet active, and new chained dialog at same line1. Fixed,
regression tested, full natural04 rerun passed. Healing modal composition remains
polish work; source sprites and functional checkpoint are proven. Initial rival
175 payout/heal-after-both and general blackout money remain staged trainer work.

Latest root connected regression **337/337 SDK,9/9 jobs**, same Source:
`/private/tmp/pokemon-connected-regression-01`.42 real protocol cases incl Unicode
error/recovery, full-bag Potion/parcel retry, before/after visibility/checkpoint,
actual two-process Viridian Save/Continue, both failed-capture animation cases.
Restart includes actual nurse healing and preserves imported location/quest flags,
bag/money/HP/PP/outdoor checkpoint across owned PIDs. The suite is archived in
[accepted-connected-world](accepted-connected-world/acceptance.json); restart
PIDs97153→97208 preserve the exact save hash and scene pixels (0 changed).

Catalog1635 is now a reviewed static baseline in `catalog-viridian/`:720 additions,
no missing art, original915 EXACT. Independent35 EventArt and50 capture/jump source
comparisons pass. Raw loaded capture bitmap export initially shifted padding/masks;
a clear logical mask plus white-canvas render preserves both opacity and hiddenRGB.
The original failed evidence is retained. The final export proof passes338/338 SDK,
and every live Source file matched that tested private tree after integration.

Host265 tests passed after updating explicit count to424 plus Toxic PP/accuracy.
Three additional dialogue-instance host cases pass. Protocol now literalUTF8;
strict result decoding retained. ItemASCII display is a separate font adaptation.
Tools/profiling portable runner compiled and3tests passed. Root6-cycle observation
[observed-world-profile](observed-world-profile/evidence.json):4map install165ms,
postGC9179KiB, City views8–12ms/676sprites; retained cycle1→6 8771→8950KiB includes
observer/harness growth, not a proven leak. Original sample simulator=false is an
observer bug (SDK numeric1, fixed future coercion). No device capacity conclusion.

Pending worker candidates are archived under
[paused handoffs](../plans/paused-handoffs/README.md). They are NOT installed in
production Source. Restore packets to their named `/private/tmp` paths and verify
manifests before resuming; do not copy complete stale trees over live changes.

- Pewter provider/trainer: `pokemon-pewter-runtime-candidate-02`,22 new contracts,
  compiled only. LRU2 imported-zone cache, compact terrain/sparse ledger, pure save
  validation, rollback and300-image isolated catalog. Separate trainer-domain
  native proof347/347 passed; final combined provider remains untested. Default
  fullcatalog aggregation and natural Brock journey remain pending.
- PC: `pokemon-pc-ui-followup-01` passed354/354 SDK and its real two-process
  deposit→box save→Continue→withdraw scenario passed. Root reviewed all5 panels.
  Source is unmerged; serial-merge context/save/storage hooks with other candidates.
- Healing: `pokemon-healing-presentation` passed342/342 SDK before a test-export
  path defect was found. Export path and14 required outputs are repaired/compiled;
  rerun to obtain actual panels before accepting in-world composition. Original
  EventArt unchanged; source palette-flash refinement remains pending.
- Evolution: `pokemon-evolution` passed364/364 SDK. Followup01 adds same-visit stale
  callback guard (27 new evolution groups), compiled but not run. Codec4 with
  explicit old3 migration, original151 graph, stone/level/trade-hook seams. Keep
  HP0 on qualifying Gen5 victory/run/caught returns; discard pending on defeat.
- Midbattle learning: `pokemon-battle-learning-contract-followup`, compiled only;
 18 learning groups plus2 learning→evolution integration groups, with optional
  evolution packet composition. Actual LearningState receipts suspend before the
  next enemy; input release gate prevents accidental choice. Existing contract
  helpers drive genuine learning rather than deleting queues. Native recipes ready.
- Battle medicine: `pokemon-battle-items`, proposal/partial stage at pause; requires
  review, completion and native proof. Current production battle bag supports balls.
- GenV attributes: explicit user requirement includes abilities, held items and
  natures. Source audit only, no implementation yet. Persistent ability-slot/HA
  identity must survive evolution (including same-ability intermediate species).
  Nature is independently stored in B2W2, not inferred from PID. Read worker notes.

Next on an authorized resume: validate/review the frozen candidates, merge narrow
shared-file hunks, run integrated SDK/journeys and inspect real images; then finish
Pallet–Brock and every remaining campaign/postgame milestone. Current integrated
build reaches the functional Viridian parcel/Pokédex milestone. No full-game
completion is claimed.

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
| `harness` | Source-backed Pewter runtime, bounded imported provider, trainer integration. |
| `rules_contracts` | Evolution domain/overlay/persistence and exact Gen5 sequencing. |
| `visual_catalog` | Capture export repair, frozenPC candidate, healing composition proposal. |

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
