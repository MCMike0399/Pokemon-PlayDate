# Overworld visual audit

Report only. No `Source/` file was changed. Each PNG under this directory is one raw Playdate Simulator frame (left, 400×240) beside the same window of pret/pokered `af519899719f0754965776faac0e836a3b906e6d` (right), scaled 2× with the approved Bayer mapping. A 2px white line separates them. The image is 802×240, 1-bit.

The capture was taken from game commit `0dadd38ac3355b4b9805d6f88d220fb71d0a1fa0`. Pokered supplies the tileset PNG and the blockset. Shade 0 is white, shade 1 is Bayer 31.25% (`{0x55, 0xBB, 0x55, 0xFF, 0x55, 0xBB, 0x55, 0xFF}`), shade 2 is Bayer 68.75% (`{0x00, 0xAA, 0x44, 0xAA, 0x00, 0xAA, 0x44, 0xAA}`), and shade 3 is black. The pattern phase is the world pixel modulo 8, which is the same phase the tile renderer bakes in, because every cell is 32px and 32 is a multiple of 8.

Scores ignore the player, the NPC sprites, an open field text box (y 180–239), and the service money window (x 236–396, y 0–52). Those overlays are not terrain.

**215 maps captured. 13 maps could not be opened. 12 captured maps score above zero. The other 202 score 0 on every axis. `test_zone` has no pokered counterpart.**

## Shared causes

### 1. Pallet and its four rooms are still the hand-authored tiles

Affects `pallet_town`, `oaks_lab`, `reds_house`, `reds_house_2f`, and `blues_house`. These five are the worst maps in the audit, with totals 8 or 9.

The playable rooms are drawn by `Source/world/tilefactory.lua` from the layouts in `Source/data/maps.lua`. They keep the room's silhouette and then diverge: Pallet's trees and flowers are missing or redrawn, roofs are a lighter dither than the overworld tileset, and the lab and houses move or simplify the furniture. On white and light-gray source pixels the authored art adds solid black that the Bayer reference does not have (tick rate about 0.20–0.28).

The imported counterparts (`kanto_pallet_town`, `kanto_oaks_lab`, `kanto_reds_house_1f`, `kanto_reds_house_2f`, `kanto_blues_house`) use the pokered grids. `kanto_reds_house_2f` was captured and matches. The other four abort during actor setup, so they are listed under maps not captured. One tileset cutover, from the authored grids to those imported maps, would clear this whole group.

Owning files: `Source/world/tilefactory.lua`, `Source/data/maps.lua`.

### 2. The approved light-gray Bayer reads as a horizontal hatch

Affects the six gyms that use the GYM tileset: `kanto_fuchsia_gym`, `kanto_viridian_gym`, `kanto_pewter_gym`, `kanto_vermilion_gym`, `kanto_celadon_gym`, and `kanto_cerulean_gym`.

`Shade.LIGHT` in `Source/lib/shade.lua` is the same eight bytes as `Source/data/importedTonePatterns.json`. The fourth byte is `0xFF`, a fully white row. A flat Game Boy light gray therefore becomes horizontal stripes: a black row, a gap, a black row, a blank row. That is the Celadon Gym floor. The right-hand reference is the same pattern, and outside the sprites these six frames match it. Celadon's floor is 25% of the frame and Fuchsia's is 60%; the rest of the gyms fall between those.

The same pattern makes trainers hard to read. Gym sprites fill their bodies with shade 1, so the body dither is the floor dither and only the black outline separates them. Fuchsia, Viridian, Pewter, and Vermilion are the worst because the floor fills the frame. Celadon and Cerulean keep some statues and walls, so the sprites have a little more contrast.

Cinnabar Gym and Saffron Gym use the FACILITY tileset. Their floors match the reference and do not show this hatch.

One change to the two pattern tables would retune every imported light-gray floor, gyms included. The gym grids themselves are not the bug.

Owning files: `Source/lib/shade.lua`, `Source/data/importedTonePatterns.json`. The gym pictures are rendered through `Source/world/tileRegistry.lua` from `Source/data/sourceMapCache/tile-grids.json`.

### 3. Silph Co. 9F paints a solid panel on the facility floor

