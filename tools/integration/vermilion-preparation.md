# Private Vermilion content preparation

Branch `wip/vermilion-content` starts exactly at
`c6882b696fa9e0b8b4f43e7bb46fffacceeb11f6` (including the standard 14×8
Center healing composition). The initial T3 branch was divergent; it is preserved,
and the isolated implementation branch was created directly at the requested
base. This is NEXT milestone 5.4 preparation only. No activation, main acceptance,
Simulator run, push, delegation, coverage refresh or protected baseline change.

## Concrete batch and family provenance

`Source/data/vermilionPreparation/` contains 35 decoded source maps, 85 ordinary
object descriptors, 14 sign descriptors, 37 direct object roster definitions,
complete Rival1/Rival2 class rosters, 34 immutable NPC strips and 630 text recipes.
The shared text-bank superset includes the aide/trade/service resources; storing
those recipes does not register their interactions. `reservations.json` accounts
for every remaining object/sign, with exact stable IDs, pointer-owned text labels,
source flag symbols and roster references. Its 29 reservations are disjoint from
the ordinary descriptor IDs. `scripts.json` retains source programs, pointer maps,
hidden-event positions and explicit gaps; source programs are never interpreted.

The 35 maps are Route5/Route5Gate/Daycare, both underground entrances and the
north–south tunnel, Route6/Route6Gate, Vermilion City/Center/Mart/Fan Club/Old Rod
house/Pidgey house/trade house/dock/Gym, all ten S.S. Anne maps (1F, 2F, 3F, B1F,
Bow, Kitchen, Captain and all three combined cabin maps), DiglettsCave and both
Route2/11 entrances, Route2Gate/Route2TradeHouse, Route11 and both gate floors.
Cabin maps retain all their original individual room warps; they are not one
representative cabin. Boundaries toward later Saffron/Route12 geography remain
unavailable and need their own content packet.

All 261 consumed inputs are SHA-256 pinned against immutable pokered revision
`af519899719f0754965776faac0e836a3b906e6d` in
`tools/references/vermilion-preparation.json`. This includes actual tilesheet and
NPC PNGs, blocks/blocksets, collision, objects/warps, connections, Blue encounters,
trainer tables, music symbols/bank expressions and text/control programs.
`provenance.json` hashes the artifacts and all four shared generator dependencies.

Terrain is decoded by `generate_kanto_maps.decode_map`; candidate metadata and
tile grids are built by `generate_source_map_cache.build`. There is no regional
geometry factory/provider/renderer. Independent host checks use original layout
and blockset indexing, Pillow pixels, source collision lists, object/header/music
records, a separate party parser and explicitly selected Blue wild declarations.
Every old tracked Source file (including all protected art) equals the exact base.
Source PNG agreement is not native visual acceptance.

Raw NPC strips preserve all four shades through the existing immutable converter.
The supplied resolver patch retains the existing `CeruleanContent` source actor
owner, key namespace, mask and phase policy. Canonical BLUE standing images still
come from `SpriteFactory.npc.rival`; BLUE additive walk frames still use greyhair
and the omitted-phase renderer. Other source NPCs retain explicit phase `(0,0)`.
No RED/Oak/Mom/Daisy grid is reimported, regenerated or edited. All existing
production Lua is unchanged; the proposed resolver edit is an unapplied patch.

### Underground layout exception

The north–south header declares 4×24 blocks, but its file contains only 92 bytes
(4×23). Pinned `maps.asm` lines 979–980 place the west–east INCBIN immediately
following it, within the same ROMX section. Opt-in `linked_layout_tail` on the
existing shared decoder verifies exactly consecutive declarations, the exact
missing byte count and pinned tail file, then consumes its first four bytes.
`layout_extent` records the span. This reproduces the declared source extent;
it does not fabricate a wall row, crop dimensions, pad a file or silently consume
unbounded adjacent bytes. It is source-declaration evidence, not a linked-ROM
comparison. The default decoder still rejects this short layout; wrong tail
files/counts and changed pinned bytes fail host checks.

## Reserved ownership and limits

The following IDs are deliberately absent from ordinary event registration:

