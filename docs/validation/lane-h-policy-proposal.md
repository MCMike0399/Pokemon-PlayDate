# Link, exclusives, trade evolutions, and Mew

This page is a choice for Miguel. Nothing here is implemented. The pin stays pret/pokered `af519899719f0754965776faac0e836a3b906e6d`, English Blue.

## Cable Club

`TRADE_CENTER` (`$EF`) and `COLOSSEUM` (`$F0`) are real map slots. The Pokémon Center receptionist already has the welcome and save lines. There is no partner, no cable protocol, and no second console in this port.

1. Leave both rooms excluded. The receptionist text can stay. No trade and no colosseum battle is added.
2. Build the rooms as local-only. One player would trade or battle a stand-in. That is not the source.
3. Wait, and add a real link later. The rooms stay excluded until that protocol exists.

Recommendation: option 1. A solo trade would invent a partner the source does not have.

## Version exclusives

The installed wild tables are English Blue. Power Plant slots 8 and 9 are Raichu, not Electabuzz. Cerulean Cave slot 5 is Sandslash, not Arbok. `IF DEF(_RED)` rows in the pinned asm are skipped by the generators.

1. Keep shipping Blue only. Red-only species stay out of wild tables.
2. Add a version switch and generate both tables. Saves, the dex, and the statics would have to record which table they used.
3. Mix the two tables. A player could meet both exclusives without a trade.

Recommendation: option 1. The map JSON and the postgame plan are already Blue. A switch is a new product, not a missing row.

## Trade evolutions

Kadabra, Machoke, Graveler, and Haunter evolve by trade. The goal's nine in-game NPC trades are a different list, and the fossil-room scientist 2 is one of those trades (`TRADE_FOR_SAILOR`), not an evolution.

1. Leave the four unable to evolve. Document it. No new item and no new NPC.
2. Add a stone or an NPC that evolves them. That NPC is not in this revision.
3. Wait for the Cable Club. They evolve only if option 3 there is actually built.

Recommendation: option 1. Option 2 would put a species in the dex that the source only produces by link.

## Mew

This revision has no Mew wild slot and no Mew object. The cave and Power Plant generators reject a wild Mew. The old-man glitch and the stadium event are not in the map or the object data.

1. Do not add Mew. The dex can name the species. Nothing in Kanto awards it.
2. Add the event Mew at a new coordinate. That coordinate is not in pokered.
3. Add Mew as a gift, a static, or a wild slot. That is new loot.

Recommendation: option 1.

## Recommendation

Take option 1 for all four. The campaign stays the English Blue cart: no link, no Red tables, no invented trade evolution, and no Mew. Miguel can pick a different option later. Until then these rows stay excluded, and this page is not a change to the game.
