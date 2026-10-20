# Staged Pokémon codec and transactional save container

Originally prepared at `/private/tmp/pokemon-save-foundation/Source/`, then imported by root for real SDK contract execution. The worker now owns only persistence modules/contracts and the small shared decimal-integer helper during repair; no game session, UI, bundle Data or Simulator is accessed by the worker. Root's first integrated run passed 93 of 94 total contracts, exposing a sequence-header precision defect described below. The repaired runtime rerun remains pending. These modules are not an implemented Continue menu, aggregate world save or battle resume.

## Authoritative current Pokémon record

`domain/pokemonCodec.lua` exports `PokemonCodec.encode(actualPokemon)`, `decode(record)` and `validate(record)`. Encode/decode return a detached record/new actual Pokémon or `nil, reason`; validation returns `boolean, reason`. Version 1 records preserve species, nickname/name, level, XP, HP, major status and sleep counter, selected move order, exact remaining PP including zero, queued learning choices and `nextMoveChoiceId`.

Decode invokes the real production `Pokemon(species,level)` constructor to derive max HP, stats, types, dex number and XP threshold, then overrides durable choices instead of deriving the saved moves from the encounter learnset. It consumes no rules RNG. Derived values are never trusted from the record. Stat stages, confusion and flinch reset through `resetStages`; they belong to battle execution, which this record does not resume.

Validation rejects unknown version/fields/species/moves and runtime-only `noPP` fallback moves such as Struggle, duplicate/empty/oversized/sparse move lists, extra/missing/negative/excess PP, invalid level/HP/XP/name/status, malformed learning arrays, duplicate/out-of-order choice IDs/moves, bad next ID and source tuples that do not match the current species' canonical B2W2 learnset. Known moves need not appear in the current level-up learnset, because player choices from future TM/tutor/evolution flows must be preserved; acquisition legality is a separate content/rules check. A queued choice already known by the Pokémon remains representable, matching `resolveMoveChoice`'s existing already-known behavior.

Sleep uses the approved remaining-blocked-turn invariant: a durable sleeping Pokémon may have `statusTurns` 0–3. A positive counter blocks/decrements; zero wakes at the next attempted turn. Non-sleep statuses require counter zero. Both positive and zero sleep records roundtrip without being cured during load. The current learning fields were coordinated with the learnset owner: `pendingMoveChoices` contains `{id,move,level,sourceOrder?,sourceMoveId,reason="level-up"}` and the next ID exceeds all queued IDs. Codec choice source validation uses the complete matching move/level/order/source ID tuple. Names are 1–10 printable ASCII bytes, matching all current species names and the original naming length; no naming UI is implemented. Current cubic XP thresholds come from production `xpForLevel`; level 100 can preserve extra XP without inventing another level. XP/choice counters are bounded by the installed SDK signed integer maximum 2147483647, rather than relying on a 64-bit/double Lua assumption.

The **session policy is saves outside battle only**. The eventual session owner must reject save attempts while a battle/transition is active and establish a coherent aggregate snapshot before using this codec. Neither an isolated Pokémon record nor SaveStore knows GameContext's battle phase. Do not advertise battle saving or silently discard a battle coroutine/RNG/turn state. Major status, HP, PP and pending choices remain persistent; only documented battle transients reset.

## SaveStore interface and format

`domain/saveStore.lua` provides `SaveStore(prefix, validate [, filesystem])`, then `load()`, `save(data)` and `recover("candidate" | "published")`.

- `load()` returns `data, metadata` from the newest valid **published** slot; unavailable/blocked state returns `nil, metadata` with an explicit reason.
- `save(data)` returns `true, metadata` only after candidate and published bytes have both been read back and validated. Failure returns `false, metadata`; callers must handle it.
- `recover(source)` is a deliberate recovery decision, not an automatic fresh start. It returns the same mutation result shape. Candidate recovery promotes the existing candidate before it can be reused. Published recovery writes the newest validated committed data into the damaged/older slot using the normal candidate transaction.

The prefix is mandatory, safe and relative to the current bundle's Data directory; the caller chooses it explicitly. Example `player-save` yields `player-save.a.json`, `player-save.b.json`, `player-save.candidate.json`. Existing prefix directories must already exist. There is no default production path, cross-bundle access, delete/reset function or automatic cleanup. The owner must serialize calls for one prefix; the SDK implementation is synchronous and has no internal yield points.

Each JSON envelope contains format ID, schema version 1, a canonical decimal-string sequence decoded to a native integer, exact serialized payload string and FNV-1a-32 checksum. The checksum binds decimal schema, newline, decimal sequence, newline and the exact payload bytes. It does not depend on re-encoding table iteration order. Whitespace changes in a semantically equivalent payload still invalidate its checksum. FNV is corruption detection, not authentication or anti-cheat. FNV starts from the exact signed-int32 literal `-2128831035` (hex `811c9dc5`), never the float32-rounded positive decimal 2166136261. Signed low-32-bit arithmetic and SDK known vectors for empty, `a`, `foobar` and `hello` avoid integer/formatting surprises.

