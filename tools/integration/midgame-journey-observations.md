# Exact midgame journey observations and fixed waypoints

Checked root exact `7351c003a1edec80a772e5d50335223c79aa206e` and later
`9e8e06d`. Neither contains these new story modules or scripted-wild owner APIs
until root integrates this branch. Do not pretend a seeded flag or fabricated
receipt is gameplay. The following is the prepared packet's concrete interface.

Read durable truth through `game.session:questFlag(id)`,
`game.session:trainerDefeated(stableID)`, and
`game.session:inventory():quantity(itemID)`. Inventory flag possession does not
substitute for actual key quantity. `game.machine:get("event"):getSnapshot()`
already returns `id`, `phase`, `waiting`, `menu.active`, `menu.selected`,
`menu.options` and `trainer`. The event's `plan.scene`/`plan.scene_script` are
transient dispatch/presentation, not authoritative saved progression. No new
story state owner or debug projection is required. Do not consume TrainerEvents
or source battle receipts from diagnostics. Pure `scenes()` and `descriptors()`
accessors return detached data and have no execution effects.

Native menu phases/options after root composition:

| Phase | Options | Selection |
| --- | --- | --- |
| `hideout-floor` | `B1F`, `B2F`, `B4F` | 1..3 |
| `silph-floor` | `1F` through `11F` | 1..11, existing scrolling menu |
| `service-choice` for Dojo | `YES`, `NO` | 1..2 |
| `source-pokedex` | existing species display | dismiss to the Dojo offer |
| `move` | no menu | waiting is player direction |
| `move-npc` | no menu | waiting is exact source actor ID |
| `dialog` / `receipt` | no menu | waiting is the source page label |

Every controller phase above falls through the existing NPCTradeState chain.
Menu B cancels; it grants nothing and retains the prior elevator destination.
Battle/menu observations remain the existing battle owner fields. Await a real
settled overworld after spinners, not each automatic intermediate cell.

## Runtime coordinates (padding already included here)

All Hideout floors, Game Corner, Tower, Routes12/16 and Silph floors have padding0.
Rocket elevator padding3; Fuji house padding2; Erika/Koga/Dojo padding1; Sabrina
padding0; Silph elevator padding4. These values were checked against the exact
worker contexts at f2166ef / ed941b0 / 22eee05. The JSON scene coordinates are
source coordinates: add SourceMaps.entry(mapName).padding once, never twice.

Hideout:

- Game Corner guard `pokered:GAME_CORNER:objects:11` at (9,5). Talk from (9,6)
  for direct RIGHT5 departure, or (8,5), facing right. Poster is (9,4); after
  guard departure stand (9,5), face up and interact. Door appears at (17,4).
- B1F entrance (21,2); stairs (23,2) -> B2F (27,8).
- B2F stairs (21,8) -> B3F (25,6). B3F stairs (19,18) -> B4F (19,10).
- Lift Key Rocket `pokered:ROCKET_HIDEOUT_B4F:objects:4` (11,2). Defeat him,
  finish the win receipt, **talk again** to set EVENT_ROCKET_DROPPED_LIFT_KEY.
  Lift Key pickup objects:9 is (10,2); item `liftKey`; collection flag
  `PICKUP:pokered:ROCKET_HIDEOUT_B4F:objects:9`. Full bag leaves it retryable.
- Return through B3F to B2F. B2F cabin entrances (24,19)/(25,19). Cabin panel
  runtime (4,1). Choose B4F. Both cabin exits resolve to B4F (25,15).
- B4F guards objects:2 (23,12), objects:3 (26,12). Both source trainer victories
  unlock source door block (12,5), cells x24..25/y10..11, on map load. Re-enter
  via cabin if necessary. Flag EVENT_ROCKET_HIDEOUT_4_DOOR_UNLOCKED.
- Giovanni objects:1 (25,3); trainer victory and
  EVENT_BEAT_ROCKET_HIDEOUT_GIOVANNI. Scope objects:8 (25,2) is a **separate**
  pickup: item `silphScope`, flag `PICKUP:pokered:ROCKET_HIDEOUT_B4F:objects:8`.
- Static, collision-derived routes for B2/B3, both directions, including each
  spinner approach/trigger/stop and single step command are in
  `hideout-fixed-routes.json`. Source-only, no native acceptance claim or runtime
  planner extension. B3 required forward spinner triggers: (12,11), (10,13),
  (11,18). Stops: (10,11), (14,13), (15,22). Reverse: (18,16)->(18,15),
  (16,13)->(16,11). Wait for each real event to finish before the next walk.
- Synthetic spinner IDs are B2F hidden_events:1001..1043 and B3F
  hidden_events:1001..1016. IDs1.. are actual source hidden items and are reserved.
- Saved cabin selection flags: ROCKET_HIDEOUT_LIFT_V1_B1F/B2F/B4F. Guard left
  flag: ROCKET_HIDEOUT_SCENE_V1_GUARD_LEFT. No scene phase is saved.

Tower and Snorlax:

- Tower6F ghost script trigger (10,16), ID
  `pokered:POKEMON_TOWER_6F:hidden_events:1`. Reads actual `silphScope`; source
  Marowak level30, cannot be caught. Confirmed victory sets
  EVENT_BEAT_GHOST_MAROWAK. Failed non-blackout battle moves player right one cell.
