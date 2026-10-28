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
