# Pinned Kanto content inventory and map-import feasibility

Research date: 2026-10-20. Reference: `pret/pokered` at **af519899719f0754965776faac0e836a3b906e6d**, the same immutable revision as the sprite-reference work. Product policy remains **English Blue world/content by default, original 151 species supported, project Gen V/B2W2 combat/stats/move policy preserved**. This document inventories the reference; it does not certify the current Playdate game implements it. Existing tuned Pallet and its interiors remain protected authored content. [Reference identity][readme], [project goal](../plans/astra-full-game-goal.md).

The paired machine-readable artifacts are [kanto-source.json](../../tools/references/kanto-source.json) (archive URL/hash and per-file source checksums) and [kanto-inventory.json](../../tools/references/kanto-inventory.json) (all map slots, headers/blocks, connections, object/warp/background declarations, symbolic script surfaces, parties, Blue wild slots, marts, HM/TM/evolution/trade/hidden-event manifests, music assignments, audio files, and decoded coordinate examples). Bulky source was extracted only under `/private/tmp`; no ROM was downloaded, built, or required. The source README identifies the target English Blue ROM checksum; that is a provenance identifier, not an executed comparison. [Reference identity][readme].

## What was enumerated, and what the counts mean

| Source-derived inventory | Count | Scope |
|---|---:|---|
| Map-ID slots | 248 | Includes 22 explicitly unused aliases and 4 named copy/alias slots |
| Ordinary named map slots | 222 | Includes Trade Center/Colosseum; does not mean 222 campaign destinations |
| Unique header files / unique object tables | 223 / 223 | Includes the separate UndergroundPathRoute7Copy table |
| Warps / background events | 805 / 201 | Count each unique source object table once |
| Declared NPC / ordinary trainer / item / static-Pokémon objects | 466 / 334 / 106 / 12 | Total 918 declarations; bosses/rivals/Snorlax and gifts may start battles/items in scripts instead |
| Trainer-party rows | 391 | Includes unused classes/rows; not a count of reachable trainer fights |
| Blue grass/water table files / selected nonempty slots | 59 / 570 | Ten weighted slots per nonempty table; fishing is separate |
| Mart inventories | 16 | Two labeled unused; vending/Game Corner are separate |
| Tileset header entries | 24 | Some share graphics/blocksets |
| Music source files / SFX source files | 46 / 323 | SFX include bank-specific copies; not 323 distinct audible effects |
| Hidden-item coordinate declarations / hidden coins / in-game trade rows | 54 / 12 / 10 | Includes inaccessible/unused entries; one trade row is labeled unused |

Counts come from declarative records at the pinned revision, not recollection or a wiki. See [map constants][maps], [header pointer order][pointers], [object macro encoding][macros], [trainer rows][parties], [wild tables][wild], [mart inventories][marts], and [audio assembly][audio]. The inventory resolves all 334 ordinary trainer-object class/index references into actual party rows and validates every map block ID against its tileset blockset. Both checks passed. The one layout-size discrepancy is `UNDERGROUND_PATH_NORTH_SOUTH`: declared **4×24 blocks**, actual `.blk` length **92 bytes = 4×23**; the source itself comments on it. An importer must report and explicitly resolve this exception rather than silently pad or read past the file. [Dimensions and source note][maps].

Extraction selects only the explicit `_BLUE` branch of `IF DEF(_RED)` / `IF DEF(_BLUE)` in declarative tables. It does **not** execute the assembler or interpret arbitrary Z80 control flow. Script entries list referenced event constants, script states and call targets; they are an audit index, not an inferred complete dependency graph. Original row/line references remain available in JSON. Battle parties use the source's uniform-level versus `$FF` per-mon-level encodings; neither is a Gen V stat or learnset oracle. [Party encoding][parties].

## Content and system matrix

This matrix covers the source's major content families and the systems they require. “Inventory captured” means the rows/source owners are indexed; it does not mean scripts, all special cases, implementation, or runtime acceptance are complete.

