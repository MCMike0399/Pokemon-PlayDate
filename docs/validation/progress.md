# Full-game execution ledger

Updated 2026-10-28. Follow [the goal](../plans/full-game-goal.md).
Progress: **30 / 222 source maps playable on main. Current milestone: 5.4.**

## 1. Accepted revision and what the player can do

Accepted game code: `1794e48`. Source:
`44280b886e08a3549f502b4383e9e191f7264b85a9f3bc7a6881f2268c989529`.
A player can continue an earned Brock save, cross Mt. Moon, choose a fossil,
beat Misty and the Bridge rival, clear Nugget Bridge, help Bill, receive the
S.S. Ticket, save, quit the process and Continue with any starter.
The opening and protected art remain intact. Audio, later Kanto, the League,
postgame and physical-device checks remain unfinished. Commits are local;
nothing has been pushed since the user's earlier explicit request.

## 2. Milestones and checks

**5.0 — DiveMac setup: done.** Environment and smoke passed, 529 host tests,
1091 SDK checks and 2494 protected images.
[Setup summary](divemac-baseline-20261026.json).

**5.1 — Pallet to Brock: done.** All three natural starter journeys, rewards,
actual process exit/Continue, full-bag retry, blackout and evolution cases passed.
Charmander's old level-16 preparation was an evolution witness, not pacing proof.
[Brock summary](brock-acceptance-20261026.json).

**5.2 — Shared foundations: done.** Map loading, events, NPC movement, text,
production builds, loud move failure and phazing passed. Main had 1274 SDK and
605 host checks; all 2494 protected images and nine journey cases passed.
[Foundation summary](foundation-acceptance-20261026.json).

**5.3 — Pewter to Cerulean: done.**

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

**5.4 — Vermilion and the first HMs: next.** Merge accepted main into the one
existing Vermilion branch, then fix its current failures. Its three journeys
must start with the accepted Cerulean saves and continue after individual
failures. No later region preparation starts before 5.4 is accepted.

## 3. Open problems

No known defect blocks the accepted Cerulean path. Full mechanics and rare
interactions remain separate release work. Device validation has not run.

Vermilion has unaccepted field-move, Day Care, trade and save-fixture work.
Its Route 2 collision image changes four door cells; that diagnostic update
has **not** been approved. It needs actual images and review before acceptance.
Audio and later campaign work remain parked.

## 4. Work in flight

| Branch | Next step |
|---|---|
| `main` / root | 30/222 maps; 5.3 accepted. GPT-6.1 Sol integrates and validates; only root runs the Simulator. |
| `wip/vermilion-integration` | Accepted main is merged. Journey JSON is now in `Source/dev`; all three journeys start from the accepted Cerulean saves. Native rerun: 2167 passed, one old reward-name expectation failed. That expectation is updated and another run is active. Three invalid synchronous sprite-callback cases were removed; the real Day Care journey checks step growth. Next: three starters with continue-on-failure. |
| Audio, trades and Saffron branches | Parked. Existing needed 5.4 content is handled only through the Vermilion branch. |

Workers use `gpt-6.1-sol` at medium effort in separate worktrees.
The cleanup removed at least 93 clean superseded worktrees and 173 old evidence
directories, freeing 15.3 GB of evidence. Branches and required evidence remain;
two dirty worktrees were kept intact.

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
