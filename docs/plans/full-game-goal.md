# Goal: finish Pokémon Blue for Playdate

This is the persistent goal for the agent implementing this repository. It
supersedes [astra-full-game-goal.md](astra-full-game-goal.md). That file stays
for history and its product decisions are carried over here. If anything in an
older document conflicts with this one, this one wins. Explicit user decisions
recorded in the [fidelity ledger](../validation/fidelity-ledger.md) still bind.

Written 2026-10-26 from a full review of the code, docs, ledger and git history
at `87e90e8`. Work now happens on **DiveMac**. See "Machine and environment" below.

---

## Play quality direction — 2026-10-28 (latest user steer)

The target is a native Blue that feels good on Playdate, with Gen V rules and
modern quality of life. Quality tracks run alongside 5.4/5.5, not after the map work.
Keep 2–3 Sol/medium workers active on tileset legibility, battle presentation/QoL
and native synth audio. The root reviews and integrates while journeys run in the
background, reporting passes, failures and new defects rather than polling turns.

One rotating starter per milestone covers optional content. The other two cover
only story gates, rival, gym, HM/badge rewards and Save/Continue from earned saves.
Use fixed waypoints for troublesome maps. Before 5.4 merges, park NPC trades and
Saffron guards; Pickup remains. Add no driver/journey Simulator contracts.
Frames name their milestone and map. Keep new Lua one statement per line.

Imported terrain needs reviewed per-tileset shade mappings above immutable source
data. The user approves OVERWORLD, CAVERN and SHIP separately before merge.
Pallet/interiors, RED and NPC sprites stay exact. Review source/current/proposed
at native size and 2x, plus native motion. Battle work starts with HP/EXP animation,
learning HUD layout and Gen 1 evolution text, then intros/send-out/recall/faint,
reusable type effects, animations-off and trainer-class AI.

Approved QoL now: hold B to run, fast default text with hold-A acceleration,
Options (text speed, battle animations/style), and a real generated title screen.
Record deliberate changes in the fidelity ledger. Propose crank controls,
registered key items, bag sorting and reusable TMs; implement only after approval.
Audio is unparked: original scores to native synth, first town/route/battles/heal/
menu/hit/faint/low-HP. At every milestone acceptance starting 5.4, provide outside
Git production .pdx bundles, earned starter saves, one-line loading instructions,
and a 60–90 s real-speed clip covering walking, a full trainer battle, the gym and
a cutscene. Record paths, elapsed milestone hours and maps/day in the ledger.

## Course correction — 2026-10-28

Finish and accept one milestone before resuming the next. Freeze Vermilion,
Saffron guards, trades and audio until 5.3 is accepted on main. Keep only one
next-milestone branch checked out. No policy questions beyond 5.4 for now.

Natural journeys start from the previous milestone's accepted save for that
starter, stored outside Git at `~/Developer/Pokemon-PlayDate-env/evidence/chain/<milestone>/<starter>`.
Commit only save hashes and provenance. Run all three starters with
`--continue-on-failure`. Only the release pass replays New Game through credits.
Cap preparation battles; use medicine and Centers instead of grinding.

A harness failure is a tooling bug. If the same check fails twice for reasons
unrelated to gameplay, simplify or remove it instead of adding diagnostics.
After each journey, count missing effects in its logs and fix the most frequent
ones first, starting with wild Teleport. Use Showdown gen5 and one contract per
new behavior. Do not add contracts for fixtures or repeat accepted proofs.
Fix a shared fixture factory rather than repairing many individual fixtures.

Every ledger update reports playable source maps on main out of 222 and the
current milestone. Keep acceptance entries and commit messages in plain words.
Remove clean superseded worktrees without force, retaining branches. Delete
compile-only and superseded evidence, retaining acceptance references, ledger
references and the newest failure per milestone. Keep journey data outside
production Source. Generate large reference extracts from the reference
checkout and record checksums instead of committing the extracts.

