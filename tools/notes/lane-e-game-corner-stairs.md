# Game Corner stairs do not open

Real input from sequence 180, Game Corner (15, 17) facing up. Pidgeotto 32, Bellsprout 15, Wartortle 31, Dugtrio 27. Boulder, Cascade, Thunder, and Rainbow are set.

The walk reached (17, 5) and pressed up. The player stayed on (17, 5) facing up. The map did not change. `GameCorner.json` warp 3 is that north tile, source (17, 4), destination `ROCKET_HIDEOUT_B1F`. It did not fire.

The poster is background event `pokered:GAME_CORNER:background_events:1` at (9, 4), text `TEXT_GAMECORNER_POSTER`. It is not in `Source/data/midgameEast/events.json` or that file's signs. `Source/data/midgameEast/reservations.json` still reserves Game Corner for "Rocket/poster/hidden stairs and coins/slots". Rocket `pokered:GAME_CORNER:objects:11` stands on (9, 5). A step left from (10, 5) onto that tile was refused: `occupied-next-cell`. There is no event program for that Rocket.

Session `/tmp/lane-j-squirtle-99`. The save stayed sequence 180 because the walk raised before the checkpoint. Hideout, Silph Scope, the Pokémon Tower, the Poké Flute, and Koga are behind this door.
