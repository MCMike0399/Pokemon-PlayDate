# Private S.S. Anne presentation follow-up

This follows the preserved `d1c5b5e` scene packet. The isolated
`wip/anne-surge-scenes` branch merged **exact root packet
`4c851502d89a4faa1e37fabf93a16e27c4dbfc3e`**, producing merge `4c66f84`.
Root already has that packet; cherry-pick only this follow-up's implementation
commit. No runtime, Simulator, push, delegation or acceptance is claimed.

## Root calls and composition seam

Add ONE production import before the existing story imports/installation:

```lua
import "game/vermilionShip"
```

It imports the new `vermilionShipArt` and `vermilionShipTimeline` modules.
`vermilionStoryState` now creates and advances the presentation before invoking
the unchanged `VermilionStory.commitIntent(game, "departure")`. The existing
pending actual-exit intent, HM01 guard, session transaction, world/RNG guards,
DoorWarp and automatic walking remain the only progression/traversal owners.
Hooks add `VermilionShip.beforeSpawn(game)` and `VermilionShip.onLeave(game,
destination)` to their existing boundaries; no second dispatcher is installed.

Root checkpoint **`bad58824b0db68344ebfb11dd5ec22f5fe4ad613`** was inspected
read-only after this packet's work began. The superclass now preserves its exact
`VermilionGiftsState` line. Root's chain remains DaycareState → VermilionStoryState
→ VermilionGiftsState → KantoServicesState, with one registered `event` state.
This branch did not merge or edit root's newer active session/field/Day Care APIs.
The final private SDK stage uses those exact checkpoint files plus this packet.

Optional future audio registration:

```lua
VermilionShip.setAudioSink(function(cue)
    -- cue.symbol and cue.source_frame are pinned source identities/timestamps.
    -- Route to the future audio owner; this callback must not yield, drive UI,
    -- mutate story/session/world, or replace the current context.
end)
```

Without a sink the presentation records cues and plays no sound. Installing a
sink still reports audio as unaccepted until root verifies actual playback.
The four cues are STOP_ALL_MUSIC and MUSIC_SURFING at source frame 0, and
SFX_SS_ANNE_HORN at source frames 130 and 1156. Original sound-engine scheduling,
previous-SFX waiting and audible output remain unaccepted; no fake audio was
added. The next map's ordinary music belongs to its existing map/audio owner.

## Original pixels and clock

`tools/generate_vermilion_ship.py` verifies SHA-256 pins at immutable pokered
`af519899719f0754965776faac0e836a3b906e6d`. Its vendored references are under
`tools/references/vermilion-ship`. Source/art/timing output is only
`Source/data/vermilionShip/{art,timing}.json`.

- Hull cells are the actual dock layout/blockset/ShipPort PNG at source cells
  `(10..17, 3..5)`, converted by the existing shared grid functions. Native art
  uses `TileFactory.renderGrid(..., nil, {0,0})`, with no hand drawing or changes
  to the protected renderer/art.
- Source scanline band `$50..$7f` maps to the dock's world rows 3..5. It is
  presented at the existing 2× source scale and camera offset, rather than
  stretching the 160×144 Game Boy viewport onto 400×240. A fixed world band
  preserves the dock/player above it; the source hull moves west two native
  pixels per one-pixel source step.
- The smoke is the original `gfx/overworld/smoke.png`, repeated four times by
  LoadSmokeTileFourTimes. Original OBP1=$00 means source index 0 is transparent
  and EVERY nonzero index is white. The original mask is retained; no grey
  cloud or flood-fill silhouette was invented.
- EmitSmokePuff rewrites OAM block 1 (entries 4..7), so one four-tile puff is
  shown at a time. Its 8-bit X wrap, offscreen range, two-pixel drift per source
  step, and 16-pixel decrement on each of eight chunks are preserved.
- The clock records source frames, advancing two per native 30 Hz update.
  Each scroll pixel lasts **eight source frames / four native updates**.
  Existing player/NPC movement remains eight native frames per cell. No actor
  coordinates, source motion leases or movement constants were changed.

Fixed source phases (source frame boundaries):

| Phase | Start | Duration |
|---|---:|---:|
| Four single-tile smoke loads | 0 | 4 |
| Initial DelayFrames | 4 | 120 |
| Three-frame screen copy plus Delay3 | 124 | 6 |
| Eight chunks × sixteen pixels × eight source frames | 130 | 1024 |
| Erase CopyVideoData (12 tiles) | 1154 | 2 |
| Second horn / final DelayFrames | 1156 | 120 |
| Two player graphics copies (12 tiles each) | 1276 | 4 |
| Dock script's pre-walk Delay3 | 1280 | 3 |

The presentation completes at source frame 1283, the 642nd native update.
These are explicit source-loop/transfer waits, not a ROM emulator or a claim of
CPU/scanline-cycle equivalence. Horn waiting depends on an unavailable audio
engine and is explicitly not accepted.

The visual band clears at the source erase phase AFTER all 128 scroll steps.
**No durable hull erasure, collision change or departure flag is committed until
the final presentation/walkout delay completes.** The transaction then runs once
through the existing owner and retains the water band through overlay pop and
DoorWarp fade. This prevents the source map's unchanged upper hull from flashing
back before actual dock exit. A different session/player/zone is cleaned at
beforeSpawn; actual onLeave removes the retained graphics. Cancellation before
commit removes only temporary images/sprites, leaving source flags, world and
both RNG streams intact. Premature advance fails before attempting a transaction.

The temporary weak per-context view index holds graphics only, never progression
or an alternate world ledger. Cues originate in owned updates, never draw or
snapshot. Stale session/player/zone/epoch updates cannot advance the visual clock.

