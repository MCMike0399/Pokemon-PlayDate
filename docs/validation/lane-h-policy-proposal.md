# Link, exclusives, trade evolutions, and Mew

Miguel decided all four questions on Nov 12, 2026 at 9:43 AM CST. The pin stays pret/pokered `af519899719f0754965776faac0e836a3b906e6d`, English Blue. Questions 3 and 4 are Miguel-approved deviations from that revision.

## Cable Club

`TRADE_CENTER` (`$EF`) and `COLOSSEUM` (`$F0`) are real map slots. The Pokémon Center receptionist already has the welcome and save lines. There is no partner, no cable protocol, and no second console in this port.

Miguel's pick: leave both rooms excluded. The receptionist text stays. No trade and no colosseum battle is added.

## Version exclusives

The installed wild tables are English Blue. Power Plant slots 8 and 9 are Raichu, not Electabuzz. Cerulean Cave slot 5 is Sandslash, not Arbok. `IF DEF(_RED)` rows in the pinned asm are skipped by the generators.

Miguel's pick: Blue only. There is no Red/Blue switch.

## Mew

Miguel-approved deviation. This revision has no Mew wild slot and no Mew object. The old-man glitch and the stadium event are not in the map data.

Miguel's pick: make Mew obtainable, as a gift. After the Hall of Fame, a scientist at Cerulean Cave 1F `(23, 16)` gives Mew at level 5, the level of the original event distribution. One Mew per save, behind `EVENT_GOT_MEW`. The giver, the flag, and the lines live in `Source/data/postgame/` and `Source/game/postgameStory.lua`. The cave opens when the ceremony hides the guard, so the gift is not available before then.

The giver is a real map object, or the cave shows nobody. `tools/notes/lane-e-mew-scientist.patch` appends that scientist to `Source/data/zRemainder/CeruleanCave1F.json` at `(23, 16)`, sprite `SPRITE_SCIENTIST`, facing right, id `postgame:CERULEAN_CAVE_1F:mew-gift`. That file's checksum is the runtime cache pin, and the manifest hash of those pins is in every cell-cache header. The patch is not applied on this branch. The steps at the top of the patch are how lane E replaces the pin and regenerates `Source/data/sourceMapCache` and `Source/data/sourceMapCells`. The headless run stands on `(24, 16)`, facing the giver, and takes the gift.

## Trade evolutions

Miguel-approved deviation. Kadabra, Machoke, Graveler, and Haunter evolve by trade in the Gen5 graph. Those trade rules stay. The Cable Club is not built, so the trade hook still does not fire.

Miguel's pick: a new item, used like an evolution stone. The name is `LINK CABLE` (10 characters). It turns Kadabra into Alakazam, Machoke into Machamp, Graveler into Golem, and Haunter into Gengar, and it does nothing to any other species. It is consumed. The bag name and the line `Use like a stone.` are the bag entry and the item text.

The item comes from the same cave scientist, one cable each time you ask, after the Hall of Fame. Celadon Mart 4F is the generated stone counter and is open before the ceremony, on another lane's stock list. A repeatable gift in the cave covers all four consumed uses without editing that mart. The bag row, the stone set, and the four evolution edges are `tools/notes/lane-e-link-cable.patch`. They are not applied on this branch.