Affects `kanto_silph_co_9f` only. About 3.3% of the frame, in the lower right and along the bottom edge, is a solid black panel with a dithered rim. The cell stored for that spot in `Source/data/midgameSaffron/SilphCo9F.json` is `pokered:FACILITY:cell:01-01-01-01`, the plain floor, and the pokered blockset draws that floor. The four NPCs in the snapshot are not standing on the panel.

Owning file to start from: `Source/data/midgameSaffron/SilphCo9F.json`, then whatever draws on top of that floor cell.

## How the scores are set

| Axis | 0 | 1 | 2 | 3 |
| --- | --- | --- | --- | --- |
| (a) wrong tile or shade | under 1% of unmasked pixels differ | 1–5% | 5–15% | 15% or more |
| (b) noisy or overdense dither | the light-gray hatch is not the picture |  | the GYM-tileset floor hatch |  |
| (c) hard black ticks on faint detail | under 2% of white/light reference pixels are black in the game | 2–8% | 8–15% | 15% or more |
| (d) missing or extra decoration | terrain matches | one extra panel | same room, different furniture | trees, flowers, or machines don't match |
| (e) sprite readability | sprite reads against its background | gym sprite on a broken-up hatch | gym sprite on a full-frame hatch |  |

A map can score 0 with a few dozen stray pixels. Those are sprite outlines the mask did not quite cover. They are named in the table and are not treated as tile bugs.

## Ranked issues

Worst first. Maps that score 0 on every axis are in the table only.

| Total | Map | (a) | (b) | (c) | (d) | (e) | What is wrong |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 9 | `oaks_lab` | 3 | 0 | 3 | 3 | 0 | Oak's Lab, hand-authored. |
| 9 | `pallet_town` | 3 | 0 | 3 | 3 | 0 | Pallet Town, hand-authored. |
| 8 | `reds_house_2f` | 3 | 0 | 3 | 2 | 0 | Red's room, hand-authored. |
| 8 | `blues_house` | 3 | 0 | 3 | 2 | 0 | Blue's house, hand-authored. |
| 8 | `reds_house` | 3 | 0 | 3 | 2 | 0 | Red's house, downstairs, hand-authored. |
| 4 | `kanto_vermilion_gym` | 0 | 2 | 0 | 0 | 2 | Vermilion Gym floor hatch. |
| 4 | `kanto_pewter_gym` | 0 | 2 | 0 | 0 | 2 | Pewter Gym floor hatch. |
| 4 | `kanto_fuchsia_gym` | 0 | 2 | 0 | 0 | 2 | Fuchsia Gym floor hatch. |
| 4 | `kanto_viridian_gym` | 0 | 2 | 0 | 0 | 2 | Viridian Gym floor hatch. |
| 3 | `kanto_silph_co_9f` | 1 | 0 | 1 | 1 | 0 | Silph Co. 9F, extra solid panel. |
| 3 | `kanto_cerulean_gym` | 0 | 2 | 0 | 0 | 1 | Cerulean Gym floor hatch. |
| 3 | `kanto_celadon_gym` | 0 | 2 | 0 | 0 | 1 | Celadon Gym floor hatch. |

### `oaks_lab` — total 9  (a 3, b 0, c 3, d 3, e 0)

The room shell is there. The floor is a pale dither where pokered is a darker lab floor, and the machines sit in different rows. About 30% of the unmasked frame differs, and a fifth of the faint source pixels are solid black in the game.

Likely cause: Hand-authored TileFactory grids and the authored lab layout, not the imported DOJO/gym tileset.

Owning file: `Source/world/tilefactory.lua`, `Source/data/maps.lua`. The matching imported map is `kanto_oaks_lab`, which did not open.

### `pallet_town` — total 9  (a 3, b 0, c 3, d 3, e 0)

The house in this window is recognizable, and then the roof, the trees, and the flowers diverge. White source pixels are about 20% black in the game. Dark source pixels are about 32% black against a 70% reference. Solid source black survives at about 27%.

Likely cause: Same authored tile set as the interiors. The imported overworld tileset already matches pokered on every other town that opened.

Owning file: `Source/world/tilefactory.lua`, `Source/data/maps.lua`. The matching imported map is `kanto_pallet_town`, which did not open.

### `reds_house_2f` — total 8  (a 3, b 0, c 3, d 2, e 0)