| Content/system | Reference owner and captured surface | Required native implementation / verification |
|---|---|---|
| World geography | All 248 slots; 223 headers and block layouts; outdoor connections; 24 tilesets; all warps and object coordinates | Declarative map definitions, collision/terrain semantics, seamless connection or explicit transition policy, facing/arrival, camera, stable IDs; preserve authored Pallet adapter |
| Signs, dialog, named NPCs | 201 background events, 466 NPC declarations, per-map text pointers/scripts | Text resources, names and choices, text timing, facing, counter interactions, one-shot callbacks, conditional visibility; parse every special text function before calling coverage complete |
| Ordinary trainers and bosses/rivals | 334 direct trainer objects resolved to 391 party rows; script flags/calls/states capture leaders and dynamic rival teams | Party battle support, money/prizes, sight/approach, defeat persistence, counter-pick branches, distinct victory/loss/run/capture outcomes and legal Gen V moves at each level |
| Grass/cave/water encounters | 59 table files, map pointer table, exact Blue slots and level/species; 256-total slot weights | Encounter-rate interpretation, terrain, level distributions, repel, Surf encounters, deterministic rules RNG; current flat 15% grass rule is not source equivalence |
| Fishing and Safari | Good/Super Rod tables, rod scripts; Safari maps, timer/step/ball state and special battle control flow | Old/Good/Super Rod choices and probabilities, bait/rock/flee/catch model, entrance payment, step/ball exhaustion, return, save/exit behavior |
| Visible and hidden items | 106 item objects, 54 hidden coordinate rows, 12 coin rows, separate hidden-event function tables | Bag capacity, stack limits, unique flags, Itemfinder, pickup failure/retry, hidden event ownership; not every hidden event is an item |
| Script gifts and key items | Scripts indexed for all event/call/state symbols; parcel, Pokédex, bicycle, rods, ticket, flute, keys, fossils, teeth, Coin Case, HMs | Item/quest transactions must be atomic, inventory-full paths must remain recoverable, event flags persistent; do not infer “gift succeeded” from reaching a text label |
| HM/TM and field moves | 50 TM + 5 HM definitions; five HMs and field move display data; badge gates in start submenu | Teach/forget/compatibility and Gen V move behavior policy; Cut/Surf/Strength mutate traversal consistently; Fly destination history; Flash, Dig, Teleport, Softboiled; make the chosen original TM locations and Gen V mechanics deliberate |
| Gyms/badges/obedience | Eight gym scripts, badge map table, trainer parties, battle obedience code | Leader gates/puzzles/rewards and badge flags; policy needed for original badge combat boosts/obedience versus project Gen V rules, without silently copying Gen I mechanics |
| Shops/money/economy | 14 used + 2 unused mart lists, prices, TM prices, vending prices, Game Corner prizes | Money/coins/caps, buy/sell quantity/capacity, stock, stones/vitamins/X items/repels, prize payments, discount-free original behavior; unused lists stay excluded unless approved |
| Healing/blackout | Center scripts and heal-party/set-blackout modules; Mom, Tower healing zone, Silph nurse and other script healing | Heal whole party/PP/status, stable checkpoint, original return/blackout money policy, preservation across ordinary battle exits; current one-mon blanket status clearing must be replaced deliberately |
| Storage/PC | Bills PC, player PC, Oak/League PC, hidden PC interactions | Party/storage transfer, release restrictions, full-box capture behavior, item storage, Hall of Fame history, naming and persistence; no invisible link-hardware dependency |
| Capture/evolution/learning/Pokédex | Capture item engine; 151 evolution/learnset records; TM/HM flags; trades/prizes/gifts; dex entries/cries | Gen V-compatible capture/status/evolution/level-aware learning policy, nicknames, seen/owned, cancel/retry, species support distinct from one-version obtainability |
| Menus/naming/options/save/continue | Menu modules, naming screen, save checksum/data logic, options, startup and Oak speech | Native menus, player/rival/Pokémon names, item/party/dex/options screens, versioned native save migration/corruption recovery; test isolated saves and resume every progression state |
| Transport and spatial puzzles | Cut/ledges, cycling road, Surf, elevators, spinner tables, warp pads/holes, card-key coordinates, boulder switches/currents | Directed movement, one-way geometry, cycling enforcement, elevator destination unlocks, atomic tile/collision/object changes, reset-on-leave versus persistent state per source |
| Endgame/postgame | Four Elite rooms, Champion, Hall of Fame/credits, Cerulean Cave and static legends | Consecutive party battles, loss/continue, rewards, record/save/credits/return, postgame gate; optional legends are not all postgame-only |
| Audio | Map music by slot, 46 music files, 323 bank-specific SFX files, cries and move-SFX manifest | Traceable synthesis/arrangement/playback pipeline, music transitions, channel/SFX priority, cries, low-HP and flute cues; no audio implementation or listening validation is claimed here |
| Link/exclusives/event scope | Trade Center/Colosseum slots; 10 NPC trade rows; trade-evolution records; Blue/Red encounter branches; Mew data | Explicit offline policies for version exclusives and trade evolution; preserve nine used NPC trades; event-only Mew availability remains a product decision, not an invented original encounter; online/link emulation is out of the default campaign dependency |

Primary owners beyond the data tables: [field move badge gates][field], [item behavior][items], [hidden events][hidden], [PC/storage][pc], [save][save], [healing][healing], [evolution/learning][evos], [NPC trades][trades], [credits][credits], [audio assembly][audio]. Gen I data establishes locations/characters/prerequisites, while the enhanced battle system must use its separately pinned Gen V references.

## Progression dependencies and concrete special cases

This is a dependency-oriented implementation sequence, not a claim that Kanto is a single strict linear path. Several gyms/branches can be visited in different orders; route graph reachability must ultimately be checked against actual blockers and party capabilities.

| Campaign stretch | Source-backed dependencies/rewards | Special systems and acceptance points |
|---|---|---|
| Pallet → Route 1 → Viridian → return to Oak | Starter/counter-pick; Mart parcel; `EVENT_GOT_OAKS_PARCEL`, `EVENT_OAK_GOT_PARCEL`, `EVENT_GOT_POKEDEX`; Route 1 Potion sample | Existing intro preserved; actual parcel return/dex transaction, empty/full bag paths, shop before/after parcel, old-man blocker/tutorial and optional Route 22 rival |
| Route 2 / Forest → Pewter → Route 3 / Mt. Moon | Brock/badge, route blocker, Forest trainers/items; fossils and Moon Stone branches | Capture/party/poison/blackout, ledges, trainers, fossil choice exclusivity; museum optional content remains in inventory |
| Cerulean / Routes 24–25 / Bill → Routes 5–6 → Vermilion | Rival/Nugget Bridge, Bill's cell-separator movement, S.S. Ticket; robbed-house Rocket/Dig; bicycle voucher | Scripted NPC movement + collision and reward retries; daycare and underground passage; optional Misty order is not forced by this table |
| S.S. Anne → Cut access; Diglett/Route 2 aide | Captain grants HM01; Route 2 aide grants HM05 with owned-species threshold | Cut field-use needs Cascade Badge; Flash needs Boulder Badge; ship departure and ticket/return semantics, all cabins and rivals; actual HM inventory/party capability required |
| Routes 9–10 / Rock Tunnel → Lavender / Celadon | Dark cave; Rocket Game Corner/Hideout, Lift Key, Giovanni → Silph Scope; Tower ghost/rescue → Poké Flute | Spinner floors/elevator/key, ghost identity/catch restrictions, Fuji rescue; sleeping Snorlax Route 12/16 routes need actual flute transaction |
| Celadon/Saffron/Fuchsia branches | Guard drink item clears Saffron guards; Silph Card Key/warp floors/rival/Giovanni/Master Ball; Safari Secret House HM03, Gold Teeth → Warden HM04 | Shops/vending/stones/prizes, Eevee, Dojo choice, Erika/Koga/Sabrina puzzles, cycling road; Surf needs Soul Badge, Strength Rainbow Badge; Saffron opens with the source drink list, not later-generation Tea |
| Surf branches / Seafoam / Cinnabar | Seafoam boulder/current puzzle; Mansion statue switches and Secret Key → Cinnabar Gym; fossil revival | Surf routes/Power Plant/Zapdos optional; Articuno/Moltres optional; quiz doors, fossil/Old Amber revival, Blaine; geography and event resets need dedicated tests |
| Viridian Gym → Route 22/23 → Victory Road | Giovanni/last badge, rival, eight badge checks; Victory Road boulder switches | Badge gates checked individually, surfing section, boulder reset semantics, Moltres; party healing/storage before League |
| Elite Four → Champion → Hall of Fame/credits | Four room scripts, starter-dependent Champion party; Hall of Fame hides the Cerulean Cave guard and saves/returns | Consecutive team battles, blackout reset, Hall of Fame history/credits + playable return, no false completion at Champion dialog |
| Original postgame | Cerulean Cave three floors, Mewtwo level 70; remaining legends/collection/optional trainers | Mewtwo flag is separate from ordinary trainers; cave guard removed by Hall of Fame script; repeat League records and all supported 151-species storage/evolution/learning; no invented Mew location |

