# Party battle and capture integration

Root integrated the rules and selection overlays after242 SDK cases passed.
The combined field/session suite then passed244 contracts and14 native jobs,
including voluntary/forced switches, successful/failed capture, all3 starter
intros, medicine menus, checkpoint blackout and two-process Save/Continue.
[Durable evidence](accepted-session-gameplay/acceptance.json).

Actual capture commands are functional, but the current result leaves the enemy
visible; original-art capture animation is staged separately and required before
presentation acceptance. Trainer-team continuation is SDK-tested but full trainer
content, AI and payout integration remain outstanding. The old handoff at
`/private/tmp/pokemon-party-battle-foundation` must not overwrite newer owner/UI
changes.

## Public battle seam

Existing `Battle(player, enemy, trainerName)` callers keep single-mon behavior
and their two-choice FIGHT/RUN menu. Optional fourth dependencies are:

```
{party=authoritativeParty, session=authoritativeSession, enemyParty=trainerParty}
```

Party may be derived from session. Its actual active member must match player.
An enemyParty uses the same production Party model, must belong to a named
trainer battle and have enemy as its active member. These are references, never
copies or a second roster/bag owner. The current NPC path can omit enemyParty.

- `chooseParty(index)` validates phase, index, ownership roster, already-active,
  fainted state and sleep-duration coherence before mutation/RNG. Voluntary
  switching withdraws the old member, installs the actual selected member,
  clears supported battle stages/volatiles and gives the enemy one turn. Forced
  switching installs the selected member without another attack/residual phase.
- `needsForcedSwitch()` reflects the `forcedSwitch` rules phase. A fainted
  active member with conscious reserves does not end the battle. Commands other
  than valid replacement are refused. The engine never silently revives/heals.
- `beginSelection("party"|"bag")` locks move/run commands while the owner opens
  a selection overlay. `cancelSelection()` costs no turn for voluntary requests;
  forced replacement cannot cancel. A successful chooseParty/throwBall clears
  its selection lock. Rejected choices retain it for correction.
- `availableBalls()` returns actual authoritative bag quantities for the four
  supported balls. `throwBall(id)` performs the real rules/ownership transaction.

Party-backed scenes show FIGHT/BAG/POKEMON/RUN in the existing menu component's
2x2 layout. Only the control area's width changes; sprites, platforms, HP/XP
boxes, typography and all map/character assets remain unchanged. Legacy scenes
retain their existing layout. `BattleScene:takeSelectionRequest()` returns each
`{kind="party"|"bag",forced=boolean}` once. Repeated updates/input cannot enqueue
two overlays. `completeSelection(cancelled?)` clears presentation only after an
accepted command, or explicitly cancels a voluntary request. It refuses an
unresolved selection or forced cancellation. While selection is open, the scene
renders with zero display offset so a previous shake cannot move the overlay.
The owner must still reset display offset on battle exit.

Defeat requires no conscious player member. Enemy fainting with reserves awards
that opponent's XP once, resolves supported residuals, then sends the first
usable enemy member deterministically. No intermediate battleEnd/victory or
trainer reward is emitted. Final battleEnd remains once-only and preserves
`(wonBoolean, kind)`. Kinds include `victory`, `defeat`, `run`, `caught`; caught
uses false as its compatibility boolean and must not be interpreted as defeat.
The owner's actual party-all-fainted check controls blackout. Final trainer
money/progression is owner work triggered once by final victory; no arbitrary
trainer payout amount is invented here.

## Gen V rules and pinned evidence

[Party-battle primary pins](../../tools/references/party-battle-sources.json)
include Pokémon Showdown revision `9b136a8c8cdb860a8ab96fa063f906604e352547`:
[turn/faint/replacement processing](https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/sim/battle.ts),
[BeforeMove/PP/target ordering](https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/sim/battle-actions.ts),
[move targeting](https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/sim/pokemon.ts)
and [Gen V original sleep timer reset](https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/data/mods/gen5/conditions.ts).
The existing [growth pins](../../tools/references/growth-sources.json) preserve
the contemporary Gen V XP research specifying participant splitting before
recipient-level scaling. The separate [capture foundation](capture-foundation.md)
records the capture formula and replay policy unchanged by this slice.

