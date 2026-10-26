# Bespoke Cerulean story sources

English Blue story source: [pret/pokered at af519899](https://github.com/pret/pokered/tree/af519899719f0754965776faac0e836a3b906e6d).
`tools/references/cerulean-story/manifest.json` pins every vendored source byte.
`python -m tools.generate_cerulean_story --check` reproduces the four JSON files.
The generator supports `--reference "$POKERED_REFERENCE_DIR"` for the real pinned
checkout and requires an explicit `--output` when writing candidates.

The descriptors cover only Bill's three object rows and hidden PC row, the
MtMoonB2F Super Nerd and two fossils, and Misty. Movement arrays and original
text recipes are extracted from the pinned source; rosters retain Super Nerd's
Grimer/Voltorb/Koffing at 12 and Misty's Staryu 18/Starmie 21. Payouts are 300 and
2079. Source script labels preserve case, including `MtMoonB2f`.

The shared content candidate `48943b7` has identical common text recipes and
trainer teams. Runtime registration reuses its existing trainer records and text
API. The local text/roster projections are independent pinned references and
allow detached foundation contracts without activating another region.

See [root integration](../../../tools/integration/cerulean-story.md) for actor
visibility, collision exceptions, APIs, cancellation policy, root-only runtime
checks, and current limits. These files establish preparation, not acceptance.


Bill PC target semantics are pinned in `engine/overworld/hidden_events.asm`:
`CheckForHiddenEvent` calls `CheckIfCoordsInFrontOfPlayerMatch`. The hidden-event
macro accepts `(x,y)` and emits y before x; its BillsHouse `(1,4)` row is the PC
**target**. Required-up interaction projects the standing player to `(1,5)`.
`scenes.pc` preserves that source target; `scenes.pc_player` records the derived
source standing pose returned by `CeruleanStory.pcPlayer()`. The runtime
`pcInteraction` API receives player coordinates with map padding already applied.