Sources: [Viridian Mart parcel][parcel], [Oak lab state transitions][oak], [Bill and ticket][bill], [S.S. Anne Captain][cut], [Route 2 aide][flash], [Safari secret house][surf], [Warden][strength], [Saffron guard drink list][drinks], [Hall of Fame postgame gate/save][hof], and individual per-map script references in the inventory. Original HM field badge gates are **Cut=Cascade, Fly=Thunder, Surf=Soul, Strength=Rainbow, Flash=Boulder**. Their item gifts and field permission are distinct prerequisites. [Executable field permission checks][field].

Specific puzzle owners to audit before calling scripts complete: `VermilionGym` trash switches; `SaffronGym` warp pads; `RocketHideoutB2F/B3F` spinner paths and B4F dropped Lift Key; `SilphCo*` card-key doors/elevators/warp routing and nurse; `PokemonMansion*` statue switches/fall points; `SeafoamIslands*` boulder holes and currents; `VictoryRoad*` boulder-on-switch flags; `CinnabarGym` quiz/door states; `SafariZone*` timer/balls/return; `PokemonTower6F` ghost script. Map topology alone cannot reproduce these. Their owner scripts are pinned individually in [the source manifest](../../tools/references/kanto-source.json); each has its event/call/state index in the inventory.

## Exact coordinate and graphics transformation

An original **graphics tile is 8×8 pixels**. A `.bst` block definition stores **16 tile IDs**, row-major **4×4**: one original **32×32-pixel block**. A `.blk` byte selects one such block. Header/map constants measure these blocks. Player/object/warp/sign coordinates measure **16×16-pixel movement cells**, so each original block is **2×2 movement cells**, not one Playdate tile. The engine explicitly doubles header width/height into 2×2-tile movement dimensions. `DrawTileBlock` multiplies a block ID by 16 and writes four rows of four tile IDs. [Block expansion and dimensions][overworld], [object/warp encoding and header dimensions][macros].

Macro arguments are already unpadded source movement coordinates. The object
macro adds **4** to X/Y only in its encoded bytes for the original engine's
surrounding buffer; do not import that internal +4 as content padding. Warp
arguments are X,Y but encoded byte order is Y,X,warpIndex−1,map. Header arguments
name width/height through constants while encoded dimensions are height,width.
These are distinct schemas, not interchangeable arrays. [Encoding macros][macros].

The existing Playdate renderer takes one **16×16 authored grid** and emits one **32×32 image**; player grid coordinates are those 32-pixel cells. Therefore use **one original 16-pixel movement cell → one current 32-pixel cell**, composing its 2×2 original 8-pixel graphics tiles into a 16×16 grid before the existing renderer applies 2× output scaling/dither. One original block becomes a **64×64 Playdate area** containing four current cells. Do not map a whole original block into one current 32-pixel tile. [Current grid renderer](../../Source/world/tilefactory.lua), [current coordinates](../../Source/world/player.lua).

For source cell `(x,y)` and block width `Wb`:

```text
bx = floor(x/2); by = floor(y/2)
layoutOffset = by*Wb + bx
blockID = layout[layoutOffset]
qx = x mod 2; qy = y mod 2
cellTile[r][c] = blockset[blockID*16 + (2*qy+r)*4 + (2*qx+c)]  # r,c=0..1
originalPixel = (16*x,16*y)
playdatePixel = (32*(x+padX),32*(y+padY))
```

A future 2bpp decoder must read each 8-pixel row's low/high bitplanes, then `shade = lowBit + 2*highBit`, preserving the source shade ordering. The checked-in tileset PNGs are source graphics; `.2bpp` referenced by assembly is generated during the reference build. Pin and validate the PNG palette/value mapping rather than thresholding it by eye. Existing Playdate Shade LIGHT=12.5%-black and DARK=50%-black remains the accepted adaptation, not a request to rewrite existing art. No tileset pixels or Playdate asset were altered for this research. [Tileset graphic/blockset bindings][tilesets], [current shade](../../Source/lib/shade.lua).

### Route 1 decoded example

Route 1 header uses `OVERWORLD`, north connection Viridian offset `-5`, south Pallet offset `0`. Dimensions are **10×18 blocks = 20×36 movement cells = 320×576 original pixels = 640×1152 Playdate pixels** before any padding. Its sign is declared at movement cell **(9,27)**. That selects block `(4,13)`, `.blk` zero-based byte **134**, value **$08**; Overworld `.bst` bytes **128..143** are:

```text
39 39 39 39
39 39 39 39
39 39 46 47
39 39 56 57
```

The sign cell is the bottom-right quadrant: `46 47 / 56 57` (hex). Its original top-left pixel is **(144,432)**, Playdate **(288,864)** with no padding. Bottom-left tile `$56` is absent from Overworld's passable list, matching a solid sign. The sign background-event identity remains separate from terrain collision. The two NPC declarations are `(5,24)` and `(15,13)`; their routes/movement are also movement-cell values. [Header][route1header], [Route 1 objects][route1objects], [layout bytes][route1blocks], [Overworld blockset][overworldblocks], [passable lists][collision].

The Route 1 grass slots preserve level/species/order: `3 Pidgey, 3 Rattata, 3 Rattata, 2 Rattata, 2 Pidgey, 3 Pidgey, 3 Pidgey, 4 Rattata, 4 Pidgey, 5 Pidgey`. Slot weights are integer counts `[51,51,39,25,25,25,13,13,11,3]/256`, not ten equal chances. Source encounter rate byte is 25; the actual encounter routine must be inspected before treating that byte as a percentage. The Potion NPC is an event/inventory transaction, not an item object. [Route 1 encounters][route1wild], [slot weights][weights], [Potion transaction][route1script].

