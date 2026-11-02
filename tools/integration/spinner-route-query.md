# Spinner route query candidate

Host-only implementation on exact main base
`24ea539cd68142af6b50ca57841cdb8ae350f519`, branch
`t3/spinner-route-cache`. Only `Source/game/rocketHideoutStory.lua` changes
game behavior. This is unqualified preparation, not adoption.

The existing private scene cache now has a private accessor. Public `scenes()`
still deep-copies the same scene data, with the same lazy decode, schema/revision
assertions and errors. Explore borrows routes only to compare coordinates and
returns a string ID to the unchanged SourceEvents dispatcher. Padding is queried
once for a nonempty applicable route set, never for absent/empty routes. The
Game Corner guard still precedes the B2/B3 filter. No route table escapes.

Spinner planning scans that same private data in the same order, copies only the
selected path, and constructs a fresh origin. Mutating either returned value or
a public scenes copy cannot affect later plans/lookups. Unknown IDs still reach
`error("unsupported Hideout source ID")`. Nonspinner plan branches, session/lift
APIs, registration/conflict checks and all code after installation are unchanged.
There are no new caches/maps, generated data, timing, GC, RNG or ownership changes.

Verification run once under the existing environment:

- `python3 tools/generate_rocket_hideout_story.py --reference "$POKERED_REFERENCE_DIR" --check`: passes.
- `python3 -m unittest tools.tests.test_rocket_hideout_story -v`: 5/5 pass, no skips.
- `git diff --check`: passes. Static comparison confirms nonspinner plan branches,
  session/lift/install code before explore, and post-install APIs are byte-identical.
- Static public whole-scene copy call sites in plan/explore fall from 1/1 to 0/0.
  A successful spinner plan still copies its path. No measured speed/memory gain.

Root follow-up uses fresh actual SDK qualification/exports; do not repin old
reports. `tools/references/content-transforms-149/provenance.json` currently pins
the old owner hash `0d6e8ec3cd50acf584a622c460c15f7bdb4c4e3655e1c2cc7932ecf124c1ff0e`.
That dependency is stale for this candidate; historical reports remain historical.
No qualification, generated export or evidence hash was changed here.

Exact existing native selections for Root (not executed here):

- SourceEventContracts: `descriptor and returned plans cannot mutate shared source data`;
  `bounded operations reject malformed movement, grants and nonterminal warps`.
- EventContracts: `Real Player scripted Mart UP2 LEFT1 uses eight updates per cell without trigger residue`;
  `Aborting real movement restores its previous cell and stale dialogue callback cannot reward`.
- SourceMapContracts: `source elevators resolve only their recorded floor through the shared map pipeline`.
- Existing `MidgameJourney.fixed_hideout` and
  `tools/harness/scenarios/midgame/hideout-fixed-routes.json`: zero-based route 1
  traverses B3 triggers 1004, 1001, 1003; route 2 traverses 1016, 1014 in reverse.
  These generic native contracts are not dedicated spinner query/detachment proof.

Root must qualify the exact candidate, check original API/unknown-ID/detachment
behavior natively, run guarded 16 MiB safety and paired physical B3 measurements
using the retained heavy-B route. Baseline
`E/heavy-b-memory-hardware-20261102-02` reports active frames
2264.312/2233.062/2224.750 ms without nearby explicit BootTrace GC windows;
attribution is still unknown. Only a measured >=10% phase gain proceeds to review
and adoption. Keep reserve/admission 30/31 GiB and all memory guards unchanged.
No SDK/build/compile/Simulator/device/GUI/lock/storage/delegation/push/main work
was performed by this worker.
