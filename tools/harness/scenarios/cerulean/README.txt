Goal 5.3 bounded host driver — root handoff

Branch: wip/cerulean-journey-driver
Exact required foundation: 66b9d9968f63b4ff9bcb1f4d26d333718fbc3e52
Foundation merge: cc6de68 (conflicts in run.py and capture-policy test resolved
using foundation versions, preserving its deliberate production staging change).
Map candidate read: 48943b7f70ba741bed360b712e79ab9f58ee5bd2
Story candidate read: f30515e048eccc97d8de68b9a94c71ac93a9fdc5
Neither content candidate was merged here. All Source remains root-owned.

Delivered

- New cerulean_journey.py subclasses BrockJourney. It calls Brock natural first,
  retaining the actual capture, party switching, medicine, training, learning,
  evolution and real-input Save evidence. Its continuation uses real directional
  input; no move/warp/debug/HP/item/flag commands are permitted in natural mode.
- The shared compiled cache and active source manifest supply collision,
  padding, grass, ledges, blocked warps, LAST_MAP and header adjustments. Floor
  routing retains exact arrival cells, so disconnected Mt. Moon corridors do
  not become shortcuts. Each runtime step still replans actual NPC occupancy.
- Required path: Route 3 trainers, Mt. Moon Moon Stone, Rocket object 2,
  positional Super Nerd battle, selected fossil, Route 4, Cerulean Center/Misty,
  starter-specific Bridge rival, all five bridge trainers and Nugget Rocket,
  Route 24/25, Bill separator, Ticket, real house departure, Save/Continue.
- Three natural restart cases cover Squirtle, Bulbasaur and Charmander. Charmander
  selects Helix; the other two select Dome. Five clearly supplementary cases
  cover Ticket/TM11/full-bag retry, both fossil choices/exclusion, and actual
  trainer blackout to an actual Center checkpoint. Fixtures supply only starting
  positions, party and inventory, never a victorious battle or successful reward.
- Natural rewards require stable flags and exact inventory changes. Trainer
  checks require actual teams, stable receipt IDs, source payouts and money
  deltas. No narrative text is a reward or victory oracle. Save receipts contain
  the inherited durable state plus an actual SessionCodec-validated payload.
- Per-request/frame limits and inherited action/step/encounter/training budgets
  remain. Cross-map searches cap their nodes and physical transitions. Exhaustion
  or genuine natural failure stays a failure; no restart with convenient state.

Root registration (unapplied)

Apply root-registration.patch after composing 5.2 and the content candidates.
It changes only four existing host modules:

1. BrockJourney: default-false advance_event hook in its existing bounded drain;
   optional exact event_id filter in warp; overridable stock validation. No
   battle/dialog/learning/evolution/navigation implementation is copied.
2. journeys.py: three-name dispatch to this module.
3. restarting.py: bounded Cerulean configuration/sequence validation, receipt
   kind registration, validated immutable receipt reads and Continue forwarding.
   The actual owned-process lifecycle and private Data rules remain unchanged.
4. brock_capture.py: Pillow preflight registration for natural/Continue.

The patch is separately reviewed/applied by root; it is not active on this branch.
The existing suite recursively discovers the eight new JSON scenarios without
any suite.py change. Root can select cerulean--restart-squirtle, etc. Set a
sufficient finite suite --job-timeout for full New Game runs; the default 240s
has not been established as adequate for this extended path.

Required read-only root integration

The driver deliberately fails before natural gameplay when any dependency is
missing. The following is an API contract, not fabricated acceptance evidence.

A. Compose the active Source/data/sourceMaps.json and sourceMapCache normally.
   All 15 required new map IDs must be active. The host uses source-manifest.json
   from the identified staged build and hashes every consumed JSON input.

B. Export Source/data/ceruleanJourney.json from the actual registered owners for
   the staged build (not from English text or hand-guessed teams). Fields:

   schema: 1
   source_revision: af519899719f0754965776faac0e836a3b906e6d
   sources: mapping of Source-relative dependency paths to their exact SHA256
   events: array or map of actually registered stable source event IDs
   trainers: stable ID -> actual TrainerEvents definition
   rivals: pokered:CERULEAN_CITY:objects:1 -> starter -> actual definition
   shops: clerk stable ID -> {stock: [actual ItemData IDs], prices: {ID: price}}
   session_codec: actual current SessionCodec version
   bill_pc_player: {id: pokered:BILLS_HOUSE:hidden_events:1,
                    x: resolved SOURCE player x, y: resolved SOURCE player y,
                    facing: actual required direction}

   Required source hashes include data/sourceMaps.json, domain/sessionCodec.lua,
   data/items.lua, data/sourceSlice/trainers.json and
   data/ceruleanStory/events.json. Include all additional runtime planner/owner
   files used to produce the projection. Do not include the projection's own
   hash in its sources. The normal staged source manifest identifies it.
   Definitions need id, map_id, party, payout and source_object_index where
   applicable. party is the actual registered ordered source roster, including
   any source metadata; do not normalize one side differently. Shops used are
   Pewter and Cerulean clerks. Actual stock checks happen before spending; actual
   money and quantity changes still verify the input-driven purchase.

