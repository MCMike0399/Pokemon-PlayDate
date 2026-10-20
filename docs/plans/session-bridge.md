# Authoritative session bridge

Root integrated the bridge after215 native contracts passed. Subsequent ownership,
party and field UI integration passed244 contracts and fourteen native jobs,
including all3 intros, checkpoint blackout and real two-process Save/Continue.
[Durable evidence](../validation/accepted-session-gameplay/acceptance.json).
The original handoff remains `/private/tmp/pokemon-session-bridge`; do not reapply
its old files over the current context, fixtures or battle owner.

## Ownership and API

`GameContext.session` is the sole durable owner. `getPlayerPokemon()` derives `session:activePokemon()`; no mutable `playerPokemon` field or metatable alias remains. `recruit(mon)` transfers the actual object into party/current box using existing domain ownership rules.

- `getSessionDependencies()` supplies production ItemData, pure WorldDeltas validation, and location resolution. Optional constructor `sessionLocationPolicy` passes the root's explicit slice whitelist to the resolver; the default stays strict.
- `beginNewSession(seed)` creates and installs an empty party/bag with 3000 money and bedroom location/checkpoint `(5,3,up)`. Construction alone stays inactive and leaves the global RNG and Story facade owner untouched.
- `captureSession()` returns aggregate primitive payload or `nil,error`, requiring the actual root overworld, stack depth one, explore substate, and settled Player after step triggers. It captures world and position atomically through `captureTraversal` before encoding.
- `installSession(candidate)` validates the entire aggregate first, applies candidate world, explicitly activates candidate RNG, binds the Story facade, and rebuilds overworld at its saved coordinates. Durable owners roll back on renderer rejection. It returns `true` or `false,error`; it does not resume an obsolete coroutine. A repeated renderer failure can still require the root error/title controller to rebuild a view.
- `returnToCheckpoint()` resolves the persisted checkpoint against current world and enters that exact location. Center healing must separately capture a new checkpoint.

No method writes save files or adds boot/menu UI. Root's GameSaves owns those concerns.

Story methods use an explicit game context and atomic `session:setIntro` tuples. `Story.bind(game)` installs a read-only facade for existing authored-map dialogue closures; writes to `Story.stage/starter/rivalStarter/rivalOutcome` fail. `Story.notifyBattleEnd(game,won,kind)` uses the actual battle owner. Opening/starter/rival dialogue text is preserved.

NPCs bind to `def.source_event_id`, or `authored:<zone stableID>:npc:<definition index>` for existing authored actors. `hasInteracted`, mark, reset and rebuilt dialogue read session trainer flags; authored `def.interacted` is never written by the bridge. Contextless catalog NPC managers still work. Existing unresolved imported blocker objects remain blockers, not invented actors.

Explicit development reset APIs replace fixture Pokémon through a detached aggregate and keep the protected runtime owner coherent; debug level reset preserves the party object's identity. Ordinary empty sessions never receive a fallback Pokémon.

## Battle return policy

The intro rival fight retains its existing lab respawn/goodbye/healing exception. Ordinary all-party blackout heals the party, selects its first usable member, and returns the persisted checkpoint (initially Red's bedroom). The staged wild-blackout journey therefore expects bedroom `(5,3)` instead of Pallet's historical zone spawn `(5,6)`.

Forced switching is now integrated: a fainted active member with usable reserves
keeps the battle running and requires a valid replacement. A final recoil victory
may select a usable field lead without healing the fainted member. Native forced
and voluntary switch journeys pass; capture presentation polish remains pending.

## Integration and validation

Apply the manifest-owned patch after checking original hashes. Root main registers the nine-group suite with:

```lua
import "dev/sessionBridgeContracts"
Contracts.register("session-bridge", SessionBridgeContracts.run)
```

For protected no-save startup, replace old `Story.begin(); machine:change("overworld")` with `assert(game:beginNewSession(RulesRNG.snapshot().seed))` and keep the same opening-dialog push. Root's GameSaves startup can perform this instead. Keep root's new saves/title/pause/party/bag files intact.

Compile-only validation against current Source passed at `/private/tmp/pokemon-session-bridge-compile-02`. The root-owned helper overlays only owned Source files and privately adjusts main; it does not copy a historical Source tree over other workers' modules:

```sh
python3 /private/tmp/pokemon-session-bridge/validate_staged.py --project "$PWD" --output /private/tmp/pokemon-session-bridge-runtime-01 --execute
```

Only root may execute that Simulator command. Nine added production-seam groups cover inactive construction, exact party identity, Story ownership, trainer rebuild persistence, actual SDK Player save gating, install publication, renderer rollback, full-party checkpoint blackout, and usable-bench behavior. Existing combat contracts now use real context recruitment/session tuples and verify trainer flags without mutable definitions. No native execution is claimed by the worker.

Root should run all contracts, natural intro, wild return/blackout, fixture resets from battle/dialog/door, protected catalog comparison, then actual New/Save/Continue and party/bag UI journeys. Sleep-duration/codec3 and party-battle staging from the rules worker are separate changes; merge their fixture hunks into the migrated combat contracts rather than replacing this file wholesale.

Initial money matches pinned original Blue `engine/movie/oak_speech/init_player_data.asm` at pokered `af519899719f0754965776faac0e836a3b906e6d` (`DEF START_MONEY EQU $3000`, packed decimal). No art, map definition, growth rules, or existing aggregate codec changes are part of the bridge.