## 1. What we are building

A complete, enjoyable, native Lua recreation of **Pokémon Blue** for Playdate.
It runs from New Game through the Elite Four, Champion, Hall of Fame and credits,
and on into the original postgame (Cerulean Cave and Mewtwo, plus the legendaries).

The product identity was chosen by the user and is not open for re-litigation:

| Layer | Source of truth |
|---|---|
| World, map geography, story, progression, characters, dialogue, visual feel | **Red/Blue** (pinned `pret/pokered` `af519899719f0754965776faac0e836a3b906e6d`). Use Blue where versions differ. |
| Battle rules, base stats, physical/special split, learnsets, 17-type chart (Dark/Steel) | **Gen V / B2W2** |
| Abilities, natures, held items, IVs/EVs | **Added deliberately** (user decision 2026-10-20), with Gen V behavior for the original 151 |
| Roster | Original 151 only. No Fairy, Megas, later species or unrelated modern features. |
| Platform | 400×240 1-bit display, 30 FPS target. Native Lua, not an emulator, and no ROM is loaded at runtime. |

Do not revert combat to Gen I for the sake of fidelity. Do not invent original-world
rewards, such as a Mew encounter or held items as Kanto loot, without logging them
as deliberate changes. Every intentional deviation gets a row in the fidelity ledger.

### The art is the foundation

RED, BLUE, Oak, Mom, Daisy, the Pallet tiles and the interiors took many
iterations to get right. Keep them exactly as they are. The visual catalog protects
2494 images; they must stay pixel-exact unless the user approves a reviewed change.
CLAUDE.md lists the contracts:

- RED's hand-tuned grids are never regenerated.
- NPC sprites come from the pinned converter (`outline` for Oak, `greyhair` for BLUE, Mom and Daisy).
- Masks, 8-frame steps, grass occlusion, exit arrows, water/flower animation and roof composites stay as they are.

New maps, characters and tiles must extend the same source-to-grid pipeline and match the style.

---

## 2. Where the project actually is (2026-10-26)

### Timeline

- **June 2026.** A human and agent iterated by hand. The work produced:
  - authored Pallet Town and its interiors;
  - the Gen 1 intro;
  - runtime sprite and tile factories;
  - the first Gen V battle engine;
  - autopilot.
- **2026-10-20 → 10-21, about 31 hours.** A Codex `/goal` run did the next phase. A GPT-6.1 Sol root orchestrated it, with Sol/medium workers. It made 11 commits and added about 340k lines to Source and tools, including generated data and pinned references. It also added about 6,400 doc and evidence files. Then the user paused it at `87e90e8`.

### What exists and works

Component tests pass on Source `44bd25…`. That source hash is a fingerprint of the Source tree at that point, and it is not a git commit. At that source, 1091 SDK contracts and 529 host tests pass. All 2494 catalog images are exact. On DiveMac (2026-10-26), the build compiles and the protocol tests pass.

**Harness**
- An identified Simulator runner, `tools/harness/run.py`, runs a UUID bundle. It holds a per-user lock, uses private save Data, and has a build handshake.
- It uses a versioned protocol. Supported operations include semantic `assert`/`await`, fixtures, captures and quiesce.
- Supporting tools:
  - a serial suite with mutation qualification;
  - multi-process restart jobs;
  - a full visual catalog and an exact comparator;
  - resource profiling;
  - a move verifier pinned to B2W2 sources.

**Domain**
- `GameSession` is the single owner of durable state. That covers the party, 12×20 PC boxes, bag, item PC, flags, the Pokédex, checkpoint, world deltas and both RNG streams.
- `SaveStore` keeps two checksummed slots with archives. It recovers from corrupt saves and offers a safe New Game.
- Supporting pieces:
  - decimal-string counters for precise JSON;
  - a separate world RNG for NPC wandering;
  - IV/EV/nature/ability/sex/held-item specimens, with codec migrations.

