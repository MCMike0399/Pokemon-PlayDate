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
