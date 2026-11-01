# Root-executed checkpoint 5.5b native showcase

Preparation only. No Simulator, locks, GUI, Accessibility API, device, USB,
serial or OS settings were touched. No runtime tests, push or delegation were
performed. B remains private and unaccepted. Root's current full-host rerun
(`exec61981`) is unrelated to this packet and was not inspected or interrupted.
Native performance, recording overhead, battle success and pacing are unmeasured
until Root executes. Audio remains held: deliver **silent — audio held**.

This adapts the existing A recipe at
`$POKEMON_ENV/evidence/showcase-5.5a-recipe-20261029-01` and its recorder/exporter;
their exact hashes are retained in `provenance.json`. It uses existing runner,
strict save importer, input driver, source portals, fixed B road waypoints and
cleanup owners. There is no new planner, game contract or compression system.

## Immutable earned seed

Use Bulbasaur's genuine post-Fuji, pre-Koga Save, not the final B chain:

```text
$POKEMON_ENV/evidence/m55b-earned-fourth-20261030-01/
  01-midgame--restart-55b-bulbasaur/processes/0001/partial-save.json
SHA256 948ff168e4d4e558bdda65d124112aa86c1fa9656457d961d5ecd66b83f854e4
```

The two existing archived slots under that generation's `runtime-data/` are:

| Slot | SHA256 |
| --- | --- |
| adventure.a.json | eea7659948da1b34c2b5e035a8665660bdbd780acdfc2fecbba85fefea7c44f7 |
| adventure.b.json | e682f66f77dc84d87d7b20345b15e0e5afb23d7514246a6f000212a36b1d4431 |

The actual producer is recorded as PID 92977, `failed-exited`, return code -9.
Its failure remains a failure. The run manifest SHA256 is
`d065df5d0e016469842f9c71bc0c2191f1d46b080f411d30bef7fb947bc6a52f`.
No live-PID assumption is made from this historical number. The strict importer
binds the marker to that exact stopped generation and reads both archived files.

Actual `02131-result.json` observes `saved`, valid and roundtrip-equal. Its complete
codec equals both the marker observation and the newest actual slot payload
(`adventure.b.json`, sequence 48). The result hash is
`c3fe5049bb22c76b75e73e110aacdccb41ca9879023cd1b4a28957017a1ad273`.
The saved location is Lavender Pokécenter (3,3), facing up. Only
`tower-fuji-flute` is completed in B; the earned Flute is present. Soul Badge,
Koga victory, Route 12 Snorlax clearance and Route 12 trainer 6 victory are unset.
An absent/false flag is reported as unset, not inserted into the save.

Accepted-A ancestry is verified through `restarting.import_chain_save`, including
accepted A `c946efdfbf20952844dbca78d97a5a3439212fab`, its exact two slots,
production Source `f7075f0a4b0f0505e3cc60ac425c8ce972d731ea9e052216d2dfd00546d5699d`,
actual A process restart/receipts and earned 5.4 ancestry. Full references and
hashes are in `provenance.json`. The host-only check passed. Replay must select
real CONTINUE and pass complete codec equality before input. No save bytes,
flags, position, resources, Pokémon, RNG or rewards are manufactured.

The archived producer used historical Source; it is evidence of earned state,
not acceptance of today's Source. Capture uses read-only B checkout
`/Users/burbujamc/.t3/worktrees/Pokemon-PlayDate/t3-2c976160`, pinned at `e71e3301`
with actual base Source fingerprint
`e470f3cab45821d11c197815e73e6ca2fb06b3796be4be1a269885510da91261`.
Docs-only descendant commits are allowed only while **every Source and harness
file hash and inventory remain equal**. Any runtime change refuses execution.
The private capture overlay is separately declared and fingerprinted; this is
not the production PDX and cannot establish production performance.

Canonical `evidence/chain/5.5b/<starter>` finals remain untouched. No final-chain
export function is called. All new saves belong to UUID-isolated private Data.

## Root commands and admission

Use this checkout's packet after reviewing/cherry-picking it. Keep the retained A
recipe and pinned footprint-reader file available at their recorded paths.
All output directories must be new. First run host verification:

```sh
source "$HOME/Developer/Pokemon-PlayDate-env/env.sh"
SHOWCASE_PACKET=/Users/burbujamc/.t3/worktrees/Pokemon-PlayDate/t3-8a117d36/tools/integration/checkpoint-b/showcase
python "$SHOWCASE_PACKET/record.py" --check
```

**Do not execute the following runtime commands while the hold remains.** Root
must first independently verify actual Accessibility trust, exact Clear control
and measured reclamation, retain that evidence, release the long-run safeguard
hold and relinquish the previous runtime owner. Follow the existing
`tools/harness/malloc_history_clear.md` qualification; this recipe neither runs
AX automation nor substitutes a flag for that qualification. Keep the existing
16 MiB pool setting. Do not disable malloc history or change the pool/settings.
`--root-gates-verified` is Root's explicit assertion that these prerequisites
already passed, not a permission or verification mechanism.

