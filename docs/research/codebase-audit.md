# Codebase research for the full-game Astra goal

Research date: 2026-10-20. Source revision: `1cb8225` (`Update README for Gen V mechanics, Gen 1 intro, and runtime sprites`). The tracked working tree was clean before this research. This document distinguishes inspected code, limited runtime observations, and proposed work; it does not certify the existing game as complete or fully correct.

The user explicitly reaffirmed the design: Red/Blue world/story/visual fidelity, with Gen V mechanics and move variety, including Dark/Steel, as deliberate gameplay improvements. The resulting executable goal is [the Astra prompt](../plans/astra-full-game-goal.md).

## What exists and how it fits together

The source contains 33 Lua files, six registered zones, 151 species definitions, 419 `Move` entries, and 302 Pokémon battle PNGs. Counts came from the current source and filesystem. The zones are Pallet, Red's house 1F/2F, Blue's house, Oak's lab, and `test_zone`. The northern grass strip is part of Pallet; no adjoining Route 1 zone exists. [Map definitions](../../Source/data/maps.lua), [species](../../Source/data/pokemon.lua), [moves](../../Source/battle/moves.lua).

`main.lua` imports modules in dependency order, constructs `GameContext`, registers overworld/dialog/battle/debug, starts the bedroom intro, and runs autopilot → state update → input → draw → timers/GC. `GameContext` owns camera, NPC manager, player, one persistent player Pokémon, debug menu, and a 12-entry root transition log. [Entry point](../../Source/main.lua), [context](../../Source/game/context.lua).

The custom OOP library provides globally registered `Class`, inheritance, mixins, Signal, and Pool. Playdate's native class system serves sprite entities. The stack state machine updates/draws bottom to top and sends input only to the top. The overworld nests explore/irisOut/doorWarp; battle nests command/script/ended. `pause` is a lifecycle hook, not automatic update suspension. Transition mutation guards compare the current stack entry by object identity, so same-instance reentry and push/pop scheduling deserve contract tests. [OOP](../../Source/lib/oop.lua), [state machine, especially lines 110–174](../../Source/lib/statemachine.lua).

Overworld exploration processes pending edge exit, story, completed-step door, then encounter. It owns world rebuilding and remembered battle-return position. Dialog pops before invoking its callback. Battle tears down the world, resets player stages, constructs rules and scene objects, then returns or respawns. Trainer “defeated” flags are copied into mutable zone definitions; that persistence lasts only in memory. [Overworld state](../../Source/game/overworldState.lua), [dialog](../../Source/game/dialogState.lua), [battle lifecycle](../../Source/game/battleState.lua), [NPCs](../../Source/world/npc.lua).

The intro is a global, linear stage table: bedroom/opening → Oak stop → lab greeting → starter → rival → goodbye → done. Starter balls and NPC conditions depend on mutable global Story and zone data. Starter creation deliberately takes the first two listed moves. This is an effective small intro, but full campaign events, saves, and concurrent development need clearer persistent state ownership. [Story](../../Source/game/story.lua).

`Battle` already separates much of its rules from `BattleScene`. Coroutine scripts yield narrative messages; the scene supplies menus/rendering. The DSL composes targets, numbers, conditions, and effects. This is a useful foundation to preserve. However rules and rendering share RNG, presentation timers live partly in draw, and battle end is a boolean even though win/loss/run and future capture need distinct outcomes. [Battle](../../Source/battle/battle.lua), [scene](../../Source/battle/battleScene.lua), [DSL](../../Source/battle/dsl.lua).

## Art contracts worth preserving

Tiles use sixteen 16-character rows and `. 1 2 #` shades, rendered at 32×32 through `TileFactory.renderGrid`. Dithering occurs at output resolution. Actual LIGHT is 12.5% black and DARK 50%; opening comments and README disagree about LIGHT. Existing output is the baseline, not contradictory prose. [Renderer, lines 24–63](../../Source/world/tilefactory.lua), [patterns, lines 21–32](../../Source/lib/shade.lua).

