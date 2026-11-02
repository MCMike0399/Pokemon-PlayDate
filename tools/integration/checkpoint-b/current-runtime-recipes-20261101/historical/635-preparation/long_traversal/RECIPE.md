# B149 physical long traversal — root execution packet

Refreshed host/compile preparation only. Root must establish current runtime
ownership before any execution; no historical census owner is presumed live. No Simulator, lock, GUI, USB, serial or device operations were used
to prepare this packet. No pushes, delegation, shared-driver edits, production
Source edits, new contracts, ledger edits or map activation on main108.

Input checkout is read-only
`/Users/burbujamc/.t3/worktrees/Pokemon-PlayDate/t3-2c976160`, exact
`63549857c19ec1edc191ed02fecb8b20f8b2617a`. `inputs.json` pins the DS1 module,
builder, smoke runner, shared owner, B driver, relevant production seams, all
30 map inputs, accepted A ancestry references and actual earned B files.
Its B provenance says **journey passed Save/Continue; milestone review pending**,
not accepted B hardware. The earned producer Source hash is
`02f483604ea6bc37236538f29885dded59d610592024702cf3977dcdef3b594e`.

Canonical earned input: environment `evidence/chain/5.5b/charmander`:

| File | SHA256 |
|---|---|
| adventure.a.json (sequence 61) | `69e5b9c7472c4170fa3faeec3cfd8176a41169352e390e7ccabb4450999239a0` |
| adventure.b.json (sequence 62) | `f67c86b43a5c2a2e5f8a06342977e6b54838fc870651e4da68bc4cf6d26a8801` |
| provenance.json | `fdc4fc146885d09a0944a18efc854cafaf09c99172837c4431d632a7ca6b9046` |

Both slots have the same Fuchsia Center `(3,3,up)` location. Party: Charizard47
149 HP (Strength/Flamethrower/Slash/Fire Fang), Bellsprout14 Cut, Drowzee13 Flash,
Goldeen10 Surf, plus Metapod8 and Pidgey9. Earned money 52,410; 11 Potions,
4 Revives, both new rods, Bicycle, Flute and HMs. Read current resources from
DS1 `state.resources`; never infer remaining HP/PP from this starting summary.

## Small private extensions, all unapplied to shared files

Existing DS1 can drive ordinary input, but its hardware owner replays a frozen
route. That cannot react safely to natural encounter timing or UI choices.
`root_driver.py` supplies an invocation-local replacement of **only**
`Cycle.wait_smoke`, plus read-only diagnostic inspection and extra validation.
It uses the existing `SmokeSerial`, gate, sequence handling, runtime/device locks,
soak reservation, deploy/import backups, descriptor cleanup, archives and crash
log comparison. It does not replace those owners. No teleport/navigation/RNG/
reward/placement command is added. Root feeds numbered small input batches.

`diagnostic.lua` is appended only to the retained private DS1 module. Its main
installation call is in private staged main. No new dev module is imported.
It wraps actual `OverworldState.enter` and `BattleState.enter`, after their
ordinary owners succeed. `opts.fromDoor == true` counts completed doors;
connections and battle returns are separately recorded entries, never doors.
An initial Continue entry counts as a visited map but not a door. Each entry
must receive one full-GC sample before the next entry, at a settled, top-level
explore frame without field arrival/motion/loading/overlay. A pending sample
that cannot be completed fails rather than silently disappearing. This may
conservatively stop on an immediate arrival battle; root must retain that gap.

Samples are flushed to `long-traversal.jsonl` and printed as `LTR1`, with build,
sequence, zone, entry, origin, completed door count, pre/post-GC heap and GC time.
BootTrace marks bracket GC so existing ordinary-frame metrics exclude those
updates; raw safety still includes them. Only scalar counters, at most149 visited
IDs and one pending record stay resident. Snapshot resources copy at most six
members/four moves and 20 bag slots. No full codec export or observer history.

Hardware Save asserts **before** calling the save owner. Simulator Save remains
available only because the unchanged safety gate requires actual Save. It writes
only disposable Simulator Data imported from separately retained byte-exact
`immutable-seed/`; the original and private seed slots remain unchanged. The
existing device owner additionally archives installed Data and backs up both
slots before import. No hardware Save is needed or authorized by this recipe.