After those gates, capture a 2–3 second preflight before battle/story effects:

```sh
python "$SHOWCASE_PACKET/record.py" --execute-root-owned --root-gates-verified \
  --preflight-only --output "$POKEMON_ENV/evidence/showcase-5.5b-preflight-ROOT-01"
python "$SHOWCASE_PACKET/export.py" \
  "$POKEMON_ENV/evidence/showcase-5.5b-preflight-ROOT-01" \
  --output "$POKEMON_ENV/evidence/showcase-5.5b-preflight-export-ROOT-01"
ffprobe -v error -show_streams -show_format -of json \
  "$POKEMON_ENV/evidence/showcase-5.5b-preflight-export-ROOT-01/preflight-complete.mp4"
ffmpeg -v error -n \
  -i "$POKEMON_ENV/evidence/showcase-5.5b-preflight-export-ROOT-01/preflight-complete.mp4" \
  -frames:v 1 "$POKEMON_ENV/evidence/showcase-5.5b-preflight-export-ROOT-01/decoded.png"
```

The inherited framebuffer recorder caps the `preflight` label at 3 SDK wall
seconds; final unknown tail is omitted. The real input is one downward step on
the saved Center floor (static path checked), then a settled hold. Verify decoded
duration is 2–3 seconds; reject a shorter sample or excessive frame gaps. Compare
`decoded.png` with its matching original `frames/showcase-preflight-*.png`, using
`runtime-data/showcase-frames.jsonl` timestamps. Inspect at 100% and normal size:
400×240 game pixels, glyphs, floor edges, walking stride, no blur or cropping.
The output must have one video stream and no audio stream. A clean static sample
does not establish battle motion quality; inspect actual chapters too.

After preflight passes, Root records the bounded journey:

```sh
python "$SHOWCASE_PACKET/record.py" --execute-root-owned --root-gates-verified \
  --output "$POKEMON_ENV/evidence/showcase-5.5b-earned-ROOT-01"
python "$SHOWCASE_PACKET/export.py" \
  "$POKEMON_ENV/evidence/showcase-5.5b-earned-ROOT-01" \
  --output "$POKEMON_ENV/evidence/showcase-5.5b-companions-ROOT-01"
```

One runner owns all inputs; no second controller/GUI interaction is allowed.
The existing global Simulator/device/private Data locks are used only by Root's
runtime execution. `--check` and `--compile-only` acquire none. The guard samples
the owned Simulator's **physical footprint**, including compressed/swapped memory,
every 0.5 seconds using the existing census reader. Above 1 GiB, a read failure or
30-minute overall runtime deadline interrupts this runner, whose cleanup stops
only its own child. Sampling may overshoot between checks; it is not a memory
reservation. Existing bounded Client requests and semantic action/step/encounter/
transition/blackout limits remain active. The guard does not clear history or
make long runs safe. A ceiling/deadline failure is a failed capture, not permission
to raise limits, change settings or continue with a second owner.

## Actual-input stages

1. `walk`: leave Lavender Center through ordinary D-pad/door inputs.
2. `trainer`: approach and fight undefeated
   `pokered:ROUTE_12:objects:6`, the Fisherman with one level-27 Goldeen. Capture
   starts before approach, so any incidental trainer encounter is also retained.
   This stage intentionally precedes Snorlax: its northern sight line could be
   crossed on the way to the blocker. The saved seed proves it is undefeated;
   victory must have the existing source outcome receipt. Never reset/rematch it.
3. `cutscene`: heal at the real Center, use the earned Bag Flute at source
   waypoint (10,61) via `wake_snorlax('ROUTE_12', 1, ...)`, observe wake-up text/
   encounter and ordinary resolution, then require genuine blocker clearance.
   This is the Snorlax wake-up scene, not a scripted NPC walk or Fuji replay.
   Its full capture includes approach and wild battle; select the actual scene
   interval after inspecting frames. If native observation does not establish a
   suitable cutscene, report the missing requirement rather than rename footage.
4. `gym`: use the existing B road, Route 13 Center/restock detour, Route 14 east
   entry, Route 15 gate and Fuchsia Center. `leader` approaches and battles Koga
   through source geometry, checks Soul Badge/TM06, returns to Center and saves.
   Stop before Safari/Cycling Road. The complete gym companion remains retained;
   a gym excerpt in the short clip is explicitly labelled.

These calls reuse the passed B driver. The closest final earned journeys are
`m55b-earned-fourteenth-resumed-20261030-01` (Bulbasaur/Squirtle) and
`m55b-charmander-learning-retry-20261030-01/01-midgame--restart-55b-charmander`.
They do not establish this new capture route's success or current Source
acceptance. Host checks here establish only pinned bytes, seed provenance,
selected terrain endpoints and the Center step, not live actor occupancy or
all portal interactions. No new training/grinding or artificial reward is used.

## Composition and export gate

