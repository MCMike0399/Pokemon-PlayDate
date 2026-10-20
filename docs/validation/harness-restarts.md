# Owned Simulator process restart jobs

A scenario can require an actual process exit and fresh launch between command groups:

```json
{
  "processes": [
    {"requests": [["gamestate", "shot before"]], "outputs": ["before.png"]},
    {"restart": true, "requests": [["gamestate", "shot after"]], "outputs": ["after.png"]}
  ]
}
```

There must be 2–8 groups. The first cannot contain `restart`; every later group requires `restart: true`. Groups accept only `restart`, nonempty request arrays, and optional relative PNG output paths. Top-level commands, requests, journey, outputs, or qualification cannot be mixed with this mode. Existing ordinary scenarios retain their original behavior and layout.

The runner stages and compiles once. Both the global Simulator lock and the same private Data owner lock remain held throughout all generations. The private bundle ID, build ID, session ID, bundle path and save directory do not change. No files are copied into normal user game Data.

Each boundary completes requests, obtains the normal capture quiescence acknowledgement, sends terminate only through this run's owned Popen handle, waits for that PID to exit, and archives its evidence. A kill fallback targets that same owned handle only if termination times out. A replacement process cannot launch until old exit is confirmed. A new Client starts with the continued sequence; pending/poison/quiescent state is never reused. Requests and the quiesce barrier therefore have unique IDs across the entire job.

Only exact protocol publications (`ready`, `heartbeat`, `request`, `result`, `rejected`, `cancel`, `runtime-error`, `captures-final`, each `.json` and its exact `.tmp`) are cleared after exit. Save slots, candidates, trace, capture journals and other files are preserved. Durable-file SHA256 maps before cleanup, after cleanup and after the next ready handshake detect unintended save-byte changes. Known recent-frame files and append-only protocol journals are excluded from durable hashes. Symlinks are rejected.

The old ready publication is absent before launch, its old publisher has exited, and the new process must publish a build/session-valid ready handshake while still alive. A prior ready or reply cannot satisfy the next generation. Missing ready, wrong identity, launch failure, changed save bytes, cancelled requests or incomplete capture finalization fail the job. The runner never invokes fixture recovery to turn a failed restart into success.

## Evidence

`run.json` lists each generation and PID, previous PID/confirmed exit, fresh-ready observation, request sequence range, lifecycle status and durable hashes. Each `processes/0001/`, `0002/`, etc. contains:

- `process.json`, fresh `ready.json`, all numbered request/result evidence, and `simulator.log`;
- `frames/` and `captures.json` for that generation, with any `catalog.json` retaining `image_root: "frames"`;
- `trace.jsonl`, containing only that generation's appended trace bytes;
- `runtime-data/`, an immutable copy made after its producer exits, including that generation's save bytes and protocol diagnostics.

Names can be reused in later generations without replacing earlier artifacts. The root output's `outcome.json` describes the entire job. As in ordinary runs, final private Data is archived once more at root `runtime-data/` and then that exact UUID directory is removed; the archives retain the saves. If owned process exit cannot be confirmed even after the kill fallback, the job fails and retains its exact private Data directory instead of deleting files under a possibly live producer. `outcome.json` records this path. No unrelated process or Data path is touched.

## Save/Continue proof recipe

After root integrates the authoritative context and Save/Continue UI, root can execute:

```sh
python3 tools/harness/run.py --scenario tools/harness/scenarios/restart-save-continue.json --output /private/tmp/pokemon-save-restart-01
```

This supplementary scenario starts with an explicit skipped-intro fixture, walks from bedroom `(5,3)` to `(4,3)`, saves through the actual pause/confirmation UI, then restarts the owned process. The next group contains no reset fixture: it asserts the title menu, chooses Continue through real input, and verifies the persisted position, starter, level and story stage. Root should inspect both native menus and the before/after exploration PNGs, compare generation save hashes, and verify distinct PIDs. A natural intro and broader party/bag/RNG state proof remain separate native journeys. The worker has not run Simulator or claimed this UI scenario passed.

Host verification:

```sh
python3 -m unittest tools.tests.test_protocol_restart tools.tests.test_protocol_captures tools.tests.test_protocol tools.tests.test_protocol_integers tools.tests.test_protocol_suite -q
```

The restart tests use an isolated host mailbox producer double, real Client/locks/files, and injected owned-process lifecycle handles; they do not pretend to implement Playdate or game rules. They prove stale-handshake rejection, retained save bytes and frame/trace evidence, unique sequence continuation, failed relaunch, boot mutation rejection, lock enforcement, symlink rejection, and unconfirmed cancellation stopping the owned process without recovery or another launch. Actual macOS Simulator PID/Save/Continue behavior remains root's execution responsibility.
