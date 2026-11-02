# Isolated Hideout tile membership candidate

Base: `952db34f540257a351e8e1e5648320339d478315`, merged normally into
`t3/gamecorner-membership-allocation`. No changes to the metadata owner's
checkout, actual B, main or C. Metadata qualification and historical evidence
are intact. Root's actual-B documentary commit `24e49bb4` records the failed
metadata-only GameCorner hardware attempt; its Source is not this candidate.

Only two production files change. `SourceMaps.hasTile(key)` returns the exact
boolean coercion of the same private `compactData().tiles[key]` lookup. It uses
the same lazy record/manifest validation and override/origin scope, returns no
backing value, and adds no cache or qualification shortcut. Hideout retains the
same assertion text, four cell reads, delta projection and all other bytes,
including normalization, transactions, RNG and rollback. The packet checker
verifies the entire Hideout source against the base with only this substitution.
`SourceMaps.compact`, descriptor and tile defensive getters are unchanged.

A successful effect previously called the full-catalogue recursive copier four
times (149 map descriptors plus tile metadata on each call); now it calls that
copier zero times. Four existing `SourceMaps.cell()` defensive cell copies and
the world copy remain. This is a Source-level call count, not measured bytes,
heap, latency or evidence of hardware success. Vermilion's analogous call at
`Source/game/vermilionStoryTerrain.lua:31` is deliberately unchanged.

## Root-provided baseline reproduction (not worker execution)

Root's retained actual SDK report at
`$POKEMON_ENV/evidence/catalogue-copy-b149-native-20261102-01/startup-probe.json`
counts 149 maps and 730 tile metadata entries. Before-GC heap is
6422.949 KiB; retaining one copy after full GC is 7378.660 KiB, a
955.711 KiB increase. Releasing it and collecting returns to 6424.293 KiB.
These are instrumented Simulator diagnostics, not physical allocation totals.

Root's exact qualified `952db34f` minimal red reproduction at
`$POKEMON_ENV/evidence/hideout-projection-red-native-20261102-02/startup-probe.json`
calls `RocketHideoutStoryWorld.project(WorldDeltas.export(), "entrance-open")`
inside the existing `GameBootstrap.withLoading`. It fails after 330 ms on the
third whole-catalogue call: heap 6424.766 -> 9225.837 KiB; error
`game/bootTrace.lua:210: device-test memory guard: 9224.425 KiB at initialize.yield`.
The pure projection does not apply world/session state. Root's script is
`/private/tmp/run-hideout-projection-red-native-20261102-02.py`; setup attempt01
had the wrong helper name and is retained separately. Root must repeat this
same diagnostic against the freshly qualified candidate, then the physical
route. No GC placement, guard policy or Source scope change is warranted.

## Private native packet (Root only)

The frozen base projection is literal original source with only its owner name
changed. `check.py` uses the existing harness overlay, not production imports or
a new runner. It verifies the oracle before staging. Six native case names:

1. `boolean parity for every catalogue key and unknown/nonstring values`
2. `all six effects with empty, unrelated and overlapping world data: old4/new0`
3. `valid corner blocks and out-of-bounds source cell rejection`
4. `unknown tile rejected at every quadrant with original assertion`
5. `fixture truthiness and restoration retain origin fences`
6. `lazy record schema, revision and descriptor validation still fail closed`

