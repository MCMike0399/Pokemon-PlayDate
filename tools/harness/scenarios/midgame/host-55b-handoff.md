# Host preparation for checkpoint 5.5b

This supersedes the README's unapplied-correction paragraph only. The original
patch remains as history. Work is based on exact private checkpoint `a7184504`,
merged in `4d6d6b3` with an identical tree. Production Source remains identical
to `2a015c89`; the checkpoint's test repairs remain intact.

The dormant Tower route approaches `(10,15)` and presses DOWN into the pinned
Marowak trigger `(10,16)`. It omits `face()`, whose stationary-position assertion
cannot be used on that walkable trigger. The dormant Fuchsia route enters Good
Rod House, takes north warp 1 to city `(31,24)`, walks to `(29,22)`, boards Surf
UP into `(29,21)` and lands DOWN. The old blocked cells remain in the manifest
as historical evidence. Existing 5.5a scenarios, fixed scripts and plan are intact.

Preflight still reads the exact `b676f305` current and `0406bf30` full prepared
objects. It now checks the six declared gaps against source actors, flute ranges,
removal flags, boulder coordinates and push surfaces, Bicycle entries, gate stops
and allowed tilesets. It hashes the reviewed prepared APIs and checks their
presence. These are conditional static input projections; Lua APIs are not
executed. No actor is removed or pushed by this host check. Warden source `(8,4)`
is runtime `(9,4)` and pushes to `(10,4)`; `face('right')` already supplies the
first attempt and the following press supplies the second. Its script is unchanged.
Surf input checks use the actual compact terrain and prohibited water pairs.

Evidence is outside Git at
`~/Developer/Pokemon-PlayDate-env/evidence/host-55b-geometry-20261029-01`:
`checked-report.json`, `final-host-checks.log`, `protocol-checks.log`, and
`compile-stage/build.json`. All 37 relevant host/projection tests and 54 protocol
tests pass. SDK 3.1.2 production compile passes. Preflight has 1,569 checks:
5.5a has 656 passes and 158 exclusions; prepared 5.5b has 556 conditional/static
passes and 199 exclusions. Neither scope has a geometry gap or unreachable route.

Root follow-up: a missing historical comparison report is now reported as unavailable,
not as a current geometry failure. Existing report corruption still fails. The
current pinned-source geometry, all call coverage and earned traces remain checked;
no historical evidence is reconstructed. Preflight now exits 0 with 1,569 checks,
zero geometry findings and zero evidence errors. Five existing
earned trace records verify independently. The pinned 169 historical call sites
retain their classification, including 35 inactive sites; the report separately
hashes the corrected driver. Actual occupancy, earned actions, animation, commits,
Safari resources and field controller execution remain unverified. No new packet
is enabled. No Simulator, hardware, USB, push or runtime acceptance occurred.
