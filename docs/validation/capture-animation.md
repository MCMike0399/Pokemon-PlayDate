# Capture presentation candidate

The runtime candidate is staged under `/private/tmp/pokemon-capture-animation`; live Source has not been edited by this worker. Compilation passed in `/private/tmp/pokemon-capture-animation-build-01`. Actual SDK contracts and native image acceptance belong to the root Simulator owner and remain pending at handoff.

The new `CaptureAnimation` presents an existing rules receipt. It never invokes capture rules, consumes items, recruits Pokémon, advances battle scripts, or reads any RNG. `BattleScene` starts each receipt identity once in update; extra draw calls cannot advance it. Pending and active animation block input. Successful absorption hides the enemy through the caught message; a failed attempt restores the enemy after its breakout effect. Existing Pokémon sprites, platforms, coordinates, fonts and world art are unchanged.

## Original source and transformation

`tools/references/capture-animation.json` pins six files, SHA-256 hashes, immutable URLs and all nine generated images to pret/pokered revision `af519899719f0754965776faac0e836a3b906e6d`. The battle source is [move_anim_0.png](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/gfx/battle/move_anim_0.png), not the HUD ball icons. [Frame blocks](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/battle_anims/frame_blocks.asm) define the exact tile geometry and flips; [subanimations](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/battle_anims/subanimations.asm) and base coordinates supply throw/poof/shake poses. [TossBallAnimation](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/engine/battle/animations.asm) supplies toss → poof → hide → shake → breakout poof → show order. The source hides the Pokémon after the poof; there is no invented shrinking/redrawn Pokémon sprite.

The pinned grayscale sheet has shades 0/85/170/255. For the 1-bit screen, 0 and 85 become black, 170 becomes white, and original shade255 is transparent. This preserves opaque white detail separately from transparency. Original tile X/Y flips are applied exactly, followed by nearest-neighbor 2× scaling. Ultra/Master throw poses alternate the original palette exchange of shades85/170; their outline remains black. All four balls use the original common battle ball art. Poke uses the original high arc, Great the middle arc, Ultra/Master the low arc.

Original poses at60Hz are sampled at the game's30Hz: toss holds3/3/2 source frames, poof/shake holds4 source frames, and the pre-shake pause40 source frames. Source coordinates map between this scene's hand `(105,120)` and target `(340,60)`; this is a composition adaptation, not a claim of original device coordinates. A three-update drop connects the original throw/shake baseline change; caught settling holds10 updates. The generated poofs are64/80/96px and the closed ball32px. No global display translation or SDK timer is used.

Gen V receipt `displayShakes`, rather than Red/Blue's capture odds, controls visible shakes: normal0/1/3, critical1, guaranteed3. `checks` remains distinct from displayed shakes. Animation does not reroll or infer success from artwork.

## Root integration

Overlay only the `owned_files` in `foundation-manifest.json`. `battleScene.patch` is the narrow reviewable change against the recorded baseline. Add these owner hooks:

- In `BattleState:exit()`, call `if self.scene then self.scene:exit() end` before clearing its reference.
- Expose `battle.capture_animation = battleState.scene:getCaptureSnapshot()` in diagnostics.
- Import `dev/captureAnimationContracts` and register `Contracts.register("capture-animation", CaptureAnimationContracts.run)` in the dev registry.

`BattleScene` imports `battle/captureAnimation`, which imports its generated metadata. `getCaptureSnapshot()` returns a fresh `{phase,frame,done,shake}` table. Before the first update it reports `pending`, `done=false`; this avoids a stale completion observation between successive throws. Completed phases are `caught`/`escaped`; exit reports `closed` and prevents stale receipt restart. Other phases are `throw`, `absorb`, `drop`, `shake_wait`, `shake`, `breakout`. Scene exit cancels presentation, clears menus/selection state and resets the display offset to0.

The validator overlays only manifest-owned files onto the current checkout, adds those hooks in the private copy if absent, refreshes source/build fingerprints, and compiles by default. It never copies an old main.lua or invokes Simulator without explicit `--execute`.

```sh
python3 /private/tmp/pokemon-capture-animation/validate_staged.py --project "$PWD" --output /private/tmp/pokemon-capture-animation-review-01
# Root Simulator owner only:
python3 /private/tmp/pokemon-capture-animation/validate_staged.py --project "$PWD" --output /private/tmp/pokemon-capture-animation-sdk-01 --execute
python3 /private/tmp/pokemon-capture-animation/validate_staged.py --project "$PWD" --output /private/tmp/pokemon-capture-animation-native-01 --scenario /private/tmp/pokemon-capture-animation/scenarios/capture-animation-success.json --execute
```

Native companion scenarios `capture-animation-fail.json` and `capture-animation-three-shake-fail.json` cover immediate breakout and three-shake breakout. They assert early A leaves the throw text unchanged, the consumed ball count remains0 and rules rolls stay fixed, then await completion before advancing text. Shots/recordings cover actual throw, absorb, shake and breakout frames. Success uses Master Ball with zero RNG draws. Failure seed62594 consumes two draws and first shake roll49802; three-shake failure seed42 consumes four draws with rolls43918/23480/65270 (the independent capture vector). Native frame appearance still requires root inspection.

## Reproduction and checks

```sh
/private/tmp/pokemon-visual-venv/bin/python -m unittest tools.tests.test_capture_art -v
/private/tmp/pokemon-visual-venv/bin/python tools/generate_capture_art.py --reference-root /private/tmp/pokered-af519899719f0754965776faac0e836a3b906e6d --output-root /private/tmp/pokemon-capture-animation --check
```

Six host tests exercise literal ASM count/geometry/flag rejection, exact flips/palette/transparency/scaling, unknown shades, source corruption/path escape, staged-output restriction, and read-only check drift failures. The pinned complete asset regeneration/check passed. Thirteen SDK contract groups exercise0/1/3 normal and1 critical shake outcomes, source paths/flash, invalid receipts, one-shot detection, detached snapshots, controller blocking/resumption, repeated real scene drawing with unchanged battle/RNG, actual enemy draw suppression/restoration, and forced cleanup. These use real production classes and SDK images, without a replacement SDK. Compilation alone does not establish their runtime success.

The candidate does not add Safari capture behavior, new capture odds, ball-specific replacement artwork, recruitment animations or a general effect framework. The campaign remains unfinished.
