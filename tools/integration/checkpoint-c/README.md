# Actor-validation correction — 2026-11-05

The reviewed Macintosh actor migration had three defects: hidden saved records
skipped structural/value validation, the session retention boundary could
accept arbitrary actor deletion, and the diagnostic could report unequal actor
payloads as equal. All three are corrected on the isolated C branch:

- every known saved actor is structurally and intrinsically validated before a
  bounded visibility migration may drop it;
- only a removal independently proven hidden by a fresh source descriptor and
  flags survives the session boundary; survivors must be value-identical;
- literal equality (`roundtrip_equal`) is separate from the proven migration
  (`migrated_equal`/`migration`), and raw selected-slot payload/sequence stay
  distinct from the canonical state.

The new native cases cover malformed hidden records, duplicate/unknown IDs,
custom-validator deletion/addition/mutation, wrong counts, stale flags,
survivor changes and the exact migration receipt. The elevator test now covers
all eleven floors, both cabin exits, persisted-map projection and unknown-floor
rollback. Fresh actual SDK 3.1.2 export refreshed both dependency pin maps (only
`domain/gameSession.lua` changed), production compiles, and native
`contracts saffron-guards` passes 110/110. The full host suite has 0 new failures
versus unmodified `03c1bae4`; the two stale development projections were
regenerated.

