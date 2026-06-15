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

> **Generations — read this first.** The game runs **Gen V (B2W2) battle mechanics, move data, and base stats** throughout (battle engine, `moves.lua`, `pokemon.lua`, type chart). The opening **story and dialogue** recreate the **Gen 1 (Red/Blue) Kanto intro** (Oak, rival BLUE, Kanto starters, verbatim R/B text). So: when adding/changing moves, stats, or battle rules → target **Gen V**; when adding intro flow or dialogue → target **Gen 1**. A "wrong" move at low level (e.g. a Lv5 Charmander knowing Ember/Smokescreen) is a Gen-V-learnset-ordering issue, not a Gen 1 question — see the level-1-moves note in the Intro Questline section.

### Game Loop & State Machine

`main.lua` is the entry point: it imports everything, builds a `GameContext` (global `game`: root machine, camera, npcManager, player, playerPokemon, transition log), registers the four top-level states, and runs `machine:update()` → `machine:handleInput()` → `machine:draw()` each frame, followed by incremental GC (`collectgarbage("step", 1)`).

`lib/statemachine.lua` provides `State` (lifecycle: `enter/exit/pause/resume/update/draw/handleInput`) and `StateMachine` — a **stack** machine. `change(name, ...)` replaces the stack; `push(name, ...)`/`pop(...)` overlay states. Every stacked state updates and draws bottom→top each frame, but **only the top state receives `handleInput()`** — so dialog and the debug menu are pushed over the overworld and the world keeps animating beneath them. The machine emits a `"changed"` signal (kind, from, to); `GameContext` records the last 12 transitions for triage (`gamestate` autopilot command prints them).

Top-level states (classes in `Source/game/`):
- **`OverworldState`** — builds the world, owns a *nested* `StateMachine` with substates `explore` (edge-door checks → story triggers → door checks → encounters, in that order), `irisOut` (battle transition), and `doorWarp` (door/mat/stairs transition: GB-style shade fade to black, then `change("overworld", { entry = {x, y, facing} })` into the target zone). Saves the player's position on exit and restores it when re-entering the same zone (`{ respawn = true }` forces the zone spawn — blackout and zone switches; `{ entry = ... }` overrides both — door warps).
- **`DialogState`** — pushed overlay; pops itself when the last line is dismissed, then runs its onComplete callback (trainer dialogs chain into `change("battle", ...)`).
- **`BattleState`** — owns `Battle` + `BattleScene`; on `battleEnd`, victory/run returns to the saved overworld position, defeat full-restores the pokemon and respawns at zone spawn. Calls `Story.notifyBattleEnd(won)` so the questline tracks the rival fight.
- **`DebugState`** — pushed overlay around `DebugMenu`; in-menu actions consumed per-frame in `update()`, menu-closing actions (wild battle, zone switch, skip/reset intro) handled in its onClose: pop, then change.

Trainer NPC "defeated" flags survive world rebuilds: `NPC:markInteracted()` mirrors the flag onto the zone's npc def, and `Zone:spawnNPCs()` restores it.

### Intro Questline (`game/story.lua`)