The upstairs room keeps its walls and then redraws the NES, the table, and the pictures. About 20% of the frame differs. The imported upstairs map, `kanto_reds_house_2f`, was captured separately and matches pokered.

Likely cause: Authored interior grids.

Owning file: `Source/world/tilefactory.lua`, `Source/data/maps.lua`.

### `blues_house` — total 8  (a 3, b 0, c 3, d 2, e 0)

Same shape as Daisy's house, with a different table, plant, and picture. About 17% of the frame differs. Daisy herself is readable.

Likely cause: Authored interior grids.

Owning file: `Source/world/tilefactory.lua`, `Source/data/maps.lua`. The imported `kanto_blues_house` did not open.

### `reds_house` — total 8  (a 3, b 0, c 3, d 2, e 0)

The television and the plant are not the pokered tiles, and the top of the frame is a solid band where pokered has the window line. About 16% of the frame differs. Mom is readable.

Likely cause: Authored interior grids.

Owning file: `Source/world/tilefactory.lua`, `Source/data/maps.lua`. The imported `kanto_reds_house_1f` did not open.

### `kanto_vermilion_gym` — total 4  (a 0, b 2, c 0, d 0, e 2)

The floor is about 44% of the frame and matches. A thin strip at the top of the frame is Lt. Surge's hat, not a wrong tile.

Likely cause: Same light pattern.

Owning file: `Source/lib/shade.lua`, `Source/data/importedTonePatterns.json`.

### `kanto_pewter_gym` — total 4  (a 0, b 2, c 0, d 0, e 2)

The floor is about 45% of the frame and matches, apart from a few pixels of Brock's outline that the sprite mask missed. Those pixels are not a tile error.

Likely cause: Same light pattern.

Owning file: `Source/lib/shade.lua`, `Source/data/importedTonePatterns.json`.

### `kanto_fuchsia_gym` — total 4  (a 0, b 2, c 0, d 0, e 2)

The floor is the approved light-gray Bayer and it fills about 60% of the frame, so the horizontal white rows dominate. The pixels match pokered. Koga and the trainers lose their bodies in that hatch; the outline is what remains.

Likely cause: The light pattern's all-white row, shared with every other GYM-tileset gym.

Owning file: `Source/lib/shade.lua`, `Source/data/importedTonePatterns.json`.

### `kanto_viridian_gym` — total 4  (a 0, b 2, c 0, d 0, e 2)

Same floor, about 54% of the frame, with the most trainers of any gym in this pass (the leader and ten others are on the map; several are in the frame). The terrain matches. The sprites sit in the hatch.

Likely cause: Same light pattern.

Owning file: `Source/lib/shade.lua`, `Source/data/importedTonePatterns.json`.

### `kanto_silph_co_9f` — total 3  (a 1, b 0, c 1, d 1, e 0)

The facility floor, the plants, and the glass all match. A solid panel with a dithered rim covers the lower right, and a smaller shape sits on the bottom edge. Together they are 3.3% of the frame. The stored cell under the panel is the plain facility floor.

Likely cause: Something draws that panel on top of a floor cell. It is not one of the four NPCs in the snapshot.

Owning file: `Source/data/midgameSaffron/SilphCo9F.json`.

### `kanto_cerulean_gym` — total 3  (a 0, b 2, c 0, d 0, e 1)

Same GYM-tileset floor, about 30% of the frame, matching the reference. Walls and statues break the hatch up, so the sprites have a harder edge than they do on a bare floor.

Likely cause: Same light pattern.

Owning file: `Source/lib/shade.lua`, `Source/data/importedTonePatterns.json`.

### `kanto_celadon_gym` — total 3  (a 0, b 2, c 0, d 0, e 1)

This is the example of the hatch. The striped floor matches the reference exactly. Statues break the floor up, so it is 25% of the frame rather than the whole picture, and the trainers are a little easier to separate than in Fuchsia.

Likely cause: Same light pattern.

Owning file: `Source/lib/shade.lua`, `Source/data/importedTonePatterns.json`.

## Maps not captured

Every other zone in the warp list opened. These 13 abort inside the fixture, before a frame can be taken.

### Actor art installation aborts

Twelve maps die in `Source/data/ceruleanContent.lua` while installing the overworld actors on that map. A different entry tile does not help, because the crash walks every object on the map.