The two example records also contain full composed 16×16 `.12#` shade grids
and SHA-256 over 256 canonical shade bytes (0=white through 3=black), decoded
from the pinned 2-bit grayscale PNGs. Route 1 sign raster hash is
`f31adf65be1d1ec73c573d4aebaf0fda4270dbd58b6b286604a8af982b45a249`;
Red-house stairs is
`e420c633515349e4ad0dfa9fc00412d61348dced842795c20677b14ee5bf7dae`.
The limited research decoder checked PNG chunk CRCs and reconstructed PNG row
filters; independent upstream/Pillow decoding and visual review remain acceptance
checks before using these as generated assets. The reference build's tile
conversion rules use `rgbgfx --colors dmg`, followed by trailing-whitespace
trimming, with Red-house index `$48` preserved. No reference build was executed.
[Reference conversion rules](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/Makefile),
[trimming implementation](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/tools/gfx.c).

Connection offsets are in original block units: the macro multiplies them by two when computing movement-coordinate entry offsets. For north/south it computes `x = -2*offset`, so Route 1 north `-5` yields a ten-movement-cell lateral adjustment in that connection record. Respect the complete macro's border-strip and entry rules, including reciprocal maps; do not copy an offset directly as current-cell units. [Connection implementation][macros].

### Interior decoded example: Red's house 1F reference

Reference dimensions are **4×4 blocks = 8×8 movement cells = 128×128 original pixels = 256×256 Playdate pixels**. Stairs warp `(7,1)` targets `REDS_HOUSE_2F`, destination warp **1** (external IDs start at 1; encoded byte subtracts 1). `(7,1)` selects block `(3,0)`, layout byte **3**, value **$07**, `.bst` byte offset **112**:

```text
00 00 24 25
00 00 34 35
01 01 0c 0d
01 01 1c 1d
```

Selected bottom-right quadrant is `0c 0d / 1c 1d`; bottom-left `$1c` is in the shared Red-house passable list. Pixel origin is **(112,16)** original and **(224,32)** Playdate without padding. Two exit warps `(2,7)` and `(3,7)` target `LAST_MAP`, warp 1; this is dynamic “last outdoor map,” not a named immutable destination. Mom's source object is `(5,4)` and TV background interaction `(3,1)`. [Interior objects][redobjects], [layout][redblocks], [shared blockset][redblockset], [collision][collision], [warp encoding][macros].

The current tuned house stairs are `(9,2)` and its exits are `(2,7)/(3,7)`, so **the existing house is not a uniform translated copy** of this original interior. Preserve it. For newly imported small rooms, maintain explicit `contentOrigin` padding and transform **all** tiles/warps/objects/signs/scripts together; distinguish that adapter transform from source coordinates. Camera framing must be tested in 400×240, and return coordinates/facing must be explicit. [Current authored interiors](../../Source/data/maps.lua).

## Recommended pilot importer seam (proposal, not implemented)

Use a deep **MapSource module** whose small interface is `decode(mapId, sourcePin) -> MapDefinition + provenance + diagnostics`. It should own blockset/tile decoding, Blue condition selection, dimensions, event coordinates, connection metadata, stable source IDs, canonical species/item/trainer-name mapping (including
`MR_MIME`/`NIDORAN_F` versus current project IDs), and explicit unsupported
constructs. Return plain data; do not modify global game state during decoding. A second **WorldContent adapter** translates that definition into the current Zone/TileFactory/State ownership. The existing authored Pallet/interiors and pinned imported maps are two real adapters; preserve their difference rather than forcing a bulk rewrite. [Current Zone interface](../../Source/world/zone.lua), [current states](../../Source/game/overworldState.lua).

Pilot **Route 1 + a new Viridian Mart interior** before bulk generation. Route 1 exercises the outdoor blockset, grass, ledges, sign, moving NPC, sample item and north/south connection; Viridian Mart exercises counter talk, scripted parcel versus real inventory, dual exterior exit warps, and small-room framing. Keep source coordinate IDs unchanged in definitions; apply an explicit presentation padding transform at the adapter. Connect existing Pallet's accepted north gap through a deliberate authored seam, without regenerating Pallet. Existing Pallet has original-sized 20×18 cells but custom interior geography/trigger details; equal dimensions do not establish exact source identity.

Return hard diagnostics for missing palette/blockset references, layout-size mismatch, unknown script patterns, out-of-bounds events, unresolved `LAST_MAP`, invalid destination warp indices, inconsistent reciprocal connection alignment, and collision-changing mutations not supported atomically. Imported movement cells must carry source 2×2 tile composition plus terrain properties; current `CODES`/`SOLID` IDs cannot represent every original tileset solely by reusing visual IDs.

Acceptance before expansion: independently re-decode the two examples above; exact source-pixel/quadrant checks; source event-coordinate overlays; all walkable connectivity/ledge/direction checks; Route 1 north/south round trip with existing Pallet unchanged; parcel full-bag retry and shop transition; camera/padding/native 400×240 and motion review; deterministic regeneration/check-only; reject an injected wrong block byte, wrong warp index, missing shade, and altered collision probe. Then implement a small persistent event/transaction module before Tower/Silph/Safari/puzzle bulk content. Arbitrary assembly is a manual translation queue, not an unchecked generic script converter.

## Explicit unresolved work and provenance

The machine inventory is complete at the level of named source files/declarations described above. It is **not** complete interpretation of scripts, text functions, conditional object visibility, source graph reachability, fishing/Safari probability semantics, trainer AI, hidden-event handlers, music synthesis, or Gen V-compatible mechanics. Calls/events are indexed to make those audits finite. The map-count aliases, the short Underground layout, indirect scripts and `LAST_MAP` warps must be handled intentionally. No implementation-progress percentage or playability claim follows from these counts.

Species support and original availability are different. Blue encounter branches are selected in JSON; NPC trades, prizes, gifts, fossils, alternate starters, evolution and version exclusives need a complete obtainability graph before making a “151 obtainable offline” claim. The reference trade table has nine used entries plus one explicitly unused Butterfree→Beedrill row. Trade evolutions need an offline product policy; event-only Mew requires a declared policy and must not become a fabricated “original” wild encounter. Do not require nonexistent link hardware to finish the main campaign. [Trade records][trades], [evolution/learning records][evos], [project product policy](../plans/astra-full-game-goal.md).

The checkout identifies itself as a disassembly of Pokémon Red/Blue; no root license/COPYING file was present in this pinned archive. File checksums identify the material examined; they are not permission grants or a claim of independent art authorship. Reference art/text/music provenance and adaptation rights remain distinct from deterministic generation. New generated asset manifests should retain original source/revision/checksum and transformation steps. This research changes no protected art and does not establish provenance for the project's pre-existing Pokémon battle PNGs. [Reference README][readme], [existing audit](codebase-audit.md).

