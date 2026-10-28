# Milestone 5.5 map/content candidates

Worker base is exact accepted `63267b0`; merging it was already up to date.
The first useful east packet was committed as `f2166ef` before continuing south.
No active manifest/cache, bootstrap, world/domain/session/codec, UI, battle, audio,
protected art, baselines or ledger changes. No Simulator, push or delegation.

## Packet inventory

| Package | Maps | Ordinary objects | Signs | Trainers included in objects | Reserved object/sign IDs |
| --- | ---: | ---: | ---: | ---: | ---: |
| `midgameEast` | 43 | 145 | 48 | 55 | 30 |
| `midgameSouth` | 42 | 150 | 39 | 78 | 31 |
| `midgameSaffron` | 21 | 108 | 11 | 41 | 13 |

These are **106 candidate maps**, composing to **171** with the accepted 65.
They are not activated or campaign accepted. No representative-floor shortcuts:

- East: Routes9/10, both Rock Tunnel floors and Center, Lavender and its
  Center/Mart/Cubone/Fuji/name-rater interiors; Routes7/8, both Saffron gates,
  all three east–west Underground Path maps; Celadon City/Center/Gym/Diner/Hotel/
  Chief House, all five Mansion maps, all seven Department Store maps,
  Game Corner/Prize Room and all five Rocket Hideout maps.
- South: all seven Pokémon Tower floors; Routes12–18, all associated gates,
  Super Rod/Fly houses; Fuchsia City/Center/Mart/Gym/Bill's Grandpa/Good Rod/
  Meeting Room/Warden interiors; Safari Gate, all four outdoor areas,
  all four rest houses and the Secret House.
- Saffron: City/Center/Mart/Gym/Dojo/Pidgey/Mr. Psychic, both Copycat floors,
  all eleven Silph floors and its elevator.

Every package exposes `contexts.json`: exact source map ID, runtime key,
horizontal padding, connections, warps, actor ID/pointer, source and runtime
coordinates, and the reserved owner where relevant. `manifest-entries.json`
is the candidate map inventory. `reservations.json` exhaustively partitions
unregistered object/sign IDs and separately lists bespoke per-map script seams.
`scripts.json` provides script hashes, text pointer indices and hidden-event
coordinates; source bodies remain outside Git.

Ordinary trainers, pickups, stock-backed shops, Centers, direct/conditional text,
Pokemon cries and eight ordinary gifts use existing SourceEvents descriptors.
The gifts are Coin Case, TM41, TM18, TM39, HM02, HM03, TM29 and TM36. Full-bag
retry/completion use the existing generic gift planner. Sound cues/waits are
preserved through the existing `source-audio` descriptor; actual audio remains a
known root-owned gap. Text is literal UTF-8. Reserved trainer definitions and full
Rival1/Rival2/Giovanni classes remain available without ordinary registration.

## Root installation calls

The shared gift planner currently omits `wStringBuffer`, required by six of the
new gift receipt recipes. Apply the supplied **unapplied one-line patch** before
registering these packages; it sets RAM from the actual ItemData name on success:

```sh
git apply --check tools/integration/midgame-gift-ram.patch
git apply tools/integration/midgame-gift-ram.patch
```

The worker has not edited `Source/game/sourceEvents.lua`. Root owns that small
integration and native receipt/full-bag validation. No regional event engine or
new runtime module is needed. After the existing content setup, before entering
new maps, add these exact calls in root's owned bootstrap:

```lua
CeruleanContent.registerPackage("midgameEast", "data/midgameEast/")
CeruleanContent.registerPackage("midgameSouth", "data/midgameSouth/")
CeruleanContent.registerPackage("midgameSaffron", "data/midgameSaffron/")
```

Do not copy a stale `proposed-source-maps.json` over root's integrated inventory.
The east/south/saffron proposals contain respectively 108/150/171 maps against
this worker's base. Compose a fresh candidate from root's current manifest:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
export MIDGAME_CANDIDATE="$POKEMON_ENV/evidence/m55-map-promotion-UNIQUE"
mkdir "$MIDGAME_CANDIDATE"
python - <<'PY'
import json, os
from pathlib import Path
candidate = Path(os.environ['MIDGAME_CANDIDATE'])
manifest = json.loads(Path('Source/data/sourceMaps.json').read_bytes())
for package in ('midgameEast', 'midgameSouth', 'midgameSaffron'):
    additions = json.loads((Path('Source/data') / package / 'manifest-entries.json').read_bytes())['maps']
    for name, entry in additions.items():
        if name in manifest['maps']:
            for field in ('id', 'key', 'path', 'source_sha256'):
                assert manifest['maps'][name][field] == entry[field], (name, field)
        else:
            manifest['maps'][name] = entry
(candidate / 'sourceMaps.json').write_text(json.dumps(manifest, sort_keys=True, separators=(',', ':')) + '\n')
PY
# Root composes story/field blockers and activation policy in this candidate.
python tools/generate_source_map_cache.py \
  --manifest "$MIDGAME_CANDIDATE/sourceMaps.json" \
  --source-root Source --output "$MIDGAME_CANDIDATE/cache"