| Owner / next packet | Exact reserved object ID | Source contract |
|---|---|---|
| Scene worker | `pokered:SS_ANNE_2F:objects:2` | Object OPP_RIVAL1/1 is only a placeholder. Script uses OPP_RIVAL2 rows 1/2/3 according to rival starter; all classes/rows are retained. |
| Scene worker | `pokered:SS_ANNE_CAPTAINS_ROOM:objects:1` | Captain, HM01 and departure prerequisites. |
| Scene worker | `pokered:VERMILION_CITY:objects:3` | Sailor boarding/Ticket guard and ship departure state. Dock script is retained separately. |
| Scene worker | `pokered:VERMILION_GYM:objects:1` | Surge: Voltorb21/Pikachu18/Raichu24; Thunder Badge/TM24 and trash switches remain unimplemented here. |
| Ordinary quest packet | `pokered:POKEMON_FAN_CLUB:objects:5` | Voucher choice, bike/voucher checks, capacity retry, `EVENT_GOT_BIKE_VOUCHER`; exact chairman text labels retained. |
| Ordinary quest packet | `pokered:VERMILION_OLD_ROD_HOUSE:objects:1` | Old Rod choice/retry; source uses `wStatusFlags1.BIT_GOT_OLD_ROD`, not an invented event flag. |
| Ordinary quest packet | `pokered:ROUTE_2_GATE:objects:1` | HM05, 10 owned species, `EVENT_GOT_HM05`; shared aide success/insufficient/full text retained. |
| Ordinary quest packet | `pokered:ROUTE_11_GATE_2F:objects:2` | Itemfinder, 30 owned species and bag retry; shared aide text retained. |
| Service packet | `pokered:DAYCARE:objects:1` | Actual deposit/withdraw/party/growth/payment ownership required. |

Other explicit reservations include Saffron guards/drinks, in-game trades,
Fan Club boast flags and Pokémon cries, the kitchen random menu, Snorlax Pokédex
presentation, binoculars and link reception. Ordinary dialogue with extra effects
is not silently replaced by its convenient `text_far` line. Hidden events are
indexed, not registered. No quest success, sound playback, full source-script
execution, progression, departure, puzzle or journey acceptance is claimed.

Ordinary interactions use SourceEvents descriptors (dialogue/conditional
programs, trainers, pickups, shop and healing). The Vermilion Mart uses the
existing `vermilionMartClerkText` stock. The source Center is exactly 14×8,
zero padding, with source outside checkpoint `(11,4)` in VermilionCity. Root's
`c6882b6` generic healing composition covers this installed geometry; no regional
healing branch is needed.

## Exact root resolver and promotion work

`vermilion-content-root.patch` modifies only `Source/data/ceruleanContent.lua`.
It adds `registerPackage(name, root)` and immutable text/art lookup across
packages. Conflicting duplicate text/art fails. New package ordinary events/signs
register under their package ID, and only ordinary trainer descriptors register
their rosters; reserved rival/leader definitions remain available for scene owners.
It does not register another `SourceActors` resolver, replace the existing owner,
change canonical BLUE pose code or install content merely because files exist.
`packages.json` records the package inventory. Apply only during root composition:

```sh
git apply --check tools/integration/vermilion-content-root.patch
git apply tools/integration/vermilion-content-root.patch
```

After the existing Cerulean content installer (and before first entering any new
map), root adds exactly this registration call in its owned bootstrap:

```lua
CeruleanContent.registerPackage("vermilion", "data/vermilionPreparation/")
```

The bootstrap/dev-import/scene edits are not applied here. Root can register the
standalone SDK module in its private harness overlay:

```lua
import "dev/vermilionPreparationContracts"
Contracts.register("vermilion-preparation", VermilionPreparationContracts.run)
```

That suite intentionally asserts the current 30-map inventory remains inactive;
run it before promotion. It uses the real SourceEvents compiler/text renderer,
capacity/repeat observations, actual SDK JSON UTF-8 and scoped real SourceMaps
records for standard Center healing composition. It neither registers new
campaign content nor persists a candidate manifest. Package resolver composition
and full provider/actor/art construction still require root's integrated tests.

