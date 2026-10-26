# Kanto services: bounded implementation handoff

Branch `wip/kanto-services` starts exactly at `e890839` (the private 30-map,
all-scene candidate). This implements three services, not milestone acceptance.
Only existing Source edit: the atomic paid-gift method in GameSession. No
Simulator, push, delegation, art, maps, existing scene modules or ledger changes.

## Root integration

Apply `tools/integration/kanto-services.patch` after reviewing composition with
other pending bootstrap patches. It adds one import, installs this source once,
selects `KantoServicesState` as the single `event` executor, adds the museum
exploration/map-entry hooks, and registers the new harness-only SDK suite.
The patch was checked against the exact base plus this worker's changes.
Regenerate for a changed composed root with:

```sh
python -m tools.integration.build_kanto_services_patch --root <checkout> --output <patch>
```

Install the existing ordinary content and scene candidates as their own packets
require. Install KantoServices once before contexts construct TrainerEvents.
Import it after `ceruleanRoutesState`: its subclass delegates every non-service
scene to that existing executor. No second event dispatcher or ordinary content
registration is added. Current ordinary event descriptor overlap is **empty**.
Only these bespoke object IDs are registered:

- `pokered:MUSEUM_1F:objects:1`
- `pokered:MT_MOON_POKECENTER:objects:4`
- `pokered:BIKE_SHOP:objects:1`

Retain the ordinary Museum scientist 2 Old Amber gift, museum visitors, Bike
Shop woman and conditional youngster, Center nurse and other ordinary actors.
If later root changes introduce any of the three IDs above, omit only those
ordinary descriptors before registration. No trainer rows are added here.
TMs already route through Teaching.isMachine; no teaching change is needed.

## Source policy

References are vendored at `tools/references/kanto-services`, with SHA-256 pins
from pokered `af519899719f0754965776faac0e836a3b906e6d`. The generator verifies
scripts, object order, price/operation anchors and text inputs before projection.
Story/text/prices/branches follow Blue; acquired specimen traits follow the
existing Gen V ordinary gift policy, not the Blue trainer fixed-IV policy.

Museum admission costs 50. Source automatic triggers are `(9,4)` and `(10,4)`;
refusal/insufficient funds backs the player down one cell. Admission remains
valid through Museum1F/2F visits and Continue there. Pewter's default script
resets `EVENT_BOUGHT_MUSEUM_TICKET`; the map-entry hook implements that reset,
including Continue in town. Behind-counter `(13,4)` / `(12,3)` gets the actual
Amber explanation choice. No permanent admission/unlock flag or Cut back-door
bypass is created; existing map geometry still controls Old Amber access.

Magikarp costs 500, level 5, once via `EVENT_BOUGHT_MAGIKARP`. Source GivePokemon
sends a full party's gift to the **selected** PC box; a full selected box fails,
even if another box is empty. The owner validates money, capacity, flag limits,
codec and Pokédex before mutation and builds the specimen on a detached stream.
Failed/cancelled attempts do not debit cash, claim a mon, set the flag or advance
rules RNG. Success commits the ordinary gift's nature, normal ability slot,
sex and six IV samples, plus cash/flag/dex/RNG exactly once. No new acquisition
policy or duplicate gift domain abstraction was needed.

Without a voucher the shop offers BICYCLE / CANCEL at 1,000,000; selecting it
always gives the source unaffordable dialogue. With a voucher, source has no
extra confirmation menu: dismissing the introduction commits the exchange.
The atomic transaction grants bicycle **before** removing voucher, preserving
source full-bag failure. An interrupted introduction cannot consume the voucher;
receipt/revisit uses `EVENT_GOT_BICYCLE`. Stale UI callbacks are epoch/serial and
session/player/zone/top-state guarded by EventState.

## Checks and remaining acceptance

Host: all 35 relevant service/content/story/routes generator/input checks pass
(6 new service checks). SDK 3.1.2 compile-only succeeds, including a private
staging copy explicitly importing the new executor and registering its suite.
No Lua was executed through a host interpreter or fake SDK.

Compile evidence under `~/Developer/Pokemon-PlayDate-env/evidence/`:
`kanto-services-compile-20261026-01` and
`kanto-services-contract-compile-20261026-01`. The latter retains a per-file
manifest and declared import overlays; neither directory claims runtime results.

`KantoServicesContracts` prepares 20 real SDK cases using actual imported zones,
source sprites/NPCMotion, DialogState, composed event state and SessionCodec.
They cover admission/decline/insufficient funds/behind-counter/revisit/Continue
policy, exact paid gift/ordinary traits/selected-box/full capacity/retry,
flag-capacity and stale-money rejection, no-voucher menu, full-bag voucher retry,
codec persistence, cancelled/stale/replayed callbacks and RNG stability.
Missing source installation fails explicitly. The root must execute the suite,
check native menus/screenshots, then do integrated real-input and process-restart
acceptance. Worker codec tests are not process-restart or campaign proof.
