# Unadopted Game Corner metadata candidate

Exact requested private B base: `67e391e8c0936ee0cc851f28838350ad1d3d87d6`.
The normal merge is `40971923`; its tree is exactly that base, resolving the
initial main/B divergence in favor of the requested B tree. Work is isolated on
`t3/gamecorner-metadata-allocation`. Root's worktree was not modified.

This targets the actual physical failure recorded in
[b149-gamecorner-memory-stop-20261102.json](b149-gamecorner-memory-stop-20261102.json),
build `7532af0560e64cd187477626cf944ce1`. The raw trace rises from 7634 KiB after
view preparation through actor yields to 9189 KiB before the hard guard. That
establishes neither a retained leak nor one cause. This candidate is not a fix
claim and must not be adopted before Root native checks, fresh safety admission,
same-route physical measurement and review.

The sole production change is inside `MidgameGymStory`: extract its existing
schema/revision-validated private data loader, then check that data for a
species-bearing descriptor before projecting all activated descriptors.
Eligible gifts still take the original public `descriptors()` path, including
all map activation checks and primitive copies. Unrelated calls still return a
fresh empty table. No new ID whitelist, cache, trust epoch or production state.
The existing `cached` owner remains the only data lifetime. Public descriptors,
plan, giftOffer and installation behavior remain; every upstream descriptor,
metadata and story callback and validator is untouched. No actor constructor or
empty-world shortcut. Source data/art/maps, schema4, producer epoch18,
bootstrap, BootTrace, thresholds and safety policy remain unchanged.

The pinned generator/data test proves the only eligible records are
`pokered:FIGHTING_DOJO:objects:6` (EVENT_GOT_HITMONLEE) and `:7`
(EVENT_GOT_HITMONCHAN), each level30. This is a data-derived predicate; adding
another species-bearing record naturally retains the original projection path.
Only the selected ball disappears. The other still remains with the greedy text.

## Allocation accounting

For B's activated Celadon and Fuchsia gyms, each original unrelated metadata
call allocates one projection table, 24 cloned descriptor tables, two
`Party._primitive` visited tables and the empty result: **28 tables**. The
candidate allocates only the empty result: **1 table**, 27 fewer. Game Corner's
11 shipped objects therefore avoid 22 deep-copy calls and **297 temporary
tables per metadata pass**. The six descriptor map-lookup/pattern operations per
unrelated call also disappear. One-time JSON loading is unchanged. Eligible
gifts retain the original allocations; inactive gift IDs still perform the
original projection and return empty. These counts are from source, exclude
strings/native allocations, and are not measured bytes, live heap or timings.

## Checks and Root native work

The private packet is `tools/integration/gamecorner-metadata/`. It adds no
production registration or journey/driver test. `baseline.lua` freezes only the
original loader, descriptors and metadata functions from exact B, with the owner
identifier renamed. The runner derives IDs from the copied current source-map
records, not a manually authored list.

Six bounded native cases are compiled, **not executed**:

1. Old/new deep equality over all **1262** current shipped source event IDs.
2. Empty/unrelated/GameCorner and nil/boolean/number lookup behavior.
3. Both exact Dojo IDs with their map inactive.
4. Both gifts with map active, exact visibility values across all four quest
   flag tuples, mutation isolation, and public descriptor equality. Cases3/4
   temporarily scope only `SourceMaps.nameForID` for the absent Dojo and restore
   it on error; this is not C activation or a Dojo journey.
5. Old unrelated call copies exactly two descriptors; new copies zero.
6. Public projections remain detached after caller mutation.

