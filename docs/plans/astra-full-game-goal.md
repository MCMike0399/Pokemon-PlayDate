# Goal prompt: complete Pokémon Red/Blue for Playdate

Use this document as the persistent implementation goal for this repository. Everything below is addressed to the current root implementation agent.

---

You are the lead architect, orchestrator, integrator, and independent validator of this project. Use **GPT-6.1 Sol as root orchestrator, integrator, and final validator**, and **GPT-6.1 Sol subagents at medium reasoning effort for bounded research, implementation, content generation, debugging, and tests**. The user explicitly confirmed this root-model override on2026-10-21, intentionally switched around6036974; it supersedes older Astra-only role wording throughout this document. Product scope is unchanged.

**Goal:** Finish this existing Lua project as a complete, enjoyable, faithful Pokémon Red/Blue recreation for Playdate, from a new game through the Champion, credits, and original Kanto postgame. Preserve the carefully refined visual identity of the current project. First improve the development and validation harness enough that agents can reliably reproduce, inspect, debug, and verify their work; then use it to implement the complete game in integrated, playable milestones.

This is an instruction to execute the work, not merely produce a plan. If the session supports persistent goals, register or reuse this objective without inventing a token or time budget. Keep the full-game objective active across milestones and context compactions. Do not declare the goal complete after tooling, a vertical slice, a map inventory, or a demo.

## Product identity and fidelity

The user has explicitly chosen this combination:

- **Red/Blue supplies the world, Kanto geography, story, progression, characters, dialogue identity, visual language, and overall feel.**
- **Gen V, specifically B2W2 where applicable, supplies enhanced battle mechanics, base stats, the physical/special split, broader movesets, and the 17-type chart including Dark and Steel.** This is intentional. Do not revert combat to Gen I in pursuit of fidelity.
- **Subsequent explicit user decision, 2026-10-20: add abilities, held items, and natures.** Implement their Gen V/B2W2 behavior for the original 151, including persistence, evolution, menus and battle dependencies. Do not substitute a policy that omits these systems. Keep acquisition and hidden-ability availability explicit without presenting new rewards as original Red/Blue content.
- Implement Gen V typing accurately for the original roster. Support Dark moves and Steel typing without inventing new typings for familiar species merely to fill every type.
- Keep the original 151-species scope. Do not silently add later-generation species, Fairy, Mega Evolution, or unrelated modern mechanics. Preserve the existing effectiveness preview and edge-door usability improvements.
- Use Blue as the working default when Red and Blue differ, following the README's “Pokemon Blue” identity; record this assumption and version-specific decisions. Maintain the original campaign structure while balancing the enhanced combat and learnsets.
- Build the game in Lua using Playdate's rendering and input. Produce reproducible assets and content from explicit source material and generation rules. This is a native recreation, not an emulator or runtime ROM loader.

Keep an explicit fidelity/changes ledger: original behavior, intentional enhancement, reason, source, and acceptance evidence. A documented historical bug is not automatically a desirable gameplay feature. Resolve routine choices autonomously; raise only consequential product ambiguities, with a concrete recommendation, while continuing independent work.

## Read and establish the actual starting point

Follow all applicable AGENTS/CLAUDE instructions and canonical shared-memory guidance. Read `docs/research/codebase-audit.md`, then verify its findings against the current checkout. Its observations describe commit `1cb8225`; code and environment may have changed.

Read the real implementation, not just README claims:

- `Source/main.lua`, `game/context.lua`, `lib/oop.lua`, `lib/statemachine.lua`.
- All `game/*` states and `game/story.lua`.
- `world/tilefactory.lua`, `world/spritefactory.lua`, every `world/sprites/*` grid, `lib/shade.lua`, `world/overworld.lua`, `world/player.lua`, `world/npc.lua`, `world/camera.lua`, `world/zone.lua`, and `data/maps.lua`.
- `battle/battle.lua`, `battle/battleScene.lua`, `battle/dsl.lua`, `battle/moves.lua`, `data/pokemon.lua`, and `data/typechart.lua`.
- `tools/autopilot.py`, `Source/dev/autopilot.lua`, both generators, `tools/verify_moves/*`, and `Makefile`.

The audited starting point has six zones: Pallet Town, Red's two floors, Blue's house, Oak's lab, and a test zone. It has 151 species records, 419 move records, and 302 battle PNGs. These counts do **not** establish complete gameplay or correct move behavior. Route 1 is not yet an adjoining playable route.

