# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Requires the [Playdate SDK](https://play.date/dev/). Set `PLAYDATE_SDK_PATH` before building.

```bash
# Build, clean, and open in Simulator
PLAYDATE_SDK_PATH=~/Developer/PlaydateSDK make build

# Individual steps
make clean      # rm -rf PokemonPoC.pdx
make compile    # stage production Source without dev/, then compile PokemonPoC.pdx
make run        # open Simulator with PokemonPoC.pdx

# Deploy to a connected Playdate device (USB, unlocked)
make deploy     # compiles, enters data disk mode, copies .pdx, ejects & reboots
```

The `deploy` target auto-detects the Playdate at `/dev/cu.usbmodemPD*`. It puts the device into Data Disk mode, waits for `/Volumes/PLAYDATE` to mount (up to 30s), copies the `.pdx` bundle, and ejects. The Playdate reboots automatically after eject.

Production builds use `tools/build.py`; direct `pdc Source` includes unreferenced development modules. Harness staging inserts `tools/harness/dev_imports.lua` into its private entry point. When changing staging or imports, read [production-build.md](docs/validation/production-build.md).

Before Simulator, harness, or visual work, read [the harness contract](docs/validation/harness.md). `make test-harness` runs host protocol tests; `make harness-smoke` runs an identified SDK session. The deeper suite is `python3 tools/harness/suite.py --mutations --output /private/tmp/pokemon-suite-UNIQUE`. Install `tools/requirements-dev.txt` in a venv for visual/generator checks.

For full-game implementation or resuming after compaction, read [the goal](docs/plans/full-game-goal.md) and then [the execution ledger](docs/validation/progress.md). The older [Astra goal](docs/plans/astra-full-game-goal.md) is superseded history. Implementation and independent acceptance are tracked separately; the full campaign remains unfinished.

## Architecture

Lua project for the Playdate handheld (400x240, 1-bit display, 30 FPS). All source is in `Source/`.

> **Generations — read this first.** The game runs **Gen V (B2W2) battle mechanics, move data, and base stats** throughout (battle engine, `moves.lua`, `pokemon.lua`, type chart). The opening **story and dialogue** recreate the **Gen 1 (Red/Blue) Kanto intro** (Oak, rival BLUE, Kanto starters, verbatim R/B text). So: when adding/changing moves, stats, or battle rules → target **Gen V**; when adding intro flow or dialogue → target **Gen 1**. A "wrong" move at low level (e.g. a Lv5 Charmander knowing Ember/Smokescreen) is a Gen-V-learnset-ordering issue, not a Gen 1 question — see the level-1-moves note in the Intro Questline section.

### Game Loop & State Machine

`main.lua` is the entry point: it imports everything, builds a `GameContext` (global `game`: root machine, camera, npcManager, player, authoritative GameSession, transition log), registers the top-level states, and runs `machine:update()` → `machine:handleInput()` → `machine:draw()` each frame, followed by incremental GC (`collectgarbage("step", 1)`).

`lib/statemachine.lua` provides `State` (lifecycle: `enter/exit/pause/resume/update/draw/handleInput`) and `StateMachine` — a **stack** machine. `change(name, ...)` replaces the stack; `push(name, ...)`/`pop(...)` overlay states. Every stacked state updates and draws bottom→top each frame, but **only the top state receives `handleInput()`** — so dialog and the debug menu are pushed over the overworld and the world keeps animating beneath them. Overworld overlays keep tile rendering/animation alive but suspend Player/NPC updates and progression triggers. The machine emits a `"changed"` signal (kind, from, to); `GameContext` records the last 12 transitions for triage (`gamestate` autopilot command prints them).

