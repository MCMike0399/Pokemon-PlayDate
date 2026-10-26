# Tutorial and escort source family

All inputs are pinned to English Blue `pret/pokered`
`af519899719f0754965776faac0e836a3b906e6d`. The 17 SHA-256 entries in
`tools/references/tutorial-escort.json` cover the vendored actual map scripts,
objects, text, movement decoder/consumer, battle/item tutorial branches, and art.
The local reference checkout was read through the project env script; no ROM is
used. Inputs are under `tools/references/tutorial-escort/`.

Reproduce only the new output:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python -m tools.generate_tutorial_escort --check
python -m unittest tools.tests.test_tutorial_escort -v
```

Without `--check`, the generator writes only
`Source/data/tutorialEscort/scenes.json`. It validates all input checksums first.
It transcribes opaque source grayscale pixels directly as `.12#` grids and
records source paths and dimensions. New runtime images use explicit phase `(0,0)`
through the existing TileFactory; new NPC review frames use SpriteFactory's
existing border flood-fill mask. No RED, BLUE, Oak, Pallet or existing shared NPC
mapping is regenerated or replaced.

Art family: `gfx/battle/oldmanb.png`, `gfx/pokemon/front/weedle.png`, and original
`youngster`, `gambler`, `gambler_asleep` overworld strips. The scene's actual guide
uses the existing source SPRITE_YOUNGSTER resolver through NPCMotion's eight-frame
steps. `TutorialDemoArt.actorFrame(name,index)` makes the new strip records available
for native review without installing a shared sprite mapping. Battle art uses
source rows, split into TileFactory-sized blocks at render time; original native
geometry is scaled 2x. No hand-drawn scene art is included.

Source text recipes retain labels, control instructions and source line numbers;
EventText expands and reflows them through existing production pagination.
`PewterGymGuyCoords` and `RLEList_PewterGymPlayer` are consumed as LIFO player data;
`RLEList_PewterGymGuy` and departure movement are forward NPC data. The independent
host oracle checks all five player endpoint routes, but actual native reservations,
interpolation and visible composition remain root acceptance work.
