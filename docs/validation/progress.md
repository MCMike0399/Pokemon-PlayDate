# Full-game execution ledger

Persistent objective: [complete goal](../plans/astra-full-game-goal.md).
Status: **active; campaign unfinished**. Resume from this ledger, then inspect the
owned task handoffs before changing files. Do not repeat the original audit.

## Current checkout / next continuation

Committed checkpoints: harness `b53566d`, foundations `75b7d05`, battle-art
provenance `a4e2f03` (HEAD before the next checkpoint). Later Source is integrated
and independently tested. **Do not reapply historical foundation/bridge/party/
slice/followup/catalog patches over current code.**

Latest root integrated acceptance: **244/244 SDK contracts,14/14 native jobs**,
all same source hash, `/private/tmp/pokemon-session-party-integrated-suite-01`.
It covers field party/stats/bag/medicine, voluntary sleep reset and forced switch,
successful/failed capture commands, checkpoint blackout, overlays,41 protocol
fault cases, all3 natural starter intros and actual two-process Save/Continue.
Root inspected native menus, stats, capture/forced-switch scenes and Continue.
Original915 visual artifacts remain EXACT. Current catalog adds292 valid but
explicitly unreviewed artifacts; full installed four-map catalog remains pending.
Durable evidence: [accepted-session-gameplay](accepted-session-gameplay/acceptance.json).
212 host tests passed at the combined run; subsequent added generators have
separate check-only proofs.

Live Source includes authoritative GameSession/SessionCodec, lossless saves/RNG/
integer command transport, correct B2W2 learnsets/growth/participant XP,423 moves
with pinned target metadata, Party/Storage/Inventory/items, PokemonCodec3 with
original sleepDuration, player/enemy-team battle seams, capture rules and actual
party/bag selection overlays. `game.playerPokemon` is gone: use getPlayerPokemon().
Story delegates session tuples; trainer flags have stable IDs. B opens field menu.
No-save boot retains Oak opening; existing save opens Continue/New Game. Initial
money3000, empty party/bag, bedroom checkpoint. General blackout uses checkpoint;
intro rival keeps lab exception. All pending party learning queues are drained.

Source-backed world registry/views/deltas and four-map Viridian modules are live,
but four new maps are NOT registered/connected yet. Source followup fixes full-bag
entry movement, idempotent sprite install, defensive binding flags and10 simple
local dialogue handlers. Registry-aware catalog is applied; do not register its
coverage tests until production maps are installed. Root separately proved96 new
source sprite/mask/terrain comparisons exact and inspected City/Mart/Center
composites: `accepted-viridian-art/`, runtime `/private/tmp/pokemon-viridian-slice-runtime-02`.
Preserve original render calls; only new imported tiles/NPCs use explicit phase0.

Known capture presentation gap: caught enemy remains visible behind result text.
Rules/ownership commands passed; animation acceptance is NOT claimed. Original-art
throw/absorb/shake/breakout/caught scene is staged for root next.

Runtime ownership: root alone launches/owns Simulator/private Data. **Current
single native job** is staged Shop UI, exec session77477, output
`/private/tmp/pokemon-shop-ui-runtime-01`. Poll/finish before another launch.
No other Simulator job is active. All workers remain explicit Sol6.1/medium.

Pending staged work (do NOT overwrite root main/UI with old staging trees):

- `/private/tmp/pokemon-shop-ui`: two new Source modules,12 SDK groups; running.
- `/private/tmp/pokemon-event-ui`: five new Source files,16 SDK groups, pinned7
  event images; root helper uses current SliceEvents7e2c... and optional staged
  ShopState only if absent. Actual Oak/Blue motion/receipt/heal review pending.
- `/private/tmp/pokemon-kanto-traversal`: worker still implementing source
  connections/ledges/entry/counters/install, preserving root pause/B policy.
- `/private/tmp/pokemon-capture-animation`: Scene/module/data/9 PNGs,13 SDK groups,
  three native scenarios. Root must add scene:exit and capture_animation snapshot.
- Event-art catalog extension/profiling probe is staged by visual worker.
- Host parcel journey/scenarios are live but dispatch is a separate patch
  `tools/harness/parcel_dispatch.patch`; natural journey not run yet.

Fixture party_pokemon/inventory/quest_flags and sleep_duration are implemented
and native-tested. Read harness/scenario files for exact schema. Diagnostics
include session.{party,inventory,flags,checkpoint}, top-level party/inventory
aliases, pause/title/party_ui/bag, maxPP, battle selection/capture result and menu
options/columns. Event/shop/traversal snapshots still need owner wiring.

The complete campaign/postgame objective is active. No physical-device claim.

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
| `harness` | Source slice/followup and host parcel driver delivered. Now stages Kanto traversal/install/ledges/connections; no live Source edits. Portable Viridian generator checks all6 current JSONs exactly. |
| `rules_contracts` | Party/capture rules integrated; capture animation frozen at `/private/tmp/pokemon-capture-animation`, native proof pending. |
| `visual_catalog` | Session bridge/restart/catalog delivered; Shop native job running, Event UI frozen, event-art catalog followup/profiling probe underway. |

Shared checkout uses disjoint ownership. No worker runs the Simulator. Root must
review diffs, apply only owned staged files, run integrated SDK contracts and
inspect resulting images before accepting implementation.

## Next executable work

1. Poll Shop SDK job77477, inspect/review and apply only owned modules, register
   shop state/contract/snapshot. Run staged Event UI next, review source assets and
   BLUE arrival/departure motion; apply guarded operations only after proof.
2. Run capture-animation SDK+three native scenarios. Root integrates scene exit
   cleanup and snapshot; verify early input can't skip animation or spend RNG.
3. Integrate staged Kanto traversal and event-art catalog, register maps with
   explicit slice save-location whitelist before GameSaves startup. Preserve
   authored Pallet±1, Route1/City±10, edge-down interior usability; no unsupported
   generic Center/later-Mart auto-step. Continue must not replay entry scripts.
4. Wire EventState/source NPC/counter/background interactions and entry scripts;
   source text/state for Oak parcel/Pokedex actor scene, shop and healing outdoor
   checkpoint. Full bag must retry; no receipt claim before atomic commit.
5. Run natural intro→Mart parcel→Oak→shop/heal/save plus supplementary full-bag/
   old-man/checkpoint scenarios; review expanded catalog and native ledge/capture/
   cutscene motion. Source slice readiness is not complete campaign readiness.
6. Commit accepted checkpoints/evidence and keep ledger current. Before bulk map
   expansion, measure retained heap/startup/map-entry and determine lazy loading
   needs. Continue Pallet–Brock and every campaign/postgame milestone; don't stop.

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
