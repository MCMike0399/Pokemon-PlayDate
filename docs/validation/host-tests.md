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