- Tower7F Rocket talk positions: (9,12), (12,10), (9,8), for objects1/2/3.
  Other exact source coordinate cases are in towerStory/scenes.json. Await
  POKEMON_TOWER_ROCKET_V1_LEFT_1/2/3, not merely trainer defeat.
- Fuji object4 at (10,3); source rescue transaction sets EVENT_RESCUED_MR_FUJI
  and EVENT_RESCUED_MR_FUJI_2, warps to Fuji house runtime (5,7), facing up.
- Fuji house object5 is runtime (5,1). Separate ordinary gift: `pokeFlute`,
  EVENT_GOT_POKE_FLUTE. Full-bag retry must not manufacture either item or flag.
- Route12 Snorlax objects:1 at (10,62); use the actual Bag Poké Flute from
  (9,62), (10,61), (10,63) or (11,62). Route16 Snorlax objects:7 at (26,10),
  source flute range only (25,10)/(27,10). Talking only prints sleeping text.
- EVENT_FIGHT_ROUTE12_SNORLAX / EVENT_FIGHT_ROUTE16_SNORLAX arm admission.
  EVENT_BEAT_ROUTE12_SNORLAX / EVENT_BEAT_ROUTE16_SNORLAX remove the blocker
  after real victory, capture **or run**. Defeat leaves it retryable. Both level30.
- Root must wire SnorlaxStory.arm(game) through the existing settled field-item
  owner. Root FieldBattle.startSourceEncounter/takeSourceReceipt APIs are absent
  in the checked roots; fail explicitly until installed. No fake ghost rejection
  dialog substitutes for its actual unidentified wild battle.

Silph:

- Card Key is ordinary `cardKey` on 5F at source/runtime (21,16). Door interact requires actual inventory,
  faced foot tile and exact block. All20 source door flags/blocks and trigger IDs
  are in silphStory/scenes.json. IDs are hidden_events:1001.. on each floor.
- Cabin panel runtime (7,0). Eleven options; SILPH_STORY_LIFT_V1_1..11 retain
  chosen floor. Cabin arrival initializes origin floor; no key required.
- Required pad routing: floor3 (11,11), warp9 -> floor7 (5,3), warp5. Walk to
  (3,2) to trigger the first rival path; (3,3) is the second path.
  Rival objects:9 source home (3,7), battle pose (3,3) or (3,4). Source index is
  **one-based**: first gets UP4/RIGHT2 departure; second gets UP3 then
  LEFT,UP,UP,RIGHT3,DOWN. Both end on pad(5,3). No teleporting the player/NPC.
- EVENT_BEAT_SILPH_CO_RIVAL is committed by trainer victory;
  SILPH_STORY_V1_RIVAL_LEFT only after actual departure. Rival teams use content
  OPP_RIVAL2 index7/8/9 for player Charmander/Squirtle/Bulbasaur, payout2600.
- Lapras giver objects:1 at (1,5), exactly level15, source BIT_GOT_LAPRAS. Full
  party uses selected box; full box fails without claim/RNG. No added bag check.
- Floor7 pad(5,7), warp4 -> floor11 pad(3,2), warp4. Giovanni triggers (6,13)
  or (7,12); source walks from (6,9) to (6,12). First faces player up/Giovanni
  down; second player left/Giovanni right. EVENT_BEAT_SILPH_CO_GIOVANNI.
- President objects:1 at (7,5), ordinary `masterBall`/EVENT_GOT_MASTER_BALL gift
  and full-bag retry. Inaccessible LAST_MAP pad(5,5) stays inaccessible.

Gyms / Dojo:

| Trainer | Runtime actor | Confirmed flags | Separate retry reward |
| --- | --- | --- | --- |
| CELADON_GYM:objects:1 Erika | (5,3) | EVENT_BEAT_ERIKA, BADGE_RAINBOW | tm21 / EVENT_GOT_TM21 |
| FUCHSIA_GYM:objects:1 Koga | (5,10) | EVENT_BEAT_KOGA, BADGE_SOUL | tm06 / EVENT_GOT_TM06 |
| SAFFRON_GYM:objects:1 Sabrina | (9,8) | EVENT_BEAT_SABRINA, BADGE_MARSH | tm46 / EVENT_GOT_TM46 |
| FIGHTING_DOJO:objects:1 Master | (6,3) | EVENT_BEAT_KARATE_MASTER | source one-of-two Pokémon |

All trainer IDs have `pokered:` prefix. Leader victory also deactivates all
source gym trainers (7/6/7 respectively), independent of bag-full TM retry.
Dojo auto-trigger is runtime (5,3), player right. Gifts objects6/7 are runtime
(5,1)/(6,1): Hitmonlee/Hitmonchan, level30. Claim selected species flag
EVENT_GOT_HITMONLEE or EVENT_GOT_HITMONCHAN **and** EVENT_DEFEATED_FIGHTING_DOJO
atomically; neither is granted by Master victory. Only the chosen ball vanishes.
Decline/box-full is retryable. The root gift extra-flags patch is required.

Charmander's optional route can cover all spinner items / twelve alternative
script cases separately; Bulbasaur and Squirtle need only these story gates and
source-correct teams. Fixed routes are preparation, not earned-save evidence.
Journey/scenario/dev projection code remains with its assigned worker.