The bounded probes show Continue near 318 MiB and Silph 1F entry near 547 MiB,
not the earlier ~900 MB boot figure. Two genuine cabin pilots still trip the
unchanged 1 GiB host ceiling during repeated route requests/Saves; Lua heap stays
near 8 MiB while native `Malloc Small` grows. A trusted-boundary observation
change (do not repeat SaveStore's already-completed deep validation) reduced the
measured Saffron-walk peak from 701 to 611 MiB (12.8%) with the owner deep path
unchanged. The harness still takes the deep Save path because `SaveBuildPolicy`
disables owner exports whenever `HarnessBuild` exists; changing that or the
guard needs an explicit user decision. No more pilot retries were made.

Exact evidence and failures:
[actor-validation-correction-20261105.json](actor-validation-correction-20261105.json).
C remains unaccepted: earned completion, restarts, visuals, hardware, memory and
latency gates are open.

# Macintosh takeover — Saffron Silph guard fix, 2026-11-04

The ordinary C driver had bounced Saffron `(0,23)` ↔ Route7 until the existing
64-Clear cap. The cause was a source bug, not a planner bug: `SilphStory`
applied only `EVENT_BEAT_SILPH_CO_GIOVANNI` to Saffron objects 14/15, so the
Rocket at `(18,22)` kept the Silph warp at `(18,21)` blocked even after Mr. Fuji
was rescued.

The generator now also reads the pinned `scripts/PokemonTower7F.asm` rescue
pair (`HideObject TOGGLE_SAFFRON_CITY_E`, `ShowObject TOGGLE_SAFFRON_CITY_F`)
and emits `scenes.fuji_rescue`. Object identity still comes from the pinned
`toggleable_objects` order, and both ids must also appear in the later Silph
completion hide list. Runtime conditions are now exactly:

- object 14: `not SilphCleared and not FujiRescued`
- object 15: `not SilphCleared and FujiRescued`

Coordinates, art, collision, raw maps, warp geometry, existing flags, the
custom resolver, the deep fallback and old actor saves are unchanged.

Evidence: one actual SDK 3.1.2 thin export refreshed the two region dependency
pins (parsed transform values are identical to the prior pins; only Lua JSON
key order differs), the qualified production compile passes, and the bounded
native `contracts saffron-guards` witness passes 104/104 for all four flag
combinations. The full native contract aggregate and multi-zone suites cannot
publish inside the pinned 16 MiB pool on a 171-map candidate; those failures
are retained, not relabelled. Host suite: 0 new failures versus unmodified
`1464d1a2`, with the same 34 pre-existing C failures.

## Host runtime gate on the current Simulator (2026-11-04)

The corrected pilot now walks through the Silph door, enters the building,
rides the elevator and writes genuine transit Saves (8 in one run, including
inside the cabin). Long journeys currently stop at the existing 1 GiB owned
Simulator ceiling: the Simulator allocates roughly 900 MB of small malloc
blocks during harness boot on both Macintosh and DiveMac (vmmap MALLOC_SMALL
~852 MB virtual, ~15 MB resident, ~812 MB swapped).

The unmodified 1464d1a2 worktree shows the same curve with the same guards, so
this is a host/SDK runtime gate, not a regression from the Saffron fixes. No
guard, pool or policy value was changed, and both Simulator inis keep
`MallocPoolSize=16645684`. The planner also projects the Silph cabin exits to
the persisted floor (commit 873c73cf) so a resume inside the cabin can leave.

## Older actor saves across the corrected visibility rule

A frozen candidate slot can contain a known source actor that the corrected
rule now hides (record16's `adventures.b` keeps object 14). Strict decode
rejected it and Continue fell back to the older published slot.

`WorldMotionData.normalize` now drops a KNOWN saved actor whose source spec is
hidden, updates `count`, and returns the dropped ids. Unknown ids, duplicates,
out-of-shape entries, added actors and missing still-visible actors keep their
strict validation. `GameSession._validateActors` permits only the actor
list/count to differ, and the dev boundary observation accepts exactly that
canonicalization and reports it, so an accepted checkpoint stays comparable.

The resumed pilot records `startup_actor_visibility_migration` with the exact
dropped id and the hidden actor never spawns.

## Silph elevator confirm

`SilphStoryController` created two `EventState:guard` callbacks in one
`menu:show` call. The second guard advanced the serial, so the confirm guard
was stale on creation and A silently did nothing. One guarded callback now owns
confirm and cancel, as the reviewed Hideout elevator does, with a native
regression case.

[Receipt](saffron-fuji-guard-visibility-20261104.json). C remains unaccepted:
the short Squirtle record16 pilot, three-starter earned journeys,
Save-Continue, visuals, hardware and every latency gate are still open.

# Root C candidate wiring and qualification — 2026-11-02 (superseded above)

This current section supersedes the historical unapplied-hook claims below.
Root synchronized main through afededc8, applied the combined activation hooks
as409da7e7, selected generic source-warp packet2f5e6469 as a standalone commit,
and expanded its one inline conditional for readability as5d77ebd4. The retired
map-specific geometry patch was deleted; do not apply old alternatives again.
The isolated branch now wires171 maps; main still has149 accepted maps. Nothing
is pushed, and no C campaign, native-map or hardware acceptance is claimed.

Actual SDK3.1.2 deep installers produced all four export files in the thin probe
`checkpoint-c-sdk-exports-thin-20261102-03`, under the16MiB pool and31/30GiB,
1GiB host guards. Sampled host peak203572256 bytes. Kanto and prior East/South
values match; Saffron contributes30 transformed events/45 trainers. Previous
producer/export bytes remain archived. The qualified171-map production build
compiles. The full-harness attempt that hit1GiB remains failed; no continuation.
[Exact receipt and limits](root-wiring-qualification-20261102.json).

Next Root: execute the extended native inert-floor/elevator case and actual
C access/rewards/Save-Continue checks, then three earned journeys and hardware.
Atlas enablement runs as a separate measured candidate; C acceptance still needs
all latency, memory, visual and native gates. B's listed heavy-map memory margin
is met per reviewer steer7; no additional B memory block remains. Main policy
is reserve30/admission31GiB, all other guards unchanged.

## Historical preparation below

# Current source warp host preparation — 2026-11-02

See [source-warp-host.md](source-warp-host.md) for the current implementation,
checks, preservation boundary and minimal Root integration. The generic shared
warp preparation is implemented; the old map-specific geometry patch is retired.
Only activation/Copycat hooks remain unapplied. C is inactive and unaccepted.

Everything below is historical composition evidence. Its statements about an
unapplied geometry patch and pending host binding preparation are superseded.

---

# Checkpoint C current-main host composition — 2026-11-02

Current merge: `a62974fa84cf48a97bcd83ceb4910aae0633196e`, parents exact original
C preparation `69658243ca052b100f3d1d6ecbe4efd90d464884` and exact current main
`24ea539cd68142af6b50ca57841cdb8ae350f519`. Original preparation is preserved at
`prep/checkpoint-c-before-main-24ea539c-69658243`. This is a normal merge with
no conflicts; no old divergent/synchronization history was added.

**Main remains149; isolated171 remains inactive and unaccepted.** Root activation
and geometry hooks remain UNAPPLIED. No SDK/build/compile, Simulator, device,
USB, GUI, runtime locks, full suite, storage work, push or delegation occurred.

## Current preservation and host result

All75 files changed by current main since the original accepted base are exactly
current-main bytes. There are zero unrelated main deletions or differing main
updates. This includes reviewed terrain queries `9ba63d68`, actual SourceMaps
qualification and provenance, adopted Substitute `056fe922` / epoch19, inverse
policies, migrations, source doll assets, native299/motion/protocol proof files,
coverage, progress and operator tools. `Source/main.lua` and all existing shared
runtime owners are exactly current main. No qualification pin/export was invented
or widened. Current main wins unrelated documentation, proofs and tools.

The original149 map entries/decoded records/grids/cell payloads/content digests
and all22 prepared C maps, Copycat and selected Silph geometry survive. The same
existing preservation audit now uses exact current main as its comparison base.
The original Route16 compact barrier exception and two callback-only atlas cells
remain exactly as documented in the historical composition below.

Focused host checks: **54+7 pass**, no skips. Existing map/cell cache, content
cache, Silph and Copycat generator checks all pass. No native/build result follows.
The one existing C preflight runs against immutable Source commit `a62974fa...`:
**239 checks / four conditions**, expected exit1. All three actual B ancestry
boundaries now pass, including restored B11 at its original path. Six canonical
B slot hashes, historical A chain-manifest authority and original producer
Source remain unchanged; no slots/provenance were rewritten.

Current evidence is outside Git:
`/Users/burbujamc/Developer/Pokemon-PlayDate-env/evidence/checkpoint-c-current-main-host-20261102-01/`:
`preflight.json`, `preservation.json`, `main-preservation.json`, `focused.log`.
The earlier Root report remains historical and unchanged:
`/Users/burbujamc/Developer/Pokemon-PlayDate-env/evidence/checkpoint-c-ancestry-restored-preflight-20261102-01.json`.

## Current unapplied hooks and remaining gates

Hooks were regenerated against current Source without applying them. Both
`activation-root-hooks.patch` + `geometry-root-hooks.patch`, and the separate
C-only `root-hooks.patch` + Copycat `../copycat/root-hooks.patch`, compose in
disposable file copies. Do not apply both alternatives. The existing optional
Copycat SDK registration patch also apply-checks against current harness imports.
No new journey SDK contracts/framework were added.

The exact four remaining host conditions are:

1. President access requires the unapplied source-qualified inert-floor binding.
2. Silph floor3 elevator arrival requires the existing live scripted binding.
3. Silph floor5 elevator arrival requires the same owner before map construction.
4. C declaration qualification: current transform dependency pins reject the
   C171 manifest. Root needs a real C/Saffron SDK export and qualification through
   the existing pipeline; none was fabricated or relabelled here.

Root still refreshes private171-map journey/source extension projections and
owns current native actor/door/pad/elevator/reward/Copycat/Fly/Save-Continue,
current exposed rules, visuals and hardware qualification. Root owns the physical
heavy-map memory table. Reserve30GiB/admission31GiB and16MiB pool/1GiB host/6-8-9
Lua policy are preserved unchanged. C activation still waits for working memory
margin; all latency gates remain mandatory for C acceptance.

## Historical first composition below (superseded where noted above)

This records the original pre-merge preparation only. Its epoch18, unadopted
Substitute and unavailable B11 statements describe that earlier boundary;
current main's epoch19/adopted Substitute and restored ancestry take precedence.


This branch starts exactly at accepted-main `7726ea49`. Main stays **149/222**;
this isolated **171-map preparation is inactive and unaccepted**. No push,
Substitute adoption, SDK/build, Simulator, device, USB, GUI, runtime lock,
delegation, storage maintenance or other checkout edit occurred.

## Logical integration order

1. `93b93b284a8f9fb10e62d66b1bc0142379ed5461`: compose C packet
   `e7249cf459a19296e6573040c23c8272a04934ff` using accepted-main generators,
   plus only the owned geometry changes from `1af97719`, `e56ca9ad`, `9b173968`.
   No divergent/synchronization ancestry is merged. Binary cells and content
   use the current shared pipeline. The Silph auxiliary input uses the explicit
   source root, including in the unapplied geometry hook.
2. `8ab9b4fb0eca651c2e70455bc5c108e68687065a`: unchanged Copycat service
   implementation from `8a4a8e4acc17b52f5adcc5ea01a89212dbd99c42`; installation
   remains unapplied.
3. `96f162c872acb5d7677402b3479659454a944370`: compose owned driver work from
   `3006169c` / `a7196459e9c8246ab26bfbda86a921785d72ae57`, fixed geometry routes
   and host preflight from `e71bb2cb2af107a3c1d6a5f0af5ef8068b94b5f1`, and bind
   the C scenarios to actual accepted B authority. Existing test doubles retain
   phase names; shared host inventory recognizes only the exact C manifest.
4. Apply this branch's handoff/hooks commit after those three. All actual Root
   hooks below remain **unapplied**.

Existing owners, schema4, epoch18, Safari correction, Gen V rules, caches and
protected art survive. `Source/main.lua`, shared runtime owners, operator files,
B/A authority documents, chain manifests and all canonical save bytes are exact
accepted-base bytes. Separate Substitute candidate `66ff1861` is unadopted.

## Unapplied Root hooks

`activation-root-hooks.patch` is the combined C + Copycat installation patch.
It adapts imports, guarded service installation and Saffron registration to the
accepted owner pipeline, with `hideout-tower-midgameSaffron-v1` identity. It also
extends the existing declaration allowlist/generator, requiring a **real pinned
SDK Saffron transform export**. It does not invent an export, qualification or
producer epoch. Existing strict dependency pins intentionally reject this C
composition until Root produces and qualifies replacement evidence.

`geometry-root-hooks.patch` contains only the three shared geometry hooks:
source-qualified inert 11F warp classification, binding enumeration without a
live transition, and removal of its exact compact blocked-floor cell. President,
Beauty, the original warp declaration and source topology remain intact. Its
map-specific inert classification still requires Root review/native qualification
through the shared terrain/binding authority; host preparation does not approve it.
The driver-owned door-before-Giovanni / President-route hunk is already composed.

Both patches pass `git apply --check` against this branch. Root may apply the
combined activation patch and geometry patch in either order, then regenerate
the existing map/cell caches. The separate `root-hooks.patch` is C-only;
`../copycat/root-hooks.patch` follows it. Do not apply both the combined and
separate alternatives. The existing Copycat SDK registration patch is optional,
unapplied and unexecuted; no new journey SDK contract/framework was added.

## Preservation and host evidence

Outside Git:
`/Users/burbujamc/Developer/Pokemon-PlayDate-env/evidence/checkpoint-c-host-integration-20261102-01/`.

- `preservation.json`: all 149 previous manifest entries, decoded maps, dimensions,
  source pins, binary cell payloads, runtime projections, stable grids and content
  record digests preserved. Whole-manifest cache header pins change normally.
  Only prior compact geometry change: Route16 blocked cell208 is removed because
  its original warp9 now reaches the installed Fly house. New C maps add their
  source grids; exactly two additional callback-only atlas cells are supplied:
  `pokered:FACILITY:cell:24-25-24-25` and
  `pokered:INTERIOR:cell:5d-5d-5e-5e`. The 22 new decoded maps remain pinned,
  unchanged preparation inputs. All current generated bytes reproduce.
- `preflight.json`: the single requested batch, **239 checks / six blockers or
  owner conditions**, expected exit1. Immutable Source ref is `8ab9b4fb...`;
  current driver/script hashes are recorded independently. Route16's existing
  pinned Cut projection passes conditionally on an actual earned Cut commit.
- Focused checks: **28** Silph/gym/guards/manifest/events; **26** restart/import,
  Save input, generated map and content cache checks; **7** C boundary checks.
  All pass with the existing environment venv, no skips. Copycat source generation
  reproduces exactly. The initial system Python lacked Pillow; the environment
  rerun passed. A test double lost its phase name; corrected and affected26 rerun.
  No full suite, build, runtime, art acceptance or latency measurement is claimed.

The packet `validation.json` and geometry/Copycat handoffs retain their original
historical evidence scopes. They are not fresh compile or runtime evidence here.

## Accepted B boundary and honest remaining gates

C initial saves select `chain/5.5b/<starter>` through
`docs/validation/midgame-b-acceptance-20261102.json`, accepted code
`af9a89380f9730767ff22b3ac5114cf32f216a75`, production Source
`9b086ab51d65b4ad212d8f4486ba01ce8562e563e41ebf3947e2c7dcad058284`.
All six canonical slot hashes are exact. The original B producer Source
`02f483604...` stays historical. The B producer's immutable Git chain manifest
is used to verify its frozen A boundary; today's larger manifest never replaces
that historical hash. No frozen proof field or save is rewritten.

The strict import verifies the authority record, actual producer run/outcome,
confirmed distinct exited processes, equal Save/Continue receipts/codecs, stopped
archives, canonical envelope checksum/latest saved codec, accepted A ancestry
and every partial marker/archive. Squirtle passes completely. Bulbasaur and
Charmander verify their final producer/slots/codecs but remain blocked on missing
historical `m55b-earned-eleventh-resumed-20261030-01/.../partial-save.json`
archives. Nothing is copied into a private Data directory until validation passes.
No restore/storage work or provenance relaxation was attempted.

The six preflight blockers/conditions are: President inert-floor binding; floor3
and floor5 elevator arrivals requiring live scripted bindings before map build;
Bulbasaur and Charmander unavailable partial ancestry; C declaration qualification
(stale `data/sourceMaps.json` transform dependency, and missing real C export).
These are preparation gaps, not permission to fabricate inputs or skip checks.

Root must resolve those, refresh existing private 171-map journey/source-map
extension projections and qualify the same shared shipped-data/cache pipeline.
Then review actual actor, door/pad/elevator, guard, rival/gift/reward, optional
Copycat, Fly/history/PP and real Save/Continue behavior on all three earned B
chains, including current exposed move gaps. Substitute remains separate.

**C activation waits for Root's working memory margin (about 7.5 MiB peak with
existing guards unchanged). C acceptance additionally waits for all latency gates,
root reviews/native journeys/visuals and exact hardware qualification.** No C
activation, acceptance, compile-success claim or full-game completion follows
from this host packet.
