# Vermilion battle abilities — root handoff

Prepared on `wip/vermilion-battle-abilities`. The branch preserves audit commit
`edba4e5ad8f007dc8eb560098935d074dc64c891` and merges exact root
`4deee81` at `b24e617` before implementation. Root's uncommitted 65-map activation
was not copied. Cherry-pick the implementation commit reported with this handoff;
the merge/audit commits do not need to be replayed onto root.

## Concrete changes

- `OrdinaryAbilities` owns Flash Fire's identity-keyed volatile and the seven
  bounded callbacks. `BattleEffects` remains the effective-ability, HP-loss and
  receipt owner. Flash Fire commits activation before narration, boosts physical
  and special Fire attack stats, never stacks, and clears on actual withdrawal,
  Worry Seed's ability change and battle close.
- Technician (101) joins the existing Q12 power-modifier chain at Gen5 priority19,
  after Rivalry24 and before Dry Skin17. Its 60-power threshold observes accumulated
  modifiers. Fixed damage bypasses it; multi-hit sampling is unchanged.
- Fire absorption (18), Water Absorb (11) and existing Dry Skin share the actual
  post-Protect, pre-accuracy TryHit seam. Absorption consumes attempted PP but no
  accuracy/critical/variance/secondary/contact trials or hit receipts.
- Clear Body (29) shares `canDropStat` between `ModifyStat` and Intimidate entry.
  Self drops remain legal. Typed secondary provenance passes through `When` and
  `EffectSeq`, preserving the chance trial while suppressing secondary fail text.
- Direct drain consumes an actual hit receipt once. Shared drain healing receives
  explicit donor/recipient identities and cause; Liquid Ooze (64) reverses the
  attempted healing even at full recipient HP or when the donor just reached 0 HP.
  It uses existing indirect `condition` HP-loss provenance, including Magic Guard
  and hurt-this-round accounting. It does not create a second direct-hit receipt.
- Leech Seed captures its existing source **side**, then drains to that side's
  current member. A reflected recipient KO returns its side to the existing
  residual faint cohort and reward checkpoint. No reward/session owner is added.
- Swift Swim (33) joins `Battle:effectiveSpeed` before Gen5 paralysis division.
  Turn order, entry ordering, Electro Ball and residual sorting use this query.
  Rain remains field-owned; an outgoing or overridden member gets no stale boost.
- Levitate (26) guards supported Ground damage before accuracy and Protect, and
  participates in groundedness for Arena Trap, Spikes and Toxic Spikes. Ground
  status moves still work. Witnesses use actual Mud-Slap/Bulldoze; Dig/Magnitude
  dispatch remains unchanged and loud-failed.

## Root integration and native execution

Production imports the new module through `battle/effects.lua`; no main change.
Apply the separate, **unapplied** registration patch to root's owned overlay:

```sh
git apply --check tools/patches/vermilion-abilities-registration.patch
git apply tools/patches/vermilion-abilities-registration.patch
```

It registers `VermilionAbilityContracts.run` as `vermilion-abilities`. The new
module contains **39 prepared real-SDK cases**, using production Battle scripts,
commands, HP/PP, actual move records and RulesRNG. Cases cover ordinary damage,
absorption, Intimidate, secondary trials, direct/seed drain, KO/reward boundaries,
Protect, ability absence, voluntary/forced switching, Worry Seed, stale actors,
cancellation, spent receipts, rain order/expiry and grounded hazards. Supplemental
fixtures may select existing moves outside a specimen's acquisition path; they
are rules witnesses, not natural-journey or acquisition acceptance. No fake
Substitute, Sun or Gastro Acid producer exists in this packet.

**Root must execute these and the full existing SDK suite.** Nothing here claims
39 native passes or preservation of the previous 1597 passes. Compile-only is not
runtime acceptance; case assertions may require root's actual SDK feedback.

## Checks and conditional gaps

Pinned Showdown `9b136a8c8cdb860a8ab96fa063f906604e352547`, base through Gen8→7→6→5,
is the behavior oracle. `python3 -m tools.check_vermilion_ability_sources` verifies
all 17 existing immutable oracle files, callback inheritance/priority, the Gen6
Liquid Ooze override retained in Gen5, and full-HP TryHeal order. Native personal
bytes verify ordinary specimen slots only; no native behavior discrepancy or new
fidelity decision was needed.

**17 focused host checks pass, zero skips** (`test_vermilion_ability_sources`,
`test_contact_ability_sources`, `test_ability_metadata`), including six callback
policy mutations, corrupt pin rejection and regeneration of 16 actual trigger
move records. The full existing metadata generator reports an unchanged baseline
gap: its 425-record projection adds Bide to the 424 tracked records; all 424 existing
records agree exactly. No generated metadata or baseline was edited.

SDK3.1.2 production and harness compilation pass. A separate private staged main
also compiles with the new suite imported and registered. Evidence lives under
`~/Developer/Pokemon-PlayDate-env/evidence/` in
`vermilion-battle-abilities-production-20261026-01`,
`vermilion-battle-abilities-compile-20261026-04`, and
`vermilion-battle-abilities-registered-compile-20261026-02`.

Field acquisition/rate effects remain the other worker's scope. Pickup loot,
Magnet Pull, unsupported moves, later ability suppression/grounding producers and
full mechanics promotion remain outside this packet. No Simulator/runtime,
push, delegation, main/dev-import, maps, session/codec, ledger, coverage,
protected baseline or existing contract edits were made by this implementation.
