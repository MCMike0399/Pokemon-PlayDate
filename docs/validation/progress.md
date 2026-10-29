# Full-game execution ledger

Updated 2026-10-29. Follow [the goal](../plans/full-game-goal.md).
Progress: **0/222 maps verified playable on Playdate hardware; 65/222 route-verified in Simulator. Current checkpoint: 5.5a, frozen for P0 device boot.**
Last accepted Simulator milestone, 5.4: **8.70 h**, **96.55 maps/day**; [times](milestone-times.json).
P0 elapsed since the first guarded trace commit: **11.40 h**; hardware pace: **0 maps/day**.

## 1. Accepted game and current main

Simulator-accepted 5.4 gameplay: `1a4a7894aa40125147e8f2d227fd1da6320dd341`.
[Acceptance](vermilion-acceptance-20261028.json), [earned-save hashes](chain-saves.json).
All three starters reached Vermilion, explored Anne, received Cut, beat Surge,
crossed Diglett's Cave and earned Flash, starting from earned Cerulean saves.
Bulbasaur covered optional content; the others covered the critical path.
All passed actual process exit/Continue. These are Simulator results.
**The game is not yet playable on Playdate hardware.** The last hardware game
requested a restart; only the safe calibration app has since passed on hardware.

Current P0 game change on main: `92103bb`. Imported maps use two cache slots.
Startup work yields; map cells use validated packed rows. Field data/art prepares
at map entry. Encounter policy reads retain every commit guard without repeated
slot copying. Original source grids, world/story/rules and protected pixels remain.
The approved GB tones and non-audio QoL remain; no new regions are active.

Simulator preview packages: `evidence/player-packages/5.4-playable-20261028`.
Showcase: `evidence/milestone-5.4-showcase-20261028/PokemonBlue-5.4-showcase.mp4`.
These are not verified device deliveries.

## 2. Current checkpoint and checklist

**P0 hardware boot: in progress. Checkpoint 5.5a: frozen.**

- [x] Persistent phase trace, guarded error screen, cooperative loading.
- [x] Simulator 16 MB pool verified (`MallocPoolSize=16645684`).
- [x] Calibration, serial print/messages and attached-device coexistence verified.
- [x] Earned-save smoke reaches title, Continue, save, doors, Cut and wild battle.
- [x] Simulator Lua heap fits 6 MiB live / 9 MiB sampled-peak targets.
- [ ] Ordinary frames, loading slices and map latency fit timing limits.
- [ ] Exact hardware build reaches title and earned Continue.
- [ ] Hardware warp, battle, save, logs, timing and memory pass.

Then accept 5.5a (Rock Tunnel/Lavender/Celadon/Erika/Hideout/Scope),
5.5b (Tower/Fuji/Flute/Fuchsia/Safari/Koga/Surf/Strength), and
5.5c (Saffron/Silph/Sabrina/Dojo/Fly), each on main with three chained earned saves.
Only one starter covers optional content. Sets continue after a starter fails.

## 3. Open defects and evidence

Latest policy candidate run: `evidence/p0-policy-smoke-20261029-02`, exact build
`31900e32f92b4fdbb8467b62137e36e6`, same game Source now accepted on main.
It reached all smoke steps without a runtime error. Live Lua heap **5.09 MiB**,
sampled peak **6.56 MiB**, excluding native image memory; 16 MB pool enabled.
Timing **fails**: ordinary update **3.462 ms**, slice **29.153 ms**, map wall
**172 ms**, provisional device map estimate **2.67 s**. An earlier policy run had
a large outlier and remains failed. No new game build was deployed to hardware.

The synthetic factor **35.11** is conservative and provisional, not a game-phase
measurement. Calibration evidence: `evidence/p0-calibration-device-cycle-20261028-03`
and `evidence/p0-calibration-simulator-16mb-20261028-01`.
The safe app remains awake for USB control. Close serial readers before SDK use.
If a hard crash recurs, stop hardware attempts for the night: device needs one A press.
Diagnostic-only builds are rejected before hardware access, even if their metrics pass.

Current SDK evidence: 54 encounter/acquisition/specimen cases in
`evidence/p0-borrowed-policy-{encounter,acquisition,specimen}-sdk-20261029-01`;
46 field/field-world/save cases in `evidence/p0-prepared-{field,field-world,save}-sdk-20261029-01`.
Both reviews were clear. All 24 native Cut frames remain exact RGBA in
`evidence/p0-cut-art-{before,after}-20261029-02`.
Packed-cell code passed 44 SDK cases and all **2,494** protected images in
`evidence/p0-packed-cells-final-protected-catalog-20261029-01/comparison.json`.
That comparison combines two independent exports; it is not hardware acceptance.

Component measurements: six-member freshness reads **0.173 → 0.082 ms**;
Route2 construction **20.9 → 12.6 ms**; encounter prepare/resolve **1.12 → 0.85 ms**.
These do not establish a whole-route timing pass. Cave spikes occur after movement
completion, during encounters; completion-only probes miss that following update.
Full host run: **960/961 passed**, zero skips, in `evidence/p0-current-host-20261029-05.log`.
Both geometry-loader errors are repaired without changing the collision reference.
The sole remaining failure is stale coverage; historical evidence is not relabeled.
Use small existing SDK batches: the monolithic development harness exceeds 16 MB.

## 4. Work in flight

Root owns main, Simulator and hardware. A Sol/medium worker is preparing fewer
static wall sprites in an isolated branch, preserving exact collision, registration,
visibility and rollback. Root will run the existing SDK coverage/rollback cases,
compare pixels and measure before integration. Current main host checks are next.
The terrain-image cache, whitespace-only JSON compaction and update-flag/GC-step
experiments showed no useful route gain and remain excluded.

`wip/midgame-integration`: 108-map checkpoint A, frozen; needs current P0 changes
and the same memory/device gate. Later content, trades and guards remain parked.
Root audio, cleanup and Safari polish remain paused. Resume minimal audio after 5.5a.

## 5. Decisions and history

Keep Blue world/story/dialogue, Gen V rules, 151 species and protected art.
Approved display changes: imported GB tones plus museum/Route2 diagnostics.
Crank, registered A+B, manual Bag sort, reusable TMs and B2W2 Pickup are approved.
Trades require taking held items first but remain parked. No repeated policy or volume questions.
Detailed history: [earlier device reports](progress-history-device-p0-20261029.md),
[loading reports](progress-history-p0-loading-20261029.md).
Accepted summaries: [setup](divemac-baseline-20261026.json), [Brock](brock-acceptance-20261026.json),
[foundations](foundation-acceptance-20261026.json), [Cerulean](cerulean-acceptance-20261028.json),
[Vermilion](vermilion-acceptance-20261028.json).
Prior housekeeping freed 16.13 GB and removed at least 94 clean worktrees; further cleanup is paused.
Journey data stays in `Source/dev`; references regenerate from checksum manifests.
Packages, earned slots and clips remain outside Git. **Local commits await an explicit push request.**
**The full game remains unfinished.**
