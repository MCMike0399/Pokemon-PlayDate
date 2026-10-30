# Safari runtime for checkpoint 5.5b

This packet completes the runtime on top of preparation `41311a2`. It prepares
checkpoint 5.5b only. Main acceptance, three earned saves and Simulator execution
belong to root; checkpoint 5.5a is accepted first. There is no new Celadon,
bicycle/fishing, checkpoint 5.5c or later content in this packet.

## Capture and battle

The user explicitly selected this hybrid: Blue supplies Safari commands,
resources, bait/rock catch-byte changes and escape checks; Gen V supplies capture
math and the Safari Ball multiplier, 1.5. Capture.safariParameters and
Capture.safariAttempt validate an explicit 0–255 byte and use the existing
Q12/HP/status/critical/shake calculation. Zero catch bytes fail normally without
division by zero. Ordinary Capture.parameters/attempt still reject Safari Ball
and unknown context fields; their calculations and RNG cadence are unchanged.
No Safari Ball enters the bag or substitutes an ordinary item transaction.

SafariBattleState is a separate overlay with BALL, BAIT, ROCK and RUN. It shows
the actual original enemy front art and reuses source capture animation assets.
The animation hook adds the explicit Safari Ball identifier to the source low
throw path. It does not change existing ball art or behavior. Bait/rock have a
bounded visual throw and source eating/anger/flee results. No move menu, attack,
party switch, ordinary bag, money payout, combat XP or Pickup battle is created.
Caught specimens use the session's existing party/storage/dex recruitment owner.

Turn preparation samples detached RNG once and returns a defensive presentation
preview. The capture animation is constructed BEFORE the session commits balls,
RNG and any recruitment. Cancel/stale/storage/art failures publish no turn.
The root turn session method is already installed on current main;
it receives prevalidated values through the opaque turn request. A last-ball
catch recruits before the exit check. Run and flee retain unused Safari Balls.
The overlay resets an iris transition to exploration and clears the already
consumed step flag, so returning cannot re-run the same encounter.

## Source passage and rollback

SafariPassage is a transient transaction over existing WorldDeltas, Zone,
WorldView, NPCManager and Player owners, not a second map or movement owner.
SafariPassageState drives actual Player cells through an opaque script intent.
The returned Player hook retains ordinary terrain/NPC collision and never grants
Tutorial Escort's overlap permission. Player still supplies the eight native
interpolation updates. No duration estimate spends a Safari step.

Admission starts at aligned source (4,2) in the gate, walks up twice, uses the
immutable Center warp 2, then walks up once to source (15,24). The raw 502 budget
therefore publishes as 499 after those three actual source cells. The fee,
Safari tuple/flags, final location, field mode, world and actors publish together
only after target construction and all three cells succeed. Before publication,
the old view/player/actors/camera are retained for rollback. A cancelled or
rejected install restores the origin and leaves resources and RNG unchanged.

Confirmed early exit walks down three actual cells and clears admission at the
settled endpoint. NO uses the original gate's matching return warp and retains
the resource tuple. Expired steps or balls announce game over, stage gate warp 3,
walk down three cells and clear the game at source (3,3). No fee is refunded and
no nearby free tile substitutes for the immutable arrival. Exit cells do not
spend Safari budget after the source leave operation clears its active state.
The scene ignores ordinary input during forced movement, like the source script;
unexpected controller exit invokes rollback. A replaced session is never
replaced with the old session merely to cancel a stale passage.

## Exact root integration order (current main 2dd9f3cc)

1. Integrate the map worker's B package through the existing content loader.
   Its manifests/caches/events remain map-worker owned. Safari reward descriptors
   must exist before `MidgameServices.install()`; that installer asserts this.
2. Keep accepted `SessionCodec.VERSION == 4` and its exact Safari v1 tuple
   `{version, active, steps, balls, ending}`, coins, FieldTravel and all A fields.
   Keep legacy migration unchanged. Main already has `safariData`, `commitSafari`
   and `commitSafariBattle`; do not apply the old preparation `root-api.patch`.
   Append only `root-session-method.lua` inside GameSession, where `state`,
   `copy`, `flags`, `world`, `location` and `fieldData` are private locals.
   No new durable field or migration is needed.
3. Apply `root-owner-hooks.patch` against current main. It contains only Player's
   opaque Safari script intent, CaptureAnimation's Safari Ball enum, and
   Overworld's settled-step, return, unpaid-door and encounter hooks. WorldView's
   `exchangePrepared` already exists; do not apply an older view patch.
4. Follow `root-hooks.lua`: import the domain/runtime files, install services
   after the B reward package, register the gate hook once and register the two
   overlays. Replace the one `event` registration with `MidgameServicesState`;
   it extends the accepted NPCTradeState/Daycare/Vermilion executor chain and
   delegates non-Safari programs. Preserve inherited
   `serviceChoice(options, callback)`; Safari/Warden use `midgameYesNo(callback)`.
5. Expose `SafariRuntime.observe(game)` as the Safari member of the existing
   `midgame-state` read-only projection. The driver worker owns that wiring and
   the real-input journey; see `driver-observations.md` in the follow-up packet.

Root must run the same three `safari-services` cases after integration and the
real earned-save driver. Do not replay A or treat host geometry/compile as
Safari runtime acceptance. Keep unrelated field controllers outside this patch.

## Original packet verification (historical e526eff3)

SDK 3.1.2 compilation passed with the unapplied session/owner/import hooks staged
privately. Twenty-eight scoped host checks passed, including capture source/art
mutations and existing source policy/placement inputs. Final evidence is reported
with the commit. No Simulator, push or delegation was used.

The same three Safari behavior cases remain; none was added for a fixture,
driver or helper. The admission case now also uses actual Player cells, staged
views, cancelled installation and forced return. The command case now uses the
explicit Gen V Safari parameters instead of a missing-policy fallback. Warden
remains its existing source handoff case. These contracts compile but are not
executed by this worker. Root still must run them and the earned-save journey;
compilation is not a claim of native behavior, image acceptance or checkpoint
acceptance. Shared fixture expectations remain root-owned.

## Current port verification (2026-10-29)

First useful port: `821bd4e0` on current main `2dd9f3cc`. Follow-up adds detached
turn, step and committed passage observations with assertions inside the same
three behavior cases. Exact driver fields and real input are in
[driver-observations.md](driver-observations.md).

All 33 scoped host checks pass: `test_safari_service_sources`, `test_capture_art`,
`test_capture_generator`, `test_source_actor_placement_inputs`, `test_source_events`.
SDK 3.1.2 compilation passes for both the unchanged production entry point and a
private Source copy with the returned session/Player/animation/Overworld hooks,
imports, overlay registrations and existing Safari contracts compiled together.
The owner patch apply-checks current main. Map activation is deliberately not
staged; installation/run still depends on the map worker/root package.

Evidence and the exact private compile recipe are outside Git at
`~/Developer/Pokemon-PlayDate-env/evidence/safari-runtime-55b-port-20261029-01/`.
`compile.json`, `sdk-compile.log`, `host-tests.log` and
`production-stage/build.json` record those checks. The private staging recipe
never launches Simulator. No behavior case was executed, no native/device/USB
was used, and no protected owner, ledger, accepted evidence, map/cache or art
file was edited. No push or delegation occurred. Root owns the remaining SDK
execution and earned-save acceptance after integration.