**Gameplay**
- **Battles:** 1v1 battles, party switching, the bag in battle, capture with animation, move learning, natural and stone evolution, and TM teaching.
- **Overworld:** the Pokédex, Town Map, shops, healing, blackout, field items, trainer sight and approach, and NPC motion.
- **Battle content:**
  - about 22 ability handlers;
  - Rain and Sand weather;
  - Light Screen, Safeguard and Tailwind;
  - Protect, Bide, charge moves, Roost and others.

**World**
- Authored Pallet and its 4 interiors.
- Imported from pokered:
  - Route 1;
  - Viridian City, its Mart and its Center;
  - Route 2;
  - both Forest gates and Viridian Forest;
  - Pewter City, its Gym, its Mart and its Center.
- The furthest playable point is **Brock**. The Boulder Badge and TM34 are available.

### What is not done

- **Campaign.** None of the 222 named source maps beyond those ~13 exist. Missing areas include Route 22, Route 3, Mt. Moon, Cerulean, every later town, every other gym, the League and the postgame. There is also no audio at all: no music, SFX or cries. Naming and options screens are missing too.
- **Brock gate.** The all-three-starters gate was never closed:
  - Squirtle passed.
  - Bulbasaur failed, but because of a harness *driver* bug (zero-step warp route after a blackout), not a game bug.
  - Charmander was interrupted by the user.
  - Two patches were left frozen and unapplied (see §5.1).
- **Moves.**
  - **72 of the 153 status moves have no behavior at all.** Examples are Whirlwind, Roar, Reflect, Haze, Rest, Substitute, Metronome, Transform and Sunny Day. They silently do nothing, which breaks the "no successful no-op" rule.
  - Several damaging special cases are open too: Dig, Fly, Magnitude, Fury Cutter, Gyro Ball and Razor Wind.
  - In the coverage report, about 285 move records are unreviewed.
- **Abilities and weather.** About 22 of the 111 abilities needed by the 151 species have handlers. There is no setter for Sun or Hail weather.
- **Production build.** `main.lua` imports 90 `dev/` modules, including every contract suite, into the build that would ship.
- **Device.** Never run on a physical Playdate. Nothing about device memory or frame timing has been measured.

### How it was built: lessons to keep and to change

**Keep these. They work.**
- Pinned primary sources with checksums. Generators get independent oracles.
- One owner of the Simulator, plus identified builds. Saves are isolated from real player data.
- Separate rules RNG from cosmetic randomness. Use deterministic seeds.
- Exact pixel protection of accepted art, with mutation tests proving that the checks can fail.
- An honest ledger: implementation and acceptance are kept separate. Failures and interruptions never get credit.
- Atomic session transactions, so a full bag or a cancelled reward can never lose a quest item.

**Change these. They cost the most time for the least game.**
1. **Process became the product.** In the last 10 hours before the pause, most of the effort went to evidence formats, packets, errata and re-qualification. Gameplay got little of it. About 13 of 222 maps exist. Verification must stay proportional (see §4).
2. **Mechanics went too deep, too early.** Examples:
   - the 1/2^32 Protect streak branch;
   - Bide against Protect, decided across native C and Showdown;
   - Mud Sport stacking policy.

   That depth was spent while most of Kanto doesn't exist. Use the reference oracle in §4.3, record any disagreement in one line, and move on.
3. **Unreadable docs.** The ledger and coverage docs use fused shorthand ("Source44bd", "1091SDK", "Codec7", "all3"). A fresh agent cannot follow them without re-deriving everything. Write plain sentences.
4. **Work-in-progress lived in fragile places.** About 100 tarball "handoffs" (33 MB) were committed into `docs/plans/*handoffs`. Live candidates sat in `/private/tmp`, and they were lost on reboot. For example, the "root-private composed candidate" named in the ledger no longer exists. Use git branches and worktrees instead.
5. **Three map pipelines.** These are:
   - authored `Zone` (Pallet);
   - eager `KantoSlice` (Viridian);
   - lazy `PewterSlice` + `ImportedMaps` (Pewter).

   They differ in padding, binding and stable-ID conventions, and every source event is handled by a hand-written ID table across four dispatch modules. That does not scale to more than 200 maps.
