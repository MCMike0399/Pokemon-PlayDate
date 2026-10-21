# Held-item ownership and Party/Bag interface — integrated phase2

Status: integrated and independently validated. The composed build passed
**516/516 SDK contracts and7/7 native jobs**, including Give/Take/INFO, full-bag
swap/take refusals and successes, actual two-process held Save/Continue, medicine
and PC restart. Root inspected actual native Party/Bag/INFO and restored INFO
captures. [Durable evidence](observed-pewter-foundation/motion-held-integrated.json).
Ability/held-item battle effects and acquisition remain required; this checkpoint
does not complete all111 abilities or the remaining GenV mechanics.

## Domain interface and transaction

`GameSession:giveHeldItem(actualPokemon,id)` and `:takeHeldItem(actualPokemon)`
return boolean plus a primitive receipt/reason. Actual member identity must belong
to that session's party; a copy, foreign member or stored member is rejected.
Withdraw a stored Pokemon before this field interface. Current Codec5 attributes,
canonical holdability and current stock are validated again on each call. No old
UI preview or caller plan is transfer authority.

The method builds a detached Inventory candidate, consumes one proposed new item,
then returns one old held item. It prepares the receipt and complete bag data
before commit. Commit uses the existing retained Inventory:_replaceData and then
one existing Pokemon.heldItem scalar assignment. There are no callbacks, yields,
RNG or fallible domain validation after the first bag commit. Party/member/active
identity, money, moves/PP, HP/status/stages, nature and slot remain unchanged.
No session constructor/restore/dependency/world-motion/codec field is touched.

Same-item give returns `already-holding`; empty take returns `no-held-item`.
Nonholdable key/TM/HM/EXP.ALL IDs and unknown IDs fail. Missing stock and inability
to return the old item leave both owners exact. Full bag cases are deliberate:

| Existing bag | Operation | Result |
|---|---|---|
|20 slots, new item quantity1, old item absent|give/swap|new slot frees room for old item|
|20 slots, new quantity2, old absent|give/swap|fails unchanged|
|20 slots, old stack98, new quantity2|give/swap|old reaches99; succeeds|
|20 slots, old stack99, new quantity2|give/swap|fails unchanged|
|20 slots, old stack99, new quantity1|give/swap|freed slot holds another stack1|
|20 slots, old stack99|take|fails unchanged|
|20 slots, old stack98|take|old reaches99; succeeds|

The extra stack case preserves the already-implemented Inventory model: each
stack is at most99, and multiple non-key stacks are allowed. This slice does not
silently change that earlier bag policy. Held medicine remains medicine held;
giving Max Elixir does not restore PP, and holding a ball does not throw it.
No acquisition policy or item availability is invented here.

## Native interface and lifecycle

Field Party actions are vertical STATS/SWITCH/ITEM/CANCEL. ITEM offers vertical
GIVE/TAKE/BACK. GIVE opens the existing Bag in explicit field-only held-selection
mode. It filters the actual current bag by holdability and shows actual quantities;
keys/TM/HM/EXP.ALL are excluded. Cancel returns to the same Party item menu. Give
and take report real committed transfers. Battle/medicine target Party selections
still use their existing direct callback path and never open field ITEM actions.

The existing stat/move page retains all4 PP rows and a clear `A: INFO B: Back`
footer. A toggles a second INFO page showing actual display nature/ability/item
names; its footer reads `A: STATS B: Back`. B returns to the party list from either
page. Raw IDs, ability slots and codec versions are diagnostics only.

Party callbacks retain visit/view/session/holder identity. Held Bag callbacks
retain the actual options capability, visit/session/top state; old forced-exit,
reentry, session replacement and stale stock reject. The domain independently
revalidates owner/stock. Draw/getSnapshot never progress state or consume RNG.
Existing dirty-screen invalidation clears departing overlays.

