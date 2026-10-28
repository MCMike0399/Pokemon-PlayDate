# Vermilion ordinary dialogue handoff

Prepared on `wip/vermilion-dialogue` from exact private 65-map revision
`e4dd1701caa28c69b90788fe77ea3b290735b7b7` (the root e4dd170 candidate).
This is implementation preparation. Root owns all runtime, native, visual and
campaign acceptance. No Simulator, runtime contract execution, push or delegation
was performed.

## Bound source objects

All IDs below begin with `pokered:` and end with the shown `objects:N`.

| Map and object | Complete ordinary program |
| --- | --- |
| `POKEMON_FAN_CLUB:objects:1` | Pikachu fan: when `EVENT_PIKACHU_FAN_BOAST` is true, Better text then clear that flag; otherwise Normal text then set `EVENT_SEEL_FAN_BOAST`. |
| `POKEMON_FAN_CLUB:objects:2` | Seel fan: when `EVENT_SEEL_FAN_BOAST` is true, Better text then clear that flag; otherwise Normal text then set `EVENT_PIKACHU_FAN_BOAST`. |
| `POKEMON_FAN_CLUB:objects:3` | Pikachu text, PIKACHU cry, source WaitForSoundToFinish cue. |
| `POKEMON_FAN_CLUB:objects:4` | Seel text, SEEL cry, source WaitForSoundToFinish cue. |
| `VERMILION_CITY:objects:2` | DidYouSee text before `EVENT_SS_ANNE_LEFT`; SSAnneDeparted text after it. |
| `VERMILION_CITY:objects:5` | Machop text, MACHOP cry/wait cue, then StompingTheLandFlat text. Autonomous WALK/UP_DOWN remains with NPCMotion. |
| `VERMILION_PIDGEY_HOUSE:objects:2` | Pidgey text, PIDGEY cry/wait cue. WALK/LEFT_RIGHT remains with NPCMotion and can defer interaction until its cell finishes. |
| `SS_ANNE_1F_ROOMS:objects:8` | Wigglytuff text then WIGGLYTUFF cry cue; no explicit source sound wait. |
| `SS_ANNE_B1F_ROOMS:objects:8` | Machoke text then MACHOKE cry cue; no explicit source sound wait. |
| `SS_ANNE_2F_ROOMS:objects:5` | Gentleman text, source Snorlax Dex display, then guarded seen addition when that display closes. Full Dex data remains limited to owned Snorlax. |
| `SS_ANNE_KITCHEN:objects:7` | MainCourseIs text; execution samples one actual WorldRNG byte. Bit 7 selects salmon; otherwise bit 4 selects eels; remaining bytes select beef. |

These are descriptors installed by the existing Vermilion source package. No
`vermilionAmbient.lua`, keyed Lua handler or alternate progression/controller
owner was needed. Fan branch selection guards both source flags until the final
transaction, including repeated sets and clears. Observation, planning, text
resolution, snapshots and drawing do not consume RNG or change session state.
The existing measured text renderer and pagination remain in use.

The eleven descriptors explicitly request transient interaction-facing
restoration; existing ordinary, guard, gift and story registrations remain intact.
Existing source movement reservations and eight-frame execution are unchanged.
There are no new explicit scripted paths in these primary interaction bodies.

## Root integration patch

Apply [the owner patch](vermilion-dialogue-root.patch) after composing this commit:

```sh
git apply docs/plans/vermilion-dialogue-root.patch
```

It touches only root-owned `Source/domain/gameSession.lua` and
`Source/game/pokedexState.lua`. It adds a bounded compare-and-set
`transactSourceEffects(expected, changes)` for ordinary boolean flags and seen
additions. It cannot grant items, mark owned, clear seen, or change RNG. It leaves
one-time inventory/reward transactions untouched. Without this patch, the new
fan and Dex interactions intentionally have a missing-owner dependency; the
worker did not mutate session internals in this branch.