The packet wraps the real public copier, never substitutes a cheaper result.
Every differential checks world/spec input immutability, including rejection.
It checks old calls=4 and new calls=0 for every successful effect, and original
calls=1..4/new=0 for rejected inputs. Query coverage includes nil, booleans,
numbers, NaN, tables, function, unknown/empty strings and false/zero/empty-string
fixture values. Invalid schemas, revisions and descriptor dimensions must
reject through both APIs. Scope restoration and detached public getters are
checked. This is a bounded supplementary contract, not campaign acceptance.

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
# Worker-safe compile only (already performed; use a new output name).
python3 tools/integration/gamecorner-membership/check.py --output "$POKEMON_ENV/evidence/gamecorner-membership-compile-ROOT01"
# Root alone; retain unchanged resource guards. Root may use its already-proven
# thin private bundle to execute these unchanged six cases if full harness RSS
# would exceed 1 GiB. Never change production validation for the packet.
python3 tools/integration/gamecorner-membership/check.py --execute --output "$POKEMON_ENV/evidence/gamecorner-membership-native-ROOT01"
```

## Fresh SDK qualification is mandatory

Both East/South and Kanto provenance pin `world/sourceMaps.lua`. Production
staging currently fails closed with `transform dependency changed:
world/sourceMaps.lua`. Kanto independently rejects its stale pin too. Do not
merely update that digest. Root must run the existing actual SDK3.1.2 exporter
on this exact candidate, retain its identified completion and compare the real
outputs before binding new provenance. These commands are **not executed by the
worker**. Root may use its existing controlled thin export staging as in
`gamecorner-metadata-transform-sdk-20261102-02`; record the actual output path
and exact source manifest. No old producer may be relabelled.

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python3 tools/integration/kanto-first-entry/export.py --execute --output "$POKEMON_ENV/evidence/gamecorner-membership-transform-sdk-ROOT01"
# Run the following only after that exact identified SDK job completes.
python3 - <<'PY'
import hashlib
import json
import os
import re
from pathlib import Path
from tools.harness.run import fingerprint
from tools.generate_region_registrations import KANTO_OWNERS

root = Path.cwd()
out = Path(os.environ['POKEMON_ENV']) / 'evidence/gamecorner-membership-transform-sdk-ROOT01'
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def load(path):
    return json.loads(path.read_bytes())

build = load(out / 'build.json')
result = load(out / 'outcome.json')
manifest = load(out / 'source-manifest.json')
assert build['sdk_version'] == '3.1.2'
assert result['ok'] is True and result['session_id'] == build['session_id']
assert fingerprint(out, exclude_generated=False) == build['compiled_source_sha256']
# The complete pre-overlay Source must match, not just the changed owner.
for name, expected in manifest.items():
    assert sha(root / 'Source' / name) == expected, name

regions = root / 'tools/references/content-transforms-149'
kanto = root / 'tools/integration/kanto-first-entry/qualified'
r = load(regions / 'provenance.json')
k = load(kanto / 'provenance.json')
for pins in (r, k):
    assert sha(root / 'tools/references/content-cache.json') == pins['content_pins_sha256']
    changed = []
    for name, expected in pins['dependencies'].items():
        digest = sha(out / 'Source' / name)
        assert digest == manifest[name]
        if digest != expected:
            changed.append(name)
        pins['dependencies'][name] = digest
    assert changed == ['world/sourceMaps.lua'], changed
for name, expected in r['exports'].items():
    assert sha(regions / (name + '.json')) == expected
    assert load(out / 'runtime-data' / ('content-transform-' + name + '.json')) == load(regions / (name + '.json'))

fresh = load(out / 'runtime-data/kanto-first-entry.json')
old = load(kanto / 'export.json')
assert fresh['schema'] == 1 and fresh['simulator'] is True
assert fresh['build_id'] == build['build_id']
# Shared prerequisite enumeration is a set; retain all IDs and multiplicities.
def comparable(packet):
    value = json.loads(json.dumps(packet['sources']))
    for source in value.values():
        source['required_trainers'] = sorted(source['required_trainers'])
    return value
assert comparable(fresh) == comparable(old)
cache = {name.removeprefix('data/contentCache/'): digest for name, digest in manifest.items()
         if name.startswith('data/contentCache/')}
assert cache == k['content_cache']
for name, expected in cache.items():
    assert sha(out / 'Source/data/contentCache' / name) == expected
imports = re.findall(r'import "([^"]+)"', (out / 'original-main.lua').read_text())
assert [name for name in imports if name in KANTO_OWNERS] == k['owner_imports']
region_owners = {'game/rocketHideoutStory', 'game/towerStory', 'game/snorlaxStory',
                 'game/midgameGymStory', 'game/silphStory'}
assert [name for name in imports if name in region_owners] == r['owner_imports']
# Finish all checks before writing any new evidence/pins. Preserve prior bytes.
archives = [(regions / 'provenance.json', regions / 'gamecorner-membership-prior-provenance.json'),
            (kanto / 'provenance.json', kanto / 'gamecorner-membership-prior-provenance.json'),
            (kanto / 'export.json', kanto / 'gamecorner-membership-prior-export.json')]
assert all(not destination.exists() for _, destination in archives)
for original, destination in archives:
    destination.write_bytes(original.read_bytes())
r.update(producer=str(out), producer_build_sha256=sha(out / 'build.json'),
         producer_proof_sha256=sha(out / 'outcome.json'))
k.update(producer=str(out), build_id=fresh['build_id'],
         producer_build_sha256=sha(out / 'build.json'),
         producer_result_sha256=sha(out / 'outcome.json'),
         export_sha256=sha(out / 'runtime-data/kanto-first-entry.json'))
(kanto / 'export.json').write_bytes((out / 'runtime-data/kanto-first-entry.json').read_bytes())
(kanto / 'provenance.json').write_text(json.dumps(k, indent=2) + '\n')
(regions / 'provenance.json').write_text(json.dumps(r, indent=2) + '\n')
PY
python3 tools/build.py --stage "$POKEMON_ENV/evidence/gamecorner-membership-qualified-ROOT01" --output "$POKEMON_ENV/evidence/gamecorner-membership-qualified-ROOT01/Production.pdx"
python3 -m unittest tools.tests.test_region_registrations -v
```

