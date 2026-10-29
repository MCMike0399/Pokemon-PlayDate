Root integration status: both hook hunks are already applied on main. The
application instructions below describe the historical worker handoff; do not
apply that patch again.

# Current-map Cut resource candidate

Private implementation candidate on `t3/cut-map-resource-prep`. Prerequisite
`1bbdcb194cc938d21d3f8a4ad0e7eb4f3a0635f8` was merged exactly before edits
(merge commit `cac91df1543967ab83e7138dc36c4eefb7ee1e09`). No content is activated.

The implementation changes only `Source/domain/fieldMoves.lua` and
`Source/game/fieldMoveState.lua`. The root integration changes remain unapplied in
[p0-cut-map-preparation-hooks.patch](p0-cut-map-preparation-hooks.patch).
Apply both hunks before runtime verification:

```sh
git apply --check docs/validation/p0-cut-map-preparation-hooks.patch
git apply docs/validation/p0-cut-map-preparation-hooks.patch
```

The first hunk calls `FieldMoveState.prepareMap(currentZone.stableID)` in
`OverworldState:enter`, after source reload and before view construction, between
`overworld.field_prepare.begin/end` trace marks. Door loading, Continue and initial
startup already own that path. Keep this work inside their existing loading and
map measurement boundaries. It neither wraps field selection in loading nor adds
an independent loading task. Preparation uses the existing `yieldIfDue` within
site loops; no GC, timing budgets or measurement classifications change.

The second hunk calls
`cut.treeFrames, cut.ground = FieldMoveState.prepareTreePresentation(cut.effect, cut.preview)`
in the existing Vermilion catalog bootstrap before its tree-frame render loop.
That exporter formerly relied on draw warming its private record. The hunk is
required because production tree draw now consumes prepared images only. No
catalog inventory, driver feature or contract is added.

`FieldMoves.prepareMap` reads only the requested immutable source record. The
map cache strongly retains the two most recently read records, including records
read by source reset. There is no traversal of installed maps. Presentation
retains one map's deduplicated Cut replacement images; maps without field data
release that record. Tree and leaf palette images are shared immutable art,
created only when relevant sites are present or the existing lazy enter fallback
needs them. No session, player, token, world mutation or actor state is cached.
Map coordinates and request-specific grass composition are still prepared at
enter; they are never retained as immutable map resources.

Lazy reads and art preparation remain available when the loading hook is absent,
a move is taught during a visit, or a caller directly opens the existing field
state. Domain validation, cancellation and commit bodies, including PP, badges,
inventory, RNG and source reset, are byte-identical to the prerequisite. Both
palette/mask generation helpers are also byte-identical. Tree cadence, draw
positions, clipping, grass timing and render palette/phase calls are unchanged.

## Worker verification

All checks used the installed env script and SDK 3.1.2. No Simulator, USB,
deployment, push, delegation, host Lua, Lupa or fake SDK execution occurred.

- 22 host checks passed, no skips: `test_field_move_data`, `test_grass_cut_data`,
  `test_field_world_data`, `test_vermilion_catalog_inputs`.
- 5 production artifact/staging host checks passed, no skips:
  `python3 -m unittest tools.tests.test_production_build -v`.
- All 54 existing protocol host checks passed, no skips.
- Production compile-only succeeded with `tools/build.py`.
- Harness compile-only succeeded with `tools/harness/run.py --build-only ... snapshot`.
- The unapplied root patch passes `git apply --check`; `git diff --check` passes.
- Direct byte comparisons against the prerequisite confirmed unchanged domain
  request/guard/commit/reset bodies and both tree/leaf palette-mask helpers.

Disposable logs: `/private/tmp/p0-cut-map-host.log`,
`/private/tmp/p0-cut-map-production-host.log`,
`/private/tmp/p0-cut-map-protocol-host.log`. Disposable production compile stage:
`/private/tmp/p0-cut-map-candidate-build`; harness compile stage:
`/private/tmp/p0-cut-map-harness-build`. These are compile-only artifacts, not
acceptance evidence, and need not survive reboot. Root hooks were not applied to
the worker source or these build trees.

## Root verification still required

Apply both root hunks, then compile the integrated source and run the existing
small field-move, grass-Cut and field-world SDK batches. Compare the protected
catalog, including Vermilion Cut palette images, tree frames and grass frames.
Use the existing exact earned-save smoke to measure first-use Cut and the map
load that now includes preparation; retain the actual ordinary update, loading
slice, map span and heap results. Check cancellation, teaching during a visit,
map reload/Continue reset, and map eviction using existing cases. Refresh journey
source projections only from root's final integrated checkout.

No speed, memory improvement, native behavior, pixel acceptance or hardware
claim is made by this candidate. First-use Cut may still exceed the timing gate
because live transaction checks remain intact. Only root owns those runtime and
hardware decisions.
