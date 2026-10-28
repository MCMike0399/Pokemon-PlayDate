# Tower and Snorlax scene packet

Base `63267b0`, following Hideout `ed592e1` / `2836a99`. Source-only preparation:
worker runs proportional host checks and SDK compile only. Root retains shared
owners, final event composition, Simulator and native acceptance.

## Register with the delivered content, once

Import `game/towerStory`, `game/snorlaxStory`, `game/towerStoryController`.
No module installs a dispatcher or registers a root machine state.
`TowerStory.descriptors("midgameSouth", "midgameEast")` supplies source Tower
scenes plus the reserved Fuji Poké Flute gift. Distribute those detached values
by each descriptor's content into the content worker's single registrations.
The three existing ordinary 7F trainer descriptors must retain their source
before/won/after fields when overlaid with the bespoke kind/script positions.
Merge `SnorlaxStory.descriptors("midgameSouth")` into South's registration.
Trainer rosters remain exclusively the content worker's.

Exact reserved IDs:

- `pokered:POKEMON_TOWER_6F:hidden_events:1`: synthetic source script trigger
  (10,16), RESTLESS_SOUL / Marowak level 30. Not a fabricated hidden item.
- `pokered:POKEMON_TOWER_7F:objects:1..3`: existing source Rocket trainers,
  now with exact coordinate-specific post-victory departures.
- `pokered:POKEMON_TOWER_7F:objects:4`: Fuji rescue and script warp.
- `pokered:MR_FUJIS_HOUSE:objects:5`: ordinary Poké Flute gift, kept in
  `midgameEast` so source text resolves through that package.
- `pokered:ROUTE_12:objects:1` and `pokered:ROUTE_16:objects:7`: Snorlax,
  source coordinates (10,62) and (26,10), level 30.

After content registration call `TowerStory.install("midgameSouth", {
reconcileActors=contentReconcileActors})` and `SnorlaxStory.install("midgameSouth")`.
Merge TowerStory/SnorlaxStory actorMetadata for their exact IDs into the content
resolver. Tower Rockets stay visible until their source departure completes,
not merely until TrainerEvents records a victory. Fuji moves between Tower and
house through source rescue flags. Root must also compose those flags into
Saffron's source toggle visibility; the source toggles two Saffron objects.

`midgame-story-controller.patch` is an unapplied final-class composition example
extending root's current NPCTradeState. Root retains the one machine registration
and can put these delegation calls into its own final class instead. Never edit
or bypass the trade/daycare/vermilion chain.

## Two small missing root seams

1. `tower-rocket-exit.patch` permits only the exact first Rocket's declared final
   (9,16) stair cell during an NPCMotion script lease. SourceActors currently
   rejects any declared script position on a real warp before the scene can run.
   This patch changes no player traversal or autonomous collision behavior. It
   must be integrated/reviewed by root, which owns shared world code. The other
   eleven source paths end at their actual source cells, often above the stairs.

2. Scripted wild battles need this API in **existing FieldBattle/GameSession**,
   not a scene-owned encounter ledger. `source-story-battle-hooks.patch` contains
   only delegation/receipt call sites; root supplies the owner implementation.
   The worker deliberately provides no ordinary-wild fallback or fake ghost win.

```
FieldBattle.startSourceEncounter(game, request) -> true | false, reason
FieldBattle.attachSourceEncounter(game, battle) -> true | false, reason
FieldBattle.resolveSourceEncounter(game, battle, won, kind) -> true, receipt_or_nil
FieldBattle.takeSourceReceipt(game, stableID) -> detached_receipt_or_nil
```

Requests come from `TowerStory.ghostRequest(session)` or
`SnorlaxStory.request(session,id)`. They contain exact stable ID/zone/species/level,
optimistic flag/item guards, source battle restrictions and outcome flag writes.
The API must retain opaque identity/session/zone/enemy bindings, create through
Specimen's ordinary wild acquisition and existing RulesRNG, bind the actual Battle,
and settle exactly once only while `battle.emittingEnd` and its actual result
matches. Do not derive a result from UI, `lastBattleOutcome` or a callback token.
Ordinary/trainer battles pass through with no source receipt.