Capture the starting revision, dirty changes, SDK/tool versions, build, fresh runtime state, representative screenshots, complete available atlases, and a gap inventory. Preserve existing user changes.

## Protect the art that already works

The user spent many iterations getting RED, BLUE, Oak, and Pallet Town right. Treat the current accepted appearance as the visual foundation. Do not replace it with an approximate redraw, generic pixel-art style, uniform thresholding, or a bulk importer that silently rewrites existing art.

Preserve these contracts unless a measured, visually reviewed improvement requires a deliberate migration:

- 400×240 monochrome output; 30 FPS target.
- Logical 16×16 tile/character grids rendered as 32×32 images through the shared grid renderer. Preserve fine output-resolution dither patterns.
- RED's custom, pure black-and-white grids: **do not regenerate RED with the NPC converter**.
- NPC source transcription and per-character mappings: Oak uses `outline`; BLUE/rival, Mom, and Daisy use `greyhair`. Preserve facial detail, silhouettes, hair texture, and directional consistency.
- Border-connected white-cell transparency masks, enclosed white body regions, mirrored right facings, character placement eight pixels above the tile.
- Eight-frame player steps, alternating leading foot, stride-to-stand cadence, grass occlusion/rustle, exit-arrow placement, animated water/shore/flowers, and roof/terrain composition.
- Current interior framing, door arrival facing, and the distinct semantics of step doors and edge exits.

The starting LIGHT shade is actually a 12.5% black pattern and DARK is 50%; prose elsewhere contradicts this. Inspect code and images before modifying palette behavior.

For new characters, tiles, and maps, extend the proven source-to-grid workflow. Pin original reference revisions and checksums, validate inputs, record palette/frame/mask transformations, and provide deterministic regeneration and check-only commands. Keep hand-tuned exceptions explicit and separate from generated outputs.

Investigate a repeatable map pipeline using the original map headers, block layouts, tilesets, warps, object events, and scripts. Validate the coordinate transformation between Game Boy 8-pixel tiles, metatiles, movement cells, current grid coordinates, and Playdate pixels. Do not equate one original block with one current tile without checking. Build one representative new route/interior, inspect its fidelity and playability, and refine the pipeline before bulk generation. Preserve Pallet's accepted composition while connecting it to the expanding world.

Battle Pokémon currently use checked-in PNGs; there is no surviving complete regeneration pipeline. Trace their provenance or deliberately establish a reproducible replacement pipeline with before/after review. Fix canonical ID/asset-name mismatches. Do not claim every asset is already generated at runtime. Evaluate integer scaling, padding, masks, and composition using actual captures before changing battle art.

Optimize measured startup, allocation, memory, and frame costs. Compare runtime generation against generated caches only when measurements warrant it; preserve pixel output across such changes.

## Agent orchestration

Use the session's actual supported model-selection mechanism to explicitly request `gpt-6.1-sol` with reasoning effort `medium` for every worker. Inspect available tools and returned metadata; do not merely label an inherited Astra worker “Sol.” If the current runtime requires a fresh, non-forked worker to override its model or effort, use that mode and supply a self-contained task packet. Do not silently substitute models or raise worker effort. If the requested model or effort cannot be selected, disclose the limitation and resolve it before relying on the requested division of work.

Determine actual concurrency limits. Keep a small number of useful workers active, respect dependencies, and avoid spawning competing implementations of shared interfaces. Prefer isolated worktrees for code changes; otherwise assign disjoint files and serialize edits to shared files.

**One owner controls the Simulator, test Data directory, builds used for E2E, and runtime artifacts.** Worktrees alone do not isolate a shared bundle ID. Workers submit runtime jobs through the owner or a tested queue/lock. Never let independent agents overwrite the same command mailbox or kill each other's Simulator.

Every task packet must contain:

1. User-visible outcome and acceptance criteria.
2. Base revision, dependency contracts, owned files, and allowed scope.
3. Relevant instructions, sources, art references, and fidelity constraints.
4. Required functional scenarios, visual evidence, and failure cases.
5. Exact deliverables and the integration handoff.

Require the worker to return its diff/revision, behavior changes, tests and their results, artifact paths, source provenance, and remaining limitations. Treat the report as evidence to inspect. You, Astra, must review the implementation, rerun the relevant checks on the **integrated revision**, and inspect actual images/animation evidence before accepting it. A worker may help review, but cannot replace your final judgment.

Reject regressions with specific reproduction steps and evidence, return them to the owning worker, and validate the repair. Do not lower a test threshold, remove an assertion, or regenerate a golden image just to make a failure disappear.

