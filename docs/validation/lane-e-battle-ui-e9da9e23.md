# Battle-UI review of lane K e9da9e23

K tip `e9da9e23` contains main `e0e9a209`. The three clips were re-run on this tree. Wide Guard stays unimplemented.

## Message queue

`test_lane_k_message_queue` failed on the live scene: frame 12 replaced `LORELEI: You will lose!` with `BRUNO is about to use ONIX!`. `tools/notes/lane-e-message-queue-confirm.patch` is applied. The confirming A no longer calls `battle:handleInput`. `test_lane_e_learn_pages` still passes.

## Learn box name

Applied. The opened page is `CHARIZARD is` / `trying to learn` / `FLARE BLITZ!`. `test_lane_k_learn_name` prints `learn-name-shown`. `test_lane_e_learn_pages` still reaches the later pages before YES/NO.

## Shift on a fainted lead

Applied. A fainted lead with a living bench gets the SHIFT question before the next foe is sent. `test_lane_k_shift_slots` prints `shift-slots-held` for Bruno's Onix and Lorelei's Jynx. `eligibleForcedReplacements` still rejects a fainted target; the question uses the living bench instead.

## Bruno Hitmonlee

`docs/validation/lane-k-bruno-hitmonlee-moves.md` matches `ab91045f`. The party row is Jump Kick, Focus Energy, High Jump Kick, Mega Kick. The battle names and PP are JUMP KICK 10, FOCUS ENERGY 30, HIGH JUMP KICK 10, MEGA KICK 5. Wide Guard remains the Gen V 469 gap and the ledger N/A.