6. **Dense code style.** Recent Lua files pack several statements onto one line. That makes review and diffs hard. New code must match the readable style of the original June files.

---

## 3. Operating model

### Agent runtime

- The user's last explicit choice was GPT-6.1 Sol as the root orchestrator, integrator and final validator, with **Sol subagents at medium effort** for bounded tasks.
- In Codex, request those explicitly for every worker. Do not silently substitute a model or raise the effort.
- If running under a different harness, such as Claude Code, use that harness's equivalent: a strong root with bounded workers. Say which models are actually in use in the ledger.

### Ownership

- The root alone owns the Simulator, the integrated build, acceptance and the ledger.
- Workers get self-contained packets. A packet contains:
  - the outcome;
  - acceptance checks;
  - the owned files;
  - the base commit;
  - the constraints.
- Workers return a branch or diff, with tests and limitations.
- Never let two agents edit the same shared file at the same time. Those files include `battle.lua`, `gameSession.lua`, `main.lua`, the codecs and `zone.lua`.

### Work in progress

- Workers use `git worktree` branches named `wip/<topic>`.
- The root reviews, merges into `main` and reruns checks on the merged revision.
- Do not add new tarballs to `docs/plans/*handoffs`. The existing archives are a frozen history; extract from them when needed.
- Anything that must survive a reboot does **not** go in `/private/tmp`. Large runtime evidence goes under `~/Developer/Pokemon-PlayDate-env/evidence/<run>`. Commit only small summaries (JSON or markdown) and reviewed baselines.

### Committing

- Commit to `main` at each accepted step, with a clear message. Omit any AI attribution lines.
- Push only when the user asks. Mention in the ledger that local commits are waiting to be pushed.

### The ledger

[`docs/validation/progress.md`](../validation/progress.md) is the resume point after compaction. On the first session, rewrite it into this shape, in plain sentences and no longer than about 150 lines:

1. Current accepted commit and what a player can do on it.
2. The current milestone, its checklist, and status (done / in progress / blocked).
3. Open defects that block progress.
4. Work in flight: branch, owner, next step.
5. Decisions made since the last user check-in.

Move older material to `progress-history-*.md`. Don't delete history.

### Asking the user

Decide routine matters yourself. Ask only about consequential product questions, such as:

- version exclusives and trades;
- Mew;
- an obedience or badge-boost policy;
- whether to change protected art.

Give a recommendation when you ask, and keep doing independent work while you wait.

---

## 4. Verification that stays proportional

Every milestone still needs real evidence. The rule is: **prove the player
experience, and stop proving a thing once it is proven.**

### 4.1 Checks for every change merged to main

These run at merge time, not per worker step:

- `make compile` succeeds.
- `make test-harness` passes, plus the host tests that touch the changed area.
- The host tests run under the env script with no skips. Run the full suite before each milestone acceptance.
- The SDK contracts pass. Run `python tools/harness/run.py contracts --output <new dir>`.
- The visual catalog is compared in protected-preservation mode. Changed protected pixels fail. New art is listed and reviewed by actually looking at it at native size.

### 4.2 Milestone acceptance

For each milestone in §5, write **one** scenario set of real-input journeys. No teleports, debug shortcuts or HP edits are allowed in the natural journey. Fixtures can supplement it, but never replace it.

The set covers the milestone's critical path, plus:

- Save, quit the process, then Continue.
- Blackout recovery.
- A full-bag retry for any key-item reward.
- One journey per starter whenever the starter choice changes encounters, such as the rival's team or a type-locked gym.