## Missing closed-door dependency is now generated

The narrowly scoped extension to **`tools/generate_vermilion_preparation.py`**
appends only the absent original Gym block `$24` quadrant to VermilionGym's grid
inventory. It uses the existing shared PNG decoder, quadrant composer and source
collision list. It preserves every existing grid, local tile ID and layout cell.
The original `$24` bottom quadrants are already ordinary floor and are reused.

The prepared outputs now include **`pokered:GYM:cell:20-21-30-31`**, with solid
collision, both in `proposed-compact.json` and `proposed-tile-grids.json`.
VermilionGym's prepared source hash/manifest entry and proposed manifest/cache
fingerprints/provenance were regenerated through the existing shared builder.
No active 30-map manifest/cache, shared decoder, domain/core, protected image,
baseline or coverage file was edited.

Root should promote/regenerate the updated prepared outputs with its ordinary
65-map activation, rather than copy a grid into a live registry at runtime.
Existing `VermilionStory.sourceWorld` can then project the closed door without
its former missing-key failure. Nothing here activates the 35 new maps.

The exact promotion path is:

1. The preparation generator appends the `$24` source grid to
   `data/vermilionPreparation/VermilionGym.json` and recomputes that entry's
   `source_sha256` in `manifest-entries.json` and `proposed-source-maps.json`.
2. Root promotes the updated 65-map proposal/decoded inputs, retaining its own
   blocker, arrival, LAST_MAP and connection metadata.
3. Root runs the existing `generate_source_map_cache.py` against that promoted
   manifest and Source root into a **fresh review directory**. The builder walks
   ALL definition grids, including grids not referenced by the initial layout.
   It therefore emits the closed door's bitmap in `tile-grids.json` AND its
   collision/terrain record in `compact.json`. Their manifest fingerprints
   must match the promoted manifest. Root publishes both outputs together.
4. Runtime SourceMaps reads that shared cache, and the existing provider's
   ensureKeys path loads the pinned grid when WorldDeltas applies the closed
   door. No scene-time registration or alternate atlas is introduced.

`generate_vermilion_preparation.py` now supports both uninstalled 30-map and
fully installed inventories. `verify_installed_entries` checks ALL generator-
owned entry fields (identity/key/path/profile, dimensions/padding, source hash,
spawn), rejects partial installs and owned-field drift, and preserves root's
extra activation metadata. Installed generation does not union the batch twice
or overwrite root metadata. The original strict artifact verifier and all source
pins/preservation checks remain intact. If root changes activation metadata
relative to this historical proposal, regenerate into a fresh prepared output
before strict `--check`; stale proposal/cache fingerprints still fail visibly.
Installed-inventory host tests exercise the real shared cache builder with a
65-map fixture manifest without writing any active manifest/cache file.

## Checks and native work still pending

Host commands, with the project environment sourced:

```sh
python -m tools.generate_vermilion_ship --check
python -m tools.generate_vermilion_preparation --reference "$POKERED_REFERENCE_DIR" --check
python -m unittest tools.tests.test_vermilion_ship tools.tests.test_vermilion_preparation tools.tests.test_vermilion_story tools.tests.test_source_events tools.tests.test_vermilion_installed_inventory -v
```

The 50 scoped tests pass, zero skips. Ten new primary-source host checks compare
hull/water/smoke pixels against original PNGs, blockset/layout bytes and palette;
verify immutable external/vendored source hashes and mutation rejection; check
clock/cue constants and original helper waits; prove closed-grid metadata is
in the prepared shared lookup; and verify active 30-map bytes remain unchanged.
Host code neither executes/transpiles Lua nor simulates the SDK.

Prepared native registration (root owns the dev import overlay):

```lua
import "dev/vermilionShipContracts"
Contracts.register("vermilion-ship", function()
    return VermilionShipContracts.run(VermilionStoryFixture.withScene)
end)
```

The existing story fixture now also cleans temporary ship views. New real-SDK
witnesses cover all hull pixels at explicit zero phase, the exact smoke mask and
palette, eight-source-frame pixel cadence, cue order/once-only owned emission,
no progression/RNG during presentation/draw, cancellation while moving, early
advance, stale session/player/epoch, authorization, end-of-presentation commit,
and retained water through overlay pop until actual world exit. There are no
skip/fallback paths. They require the actual provider-owned installed maps and
root APIs, and have **not run**.

SDK compile-only evidence lives under `$POKEMON_ENV/evidence/`:
`anne-surge-ship-build-20261026-01` (standard harness compile), and
`anne-surge-ship-root-checkpoint-compile-20261026-01` (private stage based on
exact bad5882, with its field-epoch-aware API and explicit new ship/test imports). No Simulator was launched.

Root must still compose/publish imports and prepared content, execute the real
SDK suites and ship exit/restart scenarios, inspect source scroll/smoke/fade,
verify sprites/resource cleanup and actual player walkout, compare protected
catalog art, and complete natural campaign acceptance. Source-backed host art
and successful compilation do not establish native motion, audio, device or
milestone acceptance. **No 5.4 completion claim.**

**Do not apply the historical session API patch over bad5882.** Root's active
API already binds scene tickets to the current field epoch and invalidates that
epoch after successful scene commits. This work does not alter or replace it.
The session API patch asset's changes in this follow-up are readability only (expanded
sceneEqual, pcall/error branches and tables). Active core/session APIs were not
changed. Hooks and State's pre-existing guards/callbacks were similarly expanded;
only the documented ship presentation calls change scene behavior.
