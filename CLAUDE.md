# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Requires the [Playdate SDK](https://play.date/dev/). Set `PLAYDATE_SDK_PATH` before building.

```bash
# Build, clean, and open in Simulator
PLAYDATE_SDK_PATH=~/Developer/PlaydateSDK make build

# Individual steps
make clean      # rm -rf PokemonPoC.pdx
make compile    # pdc Source PokemonPoC.pdx
make run        # open Simulator with PokemonPoC.pdx

# Deploy to a connected Playdate device (USB, unlocked)
make deploy     # compiles, enters data disk mode, copies .pdx, ejects & reboots
```

The `deploy` target auto-detects the Playdate at `/dev/cu.usbmodemPD*`. It puts the device into Data Disk mode, waits for `/Volumes/PLAYDATE` to mount (up to 30s), copies the `.pdx` bundle, and ejects. The Playdate reboots automatically after eject.

There are no tests or linting tools configured.

## Architecture

Lua project for the Playdate handheld (400x240, 1-bit display, 30 FPS). All source is in `Source/`.

### Game Loop & State Machine

`main.lua` is the entry point. A single `StateMachine` instance drives the game loop with four states: **overworld**, **battle**, **dialog**, **debug**. Only one state is active at a time. State transitions pass arguments through `stateMachine:change(name, ...)`.

`playdate.update()` calls `stateMachine:update()` then `stateMachine:draw()` each frame, followed by incremental GC (`collectgarbage("step", 1)`).

### Two OOP Systems

- **Playdate's `class()`** (from `CoreLibs/object`) — used for sprite-based entities: `Player`, `NPC`
- **Custom `Class()`** (`lib/oop.lua`) — used for everything else: `Battle`, `StateMachine`, `Camera`, `Dialog`, `Menu`, `Pokemon`, etc. Registers classes as globals. Supports `:extends()`, `:includes()`, `:abstract()`, `Signal` mixin, and `Pool` for object recycling.

### Import Order (in main.lua)

Order matters. Key constraints:
1. `lib/oop.lua` first (provides `Class()` used everywhere)
2. `lib/shade.lua` and `world/tilefactory.lua` before `world/overworld.lua` (tiles generated at import time)
3. `world/zone.lua` before `data/maps.lua` (Zone class needed for `registerZone()` calls)
4. `data/pokemon.lua` before `data/maps.lua` (encounters reference Pokemon class)

### Key Modules

- **`battle/battle.lua`** — Turn resolution engine. Gen I damage formula, STAB, type chart, crits, accuracy, status effects, run formula. Uses `Signal` mixin to emit `battleEnd` events.
- **`battle/battleScene.lua`** — Battle UI rendering and input handling. Draws HP bars, sprites, move select with type effectiveness preview.
- **`battle/moves.lua`** — Move definitions with composable effect system: `StatChange`, `StatusEffect`, `ConditionalEffect`. Move data stored in global `moveData` table keyed by camelCase name.
- **`data/pokemon.lua`** — 156 species definitions in global `pokemonData` table keyed by lowercase name. Contains `Pokemon` class with stat calculation, XP, PP, damage methods.
- **`data/typechart.lua`** — 15-type effectiveness matrix accessed via `TypeChart.getMatchup()`.
- **`data/maps.lua`** — Zone definitions using declarative tile codes and `setupOverworld()`.
- **`world/zone.lua`** — Zone class with Dart-like declarative config. Auto-generates collision from tile types. See below.
- **`world/player.lua`** — Grid movement with smooth interpolation (8 frames/step at 30fps). Walk animation: Gen 1 cadence (stride first half of step, standing second half) with the lead leg alternating per step via `walkToggle` (distinct side stride frames; X-flipped frames for up/down). Characters draw 8px above their tile (GB style) and a tall-grass overlay hides the legs while in grass. `stepJustFinished` flag triggers encounter checks.
- **`world/camera.lua`** — Lerp follow (20%/frame) with `snapTo()` for instant positioning. `apply()`/`reset()` toggle the graphics draw offset.

### Zone System (`world/zone.lua` + `data/maps.lua`)

Maps are defined declaratively with 2-char tile codes in string rows:

