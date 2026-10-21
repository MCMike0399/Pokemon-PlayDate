# Gen V specimen attributes: phase 1

The original151 now have independently stored nature0..24, persistent
`first`/`second`/`hidden` ability-slot preference, species-derived ability ID,
and a canonical held-item field. This is the data/creation/persistence foundation;
ability and held-item battle effects are still required and are not implemented
by this phase. IV0/EV0 remains the explicit stat baseline. No shops, gifts,
hidden-ability encounters, roster, types, maps or protected art were changed.

Root's ordinary integrated SDK run passed **461/461** contracts, including20 new
attribute groups and3 real TrainerEvents groups:
`/private/tmp/pokemon-specimen-integrated-01/00001-result.json`.
The separate creator/session ownership followup then passed **470/470** at
`/private/tmp/pokemon-specimen-ownership-sdk-01`. Root integrated the exact11
reviewed files and confirmed zero Source differences against that proved tree.
Actual production restart/trait presentation recipes remain pending; all GenV
battle effects are not claimed complete.

## Model and migration

`Pokemon(species,level,attributes)` is pure and validates detached
`{natureId,abilitySlot,heldItem}`. Two-argument construction deterministically uses
Hardy/first/none with no RNG. Nature modifies the completed non-HP stat by integer
110/100 or90/100; HP is unchanged. `Pokemon:ability()` derives the current ID;
there is no second mutable saved ability ID. Slot preference survives equal-effect
intermediate forms: HA Caterpie→Metapod→Butterfree retains hidden provenance,
even though every Metapod slot currently gives Shed Skin.

Codec5 explicitly migrates valid3/4 records to **deliberate Hardy/first/none
legacy defaults**. This is a chosen migration policy, not historical reconstruction.
Names, HP including0, XP, major status/sleep duration, chosen moves/PP, pending
learning and existing pending evolution remain exact. Codec3 still cannot contain
new evolution fields/reasons; Codec4 retains its existing evolution semantics.
Mixed old records carrying new attribute fields and malformed current records fail.
The nested Pokemon version changes; the session and SaveStore envelope stay1.
Evolution and debug level rebuilding preserve the new attributes and custom names.

## Source and generation

[specimen-sources.json](../../tools/references/specimen-sources.json) pins all10
new raw inputs. B2W2 personal binary/structure at PKHeX
`d2fea14b563f4b16fef7788b9699b20d5b3f410f` supplies76-byte rows and slots
0x18/0x19/0x1A. This yields151 rows,75 distinct normal IDs,61 hidden IDs and111
in their union. Gengar remains GenV Levitate. Primary B2W2 decompilation
`b279bbefa99bb2f6fbabcc95e4b6d3e939290353` supplies the25-nature ordering/signs
and independent nature generation. Pinned Showdown supplies an independent check
of all25 stat signs; pinned PokeAPI supplies ID/display dictionaries.

