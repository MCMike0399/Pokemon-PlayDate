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
    statemachine.lua       -- State machine with enter/exit/update/draw
  data/
    pokemon.lua            -- 156 species (Gen I-V), stats, types, movesets
    moves.lua              -- Move definitions with composable effects
    typechart.lua          -- 15-type effectiveness matrix
    maps.lua               -- Tile data, collision, encounter zones
  battle/
    battle.lua             -- Turn resolution, damage calc, status effects
    battleScene.lua        -- Battle UI rendering and input
    moves.lua              -- Move data and effect classes
  world/
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
- Debug menu: spawn any battle, heal, warp, toggle FPS/grid overlay
- Crank scrolls the Pokedex

## What's next

- Level scaling by route
- Trainer battles with multi-Pokemon parties
- Bag and item system
- Evolution chains
- Sound and music (synth-based)
- More maps and routes
- Saving to `playdate.datastore`

---

## Development Log

### Day 1 — Friday, March 6, 2026

**8:14 AM** — First commit. The full game skeleton lands in one shot: tile-based overworld with grid movement and collision, turn-based battle system with menu flow, NPC manager with dialogue triggers, dialog UI, camera with smooth follow, player with 4-direction walk animation, and a state machine tying it all together. Two starter Pokemon (Charmander, Squirtle) with front/back sprites. Seven tile types drawn. Map data with collision layer defined in code. 37 files, 1,153 lines. The game boots, you can walk around Pallet Town, talk to Oak, and fight the rival.

**9:25 AM** — Architecture refactor. Built a custom OOP library (`lib/oop.lua`, 330 lines) with `Class()`, `Mixin()`, `Signal` (observer pattern), and `Pool` (object recycling for GC management). Refactored battle, state machine, camera, NPC, player, dialog, and menu modules to use the new patterns. Pokemon data model expanded with proper stat structure (HP, ATK, DEF, SPC, SPD). Battle scene UI improved. 11 files changed, 492 insertions, 115 deletions.

**9:26 AM – 1:21 PM** — ~4 hour gap. No commits.

**1:21 PM** — Battle system overhaul. Implemented the full Gen I damage formula with level scaling, STAB (1.5x same-type bonus), type effectiveness from a complete 15-type chart (`data/typechart.lua`), critical hits (1/16 chance, 2x multiplier), and accuracy rolls. Built a composable move effect system — three effect classes (`StatChange`, `StatusEffect`, `ConditionalEffect`) that attach to moves and stack. Screen shake on critical hits via `playdate.display.setOffset()`. Gen I run formula with escalating escape chance per attempt; failed run gives the enemy a free turn. Added the Special stat, dual types, and status condition fields to the Pokemon data model. New moves: Ember, Bubble, Leer. Fixed player sprite having left/right walk images swapped. 7 files, +364 / -81 lines.

Design decision: type effectiveness icons now display on the move select screen BEFORE confirming. The original Game Boy version only told you after the attack landed.

**2:17 PM** — Major content expansion. Pokedex grows from 4 species to 156 (Gen I through Gen V), each with base stats, types, and level-up movesets. Move library expanded with power, accuracy, PP, type, category (physical/special), and effect definitions. Pokemon sprites now lazy-load from disk via `gfx.image.new("path")` at battle start — necessary because 151+ species can't all sit in memory on Playdate's 16MB RAM. Battle scene refactored: split into dedicated draw methods, 2-column move menu showing name + PP + type + effectiveness icon, bold font for names. Type chart completed to cover all 15 Gen I types. Added a debug menu (`ui/debug.lua`, 441 lines) accessible from the system menu — spawn any Pokemon battle, heal party, warp, toggle FPS/grid overlays. Crank scrolls the Pokedex list using `getCrankTicks()`. Player walk sprite handling improved. 10 files, +1,870 / -112 lines.

**2:33 PM** — PP system wired in — moves now cost PP on use and can run out. Status effect engine integrated into battle flow: poison and burn deal 1/8 max HP at end of turn, paralysis halves speed and has 25% chance to skip the turn entirely, sleep blocks action for 1-3 turns, freeze blocks with 20% thaw chance per turn. Pokemon objects get `usePP()`, `restorePP()`, and `fullHeal()` methods. `accuracy=0` now bypasses the accuracy check (always hits, for moves like Swift). Camera gets a snap mode for instant positioning on map load instead of lerping from (0,0). Overworld map transitions improved with proper spawn point handling. Debug menu gets heal and NPC reset actions. 10 files, +507 / -73 lines. Committed 16 minutes after the previous one.

**3:06 PM** — Art drop. Front and back sprites for all 151 Gen I Pokemon added as 1-bit PNGs sized for the Playdate display. 302 image files (Charmander and Squirtle sprites also redrawn to match the new style). Added a tall grass tile (`tallgrass.png`) and tile type ID 8 so wild encounters only trigger on designated grass tiles instead of any ground tile. Camera offset now properly resets when exiting battle (was leaving the screen shifted after a critical hit shake). 303 files changed.

**4:40 PM** — Final code commit. Tall grass tile type wired into the encounter check in `main.lua` — looks up the tile ID at the player's position and only rolls for encounters on ID 8. Map data updated with tall grass tiles placed in the world. Battle exit resets `playdate.display.setOffset(0, 0)`. Player now tracks `stepJustFinished` flag so encounters trigger at the right moment (after interpolation completes, not during). 4 files, +16 / -10 lines.

**4:47 PM** — Day 1 wrapped.

| Metric | Value |
|---|---|
| First commit | 8:14 AM |
| Last commit | 4:40 PM |
| Active coding time | ~8.5 hours |
| Commits | 7 |
| Lines of Lua | ~4,000 |
| Sprites | 302 (151 front + 151 back) + 10 overworld + 7 tiles |
| Pokedex entries | 156 species (Gen I–V) |
| Files in project | 319 |
| Bugs fixed mid-session | 3 (sprite L/R swap, camera offset leak, encounter trigger zone) |