```lua
registerZone("pallet_town", Zone({
    name = "Pallet Town",
    spawn = { x = 5, y = 6 },
    tileRows = { "Tr Tr Pa Pa Tr Tr", "Tr .  Pa Pa .  Tr" },
    npcs = { { gridX=10, gridY=12, name="Oak", dialog={...} } },
    encounters = { { species="rattata", minLevel=2, maxLevel=4, weight=40 } },
}))
```

Tile codes: `.`=Grass, `Pa`=Path, `Wa`=Wall, `Wt`=Water, `Tr`=Tree, `Dr`=Door, `Fn`=Fence, `TG`=Tall Grass, `Rf`=Roof, `Sg`=Sign, `Fl`=Flowers, `Sh`=Shore, `LW`=Lab Wall, `Mb`=Mailbox, `RL`=Roof Left, `RR`=Roof Right, `WW`=Wall Window.

Collision is auto-generated from tile types — no manual collision arrays. Globals: `zoneRegistry`, `zoneList`, `currentZone`. `switchZone(key)` changes zones. Zone methods: `spawnNPCs()`, `checkEncounter()`, `rollEncounter()`.

### 2-Bit Color System (`lib/shade.lua` + `world/tilefactory.lua`)

Simulates the Game Boy's 4-shade palette on Playdate's 1-bit display using ordered dithering patterns. `TileFactory` generates all tile types at runtime — no external tile PNGs needed. Tiles are authored as 16x16 four-shade text grids (`.`=white, `1`=LIGHT, `2`=DARK, `#`=black) and rendered at native 32x32 (TILE_SIZE): each authored pixel becomes a 2x2 block, but dither patterns apply in screen space so the dots stay fine. Every grid row must be exactly 16 chars (asserted at startup).

### Conventions

- Globals are localized with `<const>` for performance: `local gfx <const> = playdate.graphics`
- Pokemon sprites lazy-load from `Source/images/pokemon/{species}-front.png` and `{species}-back.png`
- Overworld sprites are in `Source/images/overworld/`
- Wild encounters only trigger on tall grass tiles with 15% chance per step
- Screen shake uses `playdate.display.setOffset()` — must be reset to (0,0) on battle exit
- The debug menu is accessible from the Playdate system menu during overworld state

## Tools

- **`tools/autopilot.py` + `Source/dev/autopilot.lua`** — Simulator automation bridge for visual iteration. The Lua side (simulator-only, no-op on device) polls `autopilot.txt` in the game's Data folder (`~/Developer/PlaydateSDK/Disk/Data/com.poc.pokemon/`) and acks with `autopilot-done.txt`. Commands: `move <dir> [n]`, `face <dir>`, `warp <gx> <gy>`, `wait <frames>`, `shot <name>`, `record <name> <n>` (per-frame capture), `encounters <on|off>`. Screenshots land in `tools/shots/`. Example: `python3 tools/autopilot.py "encounters off" "warp 5 8" "record walk 18" "move right 2" --strip walk` builds a magnified film strip plus frame-to-frame pixel diffs. Note: `warp` bypasses collision. `open -a` does not reliably reload a running Simulator and multiple instances can accumulate — they race for the command file and answer with stale builds. Before testing: `pkill -9 -f "Playdate Simulator"`, confirm none remain with `pgrep -f "MacOS/Playdate Simulator"`, then `make run` and wait ~4s.
- **`tools/generate_side_sprites.py`** — Python/Pillow generator for all player overworld sprites (and NPC alpha re-emit). Side stride frames are authored as text grids; every frame gets sprite alpha via border flood-fill: transparent outside the outline, opaque white inside the body. Run after editing and commit the regenerated PNGs in `Source/images/overworld/`.
- **`tools/verify_moves/`** — Python tool that validates move data in `battle/moves.lua` against PokeAPI. Run with `python tools/verify_moves/main.py`. Caches API responses locally. Generates per-species comparison reports in `tools/verify_moves/reports/`.
- **`tools/generate_tiles.py`** — Python/Pillow script that generates PNG versions of tiles for reference (not used at runtime; predates the in-game shade-grid tiles).
