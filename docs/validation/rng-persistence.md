# Lossless RNG persistence

`RulesRNG.toData()` exports a JSON-safe record; `RulesRNG.restoreData(record)` validates and imports it atomically. Independent streams returned by `RulesRNG.new(seed)` expose the same colon methods. The RNG imports only the shared pure `domain/decimalInteger` codec; it has no SaveStore/filesystem dependency and does not replace or patch the SDK JSON decoder.

```lua
local wire = RulesRNG.toData()
-- {
--   version = 1,
--   algorithm = "park-miller-16807-v1",
--   seed = "42",
--   state = "1126542223",
--   rolls = "2"
-- }
local decoded = json.decode(json.encode(wire))
RulesRNG.restoreData(decoded)
```

The example state is the second advance from seed42. Seed/state/rolls are canonical decimal strings, not JSON numeric values. Version remains the small numeric1 and algorithm remains the existing `park-miller-16807-v1`; the recurrence, sampling rules and known integer-seed sequences are unchanged. The record is a detached plain table. Imports reject missing/extra fields, unsupported versions/algorithms, metatables, noncanonical text and out-of-range values before changing the stream.

Valid seed/state values are1–2147483646. Roll count spans0–2147483647, the full signed native-integer nonnegative range of the SDK. No precision threshold or lower counter cap was introduced. At the maximum count, the next draw raises an exhaustion error without changing state or rolls. Rejection sampling advances local candidates and commits only after a sample is accepted; if a retry would exceed the counter range, the entire draw fails without a partial advance. Explicit re-seeding remains the operation that starts a new stream/count; loading does not silently reset a count.

## Numeric snapshots versus wire records

`snapshot()` still returns numeric `{algorithm,seed,state,rolls}` for live traces and in-process inspection. `restore(snapshot)` remains available for in-process replay. Numeric seed, snapshot restore and integer interval inputs now pass through `math.tointeger` and explicit native bounds before arithmetic or mutation. Exactly integral, representable floats such as42.0 are normalized to native integers; fractions, nonfinite numbers and values outside native range fail. This prevents float32 Schrage products or float32 counters from diverging after an otherwise valid-looking input.

Coercion cannot recover bits already lost in an SDK JSON numeric decode. Root's real SDK evidence at `/private/tmp/pokemon-save-integer-probe-01/00001-result.json` showed numeric2147483647 decoding to float2147483648 and reencoding to that different value. Other large integers can round to a different in-range value, which cannot be inferred afterward. Therefore use `toData`/`restoreData` for persistence and any SDK JSON replay input; do not roundtrip raw snapshots through SDK JSON and assume they are lossless. The host can still inspect numeric trace values directly from an encoded response.

## Session integration

Store the wire record as a primitive nested field in the campaign/save payload. Validate it without touching the production singleton by using an independent stream:

```lua
local candidate = RulesRNG.new(1)
local ok, problem = pcall(function() candidate:restoreData(payload.rng) end)
if not ok then return nil, problem end
local validatedRNG = candidate:toData()
-- Validate the rest of the campaign payload before committing session state.
-- The session owner applies this only after all payload validation succeeds:
RulesRNG.restoreData(validatedRNG)
```

Successful `restoreData` returns a detached numeric snapshot, but callers should persist `toData()` output again. The module does not migrate old rounded numeric saves, choose a seed on load, save the world, or apply partially validated campaign state. The root/session owner retains responsibility for transaction boundaries and save schema versions. Root fixture seeds received through SDK JSON should use the same shared decimal codec when they need the full native range.

## SDK contracts and status

Import `dev/rngPersistenceContracts` after production RNG/JSON is available and register:

```lua
Contracts.register("rng-persistence", RNGPersistenceContracts.run)
```

`RNGPersistenceContracts.run()` returns `{ok,passed,failed,tests}` and restores the production singleton afterward. Fourteen real-SDK cases cover native `math.tointeger`, float/int seed and restore equivalence, floating interval normalization, complete signed seed boundaries, canonical detached records, actual SDK JSON high-state/full-counter round trips, known continuation states, unchanged numeric snapshots, malformed version/algorithm/field/text/overflow rejection, maximum counter behavior, transactional rejection-sampling exhaustion, and the singleton API.

Literal independent state vectors include seed1→16807, seed42→705894, seed16777217→654328362 and maximum legal state2147483646 continuing through2147466840,1865008398,524833574,1162539989,1003374717. Tests assert native integer types as well as values, including the16777216→16777217 counter boundary where float32 increments would stop being exact. They use actual `json.encode`/`json.decode`, not a fake SDK or replacement parser.

Worker compilation passed at `/private/tmp/pokemon-rng-persistence-compile.pdx`; `git diff --check` passed. RNG source and contracts are frozen for root-owned Simulator execution. No Simulator was launched by the worker. Actual integrated contract results must be recorded by the root before persistence acceptance. The combat source remains unchanged by this task.

Root-owned integrated acceptance evidence: `/private/tmp/pokemon-persistence-rng-contracts-02/00001-result.json` passed all14 RNG persistence cases and all112 aggregate contracts. The worker inspected the finalized report and confirmed the counts/no failures. Root also reported all915 protected visual artifacts matching exactly. This validates the SDK JSON/native-integer persistence seam; it does not claim campaign/save-load gameplay completion. Source remains frozen pending the root's native combat scenario checks.
