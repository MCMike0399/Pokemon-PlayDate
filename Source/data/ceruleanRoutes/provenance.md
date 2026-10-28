# Blue rival and Rocket scripts

The source is `pret/pokered` revision
`af519899719f0754965776faac0e836a3b906e6d`, English Blue.
`tools/references/cerulean-routes/manifest.json` pins every consumed input by
SHA-256. The vendored scripts, objects, coordinate helper, constants and map
inputs reproduce the projection offline. The existing shared map decoder reads
those map inputs only to verify collision along scripted paths. It does not
install maps or regenerate art.

Run under `source ~/Developer/Pokemon-PlayDate-env/env.sh`:

```sh
python3 tools/generate_cerulean_routes.py --check
python3 tools/generate_cerulean_routes.py --reference "$KANTO_REFERENCE" --check
python3 -m unittest tools.tests.test_cerulean_routes
```

`scenes.json` contains source coordinates, movements and trainer-number/text
references. It contains no map geometry, roster copies or dialogue strings.
`CeruleanContent.rivalClasses`, `trainers` and `text` remain the content owners.
Rival payouts use the original class multiplier and last Pokémon's level:
280 on Route 22 and 595 in Cerulean. Both imported Rocket teams are unchanged.
Battle rules, learnsets and stats remain Gen V, with the existing fixed Blue
trainer IV policy and ordinary acquisition traits.

The coordinate helper increments its index before comparing. Despite misleading
comments in Route22.asm, the upper trigger is index 1: four approach steps,
then right twice/down five on departure. The lower trigger is index 2: three
approach steps, then up/right three/down six. The city script's internal MAPX
25 means source cell 21 after its four-cell sprite bias. Both bridge lanes and
both Route 22 trigger lanes are covered by native witness definitions.

No new event names were invented. Source event flags represent victories and
the Nugget. The source hide-object bit `TOGGLE_CERULEAN_ROCKET` is represented
as a quest boolean, true only in the atomic TM28 grant. It is distinct from the
thief's defeat flag, so a full bag keeps him present. Bill's Ticket and guard
flags are exclusively owned by the story candidate.

Blue gives the Nugget before the Rocket battle. Full bags back the player down
one tile without starting battle. After a loss, the gift remains and subsequent
interaction is the leader speech: no second gift or paid rematch. A cancelled
overlay after the committed gift has that same post-gift state; normal saving
is unavailable while the overlay or battle owns the scene. Rival losses and
thief losses grant no victory flags or money, and remain retryable. Their real
blackout and disk-process Continue witnesses are root acceptance work.
