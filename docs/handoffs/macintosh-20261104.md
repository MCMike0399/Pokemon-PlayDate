# Macintosh takeover prompt — 2026-11-04

Use this document as the starting prompt for the agent on **Macintosh**. It is a
continuation of the same project, not a new audit or campaign. The user explicitly
requested pushing accepted main and handing the work to Macintosh. Do not launch
a duplicate DiveMac runtime. Read the private companion inventory before changing
or reconstructing any in-flight branch.

## 0. Final reviewed readiness and first action

An independent advisor challenged baseline `e29f4d77` and found two operational
gaps: incomplete Macintosh dependencies, and an old execution template that
resumed C record15 rather than the latest record16. Both are closed by the
on-Macintosh recovery drill described here. The advisor also requested explicit
fresh-session persistence. The advisor did not independently approve these later
fixes; Root verified them with the unchanged validators on Macintosh.

**Start a fresh Macintosh goal; app state is not transferred.** The outgoing
thread's goal, task IDs, delegates, wakeups, old PID records and historical
"needs /goal resume" memory are not local active work on Macintosh. Establish
your own continuation state for the same unfinished project; do not resurrect
the old DiveMac thread or assume the attempted Saffron delegate is running.
Start the new Macintosh agent with this exact instruction:

```text
/goal Continue the same Pokemon Blue for Playdate project through credits and
postgame. Read ~/Developer/Pokemon-PlayDate-handoff-20261104/PROMPT.md completely,
then take ownership using its verified branch/seed recovery and latest reviewer
order. Preserve all acceptance, safety and push gates. Continue the actual earned
C chain; do not restart a campaign or duplicate a DiveMac runtime. Commit accepted
work locally. Future pushes require my explicit request. Do not stop at a tool,
checkpoint or handoff.
```

Verified Macintosh setup (created without changing its existing checkout):

- `~/Developer/Pokemon-PlayDate-env/env.sh`, Python3.14.7 venv at
  `~/Developer/Pokemon-PlayDate-env/venv`, Pillow12.0.0.
- SDK compiler reports3.1.2 at `~/Developer/PlaydateSDK/bin/pdc`.
- Pinned pokered checkout at `~/Developer/Pokemon-PlayDate-env/pokered`, HEAD
  `af519899719f0754965776faac0e836a3b906e6d`, recovered from `pokered.bundle`.
- All17 Showdown oracle files at
  `~/Developer/Pokemon-PlayDate-env/preparation/common-abilities-oracle`.
  The existing loader verifies each against
  `tools/references/contact-abilities-sources.json`, revision9b136a8c.
- The11 exact B2W2 cached CSVs are supplied in `reference-caches/`, indexed by
  SHA256 in `reference-caches.json`. They are installed into the isolated recovery
  source under `tools/verify_moves/cache/b2w2/2bf639e5572812a67d2b94903fdcb9d095f5aeb2`.
  Copy them with hash/no-overwrite checks into a newly selected tool-managed
  worktree when missing there. No fresh oracle fetch or mutable upstream master
  is necessary.
- **188 exact evidence dependency files (4,790,358 bytes)** are hydrated at their
  original paths under `~/Developer/Pokemon-PlayDate-env/evidence`. These include
  the five earlier C ancestry markers and all producer records/receipts/slots read
  by the strict importer for all three starters. Their exhaustive path/hash list
  is `seed-closure.json` in the reviewed packet. Frozen proof bytes and failed
  original outcomes were preserved; no path/digest was rewritten.

Install the exact CSV cache into a newly selected worktree with this bounded
recipe (set `CODE_WORKTREE` to the actual tool-created path, not the example
recovery export). Existing different bytes refuse rather than overwrite:

```sh
export CODE_WORKTREE=/absolute/path/to/your/tool-created/worktree
"$HOME/Developer/Pokemon-PlayDate-env/venv/bin/python3" - <<'PY'
from pathlib import Path
import hashlib, json, os, shutil
packet = Path.home() / 'Developer/Pokemon-PlayDate-handoff-20261104/reviewed-readiness'
target = Path(os.environ['CODE_WORKTREE']).resolve(strict=True)
for row in json.loads((packet / 'reference-caches.json').read_text()):
    src = packet / row['packet_path']
    assert hashlib.sha256(src.read_bytes()).hexdigest() == row['sha256']
    dst = target / row['repository_relative']
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists():
        assert not dst.is_symlink()
        assert hashlib.sha256(dst.read_bytes()).hexdigest() == row['sha256']
    else:
        shutil.copy2(src, dst)
print('11 pinned CSV inputs ready')
PY
```

The on-Macintosh drill is at
`~/Developer/Pokemon-PlayDate-recovery-drill-20261104/`. Its `refs.git` recovered
the exact main/C/selected-slot/Telekinesis refs from the delivered bundle;
`candidate-source/` is an exported C1464 tree for read-only host validation,
**not a live game worktree**. Do not edit it as your implementation branch.
Receipts: `setup.json`, `strict-seed-verification.json`, `oracle-verification.json`.
All three strict seed imports pass. Squirtle has exactly the record16 slot hashes
and completed `saffron-guard-entry`; the others use canonical accepted B saves.
No Simulator, device, fixture, flag edit or campaign acceptance was involved.

