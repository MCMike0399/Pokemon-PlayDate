# Four approved QoL changes

The user approved all four proposals. This quality branch is separate from the
Vermilion release and does not merge itself into milestone 5.4. Root owns native
acceptance and release selection. No Simulator, push or delegation was used.

## Integration and behavior

Apply the quality commits after `5d0b062`. The domain commit is `0be66b2`;
the following UI/input commit contains the four SDK behavior contracts.
No new production state registration or main-loop call is required. Menu and
OverworldState import their helpers transitively. Apply
[the two-line SDK suite patch](approved-qol-root.patch) to root's harness imports:

```lua
import "dev/approvedQoLContracts"
Contracts.register("approved-qol", ApprovedQoLContracts.run)
```

This assumes root already applied the earlier OptionsState registration.
The fidelity ledger stays root-owned; the four proposed rows are below.

- **Crank scrolling:** Options → CRANK SCROLL, default OFF. ON enables a fixed
  24-degree detent per entry without acceleration in lists with five or more
  entries. Common menus, Bag, Party, Pokédex, shop browse, item PC, Pokémon PC
  lists and the twelve-box selector retain D-pad control. Crank movement and
  partial detents are discarded on entering/changing menus and returning from
  their overlays. Docking clears partial rotation. Common long menus keep the
  selected row in their visible viewport; the crank never confirms an action.
- **Registration:** Bag → TOWN MAP → REGISTER / UNREGISTER. The Bag header
  shows the registered item, including a missing-item label. A+B in settled
  field exploration invokes the same Bag USE dispatch and TownMapState's
  existing context/ownership validations. Returning from the map returns to the
  field, without leaving an incidental Bag overlay. An unavailable item reports
  a message without an effect. Registration persists in app preferences, not
  the adventure codec, and can become usable again after withdrawing the item.
- **Gesture arbitration:** simultaneous A+B, or adding B within A's four-frame
  recognition window, invokes registration once. B then A also works, including
  when B was running. The gesture stops at a settled tile and is consumed until
  both buttons are released. It cannot also interact or open Pause. A alone
  interacts on release or after four frames; a short stationary B release
  opens Pause; directional B runs. World transitions/overlays discard pending
  gestures, so an old chord cannot execute after a battle, warp or dialog.
- **Sorting:** a SORT BAG row appears after the ordinary item rows when a field
  Bag has at least two stacks. Selecting it calls one atomic Inventory operation:
  key items first, then case-insensitive display name, preserving original
  positions for ties. Counts, stack boundaries, item identities, capacity and
  money remain unchanged. It never auto-sorts and is unavailable in battle or
  held-item selection. Existing save encoding retains the resulting slot order.
- **Machines:** successful teaching retains TM stock and reports
  `consumed=false`. The same owned TM may teach another compatible member.
  Compatibility, old-PP/new-max behavior, four-slot replacement confirmation,
  HM protection, ownership, quantity/record staleness and cancellation remain
  in their existing transaction owners. Generated MachineData retains the
  pinned Blue consumption flags as source metadata; Teaching applies the
  approved reuse policy. Existing teaching fixtures use one retained-stock
  expectation helper; the independent TM34 qualification now expects reuse.

## Limits

TOWN MAP is currently the only key item with an implemented Bag USE action.
Bicycle, rods and quest keys cannot be registered; no new field effects were
invented. Registration is app-global and may reference an item absent from a
new/older adventure; use always revalidates live stock and field context.
A delayed chord after A has already interacted belongs to that consumed gesture
and does not run a second action. A transition may cancel a queued shortcut.

Sort compares the game's display names, rather than a locale-dependent collation
or a new category system. Reusable TMs do not refund previously consumed stock,
change the original compatibility roster, rewrite machine IDs or change prices.
Only root's native runs can establish input feel, frame timing and visual quality.

## Validation

Production `make compile` passes. The four-case SDK module and the existing
teaching/TM34 modules compile under SDK 3.1.2. The seven teaching-data host checks
and item-generator host checks pass. SDK behavior cases have not been executed
by this worker. No contracts were added for a driver; there is exactly one new
SDK case per approved behavior. No save schema, main, audio or protected art edit.

## Root's native input witnesses

Use a private identified SDK session, leaving accepted 5.3/5.4 save chains intact.
Run the existing suite with `approved-qol` registered, then record normal speed:

1. Enable CRANK SCROLL. In a long Bag/shop/PC list and the twelve-box selector,
   rotate below a detent, cross one detent, reverse and use the D-pad. Rotate
   while a confirmation or child overlay is open; return and verify no selection
   jumps. Dock/undock and repeat. Turn the option OFF: D-pad still works and crank
   motion does nothing. Restart the same private app data to check persistence.
2. Register the earned TOWN MAP in Bag and capture its header and REGISTER /
   UNREGISTER action. Use A+B in both orders while facing an interactable NPC;
   the map opens once and no dialog/Pause is also invoked. Hold both, release
   only one, then release both: no repeat. Close the map directly to the field.
   Check A-only interaction, stationary short-B Pause and B-running separately.
   Try the chord while running, in battle, inside menus and after an overlay.
   Deposit/remove the registered map and verify missing stock is rejected;
   withdraw it and use it again. Restart and New Game must not grant the item.
3. With a deliberately mixed earned Bag, choose SORT BAG. Capture before/after:
   keys group first, names sort, equal-name stacks retain their relative order,
   quantities/money do not change. Save/Continue preserves order. Repeating Sort
   is idempotent; battle and Give-item Bag modes offer no Sort command.
4. Use one owned TM on two compatible party members. Capture retained stock after
   each success, then cancellation, incompatible/already-known rejection and a
   four-slot replacement confirmation. Exercise an existing stale-request case
   and protected HM replacement case from the suite. Save/Continue retains the
   taught moves and original TM quantity. Do not seed or refund campaign items
   merely to claim a natural witness; use labeled supplements where necessary.

## Four fidelity rows for root

| Area | Approved deliberate change |
| --- | --- |
| Menu input | Optional Playdate crank scrolling uses 24-degree detents in long lists and PC boxes; D-pad remains available and menu entry clears accumulated motion. |
| Registered item | One supported key item is explicitly registered in Bag and stored in application preferences; field A+B reuses Bag USE with live validation and exclusive gesture arbitration. |
| Bag order | Manual atomic sorting groups key items, sorts display names and preserves ties/stacks; the ordinary inventory/save owner retains the resulting order. |
| TM economy | Gen V reuse retains TMs after successful teaching, with Blue identities/compatibility and existing HM, PP, confirmation and stale-transaction policies. |