The Pokédex patch adds a source display option to the existing renderer. It
shows the requested specimen without granting ownership, keeps full information
behind the actual owned bit, and returns through the event's guarded callback.
A/B closes the source display. Ordinary player Pokédex navigation remains as
before. Mark-seen occurs after closure; cancelled/stale callbacks cannot commit.
This is a platform presentation adaptation awaiting root visual acceptance.

Add only these lines to root-owned `tools/harness/dev_imports.lua`, after
`dev/kantoServicesContracts` and the other event suites:

```lua
import "dev/vermilionAmbientContracts"
Contracts.register("vermilion-ambient", VermilionAmbientContracts.run)
```

No new production module import, event-state registration or package installation
is required. The current composed EventState subclass chain delegates ordinary
plans to the same base executor.

## Source status and audio seams

The fan bits are actual pinned `EVENT_PIKACHU_FAN_BOAST` and
`EVENT_SEEL_FAN_BOAST`; departure uses the existing `EVENT_SS_ANNE_LEFT`.
No new EVENT constant represents a source status bit. Existing Old Rod/status
and gift mappings belong to their existing registrations and are unchanged.

Pinned `engine/events/display_pokedex.asm` sets and resets
`wStatusFlags5.BIT_NO_TEXT_DELAY` around the static Dex display, then adds the
species to `wPokedexSeen` after return. The current static renderer supplies the
no-typewriter presentation; only the session transaction owns seen state.
Pinned `engine/menus/pokedex.asm` also emits the Snorlax cry, sets/resets
`wStatusFlags2.BIT_NO_AUDIO_FADE_OUT`, and changes `rAUDVOL` from `$33` to `$77`.
Those transient audio controls are retained literally in the display descriptor
for the future `SourceAudio` owner; they are not saved quest flags.

Audio remains unimplemented. Each cry operation records an explicit
`audio_gaps` diagnostic through EventState, preserving species, source wait,
source Dex volume/fade controls and future owner. It advances without fake
playback or fake delays. Existing map music symbols/banks and hashes remain
unchanged. There is no audio timing or playback acceptance.

Trades (including the Route 11 gate youngster), link/network reception and both
binocular services remain reserved. The boarding guard, Chairman, Old Rod,
aides, Captain, rival, Surge and Day Care retain their existing separate owners.
Their preparation reservations remain historical ownership packets; no overlap
was registered or silently treated as completion.

## Checks and limits

Under `source ~/Developer/Pokemon-PlayDate-env/env.sh`:

- 57 focused host tests pass, zero skips: `test_vermilion_ambient`,
  `test_vermilion_preparation`, `test_vermilion_gifts`, `test_vermilion_story`,
  `test_vermilion_ship` and `test_source_events`.
- The eight new host tests independently compare pinned primary ASM and data,
  all 256 chef byte outcomes, flags, cry order/waits, seen behavior, overlap,
  UTF-8 and global-label recipe boundaries. They never execute or translate Lua.
- Regeneration changes only `events.json`, `scripts.json`, `reservations.json`
  and `provenance.json`, plus the source pin and generator. Decoded maps,
  manifest/cache proposals, trainer data, sprites and terrain/art remain exact.
- SDK compile-only succeeded both for the normal staged candidate and for a
  separate `Registered.pdx` with the root owner patch applied and the new suite
  explicitly imported/registered. Evidence:
  `~/Developer/Pokemon-PlayDate-env/evidence/vermilion-dialogue-compile-20261026-final`.
  The patched stage is only a reviewable compile artifact, not the branch.

Prepared SDK witnesses cover all four starting fan flag combinations per fan,
repeat/clear behavior and codec roundtrip; both departure pages; all six cry
programs; every chef partition boundary and prefix cancellation; unseen/seen/owned
Snorlax; stale/cancelled flag and Dex callbacks; session/player/zone replacement;
Pidgey deferred/cancelled interaction and facing; actual RNG ownership and pure
read/draw; source transaction rejection and ordinary-source overlap rejection.
These cases have compiled but have **not executed**. Root must apply the owner
patch, run integrated native contracts and inspect text, Dex, facing and motion
before claiming acceptance. Existing campaign and protected-art gates remain
root work. No ledger, coverage or baseline was updated.
