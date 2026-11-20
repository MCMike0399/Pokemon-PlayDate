# Cerulean inflate, session 181de250

Lane E `d010ec62678d53f41e33e2d83ba1fe946d310fa4`. One fresh Simulator process. `MallocPoolSize` stayed `16645684` (`/home/ubuntu/.config/Playdate Simulator/Playdate Simulator.ini`, SDK 3.1.2). The city `switchZone` returned. The inflate failed on the cave door one step later.

## Boot route

The process did not press Continue or New Game.

1. `tools/harness/run.py` launched `/home/ubuntu/Developer/PlaydateSDK/bin/PlaydateSimulator` on `/tmp/lane-e-hall/cave/Harness.pdx` (pid 8698). Bundle id `com.poc.pokemon.harness.181de250fb4449d3b86a7a7c383b3489`.
2. Ready, harness tick 1, `time_ms` 10815. Root `title`, `title.phase` `intro`, zone `test_zone`. Lua heap `12711.265` KiB.
3. `GameSaves` ran at boot-trace sequence 370–371. There is no `Continue.begin` or `New Game` mark.
4. The only request started at tick 3 with a fixture. That fixture is the first input.

Archived data dir `/tmp/lane-e-hall/cave/runtime-data` has no `adventure.a.json` and no `adventure.b.json`. The ready checkpoint is the unsaved default `pallet_town` (5, 6) facing down. There is no save file and no save sha.

## Fixture that placed the player in Cerulean City

`Source/dev/fixtures.lua` calls `switchZone(options.zone)`, then `machine:change("overworld", { respawn = true, entry = options.entry })`. This request's zone was `kanto_cerulean_city` at entry (4, 13) facing up. That command finished `ok` at tick 3. The player was settled there. Lua heap `13383.384` KiB.

Boot-trace for that load:

| sequence | phase | clock_ms | heap_kib | observed_peak_kib |
| --- | --- | ---: | ---: | ---: |
| 390 | map.CeruleanCity.definition.begin | 11077 | 12848.604 | 13015.498 |
| 393 | map.CeruleanCity.art.end | 11139 | 13181.685 | 13181.685 |
| 395 | map.CeruleanCity.zone.end | 11186 | 13594.846 | 13594.846 |
| 403 | overworld.actors.end | 11280 | 13644.707 | 13644.707 |

## Inputs through the failure

Request `00001-fa46adb5cdea45aa893ce47b2cbb879c`, `max_frames` 18000. Commands, in order:

1. fixture `{ intro = "skip", seed = 11, zone = "kanto_cerulean_city", entry = { x = 4, y = 13, facing = "up" }, player_pokemon = { species = "blastoise", level = 65, moves = { "surf", "hydroPump", "skullBash", "rainDance" } }, quest_flags = { BADGE_SOUL = true, EVENT_BEAT_CERULEAN_RIVAL = true, EVENT_GOT_SS_TICKET = true, TOGGLE_CERULEAN_CAVE_GUY = true, TOGGLE_CERULEAN_ROCKET = true } }`
2. `wait 20`
3. `encounters off`
4. `encounters off`
5. `move up` — city (4, 13) to (4, 12), settled at tick 34
6. `move up` — city (4, 12) to (4, 11), settled at tick 42
7. `move up` — not completed

Commands 1–6 returned `ok`. Command 7 was in progress at the error. No button was pressed. `move` calls `Player:tryMove`.

Tick 43, still command 6, still city (4, 11) facing up: the overworld substate changed `explore` to `doorWarp`. Heap `13507.356` KiB. The tile is source warp `pokered:CERULEAN_CITY:warps:7` (x = 4, y = 11) to `CERULEAN_CAVE_1F`.

## Failure

Harness tick 44, `time_ms` 13063. `runtime-error.json` error string:

```text
pd_readcompressed inflate failed, out of memory
```

`result.json` records the same string at tick 44, `time_ms` 13069. Six commands had completed. The captured frame `frames/failure.png` is solid black, which is the door fade once `frame / 12` is at least 2/3.

Snapshot at the error:

| field | value |
| --- | --- |
| root stack (`StateMachine:stackNames`) | `overworld` |
| overworld substate | `explore` |
| zone | `kanto_cerulean_cave_1f` / `pokered:CERULEAN_CAVE_1F` |
| player | (24, 17) facing up, settled, not moving |
| Lua heap in `runtime-error.json` | `13651.529` KiB (`collectgarbage("count")`) |
| Lua heap in `result.json` | `13676.414` KiB |
| boot-trace observed peak | `13857.402` KiB |

The Lua string has no file and no line. The harness update is `pcall(updateGame)` and passes `tostring(message)` through. It does not call `debug.traceback`. `GameBootstrap.fail` did not run: the boot trace has no `error.` phase and the simulator log has no `BOOTERROR`. The state-machine stack above is the only stack the session stored.

Last boot-trace row written is sequence 427, `door.map.end`, clock 12878, heap `13777.843` KiB, peak `13857.402` KiB. That mark is after `switchZone` of the cave and after `OverworldState:enter` (field reload, view, actors). Cave build rows:

| sequence | phase | clock_ms | heap_kib | observed_peak_kib |
| --- | --- | ---: | ---: | ---: |
| 404 | door.begin | 12612 | 13527.634 | 13644.707 |
| 407 | door.map.begin | 12678 | 13527.998 | 13644.707 |
| 410 | map.CeruleanCave1F.definition.end | 12711 | 13598.376 | 13644.707 |
| 413 | map.CeruleanCave1F.art.end | 12746 | 13618.564 | 13644.707 |
| 417 | map.CeruleanCave1F.zone.end | 12813 | 13711.282 | 13711.282 |
| 419 | overworld.field_reload.end | 12831 | 13819.853 | 13819.853 |
| 424 | overworld.view.end | 12850 | 13748.660 | 13821.534 |
| 426 | overworld.actors.end | 12860 | 13857.402 | 13857.402 |
| 427 | door.map.end | 12878 | 13777.843 | 13857.402 |

The error is 185 ms after `door.map.end`, still inside tick 44. The cave definition, art, zone, view, and actors marks had already completed. The pool failure is the next compressed read after that mark, with the city still in the process.

## How the zone changed

Two different calls.

- City: harness fixture, direct `switchZone("kanto_cerulean_city")`. Returned `ok` at tick 3.
- Cave: the game door, not a second fixture. `DoorWarpSubstate:update` calls `switchZone(door.to)` inside `GameBootstrap.withLoading("door", ...)`. The destination was already `kanto_cerulean_cave_1f` when the compressed read failed.

`LinuxResidentGuard` was not attached. This was one `run.py` process, not `restarting.py`. No `VmHWM` sample was recorded. Pid 8698.

Harness-only setup that a production boot does not have:

- Staged `main.lua` imports `dev/harness_build` and the dev contract modules (`dev/contracts`, `dev/fixtures`, `dev/autopilot`, `dev/harness`, the cerulean and vermilion contract modules, and the rest of that import list).
- `HarnessBuild.enabled = true`.
- `encounters off` sets `DEBUG_FLAGS.noEncounters`.
- Fixture quest flags remove the cave guard, the rival, the rocket, and the ticket check. Those flags are not a Hall-continue save.

`tools/notes/lane-e-cerulean-city-inflate.patch` described this session as `switchZone("kanto_cerulean_city")` failing. The tick 3 result and the Cerulean City boot-trace rows contradict that. The fresh city switch completed. The inflate is the door out of that city while those dev modules and the city view were still live.