The private `game/saveBuildPolicy.lua` literal is explicitly staged as
`production-profile`, under its existing comment. `build.json` and
`private-save-policy.patch` declare this. The ordinary Source literal
`production` alone would still use deep export inside DEVICE_TEST. Shared Source,
normal production policy, save codecs and the hardware Save prohibition remain
unchanged. Do not compare this production-profile safety Save with the unmatched
8,624 ms deep diagnostic; neither supplies new timing evidence here.

## Exact preparation and safety commands — root only for runtime steps

Run from the checkout containing this packet. Use fresh output names. Preparation
imports helpers from exact B; it never activates B in this main108 checkout.

```sh
PACKET="$PWD/tools/integration/checkpoint-b/current-runtime-recipes-20261101/long_traversal"
B=/Users/burbujamc/.t3/worktrees/Pokemon-PlayDate/t3-2c976160
E=/Users/burbujamc/Developer/Pokemon-PlayDate-env/evidence
SDK=/Users/burbujamc/Developer/PlaydateSDK
STAGE="$E/b149-long-traversal-root-prepare-20261101-ROOT-01"
CAPTURE="$E/b149-long-traversal-root-capture-20261101-ROOT-01"
CAP_OP="$E/b149-long-traversal-capture-operator-20261101-ROOT-01"
SAFETY="$E/b149-long-traversal-root-safety-20261101-ROOT-01"
OP="$E/b149-long-traversal-hardware-operator-20261101-ROOT-01"
ATTEMPT="$E/b149-long-traversal-hardware-20261101-ROOT-01"
python3 "$PACKET/prepare.py" --sdk "$SDK" --output "$STAGE"
python3 "$B/tools/device/simulator_smoke.py" --build-stage "$STAGE"
```

Root must record a short ordinary-input safety route on **this exact bundle and
earned B seed**. Do not substitute a plateau/headroom report or the old 5.4 seed.
`capture_safety.py` uses the existing exact-bundle Simulator runner and Mailbox,
captures input bodies, and retains normal cleanup/archives. Its empty frozen
route makes the recording inadmissible. No recorded timing verdict is promoted.
20 minute wall / 1,500 body bound; command completion timeout30 seconds.

```sh
mkdir "$CAP_OP"
python3 "$PACKET/capture_safety.py" --execute-root --stage "$STAGE" \
  --sdk "$SDK" --output "$CAPTURE" --operator-dir "$CAP_OP"
```

While that process owns the session, submit batches as below; read `state.json`
and `completed.json` after each. First Continue, then ordinary pause Save (select
SAVE and YES by observed labels), dismiss confirmation, walk out the Center door.
Use the fixed eastern-road portals below to Route15 grass for one genuine wild
start; Run through the UI. Return to settled exploration and create `finish`.
No fixed number of grass steps is claimed to guarantee an encounter. If this
cannot finish within the capture bound, stop and retain the gap.

```sh
# Example first batch; increment the six-digit filename after completion.
python3 - "$CAP_OP/000001.json" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]); assert not p.exists()
t = p.with_suffix('.tmp'); t.write_text(json.dumps(['press a 1','wait 30','state']))
t.rename(p)
PY
cat "$CAP_OP/state.json"
# After the safety route is actually complete:
touch "$CAP_OP/finish"
```

Archive the recorder's exact private SDK Data **by rename**, keeping both the
recorder archive and seed. This permits the unchanged runner to import fresh
Data for an exact frozen replay. Refuse an existing destination; no deletes.

```sh
python3 - "$STAGE" "$SDK" "$E/b149-long-traversal-capture-sdk-data-20261101-ROOT-01" <<'PY'
import json, pathlib, sys
s, sdk, dest = map(pathlib.Path, sys.argv[1:])
b = json.loads((s/'build.json').read_text()); assert not dest.exists()
(sdk/'Disk/Data'/b['bundle_id']).rename(dest)
PY
python3 "$B/tools/device/simulator_smoke.py" --execute \
  --build-stage "$STAGE" --sdk "$SDK" --output "$SAFETY" \
  --earned-save "$STAGE/earned-save.json" \
  --commands "$CAPTURE/captured-buttons.json" --timeout 120 --timing-factor 1
```