Sprite masks flood-fill border-connected `.` cells as transparent, preserving enclosed white. Any nonwhite cell stops the fill; a broken silhouette can make the body transparent. RED has seven hand-tuned source grids expanded into twelve direction/stride images; never feed it through the NPC converter. Oak uses `outline`; rival/Mom/Daisy use `greyhair`; right-facing images are mirrored left frames. [Sprite machinery](../../Source/world/spritefactory.lua), [RED](../../Source/world/sprites/red.lua), [NPC generator](../../tools/generate_overworld_sprites.py).

NPC generation is deterministic for fixed inputs, but fetches mutable `pokered/master`, caches without checksums under ignored `tools/shots`, and lacks a complete source manifest. Existing generated headers omit the `--write` needed to rewrite files, and the tool's default mapping differs from the checked-in NPC mappings. There is no general map/tileset import pipeline. Existing water/grass/flower comments cite original art; this audit did not independently pixel-compare those source images. [Generator, lines 19–117](../../tools/generate_overworld_sprites.py), [tile grids](../../Source/world/tilefactory.lua).

Player movement commits destination grid coordinates before interpolating pixels over eight frames. Walk stride occupies the first half of a step, then standing; leading foot alternates. Character images sit eight pixels above their tile; grass and exit arrows have distinct overlays. Door behavior depends on completed steps versus attempted movement into a blocked outward edge. Camera lerps 20% per frame; current rooms are padded to avoid negative bounds on smaller-than-screen maps. These are intertwined visual and gameplay contracts. [Player](../../Source/world/player.lua), [camera](../../Source/world/camera.lua), [doors](../../Source/world/zone.lua).

Zone authoring uses zero-based coordinates but one-based Lua tables. Roof composites and deterministic grass variants are resolved at construction. Collision is generated once. `setOverworldTile` updates the live tilemap only; callers separately mutate zone data, and collision stays unchanged. Current starter ball→table is safe because both are solid; Cut/Strength/gates require an atomic world-mutation interface. [Zone construction](../../Source/world/zone.lua), [tile mutation, lines 103–110](../../Source/world/overworld.lua).

Tile animation replaces shared imagetable entries; world entry regenerates tiles/animation frames. NPCs currently face the player but do not walk. Fixed sprite z ordering and player-only grass occlusion need deliberate extension for moving NPCs and more complex scenery. Profile tile rebuilding, solid-cell sprites, and unbounded battle-sprite caching before optimizing. [Overworld](../../Source/world/overworld.lua), [NPC](../../Source/world/npc.lua), [battle sprite cache](../../Source/battle/battleScene.lua).

Battle art is an exception to runtime grid generation: 302 checked-in opaque 1-bit grayscale PNGs, with 32×32 backs and 40/48/56-pixel square fronts, fitted to 80×80 at runtime. Several scales are fractional. The exact upstream version/conversion is not recorded by a current generator. Three runtime keys—`nidoranF`, `nidoranM`, `mr`—do not match filenames `nidoran-f`, `nidoran-m`, `mr-mime`; direct lookups for their six views fail and rendering falls back to initials. This is a source-verified coverage defect, not a missing-file count. [Species keys](../../Source/data/pokemon.lua), [loader and fallback, lines 10–20 and 307–332](../../Source/battle/battleScene.lua).

## Harness: capability versus trustworthy validation

Existing autopilot supports collision-aware walking, direct warps, input injection, waits, dialog dismissal, intro/debug control, battle fixtures, RNG seed, state inspection, screenshots, per-frame captures, and atlases. Python publishes commands atomically and creates film strips with adjacent-frame difference counts. These are valuable manual iteration tools. [Host](../../tools/autopilot.py), [runtime bridge](../../Source/dev/autopilot.lua).

The most consequential gaps are:

| Finding | Evidence and consequence |
| --- | --- |
| Wrong screenshot destination | Lua line 42 points to `~/Developer/PlaydateSDK/PlayDate-Pokemon-PoC/tools/shots/`; Python line 33 uses this checkout. The legacy directory was absent, not a symlink. |
| Shared mailbox without ownership or identity | Both sides use fixed `autopilot.txt` / `autopilot-done.txt` under bundle `com.poc.pokemon`; no request/session/build ID or lock. Multiple agents/worktrees can consume or overwrite each other's work. |
| Errors count as success | Python `send()` returns true for any ack. **Runtime reproduced:** `research_unknown_command` returned `err unknown command…` followed by `done`, with process exit 0. |
| Timeout does not cancel | The host leaves the runtime command running; a delayed ack can contaminate a later request. |
| Unsafe arbitrary-state fixtures | `intro reset` can set `game.playerPokemon=nil` during a live battle whose finish dereferences it. Mid-step warp does not clear interpolation. These consequences are source-derived; destructive sequences were not exercised. |
| Seed does not isolate gameplay | BattleScene draw consumes global `math.random` for shake, sharing the rules RNG. Input wrappers OR in real keyboard input. |
| Timing is ambiguous | Autopilot runs before update/input/draw; shots use the last completed display frame, press ack precedes input handling, and movement can finish before doors/story consume the completed-step flag. |
| Weak diagnostics | Plain text, short root-only transition log, no full nested trace, heartbeat, semantic assertions, reproducible state snapshots, or build handshake. |
| Atlas is incomplete | Seven of twelve player direction/stride images, sixteen NPC facings, and base tiles only. No animated-frame catalog, full maps, battle art, or automated baseline comparison. Comments claiming image identity diffs exceed current functionality. |
| Build and dependency gaps | No executable gameplay test suite/CI/test target/dependency manifest found. SDK environment was unset; system Python lacked Pillow. Make's clean/compile/run sibling prerequisites can race under `-j`. |

Sources: [host lines 32–63 and 74–79](../../tools/autopilot.py), [runtime bridge](../../Source/dev/autopilot.lua), [reset](../../Source/game/story.lua), [battle finish](../../Source/game/battleState.lua), [draw RNG/timers](../../Source/battle/battleScene.lua), [build targets](../../Makefile).

Project guidance records unreliable `open -a`/`make run` reloads and recommends direct binary launching. This audit successfully used a direct launch of the newly compiled bundle, but did not reproduce that historical reload failure. A future harness should own and terminate its exact PID instead of broadly killing all Simulators.

Rules tests cannot simply import everything into stock Lua 5.4: for example, `lib/oop.lua` contains Playdate `+=` syntax. Use the SDK or make a deliberate compatible rules subset; do not silently test altered code.

## Combat/data gaps that a better harness should reveal

- `Pokemon:init` claims level-aware moves but always selects the final four entries; the data has no move levels. Intro-only overrides hide this for starters. Level-up recalculates stats but does not learn moves. [Species class, lines 783–902](../../Source/data/pokemon.lua).
- Of 419 move entries, 87 have `category="status"` without an `effects` field. This is an audit queue, **not 87 proven bugs**: Splash is intentionally ineffective, whereas Protect, Rest, Transform, and Metronome have no behavior in the current dispatcher. Hyper Beam/Solar Beam likewise have no recharge/charge fields in the present implementation. [Move records](../../Source/battle/moves.lua), [execution](../../Source/battle/battle.lua).
- Player PP decreases at selection, enemy PP is not consumed, and the UI refuses zero-PP moves without a Struggle path. The rules interface does not independently enforce all UI preconditions. [Select/turn logic](../../Source/battle/battle.lua), [menu](../../Source/battle/battleScene.lua).
- `BattleState:finish` clears major status on every exit; blackout restores the single Pokémon and uses current-zone spawn. Full campaign healing/blackout and persistent statuses need explicit rules. [Lifecycle](../../Source/game/battleState.lua).
- Damage totals used by drain/recoil include computed overkill rather than actual HP removed. Fixed-damage DSL effects bypass the powered-move immunity branch. Tie order favors the player. These code paths need independent Gen V reference cases, including simultaneous fainting/outcome order. [Battle rules](../../Source/battle/battle.lua), [DirectDamage](../../Source/battle/dsl.lua).
- XP uses a flat formula and one simplified growth curve; stats omit IV/EV/nature inputs. These are implementation facts, not certification of authentic B2W2 behavior. Validate the chosen rules and label intentional simplifications accurately. [Pokémon calculations](../../Source/data/pokemon.lua).
- The existing verifier reads species move names, fetches **Black/White**, and compares sets, losing levels/order. It does not test move effects, data values, or runtime behavior, and report errors do not fail the CLI. The generator targets B2W2 but downloads mutable branches and trusts caches. [Verifier](../../tools/verify_moves/main.py), [fetcher](../../tools/verify_moves/fetch_pokeapi.py), [comparison](../../tools/verify_moves/compare.py), [generator](../../tools/generate_gen5_data.py).

