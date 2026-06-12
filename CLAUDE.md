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

`main.lua` is the entry point: it imports everything, builds a `GameContext` (global `game`: root machine, camera, npcManager, player, playerPokemon, transition log), registers the four top-level states, and runs `machine:update()` → `machine:handleInput()` → `machine:draw()` each frame, followed by incremental GC (`collectgarbage("step", 1)`).

`lib/statemachine.lua` provides `State` (lifecycle: `enter/exit/pause/resume/update/draw/handleInput`) and `StateMachine` — a **stack** machine. `change(name, ...)` replaces the stack; `push(name, ...)`/`pop(...)` overlay states. Every stacked state updates and draws bottom→top each frame, but **only the top state receives `handleInput()`** — so dialog and the debug menu are pushed over the overworld and the world keeps animating beneath them. The machine emits a `"changed"` signal (kind, from, to); `GameContext` records the last 12 transitions for triage (`gamestate` autopilot command prints them).

Top-level states (classes in `Source/game/`):
- **`OverworldState`** — builds the world, owns a *nested* `StateMachine` with substates `explore` (movement/NPC/encounters) and `irisOut` (battle transition). Saves the player's position on exit and restores it when re-entering the same zone (pass `{ respawn = true }` to force the zone spawn — used by blackout and zone switches).
- **`DialogState`** — pushed overlay; pops itself when the last line is dismissed, then runs its onComplete callback (trainer dialogs chain into `change("battle", ...)`).
- **`BattleState`** — owns `Battle` + `BattleScene`; on `battleEnd`, victory/run returns to the saved overworld position, defeat full-restores the pokemon and respawns at zone spawn.
- **`DebugState`** — pushed overlay around `DebugMenu`; in-menu actions consumed per-frame in `update()`, menu-closing actions (wild battle, zone switch) handled in its onClose: pop, then change.

Trainer NPC "defeated" flags survive world rebuilds: `NPC:markInteracted()` mirrors the flag onto the zone's npc def, and `Zone:spawnNPCs()` restores it.

### Two OOP Systems

- **Playdate's `class()`** (from `CoreLibs/object`) — used for sprite-based entities: `Player`, `NPC`
- **Custom `Class()`** (`lib/oop.lua`) — used for everything else: `Battle`, `StateMachine`, `Camera`, `Dialog`, `Menu`, `Pokemon`, the game states, the battle DSL, etc. Registers classes as globals. Supports `Class(name, parent)` or `:extends()`, `:includes()`, `:abstract()`, `Signal` mixin (re-entrancy-safe emit), and `Pool` for object recycling.

### Import Order (in main.lua)

Order matters. Key constraints:
1. `lib/oop.lua` first (provides `Class()` used everywhere), then `lib/statemachine.lua` (provides `State` subclassed by game states and battle phases)
2. `lib/shade.lua` and `world/tilefactory.lua` before `world/overworld.lua` (tiles generated at import time)
3. `world/zone.lua` before `data/maps.lua` (Zone class needed for `registerZone()` calls)
4. `data/pokemon.lua` before `data/maps.lua` (encounters reference Pokemon class)
5. `battle/dsl.lua` before `battle/moves.lua` (move data instantiates DSL effects at import time)
6. `game/*` after the modules their states instantiate (Dialog, Battle, DebugMenu...)

### Key Modules

