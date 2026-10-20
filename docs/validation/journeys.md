# Semantic Simulator journeys

`tools/harness/journeys.py` runs inside the existing identified runner's owned Simulator session. It does not launch/terminate a process, acquire another mailbox, or touch another run. `journeys.run(client, scenario, evidence_dir)` returns the summary; the runner publishes it as `journey-summary.json`. On failure the driver also publishes its last snapshot and progress before propagating the error.

Run each scenario in its own fresh output directory:

```sh
python3 tools/harness/run.py --scenario tools/harness/scenarios/intro-squirtle.json --output /tmp/pokemon-intro-squirtle
python3 tools/harness/run.py --scenario tools/harness/scenarios/intro-charmander.json --output /tmp/pokemon-intro-charmander
python3 tools/harness/run.py --scenario tools/harness/scenarios/intro-bulbasaur.json --output /tmp/pokemon-intro-bulbasaur
python3 tools/harness/run.py --scenario tools/harness/scenarios/rival-win-fixture.json --output /tmp/pokemon-rival-win
python3 tools/harness/run.py --scenario tools/harness/scenarios/rival-loss-fixture.json --output /tmp/pokemon-rival-loss
python3 tools/harness/run.py --scenario tools/harness/scenarios/interior-roundtrips.json --output /tmp/pokemon-interiors
python3 tools/harness/run.py --scenario tools/harness/scenarios/session-resets.json --output /tmp/pokemon-resets
python3 tools/harness/run.py --scenario tools/harness/scenarios/overlays-inputs.json --output /tmp/pokemon-inputs
python3 tools/harness/run.py --scenario tools/harness/scenarios/wild-return.json --output /tmp/pokemon-wild-return
python3 tools/harness/run.py --scenario tools/harness/scenarios/wild-blackout-fixture.json --output /tmp/pokemon-blackout
```

Run these sequentially under the designated runtime owner. Root independently verified seed 42 wins the complete natural Squirtle and Charmander intros; those scenarios now assert `expected_outcome: win`. Bulbasaur remains a candidate until independently validated. An unset `journey.expected_outcome` records either real result; pin it only after runtime verification. Never replace a failed natural run with a fixture and claim equivalent coverage.

## Scenarios and evidence

| Scenario | Setup | Actions and assertions |
| --- | --- | --- |
| Three `intro-*` cases | Whole-session new-game reset and seed; no position or combat edits | Starting dialog, TV collision, actual eight-frame steps, stairs, exit mat and exterior door, camera follow, grass/Oak stop, lab escort, chosen starter and counter-pick, rival challenge, full battle through real FIGHT/move inputs, goodbye and BLUE removal. HP/zone respawn checked on natural loss. |
| `rival-win-fixture` | Same collision-aware route; adjust only existing rival's enemy HP to 1 | Actual attacking move must KO; terminal enemy/player HP and story outcome checked. |
| `rival-loss-fixture` | Same route; adjust only existing rival's player HP to 1 | Select actual status move until enemy deals lethal damage; terminal HP, healing, lab spawn and loss story outcome checked. |
| `interior-roundtrips` | Explicit skipped-intro fixture at Pallet `(5,6)` | Physical inputs enter/exit Red's house, both stair directions, Blue's house and Oak's lab; asserts zone/arrival coordinates and exit facing. Interior edge exit is separate from stepping onto the mat. |
| `session-resets` | Explicit targeted setup for active Oak-stop dialog, stair transition and battle script | Reset within each active state, assert clean bedroom/story/Pokémon/battle, wait past old timers, finish fresh opening and verify no stale callback or held input. |
| `overlays-inputs` | Explicit free-play bedroom fixture | Open actual debug overlay; directional menu input must leave world position settled; B closes it. Hold left across frames, release, allow final step to settle, then assert position stays fixed across 20 more frames. |
| `wild-return` | Explicit free-play Pallet `(9,3)` fixture | Enable encounters, real grass steps until real encounter/iris triggers, natural FIGHT/move battle, assert victorious return to original grass position. No HP edits. |
| `wild-blackout-fixture` | Same actual grass encounter, then player HP 1 | Actual enemy action must KO while player uses status move; assert blackout returns to Pallet spawn with full HP. |

The whole-session reset is named in the summary separately from supplementary position/HP fixtures. Every fixture is recorded with its options. Natural intro means no teleport, intro skip, direct battle command, direct story choice, direct outcome change or HP edit after new-game reset. The baseline route was checked against the original-source trace in `docs/validation/baseline-initial/trace.json`; current source still receives runtime verification.

The driver uses one-frame `press` actions, actual directional collision and input handlers. It does not use `move`, `face`, `warp`, `intro skip`, `battle` or `mash` commands for natural traversal. A segment checks its starting explored/settled state and final coordinate; segments stop at known story/door triggers. Door transitions await their destination zone and explored state. Failed collision, wrong arrival or unexpected overlay fails the run.

Dialog advancement inspects `root`, current line and readiness before every single A press; it stops immediately when the overlay closes. Battle advancement inspects phase, waiting, intro readiness and menu selection; each coroutine message receives one A after the production minimum of ten frames. HP at the `ended` phase establishes win/loss before acknowledging it. English narrative is retained in snapshots for diagnosis and is never the sole oracle. All loops have finite action limits; Client additionally bounds every request by frames/time and persists request/result evidence.

The runner's normal per-command snapshots and runtime tick trace remain the detailed evidence. `journey-progress.json` and `journey-summary.json` add named semantic checkpoints, actual terminal HP/outcomes, fixture classification and recording inventory. Dialog checkpoints wait for typing to reach semantic readiness before capture, without advancing input. Named native 400×240 screenshots include opening, collision, mats, Oak stop, starter, battle/moves/terminal and final returns. Recordings capture bedroom cadence, camera follow, grass/Oak stop, stairs/exterior/interior doors, debug overlay, held/released walking, real grass encounter/iris, and representative attacks. Each expected screenshot/frame file must exist before the driver accepts its command.

## Boundaries and qualification

These are executable candidates until the runtime owner runs them on the integrated build and inspects the real native screenshots/frames. Python compilation or source review alone is not journey acceptance. The owner must record actual scenario outcomes, build identity, evidence paths and any repairs in the execution ledger.

Physical-device timing and input are not validated by these Simulator cases. The test zone is an isolated debug map with no adjoining door; it is outside the four existing interior roundtrips. Seed-sensitive outcomes must be evaluated in the actual runner. The all-PP-exhaustion behavior and full battle mechanics remain separate rules tests; these journeys do not substitute for them.
