# Source encounter API on merged root b2fccc7

Existing FieldBattle/Battle/BattleState/GameSession now admit and resolve source
Marowak and Route12/16 Snorlax requests. The new domain/sourceEncounters module
has only pinned definitions and pure validation/planning; all live identities,
real capture intents and disposable receipts are private GameSession values.
There is no scene-owned encounter store and no serialized battle/receipt phase.

`FieldBattle.startSourceEncounter(game,request)` requires the owning valid event,
settled source coordinates, completed source guards and an active session RNG.
It rejects altered species/levels/rules/outcome flags, missing flute, completed
actors, bad coordinates and stale ownership before publishing specimen RNG.
Specimen creates through the existing wild protocol. Battle construction receives
its source context and GameSession binds policy BEFORE the immediate intro and
markSeen. Ordinary Tower3F..7F wild battles without an actual Scope get the same
unidentified policy; their actual slots/rates/specimens stay with FieldEncounters.

Unidentified opponents announce GHOST, do not mark the hidden species seen, and
block both sides' moves before PP/damage. Existing major sleep/freeze gates still
run. Scope reveals Marowak through original source text and normal seen entry.
Both identified restless Marowak and unidentified Tower ghosts dodge every ball,
including Master Ball: the real ball is consumed, no capture RNG is drawn, no
specimen is recruited, and the enemy receives its real turn. Ordinary captures
retain their previous code path. Normal battle weather/status ordering is not
redefined; an unidentified indirect victory cannot grant the Scope story flag.

Source Snorlax uses actual Capture.attempt. Failed attempts consume the ball and
RNG normally. A successful roll stores its actual intent while capture messages
run, without placing a second copy in party/storage. Only actual terminal caught
emission commits the SAME enemy identity, selected destination, Pokédex and only
that Snorlax flag together in GameSession. Full party goes to the selected box;
full box rejects before a trial/consumption. Cancellation before terminal claims
no Pokémon/completion, retaining already-real ball attempts. Confirmed victory
or run removes that source Snorlax, defeat leaves it retryable, matching Blue.
Ghost completion requires actual identified victory. Forged/unconfirmed endings,
wrong enemy/party/session, stale guards and repeated completion are rejected.
The existing BattleState still owns blackout, money loss, Pickup and learning.

Root applies only `source-story-battle-hooks.patch` for EventState's explicit
one-shot receipt consumption and the scene's completed=false ghost return guard.
BattleState integration is already implemented here; do not reapply the old
BattleState portions of that patch. Receipts are
`{id,zone_id,confirmed=true,kind,completed}`. Observations must not consume them.
No main import is needed: GameSession imports the domain helper itself.

`Battle:opponentDisplayName()` exposes GHOST without altering the Pokémon name or
species. Root/UI should use that getter and `battle.sourceEncounter.unidentified`
for the source ghost image; this worker has no ownership of battleScene/art and
does not claim unidentified ghost rendering acceptance. Scope reveal text and
Pokédex gating are implemented. Exact source ghost dodge text is transcribed
inside Battle's source-only refusal; no additional text resolver is installed.

The existing Dojo guard_flags/extra_flags patch is applied in GameSession.
Its extra selected-species flag commits in the same existing gift transaction;
old gift calls keep their original defaults and semantics. Root's elevator
scripted_warps changes remain separate and this branch edits none of those files.

Worker validation is SDK compile-only plus proportional host source checks.
Root alone executes the behavior contracts/native encounters and Save/Continue.
Common source text registration and source ghost sprite presentation remain root
composition work, not claimed runtime acceptance here.

## Follow-up after root 9d3aab4

Merged exact root 9d3aab4 for compilation. Root already applied EventState's
one-shot source receipt hook there; do not apply that hunk twice. The small
Tower return completed=false guard in source-story-battle-hooks.patch remains
root-owned. Source encounter outcomes now also expose actual source_id and
source_completed in game.lastBattleOutcome; this is observation only.

The supplied commitCycling method is also installed in GameSession, with one
necessary correction: Bicycle mode is reversible and its forced source bit may
stay false. It uses the existing guarded transactSourceEffects rather than the
one-time transact, which intentionally rejects false->false flag changes. Mode
DTO, source bit and settled actors are preserved, field epoch advances, stale
contexts fail, and SessionCodec stays schema4. GameSession imports FieldCycling;
root's runtime UI/field request composition remains separate.

`dev/sourceEncounterContracts.lua` contains exactly one contract for each new
behavior: source ghost policy, source Snorlax terminal/capture ownership, the
exclusive Dojo gift, and the reversible Bicycle session commit. These use actual
Battle commands, Capture.attempt, Party/Storage/Inventory, GameSession and codec.
They do not inject outcomes, HP faints or successful catch results. Creature and
quest prerequisites are unit setup, not earned-save or journey evidence. Capture
covers party/selected-box destination, full selected box, pre-terminal refusal,
interruption and source-specific removal; ghost covers unmasked intro/Pokédex,
no-PP fear, actual ball consumption, Scope and genuine combat victory. The
existing paid/ordinary gifts retain their existing checks.

Root registration is the two-line source-encounter-contract-registration.lua.
Worker compiled the actual SDK harness with --build-only at environment evidence/
source-encounter-contract-compile-20261028-01; no Simulator or contracts executed.
Root should run this four-behavior suite once alongside its current field battle,
capture, pickup, gift and session checks. No driver/fixture contract is added.

`captureTraversal` now accepts optional internal `cyclingForced:boolean`. Inside
its existing preparation pcall it copies/validates questFlags, applies only the
existing FieldCycling.FLAG, and validates actors against those candidate flags.
Location/world/checkpoint/travel/actors and flags publish only after all validation
succeeds. No post-location transact or new schema field is used. The SAME Bicycle
behavior contract now covers failed boolean/actor rollback, real source Route16
entry, mode/flag publication and codec round trip; no fifth contract is added.

The newest compile-only evidence is source-encounter-contract-compile-20261028-03.
For root's current merged controller, apply ONLY source-ghost-return-root.patch;
EventState receipt consumption is already installed. Root may read actual source
outcome through lastBattleOutcome.source_id/source_completed without consuming a
receipt. False completed remains an explicit boolean. Native execution, earned
saves, frame/art inspection and process Continue remain root work.

Known source limit: existing Poke Doll item use is still unsupported/loud in the
shared Bag/item flow. The original Blue Doll/Marowak escape bypass is therefore
not claimed by this packet; ordinary run and real identified victory are handled.
Unidentified ghost battle sprite/name/cry presentation needs root/UI to honor the
new policy/getter. No battle art, UI, audio, codecs or shared field files were
edited here. Source context invalidation during a bound encounter is refused,
and cancellation cleans up the battle's actual session even after replacement.
