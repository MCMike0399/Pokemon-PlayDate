# Earned midgame real-input candidates

Based on exact root `7351c00` (merged before implementation). These scripts start
from accepted `chain/5.4/<starter>` slots through the real title CONTINUE menu.
They never run New Game, fixtures, state setters, free rewards/money or XP grind.
Only Charmander has optional content; Bulbasaur/Squirtle are critical-path runs.

First packet: `east-<starter>.json` continues the Flash-aide save, reuses the
existing Diglett's Cave waypoint script, crosses the north/south Underground Path,
heals, teaches Flash through the real HM Bag flow, cuts Cerulean's source tree,
travels Route9/10, uses actual Flash in dark Rock Tunnel, traverses the four
explicit source ladders and saves in Lavender. Charmander also talks to the
Cubone-house girl. Every case requires a real second-process Continue and complete
canonical codec equality. This is a partial route packet, not 5.5 completion.

Root applies the small returned patch once:

```sh
git apply --check tools/harness/scenarios/midgame/root-registration.patch
git apply tools/harness/scenarios/midgame/root-registration.patch
```

It adds dispatch/restart names, validates accepted Vermilion ancestry before the
existing exact-slot hash import, extends the existing canonical payload checker
for codec4, and adds two read-only observations (`midgame-owners`, `midgame-state`).
It changes no gameplay, main, dev imports or ledger. The observations return
actual registered events/trainers/shops, HM compatibility and field state. They
never advance gameplay, create receipts or capture traversal. Save/Continue
payloads still come only from the existing real boundary observer.

No dev projection or new generator is needed: navigation reads the one active
shared manifest/cache and pinned package definitions from the compiled source.
No new planner features, diagnostics framework, tests or SDK contracts are added.
Generic route failures remain failures. Difficult cave geometry uses explicit
source warp IDs and the existing fixed Diglett waypoints. No missing service
falls back to a fabricated successful outcome.

Root alone executes, after the game owners are integrated:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python tools/harness/suite.py \
  --only midgame--east-charmander,midgame--east-bulbasaur,midgame--east-squirtle \
  --continue-on-failure --output "$POKEMON_ENV/evidence/m55-east-input-UNIQUE"
```

Keep `--continue-on-failure`: a failed starter must not prevent the other two
from running. The runner imports the exact accepted slots into private Data;
existing stopped-process archives retain all resulting earned saves. It does
not publish partial Lavender progress into `chain/5.5` or touch accepted 5.4
slots. Root publishes accepted chain/5.5 saves only at its milestone gate.

The field worker must finish ordinary Cut coverage for the newly active route
maps and actual darkness/Flash integration before this packet can succeed.
The driver raises a concrete error when an earned compatible HM user, field
menu action, service registration or source collision route is unavailable.
Wild encounters are fled using the existing real battle controls; no preparation
fights are permitted. Required trainer battles use the shared observed-move and
confirmed-reward driver. Centers/shops are the recovery policy.

Preparation: 20 existing journey-path/dialog/restart/suite-discovery checks passed.
All three scenario identities/bounds and accepted 5.4 ancestor metadata passed
host checks. SDK3.1.2 compilation passed, including the returned read-only Lua
observation patch in a private staged tree. No Simulator executed and no native
journey result is claimed. Evidence: environment
`evidence/m55-journey-east-compile-01/`. The registration patch is unapplied.