The milestone is accepted when that set passes on the merged commit **and** the root has looked at the key screenshots.

A harness driver bug is a tooling bug:
1. Fix the driver.
2. Rerun.
3. Don't build a forensic dossier around it.

Record the result in about five lines in the ledger, with the evidence path.

### 4.3 Mechanics policy

- **The default oracle for Gen V battle behavior is pinned Pokémon Showdown gen5.** Use its mod chain. Fall back to Bulbapedia or the decompiled native code only when Showdown is clearly wrong.
- If references disagree, choose one. Record it as a single fidelity-ledger row, and move on.
- **Every move, ability and held item a player can meet must do its real effect or fail loudly.** "Meet" means anything reachable in the current campaign: learnsets up to the realistic levels for the area, TMs/HMs obtained so far, trainer parties and wild Pokémon.
  - Fail loudly means it shows "But it failed!" and records a gap in a dev log.
  - A silent success is never acceptable.
- As the first task of §5.2, make every unimplemented move fail loudly, then implement in order of exposure.
- Rare branches (very low probabilities, doubles-only behavior, interactions no Red/Blue party can produce) wait for the release pass. Record them in the coverage matrix.

### 4.4 Visual policy

- **Protected art:** pixel-exact, as above.
- **New art:** generated from pinned sources through the established converters with explicit dither phase. The root inspects it at native size and in motion. Write a provenance note per new asset family, not per image.

---

## 5. Milestones, in order

Each milestone finishes with §4.2 acceptance and a ledger update. Only then does the next one start. Workers may prepare the next milestone on branches in parallel.

### 5.0 Re-establish on DiveMac (first session)

1. Run `source ~/Developer/Pokemon-PlayDate-env/env.sh` and confirm `git status`. HEAD should be `87e90e8` plus the uncommitted goal and doc updates. Commit those doc updates first.
2. Run the full host suite with no skips, `make harness-smoke`, the SDK contracts, and a catalog comparison against the current 2494-image baseline `docs/validation/catalog-pewter`.

   Do not compare against the older 915-image `baseline-catalog` or `baseline-initial`. [visual-catalog.md](../validation/visual-catalog.md) explains how the baselines relate.
3. Rewrite `progress.md` into the §3 shape.
4. Fix the stale parts of CLAUDE.md:
   - the world now reaches Pewter;
   - list the `domain/` owners;
   - add the imported-map providers;
   - encounters use source rates, not a flat 15%.

### 5.1 Close Pallet → Brock

1. Apply only the 3 paths from `implementation-handoffs/pokemon-brock-warp-reentry-01.tar.gz`, plus the separate learning-panel patch from `pokemon-brock-learning-evidence-01.tar.gz`. Check the sha256 values against `manifest.json` first. The composed candidate in `/private/tmp` is gone, so recompose it from those two patches. Neither patch changes game Source.
2. Rerun the native warp-return check, then natural Bulbasaur, Charmander and Squirtle → Brock journeys with Save/Continue. Then run the five supplementary cases:
   - tm-full-retry;
   - blackout;
   - restarts;
   - evolution accept;
   - evolution cancel.
3. Training a starter to level 16 to witness evolution is fine. Label it as a witness, not a pacing proof.

**Done when:** the user can start a new game, beat Brock with any starter, save and continue. Record it in the ledger.

### 5.2 Scale foundations (before new regions)

These are what make the next 200 maps feasible. Do them as small, tested refactors that keep every existing test and image exact.

1. **Loud failure for unimplemented moves.** Then do **Whirlwind and Roar**, which are already exposed before Mt. Moon. Use the frozen `pokemon-whirlwind-01` packet as a starting point.
2. **One map pipeline.** Converge Viridian and Pewter onto a single source-map importer with one provider and cache. It covers:
   - blocks to cells;
   - collision;
   - warps and connections;
   - objects and signs;
   - text;
   - encounter tables;
   - trainers.

   Authored Pallet stays as is, behind an adapter. Adding a map should mean "add its ID to a manifest, then handle its bespoke script."
