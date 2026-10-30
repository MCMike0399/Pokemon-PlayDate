# Earned checkpoint 5.5a journeys

The current set is `restart-charmander.json`, `restart-bulbasaur.json` and
`restart-squirtle.json`, based on exact root
`ec937901610243158107103429cef4085ffacf8e`. Root's passive `midgame-state`
observation must also expose actual `coins` and detached `celadonSlotView`.
No gameplay, Source files, planner features or Simulator contracts are added.

Each starts from the hash-verified accepted `chain/5.4/<starter>` slots, selects
CONTINUE through normal UI, crosses Diglett's Cave and the Underground Path,
uses actual Cut on the Cerulean tree and travels through Rock Tunnel to Lavender.
The existing PC withdrawal searches only earned Pokémon for Flash. If none can
learn it, the fixed ladder route preserves actual tunnel darkness. No helper,
training fight, seeded state, money, item, RNG or reward is manufactured.

The route continues through Route 8 and the west/east Underground Path to
Celadon, defeats Erika for the Rainbow Badge and TM21, then uses the committed
fixed spinner scripts, Lift Key, actual elevator and Giovanni battle to obtain
the Silph Scope. It ends at Celadon Center. No A route visits Tower, Snorlax,
Cycling Road, Fly, Saffron, Fuchsia or Safari. Later prepared methods and fixed
scripts remain dormant; `packet: full` is no longer an accepted configuration.
The old `east-*` cases are Lavender-only partial routes and never export A saves.

Charmander additionally buys all three vending drinks and exchanges them for
the exact source TMs, collects the level 25 Eevee using the fixed Mansion
backstairs, gets the Coin Case and source coin gifts, buys only enough coins for
one one-coin slot spin and Blue's level 6 Abra prize. It observes the real slot
result and wallet change. A losing spin is valid. No random win is required.
Insufficient earned money, full bag/box, absent registration, wrong reward or
unavailable source route fails explicitly. The journey never spends fabricated
coins or interprets an offered reward as a successful acquisition.

Root alone runs the three cases:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python tools/harness/suite.py \
  --only midgame--restart-charmander,midgame--restart-bulbasaur,midgame--restart-squirtle \
  --continue-on-failure --output "$POKEMON_ENV/evidence/m55a-input-UNIQUE"
```

Each final Save uses the real pause/confirmation UI. The existing runner exits
that owned process, archives it, launches a new PID, selects CONTINUE and compares
the complete canonical codec payload. Only successful two-process 5.5a cases
export final bytes to `chain/5.5a/<starter>`. Provenance retains source/build IDs,
slot hashes and the exact starting-save record. Accepted 5.4 files are read only.
Root still owns native execution, screenshot review and main acceptance.

## Resume a verified partial run

Real Saves at Vermilion, Cerulean, the Rock Tunnel Center, Lavender, Celadon,
Erika, the Scope and each optional service group publish `partial-save.json`
inside that process's evidence directory. It contains the actual Save-boundary
codec, completed route steps, both real slot hashes and accepted 5.4 ancestry.
It is a partial observation, never a completed journey receipt.

After the producer has exited and its `runtime-data` archive exists, copy the
matching starter's scenario outside Git and add an `initial_save.resume` field:

```json
"resume": {
  "path": "/absolute/run/processes/0001/partial-save.json",
  "sha256": "SHA256 of those exact marker bytes"
}
```

Keep `milestone: 5.4`, the same starter, packet and content scope. Use the normal
runner with `--scenario /absolute/resume-scenario.json --output /new/run`.
The existing importer verifies the marker hash, confirmed owned process exit,
both archived slot hashes, unchanged accepted ancestor slots and exact ancestry.
It copies only those archived bytes into new private Data. Actual CONTINUE must
then match the marker's entire codec before any travel resumes. Previously
completed route groups are skipped; an unfinished group restarts from its last
actual Save. No failed journey is relabelled successful. A cancelled process
without confirmed exit or changed/incomplete archive cannot resume. No running
save files, accepted slots or game state are edited.

The legacy `root-registration.patch` and `root-followup.patch` are historical
handoffs already installed by root. Do not reapply them to this base. Source-only
preparation and host checks are distinct from native acceptance; this worker
runs SDK compile only and never launches Simulator.

## Host preflight before another set

Run once from this checkout without building or launching a runtime:

```sh
python3 tools/harness/preflight_midgame.py \
  --output "$HOME/Developer/Pokemon-PlayDate-env/evidence/midgame-host-preflight-geometry/report.json"
