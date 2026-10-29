# WorldView horizontal wall runs

Candidate starts at exact main `d8580322b6720e5580a2c631c7c26527f1df4b17` on
`t3/merge-world-wall-runs`, using GPT-6.1 Sol at medium effort. Only
`Source/world/overworld.lua` and this handoff change.

Each maximal horizontal blocked run owns one image-free SDK sprite with matching
pixel bounds and collide rect. `walls[y][x]` still returns a wall for every blocked
cell; adjacent cells in a run share that reference. Tile rendering and domain
collision data are unchanged. Attach/dispose visit each run once.

Tile-only edits allocate no wall sprites and skip the SDK membership scan.
Collision edits rebuild only affected rows, reusing runs with identical start/end
columns. Preparation finishes before display-list or tilemap mutation. Undo keeps
the original row tables, run records and wall objects, removes newly created runs,
and restores removed runs' actual registration and visibility independently of
attach policy. Unchanged runs are never removed or registered by the transaction.
This includes manually removed attached walls and registered offscreen walls.

SDK 3.1.2 production compilation, harness build-only compilation and
`git diff --check` passed. Compile artifacts are disposable:
`/private/tmp/world-wall-runs-final-production-stage/build.json` and
`/private/tmp/world-wall-runs-final-harness/build.json`. No game Lua was executed
outside the SDK; no Simulator or USB session was started.

Root should run these commands after integration, using new output directories:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
make compile
python tools/harness/run.py contracts --output "$POKEMON_ENV/evidence/world-wall-runs-contracts-UNIQUE"
```

The existing `world` and `worldViewRollbackContracts` suites are unchanged and
included in that native contracts run. Root should also check native collision
coverage at run edges and split/merge edits, unchanged-run identity, and partial
commit rollback before accepting. Existing contracts alone do not exhaust those
cases. No fixture contracts were added.

A collision edit scans its affected row width and, when replacing existing runs,
the SDK display list to capture membership. Cell lookup tables remain per-cell;
only sprite allocation is merged. Checkerboard collision may save no sprites.
Runtime heap, native allocation, latency, visual preservation and hardware
acceptance remain unmeasured. Root owns those measurements; this candidate makes
no runtime savings claim and has not been pushed.