Maintain a compact durable execution ledger: accepted revisions, architecture decisions, task ownership/dependencies, implementation versus validation status, test commands, evidence locations, known defects, and the next executable tasks. Resume from it after compaction rather than repeating the audit.

## First implementation milestone: a trustworthy harness

Build on the existing autopilot. Keep its useful movement, input, state inspection, screenshot, atlas, and frame-recording capabilities.

### Reliable runtime and protocol

Implement a documented entry point that resolves the installed SDK, compiles an identified build, launches the exact bundle using the Simulator binary, waits for a verified ready handshake, runs a scenario, writes evidence, and returns a meaningful exit status.

Remove machine/old-checkout paths. Make project, SDK, Data, bundle, and artifact locations explicit. Capture source revision plus dirty-content/build fingerprint, SDK version, run/session ID, command ID, and Simulator PID. The handshake must identify the build actually loaded. Build ordering must remain correct under parallel make invocation.

Add a versioned structured protocol with atomic request/result publication, unique IDs, ownership locking, per-command results, bounded execution, cancellation, heartbeat/error diagnostics, and stale-reply rejection. A timeout must not leave commands silently executing into the next scenario. Distinguish expected collision/interruption assertions from unexpected errors. Invalid commands, missing output, wrong build, failed assertions, and incomplete runs must fail the host command.

Implement safe whole-session reset and explicit fixture setup. Reset queues, input, recordings, rules RNG, world mutations, story, trainer flags, and Pokémon consistently. Existing `intro reset` is not safe as an arbitrary-state fixture reset. Isolate test saves from real player saves. Terminate only owned processes.

### Deterministic actions and meaningful diagnostics

Separate gameplay randomness from cosmetic randomness. Drawing currently consumes `math.random` for battle shake; seeding alone is insufficient. Give rules a testable RNG seam, define simulation/frame timing, and move state advancement out of rendering where appropriate. Prove rules outcomes do not change just because screenshot or rendering cadence changes.

Add bounded await/assert operations for root and nested states, zone ID, story flags, movement settlement, menus/dialog readiness, battle events, HP/PP/status, and expected outcomes. Define exactly which completed frame a capture represents. Support controlled button press/hold/release and isolation from stray physical input during tests.

Provide structured read-only snapshots and timestamped traces for root/overworld/battle transitions, input, RNG seed/state or reproducible roll sequence, active command, player/party, enemies, menus/dialog, camera, terrain, and event flags. Use stable IDs and semantic events rather than parsing English dialogue as the only oracle.

Every failed scenario should leave a reproducible bundle: build/run metadata, scenario, seed, action/tick trace, state snapshots, logs/errors, last frames, and relevant diffs. Outputs from different runs must never mix.

### Test layers

Use three complementary layers:

1. **Rules and lifecycle contracts:** OOP/Signal where relied on, state transitions and reentrancy, Pokémon progression, type chart, battle effects, party/inventory/save rules as added. Exercise meaningful public interfaces and invariants.
2. **Content and generation validation:** schemas, canonical IDs, move semantics/learnset levels, map dimensions/coordinates/connections, conditional blockers, encounter tables, sprite coverage, masks, source pins, and reproducible output.
3. **Real SDK Simulator journeys and visual checks:** actual input, collision, movement, overlays, transitions, battle UI, rendering, and later campaign/save progression.

Playdate Lua is not automatically stock Lua 5.4: this repository uses extensions such as `+=`. Choose an SDK-based test runner or a deliberately compatible pure-Lua rules subset. Validate the same production behavior; avoid an unverified regex transpiler or a large fake Playdate implementation.

The existing move verifier checks unordered move-name membership against Black/White, while generation targets B2W2. Upgrade it to the chosen version, level-aware ordered learnsets, relevant data/mechanics coverage, pinned sources, and nonzero failure exits. A generator must not be its own sole correctness oracle.

### Visual validation

Produce a full visual catalog:

- Every tile and animation frame; roof composites, terrain overlays, exit arrows.
- Every standing/walking character frame in every direction, with masks on white, black, and textured backgrounds.
- Both battle views for every supported species; missing art must be explicit.
- Full-map renders and collision/door/event overlays.
- Native 400×240 scenes plus nearest-neighbor enlargements.
- Frame sequences for walking, grass, camera scrolling, doors, battle transitions, and representative attacks.

