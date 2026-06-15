# Pokemon Blue — Playdate Edition

A reimagining of Pokemon Blue for the [Playdate](https://play.date) handheld. Not an emulator — a ground-up rebuild in Lua that keeps what made the original great (grid movement, turn-based battles, the world structure) and replaces what were Game Boy hardware limitations with designs that fit a 400x240 1-bit screen.

> **Two generations, on purpose.** The battle engine, move data, base stats, and type chart all run **Gen V (Black 2 / White 2) mechanics**. The opening — Oak, rival BLUE, the Kanto starters, the near-verbatim dialogue — recreates the **Gen 1 (Red/Blue) Pallet Town intro**. So a Lv5 starter knowing only Tackle/Growl is the Gen V level-1 learnset, not a Gen 1 quirk.

## Running it

Requires the [Playdate SDK](https://play.date/dev/). Set `PLAYDATE_SDK_PATH` before building.

```bash
# Build, clean, and open in the Simulator
PLAYDATE_SDK_PATH=/path/to/PlaydateSDK make build

# Individual steps
make clean      # rm -rf PokemonPoC.pdx
make compile    # pdc Source PokemonPoC.pdx
make run        # open the .pdx in the Simulator
```

To install on a physical Playdate, connect it via USB (unlocked) and run:

```bash
make deploy     # compile, enter data-disk mode, copy the .pdx, eject & reboot
```

`make deploy` auto-detects the device at `/dev/cu.usbmodemPD*`, waits for `/Volumes/PLAYDATE` to mount (up to 30s), copies the bundle, and ejects — the Playdate reboots itself.

## Architecture

A hierarchical, stack-based state machine (`lib/statemachine.lua`) drives the game loop. Top-level states are classes in `Source/game/`: `OverworldState` (with its own substate machine: `explore`, `irisOut`, `doorWarp`), `BattleState`, plus `DialogState` and `DebugState`, which are *pushed* onto the stack as overlays — the world keeps animating and drawing beneath them while input routes to the top state only. The battle runs the same `StateMachine` class internally for its phases (`command`, `script`, `ended`).

```
Source/
  main.lua                 -- Imports, state registration, the update loop
  game/
    context.lua            -- GameContext: machine/camera/player/pokemon + transition log
    story.lua              -- Gen 1 intro questline (linear stage machine)
    overworldState.lua     -- Overworld play (explore + iris-out + door-warp substates)
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
    spritefactory.lua      -- Runtime overworld-sprite generation (masked 4-shade grids)
    sprites/               -- Per-character sprite grids (red/oak/rival/mom/daisy)
    overworld.lua          -- Tilemap setup, animation, and rendering
    player.lua             -- Grid movement with smooth interpolation
    camera.lua             -- Lerp follow + snap mode
    npc.lua                -- NPC entity, dialogue triggers, persistent trainer flags
  ui/
    dialog.lua             -- Text box widget
    menu.lua               -- Battle menu widget
    debug.lua              -- Debug tools (spawn battles, heal, warp, skip/reset intro)
  dev/
    autopilot.lua          -- Simulator automation bridge (no-op on device)
```

### OOP System (`lib/oop.lua`)

Custom class system that sits alongside Playdate's `CoreLibs/object`. Playdate's `class()` is used for sprite entities (Player, NPC). The custom `Class()` handles everything else: data models, battle logic, systems.

- `Class(name)` — creates a class registered as a global. `:extends(Parent)` for inheritance, `.super` for parent access
- `Mixin(name)` — composable traits mixed in with `:includes(M1, M2)`
- `Signal` — built-in mixin for event handling (`:on`, `:off`, `:once`, `:emit`), re-entrancy-safe
- `Pool(cls, n)` — object recycling to manage GC pressure on hardware
- `:abstract("m1", "m2")` — enforces method implementation at instantiation

### Intro Questline (`game/story.lua`)

A new game boots in Red's bedroom with Oak's monologue. The global `Story` runs the Gen 1 "first minutes" as a tiny linear stage machine:

`pre_oak` (walking into the Route 1 grass triggers Oak's "Don't go out!" and a fade into the lab) → `lab_greet` → `choose` (press A on a Poké Ball tile to pick a starter; the three balls sit in Gen 1 order — **Charmander, Squirtle, Bulbasaur** — and BLUE takes the type-advantaged counter pick) → `pre_rival` (heading for the lab exit triggers BLUE's challenge) → `rival_fight` → `goodbye` ("Smell you later!", BLUE leaves) → `done` (free play).

The intro dialogue is kept close to the verbatim Red/Blue text. Starters are granted their **Gen V level-1 moveset only** (the first two moves), so the rival fight stays a low-level chip-damage duel. Until a starter is chosen the player has no Pokémon, so wild encounters and battles are suppressed. The debug menu (and autopilot `intro` command) can **Skip** straight to free play or **Reset** back to the bedroom.

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
- **XP**: B2W2 flat formula `(baseExp · defeatedLevel) / 7` with real base-experience yields
- **Run**: Gen III–V formula `(A·128/B + 30·attempts) mod 256`; a failed run gives the enemy a free turn (and trainer battles refuse running outright)

Move data (B2W2 power/accuracy/PP/type/priority) and Gen V base stats are regenerated by `tools/generate_gen5_data.py`, which resolves historical values through PokeAPI's move changelog and Pokémon Showdown's generation mods.

**Coroutine-scripted turns** — turn resolution runs as a coroutine inside the battle's `script` phase. `battle:say(msg)` yields until the player confirms, so the whole round reads as linear code (status gates → accuracy → damage → effectiveness/crit messages → effects → faint/XP) instead of nested callbacks.

**Composable move effects (`battle/dsl.lua`)** — moves carry an `effects` array of DSL objects that implement `:apply(battle)` and narrate themselves with `battle:say()`. The battle carries directionality (attacker/defender flip each half-turn), so effects are written once, not per side:
- Targets: `ATTACKER` / `DEFENDER` selectors resolved against the battle
- Numbers: lazy values — `Exactly(n)`, `Between(min,max)`, `Weighted{...}`, `Product/Sum/Quotient`, `MaxHPOf(target)`, `LevelOf(target)`...
- Conditions: `Chance(pct)`, `Not/AllOf/AnyOf`, battler predicates (`HasType`, `HasStatus`) lifted with `For(target, cond)`
- Effects: `ModifyStat`, `ApplyStatus`, `DirectDamage`, `Heal`, combinators `EffectSeq`, `When(cond, effect)`, `NoEffect`

```lua
-- e.g. a 30% paralysis rider would be:
When(Chance(30), ApplyStatus(DEFENDER, "paralyze"))
```

**Status conditions** are processed per-turn: poison/burn deal 1/8 max HP, paralysis has 25% skip chance and halves speed, sleep blocks 1–3 turns, freeze blocks with 20% thaw chance.

**Type effectiveness** is shown on the move-select screen before confirming — an intentional design change from the original. The player sees super effective / not very effective / no effect icons next to each move.

### 2-Bit Color System (`lib/shade.lua` + `world/tilefactory.lua`)

The Game Boy renders 4 shades (white, light gray, dark gray, black) via its 2-bit palette. The Playdate only has 1-bit (black or white). The `Shade` class simulates the Game Boy's 4-shade palette using ordered dithering patterns:

| GB Shade   | 1-Bit Mapping               | Used For                        |
|------------|-----------------------------|---------------------------------|
| White      | Pure white                  | Window glass, highlights        |
| Light Gray | Pure white (clean ground)   | Ground, paths, wall backgrounds |
| Dark Gray  | 50% checkerboard dither     | Roofs, water                    |
| Black      | Solid black                 | Outlines, doors, tree canopy    |

Light gray maps to white rather than a dither pattern because at 16x16 tiles scaled 2x, dither dots become visually noisy across large ground areas. Contrast comes from structures (mortar lines, dark roofs, black trees) against clean white ground — matching how the original Game Boy Pallet Town reads at a glance.

`TileFactory` generates every tile type at runtime using `Shade` and Playdate's drawing API — no external tile PNGs needed. Each tile is authored as a 16x16 four-shade text grid and rendered at native 32x32. Water, shore, and flowers animate from a shared Gen 1 global-animation heartbeat.

### Overworld Sprites (`world/spritefactory.lua` + `world/sprites/`)

The companion to `TileFactory`: **player and NPC sprites are generated at runtime too** — there are no overworld PNGs in the repo. Each character is a set of 16x16 four-shade grids (`world/sprites/red.lua`, `oak.lua`, `rival.lua`, `mom.lua`, `daisy.lua`), rendered to 32x32 and given a transparent alpha mask via a cell-level border flood-fill (the outside-the-outline `.` cells become transparent; the sealed body stays opaque). Right-facing frames are the left frame flipped. The NPC grids are derived deterministically from the pokered Gen 1 overworld sprites by `tools/generate_overworld_sprites.py`; RED's frames are hand-tuned. NPCs are directional and turn to face the player on interaction.

### Overworld & Zones (`world/zone.lua` + `data/maps.lua`)

Maps are defined declaratively with 2-char tile codes in string rows; collision is auto-generated from tile types (no manual collision arrays). Grid movement interpolates smoothly over **8 frames per step (~0.27s at 30 FPS)**, with Gen 1 walk cadence (stride first half of the step, stand the second, lead foot alternating each step). The camera follows with a 20% lerp per frame and snaps instantly on map load.

Wild encounters trigger on tall-grass tiles (tile ID 8) at a 15% chance per step (`encounterRate`), from a per-zone weighted table. Interiors carry no encounters or tall grass, so no battles fire indoors. An iris-out transition (a circle closing on the player, drawn with a stencil mask) plays before each battle.

**Doors** come in two flavors, both distinct from debug warp presets:
- **Step doors** fire when a step finishes on the tile (outside house doors, stairs) — Gen 1 stairs re-trigger on stepping back on.
- **Edge doors** are Gen 2/3-style exit gates: landing on the mat does nothing; the warp fires when you stand on it and *walk into the room boundary*. A bobbing **exit arrow** appears in the void tile past the door to show you can leave.

Pallet Town has four interiors — Red's house (Mom; stairs to the 2F bedroom), Blue's house (Daisy), and Oak's lab (Oak, plus BLUE during the intro). A door warp does a GB-style shade fade to black, then loads the target zone. After the intro, a rematch BLUE waits outside his house.

### Performance

- 30 FPS target (`playdate.display.setRefreshRate(30)`)
- All globals localized with `<const>` where possible
- Incremental GC every frame (`collectgarbage("step", 1)`)
- Pokémon battle sprites lazy-loaded from disk; overworld sprites generated once at startup
- Playdate's sprite system handles culling and draw order

## Tooling

- **`tools/autopilot.py` + `Source/dev/autopilot.lua`** — Simulator automation bridge for visual iteration (no-op on device). Scripts movement, dialog/battle input, screenshots and film strips, deterministic RNG, the intro questline, and an `atlas` contact sheet of every generated tile and sprite frame. First stop for triage is the `gamestate` command (state stack, battle phase, zone, story stage, player position, recent transitions).
- **`tools/generate_gen5_data.py`** — Regenerates `battle/moves.lua` and the species stat blocks in `data/pokemon.lua` from cached Gen V sources (PokeAPI CSVs resolved to B2W2 + Pokémon Showdown's generation mods).
- **`tools/generate_overworld_sprites.py`** — Generates the NPC sprite grids in `world/sprites/` from the pokered Gen 1 overworld sprites.
- **`tools/verify_moves/`** — Validates move data against PokeAPI and writes per-species comparison reports.

## What works

- Gen 1 Pallet Town intro: Oak's monologue, the "Don't go out!" stop, starter choice, and the rival battle
- Tile-based overworld with directional NPCs and dialogue (runtime-generated tiles and sprites)
- Enterable interiors (houses, Oak's lab) with step/edge doors, exit arrows, and shade-fade warps
- Random wild encounters in tall grass with iris-out transition
- Full turn-based battles on Gen V (B2W2) mechanics: damage formula, STAB, 17-type chart, crits, accuracy/evasion
- Physical/special split, multi-hit, drain/recoil, priority + effective-speed turn order
- PP system — moves cost PP and can run out
- Status conditions: poison, burn, paralysis, sleep, freeze, plus flinch/confusion volatiles
- Type effectiveness preview on move select
- 151 Pokémon (Gen I dex) with Gen V base stats/types, movesets, 1-bit front/back sprites, XP and leveling
- Trainer battles (the rival), with persistent "defeated" flags across world rebuilds
- Debug menu: spawn any battle, heal, warp, zone select, skip/reset intro, toggle FPS/grid overlay

## What's next

- Level scaling by route
- Trainer battles with multi-Pokémon parties
- Bag and item system
- Evolution chains
- Sound and music (synth-based)
- More maps and routes
- Saving to `playdate.datastore`
