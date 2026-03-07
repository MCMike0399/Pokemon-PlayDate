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
    maps.lua               -- Zone definitions (declarative tile codes)
  battle/
    battle.lua             -- Turn resolution, damage calc, status effects
    battleScene.lua        -- Battle UI rendering and input
    moves.lua              -- Move data and effect classes
  world/
    zone.lua               -- Zone class (declarative map definitions, auto-collision)
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

---

## Development Log

### Day 1 — Mar 6, 2026

Built the entire game skeleton in one session (8:14 AM – 4:47 PM, 7 commits).

**Core systems:** Tile-based overworld (grid movement, collision, camera with lerp follow), turn-based battle engine (Gen I damage formula, STAB, 15-type chart, crits, accuracy, run formula), state machine (overworld/battle/dialog/debug), NPC manager with dialogue and trainer battles, iris-out battle transition.

**Battle depth:** Composable move effects (`StatChange`, `StatusEffect`, `ConditionalEffect`), PP system, status conditions (poison/burn/paralysis/sleep/freeze with per-turn processing), screen shake on crits. Type effectiveness shown on move select before confirming (intentional design departure from the original).

**Content:** 156 Pokedex entries (Gen I–V) with stats/types/movesets, 151 Pokemon with 1-bit front/back sprites (lazy-loaded from disk), debug menu (spawn battles, heal, warp, FPS/grid overlays).

**Design decision:** Type effectiveness preview on the move select screen. The original GB version only told you after the attack landed.

| Metric | Value |
|---|---|
| Commits | 7 |
| Lines of Lua | ~4,000 |
| Sprites | 302 Pokemon + 10 overworld + 7 tiles |
| Pokedex | 156 species (Gen I–V) |
| Bugs fixed | 3 (sprite L/R swap, camera offset leak, encounter trigger timing) |

### Day 2 — Mar 6, 2026

**Walk animation overhaul.** Side-facing sprites were broken — the "standing" frame was actually the GB walking frame, and the "walk" frame was a 2px-shifted copy. Compared against the [pokered decompilation](https://github.com/pret/pokered) to get the correct frames. Built a Python/Pillow sprite generator (`tools/generate_side_sprites.py`). Right-facing sprites now generated at runtime by flipping left. Walk cycle split into walk1/walk2 tables with proper "legs apart → legs together" beat. Fixed duplicate `nidoran` keys in Pokedex.

### Day 3 — Mar 6, 2026

**Zone system and Pallet Town.** Built a declarative zone architecture inspired by Dart/Flutter's widget syntax.

**Zone class (`world/zone.lua`)** — Each zone is a self-contained `Zone({...})` object defining everything in one place: tile map (readable 2-char string codes like `"Tr Pa Wa ."`), NPCs, encounters, warps, and spawn point. Collision is auto-generated from tile types — no more maintaining parallel number arrays. `registerZone()` / `switchZone()` API for the zone registry.

**Pallet Town (20x18)** — Faithful Gen I recreation: Red's house and Blue's house with brick walls and dithered roofs, Oak's Laboratory with windowed lab walls, path network wrapping around the lab, tall grass encounter zones at the Route 1 transition, shore/water for Route 21, fences, signs, mailboxes, flower beds.

**New tiles (9–14):** Roof (50% checkerboard dither), Sign, Flowers, Shore, Lab Wall (brick + window), Mailbox. All 14 tiles drawn in 1-bit Game Boy style — researched actual GB palette mapping (4 shades → 1-bit via dithering density). Multiple iterations to get the right balance: v1-v2 had too much detail (noisy grass, heavy patterns), v3 stripped too much (walls looked like lined paper), v4 found the sweet spot.

**Debug menu** gains "Zones" submenu to teleport between zones. Warp presets now read directly from zone data. OOP lib gets flattened method lookup for O(1) dispatch.
