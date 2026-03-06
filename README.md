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

**2:14 PM** — Repo created. First commit drops the full skeleton: overworld, battles, NPCs, dialogue, camera, player movement. 37 files, 1,153 lines. Two starter Pokemon with sprites. The game boots and runs.

**3:25 PM** — Architecture pass. Built the OOP library (330 lines) with classes, mixins, signals, and object pools. Refactored all modules to use it. Battle scene and state machine cleaned up. The codebase now has a consistent pattern.

**3:26 – 7:21 PM** — Gap in commits. Probably lunch and some debugging that didn't make it to a commit.

**7:21 PM** — Battle system gets real. Gen I damage formula with STAB, type effectiveness, crits, accuracy. Composable move effect system. Screen shake on crits. Run formula with escalating escape chance. Fixed player sprite having left/right swapped.

Type effectiveness icons now show on the move select screen before confirming — the original told you after. We have the screen space.

**8:17 PM** — Pokedex grows to 156 species (Gen I-V). Move library expanded. Sprites lazy-load from disk. Battle UI gets a two-column move layout. Debug menu added. Crank scrolls the Pokedex. 1,870 lines in one commit.

**8:33 PM** — PP system. Status effects: poison/burn tick damage, paralysis speed halving and turn skip, sleep/freeze with per-turn checks. Camera snap mode for map transitions. 507 lines, 16 minutes after the last commit.

**9:06 PM** — All 151 Gen I Pokemon sprites added — front and back, 1-bit. 302 PNGs. Tall grass tile type added so encounters only trigger where they should.

**10:40 PM** — Last commit. Camera resets after battle, step tracking for encounters. 4 files, 16 lines. Clean.

**10:47 PM** — Day 1 done.

| Metric | Value |
|---|---|
| Time | ~8.5 hours |
| Commits | 13 |
| Lines | ~4,400 |
| Sprites | 302 |
| Species | 156 |
| Bugs fixed mid-session | 3 |