3. **A source-script event layer.** Turn the hand-written handler tables (`SliceEvents`, `PewterEvents`, `TrainerEvents`, `KantoWorld.tryInteract`) into one dispatcher. It should be data-driven, with reusable plan ops (dialog, give item, battle, move NPC, set flag, heal, shop, warp). Only truly bespoke scripts get Lua code, and that code is keyed by stable source event IDs.
4. **A production build without `dev/`.** Gate dev and contract imports behind a harness-only overlay, the same mechanism as `HarnessBuild`. Then measure startup time and memory before and after.
5. **Text and fonts.** Make sure imported source text renders, wraps and paginates correctly across the full character set.

### 5.3 Pewter → Cerulean

Covers:
- Route 22 (first rival, optional).
- Route 3 trainers.
- Mt. Moon:
  - three floors;
  - Rocket and fossil choice;
  - Moon Stone;
  - Super Nerd.
- Route 4.
- Cerulean City: the Center, the Mart, the bike shop (the voucher comes later), the robbed house and Misty.
- Nugget Bridge with its rival fight, Route 24 and Route 25.
- Bill's house: the cell-separator scene and the S.S. Ticket.
- The Pewter museum and the Old Amber as optional content.
- The Viridian old-man catching tutorial and the Pewter escort, which are still open from earlier.

### 5.4 Vermilion and the first HMs

- Routes 5 and 6, the Underground Path, the Day Care.
- Vermilion City, the Fan Club, and the S.S. Anne: all cabins, the rival, the Captain giving HM01.
- Cut as a field move, through the world-mutation API.
- Lt. Surge and the trash-can switch puzzle.
- Diglett's Cave, and the Route 2 aide giving HM05 Flash.
- Route 11.

### 5.5 Midgame Kanto

- Routes 9 and 10, Rock Tunnel (dark without Flash), and Lavender.
- Celadon:
  - the Department Store;
  - the Game Corner and its coins;
  - the Rocket Hideout (spinners, Lift Key, elevator, Giovanni);
  - Erika.
- Pokémon Tower: the Silph Scope ghost, Mr. Fuji, the Poké Flute.
- Snorlax on Routes 12 and 16.
- Cycling Road, the Bicycle, the rods and fishing.
- Saffron: the guard drinks, Silph Co. (card keys, warp pads, the rival, Giovanni, the Lapras gift), Sabrina and the Dojo.
- Fuchsia: the Safari Zone (its own battle mode, steps and balls), Koga, HM03 Surf, HM04 Strength.
- Fly and its destination history.

### 5.6 Late game

- Surf routes.
- Seafoam Islands: boulders and currents, Articuno.
- Cinnabar: Mansion switches and the Secret Key, Blaine's quiz, fossil revival.
- The Power Plant and Zapdos.
- Giovanni in the Viridian Gym.
- Route 22 rival 2 and Route 23 badge checks.
- Victory Road: boulder switches, Moltres.
- The Elite Four in sequence, the Champion (starter-dependent party), the Hall of Fame, credits, and a playable return.

### 5.7 Postgame and release

- **Postgame:** Cerulean Cave, Mewtwo, the remaining legendaries, and League rematch records.
- **Policies** that need the user's input before this point: version exclusives, the in-game NPC trades (keep the 9 that are used), trade evolutions, event-only Mew.
- **Audio:**
  - a reproducible pipeline from the pokered music and SFX sources to Playdate synth or samples;
  - music per map and per battle;
  - cries, the low-HP alarm and the flute.

  Start the pipeline research early, during §5.3, as a parallel worker task, because it touches every map.
