Isolated cave-step performance candidate, 2026-11-01

Exact parent: 565bfdfb4c0f2b37c921fa79e143067fe45b7637 (private checkpoint B).
Logical origin: e7270b8c..ae97ca53, including the original RNG scratch seam
from merge 4a094116's mainline-2 delta. No merge or unrelated synchronization.
Only four production files change: domain/fieldEncounters.lua, lib/rng.lua,
world/zone.lua, game/overworldState.lua. The ae97ca53 root hooks ARE APPLIED
in this isolated candidate; there is no pending activation patch.

Preservation and boundaries
- The only Overworld changes are map-entry prepareZone and the ordinary
  prepare/resolve call becoming attemptStep. Reversing the original hook
  reproduces exact B's Overworld file. Safari completed-step accounting,
  Safari battle routing, update/input expiry checks, field-step early return,
  arrival handling, ghost/Snorlax/story dispatch and door precedence remain.
- Every other Source file and every existing contract name/assertion is byte
  identical to the exact parent. Reflect producer15, ChipAway introduction14,
  schema4, Safari/session/field-travel owners and all acquisition code remain.
  No maps, loot, art, contracts, journeys, registrations or framework added.
- One bounded map policy capture replaces per-step policy/roster copying.
  Equality checks inspect live plain values rather than granting epoch or
  table-identity trust. Changed descriptors take full schema validation.
  PokemonCodec examines live durable fields, including HP/PP and traits;
  owner, roster, ability, terrain, travel mode, policy and RNG are checked at
  both resolution boundaries. Acquisition gates, draw order and commit stay.
- Retained public plans have independent request storage and immutable policy
  captures; each token is fresh and one-shot. Cache replacement never rewrites
  an older token. Synchronous scratch does not escape, rejects step reentry,
  and releases map/session/party/member references on success or any error.
  Receipts remain independent. Resolution and encounters still allocate.
- Audited all 149 installed source water policies: rate byte zero, empty slots.
  Surf selects that water policy without borrowing land or consuming acquisition
  RNG. Future nonzero water policies explicitly fail as unbound; no water
  sampler is implemented. Existing Surf movement/connection owners are intact.

Completed validation (host and SDK compile ONLY)
Evidence prefix: ~/Developer/Pokemon-PlayDate-env/evidence/cave-b565-0542f971-
- compile-20261101/: real harness/dev SDK 3.1.2 build-only passed.
  Original Source SHA256:
  2ae8a1f92e13368e8bab84b1472b59ca1498e96101360bb5fe1c2444ea141a59
- production-20261101/: production SDK 3.1.2 compilation and shipped-data
  qualification passed, with both hooks already in the copied Source.
  Production staged fingerprint (includes normal build qualifications):
  9dd9f5dd94087b750e9d9c5e492e6b14515cf9eb15533fe4468a8d3b4b076783
- host-20261101.log: 50 tests passed, no errors/skips. Existing modules:
  test_field_acquisition_sources, test_field_move_data, test_field_world_data,
  test_field_travel_sources, test_tower_story, test_safari_service_sources,
  test_specimen_traits, test_move_producer_contract,
  test_protection_move_generation, test_production_build.
- Existing generator --check passed: source map cache plus binary cells
  (149 maps), immutable content cache (2578 artifacts), specimen traits and
  Light Ball, and Cerulean journey projection. No generator wrote Source.
- Coverage checker FAILS: Source fingerprint differs. Vermilion journey
  --check FAILS: projection stale. Their logs are coverage-20261101.log and
  vermilion-freshness-20261101.log. No matrix/projection/evidence relabeling.
- git diff --check passes. Full host discovery was not run. No Lua gameplay,
  native acceptance, resource measurement, performance gain or review claimed.

Root's existing native batches (not run here)
Use the existing selected-suite staging, preserving names and assertions:
  cave-encounters, field-encounters, field-acquisition, field-travel,
  source-encounters, rng-persistence, specimenContracts, specimen-ownership,
  held-items, held-lifecycle.
Run cave/field/acquisition and RNG/specimen/held batches in full. In B scope,
exclude only prefix "field-travel: Fly" from field-travel and prefix
"Dojo gift:" from source-encounters; these are the existing parked C filters.
Keep the other source-encounters case, "Bicycle session mode: reversible
false-to-false source bit and stale context guards", as well as ghosts/Snorlax.

Required existing cases include (literal names):
  MtMoon1F non-grass land reaches Blue byte 9 accepted and 10 rejected
  MtMoonB1F non-grass land reaches Blue byte 9 accepted and 10 rejected
  MtMoonB2F non-grass land reaches Blue byte 9 accepted and 10 rejected
  current source delta terrain rejects blocked and water replacements and stale plans
  stale plan rejects roster slot HP table terrain and RNG changes with no additional rolls
  specimen constructor and exhausted continuation failures commit no actual rules or world draws
  actual Explore suppresses without iris or specimen, accepted gate enters original iris
  actual Explore source door preempts field gate without consuming any rules draw
  Synchronize literal 49/50 gates retain the ordinary nature draw
  Cute Charm literal 66/67 gates include failure-only fallback draw
  Stale lead nature sex HP and roster changes reject before any extra draw
  field-travel: Surf enters water, lands, and respects source pair barriers
  field-travel: expired Surf takes input before held traversal
  source ghosts: identification, fear, uncapturable Marowak and confirmed completion
  source Snorlax: genuine capture, victory, escape, defeat, capacity and cancellation
The expired-Surf case includes both boarding and ordinary Surf held-input paths.

SafariServicesContracts.run in Source/dev/safariServicesContracts.lua remains
unregistered by exact B's dev_imports.lua. Root's existing private owner batch
(run_midgame_b_owner_native_11.py in environment evidence) calls it directly.
Retain all three cases: admission/steps/Continue/exit, separate ball/command
supply, Warden HM04 handoff. No registration is added by this packet. Native
helpers must report actual session_id, mode and simulator, as in existing runs.
Existing public-plan cases cover retained API behavior; the two actual Explore
cases exercise this candidate's applied scratch hook. No new scratch-specific
contract was added, and host checks do not establish these native outcomes.

Remaining gate
Root alone must run existing native safety cases and the exact 16 MiB safety
route, then matched hardware with unchanged recorder/production policy.
Supplied current matched baseline: production profile 8bb9284b, cave p95
103.24 ms, worst door 3.022 s, Save 1.616 s, Continue 3.367 s; canonical record
is docs/validation/midgame-b-production-profile-hardware-20261101.json on main.
It is not an older diagnostic-Save or 101.85 ms comparison. No candidate gain
is measured. One review only after at least 10 percent measured phase gain
(cave p95 <=92.916 ms for that matched baseline), per root's current gate.
No runtime, Simulator, AX, GUI, USB/device access, runtime locks, push,
delegation or other checkout edits occurred. This is unaccepted preparation.
