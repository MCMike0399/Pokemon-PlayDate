Milestone 5.4 real-input driver preparation
=========================================

Branch: wip/vermilion-journey. Exact root f8d5ce88504f3439ace431ad8b8845ed5d9baa26
was merged first (local merge 2486823). No Simulator, runtime process, push or
delegation was used. These are executable candidates, not acceptance evidence.

Owned additions only:
- tools/harness/vermilion_journey.py
- this directory (11 scenarios and the two unapplied root patches)
- tools/generate_vermilion_journey.py and Source/data/vermilionJourney.json
- tools/tests/test_vermilion_journey.py

Root handoff
------------

Apply root-registration.patch to journeys.py/restarting.py/brock_capture.py only
when ready to register this driver. suite.py already discovers all 11 JSON cases
recursively; it needs no edit. The patch adds dispatch, process validation and
immutable receipt registration. It does not launch anything or import a save.

root-observations.patch adds one small field_move UI snapshot (phase/menu/last
result), explicit registered-owner qualification, detached current-map collision
and four Cut cell keys, and the Day Care owner's detached record and withdrawal
quote. All are read-only. No full codec enters a per-frame snapshot. Existing
owners qualification checks every previously projected trainer, allowing the new
registered trainers alongside it. Root must review this change on composition.

Regenerate both projections after composition, in this order:

    source ~/Developer/Pokemon-PlayDate-env/env.sh
    python tools/generate_cerulean_journey.py
    python tools/generate_vermilion_journey.py
    python tools/generate_vermilion_journey.py --check
    python -m unittest tools.tests.test_vermilion_journey -v

The projection describes declarations, not registration. It hashes 35 prepared
map files, their descriptors, ordinary events/trainers, all Anne rival variants,
gifts, field mechanics, machine compatibility, and relevant owner/wiring inputs.
It rejects changed staged bytes and inactive maps before any runtime request.
The base intentionally still has 30 active maps. Final composition must update
its existing manifest/cache/provider/bindings through their owners, not this
worker. Maps becoming active must match the reviewed prepared pins.

Natural path and honest limits
------------------------------

restart-{bulbasaur,charmander,squirtle}.json starts the entire existing
CeruleanJourney New Game path in the same process. It retains the actual intro,
Brock, fossil, Misty, Bridge, Bill and Ticket inputs, RNG, training, learning,
evolution, battle PP/items, trainer receipts and payouts. No accepted 5.3 save
was imported, copied or assumed. Root chooses the final runtime start. This
branch deliberately offers no arbitrary save-import shortcut.

The continuation is robbed-house Rocket, Route 5, Day Care, Underground north/
south, Route 6, Vermilion Center/Fan Club/Old Rod, every disconnected Anne cabin
component plus kitchen/upper deck/bow, positional Anne rival, Captain HM01,
actual Bag -> Teaching -> Cut, actual party field menu -> tree, ship departure,
Surge's real switch interactions/battle/TM24, Diglett's Cave and Route 2 HM05
aide, then Route 11 and real Save. The second process selects actual Continue
and compares the entire immutable canonical payload. A completed driver is
still pending root screenshot inspection and acceptance.

Read-only worker snapshots used: wip/daycare at 1886005 and the existing private
Anne/Surge and FieldMoves/FieldWorld inputs. They were not merged. Day Care
selection uses its exact story-choice and daycare-party controller phases.
A real eligible nonstarter is deposited, real map travel banks completed-step
XP, and paid withdrawal checks the held specimen, XP, traits and quoted charge.
The canonical schema-3 Day Care field is preserved in Save/Continue receipts;
the earlier schema-1/2 payloads retain their strict envelopes. SDK validation
owns complete nested Pokemon semantics.

Remaining inputs are explicit and must not be bypassed:

1. Activate the 35 prepared maps and source-bound exits/events/actors, including
   source-owned padding, last-outdoor warps, hidden can dispatch, dock departure,
   and closed/open Gym terrain. Compose the single event subclass chain for
   Day Care, gifts and Anne/Surge. Integrate worker API patches through root.
2. Integrate Day Care 1886005 modules/policy, session ownership, completed-step
   hook and schema 3. The current projection declares daycare_inputs=[] and
   preflight rejects that after the inactive-map check. Regeneration discovers
   both committed modules and pins policy/events only after root composition.
3. Integrate temporary Cut/map-reload/process-Continue behavior from its owner.
   The host path model refreshes actual terrain at each transition; it never
   changes production tiles, field state or a ledger.
4. Select a feasible natural acquisition/training plan. The inherited path
   captures actual specimens, but this candidate does not claim it reaches ten
   unique owned species or guarantees a Cut-compatible party for Squirtle. A
   missing compatible user, eligible Day Care member, or HM05 threshold fails
   closed. Seen species and duplicate specimens cannot count as unique owned.
   No artificial species, HP edit, teleport or flag seeding can fix natural mode.
5. Owned-species fixture support for the two aide full-bag supplements remains
   unavailable. Existing fixture API can seed at most six actual party members;
   it exposes seen, not owned, dex entries. hm05-full-retry and itemfinder-full-
   retry are explicitly supplementary blocked candidates and raise with that
   reason. No new fixture API or save editing is supplied here.
6. Independently run all candidates on one integrated frozen build, inspect key
   native screens and process generations. No native result is claimed here.

Supplements
-----------

hm01/tm24/voucher/rod-full-retry use explicit initial fixtures, twenty actual
bag slots, the actual scene/battle and owner reward transaction, an actual toss,
then retry. Money/battle counts and repeated interaction prevent duplicate
payout/item credit. TM24 requires a real Surge win and badge with the bag full.
The two aide cases above are labeled supplementary and remain blocked.

blackout uses an explicit level-1 fixture, real Center checkpoint and actual
Route 6 trainer loss; no HP/outcome edit. The inherited recovery checks actual
half-money, undefeated trainer, restored HP/PP/status and checkpoint position.

field-cut-reload uses an explicit compatible specimen/HM/badge fixture, actual
Teaching and field menu Cut, a real Center round trip proving tree restoration,
a second Cut and actual Save. The restarted process must Continue the exact
payload, and temporary tree removal must be restored. It is not natural credit.

Root-only eventual invocation (not executed by this worker):

    python tools/harness/run.py --scenario tools/harness/scenarios/vermilion/restart-squirtle.json --output "$HOME/Developer/Pokemon-PlayDate-env/evidence/vermilion-root-squirtle-UNIQUE"

Repeat for the other starter files and supplementary cases only under the
single runtime owner. Keep all durable outputs under that evidence directory.

Host checks
-----------

67 tests passed, zero skips: new driver boundaries, existing Cerulean boundaries,
and pinned Vermilion gifts/story/preparation generation. Log:
~/Developer/Pokemon-PlayDate-env/evidence/vermilion-journey-host-tests.txt

Tests cover bounds/shortcut rejection, inactive maps before input, staged owner
pin drift, corrupt map/counter pins, unique-owned aide gating, missing Cut user,
Day Care eligibility, finite puzzle search, detached collision updates, codec
boundary-only payloads, schema-3 envelope validation, immutable process receipts,
and dispatch/read-only patches applying in isolated host copies. These tests do
not emulate the SDK, battle outcomes or RNG, and confer no runtime acceptance.
