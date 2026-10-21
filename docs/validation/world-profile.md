# Four-map profiling

`tools/profiling/run.py` snapshots **current** Source through the ordinary harness owner-lock/build path and instruments only that private copy. Default is compile-only; the sole Simulator owner may add `--execute`. Every production insertion requires exactly one matching source marker; a changed marker fails before launch. No live Source, cache policy or production GC policy changes.

```sh
python3 tools/profiling/run.py --output /private/tmp/pokemon-profile-build-UNIQUE
# Sole runtime owner only:
python3 tools/profiling/run.py --output /private/tmp/pokemon-profile-native-UNIQUE --cycles 6 --execute
python3 tools/profiling/analyze.py /private/tmp/pokemon-profile-native-UNIQUE/world-profile.json --output /private/tmp/pokemon-profile-analysis-UNIQUE.json
python3 -m unittest tools.tests.test_world_profile -v
```

`--project` defaults to this repository; `--sdk` follows the runner's SDK resolution. Cycles are bounded6..12. A generated temporary scenario is not written into the repository. Build/source hashes, the instrumentation patch, private bundle identity and ordinary owner/PID/evidence rules remain recorded by the runner. The observer, journey and offline analysis live together in `tools/profiling/`.

The observer measures Lua heap KiB, elapsed spans, sprites, zones/cells and registry/tile counts around startup imports/context, four-map install, GameSaves startup, actual view construction and battle entry/exit. Update timing includes production update/draw/timers/incremental GC and excludes harness capture publication. Explicit profiling GC performs exactly two full passes after install, initial fixture and each cycle; it is labeled and bounded. History is capped at512 rows. Full report serialization follows retained endpoint sampling.

One labeled completed-parcel/level50/no-encounter fixture establishes the session. Each cycle directly rebuilds Route1, positions with labeled within-map fixtures, then uses real inputs for the north City connection, Mart and Center door roundtrips, and an actual wild battle victory/return. This is profiling evidence, not a natural campaign completion run. Owned-process RSS is read only for the PID in this run's metadata; it is not device/native allocator capacity. No guessed hardware budget is supplied.

Root's [completed native01 report](observed-world-profile/world-profile.json) passed six cycles. The original rows incorrectly report `simulator=false`: SDK `Inside Playdate.html` documents `playdate.isSimulator` as numeric1/nil, whereas that observer compared it to boolean true. The owned PID/build establish Simulator execution. Original evidence stays intact; future observer uses boolean coercion and records the value type. The portable compile passed at `/private/tmp/pokemon-world-profile-portable-compile-01`.

The five steady post-GC deltas average35.939KiB/cycle; first-cycle cold growth is300.287KiB. Observer retention also grows21 rows/270 row fields per cycle. Final146 rows contain1870 fields and41,996 compact JSON bytes; harness replay protection retains234 request IDs/8,892 string payload bytes. These are logical inventories, **not measured Lua allocation sizes**, and cannot be subtracted from heap growth to infer a game leak. The [offline analysis](observed-world-profile/observer-analysis.json) preserves the original report hash. Exact attribution needs a matched no-transition request/capture control and an explicit observer-release/GC or bounded-history comparison. Lua heap excludes native image/SDK allocations; native capacity remains unmeasured.