`installArt` indexes a missing sprite strip (`ceruleanContent.lua:241`, `attempt to index a nil value (local 'strip')`):

| Map | Sprites on the map |
| --- | --- |
| `kanto_pallet_town` | `SPRITE_FISHER`, `SPRITE_GIRL`, `SPRITE_OAK` |
| `kanto_oaks_lab` | `SPRITE_BLUE`, `SPRITE_GIRL`, `SPRITE_OAK`, `SPRITE_POKEDEX`, `SPRITE_POKE_BALL`, `SPRITE_SCIENTIST` |
| `kanto_agathas_room` | `SPRITE_AGATHA` |
| `kanto_brunos_room` | `SPRITE_BRUNO` |
| `kanto_champions_room` | `SPRITE_BLUE`, `SPRITE_OAK` |
| `kanto_hall_of_fame` | `SPRITE_OAK` |
| `kanto_lances_room` | `SPRITE_LANCE` |
| `kanto_loreleis_room` | `SPRITE_LORELEI` |

`CeruleanContent.key` rejects the sprite (`ceruleanContent.lua:182`, `unknown Blue source actor`):

| Map | Sprites on the map |
| --- | --- |
| `kanto_reds_house_1f` | `SPRITE_MOM` |
| `kanto_blues_house` | `SPRITE_DAISY`, `SPRITE_POKEDEX` |
| `kanto_colosseum` | `SPRITE_RED` |
| `kanto_trade_center` | `SPRITE_RED` |

The authored playable rooms for Pallet, Oak's Lab, Red's house, and Blue's house were captured and are scored above. `kanto_reds_house_2f` opened and matches.

### Rock Tunnel B1F rejects a direct warp

`kanto_rock_tunnel_b1f` raises `domain/fieldWorld.lua:177`, `unsupported Rock Tunnel outside entry`. A fixture starts outside the dark-map pair, and only Rock Tunnel 1F may be entered that way. `kanto_rock_tunnel_1f` was captured. The 1F stairs to B1F are in the map, and this pass did not walk them.

## Summary table

Every captured map. Worst first, then the zeros, then `test_zone`.