Receipts are `{id, zone_id, confirmed=true, kind}`. They are ephemeral return
presentation, consumed only on explicit EventState entry, never while observing.
Resolve source effects before returning to overworld, then dispatch the source
ID after the existing learning/evolution sequence. Defeats use normal blackout
and do not dispatch source return dialogue. Capture recruitment and the Snorlax
removal flags must share GameSession's atomic capture commit; do not recruit
first and later mark a second scene owner. Storage-full capture attempts must
leave the blocker available. Source item/flag guards and RNG must roll back on
failed admission. Key items are checked by inventory, not acquisition flags.

Root battle integration must enforce `rules.capture=false` for restless Marowak
both with and without Scope, and `rules.unidentified` for **all** ordinary Tower
wild encounters without a Scope: the source player is too scared to attack,
the ghost says Get out, no capture is possible, and running remains a real wild
battle option. `rules.intro_labels` and block labels refer to original recipes,
not invented messages. Do not expose Marowak species/Pokédex as identified before
Scope; constructor intro/markSeen is an integration seam too. Apply the same
unidentified-ghost policy to FieldEncounters in Tower 3F..7F, retaining actual
Blue encounter slots/rate bytes, rather than rerolling or suppressing encounters.
The ghost return script moves the player one cell right after an unsuccessful
non-blackout battle, exactly as source. Real victory sets only the ghost flag.

## Field Poké Flute integration

Root's existing key-item owner calls `SnorlaxStory.arm(game)` after the field bag
closes and exploration is settled. Talking to the sprite only prints its source
sleeping text. `fluteTarget(session,zoneID,x,y)` accepts four Route12 cells and
only East/West on Route16, independent of facing. No target should show source
`_PlayedFluteNoEffectText`; it must not consume the flute or invent a target.
The armed source fight flag resumes through the world hook after Continue or
cancelled presentation. Admission consumes/clears that flag in the same owner;
a failed/cancelled admission must remain retryable. No source fight flags should
leak into unrelated random battles.

The outcome table preserves source: caught, victory **and run** remove each
Snorlax permanently; non-caught returns print the route-specific source line.
Defeat clears the fight flag and leaves the blocker retryable. Source source
item use does not require owning `EVENT_GOT_POKE_FLUTE` if the actual item exists.
Flute in-battle mass waking and its music belong to existing item/audio owners,
not these field story plans.

## Cancellation, bag/party-full, Continue and actual source limits

Fuji's dialogue, both rescue flags and the warp are a single finite SourceEvents
program. Destination validation precedes commit; cancellation/failure drops the
warp and commits no rescue. The source destination warp ID is zero-based 1:
Mr Fuji's House (3,7), facing up, plus runtime horizontal padding. Do not replace
it with a guessed interior spawn. Poké Flute grant/full-bag retry is a separate
ordinary gift: failed bag capacity sets no acquisition flag and can be retried.

The three Rocket departure toggles use bounded GameSession quest flags. Source
victory stays committed if presentation is cancelled. Incomplete departure leases
roll back to the actual completed trainer-approach pose and settled exploration
retries. No script phase, callback or lease is serialized. Save is already
blocked under event overlays; settled Continue rechecks original source triggers.
A stale context cannot advance a lease or commit a source result. Ghost/Snorlax
battle cancellation before admission grants nothing. No new payout, trainer
party, capture bonus, item substitution or battle reward is introduced.

Actual Blue has the Poké Doll ghost bypass through its original wild-escape
result behavior. This packet does not invent a Scope-only policy to erase that
branch; root must either preserve the actual source outcome in its existing item
owner or report that uncovered source branch explicitly. Original cry/waits,
fade presentation, unidentified ghost battle art and source audio remain root's
presentation/audio integration. No worker runtime acceptance is claimed.

Regeneration verifies exact reference HEAD and each consumed Git blob, then
records SHA256 in `Source/data/towerStory/provenance.json`; raw inputs stay in
`$POKERED_REFERENCE_DIR`. `test_tower_story` checks all twelve routes, declared
poses, source gift/ghost destinations, Snorlax identities and flute coordinates.