In Gen V, faint replacement is requested at the end of the remaining action/
residual queue; earlier generations have different immediate-replacement rules.
The supported residuals therefore apply to the outgoing field before a new
member is sent. A surviving enemy still attempts its queued action after the
player self-KOs. A user-target Recover can heal; an opponent-target attack has
no living target. Existing status gates still run before PP, and an actual
attempt spends PP before target failure. This avoids silently skipping a
surviving battler's queued move or damaging a fainted target for0.

The minimal metadata repair adds `Move.targetId` from the pinned CSV's B2W2
resolved target_id. The generator applies target changelog corrections rather
than using later defaults (for example Struggle10 and Perish Song12). All423
existing move rows were regenerated. Removing only their targetId additions and
the new constructor line reproduces every byte of the prior moves.lua, including
all scalar/effect text. No new move effect was added. Once targetId exists,
--moves-only rejects target drift just like any other unexpected row change.
Missing/invalid Gen V target metadata fails rather than silently defaulting.
Synthetic manually constructed Move objects retain default10 for compatibility.

For supported singles target handling: IDs1/2/8/9/10/11 require a living opponent;
IDs4/5/6/7/12/13/14 are user/user-or-ally/side/field targets and do not require
that opponent. ID3 requires another ally and has no target in current singles;
IDs15/16 are outside this Gen V generated catalog. The target identifiers are
pinned [PokeAPI data](https://github.com/PokeAPI/pokeapi/blob/2bf639e5572812a67d2b94903fdcb9d095f5aeb2/data/v2/csv/move_targets.csv).
ID1 is move-specific: Counter/Mirror Coat/Curse still require their unimplemented
special mechanics; this conservative live-opponent classification does not claim
to implement conditional targeting or those effects. Side/field metadata also
does not implement currently missing weather/team effects.

## Sleep fields and record boundary

`statusTurns` retains its accepted meaning: remaining blocked sleep attempts,
including valid0 before waking on the next attempted move. New `sleepDuration`
retains the original blocked-turn roll1..3 while asleep; it is0 for every other
major status/none. Applying sleep samples once before committing either field.
Actual withdrawal restores remaining turns from that original value, without a
new random roll. Supported stages/confusion/flinch clear. Major status, HP, PP,
XP and selected moves remain. Incoming supported battle stages/volatiles clear.

Wake, thaw, fullRestore and medicine status cures clear sleepDuration as well as
the existing counter. Capture/Items reject incoherent duration states. Ordinary
battle-exit cleanup remains resetStages, preserving the prior accepted durable
sleep0 boundary; actual party withdrawal invokes `Pokemon:onSwitchOut()`.

PokemonCodec is3. Sleep duration must be1..3, remaining must be0..duration; every
nonsleep state requires duration0. Codec2 is explicitly unsupported, with no
inferred duration migration. Root approved this unreleased private-evidence
boundary. SaveStore envelope/session schema stay unchanged; SessionCodec already
passes validated small scalar fields through, so it needs no special numeric
encoding change. Sleep durations are safely representable SDK JSON integers.
Associated SDK fixture setups now supply explicit durations, preserving new
bridge/controller changes in the rebased combatContracts file.

## Conscious-participant XP and learning

Per current enemy, the engine tracks actual player Pokémon identities that have
entered the field. At faint, it gathers conscious participants from the actual
roster. The base Z is divided by their count after the trainer modifier and
before each recipient's level ratio; each receives its own Gen V scaled/capped
award. Fainted members and unused bench members receive none. Level100/capped
members cannot gain XP; no fainted recipient is resurrected by stat growth.
Participation clears for the next opponent. XP is awarded once per faint, while
only the final opponent produces victory. No Exp. Share, trade/item/Pass Power
bonus or new ability policy is implied.

`Growth.battleAward(..., trainer, participants?)` and
`Pokemon:calcExpGain(defeated, trainer, participants?)` default count to1, keeping
existing callers/vectors intact. Counts1..6 are validated. Independent literals:
base64/defeated5/trainer/two participants awards49 at recipient5 and28 at10;
base64/defeated6/two recipients6 awards58 each. Two level6 starters then queue
separate Ember/Leech Seed choices at level7. A sole conscious recipient receives
115 in that second example. A new level6 Squirtle opponent against the sole
level7 participant awards101. These cases verify splitting order, recipient
levels, faint exclusion and reset between opponents.

The owner must drain learning choices across the party, not just battle.player.
The snapshot list is actual party members in roster order; recursively offer
LearningState for each member with pending choices, then continue to the next
in its completion callback. Capture the session reference and reject continuation
if the installed session changed. Interrupted/forced-close queues remain durable;
no new Later/deferred choice or automatic replacement behavior is introduced.

## Owner integration recipe

BattleState remains root/bridge-owned; this patch deliberately does not replace
it. Root can apply this recipe after the current bridge:

1. Construct Battle with `{party=game.session:party(),session=game.session,
   enemyParty=optionalEnemyParty}`. An optional enemyParty can be a fourth
   BattleState.enter argument; existing NPC calls omit it.
2. Poll scene:takeSelectionRequest once after scene update. Push the reusable
   PartyState or BagState with the callback options below. Those overlays must
   validate via callback before popping; rejected selections stay open and show
   a friendly reason. Forced PartyState disables B/cancel. Field reorder/toss/
   medicine actions must not bypass the battle command callbacks.
3. Guard callbacks against stale BattleState battle/scene/session references.
   On accepted chooseParty/throwBall, call scene:completeSelection(); on voluntary
   cancellation call scene:completeSelection(true). Do not invoke cancel on a
   forced request. Repeated take calls returnnil, preventing duplicate pushes.
4. Keep rules input frozen under overlays. On final battleEnd use explicit kind,
   actual party.allFainted and retained pre-heal HP for outcome diagnostics.
   Keep the existing emittingEnd listener-cleanup guard so later observers still
   receive a normal terminal event. Forced exits still clear stale listeners.
5. Reset supported transients on every party member/enemy at exit; retain major
   status/duration, reset display offset, and release scene/overlay callbacks.
   Blackout heals the whole party and selects a usable lead through the session.
   A final recoil victory with fainted active but usable bench is not blackout;
   select a usable lead without healing that fainted member.
6. After returning to the world, offer all party learning queues sequentially.
   Only final trainer victory marks/rewards the trainer. Caught returns normally,
   grants no XP and never marks a trainer defeated.

Callback shape (the actual overlays remain root-owned):

```
local battle, scene, session = self.battle, self.scene, self.game.session
local request = scene:takeSelectionRequest()
-- Push party/bag only when request exists.
local function select(value)
    if self.battle ~= battle or self.scene ~= scene or self.game.session ~= session then
        return false, "stale-selection"
    end
    local ok, reason
    if request.kind == "party" then ok, reason = battle:chooseParty(value)
    else ok, reason = battle:throwBall(value) end
    if ok then assert(scene:completeSelection()) end
    return ok, reason
end
```

BAG in this slice selects balls through that callback. Field medicine UI must
not apply a medicine during battle without a separate turn-aware battle command.
The successful throw preflights phase, trainer restriction, target, ball stock,
selected-box capacity and ownership before RNG/item changes. It calls Capture,
consumes exactly one, recruits the same enemy through GameSession and produces
caught without XP. Failed actual throws spend one and run the enemy/residual
turn. Full party+selected box refuses without automatic box rollover, item
consumption or RNG. Recruitment keeps HP/status/duration/PP and clears battle
transients. No replacement bag, Pokémon clone or second storage owner is created.

## Fixture and native handoff

Four JSONs are staged under tools/harness/scenarios: capture-success,
capture-fail, voluntary-switch and forced-switch with party-battle prefixes.
They use root-approved setup names:

- party_pokemon array of species/level plus optional hp/status/status_turns/
  sleep_duration; mutually exclusive with player_pokemon. Build/validate the
  whole roster through the authoritative session before committing it.
- inventory object with optional money and slots of id/quantity; validate with
  Inventory before installing into the same authoritative owner.
- adjust_battle adds player_sleep_duration/enemy_sleep_duration. Validate both
  battlers before mutation. A new sleep0 fixture requires an explicit1..3
  original duration. Positive fresh initial sleep can supply matching duration;
  existing counter-only adjustments preserve the valid original duration.
  Nonsleep status changes clear both duration/counter.

Required semantic paths: battle.capture_result (receipt keys unchanged),
battle.forced_switch, battle.selection_kind, party.count/active/members,
inventory.quantities.ID (0 for known absent items), plus existing battle/player/
PP/rng/last_battle_outcome paths. Add sleepDuration to per-Pokémon diagnostics.
The JSONs assume PartyState's existing initial selected1, then native Down selects2.
They assert forced B remains in PartyState. Root may update that one navigation
if it intentionally changes the default to first usable. Old party-enabled
native RUN navigation becomes Right+Down in the new2x2 menu; Fight stays index1.

These are scenario candidates, not executed evidence. Root must install the
owner hooks and schema/diagnostics before running them. They use actual native
button input after setup. Success shows BAG/throw/caught/world return; failure
shows an enemy response consuming PP; voluntary switch shows original sleep
reset and the enemy turn; forced switch shows uncancellable selection and no
extra enemy attack. No fabricated captures or fake SDK are used.

## Reproducibility and gates

Executed here:

```
GEN5_GENERATOR=/private/tmp/pokemon-party-battle-foundation/tools/generate_gen5_data.py python3 -m unittest tools.tests.test_move_target_generation tools.tests.test_gen5_yield_projection
PYTHONPATH=/Users/burbujamc/Developer/Pokemon-PlayDate python3 /private/tmp/pokemon-party-battle-foundation/tools/generate_gen5_data.py --input-root /Users/burbujamc/Developer/Pokemon-PlayDate --output-root /private/tmp/pokemon-party-battle-foundation --moves-only --pinned-cache /private/tmp/pokemon-verifier-fresh-cache
python3 /private/tmp/pokemon-party-battle-foundation/validate_staged.py --project /Users/burbujamc/Developer/Pokemon-PlayDate --output /private/tmp/pokemon-party-battle-compile-03
```

Eight offline generator/yield tests pass. Pinned generation reproduces all423
rows and is idempotent; the preservation check strips only target fields and
compares all other bytes. Species blocks/learnsets/assets were not rewritten.
The real SDK compiler succeeds.27 actual SDK contract groups are authored and
compiled, not executed by this worker. They cover the production command/session/
party/capture/codec/scene seams, meaningful boundary states and independent vectors.

Root execution (root alone owns Simulator):

```
python3 /private/tmp/pokemon-party-battle-foundation/validate_staged.py --project /Users/burbujamc/Developer/Pokemon-PlayDate --output /private/tmp/pokemon-party-battle-runtime-01 --execute
```

The helper overlays only manifest-owned Source onto current Source, keeps the
current entry/bridge code, inserts the contract import/registration, refreshes
all hashes/config and compiles. It verifies the generator repair separately.
Optional --scenario points to one staged native JSON after root installs hooks.
Base hashes prevent overwriting changed owners' work; combatContracts was
explicitly rebased onto the integrated bridge rather than reverting it.

Remaining gaps: complete move effects/conditional target semantics, Pursuit and
trapping restrictions, abilities/items/entry hazards, weather, Shift-style free
counter-switch prompts, trainer AI choice/item policy, battle medicine commands,
trainer reward amounts/data and battle resume remain separate work. Enemy
replacement is deterministic first-usable/set-style without those entry effects.
This slice does not claim all423 moves, full competitive mechanics or the full
campaign complete.
