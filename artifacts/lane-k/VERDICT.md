# VERDICT

Against `6e4bc90fe6c9c72a23f8249ff453babc777193aa`.
`origin/main` and `origin/cursor/lane-e-integration` are that commit.
Lane K branch: `cursor/lane-k-qa`. E remains the only merger of `Source/`.

## Already landed (do not re-apply)

`git apply --check` fails because the change is in the tree:

- Blackout text and checkpoint warp (`lane-e-blackout.patch`)
- Player back scaled to the 80px slot (`lane-e-player-back-scale.patch`)
- Nurse audio (`lane-e-nurse-audio.patch`)
- HP drain menu (`lane-e-hp-drain-menu.patch`)
- Battle font / typewriter-finished snap (`lane-e-battle-font.patch`)
- Elite Four and Champion trainer pics, and the Route 22 rival `class_source` (`lane-e-trainer-pic.patch`)
- Yen glyph on prizes, marts, daycare, and services (`lane-e-yen-glyph.patch`)
- Shift YES/NO (`lane-e-shift-prompt.patch`)
- Send-out text box. The system-font `_wrapped("battle-message")` blit is gone. Narration, including `Go!`, uses `messageDialog:draw(true)`. Passing test: `tools/tests/test_lane_e_sendout_textbox.py`. No patch.

## Patches for E

All five apply clean on this tip. Live assertions are `expectedFailure` until they land. Detail and hunk notes: `docs/validation/lane-k-patch-preverify.md`. Fidelity labels: `docs/validation/lane-k-fidelity.md`.

1. `tools/notes/lane-e-gym-terrain-tones.patch` — Celadon / GYM mockup C. Does not retune `Shade.LIGHT`.
2. `tools/notes/lane-e-flower-tile-03.patch` — resting flower in tile `$03`.
3. `tools/notes/lane-e-battle-text-flicker.patch` — distinct from the GB-font fix. The iris stencil still clips the message box.
4. `tools/notes/lane-e-viridian-sight.patch` — sight greater than 0 is no longer talk-only. Spinners already pass.
5. `tools/notes/lane-e-money-yen.patch` — trainer card `MONEY/$`, and the Pay Day pickup page.

## npc-trades

Stopped. No patch. This tip is `main`, so the head-only set is empty. The ledger on the commit records `npc-trades` 68 passed / 1 failed, the same name `main` `bf92c4fc` failed (`full party all 240 PC slots, source append order and survivor active identity`), and `pewterProviderContracts` 29 passed / 2 failed, the same two names. `MallocPoolSize` stays 16645684. No SDK on this VM, so the device suite was not launched again.

## Fidelity

Pass: blackout page and warp (lab rival excepted), shift YES/NO, nurse YES/NO, Viridian arrow tiles, Elite Four and Champion pics, prize and mart yen (PC draws no balance).

Fail, and only these are patched: Viridian trainer line of sight; trainer-card yen; Pay Day `_PickUpPayDayMoneyText`.

## Host result

`python3 -m unittest` on the five lane K modules: 18 tests, OK, 5 expected failures. Those five fail on the live tree and pass once the matching patch is applied to a temp tree.

The first full discover died on `KeyError: POKERED_REFERENCE_DIR`. The rerun set that variable, and `KANTO_REFERENCE`, to pret/pokered `af519899719f0754965776faac0e836a3b906e6d` at `/tmp/pokemon-host/pokered`. Counts: 1382 ran, 1302 passed, 13 failed, 51 errors, 11 skipped, 5 expected failures, 0 unexpected successes. Names are in `docs/validation/lane-k-suite-6e4bc90f.md`. There is still no Playdate SDK and no parcel bundle.

## Round 2

Champion win, Hall of Fame, credits, and Continue at Pallet `(5, 6)` facing down pass for Squirtle, Bulbasaur, and Charmander fixture parties (`tools/tests/test_lane_e_postgame_continue.py`). The thirteen historical debug-warp maps resolve their sprite strips. No new patch.

Lane I moved to `51e1efc4`. Against E `6e4bc90f`:

| Patch | Verdict |
| --- | --- |
| `lane-e-message-queue.patch` | clean |
| `lane-e-possessive.patch` | clean |
| `lane-e-shift-hold.patch` | clean |
| `lane-e-shift-prompt.patch` | already-landed |
| `lane-e-battle-message.patch` | already-landed |

The 13 host failures are harness, census, projection, and byte-freeze pins. No new patch from that list. Celadon capture stays with YellowBot after E lands the gym tones and the flower tile.

## Round 3

No new patch. SHIFT after a foe faint asks `Will RED\nchange POKéMON?` before the send-out, and SET does not (`tools/tests/test_lane_e_shift_faint.py`). A trainer wipe prints `_PlayerBlackedOutText2` and the Center spots match `FlyWarpData` (`tools/tests/test_lane_e_blackout.py`). The twelve Viridian arrows match the RLE paths and swap frames (`tools/tests/test_lane_e_spinner_motion.py`). The Squirtle walk to Brock is in `docs/validation/lane-k-squirtle-pewter.md`.

## Round 4 — main FF call

E tip `56414b632d906074c7f7d78d7bb21b44061fa3c8` (Source identical to `51764017`). Host discover: 1333 ran, 1243 passed, 12 failed, 67 errors, 11 skipped, 0 expected failures. Detail: `docs/validation/lane-k-suite-56414b63.md`.

Prior expected failures now pass on the live tree: gym tones, flower `$03`, iris stencil, Viridian sight, trainer-card and Pay Day yen, message queue, possessive ligatures, shift hold.

The twelve assertion failures are the `6e4bc90f` thirteen minus `test_vermilion_preparation`, which now errors in `setUpClass` on the same new pin. Sixteen errors are new versus that baseline. All of them raise `unpinned consumed source: gfx/tilesets/flower/flower1.png`. That pin break arrives with the flower substitution in `a1740550`.

No. Do not fast-forward `main` `6e4bc90f` to `56414b63`.