No party, capture, bag/items, disk saving, evolution, complete campaign, or sound/music implementation was found in the tracked source. The battle menu currently offers FIGHT/RUN. Full-game work must build these interacting systems, rather than treating 151 records as 151 complete gameplay implementations.

## Runtime evidence from this research

The unchanged game source compiled successfully using installed Playdate SDK **3.1.2**:

```sh
PLAYDATE_SDK_PATH=/Users/burbujamc/Developer/PlaydateSDK make compile
```

A separate directly launched Simulator process answered `gamestate` with `overworld>dialog`, Red's Room, `pre_oak`, player `5,3`. The pre-existing Simulator process was left untouched.

To capture the unchanged build despite its hard-coded screenshot path, this research temporarily created the missing legacy output directory. Artifacts were copied into [runtime-evidence](runtime-evidence/); the workaround is not a harness fix. No game source was edited.

Observed smoke actions: opening dialog dismissal; tile/sprite atlas output; intro skip; a normal walk to bedroom stairs; entry to Red's 1F; edge exit into Pallet; step entry into Oak's lab; seeded wild battle fixture and battle menus. Direct warps positioned some shots. This does **not** constitute a natural intro playthrough, rival outcome test, completed battle, deterministic replay proof, or hardware test.

Images were visually inspected at their captured resolution. They show the current tuned silhouettes, dither, room framing, terrain, and battle presentation; the existing atlas labels overlap and its coverage is incomplete. See [manifest](runtime-evidence/manifest.json) for image hashes and source fingerprint. These are research observations, not automatically accepted golden baselines.

## Proposed implementation direction

First qualify the harness with a versioned protocol, single runtime owner, actual-build handshake, safe reset, semantic failures/cancellation, explicit timing, and isolated output. Then introduce rules/content/Simulator checks through narrow, production-used interfaces. Keep fixture tests and real player journeys distinct.

Create two visual references: the reviewed current Playdate appearance and pinned original material transformed through documented adaptation rules. Exact sprite/mask diffs protect preservation; actual native-size and motion review assess readability and fidelity. Use controlled defect injection to prove that validation fails when it should.

Preserve the current OOP/StateMachine/DSL foundation. Separate immutable definitions, persistent session state, and rebuilt views. Introduce party, inventory, quest/event, and save ownership incrementally; provide one interface for collision-changing world mutations. Trace nested transitions and define animation versus logical progression under overlays.

Pilot a deterministic new-map/character generation workflow before bulk production. Make every generated asset traceable and make unsupported input fail. Validate geography, warps, prerequisites, occupancy, interactables, and visual layout together. Finish dependency-ordered campaign stretches with Astra validation after integration.

## External primary references checked

- The [official Playdate 3.1.2 manual](https://sdk.play.date/3.1.2/Inside%20Playdate.html) documents `pdc`, command-line Simulator execution/arguments, stdout logging, screenshots, and performance/memory tools. Its 30 FPS recommendation agrees with this game's target. Use installed-version documentation when implementing the harness. The proposal to combine those capabilities into a reliable runner is our design inference.
- The original reconstruction separates map block data, headers, object/warp events, and scripts: [pokered map assembly](https://github.com/pret/pokered/blob/master/maps.asm), [Pallet header](https://github.com/pret/pokered/blob/master/data/maps/headers/PalletTown.asm), and [Pallet objects](https://github.com/pret/pokered/blob/master/data/maps/objects/PalletTown.asm). This supports investigating a structural importer; it does not prove existing Pallet is an exact original layout. Pin a commit before production generation.
- [Official subagent documentation](https://learn.chatgpt.com/docs/agent-configuration/subagents) describes model inheritance and explicit model selection. The tools in this research session exposed `gpt-6.1-sol`; two bounded source-audit workers were explicitly spawned with that model. A future session must inspect its own runtime support rather than assume configuration or inheritance.

No original ROM execution comparison, exhaustive Gen V rules oracle, full campaign inventory extraction, physical-device profiling, or broad playthrough was performed in this prompt-writing task.
