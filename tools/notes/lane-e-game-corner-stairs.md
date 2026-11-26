# Game Corner stairs open after the Rocket

The first walk pressed the stair at (17, 4) and tried to step onto the Rocket at (9, 5). Both misses match pokered. The stair is a wall until `EVENT_FOUND_ROCKET_HIDEOUT`. The Rocket is talk-only, sight 0, so a step onto (9, 5) is `occupied-next-cell`.

The real sequence, from sequence 180, Game Corner (15, 17):

1. Stand at (9, 6) facing up and press A. `GameCornerRocketText` starts. Party is Raticate 20, Zubat 20.
2. After the win his script walks him off and sets `ROCKET_HIDEOUT_SCENE_V1_GUARD_LEFT`.
3. Stand at (9, 5), face up, and press A. The poster sets `EVENT_FOUND_ROCKET_HIDEOUT` and opens the stair.
4. Step onto (17, 4). The player arrives at Rocket Hideout B1F (21, 2).

The first Hideout save is sequence 181. The pause on that stair is sequence 183. No patch. The Hideout story owner already plans the guard, the poster, and `entrance-open`.