## Complete map listing

Dimensions below are **movement cells**, twice header block width/height. `W/B/O` means warp/background/object declarations in that map's unique object table. Direct trainer declarations are only part of battle content; inspect scripts for bosses/static/special battles. `UndergroundPathNorthSouth` retains its declared dimensions with the short-file exception noted above. All source paths, exact map IDs, tile IDs, script indices and complete event rows are in the JSON.

### Towns/cities

| ID | Map/header | Cells | Tileset | W/B/O |
|---|---|---|---|---|
| `$00` | PalletTown | 20×18 | OVERWORLD | 3/4/3 |
| `$01` | ViridianCity | 40×36 | OVERWORLD | 5/6/7 |
| `$02` | PewterCity | 40×36 | OVERWORLD | 7/7/5 |
| `$03` | CeruleanCity | 40×36 | OVERWORLD | 10/6/11 |
| `$04` | LavenderTown | 20×18 | OVERWORLD | 6/6/3 |
| `$05` | VermilionCity | 40×36 | OVERWORLD | 9/7/6 |
| `$06` | CeladonCity | 50×36 | OVERWORLD | 13/9/9 |
| `$07` | FuchsiaCity | 40×36 | OVERWORLD | 9/14/10 |
| `$08` | CinnabarIsland | 20×18 | OVERWORLD | 5/5/2 |
| `$09` | IndigoPlateau | 20×18 | PLATEAU | 2/0/0 |
| `$0a` | SaffronCity | 40×36 | OVERWORLD | 8/10/15 |

### Routes 1–25

| ID | Map/header | Cells | Tileset | W/B/O |
|---|---|---|---|---|
| `$0c` | Route1 | 20×36 | OVERWORLD | 0/1/2 |
| `$0d` | Route2 | 20×72 | OVERWORLD | 6/2/2 |
| `$0e` | Route3 | 70×18 | OVERWORLD | 0/1/9 |
| `$0f` | Route4 | 90×18 | OVERWORLD | 3/3/3 |
| `$10` | Route5 | 20×36 | OVERWORLD | 5/1/0 |
| `$11` | Route6 | 20×36 | OVERWORLD | 4/1/6 |
| `$12` | Route7 | 20×18 | OVERWORLD | 5/1/0 |
| `$13` | Route8 | 60×18 | OVERWORLD | 5/1/9 |
| `$14` | Route9 | 60×18 | OVERWORLD | 0/1/10 |
| `$15` | Route10 | 20×72 | OVERWORLD | 4/4/6 |
| `$16` | Route11 | 60×18 | OVERWORLD | 5/1/10 |
| `$17` | Route12 | 20×108 | OVERWORLD | 4/2/10 |
| `$18` | Route13 | 60×18 | OVERWORLD | 0/3/10 |
| `$19` | Route14 | 20×54 | OVERWORLD | 0/1/10 |
| `$1a` | Route15 | 60×18 | OVERWORLD | 4/1/11 |
| `$1b` | Route16 | 40×18 | OVERWORLD | 9/2/7 |
| `$1c` | Route17 | 20×144 | OVERWORLD | 0/6/10 |
| `$1d` | Route18 | 50×18 | OVERWORLD | 4/2/3 |
| `$1e` | Route19 | 20×54 | OVERWORLD | 0/1/10 |
| `$1f` | Route20 | 100×18 | OVERWORLD | 2/2/10 |
| `$20` | Route21 | 20×90 | OVERWORLD | 0/0/9 |
| `$21` | Route22 | 40×18 | OVERWORLD | 1/1/2 |
| `$22` | Route23 | 20×144 | PLATEAU | 4/1/7 |
| `$23` | Route24 | 20×36 | OVERWORLD | 0/0/8 |
| `$24` | Route25 | 60×18 | OVERWORLD | 1/1/10 |

### Interiors, dungeons and endgame rooms