```

The tool reads immutable current `b676f305` and inactive prepared `0406bf30`
through the existing source model and the current driver's host helpers. It
also reads the original `midgame-host-preflight-baaf6368/report.json` and earned
`m55a-arrival-restart-resumed-20261029-01` evidence. Override their locations with
`--prior-report` and `--earned-evidence`. It does not import a runner or install
anything into the root-owned driver. All outputs stay outside Git.

The original report honestly contains 169 unresolved call sites, 55 gaps and
two unreachable inactive waypoints. The new report retains its exact SHA256,
resolves each of those 57 findings individually, and verifies that its hashed
geometry inputs and driver have not changed. A changed input or unclassified
call fails closed. Main's older host warp projection cannot substitute for the
private branch's Mansion repair, so the relevant helpers load from Git objects.

The completed run has **1,566 checks**. Current 5.5a has **656 conditional/static
passes, 158 explicit inventory exclusions, zero gaps and zero unreachable
routes**. The 169 original calls resolve to **77 conditional geometry sites,
57 UI/future-packet exclusions and 35 inactive 5.5b sites**. Each call retains
its exact line and text, scope, reason and evidence references. `driver_calls`,
`original_report.finding_resolutions` and `remaining_blockers` are the review
indexes. The report verifies all geometry files against the archived earned
builds; it never treats an unrecorded scene as native coverage.

Declared Cut block replacements, the poster opening, B4 guard gate and closed
B1 lift use their pinned source keys in disposable host models. Hideout scene
coordinates are **blocks**, expanded to four cells with `x*2`, `y*2`, and map
padding, matching `RocketHideoutStoryWorld.projectBlock`. Selected B2/B4 lift
exits use the source floor destinations from `resolveDoor`, conditional on
actual earned Lift Key/menu flags. Every fixed spinner step and forced path is
checked. Temporary Cut still requires the real action again on a new visit.

Two old manifest surrogates were wrong: Route9's post-Cut player origin is
adjacent `(4,8)`, not the tree `(5,8)`; Giovanni is at `(25,3)` with a legal
approach `(24,3)`, not the disconnected surrogate `(12,3)`. The historical
corrections remain explicit in the data and report. Interaction approaches,
PC/center/shop access, the inherited Flash/Cut/cave return, tunnel ladder chain,
Mansion chain and current travel targets are checked with declared origins.
Passing terrain remains conditional on actual poses, live NPC occupancy,
earned story actions, UI transactions and the existing driver's runtime checks.

**Exit 1 remains intentional.** Inactive 5.5b retains its original two blocked
walking waypoints and six explicit gaps: Snorlax actor removals on Routes12/16,
the Warden boulder and first push, and the two Bicycle/Cycling Road segments. Surf water movement, Strength pushes, Bicycle admission/motion and
Safari battle/resources are outside the walking model. The 35 inactive call
sites are not promoted to covered geometry or current acceptance. Current
5.5a has no unexplained geometry blocker; root owns the Charmander retry,
performance gate, native execution and acceptance.

[inactive-geometry-correction.patch](inactive-geometry-correction.patch) is a
small **unapplied** correction against `b676f305`; `git apply --check` passed on
that exact private checkout. It changes no current 5.5a behavior:

- Tower6F `(10,17)` is a wall. Walk to `(10,15)`, face DOWN and enter the source
  ghost trigger `(10,16)`.
- Fuchsia `(28,20)` is a pond border, and the pond enclosure is disconnected
  from main-city walking. Enter Good Rod House through city warp8, exit its
  north warp1 from source approach `(2,1)` to city warp9 `(31,24)`, walk to
  `(29,22)`, Surf UP to `(29,21)`, and return DOWN. The portal chain and walking
  approach pass; the destination is supported OVERWORLD water, foot tile20,
  without a prohibited shore/water pair. Actual Surf remains unverified.

The dormant `supplemental_services` duplicate pond call is separately excluded:
`full` is rejected and that method is not called by the current natural route.
Do not activate it as a substitute 5.5b journey. No Source files, contracts,
tests, live saves or journey code were changed; no native run or push occurred.
