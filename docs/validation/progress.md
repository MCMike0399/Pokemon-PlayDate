# Full-game execution ledger

Updated 2026-10-29. Follow [the goal](../plans/full-game-goal.md).
Progress: **0/222 maps verified playable on Playdate hardware; 65/222 route-verified in Simulator. Current checkpoint: 5.5a, frozen for P0 device boot.**
Last accepted Simulator milestone, 5.4: **8.70 h**, **96.55 maps/day**, from [milestone times](milestone-times.json).
P0 elapsed since the first guarded trace commit: **7.59 h**; hardware pace: **0 maps/day**.

## 1. Accepted game and current main

Simulator-accepted 5.4 gameplay: `1a4a7894aa40125147e8f2d227fd1da6320dd341`.
[Acceptance summary](vermilion-acceptance-20261028.json) and [earned-save hashes](chain-saves.json).
Players reached Vermilion, explored Anne, received Cut, beat Surge, crossed
Diglett's Cave and earned Flash with all three starters. Bulbasaur covered optional
content; the other starters covered the critical path. Each began from earned
Cerulean saves and passed actual process exit/Continue. These are Simulator results.
**The game is not yet playable on Playdate hardware.** The last hardware game build
requested a restart. Only the small calibration app has since passed on hardware.

Main's current P0 game change is `e8265b3`; it has no hardware acceptance.
The approved GB tones and non-audio QoL remain on main. No new regions are active.
Production 5.4 packages and earned saves: `evidence/player-packages/5.4-playable-20261028`.
Showcase: `evidence/milestone-5.4-showcase-20261028/PokemonBlue-5.4-showcase.mp4`.
These deliveries are Simulator previews, not verified device builds.

## 2. Current checkpoint and checklist

**P0 hardware boot: in progress. Checkpoint 5.5a: frozen.**

- [x] Persistent phase trace, guarded loading/error screen and cooperative yields.
- [x] Simulator 16 MB pool verified (`MallocPoolSize=16645684`).
- [x] Calibration app, serial print/messages and attached-device coexistence verified.
- [x] Current earned-save smoke reaches title, Continue, save, doors, Cut and wild battle.
- [x] Current Simulator Lua heap fits 6 MiB live / 9 MiB sampled-peak targets.
- [ ] Ordinary frames, loading slices and map latency fit timing limits.
- [ ] Exact guarded hardware build reaches title and earned Continue.
- [ ] Hardware door, battle and save pass; no new error log; timing/heap pass.

After P0, accept three chained checkpoints on main: 5.5a Rock Tunnel/Lavender/
Celadon/Erika/Hideout/Scope; 5.5b Tower/Fuji/Flute/Fuchsia/Safari/Koga/Surf/Strength;
5.5c Saffron/Silph/Sabrina/Dojo/Fly. Each uses three earned saves from its predecessor.
Only one starter covers optional content. Runs continue after a starter fails.

## 3. Open defects and latest evidence

Latest exact smoke: build `22b14e0ddd3b4053af0b52d9d234178f`,
`evidence/p0-exact-game-smoke-build-20261029-11` and
`evidence/p0-exact-game-smoke-20261029-11`.
It reached every smoke step without a runtime error. Live Lua heap: **5.06 MiB**;
sampled peak: **5.87 MiB**. Native image memory is separate; the 16 MB pool remains enabled.
Timing **fails**: ordinary update **11.956 ms**, slice **44 ms**, map wall span **322 ms**,
provisional device map estimate **4.15 s**. No new game build was deployed.

The synthetic device/Simulator factor **35.11** is conservative and provisional;
it is not a measured game-phase factor. Evidence:
`evidence/p0-calibration-device-cycle-20261028-03` and
`evidence/p0-calibration-simulator-16mb-20261028-01`.
The safe calibration app stays awake for unattended USB control. Close serial
readers before Simulator or pdutil. A hard crash stops hardware attempts for the
night and requires one physical A press; routine testing must not need the user.