| ID | Map/header | Cells | Tileset | W/B/O |
|---|---|---|---|---|
| `$25` | RedsHouse1F | 8×8 | REDS_HOUSE_1 | 3/1/1 |
| `$26` | RedsHouse2F | 8×8 | REDS_HOUSE_2 | 1/0/0 |
| `$27` | BluesHouse | 8×8 | HOUSE | 2/0/3 |
| `$28` | OaksLab | 10×12 | DOJO | 2/0/11 |
| `$29` | ViridianPokecenter | 14×8 | POKECENTER | 2/0/4 |
| `$2a` | ViridianMart | 8×8 | MART | 2/0/3 |
| `$2b` | ViridianSchoolHouse | 8×8 | HOUSE | 2/0/2 |
| `$2c` | ViridianNicknameHouse | 8×8 | HOUSE | 2/0/4 |
| `$2d` | ViridianGym | 20×18 | GYM | 2/0/11 |
| `$2e` | DiglettsCaveRoute2 | 8×8 | CAVERN | 3/0/1 |
| `$2f` | ViridianForestNorthGate | 10×8 | FOREST_GATE | 4/0/2 |
| `$30` | Route2TradeHouse | 8×8 | HOUSE | 2/0/2 |
| `$31` | Route2Gate | 10×8 | GATE | 4/0/2 |
| `$32` | ViridianForestSouthGate | 10×8 | FOREST_GATE | 4/0/2 |
| `$33` | ViridianForest | 34×48 | FOREST | 6/6/8 |
| `$34` | Museum1F | 20×8 | MUSEUM | 5/0/5 |
| `$35` | Museum2F | 14×8 | MUSEUM | 1/2/5 |
| `$36` | PewterGym | 10×14 | GYM | 2/0/3 |
| `$37` | PewterNidoranHouse | 8×8 | HOUSE | 2/0/3 |
| `$38` | PewterMart | 8×8 | MART | 2/0/3 |
| `$39` | PewterSpeechHouse | 8×8 | HOUSE | 2/0/2 |
| `$3a` | PewterPokecenter | 14×8 | POKECENTER | 2/0/4 |
| `$3b` | MtMoon1F | 40×36 | CAVERN | 5/1/13 |
| `$3c` | MtMoonB1F | 28×28 | CAVERN | 8/0/0 |
| `$3d` | MtMoonB2F | 40×36 | CAVERN | 4/0/9 |
| `$3e` | CeruleanTrashedHouse | 8×8 | HOUSE | 3/1/2 |
| `$3f` | CeruleanTradeHouse | 8×8 | HOUSE | 2/0/2 |
| `$40` | CeruleanPokecenter | 14×8 | POKECENTER | 2/0/4 |
| `$41` | CeruleanGym | 10×14 | GYM | 2/0/4 |
| `$42` | BikeShop | 8×8 | CLUB | 2/0/3 |
| `$43` | CeruleanMart | 8×8 | MART | 2/0/3 |
| `$44` | MtMoonPokecenter | 14×8 | POKECENTER | 2/0/6 |
| `$46` | Route5Gate | 8×6 | GATE | 4/0/1 |
| `$47` | UndergroundPathRoute5 | 8×8 | GATE | 3/0/1 |
| `$48` | Daycare | 8×8 | HOUSE | 2/0/1 |
| `$49` | Route6Gate | 8×6 | GATE | 4/0/1 |
| `$4a` | UndergroundPathRoute6 | 8×8 | GATE | 3/0/1 |
| `$4c` | Route7Gate | 6×8 | GATE | 4/0/1 |
| `$4d` | UndergroundPathRoute7 | 8×8 | GATE | 3/0/1 |
| `$4f` | Route8Gate | 6×8 | GATE | 4/0/1 |
| `$50` | UndergroundPathRoute8 | 8×8 | GATE | 3/0/1 |
| `$51` | RockTunnelPokecenter | 14×8 | POKECENTER | 2/0/4 |
| `$52` | RockTunnel1F | 40×36 | CAVERN | 8/1/7 |
| `$53` | PowerPlant | 40×36 | FACILITY | 3/0/14 |
| `$54` | Route11Gate1F | 8×10 | GATE | 5/0/1 |
| `$55` | DiglettsCaveRoute11 | 8×8 | CAVERN | 3/0/1 |
| `$56` | Route11Gate2F | 8×8 | GATE | 1/2/2 |
| `$57` | Route12Gate1F | 10×8 | GATE | 5/0/1 |
| `$58` | BillsHouse | 8×8 | INTERIOR | 2/0/3 |
| `$59` | VermilionPokecenter | 14×8 | POKECENTER | 2/0/4 |
| `$5a` | PokemonFanClub | 8×8 | INTERIOR | 2/2/6 |
| `$5b` | VermilionMart | 8×8 | MART | 2/0/3 |
| `$5c` | VermilionGym | 10×18 | GYM | 2/0/5 |
| `$5d` | VermilionPidgeyHouse | 8×8 | HOUSE | 2/0/3 |
| `$5e` | VermilionDock | 28×12 | SHIP_PORT | 2/0/0 |
| `$5f` | SSAnne1F | 40×18 | SHIP | 11/0/2 |
| `$60` | SSAnne2F | 40×18 | SHIP | 9/0/2 |
| `$61` | SSAnne3F | 20×6 | SHIP | 2/0/1 |
| `$62` | SSAnneB1F | 30×8 | SHIP | 6/0/0 |
| `$63` | SSAnneBow | 20×14 | SHIP | 2/0/5 |
| `$64` | SSAnneKitchen | 14×16 | SHIP | 1/0/7 |
| `$65` | SSAnneCaptainsRoom | 6×8 | SHIP | 1/2/1 |
| `$66` | SSAnne1FRooms | 24×16 | SHIP | 6/0/11 |
| `$67` | SSAnne2FRooms | 24×16 | SHIP | 12/0/13 |
| `$68` | SSAnneB1FRooms | 24×16 | SHIP | 10/0/11 |
| `$6c` | VictoryRoad1F | 20×18 | CAVERN | 3/0/7 |
| `$71` | LancesRoom | 26×26 | DOJO | 3/0/1 |
| `$76` | HallOfFame | 10×8 | GYM | 2/0/1 |
| `$77` | UndergroundPathNorthSouth | 8×48 | UNDERGROUND | 2/0/0 |
| `$78` | ChampionsRoom | 8×8 | GYM | 4/0/2 |
| `$79` | UndergroundPathWestEast | 50×8 | UNDERGROUND | 2/0/0 |
| `$7a` | CeladonMart1F | 20×8 | LOBBY | 6/2/1 |
| `$7b` | CeladonMart2F | 20×8 | LOBBY | 3/1/4 |
| `$7c` | CeladonMart3F | 20×8 | LOBBY | 3/12/5 |
| `$7d` | CeladonMart4F | 20×8 | LOBBY | 3/1/3 |
| `$7e` | CeladonMartRoof | 20×8 | LOBBY | 1/4/2 |
| `$7f` | CeladonMartElevator | 4×4 | LOBBY | 2/1/0 |
| `$80` | CeladonMansion1F | 8×12 | MANSION | 5/1/4 |
| `$81` | CeladonMansion2F | 8×12 | MANSION | 4/1/0 |
| `$82` | CeladonMansion3F | 8×12 | MANSION | 4/4/4 |
| `$83` | CeladonMansionRoof | 8×12 | MANSION | 3/1/0 |
| `$84` | CeladonMansionRoofHouse | 8×8 | HOUSE | 2/0/2 |
| `$85` | CeladonPokecenter | 14×8 | POKECENTER | 2/0/4 |
| `$86` | CeladonGym | 10×18 | GYM | 2/0/8 |
| `$87` | GameCorner | 20×18 | LOBBY | 3/1/11 |
| `$88` | CeladonMart5F | 20×8 | LOBBY | 3/1/4 |
| `$89` | GameCornerPrizeRoom | 10×8 | LOBBY | 2/3/2 |
| `$8a` | CeladonDiner | 10×8 | LOBBY | 2/0/5 |
| `$8b` | CeladonChiefHouse | 8×8 | MANSION | 2/0/3 |
| `$8c` | CeladonHotel | 14×8 | POKECENTER | 2/0/3 |
| `$8d` | LavenderPokecenter | 14×8 | POKECENTER | 2/0/4 |
| `$8e` | PokemonTower1F | 20×18 | CEMETERY | 3/0/5 |
| `$8f` | PokemonTower2F | 20×18 | CEMETERY | 2/0/2 |
| `$90` | PokemonTower3F | 20×18 | CEMETERY | 2/0/4 |
| `$91` | PokemonTower4F | 20×18 | CEMETERY | 2/0/6 |
| `$92` | PokemonTower5F | 20×18 | CEMETERY | 2/0/6 |
| `$93` | PokemonTower6F | 20×18 | CEMETERY | 2/0/5 |
| `$94` | PokemonTower7F | 20×18 | CEMETERY | 1/0/4 |
| `$95` | MrFujisHouse | 8×8 | HOUSE | 2/0/6 |
| `$96` | LavenderMart | 8×8 | MART | 2/0/3 |
| `$97` | LavenderCuboneHouse | 8×8 | HOUSE | 2/0/2 |
| `$98` | FuchsiaMart | 8×8 | MART | 2/0/3 |
| `$99` | FuchsiaBillsGrandpasHouse | 8×8 | HOUSE | 2/0/3 |
| `$9a` | FuchsiaPokecenter | 14×8 | POKECENTER | 2/0/4 |
| `$9b` | WardensHouse | 10×8 | LAB | 2/2/3 |
| `$9c` | SafariZoneGate | 8×6 | GATE | 4/0/2 |
| `$9d` | FuchsiaGym | 10×18 | GYM | 2/0/8 |
| `$9e` | FuchsiaMeetingRoom | 14×8 | LAB | 2/0/3 |
| `$9f` | SeafoamIslandsB1F | 30×18 | CAVERN | 7/0/2 |
| `$a0` | SeafoamIslandsB2F | 30×18 | CAVERN | 7/0/2 |
| `$a1` | SeafoamIslandsB3F | 30×18 | CAVERN | 7/0/6 |
| `$a2` | SeafoamIslandsB4F | 30×18 | CAVERN | 4/2/3 |
| `$a3` | VermilionOldRodHouse | 8×8 | HOUSE | 2/0/1 |
| `$a4` | FuchsiaGoodRodHouse | 8×8 | SHIP | 3/0/1 |
| `$a5` | PokemonMansion1F | 30×28 | FACILITY | 8/0/3 |
| `$a6` | CinnabarGym | 20×18 | FACILITY | 2/0/9 |
| `$a7` | CinnabarLab | 18×8 | LAB | 5/4/1 |
| `$a8` | CinnabarLabTradeRoom | 8×8 | LAB | 2/0/3 |
| `$a9` | CinnabarLabMetronomeRoom | 8×8 | LAB | 2/3/2 |
| `$aa` | CinnabarLabFossilRoom | 8×8 | LAB | 2/0/2 |
| `$ab` | CinnabarPokecenter | 14×8 | POKECENTER | 2/0/4 |
| `$ac` | CinnabarMart | 8×8 | MART | 2/0/3 |
| `$ae` | IndigoPlateauLobby | 16×12 | MART | 3/0/5 |
| `$af` | CopycatsHouse1F | 8×8 | REDS_HOUSE_1 | 3/0/3 |
| `$b0` | CopycatsHouse2F | 8×8 | REDS_HOUSE_2 | 1/2/5 |
| `$b1` | FightingDojo | 10×12 | DOJO | 2/0/7 |
| `$b2` | SaffronGym | 20×18 | FACILITY | 32/0/9 |
| `$b3` | SaffronPidgeyHouse | 8×8 | HOUSE | 2/0/4 |
| `$b4` | SaffronMart | 8×8 | MART | 2/0/3 |
| `$b5` | SilphCo1F | 30×18 | FACILITY | 5/0/1 |
| `$b6` | SaffronPokecenter | 14×8 | POKECENTER | 2/0/4 |
| `$b7` | MrPsychicsHouse | 8×8 | HOUSE | 2/0/1 |
| `$b8` | Route15Gate1F | 8×10 | GATE | 5/0/1 |
| `$b9` | Route15Gate2F | 8×8 | GATE | 1/1/1 |
| `$ba` | Route16Gate1F | 8×14 | GATE | 9/0/2 |
| `$bb` | Route16Gate2F | 8×8 | GATE | 1/2/2 |
| `$bc` | Route16FlyHouse | 8×8 | HOUSE | 2/0/2 |
| `$bd` | Route12SuperRodHouse | 8×8 | HOUSE | 2/0/1 |
| `$be` | Route18Gate1F | 8×10 | GATE | 5/0/1 |
| `$bf` | Route18Gate2F | 8×8 | GATE | 1/2/1 |
| `$c0` | SeafoamIslands1F | 30×18 | CAVERN | 7/0/2 |
| `$c1` | Route22Gate | 10×8 | GATE | 4/0/1 |
| `$c2` | VictoryRoad2F | 30×18 | CAVERN | 7/0/13 |
| `$c3` | Route12Gate2F | 8×8 | GATE | 1/2/1 |
| `$c4` | VermilionTradeHouse | 8×8 | HOUSE | 2/0/1 |
| `$c5` | DiglettsCave | 40×36 | CAVERN | 2/0/0 |
| `$c6` | VictoryRoad3F | 30×18 | CAVERN | 4/0/10 |
| `$c7` | RocketHideoutB1F | 30×28 | FACILITY | 5/0/7 |
| `$c8` | RocketHideoutB2F | 30×28 | FACILITY | 5/0/5 |
| `$c9` | RocketHideoutB3F | 30×28 | FACILITY | 2/0/4 |
| `$ca` | RocketHideoutB4F | 30×24 | FACILITY | 3/0/9 |
| `$cb` | RocketHideoutElevator | 6×8 | LOBBY | 2/1/0 |
| `$cf` | SilphCo2F | 30×18 | FACILITY | 7/0/5 |
| `$d0` | SilphCo3F | 30×18 | FACILITY | 10/0/4 |
| `$d1` | SilphCo4F | 30×18 | FACILITY | 7/0/7 |
| `$d2` | SilphCo5F | 30×18 | FACILITY | 7/0/11 |
| `$d3` | SilphCo6F | 26×18 | FACILITY | 5/0/10 |
| `$d4` | SilphCo7F | 26×18 | FACILITY | 6/0/11 |
| `$d5` | SilphCo8F | 26×18 | FACILITY | 7/0/4 |
| `$d6` | PokemonMansion2F | 30×28 | FACILITY | 4/0/4 |
| `$d7` | PokemonMansion3F | 30×18 | FACILITY | 3/0/5 |
| `$d8` | PokemonMansionB1F | 30×28 | FACILITY | 1/0/8 |
| `$d9` | SafariZoneEast | 30×26 | FOREST | 5/3/4 |
| `$da` | SafariZoneNorth | 40×36 | FOREST | 9/5/2 |
| `$db` | SafariZoneWest | 30×26 | FOREST | 8/4/4 |
| `$dc` | SafariZoneCenter | 30×26 | FOREST | 9/2/1 |
| `$dd` | SafariZoneCenterRestHouse | 8×8 | GATE | 2/0/2 |
| `$de` | SafariZoneSecretHouse | 8×8 | LAB | 2/0/1 |
| `$df` | SafariZoneWestRestHouse | 8×8 | GATE | 2/0/3 |
| `$e0` | SafariZoneEastRestHouse | 8×8 | GATE | 2/0/3 |
| `$e1` | SafariZoneNorthRestHouse | 8×8 | GATE | 2/0/3 |
| `$e2` | CeruleanCave2F | 30×18 | CAVERN | 6/0/3 |
| `$e3` | CeruleanCaveB1F | 30×18 | CAVERN | 1/0/3 |
| `$e4` | CeruleanCave1F | 30×18 | CAVERN | 9/0/3 |
| `$e5` | NameRatersHouse | 8×8 | HOUSE | 2/0/1 |
| `$e6` | CeruleanBadgeHouse | 8×8 | SHIP | 3/0/1 |
| `$e8` | RockTunnelB1F | 40×36 | CAVERN | 4/0/8 |
| `$e9` | SilphCo9F | 26×18 | FACILITY | 5/0/4 |
| `$ea` | SilphCo10F | 16×18 | FACILITY | 6/0/6 |
| `$eb` | SilphCo11F | 18×18 | INTERIOR | 4/0/5 |
| `$ec` | SilphCoElevator | 4×4 | LOBBY | 2/1/0 |
| `$ef` | TradeCenter | 10×8 | CLUB | 0/0/1 |
| `$f0` | Colosseum | 10×8 | CLUB | 0/0/1 |
| `$f5` | LoreleisRoom | 10×12 | GYM | 4/0/1 |
| `$f6` | BrunosRoom | 10×12 | GYM | 4/0/1 |
| `$f7` | AgathasRoom | 10×12 | CEMETERY | 4/0/1 |

