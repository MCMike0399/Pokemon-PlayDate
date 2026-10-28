Milestone 5.4 real-input journey preparation
==========================================

Branch: wip/vermilion-journey. Original packet: efb0753. Follow-up merged exact
root eda74a916a3a00897cd301e5fbcdfcf9d133a836 first, as 4d2a689. Root already
applied the original registration/observations and composed Day Care, schema 3,
the one event inheritance chain, field/scene transactions and learning release.
No Simulator/runtime, push or delegation was used in either worker packet.
These are executable candidates, not accepted journeys.

Owned files are the Vermilion driver, its generator/projection, this directory,
and focused host tests. Shared drivers, run.py/suite.py, production owners/main,
active manifest/cache, ledger and baselines were not edited by this follow-up.

Root integration
----------------

The old root-registration.patch and root-observations.patch remain historical;
DO NOT replay them on eda74a9. Three NEW patches are unapplied and target that
exact checkpoint:

    git apply tools/harness/scenarios/vermilion/root-collection-options.patch
    git apply tools/harness/scenarios/vermilion/root-collection-observations.patch
    git apply tools/harness/scenarios/vermilion/root-aide-capacity-fixture.patch

The options patch adds the new bounded keys to process validation only for
Vermilion names. Earlier journeys keep their existing accepted options/bounds.
The observations patch adds detached Party/Storage/owned records, actual Zone
encounter-eligible cells for the optional cave fallback, and an explicit aide
fixture recruitment receipt. It performs no setters, traversal capture or RNG
sampling. Full SessionCodec payloads remain exclusive to actual Save/Continue.

The fixture patch adds exactly two supplementary capacity setups: hm05 at
Route2Gate and itemfinder at Route11Gate2F. It preconstructs/checks fixed real
species before reset, then calls GameSession:recruit for distinct specimens.
Party fills to six, then recruitment goes to the selected PC box. The 30-species
setup fills box 1 and selects box 2 through Storage's existing owner. No direct
dex writes, generic owner setter, fabricated capture or imported save is added.
Both fixtures retain the actual full bag and use the real gift controller,
actual toss, reward retry, and repeat-interaction checks. Missing fixture support
or mismatched actual specimens/receipts fails; it never becomes a pass.

Regenerate projections AFTER root composition and map activation:

    source ~/Developer/Pokemon-PlayDate-env/env.sh
    python tools/generate_cerulean_journey.py
    python tools/generate_vermilion_journey.py
    python tools/generate_vermilion_journey.py --check
    python -m unittest tools.tests.test_vermilion_journey tools.tests.test_vermilion_acquisition -v

Root still owns activation of the 65-map manifest/cache after ship b2a497b is
composed. Current active manifest has 30 maps, so dependency preflight rejects
this build before input. The projection pins actual wiring, codec, recruitment,
PC/capture/encounter owners, machine compatibility, wild tables, shop stock and
prices, Day Care, gifts, scenes and the 35 prepared map files. A declaration is
not a runtime registration claim. Any changed staged owner bytes fail closed.

Natural continuation and acquisition
------------------------------------

restart-{bulbasaur,charmander,squirtle}.json runs the entire existing Cerulean
New Game path in the SAME process, preserving its real intro/Brock/fossil/Misty/
Bridge/Bill/Ticket choices, training, PP, items, rules RNG and source trainer
receipts. No arbitrary 5.3 save import exists. Root chooses the final runtime
start. The new acquisition code starts only after that unchanged path and the
actual robbed-house Rocket battle.

Collection uses the pinned English Blue slots and production Bag ball commands:

1. Route24: secure Bellsprout FIRST, before filling the party. Actual MachineData
   permits Bellsprout to learn Cut and excludes Rattata. Then collect missing
   Caterpie, Metapod and Pidgey. Wild Metapod is caught directly; the plan does
   not require evolution grinding, Abra, Pikachu or Clefairy.
2. Keep the actual starter, Rattata and Bellsprout in the six-member party. The
   existing Day Care service deposits an eligible nonstarter without an HM
   (normally Rattata), earns real completed-step XP, and verifies paid withdrawal
   against its actual quote and held specimen. Nothing is seeded or teleported.
3. Routes5/6 and Underground traversal remain physical. Collect common Meowth
   on Route6. With a full party, a successful capture must append its specimen to
   the actual selected PC box and commit the new unique owned-species flag.
4. Vermilion/Fan Club/Old Rod and every Anne cabin component, kitchen/deck/bow,
   positional rival, Captain HM01, actual Teaching and party field-menu Cut,
   departure, Surge cans/battle/TM24 retain their existing real-input path.
5. AFTER Surge and BEFORE the Diglett/HM05 aide leg, collect missing common
   Sandshrew/Spearow/Drowzee on Route11 until actual owned count is ten. The
   earlier starter+evolution+Rattata plus four Route24 species and Meowth gives
   eight; two Route11 catches suffice. Even without starter evolution, all
   three Route11 catches suffice. No species count is inferred from this math:
   the driver's only completion oracle is actual canonical ownership and capture
   commit receipts. A real Diglett capture is the optional fallback if still short.
6. Continue through Diglett's Cave and Route2 HM05 aide, Route11, actual Save,
   process exit and actual Continue. Compare the full immutable canonical payload,
   including fieldWorld and daycare. Root separately inspects native screens.