Any missing/failed export, changed content, unexpected dependency, mismatched
identity, export discrepancy or qualification failure stops this procedure.
Review the resulting provenance changes separately; preserve every previous
metadata proof. Then Root must run fresh exact-route 16 MiB safety and the same
hardware itinerary under unchanged 51/50 GiB disk, 1 GiB host and 6/8/9 MiB
policy before any memory-fix claim, adoption or combined performance review.

## Worker results and limits

- `git diff --check` and the frozen-oracle/full-Hideout substitution checks pass.
- SDK3.1.2 private full-harness compile-only passes; final bundle at
  `$POKEMON_ENV/evidence/gamecorner-membership-compile-20261102-02`.
  Base Source SHA256 `de3a21f9b3e9cf1218a51b63d971949886e3a26e609f9b9da35edf2a66b33991`;
  final compiled overlay Source SHA256
  `c5fa73a25862ef479279b3879e65e0c33d97a59d2228e7432da661f34cab7be5`.
- Existing affected host suite: 51 tests, 46 pass, 2 failures and 3 errors.
  All five nonpassing cases are region-registration tests blocked by the stale
  `world/sourceMaps.lua` dependency, including two expected-error-message checks
  that hit the freshness rejection first. No pins or assertions were weakened.
  Hideout 5/5, map pipeline 15/15, shipped-map qualification 7/7, activation 5/5,
  content cache 10/10; region registration 4/9. Log:
  `$POKEMON_ENV/evidence/gamecorner-membership-host-20261102-01.log`.
- Production compile correctly refuses stale East/South qualification, log:
  `$POKEMON_ENV/evidence/gamecorner-membership-production-failclosed-20261102-01.log`.
  Separate direct Kanto generation also rejects `world/sourceMaps.lua`.
- Native six cases are compiled, **unexecuted**. No runtime locks, Simulator,
  device, USB, GUI, new runtime framework, pin refresh or push was used.
  No current full-host-green, native-pass, byte-allocation, latency, memory-fix,
  hardware-safe, B acceptance or device-playability claim.