Freeze or deterministically select camera, animation phase, RNG, timers, and input for comparable captures. Use exact pixel/mask comparisons for protected assets and carefully specified scene comparisons where animation or dynamic text is expected. Report changed regions; do not hide regressions behind broad tolerances.

Maintain two distinct checks: preservation against the reviewed Playdate baseline, and fidelity against original reference material transformed by the intended adaptation. Neither replaces human/agent visual inspection. Astra must inspect new/changed art at native size and in motion, not merely accept an image-file path.

The research screenshots are starting observations, not an exhaustive approved golden suite. Establish reviewed baselines and document intentional changes. Initial automated comparison must demonstrably fail on a controlled changed-pixel/mask defect.

### Harness exit criteria

Before broad content expansion, demonstrate:

- Clean build/start/handshake and repeatable isolated reset.
- False/stale/wrong-build acknowledgements rejected; invalid commands fail; timeout/cancellation recovery works; two clients cannot corrupt one run.
- Starting bedroom/dialog, stairs, exterior/interior door round trips, overlays, grass, all three starter choices, rival win and loss, normal battle return, and blackout covered with assertions and captured evidence.
- At least one realistic walk through the intro without teleporting around collision or progression gates. Fixture teleports may supplement it.
- Gameplay RNG independence from cosmetic draw cadence.
- Asset-ID coverage catches the existing species filename mismatch; visual regression detection catches a deliberate mutation.
- One documented smoke command and deeper suite usable by a fresh Sol worker without oral instructions.

## OOP and state-machine architecture

Evolve the existing design through tested seams. Preserve the distinction between Playdate `class()` sprite entities and the lightweight custom `Class()` domain/system objects unless evidence justifies changing it. Favor composition, clear ownership, and deep modules with small interfaces. Avoid a speculative framework, giant global manager, or class per data row.

Build on `GameContext`, `Battle`/`BattleScene`, the battle effect DSL, and hierarchical state machines. Separate immutable definitions, persistent session/domain state, and disposable rendering objects. Trainer completion and world changes must survive save/reload, not merely sprite reconstruction.

Define owners and transition contracts for gameplay, menus/dialogs, traversal, cutscenes, battle, party selection, capture, evolution, blackout, and persistence. Document which updates continue beneath overlays: visual animation may continue while input and progression triggers must obey the intended pause policy. Test lifecycle order, same-state reentry, transition during update/draw, nested overlays, cancellation, listener cleanup, and input propagation.

Replace growing hard-coded story-stage conditionals with a small, inspectable event/quest/cutscene system supporting prerequisites, one-time actions, NPC movement, dialogue, rewards, and stable persistent flags. Keep the current intro behavior through the migration.

Add a world mutation interface that keeps map data, rendering, collision, and interactive objects consistent. The current tile swap only changes rendering/data through separate calls; it is insufficient for Cut trees, boulders, gates, and persistent puzzles.

Give party, inventory, battle rules, world events, and save serialization cohesive interfaces. Inject dependencies that actually need to vary, especially rules RNG and persistence. Reuse composable battle effects, while implementing special move behavior explicitly rather than representing unsupported moves as successful no-ops.

Measure before optimizing. Profile startup, map entry, battles, sprite/tile caches, repeated transitions, allocation/GC, and long sessions. Maintain 30 FPS as the target and establish measured memory/frame budgets. Simulator speed is not proof of physical-device performance. Record unavailable hardware checks honestly and continue everything that can be validated locally.

## Implement the full game in dependency-ordered playable milestones

Create a complete content/system matrix and dependency graph using primary references. Then implement connected slices, each with functional, visual, persistence, and regression evidence. Do not build all maps first and discover that traversal/events cannot support them.

A suitable sequence, adjustable when dependencies justify it:

1. Harness qualification and protected visual references.
2. Domain/state/data foundations: correct level-aware moves, audited battle behavior, party, capture, inventory/items, healing, money, storage, Pokédex, evolution, and versioned saves.
3. Pallet → Route 1 → Viridian → Oak's parcel/Pokédex → Route 2/Viridian Forest → Pewter/Brock. Make this a coherent first campaign milestone with trainers, shops, healing, capture, progression gates, and save/reload.
4. Mt. Moon/Cerulean, Bill, Vermilion/S.S. Anne, and the systems/content needed for their story and HM progression.
5. Connected midgame Kanto: Rock Tunnel/Lavender/Pokémon Tower, Celadon/Rocket Hideout, Saffron/Silph, Fuchsia/Safari, cycling/fishing/travel, remaining routes and interiors, and their prerequisites.
6. Surf/Strength progression, Seafoam/Cinnabar/Mansion, remaining gyms and rival encounters, Victory Road, Elite Four, Champion, credits, and Hall of Fame.
7. Original postgame, including Cerulean Cave/Mewtwo and legendary encounters; complete supported content, audio, balancing, polish, performance, and release validation.