C. Snapshot read-only diagnostics, with no RNG draws, state repair or writes:

   session_codec = {version: actual version, valid: actual validation result,
     roundtrip_equal: actual canonical encode/decode comparison,
     payload: complete canonical save/load boundary session payload}

   The payload must represent the actual saved/loaded boundary and include all
   durable codec state, including RNG/world/actors/storage. It must not be a
   host reconstruction of selected quest flags or freshly sampled idle motion.
   Continue compares it and the inherited receipt state exactly. Diagnostic
   validity/version are checked again after retries and blackout. Keep this a
   read-only projection of existing owner data, not a new progression owner.

   During each trainer battle, event.trainer.definition must expose
     {id: stable ID, party: actual full ordered team, payout: source payout}.
   Preserve this observed team through the battle snapshot. The actual terminal
   last_battle_outcome must include trainer_id alongside the existing won/kind/
   payout/money_delta/blackout fields. The driver checks those receipts and then
   the authoritative session trainer flags. This supplements existing Brock
   APIs; no game outcome is supplied by the driver.

Known missing story integration and candidate defects

- Map 48943b7 reserves Cerulean City's rival and Route 24's Nugget gift/Rocket
  scenes; story f30515e implements Bill/Nerd/fossils/Misty, not those two scenes.
  The root must implement/register the actual Bridge rival counter-pick,
  approach/departure and Nugget gift/recruitment/battle flow. Their absence or
  missing actual per-starter teams fails closed; no ordinary trainer substitution.
- Concrete geometry conflict: f30515e scenes.pc and its integration note call
  source (1,4) the player's PC position. Both pinned BillsHouse raw collision
  and the candidate compiled cache mark that cell blocked. hidden_events.asm
  names (1,4), and BillsHousePC requires facing up. Root must resolve hidden-event
  target versus player-standing coordinates in the real dispatcher. The host
  consumes bill_pc_player from that corrected production binding, verifies its
  collision and then demands the actual hidden stable-ID dispatch. It never
  patches collision, teleports onto the PC or silently substitutes a position.
- Bill's active monster/human visibility and fossil disappearance need the story
  worker's normal reconcile hooks. The Nerd must fire at the source positional
  trigger with its own confirmed battle receipt. Source-controlled reward flags
  include EVENT_GOT_NUGGET, EVENT_GOT_TM11, EVENT_GOT_SS_TICKET and both fossils.
- The current root Source has no Cerulean maps, owner export, new diagnostics or
  dispatch registration. Native passage is therefore intentionally unavailable.
  Root must compose these after 5.2 acceptance, then run the current merged build.
- Optional Route 22 rival and museum Old Amber are not supplied as journey cases.
  The museum's natural access/Cut progression must not be invented for this gate.
  The old-man catching tutorial and Pewter escort remain explicit 5.3 scope,
  owned separately by root. Bike shop/robbed-house bespoke flow is not certified
  by this driver. No ordinary pacing/balance, new-art or device claim is made.

Validation (no Simulator launched, no push, no delegation)

Use source ~/Developer/Pokemon-PlayDate-env/env.sh before commands.
Evidence: ~/Developer/Pokemon-PlayDate-env/evidence/cerulean-journey-host-20261026-01/

- Real SDK 3.1.2 run.py --build-only compilation passed. This builds the merged
  foundation Source; it does not claim that the two unmerged content candidates
  have native acceptance. build.json/build.log retain the exact identities.
- Python compilation passed. 65 focused host tests passed with zero skips,
  including 15 new data/configuration/graph/receipt/registration tests. These do
  not emulate Playdate, evaluate Lua, transpile regexes or simulate random rolls.
- New tests apply the separate patch only to temporary host files, import the
  resulting actual restart/dispatch code, validate all supplied process cases,
  exercise dispatch forwarding and reject modified immutable receipt bytes.
- suite --plan-only selected/copied all eight actual cases into discovery/.
  This proves recursive discovery and input identity, not runtime success.
- candidate-data-only/ is a host-only composition of immutable candidate JSON;
  it was never compiled or launched. Six collision/header/floor planning checks
  passed (candidate-geometry-plan.json). BillsHouse's blocked PC pose was
  separately inspected from the pinned raw record and candidate compact cache.
- Root still owns current native execution, owned PID/Save/Continue proof,
  key screenshot inspection, content coverage, ledger and main integration.
