# Parcel journey driver

The host driver and five scenarios are executable candidates, not runtime passage
proof. Root still owns Simulator execution and the event/shop/heal/diagnostic
integration. No Source file or shared runner was edited by this task.

`tools/harness/parcel_dispatch.patch` gives root the small `journeys.run` dispatch
hunk. It preserves existing journeys and the other worker's restart runner.
Scenarios live in `tools/harness/parcel-scenarios`, outside the default suite's
case glob while their runtime dependencies remain under construction. Once root
accepts the interface/integration, invoke the explicit scenario path:

```sh
python3 tools/harness/run.py \
  --scenario tools/harness/parcel-scenarios/natural.json \
  --output /private/tmp/pokemon-parcel-natural-UNIQUE
```

Root alone runs this command; workers may run host tests/planning only.

## Geometry and provenance

Imported maps are read from the exact identified runner output's staged Source,
verified against its source-manifest.json and immutable pokered revision
`af519899719f0754965776faac0e836a3b906e6d`. The driver retains numeric source cell
collision/foot metadata, original one-way two-cell ledges, forbidden tile pairs,
NPC/door coordinates and Mart's +2-cell padding. It replans each real step with
current NPC occupancy and blocks other doors. Grass has a routing cost; encounters
remain enabled. Wild fights use real RUN menu attempts; failure/blackout is not
replaced with a forced outcome.

`parcel_authored.json` contains Pallet/lab collision grids independently decoded
from root's SDK runtime02 uniform32x32 collision images, plus grass identified
against that same catalog's tile08. It is pinned to the compiled data/maps.lua
SHA and records the evidence PNG hashes. Changed authored Source fails before
navigation; regenerate/review the SDK reference rather than silently reuse it.
No Lua parsing or transpilation is used.

The protected Pallet +/-1 seam comes from the reviewed map-pilot reference;
Route1/City +/-10 comes from original header metadata. Crossings verify those
projections before sending input. Only explicit source edge doors or supported
connections may cross zones. Imported bottom-row interior doors preserve the explicit outward-input usability adaptation: standing on the mat does not exit; the driver presses down once. First Mart entry uses the real door marker, including full-bag supplementary setup; Continue never fabricates that marker. Ledge steps wait for the full sixteen native updates.

Runtime mismatches fail with the ordinary request,
snapshot, trace and capture evidence.

Offline action plan, with **no Simulator launch**:

```sh
python3 tools/harness/parcel_journey.py --plan \
  --bundle-source /private/tmp/identified-build-output \
  --output /private/tmp/pokemon-parcel-plan-UNIQUE.json
PARCEL_BUNDLE_SOURCE=/private/tmp/identified-build-output \
  python3 -m unittest discover -s tools/tests -p test_parcel_journey.py -v
```

Ten host tests passed against pokemon-viridian-slice-build-06, covering real
source routes/counters/projections, one-way ledges/occupied landings, collision
and unrelated door rejection, malformed/stale references, forbidden natural
shortcuts and failure summary publication. The eleven-segment offline plan was
written to /private/tmp/pokemon-parcel-plan-03.json. `ok:false` explicitly marks
this as a plan, not gameplay acceptance.

## Runtime interface agreed with root

Snapshot paths: `zone` is the registry key; `zone_id` is stable.
`session.flags.quest` is the flat quest flag dictionary, not the outer flags
object. `session.inventory` has slots/money; `session.party` has active/members;
`session.checkpoint` has zone_id/x/y/facing. Party members expose hp/maxHP/status/
pp and need read-only maxPP by move for exact full-party healing assertions.

Root UI states/phases:

* event: id/phase/waiting; dialog uses real A, movement/animation waits. Healing
  stops at heal-confirm; event.menu.selected1 is YES,2 NO.
* shop: mode BUY1 -> browse -> quantity1 -> confirm YES1 -> result. A returns to
  browse; B backs through mode to close. Selected item must be source pokeBall;
  the driver verifies one added ball and exactly200 deducted from observed money.
* pause: B opens menu; SAVE index4 -> phase save, YES1 -> saved root dialog.
  pause.lastSave.ok survives exit and must be true.
* bag: list/actions/toss/message/move; selected is the slot;
  bag.menu.selected2 selects TOSS, then YES2. These inputs free a real slot.

The driver writes parcel-dependencies.json and checks required diagnostics/maps
before the journey. It fails clearly if the integration is missing. Host driver
and authored-reference hashes are retained in its summary.

## Scenarios and acceptance

`natural.json` uses existing Journey.natural_intro with one seed-only new-game
reset. It forbids every later fixture, teleport, direct battle, encounter toggle,
HP edit, outcome adjustment or inventory grant. Rival victory is an assertion
on the real fight, not a forced result. It then walks the actual route to Mart,
receives exactly one parcel, reenters to reject duplication, returns to authored
Oak, verifies atomic parcel removal/Pokédex flags, returns for a real purchase,
visits Center, declines then accepts healing/checkpoint, and saves through B menu.
The Oak actor scene and entry movement must be real root event execution.

Supplementary scenarios are separately labeled and cannot certify natural play:

* full-bag-potion / full-bag-parcel use only the root-approved initial fixture
  options inventory/quest_flags/party_pokemon. Twenty slots are genuinely full
  for either reward (Potion99 plus19 different single ordinary items). Failed
  rewards must preserve the flag/item; real bag TOSS frees one slot, interaction
  retries, and another interaction must not duplicate the reward. Parcel case
  also requires the original full-bag entry movement to finish at padded(4,5).
* visibility-checkpoint-before / after use initial quest fixtures to check exact
  sleeping/awake source NPC identities. After Pokédex, the driver physically
  walks onto the freed(18,9) source floor. Two damaged/status party members make
  decline/no-change and full-party healing/checkpoint proof meaningful. The
  accepted checkpoint is outdoor pokered:VIRIDIAN_CITY(23,26), facing down.

Root's complete fixture preflight extension is a declared dependency for these
supplementary cases. The host does not invent another command or inventory owner.
Restart/Continue is owned by the separate restart scenarios; this driver verifies
the actual save UI and does not claim a fresh-process reload by itself.

Battle UI compatibility: the driver selects RUN from battle.menu.options when
provided, using battle.menu.columns for real two-column direction input. The old
confirmed FIGHT/RUN menu remains supported when these optional fields are absent.
A red/green host regression covers the expanded four-action two-column menu.
