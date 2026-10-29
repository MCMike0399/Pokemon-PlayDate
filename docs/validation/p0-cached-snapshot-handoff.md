# Private cached Pokémon snapshot comparison

This packet starts at exact candidate
`4a72cc334f5ab350479c57462e4e6e940af7a2d1`, merged by fast-forward from
`32c6b742a4f5ab4dd7a19cacbdcb7b90ca702fd5`. Only
`Source/domain/pokemonCodec.lua` and this handoff change above that candidate.

`_snapshot` compares live durable fields directly against its validated private
record. It allocates no temporary record on a cache hit and compares scalar
entries without recursive calls. It traverses the codec's existing allowed-field
set, including absent optional values, so adding a codec field also includes it
in this check. Version, absent acquisition and false/nil status retain the same
projection rules as `currentRecord`.

Nested tables are compared by value on every read, including added and deleted
keys; metatables are rejected before traversal. Class checks remain. A mismatch
still calls the existing full `encode` validation and replaces the private record
only on success. No live-table identity shortcut, revision flag, new snapshot
exposure or mutation of the stored record was added. Public `encode`, `decode`
and `matchesSnapshot` implementations are unchanged. Encounter/field callers and
RNG code are unchanged.

Validation used SDK 3.1.2 and the existing environment script:

- 44 host checks passed with no skips: `test_production_build`,
  `test_specimen_traits`, `test_specimen_generator`, `test_individual_data`,
  `test_field_acquisition_sources`, `test_field_move_data`, `test_field_world_data`.
  Log: `~/Developer/Pokemon-PlayDate-env/evidence/p0-cached-snapshot-host-20261029-01.log`.
- Harness compile-only passed, including existing specimen, encounter and field
  contracts. Bundle: `~/Developer/Pokemon-PlayDate-env/evidence/p0-cached-snapshot-compile-20261029-01`.
  Base Source SHA-256: `a58c1738b56f08c3ea7694c8f982ebeee689f2779d8305619bc9fd607b57d6df`.
- Production compilation also passed through `test_production_build`.
- All 54 existing `test_protocol*.py` host checks passed with no skips.
  Log: `~/Developer/Pokemon-PlayDate-env/evidence/p0-cached-snapshot-protocol-20261029-01.log`.

Root must measure actual SDK performance against the 0.153 ms six-member baseline
and run the existing small native suites before accepting this candidate. No
Simulator, USB, host Lua, Lupa or fake SDK game execution occurred. No performance
gain, native behavior pass or hardware acceptance is claimed.