Collection throws ordinary purchased Poke Balls at the actual live target from
its existing HP; it does not risk an artificial weakening attack or edit HP.
Non-target encounters use normal attacking decisions, real PP, learning and
outcomes. No critical/RNG/capture result is predicted. Every throw consumes one
actual ball. Caught=true alone cannot pass: the driver verifies the exact party
or selected-box recruitment destination, preserved unrelated boxes, appended
species, and exactly one new owned-species flag. Failed throws cannot recruit.
It does not inherit Brock's reserve-only party+1 assertion for these captures.

Supply and safety policy
------------------------

The actual Cerulean/Vermilion Mart stock prices Poke Balls at 200. Aim for 20 in
stock and retain enough for the per-encounter budget before walking in grass.
Purchases require current money, preserve a 600 reserve, and are capped. If the
stock goal is unaffordable and the actual Bridge Nugget remains, use SELL in the
real shop to sell ONE at its pinned 5000 price, verify the exact transaction,
then buy balls. It is a player sale, not a reward/money fixture. Never sell an HM,
quest item or protected specimen. Actual Centers provide free HP/status/PP
restoration; healing and shopping travel remain physical and count toward the
collection step/action budgets. Real blackout recovery retains existing checks.

Default finite 5.4-only budgets (explicit in the three starter scenarios):
- 30000 additional semantic actions for the whole continuation, after the prior
  max_actions budget. New Game -> Bill keeps the original bound unchanged.
- 12000 ordinary collection navigation/connection steps and 180 wild battles
  total. The phase check stops further grass segments after 60 wild battles.
- 80 total balls thrown, at most 80 purchased, at most 12 throws per encounter.
- 20-ball stocking goal and a 600 cash reserve.
- Each phase also checks 3000 ordinary navigation steps at settled segment
  boundaries. Healing/shopping segments can cross a phase target; global step,
  battle, ball and action limits still fail closed. Interior edge-door presses
  retain the inherited transition and action bounds.

Config keys are bounded and reject booleans/out-of-range values. Optional Route11
phase exhaustion can fall through to the actual Diglett fallback; exhaustion of
a global budget, required target, funds, party slot or box capacity fails closed.
Finite natural rolls cannot guarantee a particular run succeeds. No fixture or
outcome repair replaces a failure. Extra incidental XP does not certify pacing.

Explicit remaining cave dependency
---------------------------------

Current prepared DiglettsCave has a pinned wild table but NO cache tiles marked
as grass. Current Zone:encounterPolicyAt requires that flag, so it exposes no
eligible floor cells. The driver asks the actual Zone policy for the fallback's
eligible cells; it does not invent grass or mutate production terrain. If root
later supplies proper cave encounter eligibility, a detached host planning view
uses those actual cells. Until then a needed Diglett fallback fails explicitly.
The main Route24/6/11 common-species plan has real grass lanes and enough species
without relying on that optional fallback. All of this remains unrun natively.

Other supplements
-----------------

hm01/tm24/voucher/rod-full-retry retain their explicit setup, full bag, actual
scene/battle reward, toss and retry. TM24 requires an actual Surge win and badge.
blackout uses a level-1 supplementary specimen, actual Center checkpoint and
Route6 trainer loss, retaining real half-money and HP/PP/checkpoint checks.
field-cut-reload uses an explicit compatible specimen/HM/badge fixture but actual
Teaching and field menu Cut, actual Center round trip/tree restoration, another
Cut, actual Save, new process and Continue. None of these is natural credit.

Checks and reproducibility
--------------------------

102 host tests passed, zero skips, including the existing Cerulean/Day Care/
learning and Vermilion source checks. New boundaries include real Bag selection traces, full-party selected-box
commits, missing owned flags, wrong box/index, duplicate/failed capture rejection,
Bellsprout priority, finite budgets, actual prices, source-pin drift, real prepared
grass lanes, honest cave eligibility, fixture classification, exact recruited
10/30-species owners, immutable receipts, and all new patches applying to eda74a9.
They do not execute Lua, predict RNG or emulate game outcomes.

Compile the proposed overlays with actual SDK 3.1.2, without runtime:

    python tools/harness/scenarios/vermilion/compile_capacity_overlay.py --output "$HOME/Developer/Pokemon-PlayDate-env/evidence/vermilion-capacity-compile-UNIQUE"

Executed compile evidence:
~/Developer/Pokemon-PlayDate-env/evidence/vermilion-acquisition-20261026/compile-02/candidate/build.json
The metadata says runtime_executed=false and active_maps=30. This proves syntax/
compilation only, not recruitment behavior or journey acceptance. Host log:
~/Developer/Pokemon-PlayDate-env/evidence/vermilion-acquisition-20261026/host-tests.txt

Root-only eventual invocation (NOT executed by this worker):

    python tools/harness/run.py --scenario tools/harness/scenarios/vermilion/restart-squirtle.json --output "$HOME/Developer/Pokemon-PlayDate-env/evidence/vermilion-root-squirtle-UNIQUE"

Repeat for the other starters/supplements under the single runtime owner after
composition, activation, projection regeneration and frozen-build checks.