A presentation followup makes the4-row action box96px high at y126; the3-row
held submenu keeps76px/y146. A separate lifecycle followup recovers a Party
waiting state after an external Bag pop and accepts success presentation only
for the actual committed receipt. Normal same-call give/cancel callbacks finish
before recovery. The original frozen packets remain unchanged.

## Files and integration

Initial packet `/private/tmp/pokemon-held-items/foundation-manifest.json` pins4
Source files with exact before/after SHA and relative patches:

- domain/gameSession.lua: appended owner methods/private preparation only.
- game/partyState.lua: field item flow and readable INFO page.
- game/bagState.lua: explicit guarded held-selection mode/filter.
- dev/heldItemContracts.lua:25 real SDK groups.

For the shared session file use `gameSession-held-methods.lua` or its narrow patch,
not an old complete session snapshot. NPCMotion world RNG/actor DTO methods remain
disjoint. Root/harness were informed of the append-only interface. The independent
presentation correction is `/private/tmp/pokemon-held-items-presentation-followup-01`
(one PartyState box hunk, pinned to the initial packet manifest). Final composition
is `/private/tmp/pokemon-held-items-lifecycle-followup-01`: Party/Bag lifecycle
overrides plus2 real SDK regression groups, including the presentation fix.

Root-only SDK command; omit --execute for compile only:

```sh
python3 /private/tmp/pokemon-held-items-lifecycle-followup-01/validate_staged.py \
  --project "$PWD" --output /private/tmp/pokemon-held-items-sdk-01 --execute
```

Compile-only passed `/private/tmp/pokemon-held-items-build-03`. Exact composed
source identity is in its build.json. Default staging rejects changed owned bases;
`--merge-current` performs real three-way merges and fails conflicts. Source bytes
and hashes, rather than this prose's expected count, identify each actual proof.
There are25 transfer/UI plus2 lifecycle groups; a470-case base would produce497,
497 staged cases passed before composition; the integrated proof is516/516 above.

Required root diagnostics (read-only, already wired in private validator):
`party_info = partyState:getInfoSnapshot()` and
`bag_held = bagState:getHeldSnapshot()`. Info includes selected species/nature ID/
ability ID/held ID for assertions; Bag includes mode/holder/count/selected ID/qty.

## Contracts and native recipes

SDK groups cover all49 holdable IDs; no-effect/unknown/nonholdable IDs; foreign,
copy and storage rejection; fresh stock and invalid current mon; occupied swap;
full bag quantity1 versus2;98/99 limits; retained identities/PP/status/money/RNG;
actual Session JSON roundtrip; filtering/live quantity; actual give/take menus;
cancel/stale exit/reentry/session/stock; option preflight; battle-selection bypass;
INFO toggling and repeated-draw invariance. The extra2 groups prove forced-pop
recovery and reject forged/stale completion while actual success still reports.
Source execution remains root-owned.

Four unexecuted native recipes under `/private/tmp/pokemon-held-items/scenarios`:

- `held-give-take-info.json`: BUTTERFREE50/COMPOUND EYES/CAREFUL, all4 distinct PP,
  filtered Bag, cancel/give/take/give, MAX ELIXER INFO. Inspect readable names,
  quantities,4PP and both footer hints at native400x240.
- `held-full-bag-swap.json`: real quantity2 refusal versus quantity1 swap.
- `held-full-bag-take99.json`:99 refusal versus98→99 success.
- `held-save-restart.json`: actual2-process Save/Continue preserves given item,
  exact bag quantities, nature/ability, sleep duration, HP and all4 PP; inspect
  restored stats/INFO after restart. Holding Max Elixir must not restore PP.

Use the same runner with `--scenario <absolute.json> --execute`. Scenario JSONs
use actual one-column input navigation; their hashes are in scenario-manifest.json.
No receipt/outcome is forged, and no screenshot acceptance is claimed before root
runs the recipes and reviews actual native frames. Protected art remains unchanged.