The complete proposal is `proposed-source-maps.json` with 65 maps. Its exact
semantic diff is **only** adding the 35 entries from `manifest-entries.json` to
`maps`; all existing entries and all other top-level fields are identical.
The new entries all use the existing `source` profile and paths under
`data/vermilionPreparation/`. There is no private key in the active manifest.
The cache proposal is `proposed-compact.json` + `proposed-tile-grids.json`.
Do not copy these into active paths until scene/gate owners are ready: merely
installing the map inventory changes missing-target resolution.

Specifically, on old map Route2 the proposed compact cache removes blocked
cells 193/396/717/796, corresponding to source warp IDs 1/3/4/5 (Diglett entrance,
trade house and both aide-gate ingress cells). No other existing compact map
field changes. All existing atlas tile records are exactly preserved. New
connections also make Cerulean south→Route5 and Vermilion/Diglett/Route11
geography available. This is a promotion effect, not acceptance or permission to
bypass source gates. Root must compose Cut access, source actor visibility,
boarding/departure, quests and missing-target diagnostics first. New source
script/interaction gaps remain honest binding diagnostics until their owners
resolve them.

When ready, root's mechanical promotion is to copy the proposed manifest to
`Source/data/sourceMaps.json` and regenerate the active cache with the existing
shared generator. No decoded definition or old map entry needs changing. Any
scene-driven blocker or entry metadata changes are an additional reviewed root
diff, not hidden in this preparation batch. Root owns fixture/coverage fingerprints,
SDK registration, native art review and campaign journeys.

## Reproduction and observed verification

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python tools/generate_vermilion_preparation.py --reference "$POKERED_REFERENCE_DIR" --check
python -m unittest tools.tests.test_vermilion_preparation tools.tests.test_cerulean_content tools.tests.test_map_generator tools.tests.test_viridian_generator tools.tests.test_source_map_pipeline tools.tests.test_source_events -v
python tools/generate_source_map_cache.py --output Source/data/sourceMapCache --check
python tools/harness/run.py --build-only --output "$HOME/Developer/Pokemon-PlayDate-env/evidence/vermilion-root-build-UNIQUE" snapshot
```

Generation writes a fresh directory (use `--output`); `--check` compares the full
flat artifact inventory without repairs. Every emitted runtime JSON uses literal
UTF-8 (`ensure_ascii=False`), including maps, cache, scripts, rosters and text.
Private and exported ASM global labels terminate the preceding text/program body,
including labels with trailing comments. Unprefixed chef recipes are retained.
No missing reference test is skipped, no Lupa or fake SDK is used.

Worker evidence lives at
`~/Developer/Pokemon-PlayDate-env/evidence/vermilion-content-prep-20261026-01/`.
Final focused host pass: **72 passed, zero skips** (`host-final.log`). Earlier
failed host output is preserved separately (`host.log`); it is not acceptance.
The final host pass includes independent blocks/PNG/collision, Blue wild slots,
rosters, original events/header connections/music, UTF-8/global boundaries,
complete reservation partition, pinned mutation/output rejection and every old
tracked Source byte unchanged from the exact base.

SDK 3.1.2 harness compilation passed (`harness-compile`, refreshed as
`harness-final` before its private overlay). The resolver-patched private harness
with explicit suite/package registration also compiles (`resolver-harness.pdx`);
`resolver-harness-build.json` records its exact source/PDZ hashes and verifies the
new suite is present in the compressed main PDZ. Production/harness boundary
checks additionally passed 5 tests, zero skips (`production-boundary.log`). A separate private project
applies the resolver patch and compiles production (`resolver-project`,
`resolver-production-stage`, `resolver-production.pdx`). The patch is unapplied
in this checkout. None of these bundles was run. No Simulator/native pixel, listening,
journey, physical-device, main acceptance or milestone-completion result exists.

Root-only SDK execution after deliberately adding the standalone registration
(and before map promotion):

```sh
python tools/harness/run.py contracts --output "$HOME/Developer/Pokemon-PlayDate-env/evidence/vermilion-root-sdk-UNIQUE"
```

This command is supplied for the sole Simulator owner; the worker did not run it.
Native catalog comparison, visual review and source-connected gameplay journeys
remain separate root work after scene composition/promotion.
