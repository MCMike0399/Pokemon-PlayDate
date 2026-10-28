# Full-game execution ledger

Updated 2026-10-28. Follow [the goal](../plans/full-game-goal.md).
Progress: **65 / 222 source maps playable on main. Current milestone: 5.4 (delivery pending).**
Last accepted pace: **11.57 maps/day**; 5.4 elapsed: **6.09 h**.
[Wall-clock times per milestone](milestone-times.json) include waits and provider limits.
The reduced 5.4 set uses Bulbasaur for optional content and the other starters
for the critical path. Both journey JSON files already live in `Source/dev`, outside production. Cleanup of remaining bundles waits until journeys stop. Quality workers run alongside journeys; root does not
spend turns polling them. Acceptance includes playable packages and a real-speed clip.

## 1. Accepted revision and what the player can do

Game code on main: `1a4a7894aa40125147e8f2d227fd1da6320dd341`. Source:
`3ac88fe4dad4d0b1f5624a6f3eac025ac8814cb57fc14a4b3e7eb7cb34ca628d`.
A player can continue an earned Misty/Bill save, cross Routes5/6 and the
Underground Path, use the Day Care and Fan Club, explore the Anne, beat the rival,
receive Cut, beat Surge, cross Diglett's Cave and receive Flash. All three starters
passed actual process restart/Continue at the Flash aide. The game code is on
main; milestone 5.4 stays open until the playable packages and 60–90 second clip
are delivered. Audio and modern controls are prepared separately and still need
final integration. Later Kanto, the League, postgame and device release remain
unfinished. Nothing has been pushed since the earlier explicit request.

## 2. Milestones and checks

**5.0 — DiveMac setup: done.** Environment and smoke passed, 529 host tests, Wall clock: 0.13 h.
1091 SDK checks and 2494 protected images.
[Setup summary](divemac-baseline-20261026.json).

**5.1 — Pallet to Brock: done.** All three natural starter journeys, rewards, Wall clock: 5.62 h.
actual process exit/Continue, full-bag retry, blackout and evolution cases passed.
Charmander's old level-16 preparation was an evolution witness, not pacing proof.
[Brock summary](brock-acceptance-20261026.json).

**5.2 — Shared foundations: done.** Map loading, events, NPC movement, text, Wall clock: 1.79 h.
production builds, loud move failure and phazing passed. Main had 1274 SDK and
605 host checks; all 2494 protected images and nine journey cases passed.
[Foundation summary](foundation-acceptance-20261026.json).

**5.3 — Pewter to Cerulean: done.** Wall clock: 37.35 h.

- All three paths began with the accepted Brock saves. Bulbasaur's final path
  passed 28 real battles with no blackouts or preparation grinding. Centers,
  restocking and actual progress saves replaced XP farming.
- Squirtle and Charmander finished Bill and saved, then a screenshot check
  failed. The check was simplified; their actual earned saves passed separate
  Save/Continue retries. The original failures remain failures. Those paths
  were played before later battle fixes; the fixes passed native contracts.
- Teleport, Pursuit, Disable, Camouflage, Magnitude, Encore and Water Sport now
  have their effects. Final result: 1666 SDK checks, 723 host tests, zero failures
  or skips. All 2494 protected images match; 2448 new images were reviewed.
- Ticket/TM11 full-bag retries, both fossil choices and blackout recovery passed.
  The museum's two door openings were the only approved protected-image change.
- [Cerulean acceptance](cerulean-acceptance-20261028.json) records exact run paths,
  source versions and limitations. [Save hashes](chain-saves.json) identify the
  actual saves in `~/Developer/Pokemon-PlayDate-env/evidence/chain/5.3/<starter>`.

**5.4 — Vermilion and the first HMs: gameplay passed; delivery pending.**
All three earned-save journeys and actual restarts passed, with 2077 SDK checks,
918 host checks and all 2494 protected images exact. Main now has 65 source maps.
[The summary](vermilion-acceptance-20261028.json) retains the full save ancestry,
earlier failed outcomes and completed optional actions. The final checkpoint is
the Flash aide; the unnecessary second cave crossing was removed. No 5.5 region
preparation starts before the remaining delivery work is complete.

## 3. Open problems

No known defect blocks the accepted Cerulean path. Full mechanics and rare
interactions remain separate release work. Device validation has not run.

Vermilion has unaccepted field-move, Day Care and save-fixture work. NPC trades
and Saffron guards are removed from its release branch and kept separately.
Its Route 2 collision image changes four door cells; the user approved that diagnostic update on 2026-10-28 after reviewing the
actual four-cell difference (4096 pixels). It is updated on the private branch.
Audio is active as a quality track; later campaign work remains parked.

