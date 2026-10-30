# Early title startup candidate

Base: synchronized 108-map commit `1318bf28`. Branch: `wip/early-title-startup`.
Only main.lua, bootstrap.lua and titleState.lua change in production.

The existing artwork appears after sprites, authored maps and the real
GameContext are ready. The registered title draws during cooperative content
installation, state/provider construction, full save inspection and saved-map
preparation. Input stays gated until preparation finishes; an early A is not
queued. There is one root machine/input owner and no alternate game runtime.
Title refreshes and confirmations reject callbacks from older title generations.

`title.visible` is emitted after the first artwork presentation yield.
`title.prepare.end` means the menu and saved-map preparation finished;
`initialize.ready` still means complete startup. `title.start.end` now precedes
inspection: tooling must not treat it as a usable Continue menu. Build identity,
trace schema, memory guards, safe collection and error-screen ownership remain.
Imports retain their exact original order at PDZ load time.

Apply `prepared-save.patch` separately to enable save reuse. It adds explicit
GameSaves title preparation/consumption hooks; inspect and public continueGame
keep their full disk-load behavior. Preparation uses the original store load,
full SessionCodec decode/owner constructors and FieldWorld preparation. Continue
then uses the checked inactive candidate and original payload, retaining all
installSession encode/target validation, rollback and observer behavior.
Recovery, confirmed New Game, publication and title exit invalidate preparation;
consumption is once only and checks owner identities and generation after yields.
With the patch, load/decode/field trace spans move to `title.save.*`; pressing A
records `Continue.prepared` before the unchanged installation spans.

Without the patch, the candidate remains functional but Continue still repeats
its disk load/decode. It only benefits from the map warmed during inspection.
The map warmup uses provider:keyForID/ensure in the existing bounded cache.
It installs no saved deltas, player, actors, RNG or WorldView. The provider worker
can replace that small block with its opaque preparation hook; the active session
must remain untouched until installSession. Content workers should retain the
installContent call boundary; runtime content registration now follows context
construction, while every import remains at load time.

Host validation: 54 existing protocol checks pass. Production compilation passes
with and without the unapplied save hook. The production-build suite passes
4/5 checks; its existing dev inventory assertion at line 81 excludes
`dev/sessionFixture` from actual modules but still expects it in the pinned
baseline. This same test source is present at the base; it was left untouched.
Original ordered production imports also compare equal to the base and fixture.
No tests, Simulator contracts, loader APIs or content/provider files were changed.

No Simulator, hardware, USB, push or delegation occurred. No speed or heap gain
is claimed. Root must qualify both the candidate and any applied hook, including
retained decoded-owner/payload heap at title, recovery/New Game paths, visible
artwork time, A-to-walking and app-start-to-walking. Current warmup does not hide
WorldView construction or installSession validation. Measure hardware first and
review only a phase improvement of at least 10%.