Top-level states (classes in `Source/game/`):
- **`OverworldState`** — builds the world, owns a *nested* `StateMachine` with substates `explore` (edge-door checks → story triggers → door checks → encounters, in that order), `irisOut` (battle transition), and `doorWarp` (door/mat/stairs transition: GB-style shade fade to black, then `change("overworld", { entry = {x, y, facing} })` into the target zone). Saves the player's position on exit and restores it when re-entering the same zone (`{ respawn = true }` forces the zone spawn — blackout and zone switches; `{ entry = ... }` overrides both — door warps).
- **`DialogState`** — pushed overlay; pops itself when the last line is dismissed, then runs its onComplete callback (trainer dialogs chain into `change("battle", ...)`).
- **`BattleState`** — owns `Battle` + `BattleScene` with authoritative party/session dependencies. Party/bag selections are guarded overlays; rules wait beneath them. Victory/run/caught returns normally, only all-fainted parties black out to the persisted healing checkpoint, and the intro rival retains its lab exception. Calls `Story.notifyBattleEnd(game, won, kind)`. Pending learning choices are offered across all party members.
- **`DebugState`** — pushed overlay around `DebugMenu`; in-menu actions consumed per-frame in `update()`, menu-closing actions (wild battle, zone switch, skip/reset intro) handled in its onClose: pop, then change.
- **`LearningState`** — explicit move-learning overlay after battle XP. Free slots append with a message; full movesets require replacement confirmation or an explicit decision to stop learning. Pending choices survive the Pokémon codec.
- **`PauseState` / `PartyState` / `BagState`** — B opens the field menu. Party selections support field reorder/details and guarded battle switching; bag selections support field medicine and guarded battle ball commands.
- **`TitleState` / `GameSaves`** — a valid save offers Continue/New Game. A fresh game preserves the existing Oak opening. Capture only settled exploration; disk writes use the two-slot store. The harness can verify actual process restarts with private saves (see `harness-restarts.md`).

`GameContext.session` owns party, storage, inventory, intro tuple, quest/trainer flags, Pokédex and checkpoint. `getPlayerPokemon()` derives the active member; never recreate a `game.playerPokemon` owner. Trainer flags use stable source IDs or authored zone/index IDs through `NPCManager(game)`. Do not mutate `npcDef.interacted` as persistent state. `Story` exposes a read-only facade for authored map closures; internal writes use atomic session intro updates.

### Intro Questline (`game/story.lua`)