## 4. Work in flight

| Branch | Next step |
|---|---|
| `main` / root | 65/222 maps; 5.4 gameplay passed, delivery pending. GPT-6.1 Sol integrates and validates; only root runs the Simulator. |
| `wip/vermilion-integration` | 5.4 remains unaccepted. The current saved-checkpoint set is `m54-progress-retry-<starter>-20261028-07`, with continue-on-failure. Fixed Anne waypoints, actual Super Potion use and Center visits replace planner changes and grinding. Earned captures, Day Care progress and HM01 saves are retained. Trades and guards are removed; the approved Route2 collision image is retained. |
| Play quality | Three Sol/medium workers prepare map shade proposals, battle presentation/options and native synth audio. HP/EXP animation, trainer entry, title art, running, options and audio hooks are isolated on `wip/play-quality-native`; native visual/audio checks remain pending before release integration. The user rejected the whitened-ground proposal. The visual target is now the original GB four-shade tonal structure reproduced in 1-bit. New comparisons start with Route1, Route24 and the Cerulean Center. The user chose GB grey as the reference; Bayer is the closest measured 1-bit reproduction. Its ten-second native walking run passed. The mapping is prepared separately, with Pallet, interiors and sprites unchanged; catalog review remains pending before release integration. |
| Trades and Saffron guards | Preserved on `parked/npc-trades-saffron-20261028`, removed from the 5.4 release. |

Workers use `gpt-6.1-sol` at medium effort in separate worktrees.
The cleanup removed at least 93 clean superseded worktrees and 173 old evidence
directories, freeing 15.3 GB of evidence. Branches and required evidence remain;
two dirty worktrees were kept intact.

Quality check on the separate branch: 2086 native cases passed after repairing five obsolete checks. All 2494 protected images match in `play-quality-sdk-20261028-02`. This code remains separate from the release until visual review. The production preview build
is outside Git at `evidence/player-packages/5.4-preview/PokemonBlue.pdx`; its
finished starter saves and showcase clip remain pending.

The latest three saved-checkpoint runs reached the Gym. The driver ignored
purchased Super Potions because it only selected ordinary Potions. It now uses
actual stronger medicine and visits the Center between Gym trainers. The next
set is `m54-progress-retry-<starter>-20261028-07`, with continue-on-failure.
No preparation grinding was added. The prior played runs logged no missing
move or ability effects; Squirtle's earlier checksum failure did not reach play.

The second cleanup removed one clean superseded worktree, retaining its branch,
and 57 unreferenced compile-only bundles: another **0.83 GB**, for **16.13 GB**
freed across both cleanup passes. Active and dirty worktrees remain.
`evidence/cleanup-20261028/second-pass-result.json` records the removals.
Both journey data files are already under `Source/dev`.

Native GB-tone motion: `evidence/gb-tone-native-clip-20261028-02/native-proposed-motion.mp4`
contains 300 native 400x240 frames at 30 FPS (10 seconds), with source/frame hashes.
It is a visual witness, not a campaign completion claim.

Bulbasaur and Charmander beat Surge in retry 06 and saved their real badge/TM24
progress. Their later failures were cave routing/Run decisions, not missing game
effects. Diglett's Cave now has fixed corridor waypoints; the driver fights when
Arena Trap prevents escape and reuses learned Cut and earned rewards.

The isolated quality build passed actual input checks in
`evidence/quality-input-native-20261028-03`: fresh title, Town Map registration,
A+B opening and manual Bag sort. A startup omission was fixed so an empty save
also shows the title. These are supplemental UI checks, not natural item grants.
The four additional SDK behavior cases and full changed-tone catalog still need
root execution. Three production preview bundles with accepted 5.3 saves are
prepared at `evidence/player-packages/quality-preview-20261028`, but remain
unpublished while final quality checks are pending.

## 5. Decisions

- Finish one milestone before resuming the next. Keep one next-milestone branch.
- Chain journeys from accepted saves; only the release pass starts at New Game.
- No new policy questions beyond 5.4 for now. No invented rewards or XP farming.
- Fix effects that real play reaches; add one contract per new behavior.
- Simplify repeated tooling failures. Do not add fixture-proof contracts or
  diagnostics around a failed screenshot check.
- Exact B2W2 Pickup and taking held items before NPC trades were approved.
- Commit accepted work locally. Push only when the user asks.

[Earlier ledger](progress-history-before-cerulean-20261028.md) preserves failures
and the earlier source versions; its in-flight statuses are historical.