Recurring cave spikes occur in the update *after* movement finishes, when encounters
run. Completion-only probes miss them. Private validated Pokemon snapshots now
avoid repeated encoding/copying; freshness and RNG checks remain. First-use Cut
planning and repeated world-state reads also remain measured costs.

Latest small SDK batches under 16 MB: 18 encounter cases in
`evidence/p0-encounter-contracts-16mb-20261029-02`; 16 world / 20 map / 16 field cases in
`evidence/p0-world-contracts-16mb-20261029-08`,
`evidence/p0-map-contracts-16mb-20261029-01`,
`evidence/p0-field-contracts-16mb-20261029-05`.
Independent behavior review found public registry validation returning internal
records. The existing isolation case failed on that regression, then all 16 world
SDK cases passed after restoring the public copy boundary. Evidence:
`evidence/p0-registry-validation-red-20261029-01` and
`evidence/p0-registry-validation-green-20261029-01`.
The standards review also required this shorter ledger; earlier text is archived.
After the alias fix, production compilation and all 54 protocol host tests passed.

Full host run: **956/960 passed**, zero skips, in
`evidence/p0-current-host-20261029-03.log`. Three stale journey-hash failures were
then repaired; 50 related checks passed. Coverage remains stale and is not relabeled.
The latest earlier-P0 protected catalog comparison matched all **2,494** images:
`evidence/p0-protected-catalog-16mb-20261029-01/comparison.json`.
It combines two separate runtime exports and is not hardware acceptance.
The monolithic development harness exceeds 16 MB; use small existing SDK batches.

## 4. Work in flight

Root owns main, Simulator and hardware. Independent review is complete and its
findings are addressed. Cut reset now decodes only maps carrying tile changes;
16 field-move and 14 field-world SDK cases passed in
`evidence/p0-field-contracts-16mb-20261029-06` and
`evidence/p0-field-world-contracts-16mb-20261029-01`.
The exact `p0-exact-game-smoke-20261029-12` run is in flight. Private collector-mode
experiments `p0-generational-smoke-20261029-01` through `-03` reduced some costs but
still failed timing; collector mode on main is unchanged.
Next: reduce import-time work and trace overhead, then rerun the exact smoke. Only a passing Simulator proof may proceed to the hardware cycle.
Workers use GPT-6.1 Sol at medium effort in isolated worktrees.

`wip/midgame-integration`: 108-map checkpoint A candidate, frozen; needs current P0
changes and the same memory/device gate before campaign acceptance.
Later 5.5b/c packets, trades and Saffron guards remain parked. Root audio, cleanup
and Safari polish remain paused. Resume the smallest audible path after 5.5a.

The compact field-data experiment `80d9524` is parked. It saves 172,681 serialized
bytes but showed almost no SDK decode gain over 30 alternating calls; it was not
merged as a performance fix. Evidence: `evidence/p0-field-json-profile-20261029-01`.

## 5. Decisions and history

No new product-policy decisions. Keep Blue world/story/dialogue, Gen V rules and
151 species. Preserve protected art except approved GB imported-terrain tones and
museum/Route2 diagnostics. Crank scrolling, registered A+B, manual Bag sorting,
reusable TMs and B2W2 Pickup are approved. Trades require taking held items first
but remain parked. Do not repeat policy or Simulator-volume questions.

Detailed prior reports: [history](progress-history-device-p0-20261029.md).
Accepted milestones: [setup](divemac-baseline-20261026.json),
[Brock](brock-acceptance-20261026.json), [foundations](foundation-acceptance-20261026.json),
[Cerulean](cerulean-acceptance-20261028.json), [Vermilion](vermilion-acceptance-20261028.json).
Previously reported housekeeping freed 16.13 GB and removed at least 94 clean
superseded worktrees. Further cleanup is paused during P0; no new freed-space claim.
Journey data lives under `Source/dev`; external references regenerate from checksum
manifests. Production bundles, earned saves and real-speed clips stay outside Git.
**Local commits are waiting to be pushed. Push only when asked. The full game is unfinished.**
