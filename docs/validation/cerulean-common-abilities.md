# Cerulean ordinary abilities: repair and exposure

Private candidate based exactly on `dbdc4f08079a8b924b013cfc36647b8cbe55fd07`.
This packet does not accept milestone 5.3 or claim complete ability support.

Inner Focus now rejects the flinch volatile after the secondary chance draw;
other effects, attempted PP, action order and RNG remain with their existing owners.
Dry Skin absorbs opponent Water moves at TryHit after type immunity/Protect and
before accuracy, heals floor(maxHP/4) capped at maxHP, and creates no hit receipt.
Its Fire modifier is Q12 5120 at BasePower priority17, after Rivalry24 and before
Mud Sport1/Solar Beam0, with one half-down power rounding. Rain heals
floor(maxHP/8) at the existing weather-member stage and rechecks identity, life
and effective ability when dispatched. Worry Seed uses the existing override
owner. There is no public Sun setter or implemented Substitute/Gastro Acid
producer in this base; no fabricated setter, substitute or suppression fixture
was added. Sun loss and those interactions remain release work when producers land.

The oracle is [pinned Showdown](https://github.com/smogon/pokemon-showdown/tree/9b136a8c8cdb860a8ab96fa063f906604e352547).
The existing `tools/references/early-abilities-sources.json` checksums were checked
for abilities base/gen8/gen7/gen6/gen5 and battle/battle-actions. Dry Skin inherits
its base callbacks; Gen7 removes Inner Focus's later Intimidate protection.
Reference cache: `~/Developer/Pokemon-PlayDate-env/preparation/common-abilities-oracle`.
No native-engine comparison was needed.

## Validation and integration

Six focused host data checks and eight existing ability-metadata checks passed, zero skips. The private harness bundle
compiled with SDK3.1.2 at `~/Developer/Pokemon-PlayDate-env/evidence/common-abilities-compile-20261026-02`.
The 16 new real-SDK contracts **have not executed**; only the root owns Simulator.
They cover actual Bite rounds/target PP, Water immunity/healing/full HP/Protect,
Fire power and HP endpoints, Rain Dance/expiry, Worry Seed, switching and stale
actors/events, with status and RNG assertions. No host Lua or fake SDK was used.
The root must add these two lines to its private harness import overlay:

```lua
import "dev/commonAbilityContracts"
Contracts.register("common-abilities", CommonAbilityContracts.run)
```

After the actual SDK run, refresh Native coverage for changed meaningful bodies:
`Battle:performMove`, `ApplyStatus:apply`, `BattleEffects:basePower`,
`:statusImmunity`, `:events`, `:residual`, and new `:absorbsWater`.
Existing 50 move proofs and ten stale cases receive no renewed credit from this
compile. No main/dev import, ledger, coverage, baseline, protected art, generated
data or non-battle production Source file was changed.

## Ordinary exposure audit

`python3 tools/audit_cerulean_abilities.py --output <path>` reproduces the inventory.
It reads source-profile wild slots, every ordinary regional trainer, only bound
Route22/Cerulean rival variants, the actual Magikarp gift and all starters.
It adds player evolutions through level22 and available Moon Stones, excluding
trades, unavailable stones and unlimited grinding. All ordinary slots are checked
against checksummed B2W2 personal bytes. Result: **57 species, 44 ability IDs**.
The optional Route4 level31 trainer is listed as actual authored exposure, not
ordinary player pacing. Full source IDs/levels are retained in the generated
report at `~/Developer/Pokemon-PlayDate-env/preparation/common-abilities-exposure.json`.

Existing hooks cover IDs 5/8/9/12/14/15/19/20/38/50/51/61/62/65/66/67/68/69/77/79;
this repair adds39/87. This is an ownership inventory, **not a blanket correctness
or Supported claim**. Soundproof43 has only the existing Roar guard; Supersonic
against Voltorb11 (`pokered:MT_MOON_1F:objects:4`) remains a concrete silent gap.
Every other ordinary ID is accounted for below. Trigger examples distinguish
current low-level moves from dependencies that already fail loudly.

| ID / ability | Actual exposure and trigger / outstanding behavior |
|---|---|
| 1 Stench | Grimer12, `pokered:MT_MOON_B2F:objects:1`; its retained Mud Slap can flinch a slower living opponent. Missing chance/payload. |
| 22 Intimidate | Ekans11, `pokered:ROUTE_3:objects:3`; entry must lower opposing Attack. Also player Gyarados20 from the purchased Magikarp. |
| 26 Levitate | Koffing12, `pokered:MT_MOON_B2F:objects:1`; Ground immunity/grounding absent. Current player Magnitude15/17 and obtained TM28 Dig already fail loudly upstream, so no honest successful low-level Ground-hit witness yet. |
| 27 Effect Spore | Paras8, `pokered:MT_MOON_1F:grass:7`; Scratch/Tackle contact should sample and apply eligible status. Missing. |
| 28 Synchronize | Abra8–15, `pokered:ROUTE_24:grass:8` / rival `pokered:CERULEAN_CITY:objects:1`; Paras Stun Spore6 or Ember burn should reflect eligible major status. Missing. |
| 30 Natural Cure | Staryu18/Starmie21, `pokered:CERULEAN_GYM:objects:1`; poison then Pidgey's Whirlwind17 can force withdrawal between Misty's real party members. Cure missing. |
| 33 Swift Swim | Magikarp gift5 and Horsea16/Goldeen19, Cerulean Gym objects3/2; Rain speed hook missing. No natural regional Rain Dance producer through22; existing public rain API is covered separately, not campaign availability. |
| 34 Chlorophyll | Bellsprout12, `pokered:ROUTE_24:grass:3`, Oddish trainer11; Sun speed hook missing, but no Sun producer. |
| 35 Illuminate | Staryu/Starmie are enemy-only in this region. Field lead-rate effect has no ordinary acquisition here. |
| 41 Water Veil | Goldeen19, `pokered:CERULEAN_GYM:objects:2`; Ember burn should be prevented. Missing. |
| 42 Magnet Pull | Magnemite11, `pokered:MT_MOON_1F:objects:4`; no ordinary obtainable Steel player in this region to trap. Missing conditional trapping remains release work. |
| 56 Cute Charm | Jigglypuff3–7, `pokered:ROUTE_3:grass:7`, Clefairy8; opposite-sex contact should infatuate. Missing contact/attraction behavior. |
| 60 Sticky Hold | Grimer12, Super Nerd above; removal prevention missing. Regional item-removal moves such as Covet are already loud gaps; no successful removal trigger claimed. |
| 72 Vital Spirit | Mankey18, `pokered:ROUTE_24:objects:3`; Paras6/22 spores or Butterfree sleep should be blocked. Missing. |
| 75 Shell Armor | Shellder16, `pokered:CERULEAN_GYM:objects:3`; normal damaging hits must not crit. Missing. |
| 83 Anger Point | Same Mankey18; a surviving critical hit should maximize Attack. Missing. |
| 92 Skill Link | Same Shellder16; its retained Icicle Spear13 should hit five times. Missing. |
| 97 Sniper | Horsea16, Gym objects3; ordinary critical hits (including its retained Water Gun11) need the extra modifier. Missing. |
| 98 Magic Guard | Clefairy8, `pokered:MT_MOON_1F:grass:9`, player Clefable via Moon Stone; poison/burn residual and recoil protection missing. |
| 99 No Guard | Machop13–17, `pokered:ROUTE_25:objects:8` / `pokered:CERULEAN_CITY:objects:2`; both participants' moves must bypass accuracy. Missing. |
| 108 Forewarn | Drowzee17, `pokered:CERULEAN_CITY:objects:2`; entry should reveal the selected strongest opposing move, with tie handling. Missing. |

These common gaps still block the real-effect-or-loud-failure regional gate.
A bounded next packet should first repair entry/status/accuracy/crit/multihit hooks
(Intimidate, Forewarn, Vital Spirit, Water Veil, No Guard, Shell Armor, Skill Link,
Sniper and general Soundproof), then contact/condition ownership (Effect Spore,
Cute Charm, Synchronize, Stench, Anger Point, Natural Cure, Magic Guard).
Conditional Sun/Steel/field-only/removal branches can wait for their real producer.
If implementation must be split further, add an ability-gap receipt/dev log and
“But it failed!” **at the actual missing callback trigger** (entry, eligible status,
contact, crit or multi-hit), preserving ordinary move/PP/RNG ownership. Do not
manufacture a menu action, pretend an ability is a selectable move, or announce a
failure merely because an unrelated condition was never produced. No fallback
UI/dev-gap mechanism is claimed implemented by this packet.
