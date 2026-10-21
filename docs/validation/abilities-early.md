# First16 Gen V battle abilities

The integrated build passed584SDK contracts and9native jobs. Root reviewed real
Sturdy/secondKO, lethalStatic/paralysis, ShieldDust, sand/ShedSkin/expiry,
ArenaTrap/Party, RunAway and GroundThunderWave screens. See
[archived evidence](observed-pewter-foundation/abilities-and-natural04.json).

This covers normal IDs5Sturdy,8SandVeil,9Static,14CompoundEyes,19ShieldDust,
50RunAway,51KeenEye,61ShedSkin,62Guts,65Overgrow,66Blaze,67Torrent,68Swarm,
69RockHead,71ArenaTrap and77TangledFeet. All111IDs remain the required full scope;
95other effects, held battle effects/acquisition, other weather, sex-dependent
abilities and remaining move producers are unfinished.

Battle owns one BattleEffects instance. Pure accuracy/stat/withdrawal queries,
consumed typed hit receipts and ordered weather/ability residuals compose into the
existing coroutine/conditions owner. Nothing persists weather or transient
ability activation in a save. Existing LearningState suspends the same battle
coroutine before enemy replacement/residual; extra draws cannot advance rules.

All424 generated moves declare contact/secondary/OHKO metadata from the complete
pinned Showdown Gen8→5 inheritance chain. Primary/secondary provenance controls
ShieldDust before chance; direct hits resolve drain→secondary→contact reaction,
then whole-move recoil and faint verdict. Static can react to lethal contact.
Sturdy distinguishes fullHP direct survival from anyHP OHKO immunity. Multihit
probabilities are35/35/15/15. Separate fixed-two-hit Rage tests retain exact boosts.

Q12 ratio chaining uses half-up; stat/accuracy application uses half-down.
CompoundEyes75 becomes98 before stages. Guts modifies physical Attack and exempts
burn, while confusion self-damage uses its separate raw staged calculation.
ShedSkin uses33/100 and clears sleep/toxic state before major-status damage.
Sandstorm starts5, decrements before each weather callback and therefore damages
on4residuals, expiring without damage on the fifth. Both weather faints resolve
as one cohort before XP/learning/verdict. Rock SpD/weather healing/SolarBeam sand
power dependencies are implemented; SolarBeam charging remains a declared gap.

The compatibility followup preserves public fixed/Psywave DSL calls without a
currentMove. Damage type immunity and explicitly flagged ThunderWave immunity
resolve before accuracy, with PP already spent. Ground blocks primary
ThunderWave; GenV Electric targets can be paralyzed and Static can paralyze Ground.
RunAway bypasses wild binding/ArenaTrap; trainer refusal remains outside it.

Primary pins are [early-abilities-sources.json](../../tools/references/early-abilities-sources.json).
Root independently checked26mechanic files,5Showdown move inputs,5CSV inputs,
15literal metadata vectors and424byte-exact generated rows. Offline8host tests
pass. With explicit immutable caches, reproduce:

```sh
python3 tools/qualify_early_abilities.py --source-root "$PWD" \
  --mechanics-cache /path/to/mechanics --showdown-cache /path/to/showdown \
  --csv-cache /path/to/pokeapi --report /tmp/early-ability-primary.json
.venv/bin/python tools/harness/suite.py --only contracts-catalog ability-sturdy \
  ability-static-lethal ability-shield-dust ability-weather-shed-skin \
  ability-arena-trap ability-run-away ability-thunder-wave-ground \
  --output /private/tmp/ability-check-UNIQUE
```

Missing immutable source caches fail; add the qualifier's explicit--fetch option
to download them. Corrupt existing caches are preserved and rejected. Native
recipes are explicitly synthetic fixtures, distinct from natural campaign proof.
The full move verifier has0learnset/scalar discrepancies across151species/424moves
but still exits1 for54known mechanics gaps and73status reviews. No all-move or
complete GenV certification is claimed.
