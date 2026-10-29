# Checkpoint 5.5a release scope

Based on exact root `0406bf3`, merged before preparation. The full root candidate
is preserved by fast-forwarding `parked/midgame-b-c-before-55a-20261028` from
`922bf6c` to `0406bf3`. No history, source files or newer worker branches were
removed or reset. Worker water changes remain on their existing commits.

This directory and `tools/activate_checkpoint_a.py` are the only authored files.
Shared source files are unchanged here. Root generates and applies one patch:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python tools/activate_checkpoint_a.py \
  --output "$POKEMON_ENV/evidence/checkpoint-a-activation-UNIQUE.patch"
git apply --check "$POKEMON_ENV/evidence/checkpoint-a-activation-UNIQUE.patch"
git apply "$POKEMON_ENV/evidence/checkpoint-a-activation-UNIQUE.patch"
```

The generated patch includes `runtime.patch` plus the shared manifest and the two
cache files rebuilt by `tools/generate_source_map_cache.py`. Do not apply both
patch forms. `runtime.patch` is provided for reviewing code changes alone; it does
not activate the map inventory. There is no alternate production manifest or
cache directory. The helper writes only a fresh requested patch file, never
shared Source. Runtime edits are reproducible from the exact root commit.

The inventory is the accepted 65 map names from `63267b0` plus the 43 East names,
using the CURRENT shared entries, hashes and root activation metadata. It is
**108 installed candidate maps**, not 171 playable maps. Main remains at 65 until
root accepts three earned 5.5a saves. South/Saffron package registration is removed.
Tower, Silph, Snorlax and Dojo installation/delegation is guarded by actual map
membership and module presence. Only installed gym descriptors register, retaining
Erika. Hideout, the source elevator, Celadon services and earlier behavior remain.
Fuji stays hidden at home before the parked Tower rescue.

Surf/Strength/Fly and Bicycle/fishing controllers are not registered in the A
release. Party and Bag entry points fail clearly for absent controllers rather
than calling missing modules. Their future SDK suites are gated by installed map
scope; earlier suites remain. Catalog additions follow active map paths and omit
the future ghost and field-gear images. No baseline is changed.

`production-exclusions.json` identifies future-only files for production staging.
The returned build patch opts into those exclusions only for the exact 108-map
family composition and always excludes dev/proposal copies. Files stay in Git
and remain available to the harness and parked candidates. Existing domain/schema
files required for v4 normalization, Celadon coins or shared battle/session code
are explicitly retained; dormant data is not runtime installation. All protected
battle sprites remain, including Snorlax: they belong to the existing 151-species
inventory and are not future-only art.

Initial verification: the patch applies to root files, generates exactly 108 maps,
and compiles using the existing production builder. The actual main PDZ retains
Hideout/Celadon and contains no Tower/Silph/Snorlax/travel controllers. The PDX has
no South/Saffron data or proposal copies. This is compile-only preparation. Root
alone runs Simulator, checks all 2494 protected images and accepts the checkpoint.
Evidence: environment `evidence/checkpoint-a-preview-01/`. No Simulator, push or
delegation occurred. Further host and preservation checks are reported separately.