The final packet includes `reviewed-readiness/` with these receipts, the exact
188-file closure, pinned reference bundles/caches and source-to-destination
inventories. The earlier sibling
`~/Developer/Pokemon-PlayDate-review-fixes-20261104/` is the preparation source.
The original packet verification is historical baseline proof; use the final
packet's current `SHA256SUMS`, `manifest.json` and final receiver verification
receipt `~/Developer/Pokemon-PlayDate-handoff-20261104-final-verification.json`
for the amended delivery. The baseline folder is preserved separately; do not
use its old prompt for the next agent.

**Use the new scenario**
`docs/handoffs/resume-55c-squirtle-saffron16-20261104.json` from updated main.
The final packet also supplies it under `scenarios/`. It binds the latest marker
`ac21db92...`; do not rerun the old `run-earned-c-...-16.py` template, whose input
was record15. Adapt its existing guard wrapper into a NEW private runner, select
this scenario, the actual tool-managed C checkout and a NEW output path. Leave
all resource limits/helper pin checks intact. Apply the source visibility fix
and earn fresh qualification before starting that runtime.

To repeat only the tested host import check on Macintosh (no game launch):

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
export HANDOFF="$HOME/Developer/Pokemon-PlayDate-handoff-20261104"
export RECOVERY="$HOME/Developer/Pokemon-PlayDate-recovery-drill-20261104"
GIT_DIR="$RECOVERY/refs.git" "$POKEMON_ENV/venv/bin/python3" - <<'PY'
from pathlib import Path
import json, os, sys, tempfile
source = Path(os.environ['RECOVERY']) / 'candidate-source'
sys.path.insert(0, str(source))
from tools.harness.restarting import import_chain_save
checks = Path(os.environ['POKEMON_ENV']) / 'handoffs'
checks.mkdir(exist_ok=True)
for starter in ('squirtle', 'bulbasaur', 'charmander'):
    scenario = json.loads((Path(os.environ['HANDOFF']) / 'scenarios' /
                           ('restart-55c-' + starter + '.json')).read_text())
    root = Path(tempfile.mkdtemp(prefix='handoff-seed-' + starter + '-',
                                dir=checks))
    data, output = root / 'data', root / 'output'
    data.mkdir()
    output.mkdir()
    record = import_chain_save(scenario, source, data, output)
    if starter == 'squirtle':
        assert record['resume']['state']['completed_steps'] == ['saffron-guard-entry']
    print(starter, 'strict earned-seed import PASS')
PY
```

Expected: three PASS lines. This uses the baseline C export for dependency
verification, not the next runtime build. `GIT_DIR` is scoped to that one command
so historical frozen Git objects resolve; do not export it for normal worktree
operations. Actual code work uses a tool-managed checkout from
`refs/remotes/divemac-handoff/t3/checkpoint-c-host-preparation`.

Runtime-specific checks remain honest external gates: the read-only Macintosh
preflight found its settings file lacks `MallocPoolSize=16645684`, so it correctly
REFUSES local Simulator admission until Playdate > Malloc Pool >16MB is selected.
No preferences were edited to manufacture a pass. AX/desktop readiness and
native startup also remain unqualified on this host. Use the existing preflight
and short safety qualification before a local Simulator attempt; no new
permissions or weaker settings were assumed.
Physical device work stays on DiveMac through its existing owner/fences and
current serial detection. These pending game-runtime gates do not block source,
host or branch continuation on the verified Macintosh setup.

## 1. Your assignment and authority

Finish the complete native Pokémon Blue experience through credits and postgame,
as defined in `docs/plans/full-game-goal.md`. Preserve Red/Blue Kanto world, story,
characters and art, with Gen V/B2W2 battle rules, original 151, abilities, held
items, natures, Dark/Steel, and the explicitly approved quality-of-life additions.
This is not finished at a checkpoint, tool, benchmark or showcase.

Read, in order:

1. Your host's canonical Claude instructions/memory and this repository's
   `CLAUDE.md`. Load nested rules for files you touch. The memory reader is
   `python3 ~/.codex/claude_memory.py --cwd "$PWD" --refresh` when no current hook
   has loaded them; after compaction follow the AGENTS reload rules.
2. `docs/plans/full-game-goal.md`, then `docs/validation/progress.md`.
3. `docs/validation/harness.md`, `host-tests.md`, `journeys.md`,
   `visual-catalog.md`, `coverage-current.md`, and the area-specific contracts.
4. This entire handover and the private companion's `worktrees.json`,
   `refs.txt`, `manifest.json`, and project-memory snapshot. Snapshots are dated
   context; verify current processes and files before acting.

Accepted work is committed locally to main. The November 4 request authorizes
this handoff push; **future pushes still require an explicit request**. Do not
merge unaccepted C or pending optimization branches merely to make them portable.
Root owns integration, independent acceptance, Simulator and device execution.
User-requested workers are GPT-6.1 Sol at medium effort, in tool-managed isolated
worktrees. Do not silently substitute a provider/model or raise their effort.
Technical worker questions go to Root; avoid repeated human approval questions.

Keep the original Game Boy tones, chained earned saves and readable ledger.
New Lua uses readable expanded control flow, one statement per line, and local
immutable `<const>` SDK aliases. Domain owners retain durable state; no parallel
session, inventory, RNG, battle, movement or save authority. Generated data must
come from the generator and pinned inputs. Gen V mechanics use the cached
Showdown inheritance chain; world/story/art use pinned Blue sources.

## 2. Authoritative checkout and portability

Repository: `https://github.com/MCMike0399/Pokemon-PlayDate.git`.
DiveMac checkout: `/Users/burbujamc/Developer/Pokemon-PlayDate`.
Accepted game/validation tip before this documentation-only handoff:
`75eca5d982d6be872c017aa1ec9aaa84148260dc`.
`96b53554` adds only the two already-reviewed cold-archive allowlist entries and
was pushed. The handover document's subsequent commit is also on origin/main;
use `git rev-parse origin/main`, not a guessed final hash embedded in this file.