Sequences still range 1–2147483647; changing the wire representation does not lower that cap. `domain/decimalInteger.lua` encodes native signed-int32 integers and parses canonical decimal strings with pre-multiplication overflow checks, without using the lossy JSON number decoder. It rejects leading zeroes, whitespace, plus signs, exponent/decimal forms and out-of-range values. The helper also represents signed minimum -2147483648 exactly and is available for future explicit domain/RNG codecs; it does not alter global JSON behavior. Small legacy numeric sequence headers through 16777215 remain readable. Larger numeric headers are ambiguous under the SDK decoder and fail closed as `canonical-decimal-sequence-required`; existing artifacts are retained for explicit repair. New writes use decimal strings across the entire full sequence range. Save checks the cap **before incrementing**, preventing signed overflow. Equal sequence numbers with different payload bytes are an explicit conflict, never resolved by arbitrary file order. Payloads are bounded to 262144 bytes and complete envelope files to 1048576 bytes; nesting is bounded to 64. Primitive checks reject cyclic/metatable/function/userdata/mixed-key/sparse data and nonfinite/out-of-range numbers. A JSON encode/decode comparison rejects lossy numeric serialization rather than silently altering player data.

The mandatory `validate(data)` returns `true` for an acceptable payload or `false, reason`. It receives detached decoded primitive data, not caller/live object references. Mutation by a validator is rejected; exceptions become failed validation. This is the seam for the actual domain codec, not a substitute fake game. The staged contracts validate payloads using `PokemonCodec.validate`; a future aggregate schema must validate party, storage, inventory, story, maps and flags coherently before session publication.

## Commit and recovery policy

A normal save scans all three artifacts, validates the incoming detached payload, selects the missing/older published slot, writes the candidate, flushes/closes it, reads it back, validates checksum/schema/payload/sequence and exact complete bytes, then performs one rename into the selected published slot. It then verifies that published file and exact bytes. The other committed slot remains untouched.

| On-disk condition | Read/write behavior |
| --- | --- |
| No artifacts | `load` reports `empty`; first save allowed. |
| Two valid published slots | Load highest sequence, keep older backup until the next save replaces it. |
| Valid published state plus valid uncommitted candidate | Load published state with pending-candidate metadata. Save blocks until the caller explicitly recovers candidate or published state. Candidate never silently outranks a committed slot. |
| No valid published slot, valid candidate | Load returns no normal data and reason `recoverable-candidate`, exposing candidate sequence/data in metadata. Caller may explicitly promote it via `recover("candidate")`. |
| Valid published state plus corruption | Load returns validated committed state with `recovered-published` and per-artifact diagnostics. Save blocks until explicit recovery, preserving damaged evidence. |
| Both slots corrupt, no valid candidate | Load reports `corrupt`; save/recovery cannot silently replace it with a new game. External repair/export or a future explicit reset flow is required. |
| Unsupported schema in any artifact | Read, save and recovery all block. No older build overwrites newer-version data, even if another slot is readable. |
| IO error or conflicting sequence | Block rather than treating unreadable/ambiguous state as absent. |

A complete candidate is not itself a commit. A failure before rename leaves the old published state selected. A crash immediately after rename can produce a failed acknowledgement even though the new published state is valid and should load; the commit marker is the rename, not the caller receiving success. Explicit candidate recovery moves the only-good candidate into a published slot before a subsequent save may write the candidate path, so a later failed write cannot erase recovered state. With no valid published slot, recovery overwrites only one damaged slot after the caller explicitly chooses it; the other artifact remains available as evidence.

`recover("published")` explicitly chooses the last committed state over any pending candidate and repairs the alternate slot. `recover("candidate")` rejects a candidate whose sequence is not newer than a known published slot. Recovery never bypasses unsupported schema, validation, sequence conflict or read failures. Normal slots are retained; there is no destructive cleanup loop.

## SDK basis and limitations