### Aliases and unused slots (not additional campaign maps)

| ID | Slot | Header pointer | Kind |
|---|---|---|---|
| `$0b` | UNUSED_MAP_0B | SaffronCity | unused_alias |
| `$45` | CERULEAN_TRASHED_HOUSE_COPY | CeruleanTrashedHouse | copy_or_alias |
| `$4b` | UNDERGROUND_PATH_ROUTE_6_COPY | UndergroundPathRoute6 | copy_or_alias |
| `$4e` | UNDERGROUND_PATH_ROUTE_7_COPY | UndergroundPathRoute7Copy | copy_or_alias |
| `$69` | UNUSED_MAP_69 | LancesRoom | unused_alias |
| `$6a` | UNUSED_MAP_6A | LancesRoom | unused_alias |
| `$6b` | UNUSED_MAP_6B | LancesRoom | unused_alias |
| `$6d` | UNUSED_MAP_6D | LancesRoom | unused_alias |
| `$6e` | UNUSED_MAP_6E | LancesRoom | unused_alias |
| `$6f` | UNUSED_MAP_6F | LancesRoom | unused_alias |
| `$70` | UNUSED_MAP_70 | LancesRoom | unused_alias |
| `$72` | UNUSED_MAP_72 | LancesRoom | unused_alias |
| `$73` | UNUSED_MAP_73 | LancesRoom | unused_alias |
| `$74` | UNUSED_MAP_74 | LancesRoom | unused_alias |
| `$75` | UNUSED_MAP_75 | LancesRoom | unused_alias |
| `$ad` | CINNABAR_MART_COPY | CinnabarMart | copy_or_alias |
| `$cc` | UNUSED_MAP_CC | RocketHideoutElevator | unused_alias |
| `$cd` | UNUSED_MAP_CD | RocketHideoutElevator | unused_alias |
| `$ce` | UNUSED_MAP_CE | RocketHideoutElevator | unused_alias |
| `$e7` | UNUSED_MAP_E7 | Route16Gate1F | unused_alias |
| `$ed` | UNUSED_MAP_ED | SilphCo2F | unused_alias |
| `$ee` | UNUSED_MAP_EE | SilphCo2F | unused_alias |
| `$f1` | UNUSED_MAP_F1 | SilphCo2F | unused_alias |
| `$f2` | UNUSED_MAP_F2 | SilphCo2F | unused_alias |
| `$f3` | UNUSED_MAP_F3 | SilphCo2F | unused_alias |
| `$f4` | UNUSED_MAP_F4 | SilphCo2F | unused_alias |