The global `Story` runs the Gen 1 "first minutes" as a tiny linear stage machine: `pre_oak` (game boots in Red's bedroom; walking into the Route 1 grass strip triggers Oak's "Don't go out!" and a fade into the lab) → `lab_greet` → `choose` (A on a `Pb` ball tile picks the starter; the three balls are in Gen 1 left-to-right order **Charmander, Squirtle, Bulbasaur**; BLUE takes the type-advantaged counter pick and both balls leave the table via `setOverworldTile`) → `pre_rival` (walking toward the lab exit triggers BLUE's challenge) → `rival_fight` → `goodbye` (outcome-specific taunt, then BLUE is removed) → `done` (free play).

Wiring: `ExploreSubstate:update` calls `Story.check(game, overworldState)` every frame (scene triggers fire on *being* somewhere, step triggers on `stepJustFinished`; both no-op unless the root machine's top is `overworld`); `handleInput` calls `Story.tryInteract` for the ball tiles before NPC lookup. Stages flip *before* their dialog is pushed so a trigger can't fire twice. Until the starter is chosen `game.playerPokemon` is nil — encounter checks and trainer-battle starts are guarded on it, and `OverworldState` only auto-grants the default squirtle when `Story.stage == "done"`. Intro starters get only their **first 2 moves** — the Gen V level-1 moveset (Scratch/Tackle + Growl/Tail Whip) — instead of `Pokemon:init`'s last-4 default, so a Lv5 starter doesn't wrongly know Ember/Smokescreen/Vine Whip and the first rival fight stays a low-level chip-damage duel (see `starterPokemon` in story.lua). The intro dialogue (Oak's monologue, the "Don't go out!" stop, the lab greeting, the starter confirmation + "really energetic!" line, the rival challenge, and the win/lose "Smell you later!" goodbye) is kept close to the verbatim Gen 1 R/B text from the pokered disassembly. `Story.skipIntro(game)` / `Story.resetIntro(game)` back the debug menu's Skip/Reset Intro and the autopilot `intro` command.

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
6. `game/story.lua` before `data/maps.lua` (npc defs close over the `Story` global)
7. `game/*` after the modules their states instantiate (Dialog, Battle, DebugMenu...)

### Key Modules

- **`battle/dsl.lua`** — Composable battle DSL (inspired by Christopher Okhravi's "Rebuilding Pokémon with OOP"): Targets (`ATTACKER`/`DEFENDER` selectors), lazy Numbers (`Exactly`, `Between`, `Weighted`, `Product`, `MaxHPOf`...), Conditions (`Chance`, `Not`, `AllOf`, battler predicates lifted via `For(target, cond)`), Effects (`ModifyStat`, `ApplyStatus`, `DirectDamage`, `Heal`, combinators `EffectSeq`/`When`/`NoEffect`). Effects implement `:apply(battle)`, resolve targets through the battle's current attacker/defender orientation, and narrate themselves with `battle:say(...)`. `ApplyStatus` knows Gen V type immunities (fire/burn, ice/freeze, poison+steel/poison), routes `flinch`/`confuse` to volatile fields, and seeds the Gen V 1-3 turn sleep counter.
- **`battle/battle.lua`** — Rules engine, **Gen V (B2W2) mechanics throughout**: damage = `(2L/5+2)·power·A/D / 50 + 2` then modifiers in order crit ×2 → random 85-100% → STAB 1.5 → type → burn-halves-physical (floor each step); per-move physical/special split; crits (1/16) ignore stages unfavorable to the attacker; accuracy/evasion stages (3-based multipliers) in `checkAccuracy`; move priority brackets then effective speed (paralysis = speed/4) for turn order; multi-hit 2-5 distribution (1/3, 1/3, 1/6, 1/6); drain/recoil as % of damage dealt; flinch and confusion volatiles (1-4 turns, 50% 40-power typeless self-hit); sleep counts down 1-3 and the pokemon acts on waking; Gen III-V run formula. `Battle(player, enemy, trainerName)` — a non-nil `trainerName` makes it a trainer battle: "X wants to battle!" intro, named victory/defeat messages, and running is refused (`BattleState` passes `npc and npc.name`). Owns a nested `StateMachine` with phases **command** (menus), **script** (a coroutine resolves the round; `battle:say()` yields until A is pressed — turn logic is linear, no callback pyramids), **ended** (A emits the `battleEnd` signal). `battle:setDirection(side)` flips attacker/defender per half-turn.
- **`battle/battleScene.lua`** — Battle UI rendering and input handling. Draws HP bars, sprites, move select with type effectiveness preview. Queries `battle:isAwaitingCommand()` to decide menus vs message text.
- **`battle/moves.lua`** — GENERATED by `tools/generate_gen5_data.py` (do not hand-edit move data). Global `moveData` table keyed by camelCase name: B2W2-resolved power/accuracy/pp/type/priority, per-move damage class, drain/recoil, multi-hit ranges, and effects composed from DSL objects, e.g. `When(Chance(30), ApplyStatus(DEFENDER, "paralyze"))`.
- **`data/pokemon.lua`** — 151 species in global `pokemonData` keyed by lowercase name, with **Gen V base stats** (SpA/SpD split: `baseSpA`, `baseSpD`, `baseSpe`) and `baseExp` yields — species stat blocks are regenerated by `tools/generate_gen5_data.py`. Contains the `Pokemon` class: stats with `spa/spd/spe`, stat stages incl. `acc`/`eva`, volatiles (`confusion`, `flinched`), B2W2 flat XP formula `(baseExp · level) / 7`.
- **`data/typechart.lua`** — Gen V 17-type effectiveness matrix accessed via `TypeChart.getMatchup()`.
- **`data/maps.lua`** — Zone definitions using declarative tile codes and `setupOverworld()`.
- **`world/zone.lua`** — Zone class with Dart-like declarative config. Auto-generates collision from tile types. See below.
- **`world/player.lua`** — Grid movement with smooth interpolation (8 frames/step at 30fps). Walk animation: Gen 1 cadence (stride first half of step, standing second half) with the lead leg alternating per step via `walkToggle` (distinct side stride frames; X-flipped frames for up/down). Characters draw 8px above their tile (GB style) and a tall-grass overlay hides the legs while in grass; landing a step in grass shows a splayed rustle variant for 6 frames (`rustleFrames`). `stepJustFinished` flag triggers encounter checks.
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

Tile codes: `.`=Grass, `Pa`=Path, `Wa`=Wall, `Wt`=Water, `Tr`=Tree, `Dr`=Door, `Fn`=Fence, `TG`=Tall Grass, `Rf`=Roof, `Sg`=Sign, `Fl`=Flowers, `Sh`=Shore, `LW`=Lab Wall, `Mb`=Mailbox, `RL`=Roof Left, `RR`=Roof Right, `WW`=Wall Window. Interior codes: `Fo`=Floor, `IW`=Interior Wall, `Ma`=Door Mat, `Tb`=Table/counter, `Bk`=Bookshelf, `Tv`=TV, `Pl`=Plant, `St`=Stairs, `Bd`=Bed, `PC`=PC desk, `LM`=Lab Machine, `Vd`=Void (black surround), `Pb`=Table with a POKE BALL (starter choice; swapped to `Tb` at runtime when taken). Exit mats sit one row above the room's bottom edge with a `Vd` void row beneath them — that black space is where the exit arrow renders.

Collision is auto-generated from tile types — no manual collision arrays. Globals: `zoneRegistry`, `zoneList`, `currentZone`. `switchZone(key)` changes zones. Zone methods: `spawnNPCs()`, `checkEncounter()`, `rollEncounter()`, `getDoorAt()`, `getEdgeDoorAt()`. `setOverworldTile(gx, gy, id)` (world/overworld.lua) swaps a tile in the live tilemap; callers also mutate `zone.tiles` so rebuilds keep the change.

NPC defs support story-conditional spawning and content: `appearsIf = function() ... end` (def skipped while false), and `dialog`/`battleData` may be functions resolved at interaction time (`NPC:getDialogLines()`, `NPC:getBattleData()`).

**Doors** come in two kinds, both distinct from `warps` (debug-menu teleport presets):
- **Step doors** (`{ x, y, to, toX, toY, facing }`) fire when a step finishes on the tile — outside house doors and stairs. Stepping off and back on re-triggers (Gen 1 stairs behavior).
- **Edge doors** (`{ x, y, edge="down", to, toX, toY, facing }`) are Gen 2/3-style exit gates: landing on the tile does nothing; the warp fires when the player stands on it and *walks in the edge direction* (into the room boundary). All interior exit mats are edge doors. `Player:tryMove` sets `player.pendingEdgeDoor` when a blocked move matches an edge door; `explore` consumes it and switches to `doorWarp`. The autopilot `move` command reports `edge-door <dir> at x,y` when this happens. While the player stands on an edge-door tile, `Player:updateExitArrow` shows a bobbing **exit arrow** sprite (`getExitArrows` builds the 4 directional images procedurally; z-index 102) in the void tile just past the door, pointing the exit direction — the Gen 2/3 "you can leave here" cursor. `Zone:getEdgeDoorAt(gx, gy, dir)` finds the door (nil `dir` matches any edge door at the tile, used to aim the arrow).

Pallet Town has four interiors: `reds_house` (Mom, stairs to `reds_house_2f`), `blues_house` (Daisy), `oaks_lab` (Oak, plus BLUE until the intro ends). Interior rooms sit in a `Vd` void surround padded to at least 13x8 tiles because the camera clamp assumes the map is at least screen-sized (400x240 = 12.5x7.5 tiles). Interiors have no `encounters` and no tall grass, so no wild battles trigger indoors. After the intro, a rematch BLUE (`appearsIf` stage done, lv7 counter-pick via `battleData` function) waits outside his house.

`Zone:init` resolves roof corner tiles against the terrain beside them (RL checks left then above, RR right then above): a corner next to path/tall grass swaps to a composited variant (IDs 21-24) so the triangle outside the roof diagonal shows that texture instead of a white wedge. Authoring always uses plain `RL`/`RR`.

### 2-Bit Color System (`lib/shade.lua` + `world/tilefactory.lua`)

Simulates the Game Boy's 4-shade palette on Playdate's 1-bit display using ordered dithering patterns. `TileFactory` generates all tile types at runtime — no external tile PNGs needed. Tiles are authored as 16x16 four-shade text grids (`.`=white, `1`=LIGHT, `2`=DARK, `#`=black) and rendered at native 32x32 (TILE_SIZE): each authored pixel becomes a 2x2 block, but dither patterns apply in screen space so the dots stay fine. Every grid row must be exactly 16 chars (asserted at startup). Water, tall grass, and the 3 flower bob frames are 1:1 ports of the Gen 1 tiles from the pokered disassembly.

**Animated tiles** (`world/overworld.lua`): water, shore, and flowers animate by swapping images into the imagetable in place (tile IDs never change) and marking the tilemap sprite dirty. One shared 10-frame heartbeat reproduces Gen 1's global animation counter (one step per 21 frames at 60fps): water/shore oscillate the wave streaks ±4px (`TileFactory.water(shift)`), flowers cycle bob frames 1,2,3,1. `updateOverworldAnimations()` is driven from `OverworldState:update()`, so animation continues under dialog/debug overlays and during the iris transition.

### Sprite System (`world/spritefactory.lua`)

Overworld character sprites (player **and** NPCs) are generated at runtime by `SpriteFactory`, the companion to `TileFactory` — there are **no sprite PNGs**. Frames are authored as 16x16 grids (same `. 1 2 #` convention as tiles) and rendered to 32x32 via the shared `TileFactory.renderGrid`, then given an **alpha mask**: a cell-level border flood-fill marks every `.` cell reachable from the edge through other `.` cells as transparent, so the body must be sealed by a continuous `#` outline. Right-facing frames are the left frame flipped (`SpriteFactory.flipped`).

> **Don't hand-draw NPC sprites — transcribe the real Gen 1 art.** Hand-authored grids look amateur next to RED no matter how much they're tweaked; the fix that worked was to convert the actual pokered overworld sprites pixel-for-pixel. (And the earlier "grey dithers into noise" theory was a red herring — well-designed grey art renders fine; bad *shapes* were the real problem.) The deterministic converter is **`tools/generate_overworld_sprites.py`** — it downloads the pokered strips, slices the down/up/left frames, maps the 4 GB shades to `. 1 2 #`, and writes the grid files. Regenerate rather than hand-edit; the exact command is recorded in each file's header. Current `--map` choices: clean white bodies/faces like RED, but hair keeps a grey dither so it reads as textured hair rather than a solid-black blob. The dark-haired three (`rival`/`mom`/`daisy`) use **`greyhair`** (light-grey→white, dark-grey→`2` dither, black→black); `oak` uses **`outline`** (light-grey→white, dark-grey→white, black→black) so his light hair stays white-with-detail and his `#22#` eyes stay two dots instead of collapsing into a glasses-like bar. Other maps exist if you want to retune: `bw` (dark hair → solid black), `faithful` (all four GB shades), `heavy`.

- **Grid files live in `world/sprites/<character>.lua`** — one file per character (`red`/`oak`/`rival`/`mom`/`daisy`), each assigning into `SpriteFactory.grids.<key>`. `spritefactory.lua` owns the shared make/mask/flip machinery, `import`s those files, then assembles them into images. Tune one character without touching the others.
- **Player (RED):** `SpriteFactory.playerStand` / `playerWalk1` / `playerWalk2`, each `{down, up, left, right}`. The grids (`world/sprites/red.lua`) are a hand-tuned, pure-B/W rendition transcribed verbatim from the proven art; the autopilot `atlas` command pixel-diffed them to confirm a lossless migration from the old PNGs (do **not** casually edit the player grids, and do **not** regenerate RED from the converter — its custom look is intentional).
- **NPCs:** `SpriteFactory.npc[key]` (`oak`/`rival`/`mom`/`daisy`), each `{down, up, left, right}` (right = flipped left; up/left fall back to down if unauthored). The grids are **generated from the pokered Gen 1 originals** (Oak's bushy hair + lab coat, BLUE's spiky hair, MOM's bob, DAISY's long hair) and carry a "generated — do not hand-edit; regenerate" header. `NPC` stores a `facing` and turns to look at the player on interaction (`NPC:faceTowards`, called from `OverworldState`), Gen 1 style. A def may set a default `facing`.

**Verifying art:** the autopilot `atlas` command renders every tile and every sprite frame to labeled contact sheets (`tools/shots/atlas_tiles.png`, `atlas_sprites.png`) — this is the way to check visuals without walking the game. Edit a grid → recompile → `atlas` → view the PNG.

### Conventions

- Globals are localized with `<const>` for performance: `local gfx <const> = playdate.graphics`
- Pokemon sprites lazy-load from `Source/images/pokemon/{species}-front.png` and `{species}-back.png`
- Overworld sprites (player + NPCs) are generated at runtime by `SpriteFactory` — no PNGs; see the Sprite System section above. (Pokémon battle front/back sprites still lazy-load from `Source/images/pokemon/`.)
- Wild encounters only trigger on tall grass tiles with 15% chance per step
- Screen shake uses `playdate.display.setOffset()` — must be reset to (0,0) on battle exit
- The debug menu is accessible from the Playdate system menu during overworld state

## Tools

- **`tools/autopilot.py` + `Source/dev/autopilot.lua`** — Simulator automation bridge for visual iteration. The Lua side (simulator-only, no-op on device) polls `autopilot.txt` in the game's Data folder (`~/Developer/PlaydateSDK/Disk/Data/com.poc.pokemon/`) and acks with `autopilot-done.txt`. Overworld commands: `move <dir> [n]`, `face <dir>`, `warp <gx> <gy>` (aborts with "interrupted" if a battle yanks the state away mid-walk). Any-state commands: `wait <frames>`, `shot <name>`, `record <name> <n>` (per-frame capture), `encounters <on|off>`, `press <a|b|up|down|left|right>` (injects a one-frame synthetic button press by wrapping `playdate.buttonJustPressed/IsPressed` — drives dialogs and battle menus), `mash <btn> <n> [gap]` (n presses every gap frames, default 16 — message boxes need >10 frames between presses), `dismiss` (press A until the dialog overlay closes — prefer over `mash` for dialogs: mash can overshoot and re-trigger the NPC), `battle <species> <level>` (jump straight into a wild battle), `intro <skip|reset|status>` (drive the Story questline: skip grants the default starter and rebuilds the overworld in place; reset restarts from the bedroom), `gamestate` (state stack, battle phase + message, current zone, story stage, player pos, recent transitions — first stop for triage), `seed <n>` (deterministic RNG), `debug <open|close>`, `pokemon` (player pokemon hp/lv/xp/status), `atlas` (render every tile + every sprite frame to labeled contact sheets `tools/shots/atlas_tiles.png` and `atlas_sprites.png` — the way to verify art without walking the game). `move` steps that land on a door tile start the door fade; queued moves wait it out and continue in the destination zone (add `wait 30` before `gamestate` after entering a door). A `move` into an exit-mat edge reports `edge-door <dir> at x,y` and the warp follows. A fresh boot starts the intro: the opening monologue is up, so begin scripts with `dismiss`; story dialogs (Oak stop, rival challenge) interrupt queued moves the same way battles do. Screenshots land in `tools/shots/`. Example: `python3 tools/autopilot.py "encounters off" "warp 5 8" "record walk 18" "move right 2" --strip walk` builds a magnified film strip plus frame-to-frame pixel diffs. A full scripted battle: `"seed 42" "battle rattata 3" "wait 30" "press a"` … then `"press a"` for FIGHT, `"press a"` for move 1, `"mash a 10 16"` through the round. Note: `warp` bypasses collision. Reloading is the #1 footgun: both `open -a` and `make run` (which uses `open`) frequently fail to load a freshly compiled `.pdx` — the autopilot then times out with "no ack" or answers with a stale build, which looks exactly like a boot crash. The reliable sequence: `pkill -9 -f "Playdate Simulator"`, confirm none remain with `pgrep -f "MacOS/Playdate Simulator"`, then **launch the binary directly** with the absolute pdx path — `nohup "$PLAYDATE_SDK_PATH/bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator" "$PWD/PokemonPoC.pdx" &` — and wait ~6s. (A genuine boot crash and a stale/failed reload both present as "no ack"; rule out the reload first by direct-launching before assuming your Lua crashed.) The Simulator window grabs keyboard focus on launch — stray keystrokes land in the game and look like phantom input in scripted runs.
- **Overworld sprites are NOT a tool** — player and NPC frames are generated in-engine by `SpriteFactory` (`world/spritefactory.lua`); edit the Lua grids and verify with the autopilot `atlas` command. (The old Python generators `generate_side_sprites.py` and `import_pokered_sprite.py` were retired in this migration.)
- **`tools/verify_moves/`** — Python tool that validates move data in `battle/moves.lua` against PokeAPI. Run with `python tools/verify_moves/main.py`. Caches API responses locally. Generates per-species comparison reports in `tools/verify_moves/reports/`.
- **`tools/generate_gen5_data.py`** — Regenerates `battle/moves.lua` (whole file) and the species stat blocks in `data/pokemon.lua` from cached Gen V sources (`tools/gen5cache/`): PokeAPI CSVs (`move_changelog` resolves values as of version group 14 = B2W2) and Pokémon Showdown's pokedex + gen8→gen5 mod chain (Gen V base stats/types). Species movesets and the Pokemon class are preserved. Run after adding moves or species; delete `tools/gen5cache/` to re-fetch.
