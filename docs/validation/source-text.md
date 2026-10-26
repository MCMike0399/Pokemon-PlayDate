# Imported source text candidate

Prepared on `wip/source-text` from `1339333` for full-game goal 5.2 step 5.
This is implementation preparation, not native acceptance. The root Source
freeze for 5.1 remains in force; this branch does not modify the ledger,
`main.lua`, event dispatch/controllers, or protected art.

`EventText.pagesFrom(labels, resolver, ram)` keeps its existing arguments and
paragraph records (`label`, `text`, `receipt`, `source`). Source `line`, `next`
and `cont` rows reflow as words on the wider Playdate display; `para` preserves
the paragraph boundary. Source terminators close individual text fragments so
RAM/numeric commands can still follow them. Unknown tokens, malformed UTF-8,
missing RAM values and unsupported controls fail explicitly. Decimal fields
use confirmed integers and the source digit width; the currently imported BCD
flag combination suppresses leading zeroes and left aligns. BCD values are
semantic integers supplied by the event owner, not packed byte strings.

`Dialog` measures before presentation and splits overflow into complete pages.
Words stay whole unless a single word exceeds a line. Explicit newline/formfeed
boundaries survive, paragraphs never disappear, and the callback fires only
after every display page is acknowledged. `lines`/`currentLine` describe display
pages. `charIndex` remains a byte offset for existing diagnostics, but update
advances it only to complete UTF-8 boundaries. DialogState generation/instance
handling and host progress logic are unchanged. A first A reveals the current
page; the following A advances it.

Short ordinary strings that fit the existing box and leave the advance gutter
retain the original `drawTextInRect` path and cue. Extended/overflow pages use
the same current SDK font for ordinary glyphs, measured rows at x14/y192, a
360px text region, and a small arrow entirely inside the existing frame.
Existing box geometry stays unchanged. The runtime contracts compare ordinary
short text to the original renderer pixel for pixel, at partial/full reveal.

## Charset and provenance

The checked-in `sourceText.json` covers all 43 named tokens and every literal in
the pinned **English** charmap section. This includes the unused small kana
already in that section. The separate Japanese localization alias table is
excluded; this work does not introduce Japanese localization.

`#` deliberately remains `POKE`, matching the established display policy.
Literal `é` remains `é` and now renders with its own fallback. Name/battle tokens
use explicit context (`player`/`rival` default RED/BLUE; `target`/`user` required).
PC/TM/TRAINER/ROCKET and compact PK/MN/PKMN, Lv, ID, ED, colon/dot and bold-letter
tokens have explicit readable expansions in the existing font. Bold-letter
and logo tokens preserve their letters/abbreviations rather than reproducing
special source logo typography. Paragraph/line/end tokens are interpreted as
controls, never silently discarded as unknown tokens. Naming/options flows are
outside this candidate.

The real SDK findings establish that glyph lookup alone does not prove a
usable `é`. All 33 extended English literals therefore use deterministic
fallbacks, even when `font:getGlyph` returns an image. Ordinary ASCII never
switches fonts. Each fallback copies an original 8×8 tile into a transparent
16×16 image using exact integer 2× pixels, centered within the current line
height. Source shades below128 become ink. These small source pixel glyphs
extend the monochrome style without replacing the ordinary font.

[The reference manifest](../../tools/references/source-text/manifest.json)
records revision `af519899719f0754965776faac0e836a3b906e6d`, paths and SHA256s.
Font tiles use the charmap's source bank: main font starts at0x80; extra at0x60;
battle extra at0x62. Prime/double-prime use Pokédex tiles0/1. The town-map up
arrow uses its actual source PNG. No RED/NPC/tile/battle asset is changed.

Regenerate into an explicit candidate destination, or verify without writing:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python3 tools/generate_source_text.py --check
python3 tools/generate_source_text.py --output /path/to/candidate-sourceText.json
python3 -m unittest tools.tests.test_source_text -v
```

Host tests inspect pinned inputs, generated pixels/coverage and the actual
imported JSON corpus. They do not execute/transpile Lua, fake SDK globals, or
pretend font/layout results came from Playdate. Harness protocol remains literal
UTF-8 (`ensure_ascii=False`); no Latin-1/replacement decoding is introduced.

## Root integration and native checks

Before the existing `import "ui/dialog"`, add these exact lines in root-owned
`main.lua` (or the production/dev overlay owner as appropriate):

```lua
import "game/sourceText"
import "ui/sourceTextFont"
```

After production imports and `dev/contracts`, import/register the SDK suite:

```lua
import "dev/sourceTextContracts"
Contracts.register("source-text", SourceTextContracts.run)
```

No state registration, event-controller edit, fixture addition or protocol
change is required. Keep the dev suite in the harness-only build when the
production import split lands. `SourceTextContracts.run()` is independently
callable by the root's scoped SDK driver; the normal registration above also
includes it in integrated `contracts` execution.

The suite has42 cases: all-token semantics, RAM/numeric recipes, the194 supported
current imported records (and explicit rejection of three source-branch records),
33 individual glyph pixel comparisons, four native glyph sheets, both existing
fonts, UTF-8 reveal/advance, long paragraphs/oversized words, ordinary short-text
pixel preservation, and a readable cue/read-only drawing check. Each glyph test
name records whether the actual SDK default font reports that glyph present;
actual rendered fallback pixels are checked regardless. It saves these native
400×240 images directly under the harness frame directory:

- `source-text-glyphs-1`, `-11`, `-21`, `-31`: all33 labeled source glyphs.
- `source-text-typing-1` through `-5`: complete UTF-8 characters at partial reveal.
- `source-text-pages-*`: every page of a long paragraph plus explicit breaks and
  a65-character oversized accented word. The suite also acknowledges every page
  through the same production advance seam used by A.
- `source-text-symbols-complete`: readable currency/accent/sex/ellipsis and cue.

After root integration, the existing harness scenario runs integrated contracts:

```sh
python3 tools/harness/run.py --scenario tools/harness/scenarios/source-text.json \
  --output "$POKEMON_ENV/evidence/source-text-native-UNIQUE"
```

The root must inspect these actual PNGs and run the current protected2494-image
catalog comparison plus relevant intro/event/learning regressions on the merged
source. Existing controller lifecycle contracts sometimes dispatch completion
callbacks directly; those alone do not establish real button timing. Native
execution, final image inspection and input-driven integration remain pending.
Unsupported assembler conditionals/patch directives in three existing imported
records remain explicit errors; selecting their source branches belongs to the
importer/event owners. Japanese aliases and numeric flag combinations absent
from current imported data likewise fail rather than approximating silently.

## Preparation checks

Eight new host data tests and generator `--check` pass. The complete host run
executes547 tests:546 pass, with only the expected current-Source coverage
fingerprint rejection. The initially missing pinned move cache was restored
locally; all eight runtime-move-coverage host tests then pass. A private copy with only
the import/registration additions compiles under the installed Playdate SDK.
No Simulator process was launched by this worker. Preparation artifacts and
host output are retained under
`~/Developer/Pokemon-PlayDate-env/evidence/source-text-preparation-20261026-01/`.
The accepted coverage matrix is deliberately not regenerated for a private
candidate; its current-Source fingerprint check is expected to reject this tree.