[readme]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/README.md
[maps]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/constants/map_constants.asm
[pointers]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/maps/map_header_pointers.asm
[macros]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/macros/scripts/maps.asm
[parties]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/trainers/parties.asm
[wild]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/wild/grass_water.asm
[marts]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/items/marts.asm
[audio]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/audio.asm
[field]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/engine/menus/start_sub_menus.asm
[items]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/engine/items/item_effects.asm
[hidden]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/events/hidden_events.asm
[pc]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/engine/pokemon/bills_pc.asm
[save]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/engine/menus/save.asm
[healing]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/engine/events/heal_party.asm
[evos]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/pokemon/evos_moves.asm
[trades]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/events/trades.asm
[credits]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/engine/movie/credits.asm
[parcel]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/scripts/ViridianMart.asm
[oak]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/scripts/OaksLab.asm
[bill]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/scripts/BillsHouse.asm
[cut]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/scripts/SSAnneCaptainsRoom.asm
[flash]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/scripts/Route2Gate.asm
[surf]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/scripts/SafariZoneSecretHouse.asm
[strength]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/scripts/WardensHouse.asm
[drinks]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/items/guard_drink_items.asm
[hof]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/scripts/HallOfFame.asm
[overworld]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/home/overworld.asm
[tilesets]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/gfx/tilesets.asm
[route1header]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/maps/headers/Route1.asm
[route1objects]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/maps/objects/Route1.asm
[route1blocks]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/maps/Route1.blk
[overworldblocks]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/gfx/blocksets/overworld.bst
[collision]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/tilesets/collision_tile_ids.asm
[route1wild]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/wild/maps/Route1.asm
[weights]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/wild/probabilities.asm
[route1script]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/scripts/Route1.asm
[redobjects]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/maps/objects/RedsHouse1F.asm
[redblocks]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/maps/RedsHouse1F.blk
[redblockset]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/gfx/blocksets/reds_house.bst
