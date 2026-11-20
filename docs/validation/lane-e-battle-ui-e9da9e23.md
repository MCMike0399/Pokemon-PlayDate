# Battle-UI review of lane K e9da9e23

K tip `e9da9e23` contains main `e0e9a209`. The three clips were re-run on this tree. Wide Guard stays unimplemented.

## Message queue

`test_lane_k_message_queue` failed on the live scene: frame 12 replaced `LORELEI: You will lose!` with `BRUNO is about to use ONIX!`. `tools/notes/lane-e-message-queue-confirm.patch` is applied. The confirming A no longer calls `battle:handleInput`. `test_lane_e_learn_pages` still passes.

## Learn box name

The two-row box keeps the pokered first screen: `CHARIZARD is` / `trying to learn`. `FLARE BLITZ` is the next page, the `<CONT>` after `trying to learn`. `lane-e-learn-box-name.patch` is not applied; a third line is clipped. `test_lane_k_learn_name` prints `learn-name-on-next-page` for that next page. `test_lane_e_learn_pages` still reaches it before YES/NO.

## Shift on a fainted lead

ChooseNextMon runs first. `eligibleForcedReplacements` returns the living bench for that fainted lead. After Weepinbell is sent, the SHIFT question is printed while Onix or Jynx is still the active foe. The question uses party count, because the old lead is then the fainted bench. `test_lane_k_shift_slots` prints `shift-slots-held` and `shift-order-held`. Whirlwind still fails on a fainted target.

## Bruno Hitmonlee

`docs/validation/lane-k-bruno-hitmonlee-moves.md` matches `ab91045f`. The party row is Jump Kick, Focus Energy, High Jump Kick, Mega Kick. The battle names and PP are JUMP KICK 10, FOCUS ENERGY 30, HIGH JUMP KICK 10, MEGA KICK 5. Wide Guard remains the Gen V 469 gap and the ledger N/A.