Keep `*-complete.mp4`, source PNGs, wall timestamps, staged Source/PDX, request/
result receipts, `host-footprint.jsonl` and private save archive. Native game area
is the entire 400×240 frame, crop none, panel 400×240, scale 1. No desktop/window
capture, resampling, smoothing, interpolation, speedup, slow motion or filler.
VFR durations retain actual SDK elapsed time, including stalls. CRF 0 H.264 is
encoded directly from original PNGs; the measured final interval ends at the
last timestamp, with the inherited 1 ms terminal-frame encoding detail disclosed.
SRT captions stay separate so native game pixels remain unobscured.

Inspect full companions first. Choose source-relative intervals for 60–90 seconds
total, for example about 5–8 seconds walking, the **entire trainer battle**, about
8–15 seconds gym and about 5–10 seconds wake-up scene. These are editorial budgets,
not measured durations. Trim travel before/after the trainer only after identifying
an uninterrupted challenge/intro → every turn/opponent → victory/reward → ordinary
return interval. Record those measured offsets in a Root-reviewed plan:

```json
[
  {"label":"walk","start":0,"end":6,"title":"Lavender walk — original speed; silent, audio held"},
  {"label":"trainer","complete_battle":true,"title":"Route 12 Fisherman — COMPLETE battle; original speed; silent"},
  {"label":"gym","start":0,"end":12,"title":"Koga gym — excerpt, explicit cut; full capture retained; silent"},
  {"label":"cutscene","start":0,"end":8,"title":"Snorlax wake-up — excerpt, explicit cut; silent"}
]
```

The example offsets are **unmeasured placeholders**, not an executable promise.
Replace them from actual `capture-report.json` and timestamped frames. The omitted
trainer bounds above retain the whole trainer stage; to remove approach/return,
add the reviewed start/end and retain `complete_battle:true`. That marker is
Root's review assertion; the exporter cannot prove semantic completeness. Never
set it on a shortened battle. Include challenge, every turn and victory in one
continuous interval. Do not compose opening/ending excerpts and call them complete.
Cuts between chapters and omissions from gym/wake-up must be disclosed in SRT.

```sh
python "$SHOWCASE_PACKET/export.py" \
  "$POKEMON_ENV/evidence/showcase-5.5b-earned-ROOT-01" \
  --output "$POKEMON_ENV/evidence/showcase-5.5b-final-ROOT-01" \
  --plan "$POKEMON_ENV/evidence/showcase-5.5b-reviewed-plan-ROOT-01.json"
ffprobe -v error -show_streams -show_format -of json \
  "$POKEMON_ENV/evidence/showcase-5.5b-final-ROOT-01/PokemonBlue-5.5b-showcase.mp4"
```

Exporter requires all four chapter labels, Root's complete-battle assertion,
native dimensions, monotonic consecutive completed frames and wall timestamps,
and a 60–90 second final result. It refuses length failure; no automatic trainer
cuts or acceleration fallback exists. If the actual complete battle alone leaves
no 60–90 second composition, retain all companions and report that exact pacing
blocker. A companion does not replace the requested complete battle in the short
clip. Another genuinely untouched earned trainer would need proof and a reviewed
recipe change; debug rematches are forbidden.

`PokemonBlue-5.5b-showcase.json` records chapter output boundaries/source offsets
and probe results; `.srt` labels the cuts and silence. Chapter metadata is a
sidecar, not claimed as embedded MP4 chapters. Root extracts a meaningful frame
from **every** chapter with `ffmpeg -ss <output_start+offset> -i ... -frames:v 1 ...`,
compares matching source PNGs at native pixels, and watches every chapter's motion
and transitions at speed 1. Check no missing steps/black frames, whole trainer
challenge-to-victory, matching receipt/stable ID, gym rewards, actual wake-up,
legibility, final duration and silent label. Retain the inspected frame paths and
actual measured cadence/max gaps in the delivery receipt. Native Simulator
footage is not hardware playability proof or current B acceptance.

## Cleanup and preparation validation

On success, the recorder removes its control file, quiesces/finalizes existing
captures, stops only its owned Popen via `restarting.stop_owned`, confirms exit,
copies private Data to `runtime-data/`, then removes only that UUID Data directory.
On failure it stops recording, attempts existing artifact finalization unless the
host ceiling was hit, and records failures; host-limit failures prioritize stop.
An unconfirmed exit leaves private Data intact and raises. Do not delete it or
kill a historical/global PID. No preferences, audio settings, accepted chain,
canonical B finals or existing runtime lock files are rewritten. Preserve failed
captures and cleanup reports; use a new output path for any authorized retry.

Preparation passed strict host import, actual Save-result/newest-slot equality,
Source/harness pin checks, selected static terrain endpoints, Python syntax and
SDK 3.1.2 compile only. Compile artifact:
`$POKEMON_ENV/evidence/showcase-5.5b-recipe-compile-20261030-01`.
The offline exporter passed a clearly synthetic 65-second native-dimension smoke
at `$POKEMON_ENV/evidence/showcase-5.5b-offline-export-20261030-01/export-reviewed`.
Synthetic output proves only export mechanics, never captured detail, pacing or
native compatibility. See `validation.json`. No native execution, capture,
motion approval, performance result or checkpoint acceptance is claimed.