- **`battle/dsl.lua`** — Composable battle DSL (inspired by Christopher Okhravi's "Rebuilding Pokémon with OOP"): Targets (`ATTACKER`/`DEFENDER` selectors), lazy Numbers (`Exactly`, `Between`, `Weighted`, `Product`, `MaxHPOf`...), Conditions (`Chance`, `Not`, `AllOf`, battler predicates lifted via `For(target, cond)`), Effects (`ModifyStat`, `ApplyStatus`, `DirectDamage`, `Heal`, combinators `EffectSeq`/`When`/`NoEffect`). Effects implement `:apply(battle)`, resolve targets through the battle's current attacker/defender orientation, and narrate themselves with `battle:say(...)`. `ApplyStatus` knows Gen V type immunities (fire/burn, ice/freeze, poison+steel/poison), routes `flinch`/`confuse` to volatile fields, and seeds the Gen V 1-3 turn sleep counter.
- **`battle/battle.lua`** — Rules engine, **Gen V (B2W2) mechanics throughout**: damage = `(2L/5+2)·power·A/D / 50 + 2` then modifiers in order crit ×2 → random 85-100% → STAB 1.5 → type → burn-halves-physical (floor each step); per-move physical/special split; crits (1/16) ignore stages unfavorable to the attacker; accuracy/evasion stages (3-based multipliers) in `checkAccuracy`; move priority brackets then effective speed (paralysis = speed/4) for turn order; multi-hit 2-5 distribution (1/3, 1/3, 1/6, 1/6); drain/recoil as % of damage dealt; flinch and confusion volatiles (1-4 turns, 50% 40-power typeless self-hit); sleep counts down 1-3 and the pokemon acts on waking; Gen III-V run formula. Owns a nested `StateMachine` with phases **command** (menus), **script** (a coroutine resolves the round; `battle:say()` yields until A is pressed — turn logic is linear, no callback pyramids), **ended** (A emits the `battleEnd` signal). `battle:setDirection(side)` flips attacker/defender per half-turn.
- **`battle/battleScene.lua`** — Battle UI rendering and input handling. Draws HP bars, sprites, move select with type effectiveness preview. Queries `battle:isAwaitingCommand()` to decide menus vs message text.
- **`battle/moves.lua`** — GENERATED by `tools/generate_gen5_data.py` (do not hand-edit move data). Global `moveData` table keyed by camelCase name: B2W2-resolved power/accuracy/pp/type/priority, per-move damage class, drain/recoil, multi-hit ranges, and effects composed from DSL objects, e.g. `When(Chance(30), ApplyStatus(DEFENDER, "paralyze"))`.
- **`data/pokemon.lua`** — 151 species in global `pokemonData` keyed by lowercase name, with **Gen V base stats** (SpA/SpD split: `baseSpA`, `baseSpD`, `baseSpe`) and `baseExp` yields — species stat blocks are regenerated by `tools/generate_gen5_data.py`. Contains the `Pokemon` class: stats with `spa/spd/spe`, stat stages incl. `acc`/`eva`, volatiles (`confusion`, `flinched`), B2W2 flat XP formula `(baseExp · level) / 7`.
- **`data/typechart.lua`** — Gen V 17-type effectiveness matrix accessed via `TypeChart.getMatchup()`.
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

- **`tools/autopilot.py` + `Source/dev/autopilot.lua`** — Simulator automation bridge for visual iteration. The Lua side (simulator-only, no-op on device) polls `autopilot.txt` in the game's Data folder (`~/Developer/PlaydateSDK/Disk/Data/com.poc.pokemon/`) and acks with `autopilot-done.txt`. Overworld commands: `move <dir> [n]`, `face <dir>`, `warp <gx> <gy>` (aborts with "interrupted" if a battle yanks the state away mid-walk). Any-state commands: `wait <frames>`, `shot <name>`, `record <name> <n>` (per-frame capture), `encounters <on|off>`, `press <a|b|up|down|left|right>` (injects a one-frame synthetic button press by wrapping `playdate.buttonJustPressed/IsPressed` — drives dialogs and battle menus), `mash <btn> <n> [gap]` (n presses every gap frames, default 16 — message boxes need >10 frames between presses), `battle <species> <level>` (jump straight into a wild battle), `gamestate` (state stack, battle phase + message, player pos, recent transitions — first stop for triage), `seed <n>` (deterministic RNG), `debug <open|close>`, `pokemon` (player pokemon hp/lv/xp/status). Screenshots land in `tools/shots/`. Example: `python3 tools/autopilot.py "encounters off" "warp 5 8" "record walk 18" "move right 2" --strip walk` builds a magnified film strip plus frame-to-frame pixel diffs. A full scripted battle: `"seed 42" "battle rattata 3" "wait 30" "press a"` … then `"press a"` for FIGHT, `"press a"` for move 1, `"mash a 10 16"` through the round. Note: `warp` bypasses collision. `open -a` does not reliably reload a running Simulator and multiple instances can accumulate — they race for the command file and answer with stale builds. Before testing: `pkill -9 -f "Playdate Simulator"`, confirm none remain with `pgrep -f "MacOS/Playdate Simulator"`, then `make run` and wait ~4s. The Simulator window grabs keyboard focus on launch — stray keystrokes land in the game and look like phantom input in scripted runs.
- **`tools/generate_side_sprites.py`** — Python/Pillow generator for all player overworld sprites (and NPC alpha re-emit). Side stride frames are authored as text grids; every frame gets sprite alpha via border flood-fill: transparent outside the outline, opaque white inside the body. Run after editing and commit the regenerated PNGs in `Source/images/overworld/`.
- **`tools/verify_moves/`** — Python tool that validates move data in `battle/moves.lua` against PokeAPI. Run with `python tools/verify_moves/main.py`. Caches API responses locally. Generates per-species comparison reports in `tools/verify_moves/reports/`.
- **`tools/generate_tiles.py`** — Python/Pillow script that generates PNG versions of tiles for reference (not used at runtime; predates the in-game shade-grid tiles).
- **`tools/generate_gen5_data.py`** — Regenerates `battle/moves.lua` (whole file) and the species stat blocks in `data/pokemon.lua` from cached Gen V sources (`tools/gen5cache/`): PokeAPI CSVs (`move_changelog` resolves values as of version group 14 = B2W2) and Pokémon Showdown's pokedex + gen8→gen5 mod chain (Gen V base stats/types). Species movesets and the Pokemon class are preserved. Run after adding moves or species; delete `tools/gen5cache/` to re-fetch.