At audit, origin was 277 commits behind accepted local main. No upstream-only
commits existed after fetching. The outgoing accepted tip was fast-forward
pushed. Macintosh's checkout was reachable over `ssh Macintosh` and clean before
handoff; it was deliberately not reset, pulled, or switched by the outgoing agent.

Private companion on DiveMac:
`/Users/burbujamc/Developer/Pokemon-PlayDate-env/handoffs/macintosh-20261104/`.
It includes an all-ref Git bundle, exact ref/worktree inventory, binary patches
and untracked-file snapshots for dirty worktrees, project memory snapshots,
top-level private execution scripts, environment setup, and handoff hashes.
This protects unmerged work that **is not on origin/main**. Never infer that an
old branch is adopted because it appears in the bundle. Do not apply all patches.
The transfer receipt records whether a verified copy reached Macintosh.

Safe bootstrap on Macintosh, after checking its own working tree:

```sh
cd ~/Developer/Pokemon-PlayDate
git status --short --branch
git fetch origin
# Only if clean and fast-forwardable; preserve any newer local changes otherwise.
git merge --ff-only origin/main
git bundle verify ~/Developer/Pokemon-PlayDate-handoff-20261104/repository.bundle
# Namespaced imports preserve local branch names and avoid activating candidates.
git fetch ~/Developer/Pokemon-PlayDate-handoff-20261104/repository.bundle \
  'refs/heads/*:refs/remotes/divemac-handoff/*'
```

If the private folder is not present, retrieve it from DiveMac using the exact
path above and validate `SHA256SUMS`. Do not copy DiveMac's `.git/worktrees` or T3
SQLite/WAL into Macintosh. Recreate only the selected branch checkout through
the active tool's worktree mechanism. The Git bundle contains committed refs;
dirty snapshots are recovery material to inspect individually.

The source and proof contain absolute `/Users/burbujamc/...` paths. Evidence is
outside Git. The same username/path layout helps, but **a path string is not a
hydrated dependency**. Frozen evidence manifests, source digests, producer IDs,
canonical slots and ancestry hashes must not be rewritten to make validation
pass. Restore exact referenced trees or run remote validation on DiveMac. Do not
copy old compiled helper hashes onto newly compiled binaries.

Private execution scripts are preserved as **templates and provenance**, not
portable commands ready to run blindly. Many hardcode the old `B` worktree,
`P` checkout and output paths. Select the exact candidate, adapt those paths in a
NEW private script, use a NEW output directory and preserve the old script/hash.
Do not rerun a script whose output already exists or import a similarly named
older native group as qualification for a newer candidate.

## 3. What is accepted, and what is not

Main has **149/222 Simulator-route maps** through checkpoint **5.5b**. The label
is exactly: **Simulator-accepted and hardware-safe; device latency targets not
yet met**. Device-playable acceptance remains **0/222** under the full goal's
latency bar. The campaign, credits and postgame are incomplete.

B includes Tower/Fuji/Flute, both Snorlax routes, Bicycle/Cycling Road, rods and
fishing, Fuchsia/Koga, Safari, Surf and Strength. Original B code merged as
`af9a89380f9730767ff22b3ac5114cf32f216a75`. Its all-three-starter earned routes
and actual two-process restarts are retained. Later fixes have targeted proofs,
not a new complete campaign replay. Acceptance:
`docs/validation/midgame-b-acceptance-20261102.json`.

Subsequent adopted main improvements include:

- Source-qualified boot/first-use loading; Kanto installer about 1.17 s → 34 ms.
- Chunked FNV checksum, title store-read subphase 3,286 → 2,847 ms (13.36%).
  This did not establish a 10% whole-boot or whole-Save gain.
- Callback-preserving pose metadata, Route17 actor construction 2,470 → 1,744 ms.
- Game Corner/Hideout catalogue membership and terrain queries, including removal
  of retained field-travel catalogue copies. Heavy B maps now roughly 4.8–5.1 MiB
  post-GC, about 6.1 MiB sampled peak. This clears the prior B-memory prerequisite
  for C development, not C's own memory/latency acceptance.
- Hideout spinner private query, merge `1860b3c0`: ordinary B3 active p95 about
  148 → 39 ms. Three roughly two-second hitches remain.
- Save-inspection reuse `1ffd6fa7`: private SAVE-only proof, same owner/epoch/exact
  bytes; public/untrusted LOAD remains deep. Repeated Center Save 2,867 → 2,020 ms
  and Surf 3,529 → 2,426 ms. First Saves are 2.5/3.5% slower. Native23 pass; one
  combined review had no findings. Surf still misses the two-second target.
- Gen V Reflect, Chip Away, route-exposed Rest/Snore/Yawn/Foresight/Revenge fixes,
  and Substitute (`056fe922`, epoch19). Substitute has scoped native/component
  rendering and physical smoke evidence; this is not exhaustive move fidelity.
- Safari Surf boarding accounting, source Seel rendering, and expiry taking
  input before another field action. The later long expiry fixture hits the host
  profiler guard; no fresh pass is claimed for that fixture.

