# B host fixture repair

This isolated worker merged exact `7fb7bf76` into its checkout. Before repair,
its complete Source tree matched B. No root checkout, Simulator, device, USB,
runtime lock or live journey was accessed. All SDK work was compile-only.

The two disposable device candidate tests now fake only
`git rev-parse HEAD` with their exact candidate cwd and text-mode arguments.
All other `check_output` calls reach real Git, including activation inventory
JSON reads. Their original fake revisions and real SDK compilation remain.

The production import test retains the frozen 270 imports and 126 registration
lines from `93d480b77f3d231c7c806cf57f71c5e064fba3f0`, including the existing
bootstrap relocation and boot-tracing expectation. It permits exactly 17
additional B story, field travel/gear and Safari imports at explicit anchors.
Every original order, compiled-dev inventory, registration, staging and asset
assertion remains. The frozen fixture itself is unchanged.

Regenerate the development extension fixture from the pinned pokered reference:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python3 - <<'PY'
import os
from pathlib import Path
from tools.source_map_fixture import records
from tools.generate_source_map_cache import canonical
Path('Source/dev/sourceMapFixture.json').write_bytes(
    canonical(records(os.environ['POKERED_REFERENCE_DIR'])))
PY
```

The existing generator is unchanged. The reference revision remains
`af519899719f0754965776faac0e836a3b906e6d`. The fixture grows from 109 to 150
maps: B's 149 plus exactly `ViridianSchoolHouse`. Both original decoded extension
records (`Route22` and `ViridianSchoolHouse`) and every old manifest entry remain
identical. All existing extension, generic actor and reproducibility assertions
remain; production Lua/data, accepted evidence and baseline catalogs are unchanged.

Validation on SDK 3.1.2:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python3 -m unittest tools.tests.test_device_cycle tools.tests.test_device_simulator_smoke tools.tests.test_production_build tools.tests.test_source_map_activation tools.tests.test_source_map_pipeline tools.tests.test_generic_actor_inputs -v
python3 -m unittest tools.tests.test_grass_cut_data tools.tests.test_npc_trades tools.tests.test_coverage_matrix -v
```

The first command passes all 65 tests without skips, including real production,
harness, legacy startup and both private device SDK compilations. The second
runs 15 tests without skips and retains four failures for root:

- Grass Cut's pinned generator inventory lacks installed overworld maps
  `FuchsiaCity`, `Route12`, `Route13`, `Route14`, `Route15`, `Route16`, `Route17`
  and `Route18`. The generator iterates its fixed field-move pins rather than
  B's full installed inventory. Root must extend pinned inputs and assess the
  generated production recipes; the exact equality assertion stays red.
- NPC trades has two failures. Its generator binds every installed trade map,
  adding `pokered:ROUTE_18_GATE_2F:objects:1` as event five. Checked-in policy has
  four events; all other generated sections match. The test still requires four
  and production still parks trades. Root must reconcile that policy explicitly.
- Coverage freshness fails before row validation. The snapshot names
  `f86d62577f2288f5ae14f3102158da0f7fd90f82` and fingerprint
  `d65926449f456f2ebfe21e4fcb14bf8b4813e3a844dd2ac697c7811bb9d80889`.
  It describes accepted A's 108 maps. Root must review B's rows, snapshot and
  evidence scope; changing only the fingerprint would relabel stale evidence.

The original root log reported 1033 tests, eight failures and two errors. These
targeted reruns resolve the two compile setup errors and four fixture failures;
they are not a new full-suite run or runtime acceptance.


## Follow-up data repair

On top of `9a6fd5f3`, apply root's prepared field expansion and trade data patches
from `m55b-field-cut-expansion-prepare-20261030-01/root.patch` and
`m55b-trade-data-refresh-prepare-20261030-01/root-data.patch` under the external
evidence directory. Their generators, installed maps, decoded grids and art are
unchanged. The original four diagnostic failures above describe the first repair;
this follow-up resolves the Cut and trade failures without changing coverage.

After applying the new pins, copy the field preparation's `inputs/` directory to
`tools.materialize_field_moves.reference_root()` only if that directory is absent,
then call `verify_cache(reference_root())`. The resulting fingerprint directory is
`397bdbacf17decedbf905f08d6cd4d0b8bd696f2fdc697d82f228a32fce6a732`; all 88 cached
files verify. Reproduction commands are:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python3 -m tools.materialize_field_moves --check
python3 -m tools.generate_field_moves --check
python3 -m tools.generate_npc_trades --check
python3 -m unittest tools.tests.test_field_move_data tools.tests.test_grass_cut_data tools.tests.test_field_world_data tools.tests.test_field_acquisition_sources tools.tests.test_field_gear_sources tools.tests.test_field_travel_sources tools.tests.test_field_item_qualification tools.tests.test_npc_trades -v
```

All 37 affected tests pass without skips. Independent comparison against
`9a6fd5f3` confirms exact equality of every old field map, tile and other field
value; all 22 old per-map files are also byte-identical. Recursive comparison
preserves every old pin, index and trade-policy value. The eight added maps have
11 tree sites and 70 grass sites; all 324 before-cell stable IDs and grids match
the installed decoded maps. All nine trade records, texts and four old events
remain exact; only `pokered:ROUTE_18_GATE_2F:objects:1` is added.

The trade identity test now compares exact event membership derived from the
pinned nine-trade inventory and installed source manifest. Its identity and source
checks and explicit exclusion of the absent Cerulean trade event remain intact.
`NPCTrades.install` remains absent from the entry point; trades stay parked.


A fresh SDK compile-only harness bundle and the full host suite completed with
1,051 tests, three failures, zero errors and zero skips (136.667 seconds). The
small compile/host logs are retained durably at
`~/Developer/Pokemon-PlayDate-env/evidence/m55b-field-trade-host-6dc256f1-20261030-01/`
with SHA256 checks in `retention.json`. The disposable private bundle was staged at
`/private/tmp/m55b-field-trade-host.6D8aRS/`. Production and private device-test
compile checks also pass within that full suite.

The remaining failures are coverage freshness plus two Vermilion projection
comparisons: `test_common_blue_tables_and_actual_machine_compatibility_are_projected`
and `test_generation_is_exact_and_pins_every_map_and_three_counter_teams`.
A read-only recursive diff confirms their only projection difference is
`/sources/data/fieldMoves.json`: its recorded SHA changes from
`c58b466b2c9bdbe1f97f1b7fb5e800d658623689c27ee398f1818aac9d36d35b` to
`fbdede52c487a6c0668b99b79f186101a10db1069b71aba25e8f7ef58f2e5757`.
The field expansion necessarily changes this dependency hash. Frozen journey
files and their assertions remain untouched for root to regenerate after the
freeze. Coverage remains root-owned and unchanged. No native execution, USB,
runtime lock, root checkout change or push occurred.