Factor1 means raw Simulator diagnostic time only; it is not a hardware ratio or
latency prediction. The existing safety admission recomputes raw <=150ms slices,
<=9MiB sampled peak, title/Continue live heap and completed input receipts. An
ordinary performance-budget failure can remain `failed` if raw safety passes;
`--safety-only` implements that existing distinction. Errors/incomplete evidence
remain inadmissible. Do not edit reports, hashes, budgets or verdicts to admit it.
Fresh per-entry GC may itself exceed150ms in Simulator; if so this candidate is
blocked before hardware and requires root's diagnosis, not a gate exception.

## Exact hardware validation and execution commands

Only after runtime ownership is released and genuine exact-build safety passes:

```sh
mkdir "$OP"
python3 "$PACKET/root_driver.py" --operator-dir "$OP" \
  --execute-root --validate-only --safety-only \
  --build-stage "$STAGE" --pdx "$STAGE/DeviceSmoke.pdx" \
  --simulator-smoke "$SAFETY/simulator-smoke.json" \
  --earned-save "$STAGE/earned-save.json" \
  --output "$E/b149-long-traversal-admission-20261101-ROOT-01" --run-seconds 7200
python3 "$PACKET/root_driver.py" --operator-dir "$OP" \
  --execute-root --safety-only --build-stage "$STAGE" \
  --pdx "$STAGE/DeviceSmoke.pdx" \
  --simulator-smoke "$SAFETY/simulator-smoke.json" \
  --earned-save "$STAGE/earned-save.json" \
  --inspect-previous-game PokemonPoC.pdx \
  --output "$ATTEMPT" --run-seconds 7200 --leave-running
```

The private hardware hook starts at actual Title and presses Continue itself.
It requires one verified load and exact Fuchsia Center origin. Feed `$OP` with
numbered batches using the same atomic example above, starting `000001.json`.
Allowed bodies: `state`, `release all`, `press a|b|up|down|left|right 1..8`,
`wait 1..60`, at most64 per batch. Prefer one direction press1 + wait12 + state
per tile, never hold across a portal or unexpected UI. Ordinary idle waits are
recorded. No chord, crank, manual handoff, fixture, save, eval or mutation body.

Limits: two hours from launch, 20,000 commands, 180,000 commanded frames,
160 completed doors, 240 world entries, 48 actual battles, 180 seconds per battle
including its overlays, 30 seconds per command. Collected heap <=6MiB,
observed pre-GC heap <9MiB; original BootTrace soft/hard guards unchanged.
At bound/error, fail and retain partial evidence. No threshold implies success.

## Fixed itinerary and ordinary battle/resource handling

`route.json` fixes the30 map visit order and source-owned portal IDs, source
coordinates, connections and object coordinates. `source-guide.txt` provides
collision grids. Runtime x = source x + manifest padding; y unchanged. These
are pinned geometry inputs, not runtime occupancy/path proofs. Walk within each
map using those grids and observed player/menus; never set position. No planner
or generic travel search is added. Do not use fixture map-census routes.

1. Continue into Fuchsia Center, heal by facing the nurse and pressing A; answer
   YES through observed dialogue/menu. Exit via source warp1 `(3,7)`, DOWN edge.
   Visit Fuchsia City, Mart, Bill's Grandpa's House, Warden's House, Gym, Meeting
   Room and Good Rod House, returning through each ordinary mat. No new gifts,
   trade, boulder push or gym fight is needed. This gives eight distinct maps
   including the starting Center. Avoid the Safari fee/step mode entirely.
2. Follow the existing B driver's `return_from_fuchsia_to_route12` fixed road:
   Fuchsia `(39,16)` RIGHT -> Route15 `(0,8)`; Route15 source warp2 to Gate1F,
   detour upstairs Gate2F and return, then Gate1F source warp4 back to Route15;
   Route15 `(59,8)` RIGHT -> Route14 `(0,44)`; Route14 `(19,10)` RIGHT -> Route13
   `(0,10)`; Route13 `(51,0)` UP -> Route12 `(11,107)`. Visit the Super Rod House
   using source warp4. Route12 warp3 -> Gate1F, visit Gate2F via warp5, return,
   Gate1F warp1 -> northern Route12; `(9,0)` UP -> Lavender `(9,17)`. A same-map
   path through the Route12 gatehouse obstruction is not valid. See all source
   IDs/portal endpoints in `route.json`. These add nine distinct maps.
