# Full-game execution ledger

**Active and incomplete:** [complete goal](../plans/astra-full-game-goal.md).
Root is GPT-6.1 Sol by the explicit 2026-10-21 override. Preserve the whole
campaign and original postgame. Brock is the next gate, never the final goal.
[Earlier history](progress-history-through-1c40818.md).

## Checkout and ownership

Reviewed950-source changes are installed locally in main after `48e88ac`;
remote remains `ba8975d`. Working-tree Source SHA is
`49832dd1c89953784f13c65a54f21a63771ae7b9b73ef16b405a8118932c8386`.
Main production compile and full host suite pass. No new push is implied.

Root alone launches Simulator with UUID Data and the global lock. Latest queues
have finished; verify actual processes/locks before the next launch. Historical
PIDs or earlier running statements are never ownership evidence.

All three workers were explicitly selected as `gpt-6.1-sol`, `medium`, fresh
nonforked contexts; followups retain those settings. Runtime list exposes worker
identities/statuses, not resolved model/effort metadata. Workers write private
candidates only. Root reviews, integrates, reruns and inspects native evidence.

## Implemented and verified on the current Source

- Party/capture/storage/evolution, Pallet–Pewter events/trainers, medicine,
  learning, held menus, natures and normal-slot persistence. Added typed Blue
  TM/HM compatibility and teaching, original TM34 Bide, six move rules, Focus/
  critical stages, charge/rampage, Rain, sex/status abilities and Worry/Insomnia.
- Codec6 sex/provenance, ordinary Pikachu Light Ball and Compound Eyes loot;
  Daisy Town Map with original map transcription, Escape Rope, first-conscious
  field battle lead, new-game Pallet checkpoint, Mom rest and RED PC item storage.
  New games put Potion1 in the PC; old saves migrate an absent PC to empty.
- **950/950 SDK checks, 462 host checks, zero skips**, production compile PASS.
  Earlier Sourcecd1d qualified22 distinct native cases, including actual TM
  learning/Bide, Rain/charge/status panels, PC Potion cancel/withdraw/Save/Continue,
  Daisy full-bag retry/map/Continue, Rope purchase/cancel/return/save, replacement
  seen-state true restart, Focus, blackout and Brock full-bag TM retry.
  New Protect/field batch adds8 native cases on Source022ff, followed by3 side
  cases on current Source49832d; actual hashes remain distinct in evidence.
  Protect/Feint/Bide, physical-lead Static/KeenEye/Intimidate, Light Screen/
  Safeguard/Tailwind and successful0HP-hit reactions are integrated. All16
  deliberate fault variants failed their intended actual-SDK assertions.
- **2494/2494 catalog images exact**, including masks/hidden RGB. Mandatory
  859 native before/after pairs and both 23040-pixel Town Map rectangles qualify
  after quiescence. Root inspected map/PC/Worry/Bide/Brock screens and native
  release/response frames. No physical-device validation is claimed.
- Original scalar/effect hashes and immutable ability metadata remain unchanged.
  Explicit producer migrations preserve strict deletion/type/effect/roster checks.
  Blue55-machine/8305-bit compatibility matches independent pinned PKHeX.

[Current SDK/native/fault evidence](observed-pewter-foundation/brock-integrated950.json),
[earlier SDK/source archive](observed-pewter-foundation/brock-integrated873.json),
[input/restart evidence](observed-pewter-foundation/brock-integrated873-input-evidence.json),
[root primary engine oracles](observed-pewter-foundation/gen5-independent-root-oracles-01.json).

## Failures retained and acceptance still open

- First combined SDK was **855 PASS/17 FAIL**. Root omitted the original PC
  terminal integration patch; other failures were invalid direction/session/
  intro/seed/tie/turn-boundary fixtures. Reviewed narrow repairs pass873; no
  battle-engine bug or assertion-cap waiver was inferred.
  [Original failure](observed-pewter-foundation/brock-composed-sdk01-failures.json).
- Native recipes first gave12 PASS/5 setup FAIL. Legal captions, actual `move`
  opcode and an explicit initial false map flag repaired the recipes without
  changing Source or dropping mechanics assertions; all six retry/catalog jobs
  pass. A TM run published ready after24s and missed20s: no gameplay accepted;
  a fresh identified run passed with the same timeout. Failures remain archived.
- Legacy Source `a6fb4666...` natural runs: Charmander evolved16→Charmeleon,
  Squirtle evolved16→Wartortle, both defeated Brock at17 and retained exact state
  through two real processes. Root inspected actual Wartortle/Brock victory and
  qualified saved/continued worlds against1256 source pixels each. Bulbasaur
  caught/reordered/switched and reached7, then the old driver rejected transient
  forcedSwitch with a living reserve. This was not defeat or blackout.
- Final natural runs on current integrated Source are still required, especially
  Bulbasaur, explicit Title/save-dialog and96-frame accepted evolution; preserve
  cancellation coverage. Journey03/04/Capture05 fixes are installed. An earlier
  black-PNG observation was withdrawn after independent decoding/reopening.
- [Source exposure inventory](prebrock-mechanics/CHECKLIST.md):417 level events,
  135 moves,21 expected natural species across starters/30 technical closure.
  All grind levels remain required. Route22 integration, remaining exposed move/
  field/ability behavior, IV/EV, and original first-gate content remain open.
  First16 describes battle hooks, not complete coverage of all111 ability IDs.

## Bounded private work and next executable actions

| Owner | Current ownership |
|---|---|
| rules_contracts | Roost implementation approved: pure battle effective types, successful half-up healing and order25 expiry; native member tie policy explicitly differs from PS. |
| visual_catalog | Route22/Gate source-backed implementation proposal approved: one provider/TrainerEvents owner, authentic first BLUE, Oak five-ball followup. No new held loot; Spearow literal rows are0/0/0. |
| harness | IV/EV PacketA approved/private: six-stat ownership, append-six normal IV draws, fixed Blue trainer individual contribution and Codec7 zero migration. Rewards PacketB still pending. |
| root | Main equals reviewed950Source; all16 faults killed,2494catalog exact,11 new native cases. Freeze evidence/commit; integrate Roost/Route22/individuals, then rewards and final naturalall3. Sole Simulator owner. |

Protect/v9 and side/v10 producers are installed. Roost/v11 producer49 host
groups pass with exact5CSV regeneration and unchanged original oracles; v11
is not installed until its runtime is reviewed.
Bide/Protect uses source-C+PokeAPI block semantics despite a documented PS direct-
helper bypass. Two-holder Mud Sport stacking is PS policy, not cartridge proof.
Production opening probe now passes four fresh identified600-frame jobs: about10.35MiB post-GC Lua heap, sampled startup22.2MiB; harness adds~85KiB and frame-recording work. Root inspected native opening; no device-fit/total-memory claim or gating fix. Original verifier failures retained in [memory evidence](observed-pewter-foundation/production-memory02.json).

Private Protect+field first SDK922PASS/2FAIL retained: incorrect intermediate empty-table cleanup expectation and raw-vs-session decimal-counter fixture encoding. Reviewed test-only repairs pass924; side composition passes950. Root inspected protection/Feint/Bide, actual Static iris/entry, Screen0HP/Guard/Wind panels. The current batch is installed in main with all16 fault/catalog qualifications; final naturalall3 remains pending.

Frozen source/patches/pins/tests are in the [handoff archive manifest](../plans/implementation-handoffs/manifest.json).
After closing Brock with the required integrated evidence, proceed directly to
Mt. Moon/Cerulean and every later campaign/original postgame milestone. Existing
Mt. Moon proposals remain archived; broader map integration stays deferred.
