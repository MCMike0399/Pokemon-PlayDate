# Portable original jump/shadow source checker

`tools/generate_jump_art.py` replaces dependence on a temporary staging script. It reads `tools/references/jump-art.json`, verifies all seven immutable pokered inputs, derives the original16 vertical samples and four mirrored shadow quarters, and exactly reproduces the accepted `Source/data/kantoJump.lua`. It never downloads unpinned content or writes live Source.

The pin is pret/pokered revision `af519899719f0754965776faac0e836a3b906e6d`. The manifest preserves the traversal worker's SHA256 values for:

- `engine/overworld/player_animations.asm` — original jump samples;
- `engine/overworld/ledges.asm` — four original shadow OAM flip combinations;
- `gfx/overworld/shadow.png` — original8x8 mode1 black/white quarter;
- `home/oam.asm`, `engine/gfx/sprite_oam.asm`, `home/overworld.asm`, `engine/overworld/auto_movement.asm` — pinned provenance context.

The generator parses the first three inputs; all seven checksums are mandatory. It does not claim to execute the original assembly engine. The exact local source data currently reproduces SHA256 `44d91193792baba192f0fb6c393542a173f8f7af91058024355ff9c4a6ca1c8d`.

```sh
python tools/generate_jump_art.py --reference-root PINNED_POKERED --check Source/data/kantoJump.lua --report /private/tmp/jump-source.json
```

Use the project's pinned Pillow environment. `--output NEW_CANDIDATE.lua` is an explicit alternative that creates a new file exclusively; an existing file, live Source path, or path under pinned inputs is rejected. `--check` is read-only and fails on any byte difference. Originals and reviewed baselines are never regenerated to make a failure pass.

Original samples are `56,54,52,50,49,48,48,48,49,50,51,52,54,56,60,60`; native offsets are `(sourceY-60)*2`, peaking at24 pixels above ground. Existing runtime adaptation remains16 native updates at30FPS across two ordinary cells, with the original quarter shadow mirrored in X/Y, then2x native pixels. The shadow's standing-top offset remains16 native pixels. No movement/rules/RED artwork changed in this task.

## Exact native shadow check plan

Root's accepted actual-Player traversal contract already exports `frames/jump-shadow.png` from the real `player.jumpShadow:getImage()` after executing all16 updates. After root's run completes and its normal quiescent publication barrier is confirmed, compare the retained artifact:

```sh
python tools/generate_jump_art.py --reference-root PINNED_POKERED --check Source/data/kantoJump.lua --native-image RUN_ROOT/frames/jump-shadow.png --report /private/tmp/jump-native.json
```

The checker independently assembles original source quarters, applies the production border-white opacity rule and2x mapping, then compares decoded RGBA exactly. Invisible RGB is included; changed RGB pixels, alpha pixels and bounding box are reported separately. No threshold or approximate mask acceptance exists. An optional root-only SDK export of that **same actual image's** `getMaskImage()` can be supplied as `--native-mask RUN_ROOT/frames/jump-shadow__mask.png`; this checks standalone mask bitmap pixels too. Do not substitute an independently regenerated SDK sprite for the owned Player's actual shadow instance.

Asset equality does not prove placement/cadence. After production registers the four-map slice, root should use the genuine Route1 ledge at `(4,4)`, press DOWN once, and record18 frames to include input, all16 updates and settled landing at `(4,6)`. Inspect source offsets and the grounded shadow separately from RED's raised body; compare source sample checkpoints including the24-pixel peak and final hidden shadow. Existing traversal contracts assert actual Player positions, source offsets, ground-based camera center, two-cell landing, and blocking on reverse approach. Root owns native screenshots/motion inspection and any extra read-only diagnostic fields; worker did not launch Simulator or read active Data.

The comprehensive catalog does not yet expose the private jump-shadow getter; treat raw/mask/background additions as unreviewed until root adds the explicit actual-image accessor/export and inspects them. Do not silently add the shadow to the previously reviewed915 baseline or the separately staged event inventory counts.

## Host verification

Eight tests passed with the pinned source tree: source16-sample curve; all four mirror quadrants/native opacity; invalid OAM transforms; controlled one-pixel standalone mask, alpha and invisible-RGB failures with counts/bbox; dimensions; required seven-pin schema; rejected live-Source/reference writes and existing candidate overwrite; exact checked-in Lua reproduction; and changed primary-source checksum rejection. Source-dependent tests explicitly skip if the reference tree is not supplied.

```sh
POKERED_REFERENCE_DIR=PINNED_POKERED python -m unittest tools.tests.test_jump_art -q
```

Worker result: deterministic source data matches current accepted Lua exactly. Actual native shadow comparison and motion review remain root execution steps; no optimization or Source migration is implied.
