# Original Pokédex UI candidate

Staged only at `/private/tmp/pokemon-pokedex-ui`. Live Source has not been changed by this worker. Compile-only validation passed in `/private/tmp/pokemon-pokedex-ui-build-02`; root owns actual SDK execution and native visual acceptance. The full campaign remains unfinished.

`PokedexState(game)` is a native State overlay over the authoritative `game.session:pokedex()` records. The list contains all151 species in National Dex order. Up/down scroll one entry, left/right page eight, and both boundaries clamp without wrapping. A opens a seen entry; B returns from entry to list, then pops the overlay. Reopening resets selection to1. `getSnapshot()` returns a detached `{phase,selected,species,seen,owned}` record. Phases are `list`, `entry`, `closed`.

Unseen entries display unknown dashes and no front sprite. Seen-only entries show the proper name/front and explicitly withhold classification, measurements and flavor text. Owned entries reveal the pinned original details. The UI never grants discovery; actual session recruit/markSeen operations remain authoritative. All fronts use `PokemonArt.path(species,"front")`, including existing aliases, at exact integer2× scale without editing source images. All text remains readable native1-bit text on400×240. The UI restores graphics draw offset/font and invalidates its full rectangle on exit.

## Sources and names

`tools/references/pokedex.json` pins SHA-256 hashes and immutable URLs at pret/pokered revision `af519899719f0754965776faac0e836a3b906e6d` for:

- [Original names](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/pokemon/names.asm).
- [Internal-to-Dex order](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/pokemon/dex_order.asm) and [Dex constants](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/constants/pokedex_constants.asm).
- [Classification/height/weight and text pointers](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/pokemon/dex_entries.asm).
- [Original English shared Red/Blue entry text](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/pokemon/dex_text.asm).

The generator joins all190 internal rows before excluding the39 MissingNo placeholders. It requires all151 distinct National Dex records and the current stable species projection. Each generated record preserves the original internal ID/entry label, source name, classification, feet/inches, tenths of a pound and seven source flavor lines (including the page break). The original `#` text token expands to ASCII `POKE`. No area/evolution/availability data is invented.

`PokemonNames` provides codec-safe ASCII defaults, explicitly translating Nidoran's gender glyphs to `NIDORAN F`/`NIDORAN M`, source `MR.MIME` to `MR. MIME`, and retaining `FARFETCH'D`. The existing gameplay keys remain `nidoranF`, `nidoranM`, `mr`, `farfetchd`; art aliases remain unchanged. A separate two-line constructor patch imports this map and uses it only for new instances. It does not alter species stat blocks, moves, learnsets or starter names. PokemonCodec stays version3 with printable ASCII<=10. Decode still restores the saved name verbatim; existing nicknames or old ASCII defaults such as `MR` are never guessed/migrated.

## Root integration and execution

The manifest lists exact owned runtime file hashes. Review `pokemon-names.patch` and `pokedex-seen-fixture.patch` independently. The latter is a supplementary harness fixture, not a gameplay acquisition path: optional `pokedex_seen=[species,...]` must be a dense, unique list of known species with at most151 elements. Complete validation precedes reset; only after the session has been installed does it mark those species seen. It does not mark them owned.

Root owns these hooks; this worker did not edit main, PauseState or diagnostics:

- Import `game/pokedexState` and register `machine:register("pokedex",PokedexState(game))`.
- Offer `POKEDEX` first in the native pause menu only when `game.session:questFlag("EVENT_GOT_POKEDEX")` is true; pop pause, then push `pokedex`.
- Expose top-level diagnostics `pokedex = machine:get("pokedex"):getSnapshot()` when registered.
- Import/register `dev/pokedexContracts` as `Contracts.register("pokedex",PokedexContracts.run)` for SDK validation.

The private validator adds only UI/dev imports and the contract registry, overlays manifest files onto current Source, refreshes fingerprints and compiles by default. It deliberately leaves the root-owned production menu/registration/diagnostics integration to root. A future live integration must not overwrite newer unowned Source files.

```sh
python3 -m unittest tools.tests.test_pokedex_generator -v
python3 tools/generate_pokedex.py --reference-root /private/tmp/pokered-af519899719f0754965776faac0e836a3b906e6d --output-root /private/tmp/pokemon-pokedex-ui --check
python3 /private/tmp/pokemon-pokedex-ui/validate_staged.py --project "$PWD" --output /private/tmp/pokemon-pokedex-ui-review-01
# Root Simulator owner only:
python3 /private/tmp/pokemon-pokedex-ui/validate_staged.py --project "$PWD" --output /private/tmp/pokemon-pokedex-ui-sdk-01 --execute
```

The generator writes only an explicit staged output root. `--check` is read-only and exits nonzero for pin/projection/schema/data drift. It does not touch existing caches/reports or any protected sprite.

Six offline host tests pass: independent synthetic190-row/151-species fixtures prove internal-order mapping, literal source text/unit conversion, ASCII aliases/limits, missing/duplicate/malformed records, source checksum/path failures, read-only drift rejection and refusal to generate over live Source. Pinned all151 regeneration/check and SDK compilation passed. Ten SDK groups are supplied: all151 production constructor/codec/art paths; literal original measurements/flavor vectors; unseen gate; seen-only→owned transitions; scroll/index boundaries; actual overlay lifecycle; repeated real drawing with graphics/RNG/discovery invariants; saved nickname preservation and strict codec rejection; unchanged starter foundation; malformed optional fixture reset preflight. Runtime success is pending root execution.

After root installs the menu/diagnostic hooks, native `/private/tmp/pokemon-pokedex-ui/scenarios/pokedex-discovery.json` captures first owned list/data, seen-only list/data, unknown entry, last entry and both scroll boundaries. `pokedex-gated.json` verifies the pre-acquisition menu lacks POKEDEX. Both use actual button input and explicitly labeled fixture setup; the acquisition itself must still be proven through the source event journey. Root can pass either path with `--scenario PATH --execute` after wiring. These recipes currently assume the approved first-position menu seam.

Area maps, encounter availability, evolution pages, cries, search and regional completion rewards remain out of scope; they must be backed by implemented world/data behavior before being offered.
