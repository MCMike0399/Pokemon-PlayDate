# Battle-UI review of lane K e9da9e23

K tip `e9da9e23` contains main `e0e9a209`. The three clips were re-run on this tree. Wide Guard stays unimplemented.

## Message queue

`test_lane_k_message_queue` failed on the live scene: frame 12 replaced `LORELEI: You will lose!` with `BRUNO is about to use ONIX!`. `tools/notes/lane-e-message-queue-confirm.patch` is applied. The confirming A no longer calls `battle:handleInput`. `test_lane_e_learn_pages` still passes.

## Learn box name

Not applied. Page 1 is `CHARIZARD is` / `trying to learn`. Page 2 is `trying to learn` / `FLARE BLITZ!`, the pokered `<CONT>` page. `lane-e-learn-box-name.patch` would put the name on a third line of page 1. The two-row box and `test_lane_e_learn_pages` already keep that name on page 2.

## Shift on a fainted lead

Diagnosed, not patched. With Charizard at 0 HP, Bruno sends Hitmonchan and never sets `shiftChoice`. `Battle:finishRound` asks only when `self.player:isAlive()`. `eligibleForcedReplacements` returns `inactive-target` for a fainted lead, so the question cannot be asked until the replacement is committed.

## Bruno Hitmonlee

`docs/validation/lane-k-bruno-hitmonlee-moves.md` matches `ab91045f`. The party row is Jump Kick, Focus Energy, High Jump Kick, Mega Kick. The battle names and PP are JUMP KICK 10, FOCUS ENERGY 30, HIGH JUMP KICK 10, MEGA KICK 5. Wide Guard remains the Gen V 469 gap and the ledger N/A.