| Map | Tileset | (a) | (b) | (c) | (d) | (e) | Total | Note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `oaks_lab` | AUTHORED | 3 | 0 | 3 | 3 | 0 | 9 | hand-authored tiles |
| `pallet_town` | AUTHORED | 3 | 0 | 3 | 3 | 0 | 9 | hand-authored tiles |
| `reds_house_2f` | AUTHORED | 3 | 0 | 3 | 2 | 0 | 8 | hand-authored tiles |
| `blues_house` | AUTHORED | 3 | 0 | 3 | 2 | 0 | 8 | hand-authored tiles |
| `reds_house` | AUTHORED | 3 | 0 | 3 | 2 | 0 | 8 | hand-authored tiles |
| `kanto_vermilion_gym` | GYM | 0 | 2 | 0 | 0 | 2 | 4 | gym floor is 44% light gray |
| `kanto_pewter_gym` | GYM | 0 | 2 | 0 | 0 | 2 | 4 | gym floor is 45% light gray |
| `kanto_fuchsia_gym` | GYM | 0 | 2 | 0 | 0 | 2 | 4 | gym floor is 60% light gray |
| `kanto_viridian_gym` | GYM | 0 | 2 | 0 | 0 | 2 | 4 | gym floor is 54% light gray |
| `kanto_silph_co_9f` | FACILITY | 1 | 0 | 1 | 1 | 0 | 3 | solid panel over the facility floor |
| `kanto_cerulean_gym` | GYM | 0 | 2 | 0 | 0 | 1 | 3 | gym floor is 30% light gray |
| `kanto_celadon_gym` | GYM | 0 | 2 | 0 | 0 | 1 | 3 | gym floor is 25% light gray |
| `kanto_silph_co_10f` | FACILITY | 0 | 0 | 0 | 0 | 0 | 0 | sprite outline, 0.53% of the frame |
| `kanto_pokemon_tower_3f` | CEMETERY | 0 | 0 | 0 | 0 | 0 | 0 | sprite outline, 0.06% of the frame |
| `kanto_pokemon_tower_7f` | CEMETERY | 0 | 0 | 0 | 0 | 0 | 0 | sprite outline, 0.06% of the frame |
| `kanto_bike_shop` | CLUB | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_bills_house` | INTERIOR | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_celadon_chief_house` | MANSION | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_celadon_city` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_celadon_diner` | LOBBY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_celadon_hotel` | POKECENTER | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_celadon_mansion_1f` | MANSION | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_celadon_mansion_2f` | MANSION | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_celadon_mansion_3f` | MANSION | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_celadon_mansion_roof` | MANSION | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_celadon_mansion_roof_house` | HOUSE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_celadon_mart_1f` | LOBBY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_celadon_mart_2f` | LOBBY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_celadon_mart_3f` | LOBBY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_celadon_mart_4f` | LOBBY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_celadon_mart_5f` | LOBBY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_celadon_mart_elevator` | LOBBY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_celadon_mart_roof` | LOBBY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_celadon_pokecenter` | POKECENTER | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_cerulean_badge_house` | SHIP | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_cerulean_cave_1f` | CAVERN | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_cerulean_cave_2f` | CAVERN | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_cerulean_cave_b1f` | CAVERN | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_cerulean_city` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_cerulean_mart` | MART | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_cerulean_pokecenter` | POKECENTER | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_cerulean_trade_house` | HOUSE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_cerulean_trashed_house` | HOUSE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_cinnabar_gym` | FACILITY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_cinnabar_island` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_cinnabar_lab` | LAB | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_cinnabar_lab_fossil_room` | LAB | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_cinnabar_lab_metronome_room` | LAB | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_cinnabar_lab_trade_room` | LAB | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_cinnabar_mart` | MART | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_cinnabar_pokecenter` | POKECENTER | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_copycats_house_1f` | REDS_HOUSE_1 | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_copycats_house_2f` | REDS_HOUSE_2 | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_daycare` | HOUSE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_digletts_cave` | CAVERN | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_digletts_cave_route_11` | CAVERN | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_digletts_cave_route_2` | CAVERN | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_fighting_dojo` | DOJO | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_forest_north_gate` | FOREST_GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_forest_south_gate` | FOREST_GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_fuchsia_bills_grandpas_house` | HOUSE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_fuchsia_city` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_fuchsia_good_rod_house` | SHIP | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_fuchsia_mart` | MART | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_fuchsia_meeting_room` | LAB | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_fuchsia_pokecenter` | POKECENTER | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_game_corner` | LOBBY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_game_corner_prize_room` | LOBBY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_indigo_plateau` | PLATEAU | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_indigo_plateau_lobby` | MART | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_lavender_cubone_house` | HOUSE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_lavender_mart` | MART | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_lavender_pokecenter` | POKECENTER | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_lavender_town` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_mr_fujis_house` | HOUSE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_mr_psychics_house` | HOUSE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_mt_moon_1f` | CAVERN | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_mt_moon_b1f` | CAVERN | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_mt_moon_b2f` | CAVERN | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_mt_moon_pokecenter` | POKECENTER | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_museum_1f` | MUSEUM | 0 | 0 | 0 | 0 | 0 | 0 | text box open; masked; money window masked |
| `kanto_museum_2f` | MUSEUM | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_name_raters_house` | HOUSE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_pewter_center` | POKECENTER | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_pewter_city` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_pewter_mart` | MART | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_pewter_nidoran_house` | HOUSE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_pewter_speech_house` | HOUSE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_pokemon_fan_club` | INTERIOR | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_pokemon_mansion_1f` | FACILITY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_pokemon_mansion_2f` | FACILITY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_pokemon_mansion_3f` | FACILITY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_pokemon_mansion_b1f` | FACILITY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_pokemon_tower_1f` | CEMETERY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_pokemon_tower_2f` | CEMETERY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_pokemon_tower_4f` | CEMETERY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_pokemon_tower_5f` | CEMETERY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_pokemon_tower_6f` | CEMETERY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_power_plant` | FACILITY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_reds_house_2f` | REDS_HOUSE_2 | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_rock_tunnel_1f` | CAVERN | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_rock_tunnel_pokecenter` | POKECENTER | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_rocket_hideout_b1f` | FACILITY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_rocket_hideout_b2f` | FACILITY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_rocket_hideout_b3f` | FACILITY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_rocket_hideout_b4f` | FACILITY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_rocket_hideout_elevator` | LOBBY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route1` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route2` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_10` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_11` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_11_gate_1f` | GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_11_gate_2f` | GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_12` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_12_gate_1f` | GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_12_gate_2f` | GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_12_super_rod_house` | HOUSE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_13` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_14` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_15` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_15_gate_1f` | GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_15_gate_2f` | GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_16` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_16_fly_house` | HOUSE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_16_gate_1f` | GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_16_gate_2f` | GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_17` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_18` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_18_gate_1f` | GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_18_gate_2f` | GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_19` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_20` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_21` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_22` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_22_gate` | GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_23` | PLATEAU | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_24` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_25` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_2_gate` | GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_2_trade_house` | HOUSE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_3` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_4` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_5` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_5_gate` | GATE | 0 | 0 | 0 | 0 | 0 | 0 | text box open; masked |
| `kanto_route_6` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_6_gate` | GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_7` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_7_gate` | GATE | 0 | 0 | 0 | 0 | 0 | 0 | text box open; masked |
| `kanto_route_8` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_8_gate` | GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_route_9` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_safari_zone_center` | FOREST | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_safari_zone_center_rest_house` | GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_safari_zone_east` | FOREST | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_safari_zone_east_rest_house` | GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_safari_zone_gate` | GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_safari_zone_north` | FOREST | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_safari_zone_north_rest_house` | GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_safari_zone_secret_house` | LAB | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_safari_zone_west` | FOREST | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_safari_zone_west_rest_house` | GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_saffron_city` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_saffron_gym` | FACILITY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_saffron_mart` | MART | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_saffron_pidgey_house` | HOUSE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_saffron_pokecenter` | POKECENTER | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_seafoam_islands_1f` | CAVERN | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_seafoam_islands_b1f` | CAVERN | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_seafoam_islands_b2f` | CAVERN | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_seafoam_islands_b3f` | CAVERN | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_seafoam_islands_b4f` | CAVERN | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_silph_co_11f` | INTERIOR | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_silph_co_1f` | FACILITY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_silph_co_2f` | FACILITY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_silph_co_3f` | FACILITY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_silph_co_4f` | FACILITY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_silph_co_5f` | FACILITY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_silph_co_6f` | FACILITY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_silph_co_7f` | FACILITY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_silph_co_8f` | FACILITY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_silph_co_elevator` | LOBBY | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_ss_anne_1f` | SHIP | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_ss_anne_1f_rooms` | SHIP | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_ss_anne_2f` | SHIP | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_ss_anne_2f_rooms` | SHIP | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_ss_anne_3f` | SHIP | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_ss_anne_b1f` | SHIP | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_ss_anne_b1f_rooms` | SHIP | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_ss_anne_bow` | SHIP | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_ss_anne_captains_room` | SHIP | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_ss_anne_kitchen` | SHIP | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_underground_path_north_south` | UNDERGROUND | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_underground_path_route_5` | GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_underground_path_route_6` | GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_underground_path_route_7` | GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_underground_path_route_8` | GATE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_underground_path_west_east` | UNDERGROUND | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_vermilion_city` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_vermilion_dock` | SHIP_PORT | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_vermilion_mart` | MART | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_vermilion_old_rod_house` | HOUSE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_vermilion_pidgey_house` | HOUSE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_vermilion_pokecenter` | POKECENTER | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_vermilion_trade_house` | HOUSE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_victory_road_1f` | CAVERN | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_victory_road_2f` | CAVERN | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_victory_road_3f` | CAVERN | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_viridian_center` | POKECENTER | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_viridian_city` | OVERWORLD | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_viridian_forest` | FOREST | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_viridian_mart` | MART | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_viridian_nickname_house` | HOUSE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_viridian_school_house` | HOUSE | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `kanto_wardens_house` | LAB | 0 | 0 | 0 | 0 | 0 | 0 |  |
| `test_zone` | AUTHORED | — | — | — | — | — | — | no pokered map |

Three captures had a field text box up at the moment of the shot: `kanto_museum_1f`, `kanto_route_5_gate`, and `kanto_route_7_gate`. The museum also had the money window. Those rectangles were left out of the score. The terrain under them matches.
