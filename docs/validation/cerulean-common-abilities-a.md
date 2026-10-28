# Cerulean common abilities, batch A

Implementation branch `wip/kanto-entry-abilities` starts exactly at
`30844ee1dc696cadc9febe06c6300f2c697b5711`. This adds bounded ordinary hooks for
Intimidate22, Forewarn108, Vital Spirit72, Water Veil41, No Guard99, Shell Armor75,
Skill Link92, Sniper97 and general Soundproof43. It preserves the base's Inner
Focus39 and Dry Skin87 repairs. It does not accept milestone5.3 or renew coverage.
The exposure boundary remains the existing audit's 57 species and 44 ability IDs
in [cerulean-common-abilities.md](cerulean-common-abilities.md).

Intimidate and Forewarn run at actual entry, including replacements. Competing
initial Start callbacks use effective speed, with one ordering trial for a tie.
Intimidate clamps Attack and allows Gen5 Inner Focus. Forewarn uses declared
power and original slot order, ignores remaining PP, and samples a strongest
move even when uniquely strongest. Its fixed/variable-power class includes the
reachable Low Kick, Flail and fixed-damage moves; it does not evaluate their
unimplemented damage producers. A missing move definition fails at the actual
entry callback with “But it failed!” and a bounded `[ability-gap]` diagnostic.
The declared-power ranking follows the pinned callback, including its simple
OHKO/counter classifications, without adding those moves' missing producers.

Vital Spirit and Water Veil prevent their status payloads and cure an applicable
persisted condition on entry. Direct status moves announce immunity; immune
secondaries remain silent after the existing chance trial. No Guard bypasses the
accuracy trial on either active living participant, including the existing OHKO
accuracy seam; it does not bypass Protect, type immunity, level or Sturdy gates.
Shell Armor rejects the critical result after its trial and before stage bypass.
Skill Link chooses the maximum hit count without a count trial; actual hits still
roll critical/damage independently and stop on faint. Sniper uses final Q12
half-down rounding after burn/minimum damage. Soundproof uses the complete pinned
Gen5 sound-flag projection for all 12 current registry moves, including
Supersonic, Sing, Growl, Screech and damaging sound moves. Sonic Boom is excluded.
Moves with missing producers still fail at their earlier move-dispatch gate.

Every new hook checks active, living identity and the existing effective-ability
override owner. Worry Seed provides the real override producer. There is no
Substitute, Gastro Acid, Mold Breaker or semi-invulnerability producer in this
base; no fabricated suppression or underground fixture was added. Conditional
Sun/Steel/field-only/removal abilities remain deferred under the existing audit,
and the seven contact/condition abilities belong to batch B.

## Validation and root integration

`python3 tools/check_common_ability_hooks.py` passes 56 focused source/data checks
against 12 checksummed primary files. It resolves the actual Gen5 move mod chain
and checks callback inheritance, critical trial ordering, final damage stage,
announcement policy, and reachable Forewarn power classes. Its default paths are
the existing local preparation caches; `--abilities` and `--moves` select another
verified cache. Missing or corrupt inputs fail; there are no skips or host Lua.
The existing exposure and ability-metadata suites pass all 14 host tests.
The oracle remains [Showdown9b136a8](https://github.com/smogon/pokemon-showdown/tree/9b136a8c8cdb860a8ab96fa063f906604e352547)
through gen8/gen7/gen6/gen5. No native-engine comparison was needed.

The new `Source/dev/entryAbilityContracts.lua` contains **28 real-SDK cases**.
They use actual Battle coroutines/public commands, typed Party ownership,
production RulesRNG, and HP/PP/status endpoints. They cover initial entry order,
actual switching/reentry, stale actors, overrides, immunity timing, critical
stage behavior, early multihit KO and a Sniper rounding witness that rejects an
early x3 critical modifier. **These cases have not executed.** The root alone
owns Simulator and must execute them on the composed source. SDK3.1.2 compilation
with a private import overlay passed; the final compile evidence is recorded in
the worker's return message. Compilation is not mechanics acceptance.

Root's private harness overlay needs these lines after production battle imports
and the existing Contracts definition:

```lua
import "dev/entryAbilityContracts"
Contracts.register("entry-abilities", EntryAbilityContracts.run)
```

No main/dev import, conditions.lua, generated data, world/story, ledger,
coverage proof or baseline was edited. The root must refresh exact owner and
assertion proofs after the composed Native run; this packet grants no renewed
credit to old move proofs or stale witnesses.

## Changed meaningful production bodies

- `battle.lua`: `calcDamage`, `accuracyThreshold`, `checkAccuracy`, `Battle:init`,
  `Battle:hitCount`, and new `Battle:recordAbilityGap`.
- `dsl.lua`: `ApplyStatus:apply` (only the new immunities' announcement branch).
- `effects.lua`: `supported`, `accuracyBypassesCheck`, `canAttempt`,
  `statusImmunity`, `entry`, `ohko`; new `livingAbility`, `criticalAllowed`,
  `multiHitMaximum`, `finalDamage`, `forewarn`, `initialEntries`.

## Batch B composition seams

Batch B's core patch remains unapplied. A changes no existing receipt-consumption,
hit-loop secondary, successful status-commit, withdrawal or damage-commit site.
The root can compose B's stated APIs after this commit:

- `ContactAbilities.onHit(effects, receipt, actualCriticalFlag)` belongs before
  the hit loop's existing typed secondaries. `result.isCrit` now already reflects
  Shell Armor. `calcDamage` applies Sniper independently before `effects:hit`.
- `ContactAbilities.damagingHit(effects, receipt)` belongs at the end of the
  existing validated, once-consumed `BattleEffects:afterHit`. Its receipt includes
  source/target/move, before/removed HP, contact, cause and hit number. No critical
  field was added; B's explicit actual-critical argument remains necessary.
- `ContactAbilities.secondaries` follows existing typed secondaries in the hit
  loop and B's fixed/Psywave/OHKO integration sites. A does not change those sites.
- `ContactAbilities.afterStatus` follows the successful durable status commit in
  `ApplyStatus:apply`, before presentation. A changes an earlier immunity return
  only. `statusSource` and `statusCause` still carry explicit origin, while
  `conditions:statusOrigin`/`:preventsStatus` own Safeguard eligibility.
- `ContactAbilities.withdraw(effects, old)` belongs in `commitActiveMember` before
  `effects:clear(old)` removes Worry Seed. That commit remains non-yielding.
- `ContactAbilities.preventDamage` belongs before HP/round-ledger changes in
  `BattleEffects:damage`. Its existing cause labels distinguish hit, status,
  weather, recoil, struggle-recoil, confusion and condition-owner causes.
- Infatuation's condition owner can insert its action gate after confusion and
  before PP. A does not change `resolveTurn` or conditions.lua.

The core sites A actually changes near B are `calcDamage` (critical-result gate
and final modifier), `Battle:init` (initial entry dispatcher), `hitCount`, the two
accuracy functions, and `ApplyStatus:apply`'s earlier immunity-notification branch.
Keep both intents when applying B's patch; no concurrent writes were used.
