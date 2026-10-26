# Common Kanto abilities, batch B

Prepared on `wip/kanto-contact-abilities` from exact
`30844ee1dc696cadc9febe06c6300f2c697b5711`. This is an implementation packet;
COMMON5.3, Native acceptance, coverage and main integration remain pending.
The audit is [cerulean-common-abilities.md](cerulean-common-abilities.md).

`ContactAbilities` implements Effect Spore (27), Cute Charm (56), Synchronize (28),
Stench (1), Anger Point (83), Natural Cure (30) and Magic Guard (98) at existing event seams.
It never orders actions, spends PP, owns progression, commits HP or replaces
BattleEffects' hit-token, effective-ability, pending-action or damage owners.
There is no ability-gap fallback or battle-entry announcement in this packet.

The tracked production edits are the new module and attraction ownership in
`BattleConditions`. Attraction is keyed by actual Pokemon identities, excludes
same-sex/genderless/Oblivious targets, gates after confusion and before paralysis
and PP, and clears when either identity withdraws/faints or battle state clears.
No Pokemon field, codec or save schema was added. Existing script cancellation
owns suspended continuations; attraction makes no callback queue of its own.

## Primary policy

The oracle is [Showdown 9b136a8](https://github.com/smogon/pokemon-showdown/tree/9b136a8c8cdb860a8ab96fa063f906604e352547).
`tools/references/contact-abilities-sources.json` pins 17 primary files, checking
existing pins where available. The cache is
`~/Developer/Pokemon-PlayDate-env/preparation/common-abilities-oracle`.
The host checker checks those hashes before inspecting callbacks/mod inheritance.

- Effect Spore uses one contact roll: 11% sleep, 10% paralysis, 9% poison. The
  successful sleep payload separately samples its duration. Gen V Grass has no
  powder immunity. Existing major status and type/ability/Safeguard gates stay
  with ApplyStatus. A holder KO still reaches the contact chance.
- Cute Charm's 3/10 contact chance precedes sex/Oblivious/existing-attraction
  eligibility. The BattleConditions owner rejects a fainted source or recipient
  and retains no attraction across the real faint checkpoint.
- Synchronize runs only after a successful major-status commit, preserves bad
  poison, and excludes sleep/freeze/self/toxic-spike origins. Reflected status
  uses ApplyStatus with captured ability provenance and its existing immunities.
- Stench appends a typed 10% flinch secondary after existing secondaries. It
  respects Shield Dust before chance and Inner Focus at payload, avoids adding
  a second flinch secondary, and never modifies shared Move definitions. Fixed,
  Psywave and OHKO paths receive the same hook at their actual hit sites.
- Anger Point receives the real critical result at Hit before secondaries and
  contact; a surviving holder commits Attack +6 before narration. No critical
  result or critical RNG is fabricated for fixed damage.
- Natural Cure runs synchronously in the actual replacement commit before
  effective-ability overrides clear. Faint and battle-close cleanup never call
  this withdrawal hook. Status, duration and toxic state clear without healing.
- Magic Guard rejects status/weather/recoil/condition HP loss before HP or the
  hurt-this-round ledger changes. Toxic and binding counters still advance.
  Protected Leech Seed removes/heals zero HP. Direct hits and confusion still
  mark real HP loss. HP costs and Struggle recoil retain their existing ledger
  exclusion; Struggle recoil still damages the holder. The root patch prevents
  false damage narration for the current indirect producers.

## Root integration

[contact-abilities-root.patch](contact-abilities-root.patch) is deliberately
**unapplied**. It contains 41 insertions/14 deletions over effects.lua, battle.lua,
dsl.lua and conditions.lua. The condition hunks only make existing indirect
producers narrate positive HP loss; the committed condition changes only own
attraction. Batch A owns the other shared files. Root must compose both patches
at the declared callback seams and rerun acceptance. No tracked main/dev import,
SourceData, story/world, ledger, coverage or baseline file was changed.

After cherry-picking the implementation commit and then the handoff commit:

```sh
git apply --check docs/validation/contact-abilities-root.patch
git apply docs/validation/contact-abilities-root.patch
```

Root must add these lines to its own private harness import overlay:

```lua
import "dev/contactAbilityContracts"
Contracts.register("contact-abilities", ContactAbilityContracts.run)
```

The runtime command belongs to root, after composing Batch A and this patch:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python tools/harness/run.py contracts --output "$HOME/Developer/Pokemon-PlayDate-env/evidence/contact-abilities-sdk-UNIQUE"
```

The narrow callback patch does not register blanket `BattleEffects:supported`
metadata. Root must reconcile those support declarations with acceptance and
remaining dependencies rather than interpreting seven hooks as complete release
support. No new fallback success or global ability-failure mechanism is claimed.

## Verification and explicit limits

19 focused host checks passed, zero skips: five new primary checks, six regional
exposure checks and eight ability-metadata checks. The25 new SDK contract cases
are **prepared, not executed**. They use production Pokemon/moves, actual turn,
status, switching, phazing, critical, contact, HP and RNG endpoints. Fixture move
ownership and deterministic seeds supplement natural campaign acceptance; they
are not campaign witnesses. No stock Lua, substitute SDK, injected result or
Simulator process was used.

The private composition compiled with SDK 3.1.2 at
`~/Developer/Pokemon-PlayDate-env/evidence/contact-abilities-compile-20261026-05`.
`composition.json` records every compiled source hash and the root patch hash.
Reproduce the checks or make another private compile-only composition:

```sh
python3 -m tools.check_contact_ability_sources
python3 -m unittest tools.tests.test_contact_ability_sources tools.tests.test_cerulean_abilities tools.tests.test_ability_metadata -v
python3 tools/prepare_contact_abilities.py --output "$HOME/Developer/Pokemon-PlayDate-env/evidence/contact-abilities-compile-UNIQUE"
```

The helper copies Source and applies the declared root patch only in the new
output directory, inserts the normal harness overlay plus the two registration
lines, then invokes pdc. It never launches that bundle or creates Simulator Data.

Substitute and Gastro Acid have no implemented producers in this base, and Sun
and Hail have no public setters. No fake state/fixture or support claim covers
those dependencies. Future Substitute must suppress actual hit/contact/secondary
callbacks; suppression must resolve through the effective-ability owner. Future
indirect producers must supply explicit provenance to BattleEffects:damage;
unknown causes are not silently classified as indirect. Later held-item
interactions such as Destiny Knot and doubles-only behavior are release gaps.
Current entry hazards/Curse route through the protected condition damage owner,
but their full Magic Guard interaction suite and an eligible Magic Guard HP-cost
witness remain unexecuted/unproved. Ability metadata, the integrated Native run,
Native coverage, protected-art verification, all other existing SDK contracts
and natural regional journeys are root acceptance work and receive no credit
from this compile.
