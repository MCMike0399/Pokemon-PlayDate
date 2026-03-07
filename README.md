# Pokemon Blue — Playdate Edition

A reimagining of Pokemon Blue for the [Playdate](https://play.date) handheld. Not an emulator — a ground-up rebuild in Lua that keeps what made the original great (grid movement, turn-based battles, the world structure) and replaces what were Game Boy hardware limitations with designs that fit a 400x240 1-bit screen with a crank.

## Running it

Requires the [Playdate SDK](https://play.date/dev/).

```bash
# Build and open in Simulator
PLAYDATE_SDK_PATH=/path/to/PlaydateSDK make build
```

To install on a physical Playdate, connect via USB, then:

```bash
pdutil /dev/cu.usbmodem* datadisk
# wait ~3s for /Volumes/PLAYDATE to mount
cp -R PokemonPoC.pdx /Volumes/PLAYDATE/Games/
diskutil eject /Volumes/PLAYDATE
```

## Architecture

Top-level state machine (`StateMachine`) drives the game loop. Four states: `overworld`, `battle`, `dialog`, `debug`. Only one active at a time, with dialog compositing on top of the overworld.

```
Source/
  main.lua                 -- Game loop, state registration, encounter logic
  lib/
    oop.lua                -- Class/Mixin/Signal/Pool system (330 lines)
    shade.lua              -- 4-shade dithering system (Game Boy palette simulation)
    statemachine.lua       -- State machine with enter/exit/update/draw
  data/
    pokemon.lua            -- 156 species (Gen I-V), stats, types, movesets
    moves.lua              -- Move definitions with composable effects
    typechart.lua          -- 15-type effectiveness matrix
    maps.lua               -- Zone definitions (declarative tile codes)
  battle/
    battle.lua             -- Turn resolution, damage calc, status effects
    battleScene.lua        -- Battle UI rendering and input
    moves.lua              -- Move data and effect classes
  world/
    zone.lua               -- Zone class (declarative map definitions, auto-collision)
    tilefactory.lua        -- Runtime tile generation using Shade system
    overworld.lua          -- Tilemap setup and rendering
    player.lua             -- Grid movement with smooth interpolation
    camera.lua             -- Lerp follow + snap mode
    npc.lua                -- NPC manager, patrol, dialogue triggers
  ui/
    dialog.lua             -- Text box overlay
    menu.lua               -- Action menu (Fight/Bag/Pokemon/Run)
    debug.lua              -- Debug tools (spawn battles, heal, warp)
```

### OOP System (`lib/oop.lua`)

Custom class system that sits alongside Playdate's `CoreLibs/object`. Playdate's `class()` is used for sprite entities (Player, NPC). The custom `Class()` handles everything else: data models, battle logic, systems.

- `Class(name)` — creates a class registered as a global. `:extends(Parent)` for inheritance, `.super` for parent access
- `Mixin(name)` — composable traits mixed in with `:includes(M1, M2)`
- `Signal` — built-in mixin for event handling (`:on`, `:off`, `:once`, `:emit`)
- `Pool(cls, n)` — object recycling to manage GC pressure on hardware
- `:abstract("m1", "m2")` — enforces method implementation at instantiation

### Battle System

Battles follow the Gen I formula faithfully:

- **Damage**: `(((2 * level * crit / 5 + 2) * power * atk / def) / 50 + 2) * STAB * type * random`
- **STAB**: 1.5x when move type matches attacker type
- **Crits**: 1/16 chance, 2x multiplier, screen shake via `display.setOffset()`
- **Speed**: determines turn order, modified by stat stages and paralysis
- **Accuracy**: per-move check, `accuracy=0` bypasses (always hits)
- **Run**: Gen I formula with escalating chance per attempt, failed run gives enemy a free turn

**Composable move effects** — moves carry an `effects` array of objects that implement `:apply(attacker, defender)`. Three types:
- `StatChange(target, stat, stages)` — raise/lower atk/def/spc/spd
- `StatusEffect(target, status, chance)` — burn/poison/paralyze/sleep/freeze with proc chance
- `ConditionalEffect(condition, effect)` — apply effect only when condition passes

**Status conditions** are processed per-turn: poison/burn deal 1/8 max HP, paralysis has 25% skip chance and halves speed, sleep blocks 1-3 turns, freeze blocks with 20% thaw chance.

**Type effectiveness** is shown on the move select screen before confirming — an intentional design change from the original. The player sees super effective / not very effective / no effect icons next to each move.

### 2-Bit Color System (`lib/shade.lua` + `world/tilefactory.lua`)

The Game Boy renders 4 shades (white, light gray, dark gray, black) via its 2-bit palette. The Playdate only has 1-bit (black or white). The `Shade` class simulates the Game Boy's 4-shade palette using ordered dithering patterns:

| GB Shade   | 1-Bit Mapping               | Used For                        |
|------------|-----------------------------|---------------------------------|
| White      | Pure white                  | Window glass, highlights        |
| Light Gray | Pure white (clean ground)   | Ground, paths, wall backgrounds |
| Dark Gray  | 50% checkerboard dither     | Roofs, water                    |
| Black      | Solid black                 | Outlines, doors, tree canopy    |

Light gray maps to white rather than a dither pattern because at 16x16 tiles scaled 2x, dither dots become visually noisy across large ground areas. Contrast comes from structures (mortar lines, dark roofs, black trees) against clean white ground — matching how the original Game Boy Pallet Town reads at a glance.

`TileFactory` generates all 17 tile types at runtime using `Shade` and Playdate's drawing API — no external PNG files needed. Each tile is drawn at 16x16 and scaled 2x to 32x32. A companion Python script (`tools/generate_tiles.py`) can regenerate equivalent PNGs for reference.

### Overworld

Grid-based movement at 16x16 tiles. Player moves between tiles with smooth interpolation over 150ms. Camera follows with 20% lerp per frame, snaps instantly on map load.

Wild encounters trigger on tall grass tiles (tile ID 8) with a 15% chance per step. Encounter table is weighted — Rattata 40%, Pidgey 35%, Caterpie 15%, Weedle 10%, levels 2-5.

Iris-out transition (circle closing on player) plays before entering battle, drawn with a stencil mask.

NPCs have dialogue lines and optional battle data. After defeating a trainer NPC, they switch to post-battle dialogue.

### Performance

- 30 FPS target (`playdate.display.setRefreshRate(30)`)
- All globals localized with `<const>` where possible
- Incremental GC every frame (`collectgarbage("step", 1)`)
- Sprites lazy-loaded from disk to keep memory bounded
- Playdate's sprite system handles culling and draw order

## What works

- Tile-based overworld with NPCs and dialogue
- Random wild encounters in tall grass with iris-out transition
- Full turn-based battles (Gen I damage formula, STAB, type chart, crits, accuracy)
- PP system — moves cost PP and can run out
- Status conditions: poison, burn, paralysis, sleep, freeze
- Type effectiveness preview on move select
- 151 Pokemon with 1-bit front/back sprites
- 156 Pokedex entries (Gen I-V) with stats, types, movesets
- XP gain and leveling
- Zone system with debug teleportation between maps
- Debug menu: spawn any battle, heal, warp, zone select, toggle FPS/grid overlay
- Crank scrolls the Pokedex

## What's next

- Level scaling by route
- Trainer battles with multi-Pokemon parties
- Bag and item system
- Evolution chains
- Sound and music (synth-based)
- More maps and routes
- Saving to `playdate.datastore`

