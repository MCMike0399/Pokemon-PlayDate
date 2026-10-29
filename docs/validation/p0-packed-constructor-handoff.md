# P0 packed constructor handoff

Branch: `t3/optimize-zone-cell-build`. The branch fast-forwarded exact main
`32c6b742a4f5ab4dd7a19cacbdcb7b90ca702fd5` to the required private candidate
`4a72cc334f5ab350479c57462e4e6e940af7a2d1` before this change.

The binary loader now keeps validated byte rows behind empty, locked proxies.
Indexed readers and `pairs` still see numeric cells. Native `string.gsub` checks
all IDs and collisions, including unknown zero IDs. Padding also uses strings;
padding beyond byte-palette or 128-value native-return bounds keeps dense rows.

The private constructor translates local IDs with a replacement table into
little-endian uint32 values, then uses native `string.unpack` table construction.
Collision rows use native `string.byte`; Lua still assigns every terrain cell
and applies every binding blocker. Registry preparation, conflict checks,
owned-Zone policy checks and rollback retain their existing paths.

Private eligibility requires the loader's weak identity record. The constructor
checks raw plane identity and shape, every original proxy identity, dimensions
and absence of all raw proxy keys. It repeats those checks after cell-building
yields and after the final registry/metadata reads. Immutable strings supply
all constructed cells, so swapping or shadowing a previously processed row is
rejected before returning the Zone, inside the registry rollback scope.

Public constructors, public defensive definitions and record overrides retain
the dense validation path. Viridian materializes only private cell planes before
its existing strict `GameSession._copy` full-definition boundary. Other fields
still pass through that copier unchanged; its plain-table validation remains.

Validation: 38 existing map pipeline, generator, activation and world-profile
host checks; 5 production artifact checks; and 54 protocol checks passed, with
zero skips. Production and harness compilation passed through SDK 3.1.2 in the
artifact checks. Final production compile-only bundle:
`~/Developer/Pokemon-PlayDate-env/evidence/p0-packed-constructor-compile-20261029-03/Production.pdx`.
`git diff --check` passed. No host Lua, Lupa, fake SDK game execution, Simulator,
USB, deployment, content activation, baseline change or push occurred.

Root still needs the existing 36 map/world SDK cases and protected catalog,
then the isolated Route2 attribution and exact timing smoke. Review native
rejection of raw extra row/plane keys, row replacement and mutations to an
earlier row during later yields or registry callbacks; registry publication
must roll back. Also cover Viridian's full-definition snapshot, padding, normal
indexed movement readers, deltas/reset and defensive copies. SDK compilation
and host checks establish no runtime equivalence, speedup, heap or device result.
