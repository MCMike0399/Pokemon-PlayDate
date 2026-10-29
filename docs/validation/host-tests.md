# Reproducing the complete host checks

Run from the repository root with Python3, Git and Playdate SDK3.1.2 installed
at `~/Developer/PlaydateSDK` (or set `PLAYDATE_SDK_PATH`). This creates a private
reference checkout, virtual environment and compile-only bundle. It does not
launch Simulator or access an existing game's saves.

```sh
(
set -eu
validation_root=$(mktemp -d /private/tmp/pokemon-host.XXXXXX)
python3 -m venv "$validation_root/venv"
validation_python="$validation_root/venv/bin/python"
"$validation_python" -m pip install -r tools/requirements-dev.txt
git clone --no-checkout https://github.com/pret/pokered.git "$validation_root/pokered"
git -C "$validation_root/pokered" checkout --detach af519899719f0754965776faac0e836a3b906e6d
test "$(git -C "$validation_root/pokered" rev-parse HEAD)" = af519899719f0754965776faac0e836a3b906e6d
"$validation_python" - <<'PY'
from tools.verify_moves.fetch_pokeapi import PinnedSources
sources = PinnedSources(fetch=True)
sources.all()
print('Verified pinned B2W2 reference cache:', sources.cache)
PY
"$validation_python" tools/harness/run.py --build-only --output "$validation_root/bundle" snapshot
POKERED_REFERENCE_DIR="$validation_root/pokered" \
KANTO_REFERENCE="$validation_root/pokered" \
PARCEL_BUNDLE_SOURCE="$validation_root/bundle" \
"$validation_python" - <<'PY'
import unittest
suite = unittest.defaultTestLoader.discover('tools/tests')
result = unittest.TextTestRunner(verbosity=2).run(suite)
if result.skipped:
    raise SystemExit('Unaccepted skipped checks: ' + repr(result.skipped))
raise SystemExit(not result.wasSuccessful())
PY
)
```

Stop if any setup command fails. Existing verified reference trees and a fresh
compile-only bundle can also supply those three environment variables. Tests
independently validate pinned reference bytes; the current generator output is
not a replacement oracle. The separate B2W2 cache is populated and checked before
tests; missing inputs fail rather than silently skipping runtime-report checks.
`PARCEL_BUNDLE_SOURCE` supplies the compiled staging
tree and its source manifest for host geometry checks. Compile-only staging and
host success establish neither gameplay nor visual/Simulator acceptance.

For real SDK sessions, follow [the harness contract](harness.md). Only the
designated runtime owner may launch them; use fresh evidence paths and retain
the exact Source fingerprint. The current executed outcomes and remaining
defects belong in [the progress ledger](progress.md), not this command recipe.

The P0 host fixtures based on `309194ee` retain the original Vermilion proposal
inventory: the manifest, compact cache and tile grids. Runtime map JSON belongs
to the active cache generator, not that historical preparation inventory.
Restart mailbox doubles replace only the restart module's process API and stub
its runtime preflight; they never replace the shared Python subprocess API or
probe the physical device. Learnset exposure checks use the shared Python data
parser, which accepts compact and expanded records without executing Lua.

The frozen import fixture remains unchanged. The production artifact check
retains its complete ordered inventory and registrations, permits only the
reviewed `game/bootTrace` and `game/bootstrap` additions, and reads indented
imports and registrations. Renderer preservation compares the original helpers
and complete tile definitions byte for byte; only the exact reviewed image-table
cache section is pinned separately. Original tile constructor assignments remain
protected as well.

After root finishes changing Source, regenerate the two journey projections
from the integrated checkout, review their diff, and check them again:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python3 tools/generate_cerulean_journey.py --source Source
python3 tools/generate_vermilion_journey.py --source Source
python3 tools/generate_cerulean_journey.py --source Source --check
python3 tools/generate_vermilion_journey.py --source Source --check
```

The strict preparation verifier still rejects stale provenance. Changing the
preparation generator or its shared cache generator changes their recorded
hashes even when every generated content artifact is identical. Generate fresh
candidates outside Source and compare them before root decides how to record
the new provenance; do not modify accepted evidence to make a check pass:

```sh
regeneration_root=$(mktemp -d "$HOME/Developer/Pokemon-PlayDate-env/evidence/p0-host-regeneration.XXXXXX")
python3 tools/generate_vermilion_preparation.py --reference "$POKERED_REFERENCE_DIR" --output "$regeneration_root/vermilion-preparation"
python3 tools/generate_vermilion_preparation.py --reference "$POKERED_REFERENCE_DIR" --output "$regeneration_root/vermilion-preparation" --check
python3 tools/generate_source_map_cache.py --manifest Source/data/sourceMaps.json --source-root Source --output "$regeneration_root/source-map-cache"
python3 tools/generate_source_map_cache.py --manifest Source/data/sourceMaps.json --source-root Source --output "$regeneration_root/source-map-cache" --check
diff -ru Source/data/vermilionPreparation "$regeneration_root/vermilion-preparation"
diff -ru Source/data/sourceMapCache "$regeneration_root/source-map-cache"
```

A `diff` exit status of 1 means differences require review. The preparation
comparison at this base differs only in the generator hashes in `provenance.json`.
The strict installed-output checks intentionally remain red until root resolves
that provenance. Their missing, mutated and extra artifact rejection stays intact.

Coverage freshness is independent of these fixtures. There is no checked-in
coverage-matrix generator. Root must review the matrix's rows, source snapshot
and evidence references after integration, preserving historical evidence
identities; changing only its fingerprint would relabel stale evidence. Validate
that reviewed result with:

```sh
python3 tools/check_coverage_matrix.py --project "$PWD" --matrix docs/validation/coverage-current.json
```

Then rebuild the compile-only bundle used by `PARCEL_BUNDLE_SOURCE` and rerun the
complete host recipe above. These commands provide no Simulator or hardware
acceptance.