# Root alone promotes after that composition/review:
cp "$MIDGAME_CANDIDATE/sourceMaps.json" Source/data/sourceMaps.json
cp "$MIDGAME_CANDIDATE/cache/compact.json" Source/data/sourceMapCache/compact.json
cp "$MIDGAME_CANDIDATE/cache/tile-grids.json" Source/data/sourceMapCache/tile-grids.json
```

Adding targets removes missing-target blockers on older maps. Root must compose
Cut, story guards, actor visibility and scripted mutations before accepting those
connections. Candidate cache generation alone does not establish traversability.

### Existing trades and guards

Root's restored `a30d996` packages own all nine NPCTrades and all four
SaffronGuards IDs; none overlaps these ordinary descriptors. New activation seams:

- `pokered:ROUTE_7_GATE:objects:1`, map `pokered:ROUTE_7_GATE`, source `(3,1)`.
- `pokered:ROUTE_8_GATE:objects:1`, map `pokered:ROUTE_8_GATE`, source `(2,1)`.
- `pokered:ROUTE_18_GATE_2F:objects:1`, map `pokered:ROUTE_18_GATE_2F`, MARC trade.

Activate the existing packages at root. `contexts.json` supplies runtime padding
and exact actor placement. CeruleanTradeHouse and the Cinnabar lab trade rooms
are not in this requested midgame inventory; their existing trade policy remains
reserved for their map activation. No replacement handler is generated.

### Shared cache generator adjustment

Silph11F source warp 3 is explicitly `LAST_MAP,10 ; inaccessible`; Saffron has
only eight outdoor warps. Its manifest entry blocks exactly
`pokered:SILPH_CO_11F:warps:3`, retaining the raw destination. The shared cache
builder now excludes explicitly blocked warps from outdoor-context inference.
It neither invents a destination nor changes any active cache output. Root must
preserve that blocked event. This generic fix changes only generator code.
Vermilion's `provenance.json` updates only this dependency hash; all its decoded
map/content/cache artifacts remain byte-identical. Its existing check then passes.

## Concrete remaining game work

The 74 reserved object/sign IDs and map-script seams are exact in each package.
They include Erika/Koga/Sabrina and rewards; Eevee, Fuji/Flute and rival scenes;
Tower ghost/Scope/Marowak and purified-zone healing; Game Corner coins/slots/prizes/
poster; Hideout spinners/Lift Key/elevator/Giovanni; Silph Card Key doors, rivals,
Lapras, Giovanni/President/Master Ball and elevator; Dojo choices; Copycat;
name rating, vending/drink-for-TM choices, rods/aide, Bicycle gates and Cycling
Road, Snorlax/Flute, Warden Gold Teeth/HM04/Strength, Safari admission/steps/balls/
battle mode, and specialized Silph nurse healing. HM02/HM03 gifts are ordinary
here; actual Fly/Surf, destination history and field behavior belong to field work.

Original terrain is source-decoded. Script-only block replacements/door states,
actor visibility toggles, hidden-item dispatch, original floor/teleport policies,
and scene-driven ingress protections still require root/scene/field composition.
Do not infer those behaviors from data presence. Binocular/zoo displays, link
reception, remaining choice/service interactions and audio timing are explicit
gaps rather than convenient dialogue substitutions.

## Reproduction and checks

Pins are `tools/references/midgame-{east,south,saffron}.json`: respectively
311/319/188 consumed SHA256 inputs, immutable Blue pokered revision
`af519899719f0754965776faac0e836a3b906e6d`. All extracted inputs remain outside Git.
`materialize_midgame_content.py` follows root's `materialize_pokered_packages.py`
pattern (`git show REV:path`, checksum validation, external cache), adding atomic
publication and read-only inventory checking.

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
for packet in east south saffron; do
  python tools/materialize_midgame_content.py --packet "$packet" --pokered "$POKERED_REFERENCE_DIR"
  python tools/materialize_midgame_content.py --packet "$packet" --check
  python tools/generate_midgame_content.py --packet "$packet" \
    --reference "$POKEMON_ENV/references/midgame-$packet" --check
done
```

Regeneration requires a fresh `--output` directory. The generator never activates
maps. Terrain uses the existing decoder and approved global imported-tone mapping;
additive NPC strips use the existing immutable strip resolver. No per-tile
whitening or protected RED/NPC regeneration.

Existing focused host suites: **72 passed, zero skips** (map generator, source
pipeline/events, Cerulean content, Vermilion preparation, Viridian generator).
Independent source audit checked **42,776 layout cells**, **2,085 PNG-derived
four-shade grids**, original object/warp/sign counts, exhaustive event/reservation
partitions, immutable text/sprite overlap and no restored trade/guard collisions.
All existing atlas tiles remain exact. Audit report is outside Git at
`~/Developer/Pokemon-PlayDate-env/evidence/m55-maps-source-audit/report.json`.

SDK3.1.2 production compilation passed for the first east packet and final all-map
candidate; final artifacts are under `evidence/m55-maps-all-compile/` in the same
environment. Compile-only validation is not native behavior, pixel or milestone
acceptance. Root alone runs Simulator and owns all final activation/acceptance.
