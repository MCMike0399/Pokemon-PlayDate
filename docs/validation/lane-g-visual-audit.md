# Lane G overworld visual audit

Report only. No `Source/` file was edited for the original pass. The pictures and the ranked write-up are in [artifacts/lane-g/visual-audit/](../../artifacts/lane-g/visual-audit/AUDIT.md).

## Status on 2026-11-19

Checked `origin/main` at `bf92c4fc` and `origin/cursor/lane-e-integration` at `40bf4112`. Neither tip has applied `lane-e-pallet-cutover`, `lane-e-pallet-actors`, or `lane-e-pallet-tones` (`paintPalletField` / `PALLET_CENTER` are absent, and `maps.lua` still registers the authored `pallet_town`). The three patches still apply cleanly on this branch. No Simulator frames were captured for r20.

- **Authored Pallet** (`pallet_town`, `oaks_lab`, `reds_house`, `reds_house_2f`, `blues_house`): still open. Waiting on Lane E to apply the cutover, actor, and mockup-C tone patches.
- **Gym hatch / `Shade.LIGHT`:** held for Miguel's Celadon pick. Not touched.
- **Silph Co. 9F panel:** the locked card-key doors at blocks `(9, 2)` and `(9, 5)`, not a stray floor graphic. `lane-e-silph-9f-panel` only records that. Lane E has not applied it.
- **Twelve actor warp crashes:** fixed on Lane E. `CeruleanContent` there loads `data/zEndgame/sprites.json` and `data/zRemainder/sprites.json`. Those catalogs have standing and walking strips for Agatha, Bruno, Lance, Lorelei, Red, and the Pallet actors. This branch's `lane-e-pallet-actors` patch stays the nine Pallet strips and does not repeat that loader.
- **Rock Tunnel B1F:** a direct outside warp still raises `unsupported Rock Tunnel outside entry`. That reject is the pinned policy in `FieldWorld.transitionOffset` and `Source/dev/fieldWorldContracts.lua`. The legal entry is the stair from 1F, which keeps the dark offset. No patch.

## What was compared

Game commit `0dadd38ac3355b4b9805d6f88d220fb71d0a1fa0`. Pokered commit `af519899719f0754965776faac0e836a3b906e6d`.

Each captured map is one raw Simulator frame, 400×240, beside the same window of the pokered tileset and blockset. The reference is 2× with the approved Bayer mapping: white, 31.25% (`{0x55, 0xBB, 0x55, 0xFF, 0x55, 0xBB, 0x55, 0xFF}`), 68.75% (`{0x00, 0xAA, 0x44, 0xAA, 0x00, 0xAA, 0x44, 0xAA}`), and black. Pattern phase is the world pixel modulo 8. The combined image is 802×240, 1-bit, named `<map>.png`.

Scores ignore the player, NPC sprites, an open text box, and the service money window. Axes are wrong tile or shade (a), noisy dither (b), hard black ticks on faint detail (c), missing or extra decoration (d), and sprite readability (e). Each axis is 0–3. The rubric is in `AUDIT.md`.

## Counts

228 overworld zones are on the warp list. 215 were captured. 13 abort inside the fixture and have no frame. `test_zone` was captured and has no pokered map, so it is not scored.

202 captured maps score 0 on every axis. 12 score above zero.

## Top 10

| Total | Map | Why |
| --- | --- | --- |
| 9 | `oaks_lab` | Hand-authored lab. Floor shade and machine rows differ. |
| 9 | `pallet_town` | Hand-authored town. Roof, trees, and flowers differ. |
| 8 | `reds_house_2f` | Hand-authored room. The imported upstairs map matches. |
| 8 | `blues_house` | Hand-authored room. |
| 8 | `reds_house` | Hand-authored room. |
| 4 | `kanto_vermilion_gym` | Light-gray Bayer hatch. Sprites sink into it. Terrain matches. |
| 4 | `kanto_pewter_gym` | Same hatch. |
| 4 | `kanto_fuchsia_gym` | Same hatch, and it fills about 60% of the frame. |
| 4 | `kanto_viridian_gym` | Same hatch. |
| 3 | `kanto_silph_co_9f` | A solid panel is drawn on a floor cell. |

`kanto_celadon_gym` and `kanto_cerulean_gym` also score 3, for the same hatch on a smaller share of the frame.

## Shared causes

1. **Authored Pallet tiles.** `pallet_town`, `oaks_lab`, `reds_house`, `reds_house_2f`, `blues_house`. Owned by `Source/world/tilefactory.lua` and `Source/data/maps.lua`. The imported maps are the faithful versions. `kanto_reds_house_2f` was captured and matches. The other four imported counterparts abort while installing actors.

2. **Approved light-gray Bayer.** `Shade.LIGHT` in `Source/lib/shade.lua` and `Source/data/importedTonePatterns.json` has an all-white row (`0xFF`). On a flat gym floor that is the Celadon hatch, and gym sprites filled with shade 1 disappear into it. Affects `kanto_fuchsia_gym`, `kanto_viridian_gym`, `kanto_pewter_gym`, `kanto_vermilion_gym`, `kanto_celadon_gym`, `kanto_cerulean_gym`. The frames match the reference. Cinnabar Gym and Saffron Gym use the FACILITY tileset and do not show it.

3. **Silph Co. 9F panel.** One map. The cell in `Source/data/midgameSaffron/SilphCo9F.json` is the plain facility floor. The frame paints a solid panel there.

## Not captured

Actor setup in `Source/data/ceruleanContent.lua` aborts twelve maps. A missing sprite strip (`:241`) stops `kanto_pallet_town`, `kanto_oaks_lab`, `kanto_agathas_room`, `kanto_brunos_room`, `kanto_champions_room`, `kanto_hall_of_fame`, `kanto_lances_room`, and `kanto_loreleis_room`. An unknown actor (`:182`) stops `kanto_reds_house_1f`, `kanto_blues_house`, `kanto_colosseum`, and `kanto_trade_center`.

`kanto_rock_tunnel_b1f` raises `domain/fieldWorld.lua:177`, `unsupported Rock Tunnel outside entry`. `kanto_rock_tunnel_1f` was captured. A direct warp cannot enter B1F.