Latest full host suite at accepted game tip: **1,169/1,169 pass**, 208.137 s.
See `docs/validation/main-host-after-save-20261102.json`. Earlier red runs remain
retained; reconciliations changed projection/coverage metadata and preservation
pins, not assertions or proof levels. Coverage keeps all 1,512 rows, facets and
original proof hashes. Current packet handoff edits did not rerun the entire
SDK campaign; the archive wrapper's 23 focused host tests passed November 4.

Historical B player package and 86.161 s native 400×240 silent showcase exist
outside Git. Four explicit cuts cover walking, complete three-member Fisherman
victory, Snorlax wake/encounter/removal, and Koga dialogue/intro/first turn.
Koga is an excerpt, not a new complete-victory claim. The earned route receipts
prove the gym victory separately. The package predates later memory changes;
do not call it the exact current performance build. User cannot play-test now;
keep preparing/validating without waiting for feedback.

## 4. Earned saves and evidence that must survive

Canonical authority is `docs/validation/chain-saves.json`; B directories are
`$E/chain/5.5b/{bulbasaur,charmander,squirtle}` with `provenance.json` and the
original ancestry. `$E` below always means
`/Users/burbujamc/Developer/Pokemon-PlayDate-env/evidence` on DiveMac.

The six immutable B slot hashes:

| Starter | adventure.a.json SHA256 | adventure.b.json SHA256 |
| --- | --- | --- |
| Bulbasaur | daa9a81c7b1ca2dc6273acc0f409cd119d8235999796299d11c4b54cf3286c07 | ee2d97a44e69c176937869e3d10097e688aa8b6aa36658a29fafc8d2050e9298 |
| Charmander | 69e5b9c7472c4170fa3faeec3cfd8176a41169352e390e7ccabb4450999239a0 | f67c86b43a5c2a2e5f8a06342977e6b54838fc870651e4da68bc4cf6d26a8801 |
| Squirtle | a823d67ab2beaa4b6622c48cb46566d142c2409978e0cc48d4eb35ad820cf465 | 5e44ced5258012f2a76039e234674a4636d75cb9956dc9a9809834ad7c11abd3 |

Accepted B producers: Bulbasaur/Squirtle in
`m55b-earned-fourteenth-resumed-20261030-01`, Charmander in
`m55b-charmander-learning-retry-20261030-01`. Preserve their stopped-producer,
codec-equality and acceptance receipts. B11
`m55b-earned-eleventh-resumed-20261030-01` was restored to its original path and
is **required local C ancestry**; never automatically release it again.
Its archive ID is `playdate-0363a44b82e94ebd8587158976b765cb`, manifest
`0ee2669558980c4f14b9c853ef9f5eeab922522542fd9e6ba40f23638ec16f41`.

Do not restart C from New Game, grind again, generate a fixture, alter flags,
replace a failed verdict, or weaken ancestry to bypass a missing archive. Resume
the same actual saved record through the existing importer. Historical absolute
dependencies must be fetched before strict seed validation can succeed.

The private companion contains small chain snapshots and current run markers
when present. Raw acceptance roots, PDXs, recordings and full runtime archives
remain on DiveMac/Pi. Its `external-files.json` and `environment-inventory.json`
distinguish copied bootstrap files from paths still requiring hydration.

## 5. Isolated C171: exact frontier and immediate game bug

Branch: `t3/checkpoint-c-host-preparation`.
DiveMac worktree: `/Users/burbujamc/.t3/worktrees/Pokemon-PlayDate/t3-b137b7b5`.
Current clean tip: `1464d1a237d551e4e6909b66fea108eea0befb7a`.
Main remains B149. C171 is wired and SDK-qualified for development, **unaccepted**.
Read `tools/integration/checkpoint-c/README.md` on that branch; its current top
section supersedes the historical unapplied-hook claims lower down.

C adds Saffron, guard drinks, Silph/warp pads/elevator/Card Key/rival/Giovanni/
Lapras, Sabrina, Dojo, Fly, and Copycat. Shared metadata classifies two inert C
warps and 13 new scripted elevator IDs without changing B's 510 classifications.
All 171 raw map/cell payloads and the prior B map records are preserved except
documented source-qualified Route16 barrier/atlas-cell additions. Actual thin SDK
export produced Saffron's 30 transformed events and 45 trainers and preserved
Kanto/East/South values. Production qualification passed. Fresh owner changes
still require real SDK export and provenance refresh; rehashing historical proof
is not qualification. Host preflight reached 239 checks/zero blockers after wiring;
this is not native map or journey acceptance.

Latest genuine Squirtle C attempt:
`$E/checkpoint-c-earned-saffron-resumed-20261102-16/01-midgame--restart-55c-squirtle`.
Outcome is **failed**, `journey history Clear bound reached or owner failed`,
one generation, session `fb5296b77d6c49059d298bdd16cf080f`.
Old owned Simulator PID60610 is terminal/failed-exited, cleanup -9 confirmed in
the retained run. No SDK, journey, device or archive process was live at the
November 4 handoff process audit. Recheck before execution; never trust old PIDs.

It completed and genuinely saved `saffron-guard-entry`: bought the real drink,
committed `pokered:wStatusFlags1:BIT_GAVE_SAFFRON_GUARDS_DRINK`, entered Saffron,
healed at its nurse, and saved. Latest marker records Saffron City `(0,23)`;
healing checkpoint is Saffron City `(9,30,down)`. Do not re-buy water or re-heal
already-restored HP/PP/status. The C-only driver commits real transit Saves every
16 completed walking cells and preserves the existing earned transaction state.