Primary [poke_tool.c](https://github.com/fuddlesworth/pokebw2/blob/b279bbefa99bb2f6fbabcc95e4b6d3e939290353/src/system/poke_tool.c)
stores nature independently, preserves slot provenance and applies nature after
the base stat. [ItemStorage5.cs](https://github.com/kwsch/PKHeX/blob/d2fea14b563f4b16fef7788b9699b20d5b3f410f/PKHeX.Core/Items/ItemStorage5.cs)
defines the GenV held whitelist as General+Medicine+Berry. Intersecting that with
Blue key/TM/HM exclusions gives124 catalog entries:49 holdable,75 nonholdable.
EXP.ALL remains distinct and nonholdable; it is not silently Exp. Share. GenV item
IDs in this metadata are separate from original Blue numericId; prices/display
rows stay unchanged. None and holdability validation work before ItemData import.

Generator writes only an explicit temporary candidate; `--check` is read-only:

```sh
python3 tools/generate_specimen_data.py \
  --cache /private/tmp/pokemon-specimen-attributes/references \
  --items-cache /private/tmp/pokemon-items-references \
  --output /private/tmp/specimenData-review.lua
```

Use `--fetch` only to fetch missing immutable inputs. Corrupt existing cache files
fail checksum validation and are preserved. The item cache uses the existing
[original item pins](../../tools/references/item-sources.json).

## Reproducible host qualification

Ordinary discovery runs synthetic schema/failure fixtures without references or
network. Those tests do not claim full source projection:

```sh
python3 -m unittest discover -s tools/tests -p test_specimen_generator.py -v
```

All6 pass, including source/fetch/cache/schema failures and nonzero drift checks.
Full primary qualification is a separate **required explicit-cache command**,
never a skipped test or an implicit `/repo/references` assumption:

```sh
python3 tools/qualify_specimen_data.py \
  --cache /private/tmp/pokemon-specimen-attributes/references \
  --items-cache /private/tmp/pokemon-items-references \
  --report /private/tmp/specimen-primary-report.json
```

This verifies every pin,151 rows/111 IDs,8 literal ability vectors,25 independent
nature comparisons, all124 item entries/49 holdable and exact production generated
data. Missing/corrupt inputs or drift return nonzero. Existing explicit execution
passed: `/private/tmp/pokemon-specimen-primary-qualification-01.json`.
A fresh checkout supplies its own cache directories, optionally using `--fetch`;
the `/private/tmp` paths above are current evidence conveniences, not defaults.

## Creation and RNG

`Specimen.create(species,level,origin,rng)` accepts explicit normal origins
wild/starter/trainer/gift/debug. It validates first, clones the real RNG snapshot,
rolls normal preference1..2 then independent nature0..24, constructs purely, and
commits only success. It never ordinarily rolls hidden or a held item. Receipts
record creation version1, origin,2 API draws and the actual underlying roll delta;
rejection sampling may take3 raw rolls. Native MAX-counter exhaustion is atomic.

Production Story starter/rival, authored trainer, debug and Zone creation sites
use the factory. TrainerEvents builds the entire detached team before committing
RNG/phase; Zone wraps species+level+attributes atomically. The separate step
encounter-chance roll is outside that generation transaction. Decode, evolution,
stat rebuilding, fixtures and drawing do not generate random attributes.
The proved ownership followup adds `Specimen.createForSession`: production
creators must own the actual active rules session. Trainer launch checks before
cloning/phase changes; Story/Debug callbacks retain session/visit ownership; failed
debug replacement checks party capacity before drawing. Production encounters
pass their owner before species/level draws. The low-level explicit-stream factory
and standalone sampler remain available for deterministic tools/tests. Real actor
contracts explicitly activate/restore their own session. No new GameSession or
SessionCodec fields were required, so the separate world-motion RNG remains disjoint.

## Handoff and native recipes

Frozen original packet `/private/tmp/pokemon-specimen-attributes` contains17
owned Source files, exact base/candidate SHA and narrow patches in
`foundation-manifest.json`. It was rebased onto root's provider/PC/Evolution and
midbattle fixture helper with no live worker Source edits. The separate
`/private/tmp/pokemon-specimen-attributes-followup-01` removes ordinary contracts'
private probe dependency. Root integrated that correction; ordinary main needs
no startup probe.

Import-order qualification belongs only to the explicit private validator. Its
separate `specimen-import-order` report checks real pre-ItemData constructor,
canonical nonholdability and no RNG. It is not part of ordinary461. Root alone
may execute the Simulator; default command compiles only:

```sh
python3 /private/tmp/pokemon-specimen-import-proof/validate_staged.py \
  --project "$PWD" --output /private/tmp/specimen-import-runtime-proof --execute
```

This proof copies current Source and modifies only its private main import point;
it overlays no stale phase1 files and registers only the extra probe group.
Compile-only qualification passed `/private/tmp/pokemon-specimen-import-build-01`;
SDK execution of that separate group remains pending root. Exact source SHA is
recorded. The Source packet, probe-only correction, portable host followup and
proved ownership repair remain separately reviewable.

Native recipes under `/private/tmp/pokemon-specimen-attributes/scenarios`:
`specimen-attributes-stats.json`, `specimen-factory-starter.json`, and actual
2-process `specimen-attributes-restart.json`. They assert independent nature/
slot/derived ID/held item, HP/status/PP and bag state, use real Party/Save/Continue
input, and capture unchanged native stats screens. They remain unexecuted until
root runs them. Fixture fields `nature_id`, `ability_slot`, `held_item` all validate
before reset, including a malformed late party member. Hidden fixture setup is
technical coverage, not player acquisition. Later phase2 adds visible trait/item
labels and atomic give/take; this phase does not claim that UI or battle effects.