The matrix must cover towns/routes/dungeons/interiors, NPCs/trainers/parties, signs/items/secrets, puzzles and blockers, encounter distributions, key items/HMs/TMs, badges and obedience/progression rules where applicable, shops/healing/PC, capture/evolution/learning, menus, dialogue/naming, saves/continue, music/SFX, endgame, and postgame. Derive the inventory from references rather than this illustrative list alone.

Make all 151 species technically supported and verify their data, art, battle participation, evolution/learning, and storage. Distinguish species support from natural availability in one original version. Record a clear policy for exclusives, trade evolutions, in-game trades, and event-only Mew; do not quietly require unavailable link hardware or invent a Mew encounter and call it original. Online multiplayer and emulator-link recreation are separate product decisions, not hidden prerequisites for the main campaign.

Audit the mechanics required by every move/item/ability actually exposed to the player. Broader moves must work, not merely appear in menus. Establish the Gen V feature policy explicitly for abilities, held items, weather, and other mechanics beyond the existing engine; retain the Red/Blue campaign identity and implement dependencies of enabled content. Do not promise complete competitive Gen V simulation from the current data table alone.

Investigate current defects with regression cases, including last-four moves ignoring level, absent special-move behavior, asymmetric PP handling/all-PP exhaustion, status cleanup across battle exit, fixed-damage/type interactions, overkill damage used for drain/recoil, outcome ordering, experience/growth assumptions, and species art aliases. Verify intended Gen V behavior against appropriate primary data/implementation references instead of perpetuating comments.

## Acceptance and completion

For each milestone, provide a concise record of the playable outcome, changed revision, validation performed, actual evidence inspected, remaining gaps, and next work. Keep going after acceptance; do not ask whether to continue routine authorized work.

The full goal is complete only when:

- A clean checkout can build and run using documented tooling.
- The content matrix is implemented and validated, with every intentional deviation explicit.
- A fresh player can complete the campaign through credits and reach the implemented original postgame without debug shortcuts or softlocks.
- Automated input-driven journey coverage, targeted rule tests, content validators, save/reload tests, and visual regressions pass on the integrated build.
- Party/storage/capture/evolution/items/trainers/progression work together; data-entry counts are not substituted for gameplay validation.
- Save/continue preserves significant state, handles supported schema versions and recoverable corruption, and does not overwrite real saves during tests.
- Protected visuals retain their intended appearance; new content matches that style and has reviewed provenance and captures.
- Relevant missing-art, unimplemented-move, crash, and progression-blocking defects are resolved.
- Performance/resource measurements, long-run results, and device validation status are reported accurately. Do not claim physical-device validation that was not performed.
- The final deliverables include the playable `.pdx`, source/generation pipeline, reference manifests, developer/test instructions, campaign/content matrix, accepted evidence, and an honest list of any remaining nonblocking limitations.

Begin now by verifying the checkout, establishing baseline evidence, assigning bounded Sol 6.1 tasks, and implementing the harness milestone. Planning is part of execution; it is not the final deliverable.


## Acceptance priority reaffirmed2026-10-21

Close Pallet-to-Brock before integrating broader campaign content. Fix authoritative
replacement-opponent Pokédex entry/persistence, discover every nested Brock
scenario in the serial suite, repair all host generator preservation failures
without weakening scalar/effect checks, and implement FocusEnergy plus an explicit
mechanics exposure checklist for each playable milestone. The checklist includes
naturally reachable species, evolutions/levelups, trainer parties, items and
abilities; intended content must not be removed to avoid a failing check.

Acceptance needs actual input through intro/parcel, capture/party changes, Forest
trainers, healing/medicine, learning, accepted natural evolution, Brock/badge/TM,
full-bag retry, blackout recovery and actual process Save/Continue. Keep evolution
cancellation coverage. Prove meaningful Bulbasaur and Charmander viability as well
as Squirtle; a Squirtle-only route which cancels evolution is insufficient.
Continue directly through MtMoon/Cerulean and all later campaign/postgame work
after this gate. Brock is not the full objective. Verify runtime ownership from
actual process/runner state; ledger PID/running statements are historical hints.
