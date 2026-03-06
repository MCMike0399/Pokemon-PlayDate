# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Requires the [Playdate SDK](https://play.date/dev/). Set `PLAYDATE_SDK_PATH` before building.

```bash
# Build, clean, and open in Simulator
PLAYDATE_SDK_PATH=/path/to/PlaydateSDK make build

# Individual steps
make clean      # rm -rf PokemonPoC.pdx
make compile    # pdc Source PokemonPoC.pdx
make run        # open Simulator with PokemonPoC.pdx
```

There are no tests or linting tools configured.

## Architecture

Lua project for the Playdate handheld (400x240, 1-bit display, 30 FPS). All source is in `Source/`.

### Game Loop & State Machine

`main.lua` is the entry point. A single `StateMachine` instance drives the game loop with four states: **overworld**, **battle**, **dialog**, **debug**. Only one state is active at a time. State transitions pass arguments through `stateMachine:change(name, ...)`.

`playdate.update()` calls `stateMachine:update()` then `stateMachine:draw()` each frame, followed by incremental GC (`collectgarbage("step", 1)`).

### Two OOP Systems

- **Playdate's `class()`** (from `CoreLibs/object`) — used for sprite-based entities: `Player`, `NPC`
- **Custom `Class()`** (`lib/oop.lua`) — used for everything else: `Battle`, `StateMachine`, `Camera`, `Dialog`, `Menu`, `Pokemon`, etc. Registers classes as globals. Supports `:extends()`, `:includes()`, `:abstract()`, `Signal` mixin, and `Pool` for object recycling.

### Key Modules

- **`battle/battle.lua`** — Turn resolution engine. Gen I damage formula, STAB, type chart, crits, accuracy, status effects, run formula. Uses `Signal` mixin to emit `battleEnd` events.
- **`battle/battleScene.lua`** — Battle UI rendering and input handling. Draws HP bars, sprites, move select with type effectiveness preview.
- **`battle/moves.lua`** — Move definitions with composable effect system: `StatChange`, `StatusEffect`, `ConditionalEffect`. Move data stored in global `moveData` table keyed by camelCase name.
- **`data/pokemon.lua`** — 156 species definitions in global `pokemonData` table keyed by lowercase name. Contains `Pokemon` class with stat calculation, XP, PP, damage methods.
- **`data/typechart.lua`** — 15-type effectiveness matrix accessed via `TypeChart.getMatchup()`.
- **`data/maps.lua`** — Tile data, collision arrays, and `setupOverworld()`. Tile size is 16x16.
- **`world/player.lua`** — Grid movement with smooth interpolation (150ms). `stepJustFinished` flag triggers encounter checks.
- **`world/camera.lua`** — Lerp follow (20%/frame) with `snapTo()` for instant positioning. `apply()`/`reset()` toggle the graphics draw offset.

### Conventions

- Globals are localized with `<const>` for performance: `local gfx <const> = playdate.graphics`
- Pokemon sprites lazy-load from `Source/images/pokemon/{species}-front.png` and `{species}-back.png`
- Overworld sprites are in `Source/images/overworld/`
- Tile images are in `Source/images/tiles/`
- Wild encounters only trigger on tile ID 8 (tall grass) with 15% chance per step
- Screen shake uses `playdate.display.setOffset()` — must be reset to (0,0) on battle exit
- The debug menu is accessible from the Playdate system menu during overworld state
