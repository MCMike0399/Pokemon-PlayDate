# Full-game execution ledger

Updated 2026-10-28. Follow [the goal](../plans/full-game-goal.md).
Progress: **30 / 222 source maps playable on main. Current milestone: 5.4.**
Last accepted pace: **11.57 maps/day**; 5.4 elapsed: **4.6 h**.
[Wall-clock times per milestone](milestone-times.json) include waits and provider limits.
The reduced 5.4 set uses Bulbasaur for optional content and the other starters
for the critical path. Both journey JSON files already live in `Source/dev`, outside production. Cleanup of remaining bundles waits until journeys stop. Quality workers run alongside journeys; root does not
spend turns polling them. Acceptance includes playable packages and a real-speed clip.

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

**5.4 — Vermilion and the first HMs: next.** Merge accepted main into the one
existing Vermilion branch, then fix its current failures. Its three journeys
must start with the accepted Cerulean saves and continue after individual
failures. No later region preparation starts before 5.4 is accepted.

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
| `main` / root | 30/222 maps; 5.3 accepted. GPT-6.1 Sol integrates and validates; only root runs the Simulator. |
| `wip/vermilion-integration` | 2169 native checks pass, including the observed Odor Sleuth effect; full host checks pass. The next three saved-checkpoint retries are `m54-progress-retry-<starter>-20261028-03`, with continue-on-failure. Cabin visits now cover each connected room once rather than each paired exit mat; the earlier occupied-goal failure is fixed. Center visits, real medicine purchases and the existing blackout budget replace grinding. Captures and Day Care progress are preserved in actual saves. Approved Route2 image change is recorded; 5.4 remains unaccepted. |
| Play quality | Three Sol/medium workers prepare map shade proposals, battle presentation/options and native synth audio. HP/EXP animation, trainer entry, title art, running, options and audio hooks are isolated on `wip/play-quality-native`; native visual/audio checks remain pending before release integration. The user rejected the whitened-ground proposal. The visual target is now the original GB four-shade tonal structure reproduced in 1-bit. New comparisons start with Route1, Route24 and the Cerulean Center. No shade change is approved or included in the release branch. |
| Trades and Saffron guards | Preserved on `parked/npc-trades-saffron-20261028`, removed from the 5.4 release. |

Workers use `gpt-6.1-sol` at medium effort in separate worktrees.
The cleanup removed at least 93 clean superseded worktrees and 173 old evidence
directories, freeing 15.3 GB of evidence. Branches and required evidence remain;
two dirty worktrees were kept intact.

Quality check on the separate branch: 2081 native cases passed and five failed
in `play-quality-sdk-20261028-01`. Four failures involve presentation/text timing;
one learning-screen check calls an unavailable SDK image method. Repairs are
assigned, and none of this code is release-accepted. The production preview build
is outside Git at `evidence/player-packages/5.4-preview/PokemonBlue.pdx`; its
finished starter saves and showcase clip remain pending.

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