- **Screens:** naming for the player, the rival and Pokémon nicknames; and options (text speed, battle animation, battle style).
- **Balance pass:** Gen V learnsets and stats against the Red/Blue trainer levels. Document deliberate tuning.
- **Long session and memory:** run the whole campaign in one sitting, and do repeated transitions.
- **Device:** run on a physical Playdate via `make deploy`. Record whether it was actually done. Never claim device validation that did not happen.
- **Deliverables:** a clean-checkout build, a `.pdx`, developer docs, the coverage matrix, and a list of known limitations.

---

## 6. Definition of done

- A fresh player can go from New Game to the credits and into the original postgame with no debug shortcuts and no softlocks, using any starter.
- Every map, trainer, item, script and puzzle in the [coverage matrix](../validation/coverage-current.md) is implemented or explicitly recorded as excluded with a reason.
- Every move, ability and item a player can meet behaves correctly. There are no silent no-ops.
- Save/Continue preserves all significant state and survives recoverable corruption.
- The automated journeys, rules tests, content validators and visual regressions all pass on the final commit.
- Protected art is exact. New art matches its style and has provenance.
- Performance is measured honestly, and device status is stated honestly.

Do not stop at a milestone, a tool or a demo. Brock is not the goal.

---

## 7. Machine and environment (DiveMac)

| Item | Value |
|---|---|
| Repo | `~/Developer/Pokemon-PlayDate` (origin `github.com/MCMike0399/Pokemon-PlayDate`) |
| SDK | Playdate SDK 3.1.2 at `~/Developer/PlaydateSDK`; `~/.Playdate/config` points at it |
| Env script | `source ~/Developer/Pokemon-PlayDate-env/env.sh`. It sets `PLAYDATE_SDK_PATH`, `POKERED_REFERENCE_DIR`, `KANTO_REFERENCE`, `PARCEL_BUNDLE_SOURCE` and `POKEMON_PROJECT`, and puts the venv and SDK `bin` on `PATH` |
| Python | venv with Pillow 12.0.0 at `~/Developer/Pokemon-PlayDate-env/venv` (Python 3.14) |
| References | pokered checkout pinned at `af519899…` in `~/Developer/Pokemon-PlayDate-env/pokered`; the B2W2 CSV cache is in `tools/verify_moves/cache` (gitignored, verified) |
| Durable evidence | `~/Developer/Pokemon-PlayDate-env/evidence/<run>`. Pass it as `--output` for anything that must outlive a reboot |
| Locks | `/private/tmp/pokemon-playdate-simulator-<uid>.lock` and `-suite-<uid>.lock`, shared by every run on this machine |
| Simulator | Launched by the runner as a GUI process in the logged-in desktop session. On 2026-10-26, with the lid closed, the screen locked and the window not visible, the Simulator sat near 0% CPU and every smoke run failed with "ready handshake timed out". Once the user unlocked DiveMac and the window was visible, `make harness-smoke` passed (`evidence/setup-smoke-20261026-e`). The fix was to disable App Nap with `defaults write date.play.simulator NSAppSleepDisabled -bool YES`. With that set, the smoke passed while DiveMac was locked and the display asleep (`evidence/setup-smoke-20261026-locked`), so unattended runs work. Run the smoke first in every session anyway. If it times out, check `~/.local/bin/lidwatch --status`, then ask the user to unlock DiveMac over Screen Sharing |

After a refactor that changes staging, refresh the compile-only bundle with
`python tools/harness/run.py --build-only --output <new dir> snapshot`, then point
`PARCEL_BUNDLE_SOURCE` at the new directory.

Required reading, in order:

1. CLAUDE.md
2. this file
3. progress.md
4. [harness.md](../validation/harness.md)
5. [host-tests.md](../validation/host-tests.md)
6. [journeys.md](../validation/journeys.md)
7. [visual-catalog.md](../validation/visual-catalog.md)
8. [coverage-current.md](../validation/coverage-current.md)
9. [kanto-content-inventory.md](../research/kanto-content-inventory.md)

Read other `docs/validation/*.md` files only when you touch their area.