The implementation was checked against the **installed Playdate SDK 3.1.2 manual**. [File open modes](https://sdk.play.date/3.1.2/Inside%20Playdate.html#f-file.open) document Data-first reads and truncating writes; [write](https://sdk.play.date/3.1.2/Inside%20Playdate.html#m-file.write) returns the written byte count, [read](https://sdk.play.date/3.1.2/Inside%20Playdate.html#m-file.read) returns bytes/count, [flush](https://sdk.play.date/3.1.2/Inside%20Playdate.html#m-file.flush) flushes buffered data, [rename](https://sdk.play.date/3.1.2/Inside%20Playdate.html#f-file.rename) returns success and requires existing directories, and [JSON encode/decode](https://sdk.play.date/3.1.2/Inside%20Playdate.html#M-json) operate on strings/tables.

The default filesystem adapter uses those real APIs. The optional filesystem adapter has only `read(path)`, `write(path,bytes)` and `rename(from,to)`; it exists for real-backed fault injection and future filesystem adaptation. It is not a fake SDK. Prefixes must not collide with packaged `.pdx` files because SDK reads fall back to the game bundle when Data lacks a file.

A single rename is the application-level publication operation. The manual does not establish full power-loss atomicity or directory-fsync guarantees for physical hardware; device power-interruption testing remains unavailable. Two-slot validation/recovery is designed to tolerate incomplete or corrupt artifacts, not to claim unsupported physical durability guarantees.

## Confirmed SDK numeric precision defect

Root's real SDK probe at `/private/tmp/pokemon-save-integer-probe-01/00001-result.json` established the failure: JSON encoding wrote exact native integer 2147483647, but SDK decoding returned subtype `float`, displayed `2.147484e+09`, and re-encoded it as 2147483648. The stored header checksum `d5ef77e0` independently recomputes correctly from the archived original bytes, so the failure was decoding precision, not a torn write or checksum writer arithmetic. The installed SDK manual documents 32-bit runtime numbers; the observed decoder behavior is the concrete SDK 3.1.2 evidence.

The repair stores the sequence as exact text and explicitly parses it back to a bounded native integer before checksumming, sorting or incrementing. New SDK regressions cover 16777215, 16777216, 16777217, 2147483646 and 2147483647 through actual file publication/readback, including successful MAX-1→MAX save and unchanged MAX rejection. Third/fourth saves explicitly test replacing existing alternating slots. Diagnostic progress prints were removed; contract assertions remain.

Raw `RulesRNG.snapshot()` is an in-memory integer record, not yet a safe durable JSON wire format on this SDK. The additional SDK contract records original/decoded RNG state as **strings**, exact encoded JSON, numeric subtype and decimal-helper restoration in its unique `*-rng-numeric.facts.json` artifact. It exercises the real RNG stream without changing global rules RNG. The generic payload roundtrip guard rejects a lossy raw RNG snapshot or large Pokémon choice counter before candidate publication, leaving the previous committed state intact. Future aggregate persistence must encode RNG seed/state/roll counters, large XP and choice IDs through an explicit integer wire codec; do not treat a JSON-decoded float as the original integer or silently cast it after rounding. Python reading the emitted JSON and same-process Lua snapshot/restore are distinct from the SDK JSON roundtrip and are not evidence of that decoder being lossless.

## Root integration and contracts

Staged files:

- `/private/tmp/pokemon-save-foundation/Source/domain/decimalInteger.lua`
- `/private/tmp/pokemon-save-foundation/Source/domain/pokemonCodec.lua`
- `/private/tmp/pokemon-save-foundation/Source/domain/saveStore.lua`
- `/private/tmp/pokemon-save-foundation/Source/dev/saveContracts.lua`

After the root chooses integration, copy to an owned build/checkout and import:

```lua
-- After production Pokemon, move definitions and Class are available:
import "domain/pokemonCodec"
import "domain/saveStore"
import "dev/saveContracts"
Contracts.register("save", SaveContracts.run)
```

Recompute the identified source fingerprint before compiling. `SaveContracts.run()` returns exactly `{ok,passed,failed,tests:[{name,ok,error}]}`. The filesystem portion refuses to run unless `HarnessBuild.enabled` and the bundle ID begins `com.poc.pokemon.harness.`. Test prefixes include the session ID, invocation number and case name; tests touch only those exact private Data files and deliberately retain published/corrupt artifacts. Root controls the Simulator/Data lifecycle and archives them normally. No worker accessed that Data or launched a Simulator.

Sixteen contract groups are prepared: all 151 species plus rules RNG stability; custom selected moves/0 PP/partial or zero HP/all major statuses/XP/nickname/pending choices; malformed records; FNV known vectors and exact-byte corruption; two-slot ordering; short/corrupt/throwing writes; failure before/after rename; candidate-only recovery followed by failed save; unsupported schema in slots/candidate; both-corrupt preservation; read faults/conflicting sequences/size bounds; sequence cap and pure/detached callbacks; canonical decimal boundary/native-type preservation, safe legacy headers, real RNG precision diagnostics/fail-closed behavior and third/fourth slot replacement. These groups combine related failure cases; Python/source inspection is not substituted for actual SDK execution.

The repair compiled at `/private/tmp/pokemon-save-compile.pdx`; its runtime rerun is pending with root. Device checks, aggregate session snapshot/migration, save-point policy enforcement, world/story persistence, Continue/corruption UI and all user journeys remain pending. Do not claim save/continue is complete from this foundation.