The global `Story` runs the Gen 1 "first minutes" as a tiny linear stage machine: `pre_oak` (game boots in Red's bedroom; walking into the Route 1 grass strip triggers Oak's "Don't go out!" and a fade into the lab) → `lab_greet` → `choose` (A on a `Pb` ball tile picks the starter; the three balls are in Gen 1 left-to-right order **Charmander, Squirtle, Bulbasaur**; BLUE takes the type-advantaged counter pick and both balls leave the table via `setOverworldTile`) → `pre_rival` (walking toward the lab exit triggers BLUE's challenge) → `rival_fight` → `goodbye` (outcome-specific taunt, then BLUE is removed) → `done` (free play).

Wiring: `ExploreSubstate:update` calls `Story.check(game, overworldState)` every frame (scene triggers fire on *being* somewhere, step triggers on `stepJustFinished`; both no-op unless the root machine's top is `overworld`); `handleInput` calls `Story.tryInteract` for the ball tiles before NPC lookup. Stages flip *before* their dialog is pushed so a trigger can't fire twice. Until the starter is chosen `game:getPlayerPokemon()` is nil. Encounters and trainer starts are guarded; ordinary empty sessions never receive a fallback Pokémon. Explicit debug skip/fixture APIs create their documented starter. All Pokémon now initialize from ordered B2W2 level-up events through their actual level, keeping the last four eligible distinct moves. Lv5 starters naturally receive Scratch/Tackle + Growl/Tail Whip; there is no story-specific truncation. `gainXP` queues explicit move-learning choices rather than silently replacing selected moves. The intro dialogue (Oak's monologue, the "Don't go out!" stop, the lab greeting, the starter confirmation + "really energetic!" line, the rival challenge, and the win/lose "Smell you later!" goodbye) is kept close to the verbatim Gen 1 R/B text from the pokered disassembly. `Story.skipIntro(game)` / `Story.resetIntro(game)` back the debug menu's Skip/Reset Intro and the autopilot `intro` command.

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
- **`data/pokemon.lua`** — 151 species in global `pokemonData`, ordered B2W2 learnsets, stat stages, volatiles and explicit pending move choices. `Pokemon:xpForLevel(level)` uses the species growth family. `domain/growth.lua` supplies Gen V scaled XP with integer-safe arithmetic; `data/growthData.lua` pins all growth thresholds and B2W2 yields independently of the legacy species generator. XP grants cap before addition and cannot revive a fainted recipient. See [growth-foundation.md](docs/validation/growth-foundation.md) for formula, sources and currently supported modifiers.
- **`data/typechart.lua`** — Gen V 17-type effectiveness matrix accessed via `TypeChart.getMatchup()`.
- **`data/maps.lua`** — Zone definitions using declarative tile codes and `setupOverworld()`.
- **`world/zone.lua`** — Zone class with Dart-like declarative config. Auto-generates collision from tile types. See below.
- **`world/player.lua`** — Grid movement with smooth interpolation (8 frames/step at 30fps). Walk animation: Gen 1 cadence (stride first half of step, standing second half) with the lead leg alternating per step via `walkToggle` (distinct side stride frames; X-flipped frames for up/down). Characters draw 8px above their tile (GB style) and a tall-grass overlay hides the legs while in grass; landing a step in grass shows a splayed rustle variant for 6 frames (`rustleFrames`). `stepJustFinished` flag triggers encounter checks.
- **`world/camera.lua`** — Lerp follow (20%/frame) with `snapTo()` for instant positioning. `apply()`/`reset()` toggle the graphics draw offset.

### Domain owners (`domain/`)

`GameSession` owns durable party, storage, inventory, item storage, flags, Pokédex, checkpoint, world deltas and RNG state. `Party`, `Storage`, `Inventory` and `ItemStorage` enforce their collection invariants. `PokemonCodec` and `SessionCodec` validate persisted data; `SaveStore` owns checksummed slots and recovery archives. `DecimalInteger` preserves exact counters across SDK JSON.

`Specimen` and `IndividualStats` own acquisition traits and IV/EV stats. `Growth`, `Evolution`, `Teaching`, `Capture`, `Items` and `PCItems` own their respective gameplay transactions. `FieldEncounters` owns encounter attempts; `WorldMotionData` validates persisted NPC motion; `NPCMotion` uses the independent world RNG. Keep state changes in these owners rather than adding parallel state to UI or map handlers.

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

Authored-map collision is generated from tile definitions. Imported maps carry validated explicit terrain/collision data and stable tile keys in `TileRegistry`; numeric image IDs are never saved. Globals: `zoneRegistry`, `zoneList`, `currentZone`. Use `Zone:setTile(x,y,key)` to update data, terrain, collision and an attached `WorldView` atomically. `setOverworldTile` delegates to that API; never also assign `zone.tiles` directly. `WorldDeltas` validates, exports and applies complete stable-key delta sets with rollback. Imported terrain fixtures remain distinct from campaign-ready event bindings.

NPC defs support story-conditional spawning and content: `appearsIf = function() ... end` (def skipped while false), and `dialog`/`battleData` may be functions resolved at interaction time (`NPC:getDialogLines()`, `NPC:getBattleData()`).

**Doors** come in two kinds, both distinct from `warps` (debug-menu teleport presets):
- **Step doors** (`{ x, y, to, toX, toY, facing }`) fire when a step finishes on the tile — outside house doors and stairs. Stepping off and back on re-triggers (Gen 1 stairs behavior).
- **Edge doors** (`{ x, y, edge="down", to, toX, toY, facing }`) are Gen 2/3-style exit gates: landing on the tile does nothing; the warp fires when the player stands on it and *walks in the edge direction* (into the room boundary). All interior exit mats are edge doors. `Player:tryMove` sets `player.pendingEdgeDoor` when a blocked move matches an edge door; `explore` consumes it and switches to `doorWarp`. The autopilot `move` command reports `edge-door <dir> at x,y` when this happens. While the player stands on an edge-door tile, `Player:updateExitArrow` shows a bobbing **exit arrow** sprite (`getExitArrows` builds the 4 directional images procedurally; z-index 102) in the void tile just past the door, pointing the exit direction — the Gen 2/3 "you can leave here" cursor. `Zone:getEdgeDoorAt(gx, gy, dir)` finds the door (nil `dir` matches any edge door at the tile, used to aim the arrow).

The connected world reaches Brock in Pewter. `SourceMaps` loads the manifest in `data/sourceMaps.json`; `ImportedMaps` owns the shared provider, cache and durable delta ledger. `KantoSlice` and `PewterSlice` are compatibility facades over that pipeline. Four Viridian maps remain resident to preserve existing references, alongside two disposable map slots. Authored Pallet keeps its protected Zone adapter. `tools/generate_source_map_cache.py` verifies the manifest’s pinned decoded inputs and generates compact metadata and direct tile-grid lookup; full definitions load on demand. Adding source data does not bind its events automatically.

`SourceEvents` plans stable-ID programs from `data/sourceEvents.json`; `EventState` executes bounded operations, while session and trainer owners commit durable changes and confirmed battle rewards. Ordinary dialogue, gifts, pickups, shops, healing and trainers use descriptors. Genuinely bespoke scripts are keyed in `sourceEventHandlers.lua`. When changing those plans or ownership, read [source-events.md](docs/validation/source-events.md).

`SourceText` expands source recipes and numeric/RAM controls. `Dialog` measures and paginates complete paragraphs, and reveals only complete UTF-8 characters. `SourceTextFont` keeps ordinary SDK glyphs and supplies pinned extended glyphs. When changing text or fonts, read [source-text.md](docs/validation/source-text.md).

Pallet Town has four interiors: `reds_house` (Mom, stairs to `reds_house_2f`), `blues_house` (Daisy), `oaks_lab` (Oak, plus BLUE until the intro ends). Interior rooms sit in a `Vd` void surround padded to at least 13x8 tiles because the camera clamp assumes the map is at least screen-sized (400x240 = 12.5x7.5 tiles). Interiors have no `encounters` and no tall grass, so no wild battles trigger indoors. After the intro, a rematch BLUE (`appearsIf` stage done, lv7 counter-pick via `battleData` function) waits outside his house.

`Zone:init` resolves roof corner tiles against the terrain beside them (RL checks left then above, RR right then above): a corner next to path/tall grass swaps to a composited variant (IDs 21-24) so the triangle outside the roof diagonal shows that texture instead of a white wedge. Authoring always uses plain `RL`/`RR`.

### 2-Bit Color System (`lib/shade.lua` + `world/tilefactory.lua`)

Simulates the Game Boy's 4-shade palette on Playdate's 1-bit display using ordered dithering patterns. `TileFactory` generates tile images from 16x16 four-shade grids (`.`=white, `1`=LIGHT, `2`=DARK, `#`=black) at native 32x32: each authored pixel becomes a 2x2 block while dithers stay at output resolution. LIGHT is 12.5% black and DARK 50%. Existing authored calls retain their reviewed rendering path. Imported registry grids explicitly request phase `(0,0)`: real SDK 3.1.2 probes demonstrated omitted versus explicit phase differences. Do not normalize the legacy phase casually. [Map pipeline evidence](docs/validation/map-pipeline.md) records the exact comparison.

**Animated tiles** (`world/overworld.lua`): water, shore, and flowers animate by swapping images into the imagetable in place (tile IDs never change) and marking the tilemap sprite dirty. One shared 10-frame heartbeat reproduces Gen 1's global animation counter (one step per 21 frames at 60fps): water/shore oscillate the wave streaks ±4px (`TileFactory.water(shift)`), flowers cycle bob frames 1,2,3,1. `updateOverworldAnimations()` is driven from `OverworldState:update()`, so animation continues under dialog/debug overlays and during the iris transition.

### Sprite System (`world/spritefactory.lua`)

Overworld character sprites (player **and** NPCs) are generated at runtime by `SpriteFactory`, the companion to `TileFactory` — there are **no sprite PNGs**. Frames are authored as 16x16 grids (same `. 1 2 #` convention as tiles) and rendered to 32x32 via the shared `TileFactory.renderGrid`, then given an **alpha mask**: a cell-level border flood-fill marks every `.` cell reachable from the edge through other `.` cells as transparent, so the body must be sealed by a continuous `#` outline. Right-facing frames are the left frame flipped (`SpriteFactory.flipped`).

> **Don't hand-draw NPC sprites — transcribe the real Gen 1 art.** Hand-authored grids look amateur next to RED no matter how much they're tweaked; the fix that worked was to convert the actual pokered overworld sprites pixel-for-pixel. (And the earlier "grey dithers into noise" theory was a red herring — well-designed grey art renders fine; bad *shapes* were the real problem.) The deterministic converter is **`tools/generate_overworld_sprites.py`**. It uses vendored immutable strips with checksums, validates frames/palette, and preserves per-character mappings. Run `--check` first; `--write --output-dir <temporary-directory>` generates candidates for review. Read [sprite-provenance.md](docs/validation/sprite-provenance.md) before extending or regenerating art. Existing grid headers are historical; the manifest is the current regeneration contract. Current `--map` choices: clean white bodies/faces like RED, but hair keeps a grey dither so it reads as textured hair rather than a solid-black blob. The dark-haired three (`rival`/`mom`/`daisy`) use **`greyhair`** (light-grey→white, dark-grey→`2` dither, black→black); `oak` uses **`outline`** (light-grey→white, dark-grey→white, black→black) so his light hair stays white-with-detail and his `#22#` eyes stay two dots instead of collapsing into a glasses-like bar. Other maps exist if you want to retune: `bw` (dark hair → solid black), `faithful` (all four GB shades), `heavy`.

- **Grid files live in `world/sprites/<character>.lua`** — one file per character (`red`/`oak`/`rival`/`mom`/`daisy`), each assigning into `SpriteFactory.grids.<key>`. `spritefactory.lua` owns the shared make/mask/flip machinery, `import`s those files, then assembles them into images. Tune one character without touching the others.
- **Player (RED):** `SpriteFactory.playerStand` / `playerWalk1` / `playerWalk2`, each `{down, up, left, right}`. The grids (`world/sprites/red.lua`) are a hand-tuned, pure-B/W rendition transcribed verbatim from the proven art; the autopilot `atlas` command pixel-diffed them to confirm a lossless migration from the old PNGs (do **not** casually edit the player grids, and do **not** regenerate RED from the converter — its custom look is intentional).
- **NPCs:** `SpriteFactory.npc[key]` (`oak`/`rival`/`mom`/`daisy`), each `{down, up, left, right}` (right = flipped left; up/left fall back to down if unauthored). The grids are **generated from the pokered Gen 1 originals** (Oak's bushy hair + lab coat, BLUE's spiky hair, MOM's bob, DAISY's long hair) and carry a "generated — do not hand-edit; regenerate" header. `NPC` stores a `facing` and turns to look at the player on interaction (`NPC:faceTowards`, called from `OverworldState`), Gen 1 style. A def may set a default `facing`.

**Verifying art:** the autopilot `atlas` command renders every tile and every sprite frame to labeled contact sheets (`tools/shots/atlas_tiles.png`, `atlas_sprites.png`) — this is the way to check visuals without walking the game. Edit a grid → recompile → `atlas` → view the PNG.

### Conventions

- Globals are localized with `<const>` for performance: `local gfx <const> = playdate.graphics`
- Pokemon sprites lazy-load from `Source/images/pokemon/{species}-front.png` and `{species}-back.png`
- Overworld sprites (player + NPCs) are generated at runtime by `SpriteFactory` — no PNGs; see the Sprite System section above. (Pokémon battle front/back sprites still lazy-load from `Source/images/pokemon/`.)
- Wild grass encounters use `FieldEncounters` and each zone’s explicit policy: imported Blue rate bytes and weighted slots, or authored unit rates. Lead-ability effects use the same transaction.
- Screen shake uses `playdate.display.setOffset()` — must be reset to (0,0) on battle exit
- The debug menu is accessible from the Playdate system menu during overworld state

## Tools

- **Simulator ownership:** `tools/harness/run.py` stages an identified private bundle, launches the exact Simulator binary, verifies readiness, and records snapshots/traces/captures. One owner controls the runtime; workers submit jobs to that owner. The global lock serializes SDK sessions. Terminate only the process owned by the runner. Production builds do not poll test mailboxes. Read [harness.md](docs/validation/harness.md) for protocol, cancellation/reset, semantic assertions, frame timing and artifact contracts; [journeys.md](docs/validation/journeys.md) for real-input scenarios.
- **Visual iteration:** `tools/autopilot.py` is a fresh-session wrapper, so include `dismiss` or an explicit fixture before gameplay commands. Use `catalog` for complete tiles, character frames/masks, battle art and map overlays; preserve named artifacts from the run directory. Raw frame PNGs exclude display transforms; their `-display.png` companions include shake offsets. Read [visual-catalog.md](docs/validation/visual-catalog.md) before comparing or accepting art.
- **Rules RNG:** gameplay uses `RulesRNG`; cosmetic drawing never consumes it. `contracts` runs production SDK lifecycle/rules tests. Details and controlled mutation qualification are in [rules-contracts.md](docs/validation/rules-contracts.md).
- **Overworld sprites are NOT a tool** — player and NPC frames are generated in-engine by `SpriteFactory` (`world/spritefactory.lua`); edit the Lua grids and verify with the autopilot `atlas` command. (The old Python generators `generate_side_sprites.py` and `import_pokered_sprite.py` were retired in this migration.)
- **B2W2 content verification:** `python3 tools/verify_moves/main.py --fetch --output /private/tmp/move-report-UNIQUE.json` validates pinned inputs, ordered levels and scalar data, and fails on discrepancies. Existing reports are historical. Read [move-verifier.md](docs/validation/move-verifier.md) for offline use and known mechanics gaps.
- **`tools/generate_gen5_data.py`** — Regenerates `battle/moves.lua` (whole file) and the species stat blocks in `data/pokemon.lua` from cached Gen V sources (`tools/gen5cache/`): PokeAPI CSVs (`move_changelog` resolves values as of version group 14 = B2W2) and Pokémon Showdown's pokedex + gen8→gen5 mod chain (Gen V base stats/types). Species movesets and the Pokemon class are preserved. Run after adding moves or species; delete `tools/gen5cache/` to re-fetch.
