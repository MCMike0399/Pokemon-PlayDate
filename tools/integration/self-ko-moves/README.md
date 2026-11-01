# Isolated Gen V self-KO candidate

Based exactly on private B `f6e10a97239068937f06eebde6b30429d69cabf9`.
Unadopted source preparation. B/root/main and inactive C are untouched.
No SDK, Simulator, compile, device, network download or runtime lock was used.
Root must run native validation and obtain two independent rules reviews before adoption.

Self-Destruct and Explosion share inherited `selfdestruct: "always"` at
Showdown revision `9b136a8c8cdb860a8ab96fa063f906604e352547`.
[Provenance](provenance.json) records exact SHA-256 pins for the base and
Gen8→Gen5 move/ability chains, `sim/battle-actions.ts`, `sim/battle.ts` and
`sim/pokemon.ts`. All were verified against existing local files before use;
no authority is based on recall or network content.

`Battle:performMove` retains dispatch, BeforeMove and PP ownership, then checks
Damp, pays the complete self-KO through `BattleEffects:damage(..., "cost")`, and
uses the extracted existing target-resolution body. Thus user HP is zero before
no-target, invulnerability, immunity, Protect and accuracy checks. The existing
`handleFaint` owner runs afterward. It receives target-last only for an actual
lethal hit (`lastDamage`); misses, blocked hits and absent targets leave user-last.
The oracle queues the user first and awards a simultaneous final-mon win to the
last fainted side in Gen V: the target wins this particular double KO. Existing
recoil priority, rewards, replacement and local-blackout ownership are unchanged.
No new persistent state, faint queue or durable snapshots were introduced.

`BattleEffects` owns the narrow Damp TryMove dependency (ability 6), reading
current effective identities on both living active members. Its Mold Breaker /
Teravolt / Turboblaze suppression follows this exact Gen V Any-event seam only;
these abilities remain unsupported in the general dispatch inventory. No Guard
keeps its active move-user lifetime across the queued self-faint for accuracy and
Fly invulnerability. Other move paths retain their existing living-ability tests.
Damp's Aftermath interaction has no enabled Aftermath producer here; later-gen
Mind Blown and Misty Explosion are outside the roster. This is not blanket Damp
or Mold Breaker family acceptance. Substitute remains fail-loud unsupported.

Generated owners: `tools/generate_gen5_data.py`, `move_producer_contract.py`,
`move-support.json`, `Source/battle/moves.lua` and `moveSupport.lua`.
Producer epoch 17→18 adds only `selfDestruct = true` to the two existing move
rows; the other 423 rows and all original scalar/effect values are exact.
The original 424-row inverse SHA-256 is still
`ad40fd9b5592a4ffeb88dcfc9243cc56034b2f4ea5b2da6bb3f2a8c129da45ea`.
The producer migration JSON/history, schema 4 codec, HM definitions, trainers,
learnsets, AI, public commands, dev dispatcher and harness registrations are exact.
Existing producer tests only advance current epoch expectations or remove new
fields when constructing genuine historical exports.

Host validation: 52 focused producer/migration tests passed, including three new
self-KO producer tests. Full moves regeneration from checksum-verified pinned CSVs
is byte-exact; move support generation and `git diff --check` pass.
`root-registration.patch` passes `git apply --check` and remains unapplied.
No gameplay, SDK or hardware acceptance is claimed.

Replay the bounded host proof with existing local inputs:

```sh
POKEMON_ENV=/Users/burbujamc/Developer/Pokemon-PlayDate-env \
python3 tools/qualify_self_ko_moves.py \
  --preparation /Users/burbujamc/Developer/Pokemon-PlayDate-env/preparation \
  --report /absolute/fresh-report.json
python3 -m unittest tools.tests.test_self_ko_move_generation
python3 -m tools.generate_move_support --check
```

Root registration: apply [root-registration.patch](root-registration.patch), then
run native group `self-ko-moves` (`SelfKOMoveContracts.run`), plus existing rules
regressions. The original 14 exact native case names are:

- Self-KO zero PP rejects before round mutation and RNG
- Self-KO sleep flinch paralysis and confusion retain BeforeMove gates
- Self-KO commits before target damage bypasses Magic Guard and preserves damage RNG
- Self-KO Normal immunity still faints the user without hit RNG
- Self-KO Protect still faints the user without accuracy or damage RNG
- Self-KO accuracy miss faints the user with only the ordinary accuracy draw
- Self-KO airborne rejection and user No Guard retain pre-checkpoint ability lifetime
- Damp on either active side prevents self-KO after PP without hit RNG
- Damp reads current effective ability and ignores fainted holders
- Mold Breaker family suppresses Damp only at the explicit self-KO seam
- Self-KO simultaneous final mons award the target side in both orientations
- Self-KO double faint retains party replacement and reward identity owners
- Self-KO without a living target still faints after PP without hit RNG
- Substitute remains a reported unsupported move without self-KO activation

## Root correction after source review

Standards review found no issues. Spec review found that King's Rock lost its
flinch payload and RNG draw after the user paid the self-KO cost, because the
ordinary held-item query requires a living holder. Root now captures the typed
contact/item secondary through its existing owner before that cost. Construction
consumes no RNG; application remains at the existing successful-hit secondary
gate. The capture is a local call argument, shared move definitions stay exact,
and normal moves retain their original live-item query.

One additional native case, **Self-KO King's Rock retains its pre-faint secondary
and RNG boundary**, covers both moves and successful/failed flinch rolls at the
actual self-faint narration boundary. The group now has 15 prepared cases.
This correction and all cases remain uncompiled/unexecuted; no acceptance or
runtime gain is claimed. All generated move/producer bytes remain unchanged.
