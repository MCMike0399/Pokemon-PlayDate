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

A hierarchical, stack-based state machine (`lib/statemachine.lua`) drives the game loop. Top-level states are classes in `Source/game/`: `OverworldState` (with its own substate machine: `explore`, `irisOut`), `BattleState`, plus `DialogState` and `DebugState`, which are *pushed* onto the stack as overlays — the world keeps animating and drawing beneath them while input routes to the top state only. The battle runs the same `StateMachine` class internally for its phases (`command`, `script`, `ended`).

```
Source/
  main.lua                 -- Imports, state registration, the update loop
  game/
    context.lua            -- GameContext: machine/camera/player/pokemon + transition log
    overworldState.lua     -- Overworld play (explore + iris-out substates)
    dialogState.lua        -- Text box overlay (pushed over the overworld)
    battleState.lua        -- Battle lifecycle, blackout/respawn handling
    debugState.lua         -- Debug menu overlay (pushed over the overworld)
  lib/
    oop.lua                -- Class/Mixin/Signal/Pool system
    shade.lua              -- 4-shade dithering system (Game Boy palette simulation)
    statemachine.lua       -- State + StateMachine (stack, push/pop, nesting, signals)
  data/
    pokemon.lua            -- 151 species with Gen V stats/types + Pokemon class
    typechart.lua          -- Gen V 17-type effectiveness matrix
    maps.lua               -- Zone definitions (declarative tile codes)
  battle/
    dsl.lua                -- Composable battle DSL: Targets, Numbers, Conditions, Effects
    battle.lua             -- Rules engine: Gen V math, coroutine-scripted turns + phases
    battleScene.lua        -- Battle UI rendering and input
    moves.lua              -- B2W2 move data (generated, composed from DSL effects)
  world/
    zone.lua               -- Zone class (declarative map definitions, auto-collision)
    tilefactory.lua        -- Runtime tile generation (authored 4-shade grids)
    overworld.lua          -- Tilemap setup and rendering
    player.lua             -- Grid movement with smooth interpolation
    camera.lua             -- Lerp follow + snap mode
    npc.lua                -- NPC manager, dialogue triggers, persistent trainer flags
  ui/
    dialog.lua             -- Text box widget
    menu.lua               -- Battle menu widget
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

Battles follow Gen V (Black 2 / White 2) mechanics:

- **Damage**: `(2·L/5 + 2) · power · A/D / 50 + 2`, then modifiers in Gen V order with flooring at each step: crit ×2 → random 85–100% → STAB ×1.5 → type chart → burn halves physical
- **Physical/special split**: per move (Gen IV+), resolved from PokeAPI damage classes — not the old per-type rule
- **Stats**: full Gen V six-stat spread (Atk/Def/SpA/SpD/Spe) with stage multipliers; accuracy/evasion stages use the 3-based table
- **Crits**: 1/16 chance, ×2, ignore stat stages unfavorable to the attacker; screen shake via `display.setOffset()`
- **Turn order**: move priority brackets first, then effective speed (paralysis quarters speed)
- **Multi-hit**: 2–5 hit moves use the Gen V distribution (2/3 hits: 1/3 each; 4/5 hits: 1/6 each), one accuracy roll, per-hit damage and crit rolls
- **Drain/recoil**: % of damage dealt (Absorb drains 50%, Double-Edge recoils 33%, ...)
- **Volatiles**: flinch (one turn) and confusion (1–4 turns, 50% to self-hit with a 40-power typeless physical) live alongside major status; sleep counts down 1–3 turns and the pokemon attacks the turn it wakes
- **Status immunities**: fire can't be burned, ice can't be frozen, poison/steel can't be poisoned
- **XP**: B2W2 flat formula `(baseExp · defeatedLevel) / 7` with real base experience yields
- **Run**: Gen III–V formula `(A·128/B + 30·attempts) mod 256`, failed run gives the enemy a free turn

Move data (B2W2 power/accuracy/PP/type/priority) and Gen V base stats are regenerated by `tools/generate_gen5_data.py`, which resolves historical values through PokeAPI's move changelog and Pokémon Showdown's generation mods.

**Coroutine-scripted turns** — turn resolution runs as a coroutine inside the battle's `script` phase. `battle:say(msg)` yields until the player confirms, so the whole round reads as linear code (status gates → accuracy → damage → effectiveness/crit messages → effects → faint/XP) instead of nested callbacks.

**Composable move effects (`battle/dsl.lua`)** — moves carry an `effects` array of DSL objects that implement `:apply(battle)` and narrate themselves with `battle:say()`. The battle carries directionality (attacker/defender flip each half-turn), so effects are written once, not per side:
- Targets: `ATTACKER` / `DEFENDER` selectors resolved against the battle
- Numbers: lazy values — `Exactly(n)`, `Between(min,max)`, `Weighted{...}`, `Product/Sum/Quotient`, `MaxHPOf(target)`, `LevelOf(target)`...
- Conditions: `Chance(pct)`, `Not/AllOf/AnyOf`, battler predicates (`HasType`, `HasStatus`) lifted with `For(target, cond)`
- Effects: `ModifyStat`, `ApplyStatus`, `DirectDamage`, `Heal`, combinators `EffectSeq`, `When(cond, effect)`, `NoEffect`

```lua
-- e.g. BODY SLAM with a 30% paralysis rider would be:
When(Chance(30), ApplyStatus(DEFENDER, "paralyze"))
```

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

`TileFactory` generates every tile type at runtime using `Shade` and Playdate's drawing API — no external PNG files needed. Each tile is authored as a 16x16 four-shade text grid and rendered at native 32x32.

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

- Tile-based overworld with NPCs and dialogue (procedural or authentic ROM tiles)
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