Frozen marker: `processes/0001/partial-save.json`, SHA256
`ac21db92bb977364a573c6a8323aa9961af3aae1341b1fd849f77f57302e45e0`.
Its actual slot hashes are:

- a: `01783e5d359652f061d39d2ce9f1cddc8660aaa88f49b54e73c396f284f3b1dc`
- b: `abbeeadddcd2807965f40be0f77aac95e1611a9a6a63ae3a94ff87dbd7b42fb4`

**Confirmed gameplay blocker:** `Source/game/silphStory.lua:actorMetadata`
currently leaves BOTH Saffron objects14 and15 visible whenever Silph Giovanni
is undefeated. Object14 at `(18,22)` blocks the Silph door `(18,21)`; object15 is
the sleeping Rocket at `(19,22)`. Pinned Blue
`scripts/PokemonTower7F.asm:225–239` Fuji rescue hides
`TOGGLE_SAFFRON_CITY_E` (object14) and shows `_F` (object15). Initial state is
14 on/15 off; Silph completion hides both. The correct existing-flag conditions
are 14: `not FujiRescue and not SilphClear`, 15: `FujiRescue and not SilphClear`.
Verify all source transitions before implementation. Do not delete NPCs, change
their coordinates, art, collision, raw map, warp geometry, or fabricate a flag.
Keep custom resolver/deep fallback, candidate validation and old actor saves valid.

The ordinary driver bounced Saffron `(0,23)` ↔ Route7 `(19,15)` until the existing
64-Clear cap. `cerulean_journey.route_portal` can route out and back to the same
blocked map; after the GAME visibility correction, ensure such a planner failure
fails boundedly rather than adding another generic planner project.

A delegation titled "Fix source-backed Saffron Silph guard visibility" was
attempted immediately before a user interruption (historical activity32614),
but has **no returned task ID/result and no matching new branch in the audited
repository**. Do not assume a fix exists or an agent is running. Recover the
original thread's activity/result if the orchestrator advertises one before
starting duplicate work. Parent thread:
`t3-thread://v1/d24a9e60-3057-4d28-8db0-20ae045597d2`.

After the fix: host phase tests, native pre-/post-Fuji/post-Silph visibility,
fresh qualification, then one short actual C pilot from this frozen Squirtle
record before the three-starter sequence. Native floor/elevator/President,
reward/Copycat/Fly/Save-Continue, own C hardware/memory/visual evidence and all
latency gates remain required before C acceptance. Do not claim full C from a
partial guard-entry Save or an SDK export.

## 6. Guarded C history clearing: preserve the exact policy

User authorized the EXISTING guarded helper for ordinary C journeys, and later
approved **only** raising its soft trigger from512 to **736 MiB**. This does not
authorize a new census, Clear tooling rewrite, lower guards or altered counters.
Unchanged: Simulator pool16MiB, host hard1GiB, maximum64 Clears/131 helper calls,
all command/progress/overall deadlines, same owner/kernel/PDX/window identities,
and failure poisoning without replay or acknowledgement.

Current private first-title early barrier is candidate `27907eaf`, integrated
on C as `34ed96bc`. It pauses before content/save work with truthful pre-ready
metadata and exact generation acknowledgement; Source/main.lua is unchanged.
The actual first early Clear measured roughly126→163→121MiB. Later failures and
the64-Clear bound remain failed; this is not a whole-C qualification.

Retained helper:
`$E/journey-startup-clear-helper-20261102-01/malloc-history-clear`, SHA256
`005459edf255b519db1cb6f7cd7e0ad5379062d35652b6ed8afdc894fa37f27c`.
It is host/SDK/executable-specific. Inspect the current C source and run metadata,
recompile on Macintosh when necessary, pin the actual new binary and qualify
one bounded Clear. Do not reuse a stale pin after changing compiler/source.

Important prior fixes: history-enabled POSIX owner.lock must be excluded from
generation archival, or opening/closing another descriptor in the owning process
releases the process's lock. Keep the existing descriptor ownership chain.
Native window enumeration must fail closed, never convert unavailable results
to an empty list. Closing the post-Clear window did not reclaim headroom and is
REJECTED/reverted. Profiler history is host overhead, not device live heap.
Timers can absorb elapsed wall time on resumption; a pause is not a universal
elapsed-time freeze. Keep helper overhead outside gameplay pacing claims.

No Clear History work for the stopped exhaustive census or capture-only segments.
For a new limit refusal, report it and preserve the failed run rather than
inventing helper epochs, repeated retries or new proof machinery.

## 7. Latest reviewer order: production GC, then store inspection

Reviewer steer #8 (2026-11-02 21:20Z) supersedes older optimization proposals.
It was acknowledged but **no execution followed** before this handoff; the
November3–4 scheduled reviews observed an idle thread, not new game progress.

1. **Verify production GC on hardware over at least30 doors**, with forced
   diagnostic full collections OFF, production soft GC/guards intact. Log every
   `memory.soft` clock, before/after heap, duration and whether the player is
   walking; correlate Hideout B3's three ~2s hitches. In
   `gamecorner-membership-hardware-20261102-01`, heap rose5.17→8.01MiB over12doors.
   With diagnostic door.live collects in `atlas-baseline-hardware-20261102-01`,
   each freed430–600KiB in about650ms. The reviewer's causal explanation is a
   hypothesis to verify: `collectgarbage("generational",20,100)` promotes door
   garbage until a major near9.6MiB, beyond the9MiB hard guard, so the8MiB soft
   full collection causes the actual freeze.