Root commands (new output directories; only Root may use `--execute`):

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python3 tools/integration/gamecorner-metadata/check.py --execute --output "$POKEMON_ENV/evidence/gamecorner-metadata-native-20261102-01"
```

Inspect the actual contract report for six passes,1262 IDs and zero failures.
Then refresh qualification below, run the existing relevant native actor/content
contracts, and fresh exact16MiB safety admission before any device measurement.
Replay the retained actor-aware route and compare the GameCorner actor-phase
heap progression, phase time and complete error/crash logs. Keep all original
failed evidence. No Simulator/device/USB/GUI or runtime locks were used here.

## Executed worker checks

- 38 targeted host tests passed in4.267s with the existing project venv:
  `test_midgame_gym_story`, `test_content_cache`, `test_rocket_hideout_story`,
  `test_motion_source_render`, `test_source_actor_placement_inputs` and
  `test_source_events`. Log:
  `~/Developer/Pokemon-PlayDate-env/evidence/gamecorner-metadata-host-20261102-03.log`.
  Earlier system-Python attempt02 lacked Pillow; retained as an environment
  failure and corrected by using the documented venv, without changing tests.
- Final private SDK3.1.2 compile-only packet:
  `~/Developer/Pokemon-PlayDate-env/evidence/gamecorner-metadata-compile-20261102-02`.
  Copied production Source SHA256:
  `5984330c73d41e9d71e6e29be47865ea59a903ac74abc55be8fe57f2cce0ca16`;
  complete compiled overlay Source SHA256:
  `bc9c031cd5f0b17f252d5f996edf18a94949021a78088a7c2e080bc9e9c944cf`.
- The frozen native oracle was compared to exact B's relevant original
  functions, allowing only the owner identifier rename; match.
- `git diff --check` passed. No full-host or native pass claim.

## Qualification fails closed

The old transform provenance pins `game/midgameGymStory.lua`. Normal production
staging was attempted and correctly fails with
`transform dependency changed: game/midgameGymStory.lua`. No export bytes,
provenance or qualification rules were edited. Harness compile-only uses the
existing unqualified policies; it is not a qualified production bundle.

Root must obtain actual SDK3.1.2 exports from the current candidate. The existing
controlled exporter also captures East/South through `_registerContent` while
retaining the real deep installers. Kanto's existing pins are unaffected by this
owner change; do not relabel old exports or rewrite historical proof.

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python3 tools/integration/kanto-first-entry/export.py --execute --output "$POKEMON_ENV/evidence/gamecorner-metadata-transform-sdk-20261102-01"
python3 - <<'PY'
import hashlib
import json
import os
from pathlib import Path
from tools.harness.run import fingerprint

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

out = Path(os.environ['POKEMON_ENV']) / 'evidence/gamecorner-metadata-transform-sdk-20261102-01'
build = json.loads((out / 'build.json').read_bytes())
result = json.loads((out / 'outcome.json').read_bytes())
assert build['sdk_version'] == '3.1.2'
assert result['ok'] is True and result['session_id'] == build['session_id']
assert fingerprint(out, exclude_generated=False) == build['compiled_source_sha256']
manifest = json.loads((out / 'source-manifest.json').read_bytes())
ref = Path('tools/references/content-transforms-149')
old = (ref / 'provenance.json').read_bytes()
pins = json.loads(old)
assert sha(Path('tools/references/content-cache.json')) == pins['content_pins_sha256']
changed = []
for name, expected in pins['dependencies'].items():
    copied = out / 'Source' / name
    digest = sha(copied)
    assert digest == manifest[name] == sha(Path('Source') / name)
    if digest != expected:
        changed.append(name)
    pins['dependencies'][name] = digest
assert changed == ['game/midgameGymStory.lua'], changed
for name, expected in pins['exports'].items():
    target = ref / (name + '.json')
    actual = out / 'runtime-data' / ('content-transform-' + name + '.json')
    assert sha(target) == expected
    assert json.loads(actual.read_bytes()) == json.loads(target.read_bytes()), name
    # Retain the existing equivalent export bytes; bind the fresh real producer.
pins['producer'] = str(out)
pins['producer_build_sha256'] = sha(out / 'build.json')
pins['producer_proof_sha256'] = sha(out / 'outcome.json')
archive = ref / 'gamecorner-metadata-prior-provenance.json'
assert not archive.exists()
archive.write_bytes(old)
(ref / 'provenance.json').write_text(json.dumps(pins, indent=2) + '\n')
PY
python3 tools/build.py --stage "$POKEMON_ENV/evidence/gamecorner-metadata-qualified-20261102-01" --output "$POKEMON_ENV/evidence/gamecorner-metadata-qualified-20261102-01/Production.pdx"
```

Any missing export, semantic discrepancy, different dependency change, failed
runtime or stage qualification stops this path. Do not update pins to pass it.
The Root refresh creates a new reviewable provenance change; it is not part of
this unexecuted worker candidate. Device gain, root native success, current
production qualification, visual acceptance and full host green are unclaimed.