3. Visit Lavender Town, Center, Mart, Cubone House, Fuji House and Name Rater's
   House, through their fixed Town source warps1/4/5/3/6. Town warp2 enters
   Tower1F; climb the source stairs through2F–7F, then return down. These add13
   distinct maps, for30 total. Fuji/Scope/Marowak/Rockets were already earned;
   do not retrigger rewards or assume an NPC is still present. Do not touch
   Fuji's transport script. No Save. Heal at Lavender Center before and after
   the Tower. Unforeseen occupancy/trigger blockage is a recorded gap, never
   permission for placement, noclip or flag edits.
4. Earn at least20 actual battle starts during that continuous physical session.
   Prefer ordinary wild encounters in Route15 grass while Fuchsia Center is
   nearby, then Tower wild encounters; one-tile steps only. Root must inspect
   `state.long_traversal.battles` after every start. A trainer starts only through
   sight/talk and ordinary UI; defeated trainers cannot be counted again. Do not
   initiate optional trainers merely to replace missing random encounters.
   Twenty encounters are attainable, not deterministic within the fixed bounds.
5. For a wild battle choose RUN by the observed command label; allow at most
   three actual Run attempts, then choose a usable damaging move or stop. For
   an unavoidable trainer use ordinary Fight/PP selections; never Run a trainer.
   Ghosts need Flamethrower/Fire Fang rather than Normal attacks. Dismiss each
   battle message with A and inspect the next state; no blind A spam. Use Bag
   medicine and party selection through UI only. Never refresh HP/PP in a hook.
   Heal at the nearest visited Center at least every five starts, at lead HP
   <=50%, any status or scarce usable PP. If needed, buy source-priced supplies
   in the visited Mart with earned funds; cap added spend at10,000 and new
   medicine at20. Stop if healing/escape is unavailable within bounds. All-fainted
   stops before blackout in the private guard. Handle learning/evolution through
   real menus; protect all four earned field moves. A screenshot/UI state gap
   may require root observation; the packet does not invent an overlay driver.
6. Only AFTER actual distinct map count>=30, repeat Lavender Center <-> Town
   through the same ordinary source door/mat until the **recorded** door count
   reaches110 (margin above100). Enter, walk off the arrival, and return via
   mat/edge input; never count intended inputs as transitions. Stop at160 doors.
   Prefer110–120; do not perform more loops once qualified. Natural extra fights
   still count and still consume the48 battle cap. Finish in settled exploration.

```sh
# After state confirms >=110 doors, >=30 maps, >=20 starts and no pending sample:
touch "$OP/finish"
# Alternatively stop deliberately, retaining partial evidence:
# touch "$OP/abort"
python3 "$PACKET/summarize.py" --stage "$STAGE" --attempt "$ATTEMPT"
```

Root must inspect the completed collection and summary. Raw DS1 sends/replies,
numbered batches, LTR console/file equality, per-entry samples, frame/BootTrace
data, exact installed PDX inventory, unchanged private slots and before/after
errorlog/crashlog hashes are retained. Native allocation diagnostics in serial
stop the private owner immediately and remain visible; native logs are checked
again during collection. No new native-allocation probe is run. Missing native
logs are explicitly missing, not proof that native memory stayed bounded.

USB disappearance, uncertain write/completion, native hard crash/watchdog or new
crash logs stop hardware attempts immediately: **device needs one A press**.
Do not retry, restart, replug, reset or issue more serial input. Descriptor cleanup
and existing owner collection policy remain authoritative. Catchable failures
retain the existing awake/error screen. Successful collection may relaunch only
the exact safe app through `--leave-running`; it never repeats the traversal.

The existing `device-smoke.json` will honestly report missing hardware Save and
possibly latency phases. Do not relabel it a full smoke pass. The separate summary
only checks long-traversal scope and never sets hardware acceptance true.

## Attainable scope and remaining gaps

This is one unmodified earned B physical session through30 pinned maps, >=110
completed doors and >=20 constructed wild/trainer battle starts, with one safe
post-GC sample per entry. No actual coverage has yet been earned by this packet.
Its traversal and UI handling require root operation; there is no unattended
continuous route/battle planner. Dynamic occupancy, safe-window behavior, the
short safety replay and all hardware qualification remain unexecuted. It does not
cover all149 maps, all doors, Safari, native all-allocation peaks, uninstrumented
GC cadence, audio, ordinary pacing or B acceptance. Full GC at each entry changes
collection timing; raw diagnostic costs and pre-GC samples remain visible.
Root's native plateau and point headroom tests are separate evidence and were
neither repeated nor treated as proof of this long session.