2. Paired candidate(a): schedule the soft full collect in the existing door black
   hold above about7MiB, hiding the pause from walking. Guards unchanged.
   If necessary next try incremental+SDK idle GC, or lower generational majormul.
   Score maximum **non-transition walking hitch** (goal no >300ms), door wall time
   and peak. Do not accept a local wrapper span as whole-phase improvement.
3. Add private whole-phase store-inspection marks: read, checksum, JSON decode,
   schema/domain deep validators, and owner construction. Current inspection
   takes2.42–2.64s for21.5–24.3KB. Find repeated/superlinear work and remove it
   while retaining complete untrusted-load validation. Use the same marks for
   the remaining Surf-Save gap; do not infer that map/mode caused an ordinal cost.
4. C pilot/three-starter journeys continue alongside independent source/host work
   under the sole runtime owner. Hardware/Simulator ownership still serialize.

Performance experiments: after exact16MiB safety admission, measure on hardware
first, keep only a >=10% improvement in its explicitly declared phase, one
combined review for performance-only work. Drop ineffective candidates after
one measurement. No extra scaffolding around rejected work. C acceptance is
gated by latency; C development is not blocked on another B memory campaign.

## 8. Pending candidate branches — not adopted

### Selected-slot load/title and first-Save rotation

Branch `t3/selected-slot-load-validation`, worktree `t3-ba269cbf`.
Tip `1952a3e955ef7a697a24c8410da039587c6c3f99` atop Root `6571794a`.
Original `83e0ff41` changes only private cold Continue, so makes no title claim;
`01d67f7f` wires private production/profile title loading; Root `6571794a` fixes
a test-only constructor expectation; `1952a3e` adds private SAVE-only rotation
proof to avoid extra validators on the next Save.

Selected payload is still fully read/checksummed/parsed/primitive/domain/mutation
validated and constructed against fresh dependencies on every load. Public and
default harness paths stay deep; exceptional/recovery paths retain full fallback.
Title's older backup is honestly unverified; a corrupt older slot may omit the
Repair choice until needed. Do not claim that fidelity tradeoff is equivalent to
the original deep title inspection or that it is adopted without measurement.
SAVE-only proof never promotes older bytes or public LOAD proof. Host counts:
public load→firstSave2+0 validators; selected1+0. Fifteen shared host cases and
17 recovery cases plus compile pass. The earlier eight Title native cases passed
on the earlier wiring; the final1952 version needs UPDATED native reruns.

