# Erika, Koga, Sabrina and Dojo scene packet

Prepared from pinned Blue source. This is source-only preparation, with no
Simulator/native acceptance. Content, rosters, shared session/world/main and
root event-controller composition remain with their owners.

Merge `MidgameGymStory.descriptors()` into the worker's registrations by each
record's `content`: midgameEast (Erika), midgameSouth (Koga), midgameSaffron
(Sabrina and Dojo). These exact reserved IDs are supplied:

- CELADON_GYM, FUCHSIA_GYM, SAFFRON_GYM `objects:1`.
- FIGHTING_DOJO `objects:1`, `objects:6` (Hitmonlee) and `objects:7` (Hitmonchan).

Leader descriptors are ordinary trainer plans. TrainerEvents commits badge,
leader flag and source gym-trainer deactivation atomically on confirmed victory.
TM21/TM06/TM46 are separate guarded ordinary trainer rewards; a full bag retains
the badge and leaves the TM retryable. No payout or roster is supplied here.
These source labels match the pinned scripts, including Koga's differently
named TM06 explanation. Source scripts do not have separate leader-loss dialogue;
the same battle-end label remains the battle owner's responsibility, not a
fabricated success gift. The source badge boosts/obedience are existing mechanics
owner policy and are not reimplemented by these story descriptors.

Import `game/midgameGymStory` and `game/midgameGymStoryController`, then call
`MidgameGymStory.install()` after content registration. Root's final existing
controller calls `MidgameGymStoryController.enter(self)` before parent enter,
and delegates `advance` before its parent, exactly like the earlier scene hooks.
All other behavior falls through the existing trade/daycare/vermilion chain.
Merge `MidgameGymStory.actorMetadata(id)` for Dojo balls into content metadata.
Only the chosen ball disappears; the unchosen ball remains and says not greedy.

Dojo auto-challenges at source (4,3), plus runtime horizontal padding. Master
victory atomically marks himself and four trainers defeated. It does **not** set
EVENT_DEFEATED_FIGHTING_DOJO; the source sets that only on taking one gift.
Do not invent a master-defeat check inside the ball script: actual source checks
only whether either gift was already taken. Each choice displays its source
species encyclopedia/cry, prints the source offer and asks Yes/No. Declining or
cancelling grants nothing. Both species are level 30. The current naming-screen
limitation remains in the existing gift owner; no new rename UI is introduced.

`source-pokemon-gift-flags.patch` is a small unapplied root session extension to
the existing purchaseGiftPokemon transaction. Optional `guard_flags` check both
choices still false; optional `extra_flags` add the selected species flag in the
same prepared commit as specimen, party/storage destination, shared completion
flag, Pokédex, inventory and RNG. It does not add a second gift owner. Lapras can
reuse the existing price-zero API without these optional fields. Root owns the
application and SDK contract for the new guarded-gift behavior.

A full party sends the original species to the selected PC box through existing
GameSession behavior. A full selected box fails without claiming either choice,
flags or RNG; source `_BoxIsFullText` remains available for retry. Bag capacity
has no bearing on Pokémon gifts. Content text registration needs original common
`_GotMonText`, `_SentToBoxText`, `_BoxIsFullText`; source packages currently lack
those recipes. Receipt RAM follows the existing Magikarp gift seam. Save remains
blocked during choice; settled Save/Continue stores only existing session values,
never transient choice callbacks. Stale guards reject a second claim after a
reentrant or competing gift. No additional Pokémon reward is invented.

Provenance records SHA256 of exact external Git blobs, and regeneration rejects
modified inputs or the wrong pokered revision. Worker scoped host checks and SDK
compile do not prove native choice, full-box retry or process restart behavior.
