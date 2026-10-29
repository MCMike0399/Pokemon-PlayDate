# Aromatherapy implementation handoff

Branch `implement/aromatherapy-08cb33d1` starts at exact private checkpoint
`08cb33d1e74560ef5010eac57beda285e530a050`. The observed gap is in
`m55a-icebeam-lift-resumed-20261029-01/03-midgame--restart-squirtle/processes/0001/simulator.log`,
line 1731, under the environment evidence directory.

Aromatherapy now uses BattleConditions and Battle's existing session party or
trainer party references. It cures living active and benched members, clears
sleep counters and the existing toxic counter, preserves volatiles and HP, and
commits cures before narration yields. Standalone battles cure only the user.
No party owner or shared move-data mutation was added.

The oracle is Showdown `9b136a8c8cdb860a8ab96fa063f906604e352547`.
Local `preparation/common-abilities-oracle` bytes were checksum-verified against
`early-combat.json` and `contact-abilities-sources.json`: base moves, Gen8 through
Gen5 move overrides, base and Gen8 through Gen5 abilities, conditions and simulator
sources. Gen5's Aromatherapy onHit cures the entire team without returning a
failure when everyone is healthy. Pokemon.cureStatus excludes fainted members.
Gen5 removes Sap Sipper and Soundproof ally-side hooks; neither excludes reserves
from this cure. Base Sap Sipper's direct-hit callback excludes the user itself.
This differs from the current-generation Aromatherapy callback.

Exactly one SDK contract was added to the existing MoveFailureContracts suite:
“Aromatherapy cures the owned living team in Gen V without blocking on Soundproof
or an already healthy party”. It covers both sides, all six major statuses,
real Soundproof users and reserves, healthy-party success, fainted reserves,
sleep and empty-PP gates, unchanged RNG, volatiles, shared move data and withdrawal.

Validation passed: 25 existing move/support/producer host tests, all 54 existing
protocol host tests, generated support metadata consistency, and git diff checks.
Real SDK 3.1.2 compile-only succeeded, including the new contract, at
`~/Developer/Pokemon-PlayDate-env/evidence/aromatherapy-08cb33d1-compile-20261029-01`.
Compiled-source SHA256 is
`26b6beadddfdc49998fddf983985d09071f9fe4caf71eaa02281940efc5f7039`.

No Simulator or device was run, and the SDK contract has not been executed.
Root owns integration and runtime acceptance. Scope is the existing singles
battle model; doubles, Snatch, Substitute and other unsupported producers are
not introduced or certified. Sap Sipper has no reachable Kanto specimen witness
in this contract. Nothing was pushed.

Root integration result: the single new SDK contract passed in the private
candidate and in main, with zero failures. Exact evidence:
`evidence/m55a-aromatherapy-sdk-20261029-01` and
`evidence/m55a-aromatherapy-main-sdk-20261029-01`. Both independent reviews
reported no findings. This closes the scoped move behavior, not campaign or
device acceptance. Main remains at 65 active maps; the 108-map candidate is private.