Next:16Store+8Title cases, faults/retained-reference/custom mutable callback and
epoch revocation coverage,16MiB safety, paired immediate/1.5s-dwell boot→walk and
Save measurements, >=10% gate, one review. Scripts prepared but UNEXECUTED:
`$E/run-selected-rotation-native-group{1,2,3}-20261102-01.py` (5/5/6) and
`run-selected-rotation-title-group{1,2,3}-20261102-01.py` (3/3/2).
Read that branch's `tools/integration/selected-slot-load/{README.md,
TITLE-FOLLOWUP.md,FIRST-SAVE-FOLLOWUP.md}`. Do not accidentally run the older
similarly named selected-title scripts as final-candidate qualification.

### Telekinesis for C's three exposed trainer members

Branch `t3/gen5-telekinesis`, worktree `t3-935d1a82`, candidate
`937c13825e426b9d08ba8427911186ce6f99265a`, base accepted main75eca5d9.
Verified effective C exposures: Sabrina Kadabra38/Alakazam43 and gym Kadabra34.
Existing condition/residual/accuracy/airborne/cleanup owners; duration3 including
application-turn residual/order19; non-OHKO accuracy bypass, ordinary gates,
Iron Ball/grounding precedence, species/repeat failure, PP/RNG/lifetime checks.
Epoch20 changes only Telekinesis; schema4, original424 inverse, historical edges,
epoch19 Substitute/Reflect/Chip Away and all other rows remain exact.
Gravity/SmackDown/Ingrain/MagnetRise remain honestly unsupported.

Host61+coverage8 and production/harness compile pass; **eight native cases are
unexecuted**. Independent Standards52559708 and Spec3b7efb68 reviews both had
zero findings and verified the local Showdown pins. No adoption/C acceptance.
Prepared scripts: `$E/run-telekinesis-native-group{1,2}-20261102-01.py` (4+4).
Run native+shared-owner regressions before adoption and C sync. Handoff:
`docs/validation/telekinesis-host-preparation-20261102.md` on the candidate.

### Other branches and rejected experiments

All99 audited worktrees and every ref are in the private inventory/bundle.
Dirty snapshots include old soak, route, learnset, source-event, FieldGear-art and
field-move fixture work. They are NOT current candidates merely because dirty.
Inspect their historical handoffs and scope before selecting anything.

Do NOT revive without a new reason:

- Exhaustive Simulator door census: stopped, ~2,800/4,890 trials,864 measured/
  1,936 gaps; raw data retained/partly archived. No continuations or AX epochs.
- Atlas enablement: GameCorner3.889→3.933s; B3 1.886→1.907s. Native pixels passed,
  no phase meets10%; rejected, no adoption.
- Compact terrain rows: Fuchsia4.451→4.507s, unchanged memory; rejected.
- Production door tier: primary gains3.1% Fuchsia/8.4% Route17/7.8% GameCorner,
  Save11.3% slower; rejected despite native correctness passes.
- Two-stage title: moved cost without reducing immediate-press app→walk; rejected.
- Decode-only door prefetch6.6%, eager generated registration, compiled terrain,
  sparse view, old pose shortcut, inspect-cache shortcuts and old unqualified
  Continue/title validation shortcuts: no automatic resurrection.
- Cooperative deferred import split: SDK3.1.2 errors `import() called outside of
  pdz loading`; compile alone cannot validate moving imports into update.
- Post-Clear inspect-close did not reclaim memory; reverted.

Earlier static ranking/worst-8 door work remains incomplete; use existing measured
data and cheap host proxies if still needed, never restart the exhaustive census.
The packing hypothesis was disproved by file-open counts; do not build a new
content container based on it. Shipped-equivalent sampled doors remained ~2.96s,
so forced diagnostic GC did not explain that whole-door gap.

## 9. Measured budgets and honest interpretation

Boot means **app start→title accepts A**, not first artwork. Also report immediate
A/Continue→walking and Continue after1.5s menu dwell for any title optimization.
Diagnostic full-GC intervals must be explicit; never silently subtract them.
Give a shipped-equivalent column when measured. Native memory and transient peaks
are not `collectgarbage("count")`; harness heaps are not device heaps.

Matched three-B-save hardware observations (same code/SDK/compiler):

| Save | Selected envelope bytes | title.prepare ms | store ms | decode ms | field ms | map ms | input-ready boot ms | Continue ms | max boot slice ms | diagnostic title GC ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Squirtle | 21533 | 4589 | 2419 | 1208 | 358 | 574 | 13325 | 3293 | 1441.367 | 876 |
| Bulbasaur | 22650 | 4687 | 2482 | 1242 | 340 | 595 | 13548 | 3360 | 1470 | 899 |
| Charmander | 24316 | 4981 | 2635 | 1403 | 340 | 568 | 13774 | 3463 | 1934 | 968 |

See `docs/validation/boot-three-earned-saves-20261102.json`. Composition of party,
PC and flags varies together; lazy-PC causality is not established. These have
default diagnostic GC; matched shipped-equivalent three-save timing is unmeasured.
Current reference targets: boot<=10s, boot slice<=1s, Continue<=4s, Save<=2s,
worst door/map<=1.5s, battle<=1s, cave walking p95<=50ms / walking>=25fps.
Do not silently replace the goal's stricter legacy subtargets; record the current
reviewer-scored row and exact phase. No checkpoint may regress any phase>10%.

Historical physical long traversal:110doors/30maps/20battles/87.44minutes,
136 post-GC samples,max5.151MiB/rawpeak6.341MiB,no new logs. Because it used
diagnostic GC, it does NOT answer the new shipped-production-GC hitch question.
Idle60+60-minute soak was flat in its retained scope. Point native image probe
held eight256KiB images then released; diagnostic allocation+collections1.243s.
Audio remains held pending current headroom/listening/admission; do not activate
an old lazy-audio packet as a side effect of synchronizing refs.

## 10. Machines, runtime, device and safety

DiveMac has SDK3.1.2 at `~/Developer/PlaydateSDK`; pokered pinned
`af519899719f0754965776faac0e836a3b906e6d` in the environment tree. Cached Showdown
oracle revision is `9b136a8c8cdb860a8ab96fa063f906604e352547`; verify per-file pins
in candidate handoffs. Schema4, producer epoch19 on main; Telekinesis epoch20 is
unadopted. Gen V numbers are SDK JSON-sensitive: read memory about integer vs
float subtypes/precision; never relax typed equality to accept a mismatch.

Source `~/Developer/Pokemon-PlayDate-env/env.sh` for SDK/reference/venv paths.
Macintosh's own venv was created and verified in section0; if reconstructing it,
create a new local venv rather than copying one across hosts. `PARCEL_BUNDLE_SOURCE`
points at an actual fresh compile-only bundle after staging/import changes. Do
not use a stale bundle and call it current. All timed packet helpers must use one
resolved Python interpreter; the newly recorded cross-project mixed3.14/3.9 clock
pinning issue can make monotonic admission comparisons invalid. Read that host's
memory before reusing timing helpers.

Hard policy: **30GiB disk reserve/31GiB new-runtime admission**, Simulator16MiB
persisted `MallocPoolSize=16645684`, host1GiB hard stop, Lua6MiB post-GC live /
8MiB soft collection /9MiB hard. No guard relaxation. A measurement-admitted
Simulator safety packet can still fail the strict live budget; say so.
No arbitrary foreign Simulator termination, no parallel SDK owner, no duplicate
campaign, no fake bundle-prefix admission, no reusing another process's proof.

Physical Playdate is attached to **DiveMac**, historically
`/dev/cu.usbmodemPDU4_Y0096221`. Re-detect it; do not assume it is on Macintosh.
Use the existing `device_cycle.py`/serial owner, reservation/copy/restore controls,
no raw make-deploy bypass for acceptance. All previous USB readers/cycles closed;
Calibration keeper inventory was verified and run acknowledged, but its screen
was not directly observed on every return. A new crash/missing serial stops
attempts and may require one user A press; never launch repeated USB retries.
Remote shell source work is fine; GUI Simulator work needs its actual signed-in
desktop, visible/awake host and verified ownership.

DiveMac runtime locks are global on that host; Macintosh's local locks do NOT
protect a simultaneous DiveMac session. Choose one runtime host and state it.
Ordered project storage/producer fences: maintenance→suite→simulator→device→
per-artifact. History adds its exact private process lock. Respect active owners.
Do not edit a pinned/frozen checkout while its owner is running.

Native GUI: OpenClaw.app2026.9.8 was installed on DiveMac, existing gateway retained.
Working paired DiveMac-node `screen.snapshot` observation was verified in the
prior session; gateway `computer.status` alone can falsely imply no node path.
Permissions and pairing are host-specific and must be rechecked. User authorizes
one bounded local OpenClaw action if genuinely required; verify outcome yourself,
do not hand it Source edits/device ownership/pushes. Do not claim GUI observation
from permission settings. No unsupported CUA/TCC workaround or unrelated app kill.
Past T3 Accessibility responsible-process identities included runtime0.1.0 parent
and0.1.3; historical user grants do not prove current trust on either Mac.

## 11. Storage status and guardrails

Both user-requested superseded failed Brock directories are now fully copied,
verified, restore-rehearsed and locally released. November4 live receipts confirm:

| Source suffix | Logical bytes | Archive ID | Manifest SHA256 |
| --- | ---: | --- | --- |
| brock-charmander-policy60-20261026-01 | 4431112637 | playdate-4a57f5cdf97e4e4a8d3d04d6f149915c | 01eca1605b23c9661db3a1bb2a119dd64be704e3a848dd7ef019f6dffcc14a30 |
| brock-charmander-retry-20261026-01 | 4651841150 | playdate-fa4a4a4099664d23809068f82d257809 | 310ee5d2f8729063cdfb48c3ec213a45101c5f6232e898960305fb5439a139ca |

Both status=archived, restore_rehearsed=true, local_present=false. Earlier notes
about SADX transport busy/Pi headroom are historical; do not repeat the transfer.
Actual free at this handoff audit was about95GiB. The8.46GiB logical total is not
an isolated physical reclaimed-space measurement; other projects also freed disk.
Restore exact paths through `tools/harness/pi_archive.py restore NAME --id ID
--execute` on DiveMac before historical use. Never feed an ARCHIVED stub to a
proof reader or overwrite a present directory.

Shared helper pin remains
`29e0e8015e91cfbbbc4fd6bac5a820f00b1278ce66caa8f1a53a279f420046d2`, at
`~/Developer/burbuja-cluster/storage/pi_artifacts.py`; HDD archive root
`/srv/seafile/archive/divemac-artifacts`, expected UUID
`d7fdcd6c-c069-4dbd-945d-1bf2fe4cc1f5`.
Existing DiveMac1800s LaunchAgent `local.pokemon-playdate.storage-maintenance`
runs `/bin/sh ~/Developer/Pokemon-PlayDate-env/maintain-storage.sh`; no new service.
The wrapper preserves all five fences and inherited FD chain. Busy/offline/Pi
pressure defers, never skips proof or deletes. Partial rehearsal/restore temps
require owner review; never accumulate automatic partial copies. Do not change
the shared helper or its pin. Preserve metadata constraints (bytes/modes/links,
not application resource forks/ACLs) and the installed logicalbytes+5GiB rehearsal
guard. Normal queue70→100GiB is distinct from local maintenance30→50/admission31.

Storage is background, exception-only. No new broad inventory, recursive age
deletion, compression project, services/network/provider changes, or cold-proof
release unless a concrete capacity block requires it. A cross-project cleanup
pause for Hub/Pomnibot still applies outside the explicit completed Playdate task.
Do not migrate T3 SQLite/WAL, live Git/worktrees/SDK/models or current chain inputs.
Old archived worktree registrations can be deliberately locked; don't prune them.
New passing evidence keeps compact summary+hashes at source; full raw retention
is for failures and acceptance, preserving immutable positive proof/ancestry.

## 12. Immediate takeover sequence and reporting

1. Verify the transferred packet hashes and fetch main/selected namespaced refs.
   Inspect your own dirty state; do not overwrite it. Hydrate the exact C seed
   and all ancestry dependencies or keep validation on DiveMac. Do not replay B.
2. Recheck live runtime/USB/transport locks once. Establish one Root and one SDK
   owner. No actual runtime is being handed live from this outgoing session.
3. Foreground hardware work follows steer8: production-GC30doors with soft-event
   logging and B3 correlation; then paired black-hold candidate if supported.
4. Independent host work fixes the source-confirmed Saffron actor visibility,
   with fresh SDK qualification before the next C pilot. Recover any returned
   historical task record before duplicating an attempted delegation.
5. Run the short C pilot from the frozen Squirtle record; then the three starters.
   On a hard limit, retain failure/report; no new history machinery.
6. Add store inspection marks, evaluate selected-slot candidate on actual
   immediate-press/Save metrics, and qualify Telekinesis's native cases before
   adopting it for the exposed C battles. Keep current acceptance honest.
7. C only merges/accepts after its earned route/restart/visual/hardware/memory and
   latency gates. Then proceed through5.6 and5.7 to credits/postgame. Future
   acquisition policies (version exclusives/trades/trade evolutions/eventMew)
   still require the specific recorded user decision; do not invent one.

No polling filler or repeated stale-background FAIL investigations. Those queued
October29–30 notices were already handled. Post terminal results/new defects/
device numbers, and end a turn with a short ledger update about every two hours.
Do not hold another nine-hour turn. No more proof around ineffective candidates.
Read older ledger sections as dated history; current accepted refs and exact
retained reports take precedence. The outgoing agent hands ownership to
Macintosh and will not start another campaign after delivering this packet.
